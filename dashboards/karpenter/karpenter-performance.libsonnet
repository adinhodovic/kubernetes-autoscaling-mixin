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

    local variables = [
      datasourceVariable,
      clusterVariable,
      jobVariable,
    ],

    local karpenterClusterStateSyncedQuery = |||
      sum(
        karpenter_cluster_state_synced{
          %(clusterLabel)s="$cluster",
          job=~"$job",
        }
      ) by (job)
    ||| % $._config,

    local karpenterClusterStateSyncedStatPanel =
      statPanel.new(
        'Cluster State Synced',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterClusterStateSyncedQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]) +
      stStandardOptions.withMappings(
        stStandardOptions.mapping.ValueMap.withType() +
        stStandardOptions.mapping.ValueMap.withOptions(
          {
            '0': { text: 'No', color: 'red' },
            '1': { text: 'Yes', color: 'green' },
          }
        )
      ),

    local karpenterClusterStateNodeCountQuery = |||
      sum(
        karpenter_cluster_state_node_count{
          %(clusterLabel)s="$cluster",
          job=~"$job",
        }
      ) by (job)
    ||| % $._config,

    local karpenterClusterStateNodeCountStatPanel =
      statPanel.new(
        'Cluster State Node Count',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          karpenterClusterStateNodeCountQuery,
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

    local karpenterCloudProviderErrorsQuery = |||
      round(
        sum(
          increase(
            karpenter_cloudprovider_errors_total{
              %(clusterLabel)s="$cluster",
              job=~"$job"
            }[$__rate_interval]
          )
        ) by (job, provider, controller, method, error)
      )
    ||| % $._config,

    local karpenterCloudProviderErrorsTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Cloud Provider Errors',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterCloudProviderErrorsQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ provider }} - {{ controller }} - {{ method }} - {{ error }}'
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

    local karpenterNodeTerminationP50DurationQuery = |||
      max(
        karpenter_nodes_termination_duration_seconds{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          quantile="0.5"
        }
      )
    ||| % $._config,
    local karpenterNodeTerminationP95DurationQuery = std.strReplace(karpenterNodeTerminationP50DurationQuery, '0.5', '0.95'),
    local karpenterNodeTerminationP99DurationQuery = std.strReplace(karpenterNodeTerminationP50DurationQuery, '0.5', '0.99'),

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

    local karpenterInterruptionReceivedMessagesQuery = |||
      sum(
        increase(
          karpenter_interruption_received_messages_total{
            %(clusterLabel)s="$cluster",
            job=~"$job"
          }[$__rate_interval]
        )
      ) by (job, message_type)
    ||| % $._config,

    local karpenterInterruptionReceivedMessagesTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Interruption Received Messages',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterInterruptionReceivedMessagesQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ message_type }}'
          ),
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


    local karpenterInterruptionDeletedMessagesQuery = |||
      sum(
        increase(
          karpenter_interruption_deleted_messages_total{
            %(clusterLabel)s="$cluster",
            job=~"$job"
          }[$__rate_interval]
        )
      ) by (job)
    ||| % $._config,

    local karpenterInterruptionDeletedMessagesTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Interruption Deleted Messages',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterInterruptionDeletedMessagesQuery,
          ) +
          prometheus.withLegendFormat(
            'Deleted Messages'
          ),
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

    local karpenterInteruptionDurationP50Query = |||
      histogram_quantile(0.50,
        sum(
          irate(
            karpenter_interruption_message_queue_duration_seconds_bucket{
              %(clusterLabel)s="$cluster",
              job=~"$job"
            }[$__rate_interval]
          ) > 0
        ) by (job, le)
      )
    ||| % $._config,
    local karpenterInteruptionDurationP95Query = std.strReplace(karpenterInteruptionDurationP50Query, '0.50', '0.95'),
    local karpenterInteruptionDurationP99Query = std.strReplace(karpenterInteruptionDurationP50Query, '0.50', '0.99'),

    local karpenterInteruptionDurationTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Interruption Duration',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterInteruptionDurationP50Query,
          ) +
          prometheus.withLegendFormat(
            'P50'
          ),
          prometheus.new(
            '$datasource',
            karpenterInteruptionDurationP95Query,
          ) +
          prometheus.withLegendFormat(
            'P95'
          ),
          prometheus.new(
            '$datasource',
            karpenterInteruptionDurationP99Query,
          ) +
          prometheus.withLegendFormat(
            'P99'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10) +
      tsCustom.withSpanNulls(false),

    local karpenterNodeTerminationDurationTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Node Termination Duration',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterNodeTerminationP50DurationQuery,
          ) +
          prometheus.withLegendFormat(
            'P50'
          ) +
          prometheus.withInterval('1m'),
          prometheus.new(
            '$datasource',
            karpenterNodeTerminationP95DurationQuery,
          ) +
          prometheus.withLegendFormat(
            'P95'
          ) +
          prometheus.withInterval('1m'),
          prometheus.new(
            '$datasource',
            karpenterNodeTerminationP99DurationQuery,
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
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterWorkQueueDepthQuery = |||
      sum(
        karpenter_workqueue_depth{
          %(clusterLabel)s="$cluster",
          job=~"$job"
        }
      ) by (job)
    ||| % $._config,

    local karpenterWorkQueueDepthTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Work Queue Depth',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterWorkQueueDepthQuery,
          ) +
          prometheus.withLegendFormat(
            'Queue Depth'
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
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local karpenterWorkQueueInQueueDurationP50Query = |||
      histogram_quantile(0.50,
        sum(
          irate(
            karpenter_workqueue_queue_duration_seconds_bucket{
              %(clusterLabel)s="$cluster",
              job=~"$job"
            }[$__rate_interval]
          ) > 0
        ) by (job, le)
      )
    ||| % $._config,
    local karpenterWorkQueueInQueueDurationP95Query = std.strReplace(karpenterWorkQueueInQueueDurationP50Query, '0.50', '0.95'),
    local karpenterWorkQueueInQueueDurationP99Query = std.strReplace(karpenterWorkQueueInQueueDurationP50Query, '0.50', '0.99'),

    local karpenterWorkQueueInQueueDurationTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Work Queue In Queue Duration',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterWorkQueueInQueueDurationP50Query,
          ) +
          prometheus.withLegendFormat(
            'P50'
          ),
          prometheus.new(
            '$datasource',
            karpenterWorkQueueInQueueDurationP95Query,
          ) +
          prometheus.withLegendFormat(
            'P95'
          ),
          prometheus.new(
            '$datasource',
            karpenterWorkQueueInQueueDurationP99Query,
          ) +
          prometheus.withLegendFormat(
            'P99'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10) +
      tsCustom.withSpanNulls(false),

    local karpenterWorkQueueWorkDurationP50Query = |||
      histogram_quantile(0.50,
        sum(
          irate(
            karpenter_workqueue_work_duration_seconds_bucket{
              %(clusterLabel)s="$cluster",
              job=~"$job"
            }[$__rate_interval]
          ) > 0
        ) by (job, le)
      )
    ||| % $._config,
    local karpenterWorkQueueWorkDurationP95Query = std.strReplace(karpenterWorkQueueWorkDurationP50Query, '0.50', '0.95'),
    local karpenterWorkQueueWorkDurationP99Query = std.strReplace(karpenterWorkQueueWorkDurationP50Query, '0.50', '0.99'),

    local karpenterWorkQueueWorkDurationTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Work Queue Work Duration',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterWorkQueueWorkDurationP50Query,
          ) +
          prometheus.withLegendFormat(
            'P50'
          ),
          prometheus.new(
            '$datasource',
            karpenterWorkQueueWorkDurationP95Query,
          ) +
          prometheus.withLegendFormat(
            'P95'
          ),
          prometheus.new(
            '$datasource',
            karpenterWorkQueueWorkDurationP99Query,
          ) +
          prometheus.withLegendFormat(
            'P99'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withFillOpacity(10) +
      tsCustom.withSpanNulls(false),

    local karpenterControllerReconcileQuery = |||
      sum(
        rate(
          controller_runtime_reconcile_total{
            %(clusterLabel)s="$cluster",
            job=~"$job"
          }[$__rate_interval]
        )
      ) by (job, controller) > 0
    ||| % $._config,

    local karpenterControllerReconcileTimeSeriesPanel =
      timeSeriesPanel.new(
        title='Controller Reconcile',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            karpenterControllerReconcileQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ controller }}'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('reqps') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('value') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local karpenterSummaryRow =
      row.new(
        title='Summary',
      ),

    local karpenterInterruptionQueueRow =
      row.new(
        title='Interruption Queue',
      ),

    local karpenterWorkQueueRow =
      row.new(
        title='Work Queue',
      ),

    local karpenterControllerRow =
      row.new(
        title='Controller',
      ),

    'kubernetes-autoscaling-mixin-karpenter-perf.json': if $._config.karpenter.enabled then
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Karpenter / Performance',
      ) +
      dashboard.withDescription('A dashboard that monitors Karpenter and focuses on Karpenter performance. It is created using the [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).') +
      dashboard.withUid($._config.karpenterPerformanceDashboardUid) +
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
          karpenterSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          karpenterClusterStateSyncedStatPanel +
          statPanel.gridPos.withX(0) +
          statPanel.gridPos.withY(1) +
          statPanel.gridPos.withW(6) +
          statPanel.gridPos.withH(3),
          karpenterClusterStateNodeCountStatPanel +
          statPanel.gridPos.withX(0) +
          statPanel.gridPos.withY(4) +
          statPanel.gridPos.withW(6) +
          statPanel.gridPos.withH(3),
          karpenterCloudProviderErrorsTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(6) +
          timeSeriesPanel.gridPos.withY(1) +
          timeSeriesPanel.gridPos.withW(18) +
          timeSeriesPanel.gridPos.withH(6),
        ] +
        grid.makeGrid(
          [
            karpenterNodeTerminationDurationTimeSeriesPanel,
            karpenterPodStartupDurationTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=7
        ) +
        [
          karpenterInterruptionQueueRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(13) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterInterruptionReceivedMessagesTimeSeriesPanel,
            karpenterInterruptionDeletedMessagesTimeSeriesPanel,
            karpenterInteruptionDurationTimeSeriesPanel,
          ],
          panelWidth=8,
          panelHeight=6,
          startY=14
        ) +
        [
          karpenterWorkQueueRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(20) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterWorkQueueDepthTimeSeriesPanel,
            karpenterWorkQueueInQueueDurationTimeSeriesPanel,
            karpenterWorkQueueWorkDurationTimeSeriesPanel,
          ],
          panelWidth=8,
          panelHeight=6,
          startY=21
        ) +
        [
          karpenterControllerRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(27) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            karpenterControllerReconcileTimeSeriesPanel,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=28
        ),
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  }) + if $._config.karpenter.enabled then {
    'kubernetes-autoscaling-mixin-karpenter-perf.json'+: $._config.bypassDashboardValidation,
  } else {},
}
