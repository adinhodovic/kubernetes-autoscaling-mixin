local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-keda-sj.json':
      if !$._config.keda.enabled then {} else

        local defaultVariables = util.variables($._config);

        local operatorNamespaceVar = g.dashboard.variable.query.new(
                                       'operator_namespace',
                                       'label_values(keda_scaled_job_errors_total{cluster="$cluster", job=~"$job"}, namespace)'
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
                                       'label_values(keda_scaled_job_errors_total{cluster="$cluster", job=~"$job", namespace=~"$operator_namespace"}, exported_namespace)'
                                     ) +
                                     g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                                     g.dashboard.variable.query.withSort() +
                                     g.dashboard.variable.query.generalOptions.withLabel('Resource Namespace') +
                                     g.dashboard.variable.query.selectionOptions.withMulti(true) +
                                     g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                                     g.dashboard.variable.query.refresh.onLoad() +
                                     g.dashboard.variable.query.refresh.onTime();

        local scaledJobVar = g.dashboard.variable.query.new(
                               'scaled_job',
                               'label_values(keda_scaled_job_errors_total{cluster="$cluster", job=~"$job", namespace=~"$operator_namespace", exported_namespace=~"$resource_namespace"}, scaledJob)'
                             ) +
                             g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                             g.dashboard.variable.query.withSort() +
                             g.dashboard.variable.query.generalOptions.withLabel('Scaled Job') +
                             g.dashboard.variable.query.selectionOptions.withMulti(false) +
                             g.dashboard.variable.query.selectionOptions.withIncludeAll(false) +
                             g.dashboard.variable.query.refresh.onLoad() +
                             g.dashboard.variable.query.refresh.onTime();

        local scalerVar = g.dashboard.variable.query.new(
                            'scaler',
                            'label_values(keda_scaler_active{cluster="$cluster", job=~"$job", namespace=~"$operator_namespace", exported_namespace="$resource_namespace", type="scaledjob", scaledObject="$scaled_job"}, scaler)'
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
                            'label_values(keda_scaler_active{cluster="$cluster", job=~"$job", namespace=~"$operator_namespace", exported_namespace="$resource_namespace", type="scaledjob", scaledObject=~"$scaled_job", scaler=~"$scaler"}, metric)'
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
          scaledJobVar,
          scalerVar,
          metricVar,
        ];

        local queries = {
          resourcesRegisteredByNamespace: |||
            sum(
              keda_resource_registered_total{
                cluster="$cluster",
                job=~"$job",
                namespace=~"$operator_namespace",
                type="scaled_job"
              }
            ) by (exported_namespace, type)
          |||,

          triggersByType: |||
            sum(
              keda_trigger_registered_total{
                cluster="$cluster",
                job=~"$job",
                namespace=~"$operator_namespace"
              }
            ) by (type)
          |||,

          scaledJobsErrors: |||
            sum(
              increase(
                keda_scaled_job_errors_total{
                  cluster="$cluster",
                  job=~"$job",
                  namespace=~"$operator_namespace",
                  exported_namespace=~"$resource_namespace"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledJob)
          |||,

          scalerDetailErrors: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  cluster="$cluster",
                  job=~"$job",
                  namespace=~"$operator_namespace",
                  exported_namespace=~"$resource_namespace",
                  type="scaledjob"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject, scaler)
          |||,

          scaleTargetValues: |||
            sum(
              keda_scaler_metrics_value{
                cluster="$cluster",
                job=~"$job",
                namespace=~"$operator_namespace",
                exported_namespace=~"$resource_namespace",
                type="scaledjob"
              }
            ) by (job, exported_namespace, scaledObject, scaler, metric)
          |||,

          scaledJobActive: |||
            sum(
              keda_scaler_active{
                cluster="$cluster",
                job=~"$job",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                type="scaledjob",
                scaledObject="$scaled_job"
              }
            ) by (exported_namespace, scaledObject)
          |||,

          scaledJobDetailError: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  cluster="$cluster",
                  job=~"$job",
                  namespace="$operator_namespace",
                  exported_namespace="$resource_namespace",
                  type="scaledjob",
                  scaledObject="$scaled_job"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject)
          |||,

          scaledJobMetricValue: |||
            avg(
              keda_scaler_metrics_value{
                cluster="$cluster",
                job=~"$job",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                type="scaledjob",
                scaledObject="$scaled_job",
                scaler="$scaler",
                metric="$metric"
              }
            ) by (exported_namespace, scaledObject, scaler, metric)
          |||,

          scaledJobMetricLatency: |||
            avg(
              keda_scaler_metrics_latency_seconds{
                cluster="$cluster",
                job=~"$job",
                namespace="$operator_namespace",
                exported_namespace="$resource_namespace",
                type="scaledjob",
                scaledObject="$scaled_job",
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
              description='The number of scaled job resources registered by namespace.',
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

          scaledJobsErrors:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Jobs Errors',
              'short',
              queries.scaledJobsErrors,
              '{{ exported_namespace }} / {{ scaledJob }}',
              calcs=['mean', 'max'],
              description='The rate of errors for scaled jobs.',
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

          scaledJobActive:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Active',
              'short',
              queries.scaledJobActive,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='Whether the scaled job is active.',
            ),

          scaledJobDetailError:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Detail Errors',
              'short',
              queries.scaledJobDetailError,
              '{{ exported_namespace }} / {{ scaledObject }}',
              calcs=['mean', 'max'],
              description='The rate of errors for the selected scaled job.',
            ),

          scaledJobMetricValue:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Metric Value',
              'short',
              queries.scaledJobMetricValue,
              '{{ exported_namespace }} / {{ scaledObject }} / {{ scaler }} / {{ metric }}',
              calcs=['mean', 'max'],
              description='The metric value for the selected scaled job.',
            ),

          scaledJobMetricLatency:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Metric Latency',
              's',
              queries.scaledJobMetricLatency,
              '{{ exported_namespace }} / {{ scaledObject }} / {{ scaler }} / {{ metric }}',
              calcs=['mean', 'max'],
              description='The metric collection latency for the selected scaled job.',
            ),

          scaleTargetValuesTable:
            mixinUtils.dashboards.tablePanel(
              'Scale Target Values',
              'short',
              queries.scaleTargetValues,
              description='Current metric values for all scaled jobs.',
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
              panels.scaledJobsErrors,
              panels.scalerDetailErrors,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=7
          ) +
          [
            row.new('Scaled Job Detail') +
            row.gridPos.withX(0) +
            row.gridPos.withY(13) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.scaledJobActive,
              panels.scaledJobDetailError,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=14
          ) +
          grid.makeGrid(
            [
              panels.scaledJobMetricValue,
              panels.scaledJobMetricLatency,
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
          'Kubernetes / Autoscaling / KEDA / Scaled Job',
        ) +
        dashboard.withDescription('A dashboard that monitors KEDA Scaled Jobs. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.kedaScaledJobDashboardUid) +
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
