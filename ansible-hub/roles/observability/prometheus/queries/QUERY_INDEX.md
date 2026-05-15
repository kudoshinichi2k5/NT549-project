# PromQL Query Index

This directory decouples PromQL from Grafana JSON dashboards to support:
- easier query maintenance
- RL-Ops data collection
- feature extraction pipelines

Current dashboards still keep inline queries for runtime compatibility.
Future automation can read these `.promql` files and inject/update dashboard targets.

## Directory layout

- `traffic/`: request volume and throughput signals
- `degradation/`: error and latency degradation signals
- `stability/`: health/state/stability signals
- `resources/`: CPU/memory/resource usage signals

## Query catalog

### traffic
- `traffic/app_request_rate_total.promql`
- `traffic/app_request_rate_by_service.promql`
- `traffic/app_request_rate_by_namespace.promql`
- `traffic/app_request_drop_detection_offset_5m.promql`
- `traffic/app_request_per_replica_by_service.promql` `(RL STATE)`
- `traffic/server_rps_api_gateway_1m.promql`
- `traffic/client_rps_k6_http_reqs_1m.promql`
- `traffic/tempo_trace_throughput_spans_rate.promql`
- `traffic/tempo_span_rate_by_service.promql`
- `traffic/tempo_service_graph_request_rate.promql`

### degradation
- `degradation/app_error_rate_by_service.promql` `(RL STATE)`
- `degradation/app_error_spike_by_service_5m.promql`
- `degradation/app_latency_p95_by_service.promql` `(RL STATE)`
- `degradation/app_latency_violation_signal_by_service.promql`
- `degradation/app_sla_violation_ratio_5m.promql` `(RL STATE)`
- `degradation/app_latency_delta_1m_by_service.promql` `(RL REWARD)`
- `degradation/app_error_delta_1m_by_service.promql` `(RL REWARD)`
- `degradation/system_cpu_pressure_ratio.promql`
- `degradation/system_memory_pressure_ratio.promql`
- `degradation/system_crashloopbackoff_by_namespace_pod.promql`
- `degradation/system_deployment_replicas_unavailable.promql`
- `degradation/tempo_error_spans_5m_rate.promql`
- `degradation/tempo_error_span_rate_by_service.promql`
- `degradation/tempo_span_latency_p95_by_service.promql`

### stability
- `stability/app_pod_restart_mini_ecommerce_5m.promql` `(RL STATE - OPTIONAL)`
- `stability/app_pod_churn_5m_by_service.promql` `(RL STATE - OPTIONAL)`
- `stability/app_time_since_last_restart_by_pod.promql`
- `stability/app_deployment_replicas_available.promql`
- `stability/app_deployment_spec_replicas.promql` `(RL STATE)`
- `stability/app_cpu_requests_by_namespace_pod.promql`
- `stability/app_cpu_limits_by_namespace_pod.promql`
- `stability/app_memory_requests_by_namespace_pod.promql`
- `stability/app_memory_limits_by_namespace_pod.promql`
- `stability/system_node_ready_ratio.promql`
- `stability/system_nodes_not_ready.promql`
- `stability/system_pod_restart_by_namespace_pod_5m.promql`
- `stability/system_pods_desired_by_namespace_deployment.promql`
- `stability/system_pods_ready_by_namespace_deployment.promql`
- `stability/system_hpa_desired_replicas_by_namespace.promql`
- `stability/system_hpa_current_replicas_by_namespace.promql`
- `stability/tempo_active_services.promql`
- `stability/tempo_active_service_edges.promql`

### resources
- `resources/app_cpu_usage_by_service_pct.promql`
- `resources/app_memory_usage_by_service_bytes.promql`
- `resources/app_cpu_saturation_by_service_pct.promql` `(RL STATE)`
- `resources/app_memory_saturation_by_service_pct.promql` `(RL STATE)`
- `resources/system_cluster_cpu_utilization_pct.promql`
- `resources/system_cluster_memory_utilization_pct.promql`
- `resources/system_cpu_usage_cluster_avg_pct.promql`
- `resources/system_cpu_usage_namespace_system.promql`
- `resources/system_cpu_usage_namespace_app.promql`
- `resources/system_cpu_usage_namespace_observability.promql`
- `resources/system_cpu_usage_namespace_argocd.promql`
- `resources/system_cpu_usage_per_node_pct.promql`
- `resources/system_cpu_usage_per_pod.promql`
- `resources/system_cpu_usage_per_service_mini_ecommerce.promql`
- `resources/system_memory_usage_namespace_system_gib.promql`
- `resources/system_memory_usage_namespace_app_gib.promql`
- `resources/system_memory_usage_namespace_observability_gib.promql`
- `resources/system_memory_usage_namespace_argocd_gib.promql`
- `resources/system_memory_usage_per_node_gib.promql`
- `resources/system_memory_usage_per_pod.promql`
- `resources/system_memory_usage_per_service_mini_ecommerce_gib.promql`

## Dashboard mapping (current)

### Prometheus - Application Metrics
- `1` Request Rate (RPS): `traffic/app_request_rate_total.promql`
- `2` Request Rate per Service: `traffic/app_request_rate_by_service.promql`
- `3` Request Rate per Namespace: `traffic/app_request_rate_by_namespace.promql`
- `4` Request Drop Detection: `traffic/app_request_drop_detection_offset_5m.promql`
- `5` Error Rate per Service: `degradation/app_error_rate_by_service.promql`
- `6` Error Spike per Service: `degradation/app_error_spike_by_service_5m.promql`
- `7` P95 Latency per Service: `degradation/app_latency_p95_by_service.promql`
- `8` Latency Violation Signal: `degradation/app_latency_violation_signal_by_service.promql`
- `9` Pod Restart: `stability/app_pod_restart_mini_ecommerce_5m.promql`
- `10` CPU Usage by Service: `resources/app_cpu_usage_by_service_pct.promql`
- `11` Memory Usage by Service: `resources/app_memory_usage_by_service_bytes.promql`
- `12` Deployment Replicas Available: `stability/app_deployment_replicas_available.promql`
- `13` Deployment Spec Replicas: `stability/app_deployment_spec_replicas.promql`
- `14` CPU Requests vs Limits: `stability/app_cpu_requests_by_namespace_pod.promql`, `stability/app_cpu_limits_by_namespace_pod.promql`
- `15` Memory Requests vs Limits: `stability/app_memory_requests_by_namespace_pod.promql`, `stability/app_memory_limits_by_namespace_pod.promql`
- `16` Client RPS vs Server RPS: `traffic/server_rps_api_gateway_1m.promql`, `traffic/client_rps_k6_http_reqs_1m.promql`

### Prometheus - System Metrics
- `1` Node Ready Ratio: `stability/system_node_ready_ratio.promql`
- `2` Nodes Not Ready: `stability/system_nodes_not_ready.promql`
- `3` Cluster CPU Utilization: `resources/system_cluster_cpu_utilization_pct.promql`
- `4` Cluster Memory Utilization: `resources/system_cluster_memory_utilization_pct.promql`
- `5` Pod Restart: `stability/system_pod_restart_by_namespace_pod_5m.promql`
- `6` CrashLoopBackOff: `degradation/system_crashloopbackoff_by_namespace_pod.promql`
- `7` Deployment Replicas Unavailable: `degradation/system_deployment_replicas_unavailable.promql`
- `8` CPU Pressure Ratio: `degradation/system_cpu_pressure_ratio.promql`
- `9` Memory Pressure Ratio: `degradation/system_memory_pressure_ratio.promql`
- `10` CPU Usage per Pod: `resources/system_cpu_usage_per_pod.promql`
- `11` Memory Usage per Pod: `resources/system_memory_usage_per_pod.promql`
- `2101` CPU Usage by Namespace: `resources/system_cpu_usage_namespace_*.promql`
- `2102` CPU Usage per Node: `resources/system_cpu_usage_per_node_pct.promql`, `resources/system_cpu_usage_cluster_avg_pct.promql`
- `2103` CPU Usage per Service: `resources/system_cpu_usage_per_service_mini_ecommerce.promql`
- `2111` Memory Usage by Namespace: `resources/system_memory_usage_namespace_*.promql`
- `2112` Memory Usage per Node: `resources/system_memory_usage_per_node_gib.promql`
- `2113` Memory Usage per Service: `resources/system_memory_usage_per_service_mini_ecommerce_gib.promql`
- `2121` Pods Desired vs Ready: `stability/system_pods_desired_by_namespace_deployment.promql`, `stability/system_pods_ready_by_namespace_deployment.promql`
- `2122` HPA Desired vs Current: `stability/system_hpa_desired_replicas_by_namespace.promql`, `stability/system_hpa_current_replicas_by_namespace.promql`

### Tempo - Tracing Overview (PromQL-backed panels)
- `2` Throughput: `traffic/tempo_trace_throughput_spans_rate.promql`
- `3` Error spans: `degradation/tempo_error_spans_5m_rate.promql`
- `4` Active services: `stability/tempo_active_services.promql`
- `5` Active edges: `stability/tempo_active_service_edges.promql`
- `6` Span rate by service: `traffic/tempo_span_rate_by_service.promql`
- `7` Error span rate by service: `degradation/tempo_error_span_rate_by_service.promql`
- `8` P95 latency by service: `degradation/tempo_span_latency_p95_by_service.promql`
- `9` Service graph request rate: `traffic/tempo_service_graph_request_rate.promql`

### RL Self-Healing Observability
- `4001` Request Rate by Service: `traffic/app_request_rate_by_service.promql`
- `4002` Request per Replica by Service: `traffic/app_request_per_replica_by_service.promql` `(RL STATE)`
- `4010` Error Rate by Service: `degradation/app_error_rate_by_service.promql` `(RL STATE)`
- `4011` Latency P95 by Service: `degradation/app_latency_p95_by_service.promql` `(RL STATE)`
- `4012` SLA Violation Ratio: `degradation/app_sla_violation_ratio_5m.promql` `(RL STATE)`
- `4013` Latency Delta 1m by Service: `degradation/app_latency_delta_1m_by_service.promql` `(RL REWARD)`
- `4014` Error Delta 1m by Service: `degradation/app_error_delta_1m_by_service.promql` `(RL REWARD)`
- `4020` CPU Usage by Service: `resources/app_cpu_usage_by_service_pct.promql`
- `4021` Memory Usage by Service: `resources/app_memory_usage_by_service_bytes.promql`
- `4022` CPU Saturation by Service: `resources/app_cpu_saturation_by_service_pct.promql` `(RL STATE)`
- `4023` Memory Saturation by Service: `resources/app_memory_saturation_by_service_pct.promql` `(RL STATE)`
- `4030` Pod Restart by Pod: `stability/app_pod_restart_mini_ecommerce_5m.promql` `(RL STATE - OPTIONAL)`
- `4031` Pod Churn by Service: `stability/app_pod_churn_5m_by_service.promql` `(RL STATE - OPTIONAL)`
- `4032` Replicas Desired vs Available: `stability/app_deployment_spec_replicas.promql`, `stability/app_deployment_replicas_available.promql`
- `4033` Time Since Last Restart by Pod: `stability/app_time_since_last_restart_by_pod.promql`
