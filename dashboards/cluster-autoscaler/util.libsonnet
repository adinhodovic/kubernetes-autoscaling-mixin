local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    job: 'job=~"$job"',

    base: |||
      %(cluster)s,
      %(job)s
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
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    job:
      query.new(
        'job',
        'label_values(cluster_autoscaler_last_activity{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
