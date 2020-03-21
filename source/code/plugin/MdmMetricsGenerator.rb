#!/usr/local/bin/ruby
# frozen_string_literal: true

class MdmMetricsGenerator
  require "logger"
  require "json"
  require_relative "MdmAlertTemplates"
  require_relative "ApplicationInsightsUtility"

  @log_path = "/var/opt/microsoft/docker-cimprov/log/mdm_metrics_generator.log"
  @log = Logger.new(@log_path, 1, 5000000)

  @@oom_killed_container_count_metric_name = "oomKilledContainerCount"
  @oom_killed_container_count_hash = {}

  def initialize
  end

  class << self
    def appendPodMetrics(records, batch_time)
      begin
        @log.info "in appendPodMetrics..."
        if !@oom_killed_container_count_hash.empty?
          @oom_killed_container_count_hash.each { |key, value|
            key_elements = key.split("~~")
            if key_elements.length != 2
              next
            end

            # get dimension values by key
            podControllerNameDimValue = key_elements[0]
            podNamespaceDimValue = key_elements[1]

            record = MdmAlertTemplates::Oom_killed_container_count_custom_metrics_template % {
              timestamp: batch_time,
              metricName: @@oom_killed_container_count_metric_name,
              controllerNameDimValue: podControllerNameDimValue,
              namespaceDimValue: podNamespaceDimValue,
              containerCountMetricValue: value,
            }
            records.push(JSON.parse(record))
          }
        else
          @log.info "No OOMKilled containers found"
        end
      rescue => errorStr
        @log.info "Error appending pod metrics for metric: #{@@oom_killed_container_count_metric_name} : #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      @log.info "Done appending PodMetrics for oom killed containers..."
      @oom_killed_container_count_hash = {}
      return records
    end

    def generatePodMetrics(metricName, podControllerName, podNamespace)
      begin
        @log.info "in generatePodMetrics..."
        # group by distinct dimension values
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to oom killed container hash..."
        @oom_killed_container_count_hash[dim_key] = @oom_killed_container_count_hash.key?(dim_key) ? @oom_killed_container_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generatePodMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end
end
