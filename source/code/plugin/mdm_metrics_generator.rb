#!/usr/local/bin/ruby
# frozen_string_literal: true

class MdmMetricsGenerator
  require "json"
  require_relative "MdmAlertTemplates"

  @@oom_killed_container_count_metric_name = "oomKilledContainerCount"

  def initialize
    @oom_killed_container_count_hash = {}
  end

  class << self
    def generatePodMetrics(metricName, podControllerName, podNamespace)
      begin
        # group by distinct dimension values
        dim_key = [podControllerNameDimValue, podNamespaceDimValue].join("~~")
        @oom_killed_container_count_hash[dim_key] = @oom_killed_container_count_hash.key?(dim_key) ? @oom_killed_container_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        puts "Error in ConfigParserErrorLogger::logError: #{errorStr}"
      end
    end
  end
end
