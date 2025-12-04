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

{
  grafanaDashboards+:: {

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
        'label_values(kube_horizontalpodautoscaler_metadata_generation{%(clusterLabel)s="$cluster"}, job)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(kube_horizontalpodautoscaler_metadata_generation{%(clusterLabel)s="$cluster", job=~"$job"}, namespace)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local hpaVariable =
      query.new(
        'hpa',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(clusterLabel)s="$cluster", job=~"$job", namespace="$namespace"},horizontalpodautoscaler)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Horitzontal Pod Autoscaler') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local metricNameVariable =
      query.new(
        'metric_name',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(clusterLabel)s="$cluster", job=~"$job", namespace="$namespace", horizontalpodautoscaler="$hpa"}, metric_name)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Metric Name') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local metricTargetTypeVariable =
      query.new(
        'metric_target_type',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(clusterLabel)s="$cluster", job=~"$job", namespace="$namespace", horizontalpodautoscaler="$hpa", metric_name=~"$metric_name"}, metric_target_type)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Metric Target Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      clusterVariable,
      jobVariable,
      namespaceVariable,
      hpaVariable,
      metricNameVariable,
      metricTargetTypeVariable,
    ],

    local hpaDesiredReplicasQuery = |||
      round(
        sum(
          kube_horizontalpodautoscaler_status_desired_replicas{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            horizontalpodautoscaler="$hpa"
          }
        )
      )
    ||| % $._config,

    local hpaDesiredReplicasStatPanel =
      statPanel.new(
        'Desired Replicas',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          hpaDesiredReplicasQuery,
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

    local hpaCurrentReplicasQuery = |||
      round(
        sum(
          kube_horizontalpodautoscaler_status_current_replicas{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            horizontalpodautoscaler="$hpa"
          }
        )
      )
    ||| % $._config,

    local hpaCurrentReplicasStatPanel =
      statPanel.new(
        'Current Replicas',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          hpaCurrentReplicasQuery,
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

    local hpaMinReplicasQuery = |||
      round(
        sum(
          kube_horizontalpodautoscaler_spec_min_replicas{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            horizontalpodautoscaler="$hpa"
          }
        )
      )
    ||| % $._config,

    local hpaMinReplicasStatPanel =
      statPanel.new(
        'Min Replicas',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          hpaMinReplicasQuery,
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

    local hpaMaxReplicasQuery = |||
      round(
        sum(
          kube_horizontalpodautoscaler_spec_max_replicas{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            horizontalpodautoscaler="$hpa"
          }
        )
      )
    ||| % $._config,

    local hpaMaxReplicasStatPanel =
      statPanel.new(
        'Max Replicas',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          hpaMaxReplicasQuery,
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

    local hpaMetricTargetsQuery = |||
      sum(
        kube_horizontalpodautoscaler_spec_target_metric{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace=~"$namespace",
          horizontalpodautoscaler="$hpa",
          metric_name=~"$metric_name"
        }
      ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
    ||| % $._config,

    local hpaMetricTargetsTable =
      tablePanel.new(
        'Metric Targets'
      ) +
      tbStandardOptions.withUnit('short') +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Horitzontal Pod Autoscaler')
      ) +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            hpaMetricTargetsQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
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
              horizontalpodautoscaler: 'Horitzontal Pod Autoscaler',
              metric_name: 'Metric Name',
              metric_target_type: 'Metric Target Type',
              'Value #A': 'Threshold',
            },
            indexByName: {
              horizontalpodautoscaler: 0,
              namespace: 1,
              metric_name: 2,
              metric_target_type: 3,
              'Value #A': 4,
            },
            excludeByName: {
              Time: true,
              job: true,
            },
          }
        ),
      ]),

    local hpaUsageThresholdQuery = |||
      sum(
        kube_horizontalpodautoscaler_spec_target_metric{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace=~"$namespace",
          horizontalpodautoscaler="$hpa",
          metric_name=~"$metric_name",
          metric_target_type=~"$metric_target_type",
        }
      ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
    ||| % $._config,
    local hpaUtilizationQuery = std.strReplace(hpaUsageThresholdQuery, 'spec_target_metric', 'status_target_metric'),

    local hpaUsageThresholdTimeSeriesPanel =
      timeSeriesPanel.new(
        'Usage & Threshold',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            hpaUtilizationQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ metric_target_type }} / {{ metric_name }}'
          ),
          prometheus.new(
            '$datasource',
            hpaUsageThresholdQuery,
          ) +
          prometheus.withLegendFormat(
            'Threshold / {{ metric_name }}'
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

    local hpaReplicasTimeSeriesPanel =
      timeSeriesPanel.new(
        'Replicas',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            hpaDesiredReplicasQuery,
          ) +
          prometheus.withLegendFormat(
            'Desired Replicas'
          ),
          prometheus.new(
            '$datasource',
            hpaCurrentReplicasQuery,
          ) +
          prometheus.withLegendFormat(
            'Current Replicas'
          ),
          prometheus.new(
            '$datasource',
            hpaMinReplicasQuery,
          ) +
          prometheus.withLegendFormat(
            'Min Replicas'
          ),
          prometheus.new(
            '$datasource',
            hpaMaxReplicasQuery,
          ) +
          prometheus.withLegendFormat(
            'Max Replicas'
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

    local hpaSummaryRow =
      row.new(
        title='Summary',
      ),

    local hpaTargetTypeRow =
      row.new(
        title='Target Type $metric_name / $metric_target_type' % $._config,
      ) +
      row.withRepeat('metric_target_type'),

    'kubernetes-autoscaling-mixin-hpa.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Horizontal Pod Autoscaler',
      ) +
      dashboard.withDescription('A dashboard that monitors Kubernetes and focuses on giving a overview for horizontal pod autoscalers. It is created using the [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).') +
      dashboard.withUid($._config.hpaDashboardUid) +
      dashboard.withTags($._config.tags + ['kubernetes-core']) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
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
          hpaSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            hpaDesiredReplicasStatPanel,
            hpaCurrentReplicasStatPanel,
            hpaMinReplicasStatPanel,
            hpaMaxReplicasStatPanel,
          ],
          panelWidth=6,
          panelHeight=3,
          startY=1
        ) +
        [
          hpaMetricTargetsTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(6) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
          hpaTargetTypeRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          hpaUsageThresholdTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(0) +
          timeSeriesPanel.gridPos.withY(15) +
          timeSeriesPanel.gridPos.withW(24) +
          timeSeriesPanel.gridPos.withH(6),
          hpaReplicasTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(0) +
          timeSeriesPanel.gridPos.withY(21) +
          timeSeriesPanel.gridPos.withW(24) +
          timeSeriesPanel.gridPos.withH(6),
        ]
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
