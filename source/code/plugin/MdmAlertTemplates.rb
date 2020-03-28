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
end