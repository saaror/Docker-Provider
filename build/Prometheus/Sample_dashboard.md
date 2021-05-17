# Using dashboard in MDM Managaed Proemtheus and Grafana

As part of this private preview you will get default Prometheus dashboards. These are total 19 dashboards
1. K8s mix-ins
    * API-server
    * Cluster compute resources
    * Namespace compute resources(Pods)
    * Namespace compute resources(Workloads)
    * Node compute resources
    * Pod compute resources
    * Workload compute resources
    * Cluster network
    * Workload network
    * Namespace network(Pods)
    * Namespace network(Workloads)
    * Persistent Volume
2. Core-dns
3. Kubelet
4. kube-proxy
5. Node exporter(if installed)
    * Nodes
    * USE Method(Cluster)
    * USE Method(Node)

Here is the [link](https://github.com/Azure/prometheus-collector/tree/main/otelcollector/deploy/dashboard) to the source-code of all the dashboards. These dashboards will be pre-installed in your managed Grafana instance.

# Steps to use these dashboards
1. Once you have set-up the Grafana instance and set-up the data-source. Learn more [here] in case you haven't. 
2. Go to *Search* to see list of all the dashboards 
3. Navigate to the dashboard & you can see all the visualizations.
4. You can filter, view query and modify dashboard just like any Grafana instance.
5. Read below to see how we can modify the dashboard.


# Modify dashboard via Grafana.
As part of Azure Managed Grafana, you will get in-built dashboards.You can query using [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) but there are few limitations that you need be aware of, in case you modify the grafana dashboard
1. Query durations > 14d are blocked.
2. Grafana Template functions
   * `label_values(my_label)` not supported due to cost of the query on MDM storage. Use `label_values(my_metric,my_label)` instead.
3. Case-sensitivity
  * Due to limitations on MDM store(being case in-sensitive), query will do the following.
  * Any specific casing specified in the query for labels & values(non-regex), will be honored by the query service(meaning results returned will have the same casing).
  * For labels and values not specified in the query(including regex based value matchers), query service will return results all in lower case.
   
