local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-vpa.json':
      if !$._config.vpa.enabled then {} else

        local defaultVariables = util.variables($._config);

        local vpaVar = g.dashboard.variable.query.new(
                         'vpa',
                         'label_values(kube_customresource_verticalpodautoscaler_labels{cluster=~"$cluster", namespace=~"$namespace"}, verticalpodautoscaler)'
                       ) +
                       g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                       g.dashboard.variable.query.withSort() +
                       g.dashboard.variable.query.generalOptions.withLabel('VPA') +
                       g.dashboard.variable.query.selectionOptions.withMulti(true) +
                       g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                       g.dashboard.variable.query.refresh.onLoad() +
                       g.dashboard.variable.query.refresh.onTime();

        local containerVar = g.dashboard.variable.query.new(
                               'container',
                               'label_values(kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{cluster=~"$cluster", namespace=~"$namespace", verticalpodautoscaler=~"$vpa"}, container)'
                             ) +
                             g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
                             g.dashboard.variable.query.withSort() +
                             g.dashboard.variable.query.generalOptions.withLabel('Container') +
                             g.dashboard.variable.query.selectionOptions.withMulti(true) +
                             g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
                             g.dashboard.variable.query.refresh.onLoad() +
                             g.dashboard.variable.query.refresh.onTime();

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.namespace,
          vpaVar,
          containerVar,
        ];

        local queries = {
          cpuRecommendationTarget: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="cpu"
              }
            ) by (job, cluster, namespace, verticalpodautoscaler, container, resource)
          |||,

          cpuRecommendationLowerBound: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="cpu"
              }
            ) by (job, cluster, namespace, verticalpodautoscaler, container, resource)
          |||,

          cpuRecommendationUpperBound: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_upperbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="cpu"
              }
            ) by (job, cluster, namespace, verticalpodautoscaler, container, resource)
          |||,

          memoryRecommendationTarget: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="memory"
              }
            ) by (job, cluster, namespace, verticalpodautoscaler, container, resource)
          |||,

          memoryRecommendationLowerBound: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="memory"
              }
            ) by (job, cluster, namespace, verticalpodautoscaler, container, resource)
          |||,

          memoryRecommendationUpperBound: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_upperbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="memory"
              }
            ) by (job, cluster, namespace, verticalpodautoscaler, container, resource)
          |||,

          cpuRecommendationTargetOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="cpu",
                verticalpodautoscaler=~"$vpa",
                container=~"$container"
              }
            ) by (cluster, job, namespace, verticalpodautoscaler, container, resource)
          |||,

          cpuRecommendationLowerBoundOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="cpu",
                verticalpodautoscaler=~"$vpa",
                container=~"$container"
              }
            ) by (cluster, job, namespace, verticalpodautoscaler, container, resource)
          |||,

          cpuRecommendationUpperBoundOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_upperbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="cpu",
                verticalpodautoscaler=~"$vpa",
                container=~"$container"
              }
            ) by (cluster, job, namespace, verticalpodautoscaler, container, resource)
          |||,

          memoryRecommendationTargetOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="memory",
                verticalpodautoscaler=~"$vpa",
                container=~"$container"
              }
            ) by (cluster, job, namespace, verticalpodautoscaler, container, resource)
          |||,

          memoryRecommendationLowerBoundOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="memory",
                verticalpodautoscaler=~"$vpa",
                container=~"$container"
              }
            ) by (cluster, job, namespace, verticalpodautoscaler, container, resource)
          |||,

          memoryRecommendationUpperBoundOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_upperbound{
                cluster=~"$cluster",
                namespace=~"$namespace",
                resource="memory",
                verticalpodautoscaler=~"$vpa",
                container=~"$container"
              }
            ) by (cluster, job, namespace, verticalpodautoscaler, container, resource)
          |||,
        };

        local panels = {
          cpuRecommendationTargetTable:
            mixinUtils.dashboards.tablePanel(
              'CPU Recommendation Target',
              'short',
              queries.cpuRecommendationTarget,
              description='CPU target recommendations for VPAs.',
            ),

          cpuRecommendationBoundsTable:
            mixinUtils.dashboards.tablePanel(
              'CPU Recommendation Bounds',
              'short',
              [
                {
                  expr: queries.cpuRecommendationLowerBound,
                  legend: 'Lower Bound',
                },
                {
                  expr: queries.cpuRecommendationUpperBound,
                  legend: 'Upper Bound',
                },
              ],
              description='CPU recommendation bounds for VPAs.',
            ),

          memoryRecommendationTargetTable:
            mixinUtils.dashboards.tablePanel(
              'Memory Recommendation Target',
              'bytes',
              queries.memoryRecommendationTarget,
              description='Memory target recommendations for VPAs.',
            ),

          memoryRecommendationBoundsTable:
            mixinUtils.dashboards.tablePanel(
              'Memory Recommendation Bounds',
              'bytes',
              [
                {
                  expr: queries.memoryRecommendationLowerBound,
                  legend: 'Lower Bound',
                },
                {
                  expr: queries.memoryRecommendationUpperBound,
                  legend: 'Upper Bound',
                },
              ],
              description='Memory recommendation bounds for VPAs.',
            ),

          cpuRecommendationOverTime:
            mixinUtils.dashboards.timeSeriesPanel(
              'CPU Recommendations Over Time',
              'short',
              [
                {
                  expr: queries.cpuRecommendationTargetOverTime,
                  legend: '{{ verticalpodautoscaler }} / {{ container }} - Target',
                },
                {
                  expr: queries.cpuRecommendationLowerBoundOverTime,
                  legend: '{{ verticalpodautoscaler }} / {{ container }} - Lower',
                },
                {
                  expr: queries.cpuRecommendationUpperBoundOverTime,
                  legend: '{{ verticalpodautoscaler }} / {{ container }} - Upper',
                },
              ],
              calcs=['lastNotNull', 'mean', 'max'],
              description='CPU recommendations over time for selected VPAs.',
            ),

          memoryRecommendationOverTime:
            mixinUtils.dashboards.timeSeriesPanel(
              'Memory Recommendations Over Time',
              'bytes',
              [
                {
                  expr: queries.memoryRecommendationTargetOverTime,
                  legend: '{{ verticalpodautoscaler }} / {{ container }} - Target',
                },
                {
                  expr: queries.memoryRecommendationLowerBoundOverTime,
                  legend: '{{ verticalpodautoscaler }} / {{ container }} - Lower',
                },
                {
                  expr: queries.memoryRecommendationUpperBoundOverTime,
                  legend: '{{ verticalpodautoscaler }} / {{ container }} - Upper',
                },
              ],
              calcs=['lastNotNull', 'mean', 'max'],
              description='Memory recommendations over time for selected VPAs.',
            ),
        };

        local rows =
          [
            row.new('CPU Recommendations') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
            panels.cpuRecommendationTargetTable +
            tablePanel.gridPos.withX(0) +
            tablePanel.gridPos.withY(1) +
            tablePanel.gridPos.withW(12) +
            tablePanel.gridPos.withH(8),
            panels.cpuRecommendationBoundsTable +
            tablePanel.gridPos.withX(12) +
            tablePanel.gridPos.withY(1) +
            tablePanel.gridPos.withW(12) +
            tablePanel.gridPos.withH(8),
            row.new('Memory Recommendations') +
            row.gridPos.withX(0) +
            row.gridPos.withY(9) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
            panels.memoryRecommendationTargetTable +
            tablePanel.gridPos.withX(0) +
            tablePanel.gridPos.withY(10) +
            tablePanel.gridPos.withW(12) +
            tablePanel.gridPos.withH(8),
            panels.memoryRecommendationBoundsTable +
            tablePanel.gridPos.withX(12) +
            tablePanel.gridPos.withY(10) +
            tablePanel.gridPos.withW(12) +
            tablePanel.gridPos.withH(8),
            row.new('Recommendations Over Time') +
            row.gridPos.withX(0) +
            row.gridPos.withY(18) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.cpuRecommendationOverTime,
              panels.memoryRecommendationOverTime,
            ],
            panelWidth=12,
            panelHeight=8,
            startY=19
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / VPA',
        ) +
        dashboard.withDescription('A dashboard that monitors Vertical Pod Autoscalers. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.vpaDashboardUid) +
        dashboard.withTags($._config.tags + ['vpa']) +
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
