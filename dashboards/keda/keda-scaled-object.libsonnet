local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-keda-so.json':
      if !$._config.keda.enabled then {} else

        local defaultVariables = util.variables($._config);

        local operatorNamespaceVar = g.dashboard.variable.query.new(
                                       'operator_namespace',
                                       'label_values(keda_scaled_object_paused{cluster="$cluster"}, namespace)'
                                     ) +
                                     g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                                     g.dashboard.variable.query.withSort() +
                                     g.dashboard.variable.query.generalOptions.withLabel('Operator Namespace') +
                                     g.dashboard.variable.query.selectionOptions.withMulti(true) +
                                     g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                                     g.dashboard.variable.query.refresh.onLoad() +
                                     g.dashboard.variable.query.refresh.onTime();

        local resourceNamespaceVar = g.dashboard.variable.query.new(
                                       'resource_namespace',
                                       'label_values(keda_scaled_object_paused{cluster="$cluster", namespace=~"$operator_namespace"}, exported_namespace)'
                                     ) +
                                     g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                                     g.dashboard.variable.query.withSort() +
                                     g.dashboard.variable.query.generalOptions.withLabel('Resource Namespace') +
                                     g.dashboard.variable.query.selectionOptions.withMulti(true) +
                                     g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                                     g.dashboard.variable.query.refresh.onLoad() +
                                     g.dashboard.variable.query.refresh.onTime();

        local scaledObjectVar = g.dashboard.variable.query.new(
                                  'scaled_object',
                                  'label_values(keda_scaled_object_paused{cluster="$cluster", namespace=~"$operator_namespace", exported_namespace=~"$resource_namespace"}, scaledObject)'
                                ) +
                                g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                                g.dashboard.variable.query.withSort() +
                                g.dashboard.variable.query.generalOptions.withLabel('Scaled Object') +
                                g.dashboard.variable.query.selectionOptions.withMulti(false) +
                                g.dashboard.variable.query.selectionOptions.withIncludeAll(false) +
                                g.dashboard.variable.query.refresh.onLoad() +
                                g.dashboard.variable.query.refresh.onTime();

        local scalerVar = g.dashboard.variable.query.new(
                            'scaler',
                            'label_values(keda_scaler_active{cluster="$cluster", namespace=~"$operator_namespace", exported_namespace="$resource_namespace", scaledObject="$scaled_object"}, scaler)'
                          ) +
                          g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                          g.dashboard.variable.query.withSort() +
                          g.dashboard.variable.query.generalOptions.withLabel('Scaler') +
                          g.dashboard.variable.query.selectionOptions.withMulti(false) +
                          g.dashboard.variable.query.selectionOptions.withIncludeAll(false) +
                          g.dashboard.variable.query.refresh.onLoad() +
                          g.dashboard.variable.query.refresh.onTime();

        local metricVar = g.dashboard.variable.query.new(
                            'metric',
                            'label_values(keda_scaler_active{cluster="$cluster", namespace=~"$operator_namespace", exported_namespace="$resource_namespace", scaledObject=~"$scaled_object", scaler=~"$scaler"}, metric)'
                          ) +
                          g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                          g.dashboard.variable.query.withSort() +
                          g.dashboard.variable.query.generalOptions.withLabel('Metric') +
                          g.dashboard.variable.query.selectionOptions.withMulti(false) +
                          g.dashboard.variable.query.selectionOptions.withIncludeAll(false) +
                          g.dashboard.variable.query.refresh.onLoad() +
                          g.dashboard.variable.query.refresh.onTime();

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          operatorNamespaceVar,
          resourceNamespaceVar,
          scaledObjectVar,
          scalerVar,
          metricVar,
        ];

        local queries = {
          resourcesRegisteredByNamespace: |||
            sum(
              keda_resource_registered_total{
                cluster="$cluster",
                namespace=~"$operator_namespace",
                type="scaled_object"
              }
            ) by (exported_namespace, type)
          |||,

          triggersByType: |||
            sum(
              keda_trigger_registered_total{
                cluster="$cluster",
                namespace=~"$operator_namespace"
              }
            ) by (type)
          |||,

          scaledObjectsErrors: |||
            sum(
              increase(
                keda_scaled_object_errors_total{
                  cluster="$cluster",
                  namespace=~"$operator_namespace",
                  exported_namespace=~"$resource_namespace"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject)
          |||,

          scalerDetailErrors: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  cluster="$cluster",
                  namespace=~"$operator_namespace",
                  exported_namespace=~"$resource_namespace",
                  type="scaledobject"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject, scaler)
          |||,

          scaledObjectsPaused: |||
            sum(
              keda_scaled_object_paused{
                cluster="$cluster",
                namespace=~"$operator_namespace",
                exported_namespace=~"$resource_namespace"
              }
            ) by (exported_namespace, scaledObject)
            > 0
          |||,

          scaleTargetValues: |||
            sum(
              keda_scaler_metrics_value{
                cluster="$cluster",
                namespace=~"$operator_namespace",
                exported_namespace=~"$resource_namespace",
                type="scaledobject"
              }
            ) by (job, exported_namespace, scaledObject, scaler, metric)
          |||,

          scaledObjectPaused: |||
            sum(
              keda_scaled_object_paused{
                cluster="$cluster",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                scaledObject="$scaled_object"
              }
            ) by (exported_namespace, scaledObject)
          |||,

          scaledObjectActive: |||
            sum(
              keda_scaler_active{
                cluster="$cluster",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                type="scaledobject",
                scaledObject="$scaled_object"
              }
            ) by (exported_namespace, scaledObject)
          |||,

          scaledObjectDetailError: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  cluster="$cluster",
                  namespace="$operator_namespace",
                  exported_namespace="$resource_namespace",
                  type="scaledobject",
                  scaledObject="$scaled_object"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject)
          |||,

          scaledObjectMetricValue: |||
            avg(
              keda_scaler_metrics_value{
                cluster="$cluster",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                type="scaledobject",
                scaledObject="$scaled_object",
                scaler="$scaler",
                metric="$metric"
              }
            ) by (exported_namespace, scaledObject, scaler, metric)
          |||,

          scaledObjectMetricLatency: |||
            avg(
              keda_scaler_metrics_latency_seconds{
                cluster="$cluster",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                type="scaledobject",
                scaledObject="$scaled_object",
                scaler="$scaler",
                metric="$metric"
              }
            ) by (exported_namespace, scaledObject, scaler, metric)
          |||,
        };

        local panels = {
          resourcesRegistered:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resources Registered by Namespace',
              'short',
              queries.resourcesRegisteredByNamespace,
              '{{ exported_namespace }} / {{ type }}',
              calcs=['mean', 'max'],
              description='The number of scaled object resources registered by namespace.',
            ),

          triggersByType:
            mixinUtils.dashboards.timeSeriesPanel(
              'Triggers by Type',
              'short',
              queries.triggersByType,
              '{{ type }}',
              calcs=['mean', 'max'],
              description='The number of triggers registered by type.',
            ),

          scaledObjectsErrors:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Objects Errors',
              'short',
              queries.scaledObjectsErrors,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='The rate of errors for scaled objects.',
            ),

          scalerDetailErrors:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaler Detail Errors',
              'short',
              queries.scalerDetailErrors,
              '{{ exported_namespace }} / {{ scaledObject }} / {{ scaler }}',
              calcs=['mean', 'max'],
              description='The rate of scaler detail errors.',
            ),

          scaledObjectsPaused:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Objects Paused',
              'short',
              queries.scaledObjectsPaused,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='Scaled objects that are currently paused.',
            ),

          scaledObjectPaused:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Paused',
              'short',
              queries.scaledObjectPaused,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='Whether the selected scaled object is paused.',
            ),

          scaledObjectActive:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Active',
              'short',
              queries.scaledObjectActive,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='Whether the selected scaled object is active.',
            ),

          scaledObjectDetailError:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Detail Errors',
              'short',
              queries.scaledObjectDetailError,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='The rate of errors for the selected scaled object.',
            ),

          scaledObjectMetricValue:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Metric Value',
              'short',
              queries.scaledObjectMetricValue,
              '{{ exported_namespace }} / {{ scaledObject }} / {{ scaler }} / {{ metric }}',
              calcs=['mean', 'max'],
              description='The metric value for the selected scaled object.',
            ),

          scaledObjectMetricLatency:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Object Metric Latency',
              's',
              queries.scaledObjectMetricLatency,
              '{{ exported_namespace }} / {{ scaledObject }} / {{ scaler }} / {{ metric }}',
              calcs=['mean', 'max'],
              description='The metric collection latency for the selected scaled object.',
            ),

          scaleTargetValuesTable:
            mixinUtils.dashboards.tablePanel(
              'Scale Target Values',
              'short',
              queries.scaleTargetValues,
              description='Current metric values for all scaled objects.',
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
              panels.resourcesRegistered,
              panels.triggersByType,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=1
          ) +
          grid.makeGrid(
            [
              panels.scaledObjectsErrors,
              panels.scalerDetailErrors,
              panels.scaledObjectsPaused,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=7
          ) +
          [
            row.new('Scaled Object Detail') +
            row.gridPos.withX(0) +
            row.gridPos.withY(13) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.scaledObjectPaused,
              panels.scaledObjectActive,
              panels.scaledObjectDetailError,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=14
          ) +
          grid.makeGrid(
            [
              panels.scaledObjectMetricValue,
              panels.scaledObjectMetricLatency,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=20
          ) +
          [
            row.new('Scale Targets') +
            row.gridPos.withX(0) +
            row.gridPos.withY(26) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
            panels.scaleTargetValuesTable +
            tablePanel.gridPos.withX(0) +
            tablePanel.gridPos.withY(27) +
            tablePanel.gridPos.withW(24) +
            tablePanel.gridPos.withH(8),
          ];

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
  },
}
