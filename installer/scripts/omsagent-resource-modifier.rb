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
  currentResources = {}
  omsAgentResource = {}
  hasResourceKey = false
  begin
    if !response.nil? && !response.body.nil? && !response.body.empty?
      omsAgentResource = JSON.parse(response.body)
      if !omsAgentResource.nil? &&
         !omsAgentResource["spec"].nil? &&
         !omsAgentResource["spec"]["template"].nil? &&
         !omsAgentResource["spec"]["template"]["spec"].nil? &&
         !omsAgentResource["spec"]["template"]["spec"]["containers"].nil? &&
         !omsAgentResource["spec"]["template"]["spec"]["containers"][0].nil? &&
         !omsAgentResource["spec"]["template"]["spec"]["containers"][0]["resources"].nil?
        # Setting hasResourceKey to true because we might use this to update the pod later
        hasResourceKey = true
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
  return omsAgentResource, currentResources, hasResourceKey
end

#Get the resources for daemonset
def getCurrentResourcesDs
  begin
    currentResources = {}
    # Make kube api query to get the daemonset resource and get current requests and limits
    response = KubernetesApiClient.getKubeResourceInfo("omsagent")
    responseHash, currentResources = getRequestsAndLimits(response)
    #Return current daemonset resource and a hash of the current resources
    return responseHash, currentResources
  rescue => errorStr
    puts "config::error::Exception while getting current resources for the daemonset: #{errorStr}, using defaults"
    return nil
  end
end

#Get the resources for replicaset
def getCurrentResourcesRs
  begin
    currentResources = {}
    # Make kube api query to get the replicaset resource and get current requests and limits
    response = KubernetesApiClient.getKubeResourceInfo("omsagent-rs")
    responseHash, currentResources = getRequestsAndLimits(response)
    #Return current replicaset resource and a hash of the current resources
    return responseHash, currentResources
  rescue => errorStr
    puts "config::error::Exception while getting current resources for the replicaset : #{errorStr}, using defaults"
    return nil
  end
end

#Get default resources for daemonset
def getDefaultResourcesDs
  defaultResources = {}
  defaultResources["cpuLimits"] = @defaultOmsAgentCpuLimit
  defaultResources["memoryLimits"] = @defaultOmsAgentMemLimit
  defaultResources["cpuRequests"] = @defaultOmsAgentCpuRequest
  defaultResources["memoryRequests"] = @defaultOmsAgentMemRequest
  return defaultResources
end

#Get default resources for replicaset
def getDefaultResourcesRs
  defaultResources = {}
  defaultResources["cpuLimits"] = @defaultOmsAgentRsCpuLimit
  defaultResources["memoryLimits"] = @defaultOmsAgentRsMemLimit
  defaultResources["cpuRequests"] = @defaultOmsAgentRsCpuRequest
  defaultResources["memoryRequests"] = @defaultOmsAgentRsMemRequest
  return defaultResources
end

def isCpuResourceValid(cpuSetting)
  if !cpuSetting.nil? &&
     cpuSetting.kind_of?(String) &&
     cpuSetting.downcase.end_with?("m")
    return true
  else
    return false
  end
end

def isMemoryResourceValid(memorySetting)
  if !memorySetting.nil? &&
     memorySetting.kind_of?(String) &&
     (memorySetting.downcase.end_with?("Mi") ||
      memorySetting.downcase.end_with?("Gi") ||
      memorySetting.downcase.end_with?("Ti"))
    return true
  else
    return false
  end
end

#Set the resources for daemonset/replicaset
def getNewResourcesDs(parsedConfig)
  begin
    configMapResources = {}
    if !parsedConfig[:resource_settings].nil? &&
       !parsedConfig[:resource_settings][:omsagent].nil?
      customCpuLimit = parsedConfig[:resource_settings][:omsagent][:omsAgentCpuLimit]
      customMemoryLimit = parsedConfig[:resource_settings][:omsagent][:omsAgentMemLimit]
      customCpuRequest = parsedConfig[:resource_settings][:omsagent][:omsAgentCpuRequest]
      customMemoryRequest = parsedConfig[:resource_settings][:omsagent][:omsAgentMemRequest]

      #Check to see if the values specified in the config map are valid
      configMapResources["cpuLimits"] = isCpuResourceValid(customCpuLimit) ? customCpuLimit : @defaultOmsAgentCpuLimit
      configMapResources["memoryLimits"] = isMemoryResourceValid(customMemoryLimit) ? customMemoryLimit : @defaultOmsAgentMemLimit
      configMapResources["cpuRequests"] = isCpuResourceValid(customCpuRequest) ? customCpuRequest : @defaultOmsAgentCpuRequest
      configMapResources["memoryRequests"] = isMemoryResourceValid(customMemoryRequest) ? customMemoryRequest : @defaultOmsAgentMemRequest
    else
      # If config map doesnt exist
      configMapResources = getDefaultResourcesDs
    end
    return configMapResources
  rescue => errorStr
    puts "config::error::Exception while getting new resources for the daemonset: #{errorStr}, using defaults"
    return nil
  end
end

def getNewResourcesRs(parsedConfig)
  begin
    configMapResources = {}
    if !parsedConfig[:resource_settings].nil? &&
       !parsedConfig[:resource_settings][:omsagentRs].nil?
      customCpuLimit = parsedConfig[:resource_settings][:omsagentRs][:omsAgentRsCpuLimit]
      customMemoryLimit = parsedConfig[:resource_settings][:omsagentRs][:omsAgentRsMemLimit]
      customCpuRequest = parsedConfig[:resource_settings][:omsagentRs][:omsAgentRsCpuRequest]
      customMemoryRequest = parsedConfig[:resource_settings][:omsagentRs][:omsAgentRsMemRequest]

      #Check to see if the values specified in the config map are valid
      configMapResources["cpuLimits"] = isCpuResourceValid(customCpuLimit) ? customCpuLimit : @defaultOmsAgentRsCpuLimit
      configMapResources["memoryLimits"] = isMemoryResourceValid(customMemoryLimit) ? customMemoryLimit : @defaultOmsAgentRsMemLimit
      configMapResources["cpuRequests"] = isCpuResourceValid(customCpuRequest) ? customCpuRequest : @defaultOmsAgentRsCpuRequest
      configMapResources["memoryRequests"] = isMemoryResourceValid(customMemoryRequest) ? customMemoryRequest : @defaultOmsAgentRsMemRequest
    else
      # If config map doesnt exist
      configMapResources = getDefaultResourcesRs
    end
    return configMapResources
  rescue => errorStr
    puts "config::error::Exception while getting new resources for the replicaset: #{errorStr}, using defaults"
    return nil
  end
end

def updateResources(currentAgentResources, newResources)
  begin
    # Check to see if any of the resources are not same
    if currentAgentResources["cpuLimits"] == newResources["cpuLimits"] &&
       currentAgentResources["memoryLimits"] == newResources["memoryLimits"] &&
       currentAgentResources["cpuRequests"] == newResources["cpuRequests"] &&
       currentAgentResources["memoryRequests"] == newResources["memoryRequests"]
      return false
    else
      return true
    end
  rescue => errorStr
    puts "config::error::Exception while comparing resources for daemonset/replicaset: #{errorStr}, skipping resource update"
    return nil
  end
end

# Parse config map to get new settings for daemonset and replicaset
configMapSettings = parseConfigMap
if !configMapSettings.nil?
  newResourcesDs = getNewResourcesDs(configMapSettings)
  newResourcesRs = getNewResourcesRs(configMapSettings)
else
  newResourcesDs = getDefaultResourcesDs
  newResourcesRs = getDefaultResourcesRs
end

# Get current resource requests and limits for daemonset and replicaset
responseHashDs, currentAgentResourcesDs, hasResourceKeyDs = getCurrentResourcesDs
responseHashRs, currentAgentResourcesRs, hasResourceKeyRs = getCurrentResourcesRs

if !currentAgentResourcesDs.nil?
  if !currentAgentResourcesDs.empty? &&
     !currentAgentResourcesDs["cpuLimits"].nil? &&
     !currentAgentResourcesDs["memoryLimits"].nil? &&
     !currentAgentResourcesDs["cpuRequests"].nil? &&
     currentAgentResourcesDs["memoryRequests"].nil?
    # Compare existing and new resources and update if necessary
    updateDs = updateResources(currentAgentResourcesDs, newResourcesDs)
  else
    # Current resources are empty
    updateDs = true
  end
  if !updateDs.nil? && updateDs == true
    # Create hash with new resource values
    newLimithash = {"cpu" => newResourcesDs["cpuLimits"], "memory" => newResourcesDs["memoryLimits"]}
    newRequesthash = {"cpu" => newResourcesDs["cpuRequests"], "memory" => newResourcesDs["memoryRequests"]}
    if hasResourceKeyDs == true
      # Update the limits and requests for daemonset
      responseHashDs["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"] = newLimithash
      responseHashDs["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"] = newRequesthash
    end
  end
end

if !currentAgentResourcesRs.nil? && !currentAgentResourcesRs.empty?
  if !currentAgentResourcesRs.empty? &&
     !currentAgentResourcesRs["cpuLimits"].nil? &&
     !currentAgentResourcesRs["memoryLimits"].nil? &&
     !currentAgentResourcesRs["cpuRequests"].nil? &&
     currentAgentResourcesRs["memoryRequests"].nil?
    # Compare existing and new resources and update if necessary
    updateRs = updateResources(currentAgentResourcesRs, newResourcesRs)
  else
    # Current resources are empty
    updateRs = true
  end
  if !updateRs.nil? && updateRs == true
    # Create hash with new resource values
    newLimithash = {"cpu" => newResourcesRs["cpuLimits"], "memory" => newResourcesRs["memoryLimits"]}
    newRequesthash = {"cpu" => newResourcesRs["cpuRequests"], "memory" => newResourcesRs["memoryRequests"]}
    if hasResourceKeyRs == true
      # Update the limits and requests for replicaset
      responseHashRs["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"] = newLimithash
      responseHashRs["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"] = newRequesthash
    end
  end
end
