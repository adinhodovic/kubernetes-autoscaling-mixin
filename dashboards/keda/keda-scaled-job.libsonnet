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
      'kubernetes-autoscaling-mixin-keda-sj.json':

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.scaledJobJob,
          defaultVariables.scaledJobOperatorNamespace,
          defaultVariables.scaledJobResourceNamespace,
          defaultVariables.scaledJob,
          defaultVariables.scalerForScaledJob,
          defaultVariables.metricForScaledJob,
        ];

        local defaultFilters = util.filters($._config);

        local queries = {
          resourcesRegisteredByNamespace: |||
            sum(
              keda_resource_registered_total{
                %(base)s,
                type="scaled_job"
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

          scaledJobsErrors: |||
            sum(
              increase(
                keda_scaled_job_errors_total{
                  %(withResourceNamespace)s
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledJob)
          ||| % defaultFilters,

          scalerDetailErrors: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  %(withResourceNamespace)s,
                  type="scaledjob"
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject, scaler)
          ||| % defaultFilters,

          scaleTargetValues: |||
            sum(
              keda_scaler_metrics_value{
                %(withResourceNamespace)s,
                type="scaledjob"
              }
            ) by (cluster, job, exported_namespace, scaledObject, scaler, metric)
          ||| % defaultFilters,

          scaledJobActive: |||
            sum(
              keda_scaler_active{
                %(withScaledJob)s
              }
            ) by (exported_namespace, scaledObject)
          ||| % defaultFilters,

          scaledJobDetailError: |||
            sum(
              increase(
                keda_scaler_detail_errors_total{
                  %(withScaledJob)s
                }[$__rate_interval]
              )
            ) by (exported_namespace, scaledObject)
          ||| % defaultFilters,

          scaledJobMetricValue: |||
            avg(
              keda_scaler_metrics_value{
                %(withScaledJobMetric)s
              }
            ) by (exported_namespace, scaledObject, scaler, metric)
          ||| % defaultFilters,

          scaledJobMetricLatency: |||
            avg(
              keda_scaler_metrics_latency_seconds{
                %(withScaledJobMetric)s
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
              description='The number of scaled job resources registered by namespace.',
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

          scaledJobsErrorsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Jobs Errors',
              'short',
              queries.scaledJobsErrors,
              '{{ scaledJob }}',
              description='The rate of errors for scaled jobs.',
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

          scaleTargetValuesTable:
            mixinUtils.dashboards.tablePanel(
              'Scale Target Values',
              'short',
              queries.scaleTargetValues,
              description='This table has links to the Workload dashboard for the scaled Job, which can be used to see the current resource usage. The Workload dashboard can be found at [kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin) and requires ID customization.',
              sortBy={ name: 'Scaled Job', desc: false },
              transformations=[
                tbQueryOptions.transformation.withId(
                  'organize'
                ) +
                tbQueryOptions.transformation.withOptions(
                  {
                    renameByName: {
                      scaledObject: 'Scaled Job',
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
                  },
                ),
              ],
              links=[
                tbPanelOptions.link.withTitle('Go to Scaled Job') +
                tbPanelOptions.link.withUrl(
                  '/d/%s/kubernetes-compute-resources-workload?var-cluster=${__data.fields.cluster}&var-namespace=${__data.fields.exported_namespace}&var-type=ScaledJob&var-workload=${__data.fields.scaledObject}' % $._config.keda.k8sResourcesWorkloadDashboardUid
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

          scaledJobActiveTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Active',
              'short',
              queries.scaledJobActive,
              '{{ scaledObject }}',
              description='Whether the scaled job is active.',
            ),

          scaledJobDetailErrorTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Detail Errors',
              'short',
              queries.scaledJobDetailError,
              '{{ scaledObject }}',
              description='The rate of errors for the selected scaled job.',
            ),

          scaledJobMetricValueTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Metric Value',
              'short',
              queries.scaledJobMetricValue,
              '{{ scaledObject }} / {{ scaler }} / {{ metric }}',
              description='The metric value for the selected scaled job.',
              stack='normal',
            ),

          scaledJobMetricLatencyTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scaled Job Metric Latency',
              's',
              queries.scaledJobMetricLatency,
              '{{ scaledObject }} / {{ scaler }} / {{ metric }}',
              description='The metric collection latency for the selected scaled job.',
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
              panels.scaledJobsErrorsTimeSeries,
              panels.scalerDetailErrorsTimeSeries,
            ],
            panelWidth=12,
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
            row.new('Scaled Job $scaled_job / $scaler / $metric') +
            row.gridPos.withX(0) +
            row.gridPos.withY(21) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.scaledJobActiveTimeSeries,
              panels.scaledJobDetailErrorTimeSeries,
            ],
            panelWidth=12,
            panelHeight=5,
            startY=22
          ) +
          grid.makeGrid(
            [
              panels.scaledJobMetricValueTimeSeries,
              panels.scaledJobMetricLatencyTimeSeries,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=27
          );

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
    } else {},
}
