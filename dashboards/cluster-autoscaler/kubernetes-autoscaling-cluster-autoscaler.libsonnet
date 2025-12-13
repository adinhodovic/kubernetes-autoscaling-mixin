local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

// Gauge panel helpers
local gauge = g.panel.gauge;
local gaStandardOptions = gauge.standardOptions;

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
            max(
              cluster_autoscaler_last_activity{
                %(base)s,
                activity="scaleDown"
              }
            ) * 1000
          ||| % defaultFilters,

          lastScaleUp: |||
            max(
              cluster_autoscaler_last_activity{
                %(base)s,
                activity="scaleUp"
              }
            ) * 1000
          ||| % defaultFilters,

          unschedulablePods: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_unschedulable_pods_count{
                    %(base)s
                  }[$__rate_interval]
                )
              )
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
              ) by (reason)
            )
          ||| % defaultFilters,

          nodeActivity: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_nodes_count{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (state)
            )
          ||| % defaultFilters,

          unneededNodes: |||
            round(
              sum(
                increase(
                  cluster_autoscaler_unneeded_nodes_count{
                    %(base)s
                  }[$__rate_interval]
                )
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
        };

        local panels = {
          totalNodes:
            mixinUtils.dashboards.statPanel(
              'Total Nodes',
              'short',
              queries.totalNodes,
              description='The total number of nodes in the cluster.',
            ),

          maxNodes:
            mixinUtils.dashboards.statPanel(
              'Max Nodes',
              'short',
              queries.maxNodes,
              description='The maximum number of nodes allowed in the cluster.',
            ),

          nodeGroups:
            mixinUtils.dashboards.statPanel(
              'Node Groups',
              'short',
              queries.nodeGroups,
              description='The number of node groups in the cluster.',
            ),

          healthyNodes:
            gauge.new('Healthy Nodes') +
            gauge.queryOptions.withTargets(
              g.query.prometheus.new('$datasource', queries.healthyNodes)
            ) +
            gaStandardOptions.withUnit('percent') +
            gaStandardOptions.withMin(0) +
            gaStandardOptions.withMax(100) +
            gauge.options.reduceOptions.withCalcs(['lastNotNull']) +
            gaStandardOptions.thresholds.withSteps([
              gaStandardOptions.threshold.step.withValue(0) +
              gaStandardOptions.threshold.step.withColor('red'),
              gaStandardOptions.threshold.step.withValue(50) +
              gaStandardOptions.threshold.step.withColor('yellow'),
              gaStandardOptions.threshold.step.withValue(80) +
              gaStandardOptions.threshold.step.withColor('green'),
            ]) +
            gauge.panelOptions.withDescription('The percentage of healthy nodes in the cluster.'),

          safeToScale:
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

          numberUnscheduledPods:
            mixinUtils.dashboards.statPanel(
              'Unscheduled Pods',
              'short',
              queries.numberUnscheduledPods,
              description='The number of unscheduled pods in the cluster.',
            ),

          lastScaleDown:
            mixinUtils.dashboards.statPanel(
              'Last Scale Down',
              'dateTimeAsIso',
              queries.lastScaleDown,
              description='The timestamp of the last scale down activity.',
            ),

          lastScaleUp:
            mixinUtils.dashboards.statPanel(
              'Last Scale Up',
              'dateTimeAsIso',
              queries.lastScaleUp,
              description='The timestamp of the last scale up activity.',
            ),

          podActivity:
            mixinUtils.dashboards.timeSeriesPanel(
              'Pod Activity',
              'short',
              [
                {
                  expr: queries.unschedulablePods,
                  legend: 'Unschedulable',
                },
                {
                  expr: queries.evictedPods,
                  legend: '{{ reason }}',
                },
              ],
              calcs=['lastNotNull', 'mean', 'max'],
              description='The activity of pods in the cluster.',
            ),

          nodeActivity:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Activity',
              'short',
              queries.nodeActivity,
              '{{ state }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The activity of nodes in the cluster.',
            ),

          autoscalingActivity:
            mixinUtils.dashboards.timeSeriesPanel(
              'Autoscaling Activity',
              'short',
              [
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
              calcs=['lastNotNull', 'mean', 'max'],
              description='The autoscaling activity in the cluster.',
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
              panels.totalNodes,
              panels.maxNodes,
              panels.nodeGroups,
              panels.healthyNodes,
              panels.safeToScale,
              panels.numberUnscheduledPods,
              panels.lastScaleDown,
              panels.lastScaleUp,
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
              panels.podActivity,
              panels.nodeActivity,
              panels.autoscalingActivity,
            ],
            panelWidth=8,
            panelHeight=8,
            startY=6
          );

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
