#!/usr/local/bin/ruby
# frozen_string_literal: true

class MdmMetricsGenerator
  require "logger"
  require "json"
  require_relative "MdmAlertTemplates"
  require_relative "ApplicationInsightsUtility"
  require_relative "constants"

  @log_path = "/var/opt/microsoft/docker-cimprov/log/mdm_metrics_generator.log"
  @log = Logger.new(@log_path, 1, 5000000)

  # @@oom_killed_container_count_metric_name = "OomKilledContainerCount"
  # @@container_restart_count_metric_name = "ContainerRestartCount"
  @oom_killed_container_count_hash = {}
  @container_restart_count_hash = {}

  def initialize
  end

  class << self
    # def appendPodMetrics(records, batch_time)
    #   begin
    #     @log.info "in appendPodMetrics..."
    #     @log.info "oom killed container count: #{@oom_killed_container_count_hash.length}"
    #     if !@oom_killed_container_count_hash.empty?
    #       @oom_killed_container_count_hash.each { |key, value|
    #         key_elements = key.split("~~")
    #         if key_elements.length != 2
    #           next
    #         end

    #         # get dimension values by key
    #         podControllerNameDimValue = key_elements[0]
    #         podNamespaceDimValue = key_elements[1]

    #         record = MdmAlertTemplates::Oom_killed_container_count_custom_metrics_template % {
    #           timestamp: batch_time,
    #           metricName: MdmMetrics::OOM_KILLED_CONTAINER_COUNT,
    #           controllerNameDimValue: podControllerNameDimValue,
    #           namespaceDimValue: podNamespaceDimValue,
    #           containerCountMetricValue: value,
    #         }
    #         records.push(JSON.parse(record))
    #       }
    #     else
    #       @log.info "No OOMKilled containers found"
    #     end
    #   rescue => errorStr
    #     @log.info "Error appending pod metrics for metric: #{MdmMetrics::OOM_KILLED_CONTAINER_COUNT} : #{errorStr}"
    #     ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
    #   end
    #   @log.info "Done appending PodMetrics for oom killed containers..."
    #   @oom_killed_container_count_hash = {}
    #   return records
    # end
    
    def appendAllPodMetrics(records, batch_time)
      begin
      @log.info "in appendAllPodMetrics..."
      # @log.info "@oom_killed_container_count_hash: #{@oom_killed_container_count_hash}"
      records = appendPodMetrics(records, Constants::MDM_OOM_KILLED_CONTAINER_COUNT, @oom_killed_container_count_hash, batch_time)
      @oom_killed_container_count_hash = {}
      # @log.info "@container_restart_count_hash: #{@container_restart_count_hash}"
      records = appendPodMetrics(records, Constants::MDM_CONTAINER_RESTART_COUNT, @container_restart_count_hash, batch_time)
      @container_restart_count_hash = {}
      rescue => errorStr
        @log.info "Error in appendAllPodMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def appendPodMetrics(records, metricName, metricHash, batch_time)
      begin
        @log.info "in appendPodMetrics..."
        if !metricHash.empty?
          metricHash.each { |key, value|
            key_elements = key.split("~~")
            if key_elements.length != 2
              next
            end

            # get dimension values by key
            podControllerNameDimValue = key_elements[0]
            podNamespaceDimValue = key_elements[1]

            record = MdmAlertTemplates::Pod_Metrics_custom_metrics_template % {
              timestamp: batch_time,
              metricName: metricName,
              controllerNameDimValue: podControllerNameDimValue,
              namespaceDimValue: podNamespaceDimValue,
              containerCountMetricValue: value,
            }
            records.push(JSON.parse(record))
          }
        else
          @log.info "No records found in hash for metric: #{metricName}"
        end
      rescue => errorStr
        @log.info "Error appending pod metrics for metric: #{metricName} : #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      @log.info "Done appending PodMetrics for metric: #{metricName}..."
      return records
    end

    def generatePodMetrics(metricName, podControllerName, podNamespace, metricValue = 0)
      begin
        @log.info "in generatePodMetrics..."
        # group by distinct dimension values
        dim_key = [podControllerName, podNamespace].join("~~")
        if metricName == Constants::MDM_OOM_KILLED_CONTAINER_COUNT
          @log.info "adding dimension key to oom killed container hash..."
          @oom_killed_container_count_hash[dim_key] = @oom_killed_container_count_hash.key?(dim_key) ? @oom_killed_container_count_hash[dim_key] + 1 : 1
        elsif metricName == Constants::MDM_CONTAINER_RESTART_COUNT
          @log.info "adding dimension key to container restart count hash..."
          @container_restart_count_hash[dim_key] = @container_restart_count_hash.key?(dim_key) ? @container_restart_count_hash[dim_key] + metricValue  : metricValue
          # if !@container_restart_count_hash.key?(dim_key) ? 
          #   @container_restart_count_hash[dim_key] = metricValue
          # end
        end
      rescue => errorStr
        @log.warn "Error in generatePodMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end
end
