#!/usr/local/bin/ruby
# frozen_string_literal: true

require_relative "resource-modifier-helper"

@resourceUpdatePluginPath = "/etc/config/settings/omsagent-resource-set-plugin"

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
    file.write("export AZMON_ENABLE_RESOURCE_SET_PLUGIN=\"true\"\n")
    # Close file after writing all environment variables
    file.close
    puts "config::Successfully created environment variable file to enable plugin"
  end
end

# Parse config map to get new settings for daemonset and replicaset
configMapSettings = ResourceModifierHelper.getConfigMapSettings

#Parse config map to enable/disable plugin to retry set resources on daemonset/replicaset
pluginConfig = ResourceModifierHelper.parseConfigMap(@resourceUpdatePluginPath)
pluginEnabled = false
if !pluginConfig.nil? && !pluginConfig[:enable_plugin].nil? && pluginConfig[:enable_plugin][:enabled] == true
  pluginEnabled = true
end

# Check and update daemonset resources if unset or config map applied
puts "****************Begin Daemonset Resource Config Processing********************"
newResourcesDs = ResourceModifierHelper.validateConfigMapAndGetNewResourcesDs(configMapSettings)

# Get current resource requests and limits for daemonset
responseHashDs, currentAgentResourcesDs, hasResourceKeyDs = ResourceModifierHelper.getCurrentResourcesDs

# Check current daemonset resources and update if its empty or has changed
dsCurrentResNilCheck = ResourceModifierHelper.areAgentResourcesNilOrEmpty(currentAgentResourcesDs)
if !dsCurrentResNilCheck
  # Compare existing and new resources and update if necessary
  updateDs = isUpdateResources(currentAgentResourcesDs, newResourcesDs)
else
  # Current resources are empty
  updateDs = true
end
if !updateDs.nil? && updateDs == true
  puts "config::Current daemonset resources are either empty or different from new resources, updating"
  putResponse = ResourceModifierHelper.updateDsWithNewResources(newResourcesDs, hasResourceKeyDs, responseHashDs)

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
newResourcesRs = ResourceModifierHelper.validateConfigMapAndGetNewResourcesRs(configMapSettings)

# Get current resource requests and limits for replicaset
responseHashRs, currentAgentResourcesRs, hasResourceKeyRs = ResourceModifierHelper.getCurrentResourcesRs

# Check current replicaset resources and update if its empty or has changed
rsCurrentResNilCheck = ResourceModifierHelper.areAgentResourcesNilOrEmpty(currentAgentResourcesRs)
if !rsCurrentResNilCheck
  # Compare existing and new resources and update if necessary
  updateRs = isUpdateResources(currentAgentResourcesRs, newResourcesRs)
else
  # Current resources are empty
  updateRs = true
end
if !updateRs.nil? && updateRs == true
  puts "config::Current replicaset resources are either empty or different from new resources, updating"
  putResponse = ResourceModifierHelper.updateRsWithNewResources(newResourcesRs, hasResourceKeyRs, responseHashRs)
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
