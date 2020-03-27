# Copyright (c) Microsoft Corporation.  All rights reserved.
#!/usr/local/bin/ruby
# frozen_string_literal: true

require_relative "CAdvisorMetricsAPIClient"
require_relative "KubernetesApiClient"

class KubeletUtils
  class << self
    def get_node_capacity
      cpu_capacity = 1.0
      memory_capacity = 1.0

      response = CAdvisorMetricsAPIClient.getNodeCapacityFromCAdvisor(winNode: nil)
      if !response.nil? && !response.body.nil?
        cpu_capacity = JSON.parse(response.body)["num_cores"].nil? ? 1.0 : (JSON.parse(response.body)["num_cores"] * 1000.0)
        memory_capacity = JSON.parse(response.body)["memory_capacity"].nil? ? 1.0 : JSON.parse(response.body)["memory_capacity"].to_f
        $log.info "CPU = #{cpu_capacity}mc Memory = #{memory_capacity / 1024 / 1024}MB"
        return [cpu_capacity, memory_capacity]
      end
    end

    def get_all_container_limits
      begin
        clusterId = KubernetesApiClient.getClusterId
        containerCpuLimitHash = {}
        containerMemoryLimitHash = {}
        response = CAdvisorMetricsAPIClient.getContainerCapacityFromCAdvisor(winNode: nil)
        if !response.nil? && !response.body.nil? && !response.body.empty?
          podInventory = response.body
          podInventory["items"].each do |items|
            podNameSpace = items["metadata"]["namespace"]
            podName = items["metadata"]["name"]
            if podNameSpace.eql?("kube-system") && !items["metadata"].key?("ownerReferences")
              # The above case seems to be the only case where you have horizontal scaling of pods
              # but no controller, in which case cAdvisor picks up kubernetes.io/config.hash
              # instead of the actual poduid. Since this uid is not being surface into the UX
              # its ok to use this.
              # Use kubernetes.io/config.hash to be able to correlate with cadvisor data
              if items["metadata"]["annotations"].nil?
                next
              else
                podUid = items["metadata"]["annotations"]["kubernetes.io/config.hash"]
              end
            else
              podUid = items["metadata"]["uid"]
            end

            # Setting default to No Controller in case it is null or empty
            controllerName = "No Controller"

            if !items["metadata"]["ownerReferences"].nil? && 
                items["metadata"]["ownerReferences"][0].nil? &&
                !items["metadata"]["ownerReferences"][0]["name"].nil? &&
                !items["metadata"]["ownerReferences"][0]["name"].empty?
                controllerName = items["metadata"]["ownerReferences"][0]["name"]
            end

            podContainers = []
            if items["spec"].key?("containers") && !items["spec"]["containers"].empty?
              podContainers = podContainers + items["spec"]["containers"]
            end
            # Adding init containers to the record list as well.
            if items["spec"].key?("initContainers") && !items["spec"]["initContainers"].empty?
              podContainers = podContainers + items["spec"]["initContainers"]
            end

            if !podContainers.empty? 
              podContainers.each do |container|
                containerName = container["Name"]
                if !container["resources"].nil? && !container["resources"]["limits"].nil?
                    cpuLimit = container["resources"]["limits"]["cpu"]
                    memoryLimit = container["resources"]["limits"]["memory"]
                    key = clusterId + "/" + podUid + "/" + containerName
                    containerCpuLimitHash[key] = cpuLimit
                    containerMemoryLimitHash[key] = memoryLimit
                end
              end
            end
          end

          # return [cpu_capacity, memory_capacity]
        end
      rescue => errorStr
        @log.info "Error in get_all_container_limits: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return [containerCpuLimitHash, containerMemoryLimitHash]
    end
  end
end
