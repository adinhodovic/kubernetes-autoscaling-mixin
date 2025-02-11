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
local tsOverride = tsStandardOptions.override;

// Table
local tbOptions = tablePanel.options;
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbFieldConfig = tablePanel.fieldConfig;
local tbOverride = tbStandardOptions.override;

{
  grafanaDashboards+:: {

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
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(clusterLabel)s="$cluster"}, job)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(clusterLabel)s="$cluster", job=~"$job"}, namespace)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local pdbVariable =
      query.new(
        'pdb',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(clusterLabel)s="$cluster", job=~"$job", namespace=~"$namespace"}, poddisruptionbudget)' % $._config,
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Pod Disruption Budget') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local variables = [
      datasourceVariable,
      clusterVariable,
      jobVariable,
      namespaceVariable,
      pdbVariable,
    ],

    local pdbDisruptionsAllowedQuery = |||
      round(
        sum(
          kube_poddisruptionbudget_status_pod_disruptions_allowed{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            poddisruptionbudget=~"$pdb"
          }
        )
      )
    ||| % $._config,

    local pdbDisruptionsAllowedStatPanel =
      statPanel.new(
        'Disruptions Allowed',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          pdbDisruptionsAllowedQuery,
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

    local pdbDesiredHealthyQuery = |||
      round(
        sum(
          kube_poddisruptionbudget_status_desired_healthy{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            poddisruptionbudget=~"$pdb"
          }
        )
      )
    ||| % $._config,

    local pdbDesiredHealthyStatPanel =
      statPanel.new(
        'Desired Healthy',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          pdbDesiredHealthyQuery,
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

    local pdbCurrentlyHealthyQuery = |||
      round(
        sum(
          kube_poddisruptionbudget_status_current_healthy{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            poddisruptionbudget=~"$pdb"
          }
        )
      )
    ||| % $._config,

    local pdbCurrentlyHealthyStatPanel =
      statPanel.new(
        'Currently Healthy',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          pdbCurrentlyHealthyQuery,
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

    local pdbExpectedPodsQuery = |||
      round(
        sum(
          kube_poddisruptionbudget_status_expected_pods{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace",
            poddisruptionbudget=~"$pdb"
          }
        )
      )
    ||| % $._config,

    local pdbExpectedPodsStatPanel =
      statPanel.new(
        'Expected Pods',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          pdbExpectedPodsQuery,
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

    local pdbStatusTimeSeriesPanel =
      timeSeriesPanel.new(
        'Status',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            pdbDisruptionsAllowedQuery,
          ) +
          prometheus.withLegendFormat(
            'Disruptions Allowed'
          ),
          prometheus.new(
            '$datasource',
            pdbDesiredHealthyQuery,
          ) +
          prometheus.withLegendFormat(
            'Desired Healthy'
          ),
          prometheus.new(
            '$datasource',
            pdbCurrentlyHealthyQuery,
          ) +
          prometheus.withLegendFormat(
            'Currently Healthy'
          ),
          prometheus.new(
            '$datasource',
            pdbExpectedPodsQuery,
          ) +
          prometheus.withLegendFormat(
            'Expected Pods'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('short') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsStandardOptions.withOverrides([
        tsOverride.byName.new('Currently Healthy') +
        tsOverride.byName.withPropertiesFromOptions(
          tsStandardOptions.color.withMode('fixed') +
          tsStandardOptions.color.withFixedColor('yellow')
        ),
        tsOverride.byName.new('Disruptions Allowed') +
        tsOverride.byName.withPropertiesFromOptions(
          tsStandardOptions.color.withMode('fixed') +
          tsStandardOptions.color.withFixedColor('red')
        ),
        tsOverride.byName.new('Desired Healthy') +
        tsOverride.byName.withPropertiesFromOptions(
          tsStandardOptions.color.withMode('fixed') +
          tsStandardOptions.color.withFixedColor('green')
        ),
        tsOverride.byName.new('Expected Pods') +
        tsOverride.byName.withPropertiesFromOptions(
          tsStandardOptions.color.withMode('fixed') +
          tsStandardOptions.color.withFixedColor('blue')
        ),
      ]) +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['lastNotNull', 'mean', 'max']) +
      tsLegend.withSortBy('Last *') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local pdbDisruptionsAllowedNamespaceQuery = |||
      round(
        sum(
          kube_poddisruptionbudget_status_pod_disruptions_allowed{
            %(clusterLabel)s="$cluster",
            job=~"$job",
            namespace=~"$namespace"
          }
        ) by (job, namespace, poddisruptionbudget)
      )
    ||| % $._config,
    local pdbDesiredHealthyNamespaceQuery = std.strReplace(pdbDisruptionsAllowedNamespaceQuery, 'pod_disruptions_allowed', 'desired_healthy'),
    local pdbCurrentlyHealthyNamespaceQuery = std.strReplace(pdbDisruptionsAllowedNamespaceQuery, 'pod_disruptions_allowed', 'current_healthy'),
    local pdbExpectedPodsNamespaceQuery = std.strReplace(pdbDisruptionsAllowedNamespaceQuery, 'pod_disruptions_allowed', 'expected_pods'),

    local pdbNamespaceSummaryTable =
      tablePanel.new(
        'Summary'
      ) +
      tbStandardOptions.withUnit('short') +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('Pod Disruption Budget')
      ) +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            pdbDisruptionsAllowedNamespaceQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            pdbDesiredHealthyNamespaceQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            pdbCurrentlyHealthyNamespaceQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            pdbExpectedPodsNamespaceQuery,
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
              poddisruptionbudget: 'Pod Disruption Budget',
              namespace: 'Namespace',
              'Value #A': 'Disruptions Allowed',
              'Value #B': 'Desired Healthy',
              'Value #C': 'Currently Healthy',
              'Value #D': 'Expected Pods',
            },
            indexByName: {
              namespace: 0,
              poddisruptionbudget: 1,
              'Value #A': 2,
              'Value #B': 3,
              'Value #C': 4,
              'Value #D': 5,
            },
            excludeByName: {
              Time: true,
              job: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('Disruptions Allowed') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-text' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.thresholds.withMode('absolute') +
          tbStandardOptions.thresholds.withSteps([
            tbStandardOptions.threshold.step.withValue(0) +
            tbStandardOptions.threshold.step.withColor('red'),
            tbStandardOptions.threshold.step.withValue(0.1) +
            tbStandardOptions.threshold.step.withColor('green'),
          ]),
        ),
      ]),

    local pdbNamespaceSummaryRow =
      row.new(
        title='$namespace Namespace Summary',
      ),
    local pdbSummaryRow =
      row.new(
        title='$pdb Summary',
      ),

    'kubernetes-autoscaling-mixin-pdb.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Pod Disruption Budget',
      ) +
      dashboard.withDescription('A dashboard that monitors Kubernetes and focuses on giving a overview for pod disruption budgets. It is created using the [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).') +
      dashboard.withUid($._config.pdbDashboardUid) +
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
          pdbNamespaceSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          pdbNamespaceSummaryTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(1) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(7),
        ] +
        [
          pdbSummaryRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(8) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [pdbDisruptionsAllowedStatPanel, pdbDesiredHealthyStatPanel, pdbCurrentlyHealthyStatPanel, pdbExpectedPodsStatPanel],
          panelWidth=6,
          panelHeight=3,
          startY=9
        ) +
        [
          pdbStatusTimeSeriesPanel +
          timeSeriesPanel.gridPos.withX(0) +
          timeSeriesPanel.gridPos.withY(12) +
          timeSeriesPanel.gridPos.withW(24) +
          timeSeriesPanel.gridPos.withH(8),
        ]
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
