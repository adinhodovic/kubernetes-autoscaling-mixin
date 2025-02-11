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
local stOverride = statPanel.fieldOverride;

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

{
  grafanaDashboards+:: std.prune({

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source'),

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
        'label_values(kube_customresource_verticalpodautoscaler_labels{%(clusterLabel)s="$cluster"}, job)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(kube_customresource_verticalpodautoscaler_labels{%(clusterLabel)s="$cluster", job=~"$job"}, namespace)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local vpaVariable =
      query.new(
        'vpa',
        'label_values(kube_customresource_verticalpodautoscaler_labels{%(clusterLabel)s="$cluster", job=~"$job", namespace=~"$namespace"}, verticalpodautoscaler)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('VPA Pod Autoscaler') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local containerVariable =
      query.new(
        'container',
        'label_values(kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{%(clusterLabel)s="$cluster", job=~"$job", namespace=~"$namespace", verticalpodautoscaler=~"$vpa"}, container)' % $._config
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Container') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      clusterVariable,
      jobVariable,
      namespaceVariable,
      vpaVariable,
      containerVariable,
    ],

    local vpaCpuRecommendationTargetQuery = |||
      sum(
        kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace=~"$namespace",
          resource="cpu"
        }
      ) by (job, namespace, verticalpodautoscaler, container, resource)
    ||| % $._config,
    local vpaCpuRecommendationLowerBoundQuery = std.strReplace(vpaCpuRecommendationTargetQuery, 'target', 'lowerbound'),
    local vpaCpuRecommendationUpperBoundQuery = std.strReplace(vpaCpuRecommendationTargetQuery, 'target', 'upperbound'),

    local vpaCpuResourceTable =
      tablePanel.new(
        'CPU Resource Recommendations',
      ) +
      tbStandardOptions.withUnit('short') +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Vertical Pod Autoscaler')
      ) +
      tbOptions.footer.withEnablePagination(true) +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            vpaCpuRecommendationLowerBoundQuery,
          ) +
          prometheus.withLegendFormat(
            'CPU Lower Bound'
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            vpaCpuRecommendationTargetQuery,
          ) +
          prometheus.withLegendFormat(
            'CPU Target'
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            vpaCpuRecommendationUpperBoundQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table') +
          prometheus.withLegendFormat(
            'CPU Upper Bound'
          ),
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
              verticalpodautoscaler: 'Vertical Pod Autoscaler',
              container: 'Container',
              resource: 'Resource',
              'Value #A': 'CPU Lower Bound',
              'Value #B': 'CPU Target',
              'Value #C': 'CPU Upper Bound',
            },
            indexByName: {
              namespace: 0,
              verticalpodautoscaler: 1,
              container: 2,
              resource: 3,
              'Value #A': 4,
              'Value #B': 5,
              'Value #C': 6,
            },
            excludeByName: {
              Time: true,
              job: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('CPU Lower Bound') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('dark-red') +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic'),
        ),
        tbOverride.byName.new('CPU Target') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('yellow') +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic'),
        ),
        tbOverride.byName.new('CPU Upper Bound') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('green') +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic'),
        ),
      ]),

    local vpaMemoryRecommendationTargetQuery = std.strReplace(vpaCpuRecommendationTargetQuery, 'cpu', 'memory'),
    local vpaMemoryRecommendationLowerBoundQuery = std.strReplace(vpaMemoryRecommendationTargetQuery, 'target', 'lowerbound'),
    local vpaMemoryRecommendationUpperBoundQuery = std.strReplace(vpaMemoryRecommendationTargetQuery, 'target', 'upperbound'),

    local vpaMemoryResourceTable =
      tablePanel.new(
        'Memory Resource Recommendations',
      ) +
      tbStandardOptions.withUnit('bytes') +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Vertical Pod Autoscaler')
      ) +
      tbOptions.footer.withEnablePagination(true) +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            vpaMemoryRecommendationLowerBoundQuery,
          ) +
          prometheus.withLegendFormat(
            'Memory Lower Bound'
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            vpaMemoryRecommendationTargetQuery,
          ) +
          prometheus.withLegendFormat(
            'Memory Target'
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table'),
          prometheus.new(
            '$datasource',
            vpaMemoryRecommendationUpperBoundQuery,
          ) +
          prometheus.withInstant(true) +
          prometheus.withFormat('table') +
          prometheus.withLegendFormat(
            'Memory Upper Bound'
          ),
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
              verticalpodautoscaler: 'Vertical Pod Autoscaler',
              container: 'Container',
              resource: 'Resource',
              'Value #A': 'Memory Lower Bound',
              'Value #B': 'Memory Target',
              'Value #C': 'Memory Upper Bound',
            },
            indexByName: {
              namespace: 0,
              verticalpodautoscaler: 1,
              container: 2,
              resource: 3,
              'Value #A': 4,
              'Value #B': 5,
              'Value #C': 6,
            },
            excludeByName: {
              Time: true,
              job: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('Memory Lower Bound') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('dark-red') +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic'),
        ),
        tbOverride.byName.new('Memory Target') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('yellow') +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic'),
        ),
        tbOverride.byName.new('Memory Upper Bound') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.color.withMode('fixed') +
          tbStandardOptions.color.withFixedColor('green') +
          tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic'),
        ),
      ]),

    local vpaCpuRecommendationTargetOverTimeQuery = |||
      sum(
        kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace=~"$namespace",
          resource="cpu",
          verticalpodautoscaler="$vpa",
          container="$container"
        }
      ) by (job, namespace, verticalpodautoscaler, container, resource)
    ||| % $._config,
    local vpaCpuRecommendationLowerBoundOverTimeQuery = std.strReplace(vpaCpuRecommendationTargetOverTimeQuery, 'target', 'lowerbound'),
    local vpaCpuRecommendationUpperBoundOverTimeQuery = std.strReplace(vpaCpuRecommendationTargetOverTimeQuery, 'target', 'upperbound'),
    local vpaCpuUsageOverTimeQuery = |||
      sum(
        node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace="$namespace",
          pod=~"$vpa-(.+)",
          container="$container"
        }
      ) by (container)
    ||| % $._config,
    local vpaCpuRequestOverTimeQuery = |||
      sum(
        kube_pod_container_resource_requests{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace="$namespace",
          pod=~"$vpa-(.+)",
          resource="cpu",
          container="$container"
        }
      ) by (container)
    ||| % $._config,
    local vpaCpuLimitOverTimeQuery = std.strReplace(vpaCpuRequestOverTimeQuery, 'requests', 'limits'),

    local vpaCpuRecommendationOverTimeTimeSeriesPanel =
      timeSeriesPanel.new(
        'VPA CPU Recommendations Over Time',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            vpaCpuRecommendationLowerBoundOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Lower Bound'
          ),
          prometheus.new(
            '$datasource',
            vpaCpuRecommendationTargetOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Target'
          ),
          prometheus.new(
            '$datasource',
            vpaCpuRecommendationUpperBoundOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Upper Bound'
          ),
          prometheus.new(
            '$datasource',
            vpaCpuUsageOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Usage'
          ),
          prometheus.new(
            '$datasource',
            vpaCpuRequestOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Requests'
          ),
          prometheus.new(
            '$datasource',
            vpaCpuLimitOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Limits'
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

    local vpaMemoryRecommendationTargetOverTimeQuery = std.strReplace(vpaCpuRecommendationTargetOverTimeQuery, 'cpu', 'memory'),
    local vpaMemoryRecommendationLowerBoundOverTimeQuery = std.strReplace(vpaMemoryRecommendationTargetOverTimeQuery, 'target', 'lowerbound'),
    local vpaMemoryRecommendationUpperBoundOverTimeQuery = std.strReplace(vpaMemoryRecommendationTargetOverTimeQuery, 'target', 'upperbound'),
    local vpaMemoryUsageOverTimeQuery = |||
      sum(
        container_memory_working_set_bytes{
          %(clusterLabel)s="$cluster",
          job=~"$job",
          namespace="$namespace",
          pod=~"$vpa(.+)",
          container="$container"
        }
      ) by (container)
    ||| % $._config,
    local vpaMemoryRequestOverTimeQuery = std.strReplace(vpaCpuRequestOverTimeQuery, 'cpu', 'memory'),
    local vpaMemoryLimitOverTimeQuery = std.strReplace(vpaMemoryRequestOverTimeQuery, 'requests', 'limits'),

    local vpaMemoryRecommendationOverTimeTimeSeriesPanel =
      timeSeriesPanel.new(
        'VPA Memory Recommendations Over Time',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            vpaMemoryRecommendationLowerBoundOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Lower Bound'
          ),
          prometheus.new(
            '$datasource',
            vpaMemoryRecommendationTargetOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Target'
          ),
          prometheus.new(
            '$datasource',
            vpaMemoryRecommendationUpperBoundOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Upper Bound'
          ),
          prometheus.new(
            '$datasource',
            vpaMemoryUsageOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Usage'
          ),
          prometheus.new(
            '$datasource',
            vpaMemoryRequestOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Requests'
          ),
          prometheus.new(
            '$datasource',
            vpaMemoryLimitOverTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ container }} - Limits'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('bytes') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local vpaCpuGuaranteedQosStatPanel =
      statPanel.new(
        'CPU Guaranteed QoS',
      ) +
      stQueryOptions.withTargets([
        prometheus.new(
          '$datasource',
          vpaCpuRecommendationTargetOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'CPU Requests'
        ),
        prometheus.new(
          '$datasource',
          vpaCpuRecommendationTargetOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'CPU Limits'
        ),
      ]) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('yellow'),
      ]),

    local vpaCpuBurstableQosStatPanel =
      statPanel.new(
        'CPU Burstable QoS',
      ) +
      stQueryOptions.withTargets([
        prometheus.new(
          '$datasource',
          vpaCpuRecommendationLowerBoundOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'CPU Requests'
        ),
        prometheus.new(
          '$datasource',
          vpaCpuRecommendationUpperBoundOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'CPU Limits'
        ),
      ]) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withOverrides([
        stOverride.byName.new('CPU Requests') +
        stOverride.byName.withPropertiesFromOptions(
          stStandardOptions.color.withMode('fixed') +
          stStandardOptions.color.withFixedColor('red')
        ),
        stOverride.byName.new('CPU Limits') +
        stOverride.byName.withPropertiesFromOptions(
          stStandardOptions.color.withMode('fixed') +
          stStandardOptions.color.withFixedColor('green')
        ),
      ]),

    local vpaMemoryGuaranteedQosStatPanel =
      statPanel.new(
        'Memory Guaranteed QoS',
      ) +
      stQueryOptions.withTargets([
        prometheus.new(
          '$datasource',
          vpaMemoryRecommendationTargetOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'Memory Requests'
        ),
        prometheus.new(
          '$datasource',
          vpaMemoryRecommendationTargetOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'Memory Limits'
        ),
      ]) +
      stStandardOptions.withUnit('bytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('yellow'),
      ]),

    local vpaMemoryBurstableQosStatPanel =
      statPanel.new(
        'Memory Burstable QoS',
      ) +
      stQueryOptions.withTargets([
        prometheus.new(
          '$datasource',
          vpaMemoryRecommendationLowerBoundOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'Memory Requests'
        ),
        prometheus.new(
          '$datasource',
          vpaMemoryRecommendationUpperBoundOverTimeQuery
        ) +
        prometheus.withLegendFormat(
          'Memory Limits'
        ),
      ]) +
      stStandardOptions.withUnit('bytes') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.withOverrides([
        stOverride.byName.new('Memory Requests') +
        stOverride.byName.withPropertiesFromOptions(
          stStandardOptions.color.withMode('fixed') +
          stStandardOptions.color.withFixedColor('red')
        ),
        stOverride.byName.new('Memory Limits') +
        stOverride.byName.withPropertiesFromOptions(
          stStandardOptions.color.withMode('fixed') +
          stStandardOptions.color.withFixedColor('green')
        ),
      ]),

    local vpaNamespaceSummaryRow =
      row.new(
        title='$namespace Summary',
      ),

    local vpaSummaryRow =
      row.new(
        title='$vpa / $container Summary',
      ) +
      row.withRepeat('container'),

    'kubernetes-autoscaling-mixin-vpa.json': if $._config.vpa.enabled then
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Vertical Pod Autoscaler',
      ) +
      dashboard.withDescription('A dashboard that monitors Kubernetes and focuses on giving a overview for vertical pod autoscalers. It is created using the [Kubernetes / Autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).') +
      dashboard.withUid($._config.vpaDashboardUid) +
      dashboard.withTags($._config.tags + ['kubernetes-core']) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        [
          dashboard.link.dashboards.new('Kubernetes / Autoscaling', $._config.tags + ['kubernetes-core']) +
          dashboard.link.link.options.withTargetBlank(true),
        ]
      ) +
      dashboard.withPanels(
        [
          vpaNamespaceSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        [
          vpaCpuResourceTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
          vpaMemoryResourceTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(9) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
          vpaSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(17) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            vpaCpuGuaranteedQosStatPanel,
            vpaCpuBurstableQosStatPanel,
            vpaMemoryGuaranteedQosStatPanel,
            vpaMemoryBurstableQosStatPanel,
          ],
          panelWidth=6,
          panelHeight=6,
          startY=18
        ) +
        grid.makeGrid(
          [
            vpaCpuRecommendationOverTimeTimeSeriesPanel,
            vpaMemoryRecommendationOverTimeTimeSeriesPanel,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=26
        ),
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  }) + if $._config.vpa.enabled then {
    'kubernetes-autoscaling-mixin-vpa.json'+: $._config.bypassDashboardValidation,
  } else {},
}
