local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbQueryOptions = tablePanel.queryOptions;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-hpa.json':

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.hpaJob,
        defaultVariables.hpaNamespace,
        defaultVariables.hpa,
        defaultVariables.hpaMetricName,
        defaultVariables.hpaMetricTargetType,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        desiredReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_status_desired_replicas{
                %(withHpa)s
              }
            )
          )
        ||| % defaultFilters,

        currentReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_status_current_replicas{
                %(withHpa)s
              }
            )
          )
        ||| % defaultFilters,

        minReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_spec_min_replicas{
                %(withHpa)s
              }
            )
          )
        ||| % defaultFilters,

        maxReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_spec_max_replicas{
                %(withHpa)s
              }
            )
          )
        ||| % defaultFilters,

        metricTargets: |||
          sum(
            kube_horizontalpodautoscaler_spec_target_metric{
              %(withHpaMetricName)s
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        ||| % defaultFilters,

        usageThreshold: |||
          sum(
            kube_horizontalpodautoscaler_spec_target_metric{
              %(withHpaMetricTargetType)s
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        ||| % defaultFilters,

        utilization: |||
          sum(
            kube_horizontalpodautoscaler_status_target_metric{
              %(withHpaMetricTargetType)s
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        ||| % defaultFilters,
      };

      local panels = {
        desiredReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Desired Replicas',
            'short',
            queries.desiredReplicas,
            description='The desired number of replicas for the HPA.',
          ),

        currentReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Current Replicas',
            'short',
            queries.currentReplicas,
            description='The current number of replicas for the HPA.',
          ),

        minReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Min Replicas',
            'short',
            queries.minReplicas,
            description='The minimum number of replicas configured for the HPA.',
          ),

        maxReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Max Replicas',
            'short',
            queries.maxReplicas,
            description='The maximum number of replicas configured for the HPA.',
          ),

        usageAndThresholdTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Usage & Threshold',
            'short',
            [
              {
                expr: queries.utilization,
                legend: '{{ metric_target_type }} / {{ metric_name }}',
              },
              {
                expr: queries.usageThreshold,
                legend: 'Threshold / {{ metric_name }}',
              },
            ],
            fillOpacity=0,
            description='The current utilization and configured threshold for the HPA metric.',
          ),

        replicasTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Replicas',
            'short',
            [
              {
                expr: queries.desiredReplicas,
                legend: 'Desired Replicas',
              },
              {
                expr: queries.currentReplicas,
                legend: 'Current Replicas',
              },
              {
                expr: queries.minReplicas,
                legend: 'Min Replicas',
              },
              {
                expr: queries.maxReplicas,
                legend: 'Max Replicas',
              },
            ],
            fillOpacity=0,
            description='The desired, current, minimum, and maximum replicas for the HPA over time.',
          ),

        metricTargetsTable:
          mixinUtils.dashboards.tablePanel(
            'Metric Targets',
            'short',
            queries.metricTargets,
            description='Configured metric targets for the HPA.',
            transformations=[
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
            ]
          ),
      };

      local rows =
        [
          row.new('Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.desiredReplicasStat,
            panels.currentReplicasStat,
            panels.minReplicasStat,
            panels.maxReplicasStat,
          ],
          panelWidth=6,
          panelHeight=3,
          startY=1
        ) +
        [
          panels.metricTargetsTable +
          row.gridPos.withX(0) +
          row.gridPos.withY(4) +
          row.gridPos.withW(24) +
          row.gridPos.withH(10),
          row.new('$horizontalpodautoscaler / $metric_name / $metric_target_type') +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.usageAndThresholdTimeSeries,
            panels.replicasTimeSeries,
          ],
          panelWidth=24,
          panelHeight=6,
          startY=15
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Horizontal Pod Autoscaler',
      ) +
      dashboard.withDescription('A dashboard that monitors Horizontal Pod Autoscalers. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
      dashboard.withUid($._config.hpaDashboardUid) +
      dashboard.withTags($._config.tags + ['hpa']) +
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
