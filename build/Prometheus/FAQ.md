#### Who can use Geneva-MDM backed Prometheus?
We are currently in limited preview with 5 selected customers. We will be opening up preview to more teams in Microsoft. Sign-up here for updates [K8s Observability](https://idwebelements/GroupManagement.aspx?Group=K8sObsUpdates&Operation=join)

#### What are some prerequisite to use Geneva-MDM backed Prometheus?
1. MDM account should in **public cloud** region. We will support all regions soon.
2. Cluster's K8s versions should be > **1.16.x**
3. The MDM certificate should be stored in **Azure key-vault**, we only support Azure key-vault certificate based auth for ingesting metrics into metrics store(UA-MI will be coming soon.

#### I'm already using Azure Monitor container insights, how this is related with Azure Monitor container insights?

1. Azure monitor container insights is a third party solution which provides container logs collection(stdout/stderr) & curated experience in Azure portal. Learn more [here](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview) 
2. Geneva-MDM backed Prometheus runs independently of container insights and collects Prometheus metrics and ingest in MDM account. We have plan to bring this functionality by end of 2021 to Azure monitor container insights.


#### What are some of the limitations that are coming soon?
1. **Recording rules** support on raw Prometheus metrics collected.
2. **Alerting support** on Prometheus metrics.
3. Customizable MDM namespace for Prometheus metrics(currently fixed namespace for all Prom metrics)
4. Querying Prometheus metrics via SDK or KQL-M(currently PromQL only)
5. **Remote write** data from Prometheus server to MDM account.
6. No **up** metric for discovered targets.
7. Prometheus **Operator support**



#### Known issues on data collection side
1. Global external labels are not implemented yet. **Coming soon**
    * Workaround: Use re-labeling to add label(s)
2. For regex grouping, use $$ (instead of $) – This limitation is due to a bug where none of the $’s are escaped **(will be fixed soon)**
3. When config changes, instead of process re-start with SIGHUP, container will restart **(will be fixed soon)**
4. Metrics with Inf values will be dropped(we will address this soon)

#### Known issues on query side
1. Query durations > 14d are blocked
2. Grafana Template functions
    * label_values(my_label) not supported due to cost of the query on MDM storage
        * Use label_values(my_metric, my_label)
3. Case-sensitivity
    * Due to limitations on MDM store (being case in-sensitive), query will do the following –
       * Any specific casing specified in the query for labels & values (non-regex), will be honored by the query service (meaning results returned will have the same casing)
       * For labels & values not specified in the query (including regex based value matchers), query service will return results all in lower case

#### These inbuilt Grafana dashboard have some changes than open-source dashboard: What are those changes?
1. Queries using metrics from recording rules needed to be updated for all Prometheus default dashboards
   * So far, out of the 19 default k8s-Prometheus dashboards, We changed below dashboards which were using recording rules –
      * api-server (1)
      * workloads* (4)
      * node exporter* (3)
      * other k8s mix-ins (3)
2. All mix-in dashboards have cluster-picker hidden, so we had to ‘un-hide’ it
3. Add cluster picker for other dashboards
   * node exporter (3)
   * kube-proxy (1)
   * kube-dns (1)
4. Few Grafana template bugs in existing default dashboards
   * $ variables not substituted properly when they have ip addresses.


#### Unsupported capabilities
1. You cannot query Prometheus metrics via Jarvis, we reccomend customers to use Grafana to access Prometheus metrics.
2. You will not be able to use IFx* libaries for instrumenting Prometheus metrics. For now use Prometheus SDK to instrument your workloads & in future we will support these capabilities in OTel(Open Telemetry SDK).
3. We will not support pre-aggregates & composite metrics in Prometheus metrics.
