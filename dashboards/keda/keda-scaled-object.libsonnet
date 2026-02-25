local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbStandardOptions = tablePanel.standardOptions;

{
  grafanaDashboards+::
    if $._config.keda.enabled then {
      'kubernetes-autoscaling-mixin-keda-so.json':

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.scaledObjectJob,
          defaultVariables.scaledObjectOperatorNamespace,
          defaultVariables.scaledObjectResourceNamespace,
          defaultVariables.scaledObject,
          defaultVariables.scalerForScaledObject,
          defaultVariables.metricForScaledObject,
        ];

        local defaultFilters = util.filters($._config);

        local queries = {
          resourcesRegisteredByNamespace: |||
            sum(
              keda_resource_registered_total{
                %(base)s,
                type="scaled_object"
              }
            ) by (exported_namespace, type)
          ||| % defaultFilters,

          triggersByType: |||
            sum(
              keda_trigger_registered_total{
                %(base)s
              }
            ) by (type)
          ||| % defaultFilters,

          scaledObjectsErrors: |||
            sum(
              increase(
                keda_scaled_object_errors_total{
                  %(withResourceNamespace)s
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject)
          ||| % defaultFilters,

          scalerDetailErrors: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  %(withResourceNamespace)s,
                  type="scaledobject"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject, scaler)
          ||| % defaultFilters,

          scaledObjectsPaused: |||
            sum(
              keda_scaled_object_paused{
                %(withResourceNamespace)s
              }
            ) by (exported_namespace, scaledObject)
            > 0
          ||| % defaultFilters,

          scaleTargetValues: |||
            sum(
              keda_scaler_metrics_value{
                %(withResourceNamespace)s,
                type="scaledobject"
              }
            ) by (cluster, job, exported_namespace, scaledObject, scaler, metric)
          ||| % defaultFilters,

          scaledObjectPaused: |||
            sum(
              keda_scaled_object_paused{
                %(withScaledObject)s
              }
            ) by (exported_namespace, scaledObject)
          ||| % defaultFilters,

          scaledObjectActive: |||
            sum(
              keda_scaler_active{
                %(withScaledObject)s
              }
            ) by (exported_namespace, scaledObject)
          ||| % defaultFilters,

          scaledObjectDetailError: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  %(withScaledObject)s
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject)
          ||| % defaultFilters,

          scaledObjectMetricValue: |||
            avg(
              keda_scaler_metrics_value{
                %(withScaledObjectMetric)s
              }
            ) by (exported_namespace, scaledObject, scaler, metric)
          ||| % defaultFilters,

          scaledObjectMetricLatency: |||
            avg(
              keda_scaler_metrics_latency_seconds{
                %(withScaledObjectMetric)s
              }
            ) by (exported_namespace, scaledObject, scaler, metric)
          ||| % defaultFilters,
        };

        local panels = {
          resourcesRegisteredTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resources Registered by Namespace',
              'short',
              queries.resourcesRegisteredByNamespace,
              '{{ exported_namespace}} / {{ type }}',
              description='The number of scaled object resources registered by namespace.',
              stack='normal',
            ),

          triggersByTypeTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Triggers by Type',
              'short',
              queries.triggersByType,
              '{{ type }}',
              description='The number of triggers registered by type.',
              stack='normal',
            ),

          scaledObjectsErrorsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Objects Errors',
              'short',
              queries.scaledObjectsErrors,
              '{{ scaledObject }}',
              description='The rate of errors for scaled objects.',
              stack='normal',
            ),

          scalerDetailErrorsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaler Detail Errors',
              'short',
              queries.scalerDetailErrors,
              '{{ scaledObject }} / {{ scaler }}',
              description='The rate of scaler detail errors.',
              stack='normal',
            ),

          scaledObjectsPausedTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Objects Paused',
              'short',
              queries.scaledObjectsPaused,
              '{{ scaledObject }}',
              description='Scaled objects that are currently paused.',
              stack='normal',
            ),

          scaleTargetValuesTable:
            mixinUtils.dashboards.tablePanel(
              'Scale Target Values',
              'short',
              queries.scaleTargetValues,
              description='This table has links to the HPA for the scaled object, which can be used to see the current scaling status and history. The HPA dashboard can be found at [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin).',
              sortBy={ name: 'Scaled Object', desc: false },
              transformations=[
                tbQueryOptions.transformation.withId(
                  'organize'
                ) +
                tbQueryOptions.transformation.withOptions(
                  {
                    renameByName: {
                      scaledObject: 'Scaled Object',
                      exported_namespace: 'Resource Namespace',
                      scaler: 'Scaler',
                      metric: 'Metric',
                      value: 'Value',
                    },
                    indexByName: {
                      scaledObject: 0,
                      exported_namespace: 1,
                      scaler: 2,
                      metric: 3,
                      value: 4,
                    },
                    excludeByName: {
                      Time: true,
                      job: true,
                    },
                  }
                ),
              ],
              links=[
                tbPanelOptions.link.withTitle('Go to HPA') +
                tbPanelOptions.link.withUrl(
                  '/d/%s/kubernetes-autoscaling-horizontal-pod-autoscaler?var-cluster=${__data.fields.cluster}&var-namespace=${__data.fields.namespace}&var-hpa=keda-hpa-${__data.fields.scaledObject}&var-metric_name=${__data.fields.metric}' % $._config.hpaDashboardUid
                ) +
                tbPanelOptions.link.withTargetBlank(true),
              ],
              overrides=(
                if std.all([$._config.showMultiCluster, !$._config.allowMultiClusterSelection])
                then
                  [
                    tbStandardOptions.override.byName.new('cluster') +
                    tbStandardOptions.override.byName.withProperty('custom.hideFrom.viz', true)
                  ]
                else
                  []
              )
            ),

          scaledObjectPausedTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Paused',
              'short',
              queries.scaledObjectPaused,
              '{{ scaledObject }}',
              description='Whether the selected scaled object is paused.',
            ),

          scaledObjectActiveTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Active',
              'short',
              queries.scaledObjectActive,
              '{{ scaledObject }}',
              description='Whether the selected scaled object is active.',
            ),

          scaledObjectDetailErrorTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Detail Errors',
              'short',
              queries.scaledObjectDetailError,
              '{{ scaledObject }}',
              description='The rate of errors for the selected scaled object.',
            ),

          scaledObjectMetricValueTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Metric Value',
              'short',
              queries.scaledObjectMetricValue,
              '{{ scaledObject }} / {{ scaler }} / {{ metric }}',
              description='The metric value for the selected scaled object.',
              stack='normal',
            ),

          scaledObjectMetricLatencyTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Metric Latency',
              's',
              queries.scaledObjectMetricLatency,
              '{{ scaledObject }} / {{ scaler }} / {{ metric }}',
              description='The metric collection latency for the selected scaled object.',
            ),
        };

        local rows =
          [
            row.new('Overview') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.resourcesRegisteredTimeSeries,
              panels.triggersByTypeTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=1
          ) +
          grid.makeGrid(
            [
              panels.scaledObjectsErrorsTimeSeries,
              panels.scalerDetailErrorsTimeSeries,
              panels.scaledObjectsPausedTimeSeries,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=7
          ) +
          grid.makeGrid(
            [
              panels.scaleTargetValuesTable,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=13
          ) +
          [
            row.new('Scaled Object $scaled_object / $scaler / $metric') +
            row.gridPos.withX(0) +
            row.gridPos.withY(21) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.scaledObjectPausedTimeSeries,
              panels.scaledObjectActiveTimeSeries,
              panels.scaledObjectDetailErrorTimeSeries,
            ],
            panelWidth=8,
            panelHeight=5,
            startY=22
          ) +
          grid.makeGrid(
            [
              panels.scaledObjectMetricValueTimeSeries,
              panels.scaledObjectMetricLatencyTimeSeries,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=27
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / KEDA / Scaled Object',
        ) +
        dashboard.withDescription('A dashboard that monitors KEDA Scaled Objects. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.kedaScaledObjectDashboardUid) +
        dashboard.withTags($._config.tags + ['keda']) +
        dashboard.withTimezone('utc') +
        dashboard.withEditable(true) +
        dashboard.time.withFrom('now-6h') +
        dashboard.time.withTo('now') +
        dashboard.withVariables(variables) +
        dashboard.withLinks(
          mixinUtils.dashboards.dashboardLinks('Kubernetes / Autoscaling', $._config, dropdown=true)
        ) +
        dashboard.withPanels(rows),
    } else {},
}
