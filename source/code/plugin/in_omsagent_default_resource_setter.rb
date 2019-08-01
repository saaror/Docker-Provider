#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
  class Omsagent_Default_Resource_Setter_Input < Input
    Plugin.register_input("omsagentdefaultresourcesetter", self)

    def initialize
      super
      # require "json"

      # require_relative "KubernetesApiClient"
      # require_relative "oms_common"
      require_relative "omslog"
      require_relative "ApplicationInsightsUtility"
      require_relative "/opt/resource-modifier-helper"
    end

    config_param :run_interval, :time, :default => "1m"
    # config_param :tag, :string, :default => "oms.containerinsights.KubeServices"

    def configure(conf)
      super
    end

    def start
      if @run_interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    def updateResources
      begin
        $log.info("in_omsagent_default_resource_setter::enumerate : Getting services from Kube API @ #{Time.now.utc.iso8601}")

        resourceSetPluginEnabled = ENV["AZMON_ENABLE_RESOURCE_SET_PLUGIN"]
        # if !resourceSetPluginEnabled.nil? && !resourceSetPluginEnabled.empty? && resourceSetPluginEnabled.casecmp("true") == 0
        $log.info("in_omsagent_default_resource_setter: Env variable AZMON_ENABLE_RESOURCE_SET_PLUGIN set to true")

        # Parse config map to get new settings for daemonset and replicaset
        configMapSettings = ResourceModifierHelper.getConfigMapSettings

        # Get current resource requests and limits for daemonset
        $log.info("in_omsagent_default_resource_setter:Checking daemonset resources")
        responseHashDs, currentAgentResourcesDs, hasResourceKeyDs = ResourceModifierHelper.getCurrentResourcesDs
        dsCurrentResNilCheck = ResourceModifierHelper.areAgentResourcesNilOrEmpty(currentAgentResourcesDs)

        #Delete
        # $log.info("in_omsagent_default_resource_setter:currentAgentResourcesDs: #{currentAgentResourcesDs}")
        # $log.info("in_omsagent_default_resource_setter:hasResourceKeyDs: #{hasResourceKeyDs}")
        # $log.info("in_omsagent_default_resource_setter:dsCurrentResNilCheck: #{dsCurrentResNilCheck}")
        #Delete

        # Trigger update only if current daemonset resources are empty
        if dsCurrentResNilCheck
          $log.info("in_omsagent_default_resource_setter:One or all of current daemonset resources are empty, updating")
          newResourcesDs = ResourceModifierHelper.validateConfigMapAndGetNewResourcesDs(configMapSettings)
          putResponse = ResourceModifierHelper.updateDsWithNewResources(newResourcesDs, hasResourceKeyDs, responseHashDs)

          if !putResponse.nil?
            $log.info("in_omsagent_default_resource_setter:Put request to update daemonset resources was successful, new resource values set on daemonset")
          else
            $log.info("in_omsagent_default_resource_setter:Put request to update daemonset resources failed")
          end
        else
          $log.info("in_omsagent_default_resource_setter:Daemonset resources not empty, skipping daemonset update")
        end

        # Get current resource requests and limits for replicaset
        $log.info("in_omsagent_default_resource_setter:Checking replicaset resources")
        responseHashRs, currentAgentResourcesRs, hasResourceKeyRs = ResourceModifierHelper.getCurrentResourcesRs
        rsCurrentResNilCheck = ResourceModifierHelper.areAgentResourcesNilOrEmpty(currentAgentResourcesRs)

        # Trigger update only if current replicaset resources are empty
        if rsCurrentResNilCheck
          $log.info("in_omsagent_default_resource_setter:One or all of current replicaset resources are empty, updating")
          newResourcesRs = ResourceModifierHelper.validateConfigMapAndGetNewResourcesRs(configMapSettings)
          putResponse = ResourceModifierHelper.updateRsWithNewResources(newResourcesRs, hasResourceKeyRs, responseHashRs)

          if !putResponse.nil?
            $log.info("in_omsagent_default_resource_setter:Put request to update replicaset resources was successful, new resource values set on replicaset")
          else
            $log.info("in_omsagent_default_resource_setter:Put request to update replicaset resources failed")
          end
        else
          $log.info("in_omsagent_default_resource_setter:Replicaset resources not empty, skipping replicaset update")
        end
        # else
        #   $log.info("in_omsagent_default_resource_setter: Env variable AZMON_ENABLE_RESOURCE_SET_PLUGIN not set or set to false, skipping plugin run")
        # end
      rescue => errorStr
        $log.warn("in_omsagent_default_resource_setter::updateResources:error : #{errorStr}")
      end
    end

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @run_interval)
        done = @finished
        @mutex.unlock
        if !done
          begin
            $log.info("in_omsagent_default_resource_setter::run_periodic @ #{Time.now.utc.iso8601}")
            updateResources
          rescue => errorStr
            $log.warn "in_omsagent_default_resource_setter::run_periodic: updateResources failed: #{errorStr}"
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end
  end # omsagent_default_resource_setter End
end # module
