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

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    kubeStateMetricsSelector: 'job=~"kube-state-metrics"',

    grafanaUrl: 'https://grafana.com',

    pdbDashboardUid: 'kubernetes-autoscaling-mixin-pdb-jkwq',
    hpaDashboardUid: 'kubernetes-autoscaling-mixin-hpa-jkwq',
    vpaDashboardUid: 'kubernetes-autoscaling-mixin-vpa-jkwq',
    clusterAutoscalerDashboardUid: 'kubernetes-autoscaling-mixin-ca-jkwq',
    karpenterOverviewDashboardUid: 'kubernetes-autoscaling-mixin-kover-jkwq',
    karpenterActivityDashboardUid: 'kubernetes-autoscaling-mixin-kact-jkwq',
    karpenterPerformanceDashboardUid: 'kubernetes-autoscaling-mixin-kperf-jkwq',

    vpa: {
      enabled: true,
    },

    clusterAutoscaler: {
      enabled: true,
      clusterAutoscalerSelector: 'job=~"cluster-autoscaler"',

      nodeCountCapacityThreshold: 75,

      clusterAutoscalerDashboardUrl: '%s/d/%s/kubernetes-autoscaling-cluster-autoscaler' % [this.grafanaUrl, this.clusterAutoscalerDashboardUid],
    },

    karpenter: {
      enabled: true,
      karpenterSelector: 'job=~"karpenter"',

      nodepoolCapacityThreshold: 75,
      nodeclaimTerminationThreshold: 60 * 20,

      karpenterOverviewDashboardUrl: '%s/d/%s/kubernetes-autoscaling-karpenter-overview' % [this.grafanaUrl, this.karpenterOverviewDashboardUid],
      karpenterActivityDashboardUrl: '%s/d/%s/kubernetes-autoscaling-karpenter-activity' % [this.grafanaUrl, this.karpenterActivityDashboardUid],
      karpenterPerformanceDashboardUrl: '%s/d/%s/kubernetes-autoscaling-karpenter-performance' % [this.grafanaUrl, this.karpenterPerformanceDashboardUid],
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
