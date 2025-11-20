local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;

local timeSeriesPanel = g.panel.timeSeries;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

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
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local nodePoolVariable =
      query.new(
        'nodepool',
        'label_values(karpenter_nodepools_limit{%(clusterLabel)s="$cluster", job=~"$job"}, nodepool)' % $._config,
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
      nodePoolVariable,
    ],

    local karpenterNodesCreatedByNodePoolQuery = |||
      round(
        sum(
          increase(
            karpenter_nodes_created_total{
              %(clusterLabel)s="$cluster",
              job=~"$job",
              nodepool=~"$nodepool"
            }[$__rate_interval]
          )
        ) by (nodepool)
      )
    ||| % $._config,

    local karpenterNodesCreatedByNodePoolTimeSeriesPanel =
      timeSeriesPanel.new(
        'Nodes Created by Node Pool',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodesCreatedByNodePoolQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ nodepool }}'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterNodesTerminatedByNodePoolQuery = std.strReplace(karpenterNodesCreatedByNodePoolQuery, 'created', 'terminated'),

    local karpenterNodesTerminatedByNodePoolTimeSeriesPanel =
      timeSeriesPanel.new(
        'Nodes Terminated by Node Pool',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodesTerminatedByNodePoolQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ nodepool }}'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterNodesVoluntaryDisruptionDecisionsQuery = |||
      round(
        sum(
          increase(
            karpenter_voluntary_disruption_decisions_total{
              %(clusterLabel)s="$cluster",
              job=~"$job",
            }[$__rate_interval]
          )
        ) by (decision, reason)
      )
    ||| % $._config,

    local karpenterNodesVoluntaryDisruptionDecisionsTimeSeriesPanel =
      timeSeriesPanel.new(
        'Node Disruption Decisions by Reason and Decision',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodesVoluntaryDisruptionDecisionsQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ decision }} - {{ reason }}'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterNodesVoluntaryDisruptionEligibleQuery = |||
      round(
        sum(
          karpenter_voluntary_disruption_eligible_nodes{
            %(clusterLabel)s="$cluster",
            job=~"$job"
          }
        ) by (reason)
      )
    ||| % $._config,

    local karpenterNodesVoluntaryDisruptionEligibleTimeSeriesPanel =
      timeSeriesPanel.new(
        'Nodes Eligible for Disruption by Reason',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodesVoluntaryDisruptionEligibleQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ reason }}'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),


    local karpenterNodesDisruptedQuery = |||
      round(
        sum(
          increase(
            karpenter_nodeclaims_disrupted_total{
              %(clusterLabel)s="$cluster",
              job=~"$job",
              nodepool=~"$nodepool"
            }[$__rate_interval]
          )
        ) by (nodepool, capacity_type, reason)
      )
    ||| % $._config,

    local karpenterNodesDisruptedTimeSeriesPanel =
      timeSeriesPanel.new(
        'Nodes Disrupted by Node Pool',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodesDisruptedQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ nodepool }} - {{ capacity_type }} - {{ reason }}'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterPodStateByPhaseQuery = |||
      round(
        sum(
          karpenter_pods_state{
            %(clusterLabel)s="$cluster",
            job=~"$job"
          }
        ) by (phase)
      )
    ||| % $._config,

    local karpenterPodStateByPhaseTimeSeriesPanel =
      timeSeriesPanel.new(
        'Pods by Phase',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterPodStateByPhaseQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ phase }}'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterPodsStartupP50DurationQuery = |||
      max(
        karpenter_pods_startup_duration_seconds{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          quantile="0.5"
        }
      )
    ||| % $._config,
    local karpenterPodsStartupP95DurationQuery = std.strReplace(karpenterPodsStartupP50DurationQuery, '0.5', '0.95'),
    local karpenterPodsStartupP99DurationQuery = std.strReplace(karpenterPodsStartupP50DurationQuery, '0.5', '0.99'),

    local karpenterPodStartupDurationTimeSeriesPanel =
      timeSeriesPanel.new(
        'Pods Startup Duration',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterPodsStartupP50DurationQuery,
          ) +
          prometheus.withLegendFormat(
            'P50'
          ) +
          prometheus.withInterval('1m'),
          prometheus.new(
            '$datasource',
            karpenterPodsStartupP95DurationQuery,
          ) +
          prometheus.withLegendFormat(
            'P95'
          ) +
          prometheus.withInterval('1m'),
          prometheus.new(
            '$datasource',
            karpenterPodsStartupP99DurationQuery,
          ) +
          prometheus.withLegendFormat(
            'P99'
          ) +
          prometheus.withInterval('1m'),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterNodePoolActivityRow =
      row.new(
        title='Node Pool Activity',
      ),

    local karpenterPodActivityRow =
      row.new(
        title='Pod Activity',
      ),

    'kubernetes-autoscaling-mixin-karpenter-act.json': if $._config.karpenter.enabled then
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Karpenter / Activity',
      ) +
      dashboard.withDescription('A dashboard that monitors Karpenter and focuses on Karpenter deletion/creation activity. It is created using the [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).') +
      dashboard.withUid($._config.karpenterActivityDashboardUid) +
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
          karpenterNodePoolActivityRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterNodesCreatedByNodePoolTimeSeriesPanel,
            karpenterNodesTerminatedByNodePoolTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=1
        ) +
        grid.makeGrid(
          [
            karpenterNodesVoluntaryDisruptionDecisionsTimeSeriesPanel,
            karpenterNodesVoluntaryDisruptionEligibleTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=7
        ) +
        grid.makeGrid(
          [
            karpenterNodesDisruptedTimeSeriesPanel,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=13
        ) +
        [
          karpenterPodActivityRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(19) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterPodStateByPhaseTimeSeriesPanel,
            karpenterPodStartupDurationTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=20
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  }) + if $._config.karpenter.enabled then {
    'kubernetes-autoscaling-mixin-karpenter-act.json'+: $._config.bypassDashboardValidation,
  } else {},
}
