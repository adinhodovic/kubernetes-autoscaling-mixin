{
  local clusterVariableQueryString = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s }}' % $._config else '',
  local clusterLabel = { clusterLabel: $._config.clusterLabel },
  prometheusAlerts+:: {
    groups+: std.prune([
      if $._config.karpenter.enabled then {
        local karpenterConfig = $._config.karpenter + clusterLabel,
        name: 'karpenter',
        rules: [
          {
            alert: 'KarpenterCloudProviderErrors',
            expr: |||
              sum(
                increase(
                  karpenter_cloudprovider_errors_total{
                    %(karpenterSelector)s,
                    controller!~"nodeclaim.termination|node.termination",
                    error!="NodeClaimNotFoundError"
                  }[5m]
                )
              ) by (%(clusterLabel)s, namespace, job, provider, controller, method) > 0
            ||| % karpenterConfig,
            labels: {
              severity: 'warning',
            },
            'for': '5m',
            annotations: {
              summary: 'Karpenter has Cloud Provider Errors.',
              description: 'The Karpenter provider {{ $labels.provider }} with the controller {{ $labels.controller }} has errors with the method {{ $labels.method }}.',
              dashboard_url: $._config.karpenter.karpenterPerformanceDashboardUrl + clusterVariableQueryString,
            },
          },
          {
            alert: 'KarpenterNodeClaimsTerminationDurationHigh',
            expr: |||
              sum(
                rate(
                  karpenter_nodeclaims_termination_duration_seconds_sum{
                    %(karpenterSelector)s
                  }[5m]
                )
              ) by (%(clusterLabel)s, namespace, job, nodepool)
              /
              sum(
                rate(
                  karpenter_nodeclaims_termination_duration_seconds_count{
                    %(karpenterSelector)s
                  }[5m]
                )
              ) by (%(clusterLabel)s, namespace, job, nodepool) > %(nodeclaimTerminationThreshold)s
            ||| % karpenterConfig,
            labels: {
              severity: 'warning',
            },
            'for': '15m',
            annotations: {
              summary: 'Karpenter Node Claims Termination Duration is High.',
              description: 'The average node claim termination duration in Karpenter has exceeded %s minutes for more than 15 minutes in nodepool {{ $labels.nodepool }}. This may indicate cloud provider issues or improper instance termination handling.' % std.toString($._config.karpenter.nodeclaimTerminationThreshold / 60),
              dashboard_url: $._config.karpenter.karpenterActivityDashboardUrl + clusterVariableQueryString,
            },
          },
          {
            alert: 'KarpenterNodepoolNearCapacity',
            annotations: {
              summary: 'Karpenter Nodepool near capacity.',
              description: 'The resource {{ $labels.resource_type }} in the Karpenter node pool {{ $labels.nodepool }} is nearing its limit. Consider scaling or adding resources.',
              dashboard_url: $._config.karpenter.karpenterOverviewDashboardUrl + clusterVariableQueryString,
            },
            expr: |||
              sum (
                karpenter_nodepools_usage{%(karpenterSelector)s}
              ) by (%(clusterLabel)s, namespace, job, nodepool, resource_type)
              /
              sum (
                karpenter_nodepools_limit{%(karpenterSelector)s}
              ) by (%(clusterLabel)s, namespace, job, nodepool, resource_type)
              * 100 > %(nodepoolCapacityThreshold)s
            ||| % karpenterConfig,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
      if $._config.clusterAutoscaler.enabled then {
        local clusterAutoscalerConfig = $._config.clusterAutoscaler + clusterLabel,
        name: 'cluster-autoscaler',
        rules: [
          {
            alert: 'ClusterAutoscalerNodeCountNearCapacity',
            annotations: {
              summary: 'Cluster Autoscaler Node Count near Capacity.',
              description: 'The node count for the cluster autoscaler job {{ $labels.job }} is reaching max limit. Consider scaling node groups.',
              dashboard_url: $._config.clusterAutoscaler.clusterAutoscalerDashboardUrl + clusterVariableQueryString,
            },
            expr: |||
              sum (
                cluster_autoscaler_nodes_count{
                  %(clusterAutoscalerSelector)s
                }
              ) by (%(clusterLabel)s, namespace, job)
              /
              sum (
                cluster_autoscaler_max_nodes_count{
                  %(clusterAutoscalerSelector)s
                }
              ) by (%(clusterLabel)s, namespace, job)
              * 100 > %(nodeCountCapacityThreshold)s
            ||| % clusterAutoscalerConfig,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ClusterAutoscalerUnschedulablePods',
            annotations: {
              summary: 'Pods Pending Scheduling - Cluster Node Group Scaling Required',
              description: 'The cluster currently has unschedulable pods, indicating resource shortages. Consider adding more nodes or increasing node group capacity.',
              dashboard_url: $._config.clusterAutoscaler.clusterAutoscalerDashboardUrl + clusterVariableQueryString,
            },
            expr: |||
              sum (
                cluster_autoscaler_unschedulable_pods_count{
                  %(clusterAutoscalerSelector)s
                }
              ) by (%(clusterLabel)s, namespace, job)
              > 0
            ||| % clusterAutoscalerConfig,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
        ] + (
          if $._config.clusterAutoscaler.nodeGroupMetricsEmitted then [
            {
              alert: 'ClusterAutoscalerNodeGroupAtCapacity',
              annotations: {
                summary: 'Cluster Autoscaler Node Group At Capacity',
                description: 'Node group {{ $labels.node_group }} is above %(nodeGroupUtilizationThreshold)d%% expected capacity.' % clusterAutoscalerConfig,
                dashboard_url: $._config.clusterAutoscaler.clusterAutoscalerDashboardUrl + clusterVariableQueryString,
              },
              expr: |||
                (
                  avg (
                    cluster_autoscaler_node_group_target_count{
                      %(clusterAutoscalerSelector)s
                    }
                  ) by (%(clusterLabel)s, namespace, job, node_group) /
                  max (
                    cluster_autoscaler_node_group_max_count{
                      %(clusterAutoscalerSelector)s
                    }
                  ) by (%(clusterLabel)s, namespace, job, node_group)
                  * 100
                ) >= %(nodeGroupUtilizationThreshold)s
              ||| % clusterAutoscalerConfig,
              'for': '15m',
              labels: {
                severity: 'warning',
              },
            },
            {
              alert: 'ClusterAutoscalerAllNodeGroupsAtCapacity',
              annotations: {
                summary: 'All Cluster Autoscaler Node Groups At Capacity',
                description: 'All node groups are above %(nodeGroupUtilizationThreshold)d%% expected capacity.' % clusterAutoscalerConfig,
                dashboard_url: $._config.clusterAutoscaler.clusterAutoscalerDashboardUrl + clusterVariableQueryString,
              },
              expr: |||
                count (
                  (
                    avg (
                      cluster_autoscaler_node_group_target_count{
                        %(clusterAutoscalerSelector)s
                      }
                    ) by (%(clusterLabel)s, namespace, job, node_group) /
                    max (
                      cluster_autoscaler_node_group_max_count{
                        %(clusterAutoscalerSelector)s
                      }
                    ) by (%(clusterLabel)s, namespace, job, node_group)
                    * 100
                  ) < %(nodeGroupUtilizationThreshold)s
                ) by (%(clusterLabel)s, namespace, job) == 0
              ||| % clusterAutoscalerConfig,
              'for': '10m',
              labels: {
                severity: 'critical',
              },
            },
            {
              alert: 'ClusterAutoscalerNodeGroupUnhealthy',
              annotations: {
                summary: 'Cluster Autoscaler Node Group Unhealthy',
                description: 'Node group {{ $labels.node_group }} is unhealthy.',
                dashboard_url: $._config.clusterAutoscaler.clusterAutoscalerDashboardUrl + clusterVariableQueryString,
              },
              expr: |||
                max (
                  cluster_autoscaler_node_group_healthiness{
                    %(clusterAutoscalerSelector)s
                  }
                ) by (%(clusterLabel)s, namespace, job, node_group) == 0
              ||| % clusterAutoscalerConfig,
              'for': '15m',
              labels: {
                severity: 'warning',
              },
            },
            {
              alert: 'ClusterAutoscalerNoHealthyNodeGroups',
              annotations: {
                summary: 'No Healthy Cluster Autoscaler Node Groups',
                description: 'No node groups are healthy.',
                dashboard_url: $._config.clusterAutoscaler.clusterAutoscalerDashboardUrl + clusterVariableQueryString,
              },
              expr: |||
                sum (
                  cluster_autoscaler_node_group_healthiness{
                    %(clusterAutoscalerSelector)s
                  }
                ) by (%(clusterLabel)s, namespace, job) == 0
              ||| % clusterAutoscalerConfig,
              'for': '5m',
              labels: {
                severity: 'critical',
              },
            },
          ] else []
        ),
      },
      if $._config.keda.enabled then {
        local kedaConfig = $._config.keda + clusterLabel,
        name: 'keda',
        rules: [
          {
            alert: 'KedaScaledJobErrors',
            annotations: {
              summary: 'Errors detected for KEDA scaled jobs.',
              description: 'KEDA scaled jobs are experiencing errors. Check the scaled job {{ $labels.scaledObject }} in the namespace {{ $labels.exported_namespace }}.',
              dashboard_url: $._config.keda.kedaScaledJobDashboardUrl + '?var-scaled_job={{ $labels.scaledObject }}&var-resource_namespace={{ $labels.exported_namespace }}' + clusterVariableQueryString,
            },
            expr: |||
              sum(
                increase(
                  keda_scaled_job_errors_total{
                    %(kedaSelector)s
                  }[10m]
                )
              ) by (%(clusterLabel)s, job, exported_namespace, scaledObject) > 0
            ||| % kedaConfig,
            'for': '1m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'KedaScaledObjectErrors',
            annotations: {
              summary: 'Errors detected for KEDA scaled objects.',
              description: 'KEDA scaled objects are experiencing errors. Check the scaled object {{ $labels.scaledObject }} in the namespace {{ $labels.exported_namespace }}.',
              dashboard_url: $._config.keda.kedaScaledObjectDashboardUrl + '?var-scaled_object={{ $labels.scaledObject }}&var-resource_namespace={{ $labels.exported_namespace }}' + clusterVariableQueryString,
            },
            expr: |||
              sum(
                increase(
                  keda_scaled_object_errors_total{
                    %(kedaSelector)s
                  }[10m]
                )
              ) by (%(clusterLabel)s, job, exported_namespace, scaledObject) > 0
            ||| % kedaConfig,
            'for': '1m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'KedaScalerLatencyHigh',
            annotations: {
              summary: 'High latency for KEDA scaler metrics.',
              description: 'Metric latency for scaler {{ $labels.scaler }} for the object {{ $labels.scaledObject }} has exceeded acceptable limits.',
              dashboard_url: $._config.keda.kedaScaledObjectDashboardUrl + '?var-scaled_object={{ $labels.scaledObject }}&var-scaler={{ $labels.scaler }}' + clusterVariableQueryString,
            },
            expr: |||
              avg(
                keda_scaler_metrics_latency_seconds{
                  %(kedaSelector)s
                }
              ) by (%(clusterLabel)s, job, exported_namespace, scaledObject, scaler) > %(scalerMetricsLatencyThreshold)s
            ||| % kedaConfig,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'KedaScaledObjectPaused',
            annotations: {
              summary: 'KEDA scaled object is paused.',
              description: 'The scaled object {{ $labels.scaledObject }} in namespace {{ $labels.exported_namespace }} is paused for longer than %(scaledObjectPausedThreshold)s. This may indicate a configuration issue or manual intervention.' % kedaConfig,
              dashboard_url: $._config.keda.kedaScaledObjectDashboardUrl + '?var-scaled_object={{ $labels.scaledObject }}&var-resource_namespace={{ $labels.exported_namespace }}' + clusterVariableQueryString,
            },
            expr: |||
              max(
                keda_scaled_object_paused{
                  %(kedaSelector)s
                }
              ) by (%(clusterLabel)s, job, exported_namespace, scaledObject) > 0
            ||| % kedaConfig,
            'for': kedaConfig.scaledObjectPausedThreshold,
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'KedaScalerDetailErrors',
            annotations: {
              summary: 'Errors detected in KEDA scaler.',
              description: 'Errors have occurred in the KEDA scaler {{ $labels.scaler }}. Investigate the scaler for the {{ $labels.type }} {{ $labels.scaledObject }} in namespace {{ $labels.exported_namespace }}.',
              dashboard_url: $._config.keda.kedaScaledObjectDashboardUrl + '?var-scaler={{ $labels.scaler }}&var-scaled_object={{ $labels.scaledObject }}' + clusterVariableQueryString,
            },
            expr: |||
              sum(
                increase(
                  keda_scaler_detail_errors_total{
                    %(kedaSelector)s
                  }[10m]
                )
              ) by (%(clusterLabel)s, job, exported_namespace, scaledObject, type, scaler) > 0
            ||| % kedaConfig,
            'for': '1m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ]),
  },
}
