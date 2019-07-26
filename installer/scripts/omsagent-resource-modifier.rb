#!/usr/local/bin/ruby
# frozen_string_literal: true

require "json"
require_relative "tomlrb"
require_relative "microsoft/omsagent/plugin/KubernetesApiClient"

@cpuMemConfigMapMountPath = "/etc/config/settings/custom-resource-settings"
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

#Get current requests and limits for daemonset/replicaset
def getRequestsAndLimits(response)
  begin
    currentResources = {}
    if !response.nil? && !response.body.nil? && !response.body.empty?
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
    return currentResources
  rescue => errorStr
    puts "config::error::Error while processing the response for omsagent(ds/rs) resource for requests and limits : #{errorStr}"
  end
end

#Get the resources for daemonset/replicaset
def getCurrentResources(controller)
  begin
    currentResources = {}
    if (controller.casecmp(@daemonset) == 0)
      # Make kube api query to get the daemonset resource and get current requests and limits
      response = KubernetesApiClient.getKubeResourceInfo("omsagent")
      currentResources = getRequestsAndLimits(response)
    elsif (controller.casecmp(@replicaset) == 0)
      # Make kube api query to get the replicaset resource and get current requests and limits
      response = KubernetesApiClient.getKubeResourceInfo("omsagent-rs")
      currentResources = getRequestsAndLimits(response)
    end
    #returning a hash of the current resources
    return currentResources
  rescue => errorStr
    puts "config::error::Exception while getting current resources for the pod, using defaults"
    return nil
  end
end

#Get default resources for controller
def getDefaultResources(controller)
  defaultResources = {}
  if (controller.casecmp(@daemonset) == 0)
    defaultResources["cpuLimits"] = @defaultOmsAgentCpuLimit
    defaultResources["memoryLimits"] = @defaultOmsAgentMemLimit
    defaultResources["cpuRequests"] = @defaultOmsAgentCpuRequest
    defaultResources["memoryRequests"] = @defaultOmsAgentMemRequest
  elsif (controller.casecmp(@replicaset) == 0)
    defaultResources["cpuLimits"] = @defaultOmsAgentRsCpuLimit
    defaultResources["memoryLimits"] = @defaultOmsAgentRsMemLimit
    defaultResources["cpuRequests"] = @defaultOmsAgentRsCpuRequest
    defaultResources["memoryRequests"] = @defaultOmsAgentRsMemRequest
  end
  return defaultResources
end

#Set the resources for daemonset/replicaset
def validateConfigMap(parsedConfig, controller)
  begin
    configMapResources = {}
    if (controller.casecmp(@daemonset) == 0)
      if !parsedConfig[:resource_settings].nil? &&
         !parsedConfig[:resource_settings][:omsagent].nil?
        customCpuLimit = parsedConfig[:resource_settings][:omsagent][:omsAgentCpuLimit]
        customMemoryLimit = parsedConfig[:resource_settings][:omsagent][:omsAgentMemLimit]
        customCpuRequest = parsedConfig[:resource_settings][:omsagent][:omsAgentCpuRequest]
        customMemoryRequest = parsedConfig[:resource_settings][:omsagent][:omsAgentMemRequest]

        #Check to see if the values specified in the config map are valid
        if !customCpuLimit.nil? && customCpuLimit.kind_of?(String) && customCpuLimit.end_with?("m")
          configMapResources["cpuLimits"] = customCpuLimit
          #Todo Add check to check range of values
        else
          configMapResources["cpuLimits"] = @defaultOmsAgentCpuLimit
        end
        if !customMemoryLimit.nil? && customMemoryLimit.kind_of?(String) && (customMemoryLimit.end_with?("Mi") || customMemoryLimit.end_with?("Gi"))
          configMapResources["memoryLimits"] = customMemoryLimit
          #Todo Add check to check range of values
        else
          configMapResources["memoryLimits"] = @defaultOmsAgentMemLimit
        end
        if !customCpuRequest.nil? && customCpuRequest.kind_of?(String) && customCpuRequest.end_with?("m")
          configMapResources["cpuRequests"] = customCpuRequest
          #Todo Add check to check range of values
        else
          configMapResources["cpuRequests"] = @defaultOmsAgentCpuRequest
        end
        if !customMemoryRequest.nil? && customMemoryRequest.kind_of?(String) && (customMemoryLimit.end_with?("Mi") || customMemoryLimit.end_with?("Gi"))
          configMapResources["memoryRequests"] = customMemoryRequest
          #Todo Add check to check range of values
        else
          configMapResources["memoryRequests"] = @defaultOmsAgentMemRequest
        end
      else
        # If config map doesnt exist
        configMapResources = getDefaultResources(controller)
      end
    elsif (controller.casecmp(@replicaset) == 0)
      if !parsedConfig[:resource_settings].nil? &&
         !parsedConfig[:resource_settings][:omsagentrs].nil?
        customCpuLimit = parsedConfig[:resource_settings][:omsagentrs][:omsAgentRsCpuLimit]
        customMemoryLimit = parsedConfig[:resource_settings][:omsagentrs][:omsAgentRsMemLimit]
        customCpuRequest = parsedConfig[:resource_settings][:omsagentrs][:omsAgentRsCpuRequest]
        customMemoryRequest = parsedConfig[:resource_settings][:omsagentrs][:omsAgentRsMemRequest]
        #Todo add setting validation logic

      end
    end
  rescue => errorStr
  end
end

#Parse config map to get the custom settings for cpu and memory resources
configMapSettings = parseConfigMap
if !configMapSettings.nil?
  controller = ENV["CONTROLLER_TYPE"]
  if !controller.nil?
    currentAgentResources = getCurrentResources(controller)
    #puts currentAgentResources
    # setOmsAgentResources(currentAgentResources, configMapSettings, controller)
    validateConfigMap(configMapSettings, controller)
  end
else
  if !controller.nil?
    resourcesToSet = getDefaultResources(controller)
  else
    puts "config::error::Cannot set resources on the pod since the controller type is nil"
  end
end
