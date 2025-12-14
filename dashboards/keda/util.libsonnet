local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    namespace: 'namespace=~"$namespace"',
    scaledObject: 'scaledObject=~"$scaledObject"',
    scaledJob: 'scaledJob=~"$scaledJob"',

    base: '%(cluster)s, %(namespace)s' % this,
    withScaledObject: '%(base)s, %(scaledObject)s' % this,
    withScaledJob: '%(base)s, %(scaledJob)s' % this,
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
      query.new(
        config.clusterLabel,
        'label_values(kube_pod_info{%(kubeStateMetricsSelector)s}, cluster)' % config,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    namespace:
      query.new(
        'namespace',
        'label_values(keda_scaler_errors_total{%(cluster)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledObject:
      query.new(
        'scaledObject',
        'label_values(keda_scaler_errors_total{%(base)s}, scaledObject)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Scaled Object') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledJob:
      query.new(
        'scaledJob',
        'label_values(keda_scaledjob_errors_total{%(base)s}, scaledJob)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Scaled Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
