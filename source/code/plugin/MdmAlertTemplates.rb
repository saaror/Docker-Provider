class MdmAlertTemplates
  Pod_Metrics_custom_metrics_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/pods",
                "dimNames": [
                    "controllerName",
                    "Kubernetes namespace"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}"
                    ],
                    "min": %{containerCountMetricValue},
                    "max": %{containerCountMetricValue},
                    "sum": %{containerCountMetricValue},
                    "count": 1
                }
                ]
            }
        }
    }'

  Container_resource_utilization_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/pods",
                "dimNames": [
                    "containerName",
                    "podName",
                    "controllerName",
                    "Kubernetes namespace",
                    "percentage"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{containerNameDimValue}",
                        "%{podNameDimValue}",
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}",
                        "95"
                    ],
                    "min": %{containerResourceUtilizationPercentage},
                    "max": %{containerResourceUtilizationPercentage},
                    "sum": %{containerResourceUtilizationPercentage},
                    "count": 1
                }
                ]
            }
        }
    }'

  Node_resource_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/nodes",
                        "dimNames": [
                        "host"
                        ],
                        "series": [
                        {
                            "dimValues": [
                            "%{hostvalue}"
                            ],
                            "min": %{metricminvalue},
                            "max": %{metricmaxvalue},
                            "sum": %{metricsumvalue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

  # Aggregation - Sum
  Disk_used_percentage_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/nodes",
                        "dimNames": [
                            "host",
                            "device"
                        ],
                        "series": [
                        {
                            "dimValues": [
                            "%{hostvalue}",
                            "%{devicevalue}"
                            ],
                            "min": %{diskUsagePercentageValue},
                            "max": %{diskUsagePercentageValue},
                            "sum": %{diskUsagePercentageValue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

  Network_errors_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/nodes",
                        "dimNames": [
                            "host",
                            "interface"
                        ],
                        "series": [
                        {
                            "dimValues": [
                                "%{hostvalue}",
                                "%{interfacevalue}"
                            ],
                            "min": %{networkErrValue},
                            "max": %{networkErrValue},
                            "sum": %{networkErrValue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

            Api_server_request_errors_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/apiserver",
                        "dimNames": [
                        ],
                        "series": [
                        {
                            "dimValues": [
                            ],
                            "min": %{requestErrValue},
                            "max": %{requestErrValue},
                            "sum": %{requestErrValue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'


end
