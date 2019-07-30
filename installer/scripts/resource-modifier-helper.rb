#!/usr/local/bin/ruby
# frozen_string_literal: true

class ResourceModifierHelper
  require "json"
  require_relative "microsoft/omsagent/plugin/KubernetesApiClient"
  require_relative "tomlrb"
  require_relative "microsoft/omsagent/plugin/KubernetesApiClient"

  @replicaset = "replicaset"
  @daemonset = "daemonset"

  def initialize
  end

  class << self
    #Get current requests and limits for daemonset/replicaset
    def getRequestsAndLimits(response)
      currentResources = {}
      omsAgentResource = {}
      hasResourceKey = false
      begin
        if !response.nil? && !response.body.nil? && !response.body.empty?
          puts "config::Parsing requests and limits for the pod"
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
        puts "config::Getting current resources for the daemonset"
        # Make kube api query to get the daemonset resource and get current requests and limits
        response = KubernetesApiClient.getKubeResourceInfo(@daemonset)
        responseHash, currentResources, hasResourceKey = getRequestsAndLimits(response)
        #Return current daemonset resource and a hash of the current resources
        return responseHash, currentResources, hasResourceKey
      rescue => errorStr
        puts "config::error::Exception while getting current resources for the daemonset: #{errorStr}, using defaults"
        return nil
      end
    end

    #Get the resources for replicaset
    def getCurrentResourcesRs
      begin
        currentResources = {}
        puts "config::Getting current resources for the replicaset"
        # Make kube api query to get the replicaset resource and get current requests and limits
        response = KubernetesApiClient.getKubeResourceInfo(@replicaset)
        responseHash, currentResources, hasResourceKey = getRequestsAndLimits(response)
        #Return current replicaset resource and a hash of the current resources
        return responseHash, currentResources, hasResourceKey
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

    #Validate config map settings and get new for daemonset
    def validateConfigMapAndGetNewResourcesDs(parsedConfig)
      begin
        if !parsedConfig.nil?
          puts "config::config map mounted for custom cpu and memory, using custom settings for daemonset"
          configMapResources = {}
          if !parsedConfig[:resource_settings].nil? &&
             !parsedConfig[:resource_settings][:omsagent].nil?
            puts "config::Reading custom settings for omsagent from the config map"
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
            # If config map doesnt contain omsagent key
            puts "config::omsagent key not present in the config map, Using defaults"
            configMapResources = getDefaultResourcesDs
          end
          return configMapResources
        else
          puts "config::config map not mounted for custom cpu and memory, using defaults for daemonset"
          return getDefaultResourcesDs
        end
      rescue => errorStr
        puts "config::error::Exception while getting new resources for the daemonset: #{errorStr}, using defaults"
        return nil
      end
    end

    #Validate config map settings and get new for replicaset
    def validateConfigMapAndGetNewResourcesRs(parsedConfig)
      begin
        if !parsedConfig.nil?
          puts "config::config map mounted for custom cpu and memory, using custom settings for replicaset"
          configMapResources = {}
          if !parsedConfig[:resource_settings].nil? &&
             !parsedConfig[:resource_settings][:omsagentRs].nil?
            puts "config::Reading custom settings for omsagentRs from the config map"
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
            # If config map doesnt contain omsagentRs key
            puts "config::omsagentRs key not present in the config map, Using defaults"
            configMapResources = getDefaultResourcesRs
          end
          return configMapResources
        else
          puts "config::config map not mounted for custom cpu and memory, using defaults for replicaset"
          return getDefaultResourcesRs
        end
      rescue => errorStr
        puts "config::error::Exception while getting new resources for the replicaset: #{errorStr}, using defaults"
        return nil
      end
    end

    # Use parser to parse the configmap toml file to a ruby structure
    def parseConfigMap(filePath)
      begin
        # Check to see if config map is created
        if (File.file?(filePath))
          puts "config::configmap container-azm-ms-agentconfig for settings mounted, parsing values in path #{filePath}"
          parsedConfig = Tomlrb.load_file(filePath, symbolize_keys: true)
          puts "config::Successfully parsed mounted config map"
          return parsedConfig
        else
          puts "config::configmap container-azm-ms-agentconfig for settings in path #{filePath} not mounted, using defaults"
          return nil
        end
      rescue => errorStr
        puts "config::error::Exception while parsing toml config file for file path: #{filePath}: #{errorStr}, using defaults"
        return nil
      end
    end

    def getConfigMapSettings
      # Parse config map to get new settings for daemonset and replicaset
      return parseConfigMap(@cpuMemConfigMapMountPath)
    end

    def updateDsWithNewResources(newResourcesDs, hasResourceKeyDs, responseHashDs)
      putResponse = nil
      begin
        # Create hash with new resource values
        newLimithash = {"cpu" => newResourcesDs["cpuLimits"], "memory" => newResourcesDs["memoryLimits"]}
        newRequesthash = {"cpu" => newResourcesDs["cpuRequests"], "memory" => newResourcesDs["memoryRequests"]}
        if hasResourceKeyDs == true
          # Update the limits and requests for daemonset
          responseHashDs["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"] = newLimithash
          responseHashDs["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"] = newRequesthash
        end
        # Put request to update daemonset
        # puts responseHashDs.to_json
        putResponse = KubernetesApiClient.updateOmsagentPod(@daemonset, responseHashDs.to_json)
      rescue => errorStr
        puts "config::error::Error while updating daemonset with new resource values"
      end
      return putResponse
    end

    def updateRsWithNewResources(newResourcesRs, hasResourceKeyRs, responseHashRs)
      putResponse = nil
      begin
        # Create hash with new resource values
        newLimithash = {"cpu" => newResourcesRs["cpuLimits"], "memory" => newResourcesRs["memoryLimits"]}
        newRequesthash = {"cpu" => newResourcesRs["cpuRequests"], "memory" => newResourcesRs["memoryRequests"]}
        if hasResourceKeyRs == true
          # Update the limits and requests for daemonset
          responseHashRs["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"] = newLimithash
          responseHashRs["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"] = newRequesthash
        end
        # Put request to update daemonset
        # puts responseHashDs.to_json
        putResponse = KubernetesApiClient.updateOmsagentPod(@replicaset, responseHashRs.to_json)
      rescue => errorStr
        puts "config::error::Error while updating replicaset with new resource values"
      end
      return putResponse
    end

    def areAgentResourcesNilOrEmpty(agentResources)
      if !agentResources.nil? &&
         !agentResources.empty? &&
         !agentResources["cpuLimits"].nil? &&
         !agentResources["memoryLimits"].nil? &&
         !agentResources["cpuRequests"].nil? &&
         !agentResources["memoryRequests"].nil?
        return false
      else
        return true
      end
    end
  end
end
