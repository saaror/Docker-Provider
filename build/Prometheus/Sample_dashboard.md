# Using dashboard in MDM Managaed Proemtheus and Grafana

As part of this private preview you will get default Prometheus dashboards. These are total 19 dashboards
1. K8s mix-ins
2. API-server
3. Cluster compute resources
4. Namespace compute resources(Pods)
5. Namespace compute resources(Workloads)
6. Node compute resources
7. Pod compute resources
8. Workload compute resources
9. Cluster network
10. Workload network
11. Namespace network(Pods)
12. Namespace network(Workloads)
13. Persistent Volume
14. Core-dns
15. Kubelet
16. kube-proxy
17. Node exporter(if installed)
18.  Nodes
19.  USE Method(Cluster)
20.  USE Method(Node)

Link to use 

# Modify dashboard via Grafana.
As part of Azure Managed Grafana, you will get in-built dashboards.You can query using [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) but there are few limitations that you need be aware of, in case you modify the grafana dashboard
1. Query durations > 14d are blocked.
2. Grafana Template functions
   * `label_values(my_label)` not supported due to cost of the query on MDM storage. Use `label_values(my_metric,my_label)` instead.
3. Case-sensitivity
  * Due to limitations on MDM store(being case in-sensitive), query will do the following.
  * Any specific casing specified in the query for labels & values(non-regex), will be honored by the query service(meaning results returned will have the same casing).
  * For labels and values not specified in the query(including regex based value matchers), query service will return results all in lower case.
   
