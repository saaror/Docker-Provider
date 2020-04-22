class MdmAlertTemplates
  Pod_metrics_template = '
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

    Stable_job_metrics_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/pods",
                "dimNames": [
                    "controllerName",
                    "Kubernetes namespace",
                    "thresholdHours"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}",
                        "6"
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
                    "thresholdPercentage"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{containerNameDimValue}",
                        "%{podNameDimValue}",
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}",
                        "%{thresholdPercentageDimValue}"
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

  #Aggregation should be sum
  Api_server_request_errors_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/apiserver",
                        "dimNames": [
                            "errorResponseCode",
                            "errorCategory"
                        ],
                        "series": [
                        {
                            "dimValues": [
                                "%{codevalue}",
                                "%{errorCategoryValue}"
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

  #Aggregation should be sum
  Api_server_request_latencies_metrics_template = '
                       {
                           "time": "%{timestamp}",
                           "data": {
                               "baseData": {
                                   "metric": "%{metricName}",
                                   "namespace": "Insights.Container/apiserver",
                                   "dimNames": [
                                       "verb"
                                   ],
                                   "series": [
                                   {
                                       "dimValues": [
                                           "%{verbValue}"
                                       ],
                                       "min": %{requestLatenciesValue},
                                       "max": %{requestLatenciesValue},
                                       "sum": %{requestLatenciesValue},
                                       "count": 1
                                   }
                                   ]
                               }
                           }
                       }'
end
