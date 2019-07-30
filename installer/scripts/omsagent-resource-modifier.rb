#!/usr/local/bin/ruby
# frozen_string_literal: true

require "json"
require_relative "tomlrb"
require_relative "microsoft/omsagent/plugin/KubernetesApiClient"

@cpuMemConfigMapMountPath = "/etc/config/settings/custom-resource-settings"
@resourceUpdatePluginPath = "/etc/config/settings/omsagent-resource-set-plugin"
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

def isUpdateResources(currentAgentResources, newResources)
  begin
    if !newResources.nil?
      puts "config::Checking to see if the new resources are different from current resources"
      # Check to see if any of the resources are not same
      if currentAgentResources["cpuLimits"] == newResources["cpuLimits"] &&
         currentAgentResources["memoryLimits"] == newResources["memoryLimits"] &&
         currentAgentResources["cpuRequests"] == newResources["cpuRequests"] &&
         currentAgentResources["memoryRequests"] == newResources["memoryRequests"]
        return false
      else
        return true
      end
    else
      return false
    end
  rescue => errorStr
    puts "config::error::Exception while comparing resources for daemonset/replicaset: #{errorStr}, skipping resource update"
    return nil
  end
end

def setEnvVariableToEnablePlugin
  #Set environment variable to enable resource set plugin
  file = File.open("enable_resource_set_plugin", "w")
  if !file.nil?
    file.write("export ENABLE_RESOURCE_SET_PLUGIN=true\n")
    # Close file after writing all environment variables
    file.close
    puts "config::Successfully created environment variable file to enable plugin"
  end
end

# Parse config map to get new settings for daemonset and replicaset
configMapSettings = getConfigMapSettings

#Parse config map to enable/disable plugin to retry set resources on daemonset/replicaset
pluginConfig = parseConfigMap(@resourceUpdatePluginPath)
pluginEnabled = false
if !pluginConfig.nil? && !pluginConfig[:enable_plugin].nil? && pluginConfig[:enable_plugin][:enabled] == true
  pluginEnabled = true
end

# Check and update daemonset resources if unset or config map applied
# puts "****************Begin Daemonset Resource Config Processing********************"
newResourcesDs = validateConfigMapAndGetNewResourcesDs(configMapSettings)

# Get current resource requests and limits for daemonset and replicaset
responseHashDs, currentAgentResourcesDs, hasResourceKeyDs = getCurrentResourcesDs

# Check current daemonset resources and update if its empty or has changed
dsCurrentResNilCheck = areAgentResourcesNilOrEmpty(currentAgentResourcesDs)
if !dsCurrentResNilCheck
  # Compare existing and new resources and update if necessary
  updateDs = isUpdateResources(currentAgentResourcesDs, newResourcesDs)
else
  # Current resources are empty
  updateDs = true
end
if !updateDs.nil? && updateDs == true
  puts "config::Current daemonset resources are either empty or different from new resources, updating"
  # # Create hash with new resource values
  # newLimithash = {"cpu" => newResourcesDs["cpuLimits"], "memory" => newResourcesDs["memoryLimits"]}
  # newRequesthash = {"cpu" => newResourcesDs["cpuRequests"], "memory" => newResourcesDs["memoryRequests"]}
  # if hasResourceKeyDs == true
  #   # Update the limits and requests for daemonset
  #   responseHashDs["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"] = newLimithash
  #   responseHashDs["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"] = newRequesthash
  # end
  # # Put request to update daemonset
  # puts responseHashDs.to_json
  # putResponse = KubernetesApiClient.updateOmsagentPod(@daemonset, responseHashDs.to_json)
  putResponse = updateDsWithNewResources(newResourcesDs, hasResourceKeyDs, responseHashDs)

  if !putResponse.nil?
    puts "config::Put request to update daemonset resources was successful, new resource values set on daemonset"
  else
    puts "config::Put request to update daemonset resources failed"
    if dsCurrentResNilCheck == true && pluginEnabled == true
      #Set environment variable for plugin to retry in case of empty resources
      setEnvVariableToEnablePlugin
    end
  end
else
  puts "config::Current daemonset resources are the same as new resources, no update required"
end
puts "****************End Daemonset Resource Config Processing***********************"

puts "****************Begin Replicaset Resource Config Processing********************"
# Check and update replicaset resources if unset or config map applied
# if !configMapSettings.nil?
#   puts "config::config map mounted for custom cpu and memory, using custom settings for replicaset"
#   newResourcesRs = getNewResourcesRs(configMapSettings)
# else
#   puts "config::config map not mounted for custom cpu and memory, using defaults for replicaset"
#   newResourcesRs = getDefaultResourcesRs
# end

newResourcesRs = validateConfigMapAndGetNewResourcesRs(configMapSettings)

# Get current resource requests and limits for daemonset and replicaset
responseHashRs, currentAgentResourcesRs, hasResourceKeyRs = getCurrentResourcesRs

# Check current replicaset resources and update if its empty or has changed
rsCurrentResNilCheck = areAgentResourcesNilOrEmpty(currentAgentResourcesRs)
if !rsCurrentResNilCheck
  # Compare existing and new resources and update if necessary
  updateRs = isUpdateResources(currentAgentResourcesRs, newResourcesRs)
else
  # Current resources are empty
  updateRs = true
end
if !updateRs.nil? && updateRs == true
  puts "config::Current replicaset resources are either empty or different from new resources, updating"
  # Create hash with new resource values
  # newLimithash = {"cpu" => newResourcesRs["cpuLimits"], "memory" => newResourcesRs["memoryLimits"]}
  # newRequesthash = {"cpu" => newResourcesRs["cpuRequests"], "memory" => newResourcesRs["memoryRequests"]}
  # if hasResourceKeyRs == true
  #   # Update the limits and requests for replicaset
  #   responseHashRs["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"] = newLimithash
  #   responseHashRs["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"] = newRequesthash
  # end
  # # Put request to update replicaset
  # putResponse = KubernetesApiClient.updateOmsagentPod(@replicaset, responseHashRs.to_json)
  putResponse = updateRsWithNewResources(newResourcesRs, hasResourceKeyRs, responseHashRs)
  if !putResponse.nil?
    puts "config::Put request to update replicaset resources was successful, new resource values set on replicaset"
  else
    puts "config::Put request to update replicaset resources failed"
    if rsCurrentResNilCheck == true && pluginEnabled == true
      #Set environment variable for plugin to retry in case of empty resources
      setEnvVariableToEnablePlugin
    end
  end
else
  puts "config::Current replicaset resources are the same as new resources, no update required"
end
puts "****************End Replicaset Resource Config Processing********************"
