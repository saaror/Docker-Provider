# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

module Fluent
  require "logger"
  require "yajl/json_gem"
  require_relative "oms_common"
  # require_relative "CustomMetricsUtils"
  require_relative "kubelet_utils"
  require_relative "MdmMetricsGenerator"

  class Telegraf2MdmFilter < Filter
    Fluent::Plugin.register_filter("filter_telegraf2mdm", self)

    config_param :enable_log, :integer, :default => 0
    config_param :log_path, :string, :default => "/var/opt/microsoft/docker-cimprov/log/filter_telegraf2mdm.log"
    config_param :custom_metrics_azure_regions, :string
    # config_param :metrics_to_collect, :string, :default => "cpuUsageNanoCores,memoryWorkingSetBytes,memoryRssBytes"

    # @@cpu_usage_milli_cores = "cpuUsageMillicores"
    # @@cpu_usage_nano_cores = "cpuusagenanocores"
    # @@object_name_k8s_node = "K8SNode"
    # @@hostName = (OMS::Common.get_hostname)

    @process_incoming_stream = true
    # @metrics_to_collect_hash = {}

    def initialize
      super
    end

    def configure(conf)
      super
      @log = nil

      if @enable_log
        @log = Logger.new(@log_path, 1, 5000000)
        @log.debug { "Starting filter_telegraf2mdm plugin" }
      end
    end

    def start
      super
      begin
        @process_incoming_stream = CustomMetricsUtils.check_custom_metrics_availability(@custom_metrics_azure_regions)
        # @metrics_to_collect_hash = build_metrics_hash
        @log.debug "After check_custom_metrics_availability process_incoming_stream #{@process_incoming_stream}"

        # initialize cpu and memory limit
        if @process_incoming_stream
          # @cpu_capacity = 0.0
          # @memory_capacity = 0.0
          # ensure_cpu_memory_capacity_set
          # @containerCpuLimitHash = {}
          # @containerMemoryLimitHash = {}
          # @containerResourceDimensionHash = {}
        end
      rescue => errorStr
        @log.info "Error initializing plugin #{errorStr}"
      end
    end

    # def build_metrics_hash
    #   @log.debug "Building Hash of Metrics to Collect"
    #   metrics_to_collect_arr = @metrics_to_collect.split(",").map(&:strip)
    #   metrics_hash = metrics_to_collect_arr.map { |x| [x.downcase, true] }.to_h
    #   @log.info "Metrics Collected : #{metrics_hash}"
    #   return metrics_hash
    # end

    def shutdown
      super
    end

    def filter(tag, time, record)
      begin
        # if @process_incoming_stream
        # end #end if block for process incoming stream check
        @log.info "tag: #{tag}, time: #{time}, record: #{record}"
        return []
      rescue Exception => errorStr
        @log.info "Error processing telegraf record Exception: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
        return [] #return empty array if we ran into any errors
      end
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      begin
        # ensure_cpu_memory_capacity_set
        # Getting container limits hash
        # @containerCpuLimitHash, @containerMemoryLimitHash, @containerResourceDimensionHash = KubeletUtils.get_all_container_limits

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
