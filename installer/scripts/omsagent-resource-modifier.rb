#!/usr/local/bin/ruby
# frozen_string_literal: true

require "json"
require_relative "tomlrb"
require_relative "microsoft/omsagent/plugin/KubernetesApiClient"

@cpuMemConfigMapMountPath = "/etc/config/settings/custom-cpu-memory-settings"
@replicaset = "replicaset"
@daemonset = "daemonset"

#Default values for requests and limits in case of absent config map for custom cpu and memory resources
@defaultOmsAgentCpuLimit = "150m"
@defaultOmsAgentMemLimit = "600Mi"
@defaultOmsAgentCpuRequest = "75m"
@defaultOmsAgentMemRequest = "225Mi"
@defaultOmsAgentRsCpuLimit = "150m"
@defaultOmsAgentRsMemLimit = "500Mi"
@defaultOmsAgentRsCpuRequest = "50m"
@defaultOmsAgentRsMemRequest = "175Mi"

# Use parser to parse the configmap toml file to a ruby structure
def parseConfigMap
  begin
    # Check to see if config map is created
    if (File.file?(@cpuMemConfigMapMountPath))
      puts "config::configmap container-azm-ms-agentconfig for settings mounted, parsing values for custom cpu and memory resources"
      parsedConfig = Tomlrb.load_file(@cpuMemConfigMapMountPath, symbolize_keys: true)
      puts "config::Successfully parsed mounted custom cpu memory config map"
      return parsedConfig
    else
      puts "config::configmap container-azm-ms-agentconfig for settings not mounted, using defaults for cpu and memory resources"
      return nil
    end
  rescue => errorStr
    puts "config::error::Exception while parsing toml config file for custom cpu and memory config: #{errorStr}, using defaults"
    return nil
  end
end

def getRequestsAndLimits(response)
  begin
    currentResources = {}
    if !response.nil? && !response.body.nil? && response.body.empty?
      omsAgentResource = JSON.parse(response.body)
      if !omsAgentResource.nil? &&
         !omsAgentResource["spec"].nil? &&
         !omsAgentResource["spec"]["template"].nil? &&
         !omsAgentResource["spec"]["template"]["spec"].nil? &&
         !omsAgentResource["spec"]["template"]["spec"]["containers"].nil? &&
         !omsAgentResource["spec"]["template"]["spec"]["containers"][0].nil? &&
         !omsAgentResource["spec"]["template"]["spec"]["containers"][0]["resources"].nil?
        resources = omsAgentResource["spec"]["template"]["spec"]["containers"][0]["resources"]
        if !resources["limits"].nil?
          currentResources["cpuLimits"] = resources["limits"]["cpu"]
          currentResources["memoryLimits"] = resources["limits"]["memory"]
        end
        if !resources["requests"].nil?
          currentResources["cpuRequests"] = resources["requests"]["cpu"]
          currentResources["memoryRequests"] = resources["requests"]["memory"]
        end
      else
        puts "config::error::Error while processing the response for omsagent(ds/rs) : expected json key is nil"
      end
    end
  rescue => errorStr
    puts "config::error::Error while processing the response for omsagent(ds/rs) resource for requests and limits : #{errorStr}"
  end
end

#Set the resources for daemonset and replicaset
def getCurrentResources(controller)
  begin
    currentResources = {}
    if !controller.nil?
      if (controller.casecmp(@daemonset) == 0)
        # Make kube api query to get the daemonset resource and get current requests and limits
        response = KubernetesApiClient.getKubeResourceInfo("omsagent")
        currentResources = getRequestsAndLimits(response)
      elsif (controller.casecmp(@replicaset) == 0)
        # Make kube api query to get the replicaset resource and get current requests and limits
        response = KubernetesApiClient.getKubeResourceInfo("omsagent-rs")
        currentResources = getRequestsAndLimits(response)
      end
    end
    #returning a hash of the current resources
    return currentResources
  rescue => errorStr
    puts "config::error::Exception while getting current resources for the pod, using defaults"
    return nil
  end
end

#Parse config map to get the custom settings for cpu and memory resources
configMapSettings = parseConfigMap
controller = ENV["CONTROLLER_TYPE"]
currentAgentResources = getCurrentResources(controller)
