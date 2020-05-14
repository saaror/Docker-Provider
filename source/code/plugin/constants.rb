class Constants
    INSIGHTSMETRICS_TAGS_ORIGIN = "container.azm.ms"
    INSIGHTSMETRICS_TAGS_CLUSTERID = "container.azm.ms/clusterId"
    INSIGHTSMETRICS_TAGS_CLUSTERNAME = "container.azm.ms/clusterName"
    INSIGHTSMETRICS_TAGS_GPU_VENDOR = "gpuVendor"
    INSIGHTSMETRICS_TAGS_GPU_NAMESPACE = "container.azm.ms/gpu"
    INSIGHTSMETRICS_TAGS_GPU_MODEL = "gpuModel"
    INSIGHTSMETRICS_TAGS_GPU_ID = "gpuId"
    INSIGHTSMETRICS_TAGS_CONTAINER_NAME = "containerName"
    INSIGHTSMETRICS_TAGS_CONTAINER_ID = "containerName"
    INSIGHTSMETRICS_TAGS_K8SNAMESPACE = "k8sNamespace"
    INSIGHTSMETRICS_TAGS_CONTROLLER_NAME = "controllerName"
    INSIGHTSMETRICS_TAGS_CONTROLLER_KIND = "controllerKind"
    INSIGHTSMETRICS_FLUENT_TAG = "oms.api.InsightsMetrics"
    REASON_OOM_KILLED = "oomkilled"

    # MDM Metric names
    MDM_OOM_KILLED_CONTAINER_COUNT = "oomKilledContainerCount"
    MDM_CONTAINER_RESTART_COUNT = "restartingContainerCount"
    MDM_POD_READY_PERCENTAGE = "podReadyPercentage"
    MDM_STALE_COMPLETED_JOB_COUNT = "completedJobsCount"
    MDM_DISK_USED_PERCENTAGE = "diskUsedPercentage"
    # MDM_NETWORK_ERR_IN = "NetworkErrIn"
    # MDM_NETWORK_ERR_OUT = "NetworkErrOut"
    # MDM_API_SERVER_ERROR_REQUEST = "errorRequestCount"
    # MDM_API_SERVER_REQUEST_LATENCIES = "requestLatency"
    MDM_CONTAINER_CPU_UTILIZATION_METRIC = "cpuExceededPercentage"
    MDM_CONTAINER_MEMORY_RSS_UTILIZATION_METRIC = "memoryRssExceededPercentage"
    MDM_CONTAINER_MEMORY_WORKING_SET_UTILIZATION_METRIC = "memoryWorkingSetExceededPercentage"
    MDM_NODE_CPU_USAGE_PERCENTAGE = "cpuUsagePercentage"
    MDM_NODE_MEMORY_RSS_PERCENTAGE = "memoryRssPercentage"
    MDM_NODE_MEMORY_WORKING_SET_PERCENTAGE = "memoryWorkingSetPercentage"

    CONTAINER_TERMINATED_RECENTLY_IN_MINUTES = 5
    OBJECT_NAME_K8S_CONTAINER = "K8SContainer"
    OBJECT_NAME_K8S_NODE = "K8SNode"
    CPU_USAGE_NANO_CORES = "cpuUsageNanoCores"
    CPU_USAGE_MILLI_CORES = "cpuUsageMillicores"
    MEMORY_WORKING_SET_BYTES= "memoryWorkingSetBytes"
    MEMORY_RSS_BYTES = "memoryRssBytes"
    DEFAULT_MDM_CPU_UTILIZATION_THRESHOLD = 95.0
    DEFAULT_MDM_MEMORY_RSS_THRESHOLD = 95.0
    DEFAULT_MDM_MEMORY_WORKING_SET_THRESHOLD = 95.0
    CONTROLLER_KIND_JOB = "job"
    CONTAINER_TERMINATION_REASON_COMPLETED = "completed"
    CONTAINER_STATE_TERMINATED = "terminated"
    STALE_JOB_TIME_IN_MINUTES = 360
    TELEGRAF_DISK_METRICS = "container.azm.ms/disk"
    # TELEGRAF_NETWORK_METRICS = "container.azm.ms/net"
    # TELEGRAF_PROMETHEUS_METRICS = "container.azm.ms/prometheus"
    # PROM_API_SERVER_REQ_COUNT = "apiserver_request_count"
    # PROM_API_SERVER_REQ_LATENCIES_SUMMARY_SUM = "apiserver_request_latencies_summary_sum"
    # PROM_API_SERVER_REQ_LATENCIES_SUMMARY_COUNT = "apiserver_request_latencies_summary_count"
    # API_SERVER_REQUEST_VERB_GET = "get"
    # API_SERVER_REQUEST_VERB_PUT = "put"
    OMSAGENT_ZERO_FILL = "omsagent"
    KUBESYSTEM_NAMESPACE_ZERO_FILL = "kube-system"


    # CLIENT_ERROR_CATEGORY = "clientErrors(429)"
    # SERVER_ERROR_CATEGORY = "serverErrors(5*)"

    #Telemetry constants
    CONTAINER_METRICS_HEART_BEAT_EVENT = "ContainerMetricsMdmHeartBeatEvent"
    POD_READY_PERCENTAGE_HEART_BEAT_EVENT = "PodReadyPercentageMdmHeartBeatEvent"
    CONTAINER_RESOURCE_UTIL_HEART_BEAT_EVENT = "ContainerResourceUtilMdmHeartBeatEvent"
    # TELEGRAF_METRICS_HEART_BEAT_EVENT = "TelegrafMetricsMdmHeartBeatEvent"
    TELEMETRY_FLUSH_INTERVAL_IN_MINUTES = 10
    MDM_TIME_SERIES_FLUSHED_IN_LAST_HOUR = "MdmTimeSeriesFlushedInLastHour"
end