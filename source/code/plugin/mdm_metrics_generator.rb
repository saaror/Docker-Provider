#!/usr/local/bin/ruby
# frozen_string_literal: true

class MdmMetricsGenerator
    require "json"
    require_relative "MdmAlertTemplates"

    @@oom_killed_container_count_metric_name = 'oomKilledContainerCount'

    def initialize
    end
  
    class << self
      def generatePodMetrics(metricName, podControllerName, podNamespace)
        begin
          errorMessage = "config::error::" + message
          jsonMessage = errorMessage.to_json
          STDERR.puts jsonMessage
        rescue => errorStr
          puts "Error in ConfigParserErrorLogger::logError: #{errorStr}"
        end
      end
    end
  end
  