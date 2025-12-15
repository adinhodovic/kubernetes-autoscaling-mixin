local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbOverride = tbStandardOptions.override;
local tbFieldConfig = tablePanel.fieldConfig;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-vpa.json':
      if !$._config.vpa.enabled then {} else

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.vpaJob,
          defaultVariables.vpaNamespace,
          defaultVariables.vpa,
          defaultVariables.vpaContainer,
        ];

        local defaultFilters = util.filters($._config);

        local queries = {
          // Namespace summary queries - shows current requests/limits and recommendations
          cpuRequests: |||
            max(
              label_replace(
                max(
                  kube_pod_container_resource_requests{
                    %(base)s,
                    resource="cpu"
                  }
                ) by (%(clusterLabel)s, job, namespace, pod, container, resource),
                "verticalpodautoscaler", "%(vpaPrefix)s$1", "pod", "^(.*?)(?:-[a-f0-9]{8,10}-[a-z0-9]{5}|-[0-9]+|-[a-z0-9]{5,16})$"
              )
              + on(%(clusterLabel)s, job, namespace, container, resource, verticalpodautoscaler) group_left()
              0 *
              max(
                kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                  %(base)s,
                  resource="cpu"
                }
              ) by (%(clusterLabel)s, job, namespace, verticalpodautoscaler, container, resource)
            )
            by (%(clusterLabel)s, job, namespace, verticalpodautoscaler, container, resource)
          ||| % defaultFilters,

          cpuLimits: std.strReplace(self.cpuRequests, 'requests', 'limits'),

          cpuRecommendationTarget: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                %(base)s,
                resource="cpu"
              }
            ) by (job, %(clusterLabel)s, namespace, verticalpodautoscaler, container, resource)
          ||| % defaultFilters,

          cpuRecommendationLowerBound: std.strReplace(self.cpuRecommendationTarget, 'target', 'lowerbound'),
          cpuRecommendationUpperBound: std.strReplace(self.cpuRecommendationTarget, 'target', 'upperbound'),

          memoryRequests: std.strReplace(self.cpuRequests, 'cpu', 'memory'),
          memoryLimits: std.strReplace(self.cpuLimits, 'cpu', 'memory'),
          memoryRecommendationTarget: std.strReplace(self.cpuRecommendationTarget, 'cpu', 'memory'),
          memoryRecommendationLowerBound: std.strReplace(self.cpuRecommendationLowerBound, 'cpu', 'memory'),
          memoryRecommendationUpperBound: std.strReplace(self.cpuRecommendationUpperBound, 'cpu', 'memory'),

          // Over time queries - filtered by $vpa and $container variables
          cpuRecommendationTargetOverTime: |||
            max(
              kube_customresource_verticalpodautoscaler_status_recommendation_containerrecommendations_target{
                %(withVpa)s,
                resource="cpu"
              }
            ) by (%(clusterLabel)s, job, namespace, verticalpodautoscaler, container, resource)
          ||| % defaultFilters,

          cpuRecommendationLowerBoundOverTime: std.strReplace(self.cpuRecommendationTargetOverTime, 'target', 'lowerbound'),
          cpuRecommendationUpperBoundOverTime: std.strReplace(self.cpuRecommendationTargetOverTime, 'target', 'upperbound'),

          cpuUsageOverTime: |||
            avg(
              node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{
                %(cluster)s,
                %(namespace)s,
                pod=~"$verticalpodautoscaler-.*",
                container=~"$container",
                container!=""
              }
            ) by (%(clusterLabel)s, container)
          ||| % defaultFilters,

          cpuRequestOverTime: |||
            max(
              kube_pod_container_resource_requests{
                %(base)s,
                pod=~"$verticalpodautoscaler-.*",
                resource=~"cpu",
                container=~"$container"
              }
            ) by (%(clusterLabel)s, container)
          ||| % defaultFilters,

          cpuLimitOverTime: std.strReplace(self.cpuRequestOverTime, 'requests', 'limits'),

          memoryRecommendationTargetOverTime: std.strReplace(self.cpuRecommendationTargetOverTime, 'cpu', 'memory'),
          memoryRecommendationLowerBoundOverTime: std.strReplace(self.memoryRecommendationTargetOverTime, 'target', 'lowerbound'),
          memoryRecommendationUpperBoundOverTime: std.strReplace(self.memoryRecommendationTargetOverTime, 'target', 'upperbound'),

          memoryUsageOverTime: |||
            avg(
              container_memory_working_set_bytes{
                %(cluster)s,
                %(namespace)s,
                pod=~"$verticalpodautoscaler-.*",
                container=~"$container",
                container!=""
              }
            ) by (%(clusterLabel)s, container)
          ||| % defaultFilters,

          memoryRequestOverTime: std.strReplace(self.cpuRequestOverTime, 'cpu', 'memory'),
          memoryLimitOverTime: std.strReplace(self.cpuLimitOverTime, 'cpu', 'memory'),
        };

        local clusterInLegend(str) = if $._config.vpa.clusterAggregation then '{{cluster}} - ' + str else str;

        local panels = {
          cpuResourceRecommendationsTable:
            mixinUtils.dashboards.tablePanel(
              'CPU Resource Recommendations',
              'short',
              [
                {
                  expr: queries.cpuRequests,
                },
                {
                  expr: queries.cpuLimits,
                },
                {
                  expr: queries.cpuRecommendationLowerBound,
                },
                {
                  expr: queries.cpuRecommendationTarget,
                },
                {
                  expr: queries.cpuRecommendationUpperBound,
                },
              ],
              description='CPU resource recommendations for VPAs.',
              sortBy={ name: 'Vertical Pod Autoscaler', desc: false },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions(
                  {
                    renameByName: {
                      cluster: 'Cluster',
                      verticalpodautoscaler: 'Vertical Pod Autoscaler',
                      namespace: 'Namespace',
                      container: 'Container',
                      'Value #A': 'Requests',
                      'Value #B': 'Limits',
                      'Value #C': 'Lower Bound',
                      'Value #D': 'Target',
                      'Value #E': 'Upper Bound',
                    },
                    indexByName: {
                      namespace: 0,
                      verticalpodautoscaler: 1,
                      container: 2,
                      'Value #A': 3,
                      'Value #B': 4,
                      'Value #C': 5,
                      'Value #D': 6,
                      'Value #E': 7,
                    },
                    excludeByName: {
                      cluster: !$._config.vpa.clusterAggregation,
                      Time: true,
                      job: true,
                      resource: true,
                    },
                  }
                ),
              ],
              overrides=[
                tbOverride.byName.new('Lower Bound') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbFieldConfig.defaults.custom.withCellOptions(
                    { type: 'color-background' }
                  ) +
                  tbStandardOptions.color.withMode('fixed') +
                  tbStandardOptions.color.withFixedColor('dark-red') +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic')
                ),
                tbOverride.byName.new('Target') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbFieldConfig.defaults.custom.withCellOptions(
                    { type: 'color-background' }
                  ) +
                  tbStandardOptions.color.withMode('fixed') +
                  tbStandardOptions.color.withFixedColor('yellow') +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic')
                ),
                tbOverride.byName.new('Upper Bound') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbFieldConfig.defaults.custom.withCellOptions(
                    { type: 'color-background' }
                  ) +
                  tbStandardOptions.color.withMode('fixed') +
                  tbStandardOptions.color.withFixedColor('green') +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic')
                ),
              ],
            ),

          memoryResourceRecommendationsTable:
            mixinUtils.dashboards.tablePanel(
              'Memory Resource Recommendations',
              'bytes',
              [
                {
                  expr: queries.memoryRequests,
                },
                {
                  expr: queries.memoryLimits,
                },
                {
                  expr: queries.memoryRecommendationLowerBound,
                },
                {
                  expr: queries.memoryRecommendationTarget,
                },
                {
                  expr: queries.memoryRecommendationUpperBound,
                },
              ],
              description='Memory resource recommendations for VPAs.',
              sortBy={ name: 'Vertical Pod Autoscaler', desc: false },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions(
                  {
                    renameByName: {
                      cluster: 'Cluster',
                      verticalpodautoscaler: 'Vertical Pod Autoscaler',
                      namespace: 'Namespace',
                      container: 'Container',
                      'Value #A': 'Requests',
                      'Value #B': 'Limits',
                      'Value #C': 'Lower Bound',
                      'Value #D': 'Target',
                      'Value #E': 'Upper Bound',
                    },
                    indexByName: {
                      namespace: 0,
                      verticalpodautoscaler: 1,
                      container: 2,
                      'Value #A': 3,
                      'Value #B': 4,
                      'Value #C': 5,
                      'Value #D': 6,
                      'Value #E': 7,
                    },
                    excludeByName: {
                      cluster: !$._config.vpa.clusterAggregation,
                      Time: true,
                      job: true,
                      resource: true,
                    },
                  }
                ),
              ],
              overrides=[
                tbOverride.byName.new('Lower Bound') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbFieldConfig.defaults.custom.withCellOptions(
                    { type: 'color-background' }
                  ) +
                  tbStandardOptions.color.withMode('fixed') +
                  tbStandardOptions.color.withFixedColor('dark-red') +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic')
                ),
                tbOverride.byName.new('Target') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbFieldConfig.defaults.custom.withCellOptions(
                    { type: 'color-background' }
                  ) +
                  tbStandardOptions.color.withMode('fixed') +
                  tbStandardOptions.color.withFixedColor('yellow') +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic')
                ),
                tbOverride.byName.new('Upper Bound') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbFieldConfig.defaults.custom.withCellOptions(
                    { type: 'color-background' }
                  ) +
                  tbStandardOptions.color.withMode('fixed') +
                  tbStandardOptions.color.withFixedColor('green') +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withMode('basic')
                ),
              ],
            ),

          cpuGuaranteedQosStat:
            mixinUtils.dashboards.statPanel(
              'CPU Guaranteed QoS',
              'short',
              [
                {
                  expr: queries.cpuRecommendationTargetOverTime,
                  legend: clusterInLegend('CPU Requests'),
                },
                {
                  expr: queries.cpuRecommendationTargetOverTime,
                  legend: clusterInLegend('CPU Limits'),
                },
              ],
              description='CPU Guaranteed QoS recommendations (requests = limits) for the selected VPA.',
              overrides=[
                statPanel.fieldOverride.byName.new(clusterInLegend('CPU Requests')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('yellow')
                ),
                statPanel.fieldOverride.byName.new(clusterInLegend('CPU Limits')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('yellow')
                ),
              ],
            ),

          cpuBurstableQosStat:
            mixinUtils.dashboards.statPanel(
              'CPU Burstable QoS',
              'short',
              [
                {
                  expr: queries.cpuRecommendationLowerBoundOverTime,
                  legend: clusterInLegend('CPU Requests'),
                },
                {
                  expr: queries.cpuRecommendationUpperBoundOverTime,
                  legend: clusterInLegend('CPU Limits'),
                },
              ],
              description='CPU Burstable QoS recommendations (requests < limits) for the selected VPA.',
              overrides=[
                statPanel.fieldOverride.byName.new(clusterInLegend('CPU Requests')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('red')
                ),
                statPanel.fieldOverride.byName.new(clusterInLegend('CPU Limits')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('green')
                ),
              ],
            ),

          memoryGuaranteedQosStat:
            mixinUtils.dashboards.statPanel(
              'Memory Guaranteed QoS',
              'bytes',
              [
                {
                  expr: queries.memoryRecommendationTargetOverTime,
                  legend: clusterInLegend('Memory Requests'),
                },
                {
                  expr: queries.memoryRecommendationTargetOverTime,
                  legend: clusterInLegend('Memory Limits'),
                },
              ],
              description='Memory Guaranteed QoS recommendations (requests = limits) for the selected VPA.',
              overrides=[
                statPanel.fieldOverride.byName.new(clusterInLegend('Memory Requests')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('yellow')
                ),
                statPanel.fieldOverride.byName.new(clusterInLegend('Memory Limits')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('yellow')
                ),
              ],
            ),

          memoryBurstableQosStat:
            mixinUtils.dashboards.statPanel(
              'Memory Burstable QoS',
              'bytes',
              [
                {
                  expr: queries.memoryRecommendationLowerBoundOverTime,
                  legend: clusterInLegend('Memory Requests'),
                },
                {
                  expr: queries.memoryRecommendationUpperBoundOverTime,
                  legend: clusterInLegend('Memory Limits'),
                },
              ],
              description='Memory Burstable QoS recommendations (requests < limits) for the selected VPA.',
              overrides=[
                statPanel.fieldOverride.byName.new(clusterInLegend('Memory Requests')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('red')
                ),
                statPanel.fieldOverride.byName.new(clusterInLegend('Memory Limits')) +
                statPanel.fieldOverride.byName.withPropertiesFromOptions(
                  statPanel.standardOptions.color.withMode('fixed') +
                  statPanel.standardOptions.color.withFixedColor('green')
                ),
              ],
            ),

          cpuRecommendationsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'VPA CPU Recommendations Over Time',
              'short',
              [
                {
                  expr: queries.cpuRecommendationLowerBoundOverTime,
                  legend: clusterInLegend('Lower Bound'),
                },
                {
                  expr: queries.cpuRecommendationTargetOverTime,
                  legend: clusterInLegend('Target'),
                },
                {
                  expr: queries.cpuRecommendationUpperBoundOverTime,
                  legend: clusterInLegend('Upper Bound'),
                },
                {
                  expr: queries.cpuUsageOverTime,
                  legend: clusterInLegend('Usage'),
                },
                {
                  expr: queries.cpuRequestOverTime,
                  legend: clusterInLegend('Requests'),
                },
                {
                  expr: queries.cpuLimitOverTime,
                  legend: clusterInLegend('Limits'),
                },
              ],
              calcs=['lastNotNull', 'mean', 'max'],
              description='CPU recommendations, usage, requests, and limits over time for the selected VPA.',
              fillOpacity=0,
            ),

          memoryRecommendationsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'VPA Memory Recommendations Over Time',
              'bytes',
              [
                {
                  expr: queries.memoryRecommendationLowerBoundOverTime,
                  legend: clusterInLegend('Lower Bound'),
                },
                {
                  expr: queries.memoryRecommendationTargetOverTime,
                  legend: clusterInLegend('Target'),
                },
                {
                  expr: queries.memoryRecommendationUpperBoundOverTime,
                  legend: clusterInLegend('Upper Bound'),
                },
                {
                  expr: queries.memoryUsageOverTime,
                  legend: clusterInLegend('Usage'),
                },
                {
                  expr: queries.memoryRequestOverTime,
                  legend: clusterInLegend('Requests'),
                },
                {
                  expr: queries.memoryLimitOverTime,
                  legend: clusterInLegend('Limits'),
                },
              ],
              calcs=['lastNotNull', 'mean', 'max'],
              description='Memory recommendations, usage, requests, and limits over time for the selected VPA.',
              fillOpacity=0,
            ),
        };

        local rows =
          [
            row.new('Namespace $namespace Summary') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.cpuResourceRecommendationsTable,
              panels.memoryResourceRecommendationsTable,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=1
          ) +
          [
            row.new('$verticalpodautoscaler / $container') +
            row.gridPos.withX(0) +
            row.gridPos.withY(17) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1) +
            row.withRepeat('container'),
          ] +
          grid.makeGrid(
            [
              panels.cpuGuaranteedQosStat,
              panels.cpuBurstableQosStat,
              panels.memoryGuaranteedQosStat,
              panels.memoryBurstableQosStat,
            ],
            panelWidth=6,
            panelHeight=5,
            startY=18
          ) +
          grid.makeGrid(
            [
              panels.cpuRecommendationsTimeSeries,
              panels.memoryRecommendationsTimeSeries,
            ],
            panelWidth=12,
            panelHeight=8,
            startY=23
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / Vertical Pod Autoscaler',
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
