local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-hpa.json':

      local defaultVariables = util.variables($._config);

      local hpaVar = g.dashboard.variable.query.new(
                       'hpa',
                       'label_values(kube_horizontalpodautoscaler_spec_target_metric{cluster="$cluster", namespace="$namespace"}, horizontalpodautoscaler)'
                     ) +
                     g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                     g.dashboard.variable.query.withSort() +
                     g.dashboard.variable.query.generalOptions.withLabel('HPA') +
                     g.dashboard.variable.query.selectionOptions.withMulti(false) +
                     g.dashboard.variable.query.selectionOptions.withIncludeAll(false) +
                     g.dashboard.variable.query.refresh.onLoad() +
                     g.dashboard.variable.query.refresh.onTime();

      local metricNameVar = g.dashboard.variable.query.new(
                              'metric_name',
                              'label_values(kube_horizontalpodautoscaler_spec_target_metric{cluster="$cluster", namespace="$namespace", horizontalpodautoscaler="$hpa"}, metric_name)'
                            ) +
                            g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                            g.dashboard.variable.query.withSort() +
                            g.dashboard.variable.query.generalOptions.withLabel('Metric Name') +
                            g.dashboard.variable.query.selectionOptions.withMulti(true) +
                            g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                            g.dashboard.variable.query.refresh.onLoad() +
                            g.dashboard.variable.query.refresh.onTime();

      local metricTargetTypeVar = g.dashboard.variable.query.new(
                                    'metric_target_type',
                                    'label_values(kube_horizontalpodautoscaler_spec_target_metric{cluster="$cluster", namespace="$namespace", horizontalpodautoscaler="$hpa", metric_name=~"$metric_name"}, metric_target_type)'
                                  ) +
                                  g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                                  g.dashboard.variable.query.withSort() +
                                  g.dashboard.variable.query.generalOptions.withLabel('Metric Target Type') +
                                  g.dashboard.variable.query.selectionOptions.withMulti(true) +
                                  g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                                  g.dashboard.variable.query.refresh.onLoad() +
                                  g.dashboard.variable.query.refresh.onTime();

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        hpaVar,
        metricNameVar,
        metricTargetTypeVar,
      ];

      local queries = {
        desiredReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_status_desired_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        currentReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_status_current_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        minReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_spec_min_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        maxReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_spec_max_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        metricTargets: |||
          sum(
            kube_horizontalpodautoscaler_spec_target_metric{
              cluster="$cluster",
              namespace=~"$namespace",
              horizontalpodautoscaler="$hpa",
              metric_name=~"$metric_name"
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        |||,

        usageThreshold: |||
          sum(
            kube_horizontalpodautoscaler_spec_target_metric{
              cluster="$cluster",
              namespace=~"$namespace",
              horizontalpodautoscaler="$hpa",
              metric_name=~"$metric_name",
              metric_target_type=~"$metric_target_type"
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        |||,

        utilization: |||
          sum(
            kube_horizontalpodautoscaler_status_target_metric{
              cluster="$cluster",
              namespace=~"$namespace",
              horizontalpodautoscaler="$hpa",
              metric_name=~"$metric_name",
              metric_target_type=~"$metric_target_type"
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        |||,
      };

      local panels = {
        desiredReplicas:
          mixinUtils.dashboards.statPanel(
            'Desired Replicas',
            'short',
            queries.desiredReplicas,
            description='The desired number of replicas for the HPA.',
          ),

        currentReplicas:
          mixinUtils.dashboards.statPanel(
            'Current Replicas',
            'short',
            queries.currentReplicas,
            description='The current number of replicas for the HPA.',
          ),

        minReplicas:
          mixinUtils.dashboards.statPanel(
            'Min Replicas',
            'short',
            queries.minReplicas,
            description='The minimum number of replicas configured for the HPA.',
          ),

        maxReplicas:
          mixinUtils.dashboards.statPanel(
            'Max Replicas',
            'short',
            queries.maxReplicas,
            description='The maximum number of replicas configured for the HPA.',
          ),

        usageThreshold:
          mixinUtils.dashboards.timeSeriesPanel(
            'Usage Threshold',
            'short',
            queries.usageThreshold,
            '{{ metric_name }} / {{ metric_target_type }}',
            calcs=['lastNotNull', 'mean', 'max'],
            description='The configured threshold for the HPA metric.',
          ),

        utilization:
          mixinUtils.dashboards.timeSeriesPanel(
            'Utilization',
            'short',
            queries.utilization,
            '{{ metric_name }} / {{ metric_target_type }}',
            calcs=['lastNotNull', 'mean', 'max'],
            description='The current utilization of the HPA metric.',
          ),

        metricTargetsTable:
          mixinUtils.dashboards.tablePanel(
            'Metric Targets',
            'short',
            queries.metricTargets,
            description='Configured metric targets for the HPA.',
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
            panels.desiredReplicas,
            panels.currentReplicas,
            panels.minReplicas,
            panels.maxReplicas,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          row.new('Metrics') +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.usageThreshold,
            panels.utilization,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=6
        ) +
        [
          row.new('Metric Targets') +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.metricTargetsTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(15) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
        ];

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / HPA',
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
