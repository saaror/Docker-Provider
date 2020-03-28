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
        containerResourceDimensionHash = {}
        response = CAdvisorMetricsAPIClient.getContainerCapacityFromCAdvisor(winNode: nil)
        if !response.nil? && !response.body.nil? && !response.body.empty?
          podInventory = response.body
          podInventory["items"].each do |items|
            podNameSpace = items["metadata"]["namespace"]
            podName = items["metadata"]["name"]
            podUid = KubernetesApiClient.getPodUid(podNameSpace, items["metadata"])
            if podUid.nil?
              next
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
                  containerResourceDimensionHash[key] = [containerName, podName, controllerName, podNameSpace].join('~~')
                #   # Convert cpu limit from nanocores to millicores
                #   cpuLimitInNanoCores = KubernetesApiClient.getMetricNumericValue("cpu", cpuLimit)
                #   cpuLimitInMilliCores = cpuLimitInNanoCores / 1000000
                
                # Get cpu limit in nanocores
                  containerCpuLimitHash[key] = KubernetesApiClient.getMetricNumericValue("cpu", cpuLimit)

                  # Get memory limit in bytes
                  containerMemoryLimitHash[key] = KubernetesApiClient.getMetricNumericValue("memory", memoryLimit)
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
      return [containerCpuLimitHash, containerMemoryLimitHash, containerResourceDimensionHash]
    end
  end
end
