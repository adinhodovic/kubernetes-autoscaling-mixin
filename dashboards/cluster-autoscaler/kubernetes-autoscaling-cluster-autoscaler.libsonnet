local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

// Gauge panel helpers
local gauge = g.panel.gauge;
local gaStandardOptions = gauge.standardOptions;

// Table panel helpers
local tablePanel = g.panel.table;
local tbQueryOptions = tablePanel.queryOptions;
local tbStandardOptions = tablePanel.standardOptions;
local tbOverride = tbStandardOptions.override;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-ca.json':
      if !$._config.clusterAutoscaler.enabled then {} else

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.job,
        ];

        local defaultFilters = util.filters($._config);
        local queries = {
          totalNodes: |||
            round(
              sum(
                cluster_autoscaler_nodes_count{
                  %(base)s
                }
              )
            )
          ||| % defaultFilters,

          maxNodes: |||
            round(
              sum(
                cluster_autoscaler_max_nodes_count{
                  %(base)s
                }
              )
            )
          ||| % defaultFilters,

          nodeGroups: |||
            round(
              sum(
                cluster_autoscaler_node_groups_count{
                  %(base)s
                }
              )
            )
          ||| % defaultFilters,

          healthyNodes: |||
            round(
              sum(
                cluster_autoscaler_nodes_count{
                  %(base)s,
                  state="ready"
                }
              ) /
              sum(
                cluster_autoscaler_nodes_count{
                  %(base)s
                }
              ) * 100
            )
          ||| % defaultFilters,

          safeToScale: |||
            sum(
              cluster_autoscaler_cluster_safe_to_autoscale{
                %(base)s
              }
            )
          ||| % defaultFilters,

          numberUnscheduledPods: |||
            round(
              sum(
                cluster_autoscaler_unschedulable_pods_count{
                  %(base)s
                }
              )
            )
          ||| % defaultFilters,

          lastScaleDown: |||
            time() - max(
              cluster_autoscaler_last_activity{
                %(base)s,
                activity="scaleDown"
              }
            )
          ||| % defaultFilters,

          lastScaleUp: |||
            time() - max(
              cluster_autoscaler_last_activity{
                %(base)s,
                activity="scaleUp"
              }
            )
          ||| % defaultFilters,

          unschedulablePods: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_unschedulable_pods_count{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (type)
            )
          ||| % defaultFilters,

          evictedPods: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_evicted_pods_total{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (eviction_result)
            )
          ||| % defaultFilters,

          nodeActivity: |||
            round(
              sum(
                cluster_autoscaler_nodes_count{
                  %(base)s
                }
              ) by (state)
            )
          ||| % defaultFilters,

          unneededNodes: |||
            round(
              sum(
                cluster_autoscaler_unneeded_nodes_count{
                  %(base)s
                }
              )
            )
          ||| % defaultFilters,

          scaledUpNodes: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_scaled_up_nodes_total{
                    %(base)s
                  }[$__rate_interval]
                )
              )
            )
          ||| % defaultFilters,

          scaledDownNodes: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_scaled_down_nodes_total{
                    %(base)s
                  }[$__rate_interval]
                )
              )
            )
          ||| % defaultFilters,

          totalNodeGroups: |||
            count(
              cluster_autoscaler_node_group_min_count{
                %(base)s
              }
            )
          ||| % defaultFilters,

          atCapacityNodeGroupsPercent: |||
            round(
              count(
                (
                  avg by (node_group) (
                    cluster_autoscaler_node_group_target_count{
                      %(base)s
                    }
                  ) /
                  max by (node_group) (
                    cluster_autoscaler_node_group_max_count{
                      %(base)s
                    }
                  )
                ) >= 0.99
              ) /
              count(
                cluster_autoscaler_node_group_max_count{
                  %(base)s
                }
              ) * 100
            ) or vector(0)
          ||| % defaultFilters,

          healthyNodeGroupsPercent: |||
            round(
              sum(
                cluster_autoscaler_node_group_healthiness{
                  %(base)s
                }
              ) /
              count(
                cluster_autoscaler_node_group_healthiness{
                  %(base)s
                }
              ) * 100
            )
          ||| % defaultFilters,

          backoffNodeGroupsPercent: |||
            round(
              sum(
                cluster_autoscaler_node_group_backoff_status{
                  %(base)s
                }
              ) /
              count(
                cluster_autoscaler_node_group_backoff_status{
                  %(base)s
                }
              ) * 100
            )
          ||| % defaultFilters,

          nodeGroupMinNodes: |||
            min by (node_group) (
              cluster_autoscaler_node_group_min_count{
                %(base)s
              }
            )
          ||| % defaultFilters,

          nodeGroupTargetNodes: |||
            avg by (node_group) (
              cluster_autoscaler_node_group_target_count{
                %(base)s
              }
            )
          ||| % defaultFilters,

          nodeGroupMaxNodes: |||
            max by (node_group) (
              cluster_autoscaler_node_group_max_count{
                %(base)s
              }
            )
          ||| % defaultFilters,

          nodeGroupHealthiness: |||
            min by (node_group) (
              cluster_autoscaler_node_group_healthiness{
                %(base)s
              }
            )
          ||| % defaultFilters,

          nodeGroupBackoffStatus: |||
            max by (node_group) (
              cluster_autoscaler_node_group_backoff_status{
                %(base)s
              }
            )
          ||| % defaultFilters,
        };

        local panels = {
          totalNodesStat:
            mixinUtils.dashboards.statPanel(
              'Total Nodes',
              'short',
              queries.totalNodes,
              description='The total number of nodes in the cluster.',
            ),

          maxNodesStat:
            mixinUtils.dashboards.statPanel(
              'Max Nodes',
              'short',
              queries.maxNodes,
              description='The maximum number of nodes allowed in the cluster.',
            ),

          nodeGroupsStat:
            mixinUtils.dashboards.statPanel(
              'Node Groups',
              'short',
              queries.nodeGroups,
              description='The number of node groups in the cluster.',
            ),

          healthyNodesGauge:
            mixinUtils.dashboards.gaugePanel(
              'Healthy Nodes',
              'percent',
              queries.healthyNodes,
              description='The percentage of healthy nodes in the cluster.',
              min=0,
              max=100,
              steps=[
                gaStandardOptions.threshold.step.withValue(0) +
                gaStandardOptions.threshold.step.withColor('red'),
                gaStandardOptions.threshold.step.withValue(50) +
                gaStandardOptions.threshold.step.withColor('yellow'),
                gaStandardOptions.threshold.step.withValue(80) +
                gaStandardOptions.threshold.step.withColor('green'),
              ],
            ),

          safeToScaleStat:
            mixinUtils.dashboards.statPanel(
              'Safe to Scale',
              'short',
              queries.safeToScale,
              description='Indicates whether it is safe to scale the cluster.',
              steps=[
                gaStandardOptions.threshold.step.withValue(0) +
                gaStandardOptions.threshold.step.withColor('red'),
                gaStandardOptions.threshold.step.withValue(0.1) +
                gaStandardOptions.threshold.step.withColor('green'),
              ],
              mappings=[
                gaStandardOptions.mapping.ValueMap.withType() +
                gaStandardOptions.mapping.ValueMap.withOptions(
                  {
                    '0': { text: 'No', color: 'red' },
                    '1': { text: 'Yes', color: 'green' },
                  }
                ),
              ],
            ),

          numberUnscheduledPodsStat:
            mixinUtils.dashboards.statPanel(
              'Unscheduled Pods',
              'short',
              queries.numberUnscheduledPods,
              description='The number of unscheduled pods in the cluster.',
            ),

          lastScaleDownStat:
            mixinUtils.dashboards.statPanel(
              'Last Scale Down',
              's',
              queries.lastScaleDown,
              description='The timestamp of the last scale down activity.',
            ),

          lastScaleUpStat:
            mixinUtils.dashboards.statPanel(
              'Last Scale Up',
              's',
              queries.lastScaleUp,
              description='The timestamp of the last scale up activity.',
            ),

          podActivityTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Pod Activity',
              'short',
              [
                {
                  expr: queries.unschedulablePods,
                  legend: '{{ type }}',
                },
                {
                  expr: queries.evictedPods,
                  legend: 'Evicted / {{ eviction_result }}',
                },
              ],
              description='The activity of pods in the cluster.',
              stack='normal'
            ),

          nodeActivityTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Activity',
              'short',
              queries.nodeActivity,
              '{{ state }}',
              description='The activity of nodes in the cluster.',
              stack='normal'
            ),

          autoscalingActivityTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Autoscaling Activity',
              'short',
              [
                {
                  expr: queries.totalNodes,
                  legend: 'Total Nodes',
                },
                {
                  expr: queries.unneededNodes,
                  legend: 'Unneeded',
                },
                {
                  expr: queries.scaledUpNodes,
                  legend: 'Scaled Up',
                },
                {
                  expr: queries.scaledDownNodes,
                  legend: 'Scaled Down',
                },
              ],
              description='The autoscaling activity in the cluster.',
              fillOpacity=0,
            ),

          totalNodeGroupsStat:
            mixinUtils.dashboards.statPanel(
              'Total',
              'short',
              queries.totalNodeGroups,
              description='The total number of node groups in the cluster.',
            ),

          atCapacityNodeGroupsGauge:
            mixinUtils.dashboards.gaugePanel(
              'At Capacity',
              'percent',
              queries.atCapacityNodeGroupsPercent,
              description='The percentage of node groups at capacity.',
              min=0,
              max=100,
              steps=[
                gaStandardOptions.threshold.step.withValue(0) +
                gaStandardOptions.threshold.step.withColor('green'),
                gaStandardOptions.threshold.step.withValue(20) +
                gaStandardOptions.threshold.step.withColor('yellow'),
                gaStandardOptions.threshold.step.withValue(50) +
                gaStandardOptions.threshold.step.withColor('red'),
              ],
            ),

          healthyNodeGroupsGauge:
            mixinUtils.dashboards.gaugePanel(
              'Healthy',
              'percent',
              queries.healthyNodeGroupsPercent,
              description='The percentage of healthy node groups in the cluster.',
              min=0,
              max=100,
              steps=[
                gaStandardOptions.threshold.step.withValue(0) +
                gaStandardOptions.threshold.step.withColor('red'),
                gaStandardOptions.threshold.step.withValue(50) +
                gaStandardOptions.threshold.step.withColor('yellow'),
                gaStandardOptions.threshold.step.withValue(80) +
                gaStandardOptions.threshold.step.withColor('green'),
              ],
            ),

          backoffNodeGroupsGauge:
            mixinUtils.dashboards.gaugePanel(
              'Backoff',
              'percent',
              queries.backoffNodeGroupsPercent,
              description='The percentage of node groups in backoff state.',
              min=0,
              max=100,
              steps=[
                gaStandardOptions.threshold.step.withValue(0) +
                gaStandardOptions.threshold.step.withColor('green'),
                gaStandardOptions.threshold.step.withValue(20) +
                gaStandardOptions.threshold.step.withColor('yellow'),
                gaStandardOptions.threshold.step.withValue(50) +
                gaStandardOptions.threshold.step.withColor('red'),
              ],
            ),

          nodeGroupDetailsTable:
            mixinUtils.dashboards.tablePanel(
              'Node Group Details',
              'short',
              [
                { expr: queries.nodeGroupMinNodes, refId: 'MinNodes' },
                { expr: queries.nodeGroupTargetNodes, refId: 'Target' },
                { expr: queries.nodeGroupMaxNodes, refId: 'MaxNodes' },
                { expr: queries.nodeGroupHealthiness, refId: 'Healthy' },
                { expr: queries.nodeGroupBackoffStatus, refId: 'Backoff' },
              ],
              description='Details of node groups in the cluster. Requires --emit-per-nodegroup-metrics flag.',
              sortBy={ name: 'Group Name', desc: false },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('calculateField') +
                tbQueryOptions.transformation.withOptions({
                  alias: 'Utilization_Ratio',
                  mode: 'binary',
                  binary: {
                    left: 'Value #Target',
                    operator: '/',
                    right: 'Value #MaxNodes',
                  },
                }),
                tbQueryOptions.transformation.withId('calculateField') +
                tbQueryOptions.transformation.withOptions({
                  alias: 'Utilization',
                  mode: 'binary',
                  binary: {
                    left: 'Utilization_Ratio',
                    operator: '*',
                    right: '100',
                  },
                }),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions({
                  includeByName: {
                    node_group: true,
                    'Value #MinNodes': true,
                    'Value #Target': true,
                    'Value #MaxNodes': true,
                    Utilization: true,
                    'Value #Healthy': true,
                    'Value #Backoff': true,
                  },
                  renameByName: {
                    node_group: 'Group Name',
                    'Value #MinNodes': 'Min Nodes',
                    'Value #Target': 'Target',
                    'Value #MaxNodes': 'Max Nodes',
                    'Value #Healthy': 'Healthy',
                    'Value #Backoff': 'Backoff',
                  },
                  indexByName: {
                    node_group: 0,
                    'Value #MinNodes': 1,
                    'Value #Target': 2,
                    'Value #MaxNodes': 3,
                    Utilization: 4,
                    'Value #Healthy': 5,
                    'Value #Backoff': 6,
                  },
                }),
              ],
              overrides=[
                tbOverride.byName.new('Healthy') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withMappings([
                    tbStandardOptions.mapping.ValueMap.withType() +
                    tbStandardOptions.mapping.ValueMap.withOptions({
                      '0': { text: 'No' },
                      '1': { text: 'Yes' },
                    }),
                  ])
                ),
                tbOverride.byName.new('Backoff') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withMappings([
                    tbStandardOptions.mapping.ValueMap.withType() +
                    tbStandardOptions.mapping.ValueMap.withOptions({
                      '0': { text: 'No' },
                      '1': { text: 'Yes' },
                    }),
                  ])
                ),
                tbOverride.byName.new('Utilization') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('percent') +
                  tbStandardOptions.thresholds.withMode('absolute')
                ),
              ]
            ) +
            tablePanel.options.footer.withCountRows(true),
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
              panels.totalNodesStat,
              panels.maxNodesStat,
              panels.nodeGroupsStat,
              panels.healthyNodesGauge,
              panels.safeToScaleStat,
              panels.numberUnscheduledPodsStat,
              panels.lastScaleDownStat,
              panels.lastScaleUpStat,
            ],
            panelWidth=3,
            panelHeight=4,
            startY=1
          ) +
          [
            row.new('Activity') +
            row.gridPos.withX(0) +
            row.gridPos.withY(5) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.podActivityTimeSeries,
              panels.nodeActivityTimeSeries,
            ],
            panelWidth=12,
            panelHeight=8,
            startY=6
          ) +
          grid.makeGrid(
            [
              panels.autoscalingActivityTimeSeries,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=14
          ) +
          if $._config.clusterAutoscaler.nodeGroupMetricsEmitted then
            [
              row.new('Node Group Overview') +
              row.gridPos.withX(0) +
              row.gridPos.withY(22) +
              row.gridPos.withW(24) +
              row.gridPos.withH(1),
            ] +
            grid.makeGrid(
              [
                panels.totalNodeGroupsStat,
                panels.atCapacityNodeGroupsGauge,
                panels.healthyNodeGroupsGauge,
                panels.backoffNodeGroupsGauge,
              ],
              panelWidth=6,
              panelHeight=4,
              startY=23
            ) +
            grid.makeGrid(
              [
                panels.nodeGroupDetailsTable,
              ],
              panelWidth=24,
              panelHeight=12,
              startY=27
            )
          else [];

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / Cluster Autoscaler',
        ) +
        dashboard.withDescription('A dashboard that monitors the Cluster Autoscaler. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.clusterAutoscalerDashboardUid) +
        dashboard.withTags($._config.tags + ['cluster-autoscaler']) +
        dashboard.withTimezone('utc') +
        dashboard.withEditable(true) +
        dashboard.time.withFrom('now-6h') +
        dashboard.time.withTo('now') +
        dashboard.withVariables(variables) +
        dashboard.withLinks(
          mixinUtils.dashboards.dashboardLinks('Kubernetes / Autoscaling', $._config, dropdown=true)
        ) +
        dashboard.withPanels(
          rows
        ) +
        dashboard.withAnnotations(
          mixinUtils.dashboards.annotations($._config, defaultFilters)
        ),
  },
}
