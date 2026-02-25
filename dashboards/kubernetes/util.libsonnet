local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    clusterMulti: '%(clusterLabel)s=~"$cluster"' % config,
    clusterLabel: config.clusterLabel,
    job: 'job=~"$job"',
    namespace: 'namespace=~"$namespace"',
    container: 'container=~"$container"',

    // PDB
    pdb: 'poddisruptionbudget=~"$poddisruptionbudget"',

    // HPA
    hpa: 'horizontalpodautoscaler=~"$horizontalpodautoscaler"',
    hpaMetricName: 'metric_name=~"$metric_name"',
    hpaMetricTargetType: 'metric_target_type=~"$metric_target_type"',

    // VPA
    vpa: 'verticalpodautoscaler=~"$verticalpodautoscaler"',
    vpaPrefix: config.vpa.vpaPrefix,

    base: |||
      %(cluster)s,
      %(job)s,
      %(namespace)s
    ||| % this,

    baseMulti: |||
      %(clusterMulti)s,
      %(job)s,
      %(namespace)s
    ||| % this,

    // PDB
    withPdb: |||
      %(base)s,
      %(pdb)s
    ||| % this,

    // HPA
    withHpa: |||
      %(base)s,
      %(hpa)s
    ||| % this,

    withHpaMetricName: |||
      %(withHpa)s,
      %(hpaMetricName)s
    ||| % this,

    withHpaMetricTargetType: |||
      %(withHpaMetricName)s,
      %(hpaMetricTargetType)s
    ||| % this,

    // VPA
    withVpa: |||
      %(base)s,
      %(vpa)s,
      %(container)s
    ||| % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new('cluster') +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        config.clusterLabel,
        'kube_pod_info{%(kubeStateMetricsSelector)s}' % config,
      ) +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      query.withSort() +
      query.selectionOptions.withMulti(config.vpa.clusterAggregation) +
      (
        if config.showMultiCluster
        then
          query.generalOptions.showOnDashboard.withLabelAndValue() +
          query.selectionOptions.withMulti(value=config.allowMultiClusterSelection) +
          query.selectionOptions.withIncludeAll(value=config.includeAllValue)
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    // PDB
    pdbJob:
      query.new(
        'job',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    pdbNamespace:
      query.new(
        'namespace',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(cluster)s, %(job)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    pdb:
      query.new(
        'poddisruptionbudget',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(cluster)s, %(job)s, %(namespace)s}, poddisruptionbudget)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Pod Disruption Budget') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    // HPA
    hpaJob:
      query.new(
        'job',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    hpaNamespace:
      query.new(
        'namespace',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(job)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    hpa:
      query.new(
        'horizontalpodautoscaler',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(job)s, %(namespace)s}, horizontalpodautoscaler)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('HPA') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    hpaMetricName:
      query.new(
        'metric_name',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(job)s, %(namespace)s, %(hpa)s}, metric_name)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Metric Name') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    hpaMetricTargetType:
      query.new(
        'metric_target_type',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(job)s, %(namespace)s, %(hpa)s, %(hpaMetricName)s}, metric_target_type)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Metric Target Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    // VPA
    vpaJob:
      query.new(
        'job',
        'label_values(kube_customresource_verticalpodautoscaler_labels{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    vpaNamespace:
      query.new(
        'namespace',
        'label_values(kube_customresource_verticalpodautoscaler_labels{%(cluster)s, %(job)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    vpa:
      query.new(
        'verticalpodautoscaler',
        'label_values(kube_customresource_verticalpodautoscaler_labels{%(cluster)s, %(job)s, %(namespace)s}, verticalpodautoscaler)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Vertical Pod Autoscaler') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    vpaContainer:
      query.new(
        'container',
        'label_values(kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{%(cluster)s, %(job)s, %(namespace)s, %(vpa)s}, container)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Container') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
