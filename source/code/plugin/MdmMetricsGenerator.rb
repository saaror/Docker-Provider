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
  @stale_job_count_hash = {}
  @pod_ready_hash = {}
  @pod_not_ready_hash = {}
  @pod_ready_percentage_hash = {}

  # Keeping track of metrics for telemetry
  @containerRestartMetricCount = 0
  @oomKilledContainerMetricCount = 0
  @staleJobMetricCount = 0

  @@metric_name_metric_percentage_name_hash = {
    Constants::CPU_USAGE_MILLI_CORES => "cpuUsagePercentage",
    Constants::CPU_USAGE_NANO_CORES => "cpuUsagePercentage",
    Constants::MEMORY_RSS_BYTES => "memoryRssPercentage",
    Constants::MEMORY_WORKING_SET_BYTES => "memoryWorkingSetPercentage",
  }

  def initialize
    @@metricTelemetryTimeTracker = DateTime.now.to_time.to_i
  end

  class << self
    def populatePodReadyPercentageHash
      begin
        @log.info "in populatePodReadyPercentageHash..."
        @pod_ready_hash.each { |dim_key, value|
          podsNotReady = @pod_not_ready_hash.key?(dim_key) ? @pod_not_ready_hash[dim_key] : 0
          totalPods = value + podsNotReady
          podsReadyPercentage = (value / totalPods) * 100
          @pod_ready_percentage_hash[dim_key] = podsReadyPercentage
          # Deleting this key value pair from not ready hash,
          # so that we can get those dimensions for which there are 100% of the pods in not ready state
          if (@pod_not_ready_hash.key?(dim_key))
            @pod_not_ready_hash.delete(dim_key)
          end
        }

        # Add 0% pod ready for these dimensions
        if @pod_not_ready_hash.length > 0
          @pod_not_ready_hash.each { |key, value|
            @pod_ready_percentage_hash[key] = 0
          }
        end

        # Cleaning up hashes after use
        @pod_ready_hash = {}
        @pod_not_ready_hash = {}
      rescue => errorStr
        @log.info "Error in populatePodReadyPercentageHash: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
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

            # Switching templates so that we can add desired dimensions to job metric
            if metricName == Constants::MDM_STALE_COMPLETED_JOB_COUNT
              metricsTemplate = MdmAlertTemplates::Stable_job_metrics_template
            else
              metricsTemplate = MdmAlertTemplates::Pod_metrics_template
            end
            record = metricsTemplate % {
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

    def flushMdmMetricTelemetry
      begin
        properties = {}
        properties["ContainerRestartsSeen"] = (@containerRestartMetricCount.length) > 0 ? true : false
        properties["OomKilledContainersSeen"] = (@oomKilledContainerMetricCount.length) > 0 ? true : false
        properties["StaleJobsSeen"] = (@staleJobMetricCount.length) > 0 ? true : false
        ApplicationInsightsUtility.sendCustomEvent("ContainerMdmMetricsSentEvent", properties)
        ApplicationInsightsUtility.sendCustomEvent("PodReadyPercentageMdmMetricSentEvent", {})
      rescue => errorStr
        @log.info "Error in flushMdmMetricTelemetry: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      @oomKilledContainerMetricCount = 0
      @containerRestartMetricCount = 0
      @staleJobMetricCount = 0
      @metricTelemetryTimeTracker = DateTime.now.to_time.to_i
      @log.info "Mdm metric telemetry successfully flushed"
    end

    def appendAllPodMetrics(records, batch_time)
      begin
        @log.info "in appendAllPodMetrics..."

        #Keeping track of count for telemetry
        @oomKilledContainerMetricCount += @oom_killed_container_count_hash.length
        records = appendPodMetrics(records, Constants::MDM_OOM_KILLED_CONTAINER_COUNT, @oom_killed_container_count_hash, batch_time)
        @oom_killed_container_count_hash = {}

        @containerRestartMetricCount += @container_restart_count_hash.length
        records = appendPodMetrics(records, Constants::MDM_CONTAINER_RESTART_COUNT, @container_restart_count_hash, batch_time)
        @container_restart_count_hash = {}

        @staleJobMetricCount += @stale_job_count_hash.length
        records = appendPodMetrics(records, Constants::MDM_STALE_COMPLETED_JOB_COUNT, @stale_job_count_hash, batch_time)
        @stale_job_count_hash = {}

        # Computer the percentage here, because we need to do this after all chunks have been processed.
        populatePodReadyPercentageHash
        @log.info "@pod_ready_percentage_hash: #{@pod_ready_percentage_hash}"
        records = appendPodMetrics(records, Constants::MDM_POD_READY_PERCENTAGE, @pod_ready_percentage_hash, batch_time)
        @pod_ready_percentage_hash = {}

        timeDifference = (DateTime.now.to_time.to_i - @@metricTelemetryTimeTracker).abs
        timeDifferenceInMinutes = timeDifference / 60
        if (timeDifferenceInMinutes >= Constants::TELEMETRY_FLUSH_INTERVAL_IN_MINUTES)
          flushMdmMetricTelemetry
        end
      rescue => errorStr
        @log.info "Error in appendAllPodMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getContainerResourceUtilMetricRecords(record, metricName, percentageMetricValue, dims, thresholdPercentage)
      records = []
      begin
        dimElements = dims.split("~~")
        if dimElements.length != 4
          return records
        end

        # get dimension values
        containerName = dimElements[0]
        podName = dimElements[1]
        controllerName = dimElements[2]
        podNamespace = dimElements[3]

        resourceUtilRecord = MdmAlertTemplates::Container_resource_utilization_template % {
          timestamp: record["DataItems"][0]["Timestamp"],
          metricName: @@metric_name_metric_percentage_name_hash[metricName],
          containerNameDimValue: containerName,
          podNameDimValue: podName,
          controllerNameDimValue: controllerName,
          namespaceDimValue: podNamespace,
          containerResourceUtilizationPercentage: percentageMetricValue,
          thresholdPercentageDimValue: thresholdPercentage,
        }
        records.push(JSON.parse(resourceUtilRecord))
      rescue => errorStr
        @log.info "Error in getContainerResourceUtilMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getDiskUsageMetricRecords(record)
      records = []
      usedPercent = nil
      deviceName = nil
      hostName = nil
      begin
        @log.info "In getDiskUsageMetricRecords..."
        if !record["fields"].nil?
          usedPercent = record["fields"]["used_percent"]
        end
        if !record["tags"].nil?
          deviceName = record["tags"]["device"]
          hostName = record["tags"]["hostName"]
        end
        timestamp = record["timestamp"]
        convertedTimestamp = Time.at(timestamp.to_i).utc.iso8601
        if !usedPercent.nil? && !deviceName.nil? && !hostName.nil?
          diskUsedPercentageRecord = MdmAlertTemplates::Disk_used_percentage_metrics_template % {
            timestamp: convertedTimestamp,
            metricName: Constants::MDM_DISK_USED_PERCENTAGE,
            hostvalue: hostName,
            devicevalue: deviceName,
            diskUsagePercentageValue: usedPercent,
          }
          records.push(JSON.parse(diskUsedPercentageRecord))
        end
      rescue => errorStr
        @log.info "Error in getDiskUsageMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getNetworkErrorMetricRecords(record)
      records = []
      errIn = nil
      errOut = nil
      interfaceName = nil
      hostName = nil
      begin
        @log.info "In getNetworkErrorMetricRecords..."
        if !record["fields"].nil?
          errIn = record["fields"]["err_in"]
          errOut = record["fields"]["err_out"]
        end
        if !record["tags"].nil?
          hostName = record["tags"]["hostName"]
          interfaceName = record["tags"]["interface"]
        end
        timestamp = record["timestamp"]
        convertedTimestamp = Time.at(timestamp.to_i).utc.iso8601
        if !interfaceName.nil? && !hostName.nil?
          if !errIn.nil?
            networkErrInRecord = MdmAlertTemplates::Network_errors_metrics_template % {
              timestamp: convertedTimestamp,
              metricName: Constants::MDM_NETWORK_ERR_IN,
              hostvalue: hostName,
              interfacevalue: interfaceName,
              networkErrValue: errIn,
            }
            records.push(JSON.parse(networkErrInRecord))
          end
          if !errOut.nil?
            networkErrOutRecord = MdmAlertTemplates::Network_errors_metrics_template % {
              timestamp: convertedTimestamp,
              metricName: Constants::MDM_NETWORK_ERR_OUT,
              hostvalue: hostName,
              interfacevalue: interfaceName,
              networkErrValue: errOut,
            }
            records.push(JSON.parse(networkErrOutRecord))
          end
        end
      rescue => errorStr
        @log.info "Error in getNetworkErrorMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def getApiServerErrorRequestMetricRecords(record)
      errorMetricRecord = nil
      errRequestCount = nil
      errorCode = nil
      errorCodeCategory = nil
      begin
        @log.info "In getApiServerErrorRequestMetricRecords..."
        if !record["fields"].nil?
          errRequestCount = record["fields"][Constants::PROM_API_SERVER_REQ_COUNT]
        end
        if !record["tags"].nil?
          errorCode = record["tags"]["code"]
          if !errorCode.nil?
            if errorCode.start_with?("4")
              errorCodeCategory = Constants::CLIENT_ERROR_CATEGORY
            elsif errorCode.start_with?("5")
              errorCodeCategory = Constants::SERVER_ERROR_CATEGORY
            end
          end
        end
        timestamp = record["timestamp"]
        convertedTimestamp = Time.at(timestamp.to_i).utc.iso8601
        if !errRequestCount.nil? && !errorCode.nil? && !errorCodeCategory.nil?
          apiServerErrMetricRecord = MdmAlertTemplates::Api_server_request_errors_metrics_template % {
            timestamp: convertedTimestamp,
            metricName: Constants::MDM_API_SERVER_ERROR_REQUEST,
            codevalue: errorCode,
            errorCategoryValue: errorCodeCategory,
            requestErrValue: errRequestCount,
          }
          errorMetricRecord = JSON.parse(apiServerErrMetricRecord)
        end
      rescue => errorStr
        @log.info "Error in getApiServerErrorRequestMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return errorMetricRecord
    end

    def getApiServerLatencyMetricRecords(record)
      latencyMetricRecord = nil
      averageLatency = nil
      # resourceName = nil
      verbName = nil
      begin
        fields = record["fields"]
        if !fields.nil?
          latenciesSummarySum = fields[Constants::PROM_API_SERVER_REQ_LATENCIES_SUMMARY_SUM]
          latenciesSummaryCount = fields[Constants::PROM_API_SERVER_REQ_LATENCIES_SUMMARY_COUNT]
          if !latenciesSummarySum.nil? &&
             !latenciesSummaryCount.nil? &&
             latenciesSummaryCount != 0
            averageLatency = latenciesSummarySum / latenciesSummaryCount
            # @log.info "averageLatency: #{averageLatency}, latenciesSummarySum: #{latenciesSummarySum}, latenciesSummaryCount: #{latenciesSummaryCount}"
          end
        end

        if !record["tags"].nil?
          # resourceName = record["tags"]["resource"]
          verbName = record["tags"]["verb"]
        end
        timestamp = record["timestamp"]
        convertedTimestamp = Time.at(timestamp.to_i).utc.iso8601

        if !averageLatency.nil? && !verbName.nil?
          apiServerLatencyMetricRecord = MdmAlertTemplates::Api_server_request_latencies_metrics_template % {
            timestamp: convertedTimestamp,
            metricName: Constants::MDM_API_SERVER_REQUEST_LATENCIES,
            # resourceValue: resourceName,
            verbValue: verbName,
            requestLatenciesValue: averageLatency,
          }
          latencyMetricRecord = JSON.parse(apiServerLatencyMetricRecord)
        end
      rescue => errorStr
        @log.info "Error in getApiServerLatencyMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return latencyMetricRecord
    end

    def getPrometheusMetricRecords(record)
      records = []
      # errRequestCount = nil
      # errorCode = nil
      begin
        if !record["fields"].nil?
          fields = record["fields"]
          if fields.key?(Constants::PROM_API_SERVER_REQ_COUNT)
            # @log.info "in key check PROM_API_SERVER_REQ_COUNT: #{record}"
            errorMetricRecord = getApiServerErrorRequestMetricRecords(record)
            if !errorMetricRecord.nil?
              records.push(errorMetricRecord)
            end
          end
          if fields.key?(Constants::PROM_API_SERVER_REQ_LATENCIES_SUMMARY_SUM) ||
             fields.key?(Constants::PROM_API_SERVER_REQ_LATENCIES_SUMMARY_COUNT)
            #  @log.info "in key check PROM_API_SERVER_REQ_LATENCIES_SUMMARY_SUM: #{record}"
            latencyMetricRecord = getApiServerLatencyMetricRecords(record)
            if !latencyMetricRecord.nil?
              records.push(latencyMetricRecord)
            end
          end
        end
      rescue => errorStr
        @log.info "Error in getPrometheusMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      # @log.info "records being returned: #{records}"
      return records
    end

    def getNodeResourceMetricRecords(record, metric_name, metric_value, percentage_metric_value)
      records = []
      begin
        custommetricrecord = MdmAlertTemplates::Node_resource_metrics_template % {
          timestamp: record["DataItems"][0]["Timestamp"],
          metricName: metric_name,
          hostvalue: record["DataItems"][0]["Host"],
          objectnamevalue: record["DataItems"][0]["ObjectName"],
          instancenamevalue: record["DataItems"][0]["InstanceName"],
          metricminvalue: metric_value,
          metricmaxvalue: metric_value,
          metricsumvalue: metric_value,
        }
        records.push(JSON.parse(custommetricrecord))

        if !percentage_metric_value.nil?
          additional_record = MdmAlertTemplates::Node_resource_metrics_template % {
            timestamp: record["DataItems"][0]["Timestamp"],
            metricName: @@metric_name_metric_percentage_name_hash[metric_name],
            hostvalue: record["DataItems"][0]["Host"],
            objectnamevalue: record["DataItems"][0]["ObjectName"],
            instancenamevalue: record["DataItems"][0]["InstanceName"],
            metricminvalue: percentage_metric_value,
            metricmaxvalue: percentage_metric_value,
            metricsumvalue: percentage_metric_value,
          }
          records.push(JSON.parse(additional_record))
        end
      rescue => errorStr
        @log.info "Error in getNodeResourceMetricRecords: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      return records
    end

    def generateOOMKilledPodMetrics(podControllerName, podNamespace)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to oom killed container hash..."
        @oom_killed_container_count_hash[dim_key] = @oom_killed_container_count_hash.key?(dim_key) ? @oom_killed_container_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generateOOMKilledPodMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def generateContainerRestartsMetrics(podControllerName, podNamespace)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to container restart count hash..."
        @container_restart_count_hash[dim_key] = @container_restart_count_hash.key?(dim_key) ? @container_restart_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generateContainerRestartsMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def generatePodReadyMetrics(podControllerName, podNamespace, podReadyCondition)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to pod ready hash..."
        if podReadyCondition == true
          @pod_ready_hash[dim_key] = @pod_ready_hash.key?(dim_key) ? @pod_ready_hash[dim_key] + 1 : 1
        else
          @pod_not_ready_hash[dim_key] = @pod_not_ready_hash.key?(dim_key) ? @pod_not_ready_hash[dim_key] + 1 : 1
        end
      rescue => errorStr
        @log.warn "Error in generatePodReadyMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def generateStaleJobCountMetrics(podControllerName, podNamespace)
      begin
        dim_key = [podControllerName, podNamespace].join("~~")
        @log.info "adding dimension key to stale job count hash..."
        @stale_job_count_hash[dim_key] = @stale_job_count_hash.key?(dim_key) ? @stale_job_count_hash[dim_key] + 1 : 1
      rescue => errorStr
        @log.warn "Error in generateStaleJobCountMetrics: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end
  end
end
