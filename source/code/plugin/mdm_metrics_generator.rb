#!/usr/local/bin/ruby
# frozen_string_literal: true

class MdmMetricsGenerator
  require "json"
  require_relative "MdmAlertTemplates"

  @@oom_killed_container_count_metric_name = "oomKilledContainerCount"

  def initialize
    @log_path = "/var/opt/microsoft/docker-cimprov/log/filter_inventory2mdm.log"
    @log = Logger.new(@log_path, 1, 5000000)
    @oom_killed_container_count_hash = {}
  end

  class << self
    def appendPodMetrics(records)
      begin
        @oom_killed_container_count_hash.each { |key, value|
          key_elements = key.split("~~")
          if key_elements.length != 2
            next
          end

          # get dimension values by key
          podControllerNameDimValue = key_elements[0]
          podNamespaceDimValue = key_elements[1]

          record = MdmAlertTemplates::oom_killed_container_count_custom_metrics_template % {
            timestamp: batch_time,
            metricName: @@oom_killed_container_count_metric_name,
            controllerNameDimValue: podControllerNameDimValue,
            namespaceDimValue: podNamespaceDimValue,
            containerCountMetricValue: value,
          }
          records.push(JSON.parse(record))
        }
      rescue Exception => e
        @log.info "Error appending pod metrics for metric: #{@@oom_killed_container_count_metric_name} #{e.class} Message: #{e.message}"
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
      end
      @oom_killed_container_count_hash = {}
      return records
    end

    def generatePodMetrics(metricName, podControllerName, podNamespace)
      begin
        # group by distinct dimension values
        dim_key = [podControllerNameDimValue, podNamespaceDimValue].join("~~")
        @oom_killed_container_count_hash[dim_key] = @oom_killed_container_count_hash.key?(dim_key) ? @oom_killed_container_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        puts "Error in generatePodMetrics: #{errorStr}"
      end
    end
  end
end
