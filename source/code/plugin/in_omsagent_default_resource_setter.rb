#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent
  class Kube_Services_Input < Input
    Plugin.register_input("omsagentdefaultresourcesetter", self)

    def initialize
      super
      # require "json"

      # require_relative "KubernetesApiClient"
      # require_relative "oms_common"
      require_relative "omslog"
      require_relative "ApplicationInsightsUtility"
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

    def enumerate
      $log.info("in_omsagent_default_resource_setter::enumerate : Getting services from Kube API @ #{Time.now.utc.iso8601}")

      resourceSetPluginEnabled = ENV["AZMON_ENABLE_RESOURCE_SET_PLUGIN"]
      if !resourceSetPluginEnabled.nil? && !resourceSetPluginEnabled.empty? && resourceSetPluginEnabled.casecmp("true") == 0
        $log.info("in_omsagent_default_resource_setter: Env variable AZMON_ENABLE_RESOURCE_SET_PLUGIN set to true, checking if resources are set")
        # Parse config map to get new settings for daemonset and replicaset
        configMapSettings = ResourceModifierHelper.getConfigMapSettings

        # Get current resource requests and limits for daemonset
        responseHashDs, currentAgentResourcesDs, hasResourceKeyDs = ResourceModifierHelper.getCurrentResourcesDs
        dsCurrentResNilCheck = ResourceModifierHelper.areAgentResourcesNilOrEmpty(currentAgentResourcesDs)
        if !dsCurrentResNilCheck
          # Compare existing and new resources and update if necessary
          #   updateDs = isUpdateResources(currentAgentResourcesDs, newResourcesDs)
          # else
          #   # Current resources are empty
          #   updateDs = true
          # end
          # if !updateDs.nil? && updateDs == true
          $log.info("One or all of current daemonset resources are empty, updating")
          newResourcesDs = ResourceModifierHelper.validateConfigMapAndGetNewResourcesDs(configMapSettings)
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
      end

      serviceList = JSON.parse(KubernetesApiClient.getKubeResourceInfo("services").body)
      $log.info("in_kube_services::enumerate : Done getting services from Kube API @ #{Time.now.utc.iso8601}")
      begin
        if (!serviceList.empty?)
          eventStream = MultiEventStream.new
          serviceList["items"].each do |items|
            record = {}
            record["CollectionTime"] = batchTime #This is the time that is mapped to become TimeGenerated
            record["ServiceName"] = items["metadata"]["name"]
            record["Namespace"] = items["metadata"]["namespace"]
            record["SelectorLabels"] = [items["spec"]["selector"]]
            record["ClusterId"] = KubernetesApiClient.getClusterId
            record["ClusterName"] = KubernetesApiClient.getClusterName
            record["ClusterIP"] = items["spec"]["clusterIP"]
            record["ServiceType"] = items["spec"]["type"]
            #<TODO> : Add ports and status fields
            wrapper = {
              "DataType" => "KUBE_SERVICES_BLOB",
              "IPName" => "ContainerInsights",
              "DataItems" => [record.each { |k, v| record[k] = v }],
            }
            eventStream.add(emitTime, wrapper) if wrapper
          end
          router.emit_stream(@tag, eventStream) if eventStream
        end
      rescue => errorStr
        $log.debug_backtrace(errorStr.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
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
