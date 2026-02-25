{
  _config+:: {
    local this = self,
    // Bypasses grafana.com/dashboards validator
    bypassDashboardValidation: {
      __inputs: [],
      __requires: [],
    },

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',
    // Allow selecting multiple cluster values?
    multiClusterAllowsMultipleSelection: false,
    // Include the 'all' value in cluster selector?
    multiClusterIncludeAllValue: false,

    kubeStateMetricsSelector: 'job=~"kube-state-metrics"',

    grafanaUrl: 'https://grafana.com',

    pdbDashboardUid: 'kubernetes-autoscaling-mixin-pdb-jkwq',
    hpaDashboardUid: 'kubernetes-autoscaling-mixin-hpa-jkwq',
    vpaDashboardUid: 'kubernetes-autoscaling-mixin-vpa-jkwq',
    clusterAutoscalerDashboardUid: 'kubernetes-autoscaling-mixin-ca-jkwq',
    karpenterOverviewDashboardUid: 'kubernetes-autoscaling-mixin-kover-jkwq',
    karpenterActivityDashboardUid: 'kubernetes-autoscaling-mixin-kact-jkwq',
    karpenterPerformanceDashboardUid: 'kubernetes-autoscaling-mixin-kperf-jkwq',
    kedaScaledObjectDashboardUid: 'kubernetes-autoscaling-mixin-kedaso-jkwq',
    kedaScaledJobDashboardUid: 'kubernetes-autoscaling-mixin-kedasj-jkwq',

    vpa: {
      enabled: true,
      // Optional: If you want to aggregate the VPA by cluster, set it to true requires showMultiCluster to be true.
      clusterAggregation: false,
      // Optional: If your VPA names are not based only from the pod name and include a prefix, set it here.
      vpaPrefix: '',
    },

    clusterAutoscaler: {
      enabled: true,
      clusterAutoscalerSelector: 'job="cluster-autoscaler"',

      nodeCountCapacityThreshold: 75,
      // Enabled alert which uses aggregate cluster metrics that may include nodes not managed by CAS, which can result in false alerting.
      nodeCountNearCapacityEnabled: true,

      // Enable per-node-group metrics for detailed capacity and health monitoring.
      // Requires --emit-per-nodegroup-metrics flag. See: https://github.com/kubernetes/autoscaler/blob/cluster-autoscaler-1.34.2/cluster-autoscaler/FAQ.md?plain=1#L1006
      nodeGroupMetricsEmitted: true,
      nodeGroupUtilizationThreshold: 95,

      clusterAutoscalerDashboardUrl: '%s/d/%s/kubernetes-autoscaling-cluster-autoscaler' % [this.grafanaUrl, this.clusterAutoscalerDashboardUid],
    },

    karpenter: {
      enabled: true,
      karpenterSelector: 'job="karpenter"',

      nodepoolCapacityThreshold: 75,
      nodeclaimTerminationThreshold: 60 * 20,
      schedulerQueueDepthThreshold: 50,

      karpenterOverviewDashboardUrl: '%s/d/%s/kubernetes-autoscaling-karpenter-overview' % [this.grafanaUrl, this.karpenterOverviewDashboardUid],
      karpenterActivityDashboardUrl: '%s/d/%s/kubernetes-autoscaling-karpenter-activity' % [this.grafanaUrl, this.karpenterActivityDashboardUid],
      karpenterPerformanceDashboardUrl: '%s/d/%s/kubernetes-autoscaling-karpenter-performance' % [this.grafanaUrl, this.karpenterPerformanceDashboardUid],
    },

    keda: {
      enabled: true,

      kedaScaledObjectDashboardUrl: '%s/d/%s/kubernetes-autoscaling-keda-scaled-object' % [this.grafanaUrl, this.kedaScaledObjectDashboardUid],
      kedaScaledJobDashboardUrl: '%s/d/%s/kubernetes-autoscaling-keda-scaled-job' % [this.grafanaUrl, this.kedaScaledJobDashboardUid],

      kedaSelector: 'job="keda-operator"',

      // Default thresholds for KEDA the scaler metrics latency threshold in seconds.
      scalerMetricsLatencyThreshold: '5',
      // The default threshold for scaled objects to be considered paused for too long.
      scaledObjectPausedThreshold: '25h',

      // Used to link to the workload dashboard from the scaled job dashboards. Allows viewing resource usage.
      k8sResourcesWorkloadDashboardUid: 'this-needs-to-be-customized',
    },

    tags: ['kubernetes', 'autoscaling', 'kubernetes-autoscaling-mixin'],

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      datasource: '-- Grafana --',
      iconColor: 'blue',
      tags: [],
      type: 'tags',
    },
  },
}
