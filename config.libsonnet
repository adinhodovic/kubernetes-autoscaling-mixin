local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotation = g.dashboard.annotation;

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

    kubeStateMetricsSelector: 'job=~"kube-state-metrics"',

    grafanaUrl: 'https://grafana.com',

    pdbDashboardUid: 'kubernetes-autoscaling-mixin-pdb-jkwq1',
    hpaDashboardUid: 'kubernetes-autoscaling-mixin-hpa-jkwq1',
    vpaDashboardUid: 'kubernetes-autoscaling-mixin-vpa-jkwq1',
    clusterAutoscalerDashboardUid: 'kubernetes-autoscaling-mixin-ca-jkwq1',
    karpenterOverviewDashboardUid: 'kubernetes-autoscaling-mixin-kover-jkwq1',
    karpenterActivityDashboardUid: 'kubernetes-autoscaling-mixin-kact-jkwq1j',
    karpenterPerformanceDashboardUid: 'kubernetes-autoscaling-mixin-kperf-jkwq1',
    kedaScaledObjectDashboardUid: 'kubernetes-autoscaling-mixin-kedaso-j1',
    kedaScaledJobDashboardUid: 'kubernetes-autoscaling-mixin-kedasj-jkwq1',

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

      clusterAutoscalerDashboardUrl: '%s/d/%s/kubernetes-autoscaling-cluster-autoscaler' % [this.grafanaUrl, this.clusterAutoscalerDashboardUid],
    },

    karpenter: {
      enabled: true,
      karpenterSelector: 'job="karpenter"',

      nodepoolCapacityThreshold: 75,
      nodeclaimTerminationThreshold: 60 * 20,

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
      iconColor: 'green',
      tags: [],
    },

    customAnnotation:: if $._config.annotation.enabled then
      annotation.withName($._config.annotation.name) +
      annotation.withIconColor($._config.annotation.iconColor) +
      annotation.withHide(false) +
      annotation.datasource.withUid($._config.annotation.datasource) +
      annotation.target.withMatchAny(true) +
      annotation.target.withTags($._config.annotation.tags) +
      annotation.target.withType('tags')
    else {},
  },
}
