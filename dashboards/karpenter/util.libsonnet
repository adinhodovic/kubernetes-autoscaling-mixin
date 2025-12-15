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
    region: 'region=~"$region"',
    zone: 'zone=~"$zone"',
    arch: 'arch=~"$arch"',
    os: 'os=~"$os"',
    instanceType: 'instance_type=~"$instance_type"',
    capacityType: 'capacity_type=~"$capacity_type"',
    nodepool: 'nodepool=~"$nodepool"',

    base: |||
      %(cluster)s,
      %(job)s
    ||| % this,

    default: |||
      %(base)s,
      %(nodepool)s
    ||| % this,

    withLocation: |||
      %(default)s,
      %(region)s,
      %(zone)s
    ||| % this,

    full: |||
      %(withLocation)s,
      %(arch)s,
      %(os)s,
      %(instanceType)s,
      %(capacityType)s
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

    job:
      query.new(
        'job',
        'label_values(karpenter_nodes_allocatable{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    region:
      query.new(
        'region',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s}, region)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Region') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    zone:
      query.new(
        'zone',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s, %(region)s}, zone)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Zone') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    arch:
      query.new(
        'arch',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s, %(region)s, %(zone)s}, arch)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Architecture') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    os:
      query.new(
        'os',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s, %(region)s, %(zone)s, %(arch)s}, os)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Operating System') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    instanceType:
      query.new(
        'instance_type',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s, %(region)s, %(zone)s, %(arch)s, %(os)s}, instance_type)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Instance Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    capacityType:
      query.new(
        'capacity_type',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s, %(region)s, %(zone)s, %(arch)s, %(os)s, %(instanceType)s}, capacity_type)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Capacity Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    nodepool:
      query.new(
        'nodepool',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s, %(region)s, %(zone)s, %(arch)s, %(os)s, %(instanceType)s, %(capacityType)s}, nodepool)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Node Pool') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    nodepoolSimple:
      query.new(
        'nodepool',
        'label_values(karpenter_nodes_allocatable{%(cluster)s, %(job)s}, nodepool)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Node Pool') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
