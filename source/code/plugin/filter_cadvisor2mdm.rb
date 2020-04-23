# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

module Fluent
  require "logger"
  require "yajl/json_gem"
  require_relative "oms_common"
  require_relative "CustomMetricsUtils"
  require_relative "kubelet_utils"
  require_relative "MdmMetricsGenerator"

  class CAdvisor2MdmFilter < Filter
    Fluent::Plugin.register_filter("filter_cadvisor2mdm", self)

    config_param :enable_log, :integer, :default => 0
    config_param :log_path, :string, :default => "/var/opt/microsoft/docker-cimprov/log/filter_cadvisor2mdm.log"
    config_param :custom_metrics_azure_regions, :string
    config_param :metrics_to_collect, :string, :default => "Constants::CPU_USAGE_NANO_CORES,Constants::MEMORY_WORKING_SET_BYTES,Constants::MEMORY_RSS_BYTES"

    @@hostName = (OMS::Common.get_hostname)

    @process_incoming_stream = true
    @metrics_to_collect_hash = {}

    @@metric_name_threshold_name_hash = {}

    def initialize
      super
    end

    def configure(conf)
      super
      @log = nil

      if @enable_log
        @log = Logger.new(@log_path, 1, 5000000)
        @log.debug { "Starting filter_cadvisor2mdm plugin" }
      end
    end

    def start
      super
      begin
        @process_incoming_stream = CustomMetricsUtils.check_custom_metrics_availability(@custom_metrics_azure_regions)
        @metrics_to_collect_hash = build_metrics_hash
        @log.debug "After check_custom_metrics_availability process_incoming_stream #{@process_incoming_stream}"
        @@containerResourceUtilTelemetryTimeTracker = DateTime.now.to_time.to_i

        # These variables keep track if any resource utilization threshold exceeded in the last 10 minutes
        @cpuThresholdExceeded = false
        @memRssThresholdExceeded = false
        @memWorkingSetThresholdExceeded = false

        # initialize cpu and memory limit
        if @process_incoming_stream
          @cpu_capacity = 0.0
          @memory_capacity = 0.0
          ensure_cpu_memory_capacity_set
          @containerCpuLimitHash = {}
          @containerMemoryLimitHash = {}
          @containerResourceDimensionHash = {}

          # Adding another rescue block here so that failure to get these values dont fail plugin initialization
          begin
            cpuThreshold = ENV["AZMON_MDM_CPU_UTILIZATION_THRESHOLD"]
            if !cpuThreshold.nil? && !cpuThreshold.empty?
              cpuThresholdFloat = cpuThreshold.to_f
              @@metric_name_threshold_name_hash[Constants::CPU_USAGE_NANO_CORES] = cpuThresholdFloat
            else
              @@metric_name_threshold_name_hash[Constants::CPU_USAGE_NANO_CORES] = Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD
            end

            memoryRssThreshold = ENV["AZMON_MDM_MEMORY_RSS_THRESHOLD"]
            if !memoryRssThreshold.nil? && !memoryRssThreshold.empty?
              memoryRssThresholdFloat = memoryRssThreshold.to_f
              @@metric_name_threshold_name_hash[Constants::MEMORY_RSS_BYTES] = memoryRssThresholdFloat
            else
              @@metric_name_threshold_name_hash[Constants::MEMORY_RSS_BYTES] = Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD
            end

            memoryWorkingSetThreshold = ENV["AZMON_MDM_MEMORY_WORKING_SET_THRESHOLD"]
            if !memoryWorkingSetThreshold.nil? && !memoryWorkingSetThreshold.empty?
              memoryWorkingSetThresholdFloat = memoryWorkingSetThreshold.to_f
              @@metric_name_threshold_name_hash[Constants::MEMORY_WORKING_SET_BYTES] = memoryWorkingSetThresholdFloat
            else
              @@metric_name_threshold_name_hash[Constants::MEMORY_WORKING_SET_BYTES] = Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD
            end
          rescue => errorStr
            @log.info "Error getting custom threshold values for resource utilization for mdm metrics, using defaults: #{errorStr}"
            @@metric_name_threshold_name_hash[Constants::CPU_USAGE_NANO_CORES] = Constants::DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD
            @@metric_name_threshold_name_hash[Constants::MEMORY_RSS_BYTES] = Constants::DEFAULT_MDM_MEMORY_RSS_THRESHOLD
            @@metric_name_threshold_name_hash[Constants::MEMORY_WORKING_SET_BYTES] = Constants::DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        end
      rescue => e
        @log.info "Error initializing plugin #{e}"
      end
    end

    def build_metrics_hash
      @log.debug "Building Hash of Metrics to Collect"
      metrics_to_collect_arr = @metrics_to_collect.split(",").map(&:strip)
      metrics_hash = metrics_to_collect_arr.map { |x| [x.downcase, true] }.to_h
      @log.info "Metrics Collected : #{metrics_hash}"
      return metrics_hash
    end

    def shutdown
      super
    end

    def setThresholdExceededTelemetry(metricName)
      begin
        if metricName == Constants::CPU_USAGE_NANO_CORES
          @cpuThresholdExceeded = true
        elsif metricName == Constants::MEMORY_RSS_BYTES
          @memRssThresholdExceeded = true
        elsif metricName == Constants::MEMORY_WORKING_SET_BYTES
          @memWorkingSetThresholdExceeded = true
        end
      rescue => errorStr
        @log.info "Error in setThresholdExceededTelemetry: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def flushMetricTelemetry
      begin
        #Send heartbeat telemetry with threshold percentage as dimensions
        timeDifference = (DateTime.now.to_time.to_i - @@containerResourceUtilTelemetryTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
          properties = {}
          properties["cpuThresholdPercentage"] = @@metric_name_threshold_name_hash[Constants::CPU_USAGE_NANO_CORES]
          properties["memoryRssThresholdPercentage"] = @@metric_name_threshold_name_hash[Constants::MEMORY_RSS_BYTES]
          properties["memoryWorkingSetThresholdPercentage"] = @@metric_name_threshold_name_hash[Constants::MEMORY_WORKING_SET_BYTES]
          properties["cpuThresholdExceededInLastFlushInterval"] = @cpuThresholdExceeded
          properties["memRssThresholdExceededInLastFlushInterval"] = @memRssThresholdExceeded
          properties["memWSetThresholdExceededInLastFlushInterval"] = @memWorkingSetThresholdExceeded
          ApplicationInsightsUtility.sendCustomEvent("ContainerResourceUtilMdmHeartBeatEvent", properties)
          @@containerResourceUtilTelemetryTimeTracker = DateTime.now.to_time.to_i
          @cpuThresholdExceeded = false
          @memRssThresholdExceeded = false
          @memWorkingSetThresholdExceeded = false
        end
      rescue => errorStr
        @log.info "Error in flushMetricTelemetry: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def filter(tag, time, record)
      begin
        if @process_incoming_stream
          object_name = record["DataItems"][0]["ObjectName"]
          counter_name = record["DataItems"][0]["Collections"][0]["CounterName"]
          percentage_metric_value = 0.0
          metric_value = record["DataItems"][0]["Collections"][0]["Value"]

          if object_name == Constants::OBJECT_NAME_K8S_NODE && @metrics_to_collect_hash.key?(counter_name.downcase)
            # Compute and send % CPU and Memory
            if counter_name == Constants::CPU_USAGE_NANO_CORES
              metric_name = Constants::CPU_USAGE_MILLI_CORES
              metric_value /= 1000000 #cadvisor record is in nanocores. Convert to mc
              @log.info "Metric_value: #{metric_value} CPU Capacity #{@cpu_capacity}"
              if @cpu_capacity != 0.0
                percentage_metric_value = (metric_value) * 100 / @cpu_capacity
              end
            end

            if counter_name.start_with?("memory")
              metric_name = counter_name
              if @memory_capacity != 0.0
                percentage_metric_value = metric_value * 100 / @memory_capacity
              end
            end
            # return get_metric_records(record, metric_name, metric_value, percentage_metric_value)
            return MdmMetricsGenerator.getNodeResourceMetricRecords(record, metric_name, metric_value, percentage_metric_value)
          elsif object_name == Constants::OBJECT_NAME_K8S_CONTAINER && @metrics_to_collect_hash.key?(counter_name.downcase)
            instanceName = record["DataItems"][0]["InstanceName"]
            metricName = counter_name
            # Using node cpu capacity in the absence of container cpu capacity since the container will end up using the
            # node's capacity in this case. Converting this to nanocores for computation purposes, since this is in millicores
            containerCpuLimit = @cpu_capacity * 1000000
            containerMemoryLimit = @memory_capacity

            if counter_name == Constants::CPU_USAGE_NANO_CORES
              if !instanceName.nil? && !@containerCpuLimitHash[instanceName].nil?
                containerCpuLimit = @containerCpuLimitHash[instanceName]
              end

              # Checking if KubernetesApiClient ran into error while getting the numeric value or if we failed to get the limit
              if containerCpuLimit != 0
                percentage_metric_value = (metric_value) * 100 / containerCpuLimit
              end
            elsif counter_name.start_with?("memory")
              if !instanceName.nil? && !@containerMemoryLimitHash[instanceName].nil?
                containerMemoryLimit = @containerMemoryLimitHash[instanceName]
              end
              # Checking if KubernetesApiClient ran into error while getting the numeric value or if we failed to get the limit
              if containerMemoryLimit != 0
                percentage_metric_value = (metric_value) * 100 / containerMemoryLimit
              end
            end

            # Send this metric only if resource utilization is greater than configured threshold
            @log.info "percentage_metric_value for metric: #{metricName} for instance: #{instanceName} percentage: #{percentage_metric_value}"
            @log.info "@@metric_name_threshold_name_hash for #{metricName}: #{@@metric_name_threshold_name_hash[metricName]}"
            thresholdPercentage = @@metric_name_threshold_name_hash[metricName]
            if percentage_metric_value > thresholdPercentage
              setThresholdExceededTelemetry(metricName)
              flushMetricTelemetry
              return MdmMetricsGenerator.getContainerResourceUtilMetricRecords(record,
                                                                               metricName,
                                                                               percentage_metric_value,
                                                                               @containerResourceDimensionHash[instanceName],
                                                                               thresholdPercentage)
            else
              return []
            end #end if block for percentage metric > configured threshold % check
          else
            return [] #end if block for object type check
          end
        else
          return []
        end #end if block for process incoming stream check
      rescue Exception => e
        @log.info "Error processing cadvisor record Exception: #{e.class} Message: #{e.message}"
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        return [] #return empty array if we ran into any errors
      end
    end

    def ensure_cpu_memory_capacity_set
      if @cpu_capacity != 0.0 && @memory_capacity != 0.0
        @log.info "CPU And Memory Capacity are already set"
        return
      end

      controller_type = ENV["CONTROLLER_TYPE"]
      if controller_type.downcase == "replicaset"
        @log.info "ensure_cpu_memory_capacity_set @cpu_capacity #{@cpu_capacity} @memory_capacity #{@memory_capacity}"

        begin
          resourceUri = KubernetesApiClient.getNodesResourceUri("nodes?fieldSelector=metadata.name%3D#{@@hostName}")
          nodeInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo(resourceUri).body)
        rescue Exception => e
          @log.info "Error when getting nodeInventory from kube API. Exception: #{e.class} Message: #{e.message} "
          ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        end
        if !nodeInventory.nil?
          cpu_capacity_json = KubernetesApiClient.parseNodeLimits(nodeInventory, "capacity", "cpu", "cpuCapacityNanoCores")
          if !cpu_capacity_json.nil? && !cpu_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"].to_s.nil?
            @cpu_capacity = cpu_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"]
            @log.info "CPU Limit #{@cpu_capacity}"
          else
            @log.info "Error getting cpu_capacity"
          end
          memory_capacity_json = KubernetesApiClient.parseNodeLimits(nodeInventory, "capacity", "memory", "memoryCapacityBytes")
          if !memory_capacity_json.nil? && !memory_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"].to_s.nil?
            @memory_capacity = memory_capacity_json[0]["DataItems"][0]["Collections"][0]["Value"]
            @log.info "Memory Limit #{@memory_capacity}"
          else
            @log.info "Error getting memory_capacity"
          end
        end
      elsif controller_type.downcase == "daemonset"
        capacity_from_kubelet = KubeletUtils.get_node_capacity
        @cpu_capacity = capacity_from_kubelet[0]
        @memory_capacity = capacity_from_kubelet[1]
      end
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      begin
        ensure_cpu_memory_capacity_set
        # Getting container limits hash
        @containerCpuLimitHash, @containerMemoryLimitHash, @containerResourceDimensionHash = KubeletUtils.get_all_container_limits

        es.each { |time, record|
          filtered_records = filter(tag, time, record)
          filtered_records.each { |filtered_record|
            new_es.add(time, filtered_record) if filtered_record
          } if filtered_records
        }
      rescue => e
        @log.info "Error in filter_stream #{e.message}"
      end
      new_es
    end
  end
end
