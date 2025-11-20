local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

local statPanel = g.panel.stat;
local timeSeriesPanel = g.panel.timeSeries;
local tablePanel = g.panel.table;
local pieChartPanel = g.panel.pieChart;

// Stat
local stOptions = statPanel.options;
local stStandardOptions = statPanel.standardOptions;
local stQueryOptions = statPanel.queryOptions;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

// Table
local tbOptions = tablePanel.options;
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbFieldConfig = tablePanel.fieldConfig;
local tbOverride = tbStandardOptions.override;

// Pie Chart
local pieOptions = pieChartPanel.options;
local pieQueryOptions = pieChartPanel.queryOptions;

{
  grafanaDashboards+:: std.prune({

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: $._config.datasourceName,
          value: $._config.datasourceName,
        },
      },

    local clusterVariable =
      query.new(
        $._config.clusterLabel,
        'label_values(kube_pod_info{%(kubeStateMetricsSelector)s}, cluster)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      (
        if $._config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    local jobVariable =
      query.new(
        'job',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster"}, job)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local regionVariable =
      query.new(
        'region',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job"}, region)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort() +
      query.generalOptions.withLabel('Region') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local zoneVariable =
      query.new(
        'zone',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job", region=~"$region"}, zone)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort() +
      query.generalOptions.withLabel('Zone') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local archVariable =
      query.new(
        'arch',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job", region=~"$region", zone=~"$zone"}, arch)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort() +
      query.generalOptions.withLabel('Architecture') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local osVariable =
      query.new(
        'os',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job", region=~"$region", zone=~"$zone", arch=~"$arch"}, os)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Operating System') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local instanceTypeVariable =
      query.new(
        'instance_type',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job", region=~"$region", zone=~"$zone", arch=~"$arch", os=~"$os"}, instance_type)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Instance Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local capacityTypeVariable =
      query.new(
        'capacity_type',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job", region=~"$region", zone=~"$zone", arch=~"$arch", os=~"$os", instance_type=~"$instance_type"}, capacity_type)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Capacity Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local nodePoolVariable =
      query.new(
        'nodepool',
        'label_values(karpenter_nodes_allocatable{%(clusterLabel)s="$cluster", job=~"$job", region=~"$region", zone=~"$zone", arch=~"$arch", os=~"$os", instance_type=~"$instance_type", capacity_type=~"$capacity_type"}, nodepool)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Node Pool') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      clusterVariable,
      jobVariable,
      regionVariable,
      zoneVariable,
      archVariable,
      osVariable,
      instanceTypeVariable,
      capacityTypeVariable,
      nodePoolVariable,
    ],

    local karpenterClusterCpuAllocatableQuery = |||
      sum(
        karpenter_nodepools_usage{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          nodepool=~"$nodepool",
          resource_type="cpu"
        }
      )
    ||| % $._config,

    local karpenterClusterCpuUtilizationTimeSeriesPanel =
      timeSeriesPanel.new(
        'Cluster CPU Utilization',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterClusterCpuAllocatableQuery,
          ) +
          prometheus.withLegendFormat(
            'Allocatable'
          ),
          prometheus.new(
            '$datasource',
            karpenterPodCpuRequestsQuery,
          ) +
          prometheus.withLegendFormat(
            'Requested'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Last *') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterClusterMemoryAllocatableQuery = std.strReplace(karpenterClusterCpuAllocatableQuery, 'cpu', 'memory'),

    local karpenterClusterMemoryUtilizationTimeSeriesPanel =
      timeSeriesPanel.new(
        'Cluster Memory Utilization',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterClusterMemoryAllocatableQuery,
          ) +
          prometheus.withLegendFormat(
            'Allocatable'
          ),
          prometheus.new(
            '$datasource',
            karpenterPodMemoryRequestsQuery,
          ) +
          prometheus.withLegendFormat(
            'Requested'
          ),
        ]
      ) +
      stStandardOptions.withUnit('bytes') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Last *') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterNodePoolsUtilizationByNodePoolQuery = |||
      sum(
        karpenter_nodepools_usage{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          nodepool=~"$nodepool",
        }
      ) by (nodepool, resource_type)
      /
      sum(
        karpenter_nodepools_limit{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          nodepool=~"$nodepool",
        }
      ) by (nodepool, resource_type) * 100
    ||| % $._config,

    local karpenterNodePoolsUtilizationTimeSeriesPanel =
      timeSeriesPanel.new(
        'Node Pool Usage % of Limit',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodePoolsUtilizationByNodePoolQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ nodepool }} / {{ resource_type }}'
          ),
        ]
      ) +
      stStandardOptions.withUnit('percent') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Last *') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterNodePoolsQuery = |||
      count(
        count(
          karpenter_nodepools_limit{
            %(clusterLabel)s="$cluster",
            job=~"$job",
          }
        ) by (nodepool)
      )
    ||| % $._config,

    local karpenterNodePoolsStatPanel =
      statPanel.new(
        'Node Pools',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodePoolsQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterNodesCountQuery = |||
      count(
        count(
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        ) by (node_name)
      )
    ||| % $._config,

    local karpenterNodesCountStatPanel =
      statPanel.new(
        'Nodes',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesCountQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterNodePoolCpuUsageQuery = |||
      sum(
        karpenter_nodepools_usage{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          nodepool=~"$nodepool",
          resource_type="cpu"
        }
      )
    ||| % $._config,

    local karpenterNodePoolCpuUsageStatPanel =
      statPanel.new(
        'Node Pool CPU Usage',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodePoolCpuUsageQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterNodePoolMemoryUsageQuery = std.strReplace(karpenterNodePoolCpuUsageQuery, 'cpu', 'memory'),

    local karpenterNodePoolMemoryUsageStatPanel =
      statPanel.new(
        'Node Pool Memory Usage',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodePoolMemoryUsageQuery,
        )
      ) +
      stStandardOptions.withUnit('bytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterNodePoolCpuLimitsQuery = std.strReplace(karpenterNodePoolCpuUsageQuery, 'usage', 'limit'),

    local karpenterNodePoolCpuLimitsStatPanel =
      statPanel.new(
        'Node Pool CPU Limits',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodePoolCpuLimitsQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterNodePoolMemoryLimitsQuery = std.strReplace(karpenterNodePoolMemoryUsageQuery, 'usage', 'limit'),

    local karpenterNodePoolMemoryLimitsStatPanel =
      statPanel.new(
        'Node Pool Memory Limits',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodePoolMemoryLimitsQuery,
        )
      ) +
      stStandardOptions.withUnit('bytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterNodesByNodePoolQuery = |||
      count by (nodepool) (
        count by (node_name, nodepool) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByNodePoolPieChartPanel =
      pieChartPanel.new(
        'Nodes by Node Pool'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByNodePoolQuery,
        ) +
        prometheus.withLegendFormat('{{ nodepool }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterNodesByInstanceTypeQuery = |||
      count by (instance_type) (
        count by (node_name, instance_type) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByInstanceTypePieChartPanel =
      pieChartPanel.new(
        'Nodes by Instance Type'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByInstanceTypeQuery,
        ) +
        prometheus.withLegendFormat('{{ instance_type }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterNodesByCapacityTypeQuery = |||
      count by (capacity_type) (
        count by (node_name, capacity_type) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByCapacityTypePieChartPanel =
      pieChartPanel.new(
        'Nodes by Capacity Type'  // Title of the pie chart
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByCapacityTypeQuery,
        ) +
        prometheus.withLegendFormat('{{ capacity_type }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterNodesByRegionQuery = |||
      count by (region) (
        count by (node_name, region) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByRegionPieChartPanel =
      pieChartPanel.new(
        'Nodes by Region'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByRegionQuery,
        ) +
        prometheus.withLegendFormat('{{ region }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterNodesByZoneQuery = |||
      count by (zone) (
        count by (node_name, zone) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            nodepool=~"$nodepool",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByZonePieChartPanel =
      pieChartPanel.new(
        'Nodes by Zone'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByZoneQuery,
        ) +
        prometheus.withLegendFormat('{{ zone }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterNodesByArchQuery = |||
      count by (arch) (
        count by (node_name, arch) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            nodepool=~"$nodepool",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByArchPieChartPanel =
      pieChartPanel.new(
        'Nodes by Arch'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByArchQuery,
        ) +
        prometheus.withLegendFormat('{{ arch }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterNodesByOSQuery = |||
      count by (os) (
        count by (node_name, os) (
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        )
      )
    ||| % $._config,

    local karpenterNodesByOSPieChartPanel =
      pieChartPanel.new(
        'Nodes by OS'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterNodesByOSQuery,
        ) +
        prometheus.withLegendFormat('{{ os }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),


    local karpenterPodCpuRequestsQuery = |||
      sum(
        karpenter_nodes_total_pod_requests{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          resource_type="cpu",
          region=~"$region",
          zone=~"$zone",
          arch=~"$arch",
          os=~"$os",
          instance_type=~"$instance_type",
          capacity_type=~"$capacity_type",
          nodepool=~"$nodepool"
        }
      ) +
      sum(
        karpenter_nodes_total_daemon_requests{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          resource_type="cpu",
          region=~"$region",
          zone=~"$zone",
          arch=~"$arch",
          os=~"$os",
          instance_type=~"$instance_type",
          capacity_type=~"$capacity_type",
          nodepool=~"$nodepool"
        }
      )
    ||| % $._config,

    local karpenterPodCpuRequestsStatPanel =
      statPanel.new(
        'Pod CPU Requests',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodCpuRequestsQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterPodMemoryRequestsQuery = std.strReplace(karpenterPodCpuRequestsQuery, 'cpu', 'memory'),

    local karpenterPodMemoryRequestsStatPanel =
      statPanel.new(
        'Pod Memory Requests',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodMemoryRequestsQuery,
        )
      ) +
      stStandardOptions.withUnit('bytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterPodCpuLimitsQuery = std.strReplace(karpenterPodCpuRequestsQuery, 'requests', 'limits'),

    local karpetnerPodCpuLimitsStatPanel =
      statPanel.new(
        'Pod CPU Limits',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodCpuLimitsQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterPodMemoryLimitsQuery = std.strReplace(karpenterPodMemoryRequestsQuery, 'requests', 'limits'),

    local karpenterPodMemoryLimitsStatPanel =
      statPanel.new(
        'Pod Memory Limits',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodMemoryLimitsQuery,
        )
      ) +
      stStandardOptions.withUnit('bytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local karpenterPodsByNodePoolQuery = |||
      sum(
          karpenter_pods_state{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            nodepool=~"$nodepool"
          }
      ) by (nodepool)
    ||| % $._config,

    local karpenterPodsByNodePoolPieChartPanel =
      pieChartPanel.new(
        'Pods by Node Pool'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodsByNodePoolQuery,
        ) +
        prometheus.withLegendFormat('{{ nodepool }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterPodsByInstanceTypeQuery = std.strReplace(karpenterPodsByNodePoolQuery, '(nodepool)', '(instance_type)'),

    local karpenterPodsByInstanceTypePieChartPanel =
      pieChartPanel.new(
        'Pods by Instance Type'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodsByInstanceTypeQuery,
        ) +
        prometheus.withLegendFormat('{{ instance_type }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterPodsByCapacityTypeQuery = std.strReplace(karpenterPodsByNodePoolQuery, '(nodepool)', '(capacity_type)'),

    local karpenterPodsByCapacityTypePieChartPanel =
      pieChartPanel.new(
        'Pods by Capacity Type'
      ) +
      pieQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterPodsByCapacityTypeQuery,
        ) +
        prometheus.withLegendFormat('{{ capacity_type }}') +
        prometheus.withInstant(true)
      ) +
      pieOptions.withPieType('pie') +
      pieOptions.legend.withAsTable(true) +
      pieOptions.legend.withPlacement('right') +
      pieOptions.legend.withDisplayMode('table') +
      pieOptions.legend.withValues(['value', 'percent']) +
      pieOptions.legend.withSortDesc(true),

    local karpenterTCpuNodePoolUsageQuery = |||
      sum(
        karpenter_nodepools_usage{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          nodepool=~"$nodepool",
          resource_type="cpu"
        }
      ) by (job, namespace, nodepool)
    ||| % $._config,

    local karpenterTMemoryNodePoolUsageQuery = std.strReplace(karpenterTCpuNodePoolUsageQuery, 'cpu', 'memory'),
    local karpenterTNodesByNodePoolUsageQuery = std.strReplace(karpenterTCpuNodePoolUsageQuery, 'cpu', 'nodes'),
    local karpenterTPodsByNodePoolUsageQuery = std.strReplace(karpenterTCpuNodePoolUsageQuery, 'cpu', 'pods'),
    local karpenterTEphemeralStorageByNodePoolUsageQuery = std.strReplace(karpenterTCpuNodePoolUsageQuery, 'cpu', 'ephemeral_storage'),

    local karpenterTCpuNodePoolAllocatedQuery = std.strReplace(karpenterTCpuNodePoolUsageQuery, 'nodepools_usage', 'nodes_allocatable'),
    local karpenterTMemoryNodePoolAllocatedQuery = std.strReplace(karpenterTCpuNodePoolAllocatedQuery, 'cpu', 'memory'),

    local karpenterTCpuNodePoolLimitQuery = std.strReplace(karpenterTCpuNodePoolUsageQuery, 'usage', 'limit'),
    local karpenterTMemoryNodePoolLimitQuery = std.strReplace(karpenterTMemoryNodePoolUsageQuery, 'usage', 'limit'),
    local karpenterTNodesByNodePoolLimitQuery = std.strReplace(karpenterTNodesByNodePoolUsageQuery, 'usage', 'limit'),
    local karpenterTPodsByNodePoolLimitQuery = std.strReplace(karpenterTPodsByNodePoolUsageQuery, 'usage', 'limit'),
    local karpenterTEphemeralStorageByNodePoolLimitQuery = std.strReplace(karpenterTEphemeralStorageByNodePoolUsageQuery, 'usage', 'limit'),

    local karpenterNodePoolTable =
      tablePanel.new(
        'Node Pools'
      ) +
      tbStandardOptions.withUnit('short') +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Node Pool')
      ) +
      tbOptions.footer.withEnablePagination(true) +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterTCpuNodePoolUsageQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTCpuNodePoolAllocatedQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTCpuNodePoolLimitQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTMemoryNodePoolUsageQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTMemoryNodePoolAllocatedQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTMemoryNodePoolLimitQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTNodesByNodePoolUsageQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTNodesByNodePoolLimitQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTPodsByNodePoolUsageQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTPodsByNodePoolLimitQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTEphemeralStorageByNodePoolUsageQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTEphemeralStorageByNodePoolLimitQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
        ]
      ) +
      tbQueryOptions.withTransformations([
        tbQueryOptions.transformation.withId(
          'merge'
        ),
        tbQueryOptions.transformation.withId(
          'organize'
        ) +
        tbQueryOptions.transformation.withOptions(
          {
            renameByName: {
              namespace: 'Namespace',
              nodepool: 'Node Pool',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Allocated',
              'Value #C': 'CPU Limit',
              'Value #D': 'Memory Usage',
              'Value #E': 'Memory Allocated',
              'Value #F': 'Memory Limit',
              'Value #G': 'Nodes Count',
              'Value #H': 'Nodes Limit',
              'Value #I': 'Max Pods Count',
              'Value #J': 'Max Pods Limit',
              'Value #K': 'Storage Usage',
              'Value #L': 'Storage Limit',
            },
            indexByName: {
              namespace: 0,
              nodepool: 1,
              'Value #A': 2,
              'Value #B': 3,
              'Value #C': 4,
              'Value #D': 5,
              'Value #E': 6,
              'Value #F': 7,
              'Value #G': 8,
              'Value #H': 9,
              'Value #I': 10,
              'Value #J': 11,
              'Value #K': 12,
              'Value #L': 13,
            },
            excludeByName: {
              Time: true,
              job: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('Memory Usage') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('bytes')
        ),
        tbOverride.byName.new('Memory Allocated') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('bytes')
        ),
        tbOverride.byName.new('Memory Limit') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('bytes')
        ),
        tbOverride.byName.new('Storage Usage') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('bytes')
        ),
        tbOverride.byName.new('Storage Limit') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('bytes')
        ),
      ]),

    local inclusionList = [
      'node_name',
      'nodepool',
      'instance_type',
      'instance_memory',
      'instance_cpu',
      'instance_network_bandwidth',
      'region',
      'zone',
      'os',
      'capacity_type',
      'arch',
    ],
    local inclusionListStr = std.join(', ', inclusionList),

    local karpenterTNodeCpuUtilizationQuery = |||
      (
        (
          sum(
            karpenter_nodes_total_pod_requests{
              %(clusterLabel)s="$cluster",
              job=~"$job",
              resource_type="cpu",
              region=~"$region",
              zone=~"$zone",
              arch=~"$arch",
              os=~"$os",
              instance_type=~"$instance_type",
              capacity_type=~"$capacity_type",
              nodepool=~"$nodepool"
            }
          ) by (%(inclusionListStr)s)
          +
          sum(
            karpenter_nodes_total_daemon_requests{
              %(clusterLabel)s="$cluster",
              job=~"$job",
              resource_type="cpu",
              region=~"$region",
              zone=~"$zone",
              arch=~"$arch",
              os=~"$os",
              instance_type=~"$instance_type",
              capacity_type=~"$capacity_type",
              nodepool=~"$nodepool"
            }
          ) by (%(inclusionListStr)s)
        ) /
        sum(
          karpenter_nodes_allocatable{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            resource_type="cpu",
            region=~"$region",
            zone=~"$zone",
            arch=~"$arch",
            os=~"$os",
            instance_type=~"$instance_type",
            capacity_type=~"$capacity_type",
            nodepool=~"$nodepool"
          }
        ) by (%(inclusionListStr)s)
      ) * 100
    ||| % ($._config { inclusionListStr: inclusionListStr }),

    local karpenterTNodeMemoryUtilizationQuery = std.strReplace(karpenterTNodeCpuUtilizationQuery, 'cpu', 'memory'),

    local karpenterNodeTable =
      tablePanel.new(
        'Nodes'
      ) +
      tbStandardOptions.withUnit('short') +
      tbOptions.footer.withEnablePagination(true) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('CPU Utilization') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterTNodeCpuUtilizationQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            karpenterTNodeMemoryUtilizationQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
        ]
      ) +
      tbQueryOptions.withTransformations([
        tbQueryOptions.transformation.withId(
          'merge'
        ),
        tbQueryOptions.transformation.withId(
          'organize'
        ) +
        tbQueryOptions.transformation.withOptions(
          {
            renameByName: {
              namespace: 'Namespace',
              node_name: 'Node Name',
              nodepool: 'Node Pool',
              arch: 'Architecture',
              capacity_type: 'Capacity Type',
              instance_type: 'Instance Type',
              instance_memory: 'Instance Memory',
              instance_cpu: 'Instance CPU',
              instance_network_bandwidth: 'Instance Network Bandwidth',
              region: 'Region',
              zone: 'Zone',
              os: 'OS',
              'Value #A': 'CPU Utilization',
              'Value #B': 'Memory Utilization',
            },
            indexByName: {
              namespace: 0,
              node_name: 1,
              nodepool: 2,
              instance_type: 3,
              instance_cpu: 4,
              instance_memory: 5,
              'Value #A': 6,
              'Value #B': 7,
            },
            excludeByName: {
              Time: true,
              job: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('CPU Utilization') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('percent') +
          tbStandardOptions.withMax(100) +
          tbStandardOptions.thresholds.withMode('percentage') +
          tbStandardOptions.thresholds.withSteps([
            tbStandardOptions.threshold.step.withValue(0) +
            tbStandardOptions.threshold.step.withColor('green'),
            tbStandardOptions.threshold.step.withValue(33) +
            tbStandardOptions.threshold.step.withColor('yellow'),
            tbStandardOptions.threshold.step.withValue(66) +
            tbStandardOptions.threshold.step.withColor('red'),
          ]) +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withType()
        ),
        tbOverride.byName.new('Memory Utilization') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('percent') +
          tbStandardOptions.withMax(100) +
          tbStandardOptions.thresholds.withMode('percentage') +
          tbStandardOptions.thresholds.withSteps([
            tbStandardOptions.threshold.step.withValue(0) +
            tbStandardOptions.threshold.step.withColor('green'),
            tbStandardOptions.threshold.step.withValue(33) +
            tbStandardOptions.threshold.step.withColor('yellow'),
            tbStandardOptions.threshold.step.withValue(66) +
            tbStandardOptions.threshold.step.withColor('red'),
          ]) +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withType()
        ),
        tbOverride.byName.new('Instance Memory') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('decmbytes')
        ),
      ]),

    local karpenterClusterSummaryRow =
      row.new(
        title='Cluster Summary',
      ),

    local karpenterNodePoolSummaryRow =
      row.new(
        title='Node Pool Summary',
      ),

    local karpenterPodSummaryRow =
      row.new(
        title='Pod Summary',
      ),

    local karpenterNodePoolsRow =
      row.new(
        title='Node Pools',
      ),

    local karpenterNodesRow =
      row.new(
        title='Nodes',
      ),

    'kubernetes-autoscaling-mixin-karpenter-over.json': if $._config.karpenter.enabled then
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Karpenter / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Karpenter and focuses on giving a overview for Karpenter. It is created using the [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).') +
      dashboard.withUid($._config.karpenterOverviewDashboardUid) +
      dashboard.withTags($._config.tags + ['karpenter']) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-24h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        [
          dashboard.link.dashboards.new('Kubernetes / Autoscaling', $._config.tags) +
          dashboard.link.link.options.withTargetBlank(true) +
          dashboard.link.link.options.withAsDropdown(true) +
          dashboard.link.link.options.withIncludeVars(true) +
          dashboard.link.link.options.withKeepTime(true),
        ]
      ) +
      dashboard.withPanels(
        [
          karpenterClusterSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterClusterCpuUtilizationTimeSeriesPanel,
            karpenterClusterMemoryUtilizationTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=5,
          startY=1
        ) +
        [
          karpenterNodePoolSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(6) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterNodePoolsStatPanel,
            karpenterNodesCountStatPanel,
            karpenterNodePoolCpuUsageStatPanel,
            karpenterNodePoolMemoryUsageStatPanel,
            karpenterNodePoolCpuLimitsStatPanel,
            karpenterNodePoolMemoryLimitsStatPanel,
          ],
          panelWidth=4,
          panelHeight=3,
          startY=7
        ) +
        grid.makeGrid(
          [
            karpenterNodePoolsUtilizationTimeSeriesPanel,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=10
        ) +
        grid.makeGrid(
          [
            karpenterNodesByNodePoolPieChartPanel,
            karpenterNodesByInstanceTypePieChartPanel,
            karpenterNodesByCapacityTypePieChartPanel,
          ],
          panelWidth=8,
          panelHeight=5,
          startY=18
        ) +
        grid.makeGrid(
          [
            karpenterNodesByRegionPieChartPanel,
            karpenterNodesByZonePieChartPanel,
            karpenterNodesByArchPieChartPanel,
            karpenterNodesByOSPieChartPanel,
          ],
          panelWidth=6,
          panelHeight=5,
          startY=23
        ) +
        [
          karpenterPodSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(28) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterPodCpuRequestsStatPanel,
            karpenterPodMemoryRequestsStatPanel,
            karpetnerPodCpuLimitsStatPanel,
            karpenterPodMemoryLimitsStatPanel,
          ],
          panelWidth=6,
          panelHeight=3,
          startY=29
        ) +
        grid.makeGrid(
          [
            karpenterPodsByNodePoolPieChartPanel,
            karpenterPodsByInstanceTypePieChartPanel,
            karpenterPodsByCapacityTypePieChartPanel,
          ],
          panelWidth=8,
          panelHeight=5,
          startY=32
        ) +
        [
          karpenterNodePoolsRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(36) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          karpenterNodePoolTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(37) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
          karpenterNodesRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(45) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          karpenterNodeTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(46) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
        ],
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  }) + if $._config.karpenter.enabled then {
    'kubernetes-autoscaling-mixin-karpenter-over.json'+: $._config.bypassDashboardValidation,
  }
  else {},
}
