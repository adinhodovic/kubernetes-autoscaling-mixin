local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

// Stat panel helpers
local stat = g.panel.stat;
local stStandardOptions = stat.standardOptions;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-karpenter-perf.json':
      if !$._config.karpenter.enabled then {} else

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.jobSimple,
        ];

        local defaultFilters = util.filters($._config);
        local queries = {
          // Summary
          clusterStateSynced: |||
            sum(
              karpenter_cluster_state_synced{
                %(base)s
              }
            ) by (job)
          ||| % defaultFilters,

          clusterStateNodeCount: |||
            sum(
              karpenter_cluster_state_node_count{
                %(base)s
              }
            ) by (job)
          ||| % defaultFilters,

          cloudProviderErrors: |||
            round(
              sum(
                increase(
                  karpenter_cloudprovider_errors_total{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (job, provider, controller, method, error)
            )
          ||| % defaultFilters,

          // Node Termination
          nodeTerminationP50Duration: |||
            max(
              karpenter_nodes_termination_duration_seconds{
                %(base)s,
                quantile="0.5"
              }
            )
          ||| % defaultFilters,

          nodeTerminationP95Duration: |||
            max(
              karpenter_nodes_termination_duration_seconds{
                %(base)s,
                quantile="0.95"
              }
            )
          ||| % defaultFilters,

          nodeTerminationP99Duration: |||
            max(
              karpenter_nodes_termination_duration_seconds{
                %(base)s,
                quantile="0.99"
              }
            )
          ||| % defaultFilters,

          // Pod Startup
          podsStartupP50Duration: |||
            max(
              karpenter_pods_startup_duration_seconds{
                %(base)s,
                quantile="0.5"
              }
            )
          ||| % defaultFilters,

          podsStartupP95Duration: |||
            max(
              karpenter_pods_startup_duration_seconds{
                %(base)s,
                quantile="0.95"
              }
            )
          ||| % defaultFilters,

          podsStartupP99Duration: |||
            max(
              karpenter_pods_startup_duration_seconds{
                %(base)s,
                quantile="0.99"
              }
            )
          ||| % defaultFilters,

          // Interruption Queue
          interruptionReceivedMessages: |||
            sum(
              increase(
                karpenter_interruption_received_messages_total{
                  %(base)s
                }[$__rate_interval]
              )
            ) by (job, message_type)
          ||| % defaultFilters,

          interruptionDeletedMessages: |||
            sum(
              increase(
                karpenter_interruption_deleted_messages_total{
                  %(base)s
                }[$__rate_interval]
              )
            ) by (job)
          ||| % defaultFilters,

          interuptionDurationP50: |||
            histogram_quantile(0.50,
              sum(
                irate(
                  karpenter_interruption_message_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          interuptionDurationP95: |||
            histogram_quantile(0.95,
              sum(
                irate(
                  karpenter_interruption_message_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          interuptionDurationP99: |||
            histogram_quantile(0.99,
              sum(
                irate(
                  karpenter_interruption_message_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          // Work Queue
          workQueueDepth: |||
            sum(
              karpenter_workqueue_depth{
                %(base)s
              }
            ) by (job)
          ||| % defaultFilters,

          workQueueInQueueDurationP50: |||
            histogram_quantile(0.50,
              sum(
                irate(
                  karpenter_workqueue_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          workQueueInQueueDurationP95: |||
            histogram_quantile(0.95,
              sum(
                irate(
                  karpenter_workqueue_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          workQueueInQueueDurationP99: |||
            histogram_quantile(0.99,
              sum(
                irate(
                  karpenter_workqueue_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          workQueueWorkDurationP50: |||
            histogram_quantile(0.50,
              sum(
                irate(
                  karpenter_workqueue_work_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          workQueueWorkDurationP95: |||
            histogram_quantile(0.95,
              sum(
                irate(
                  karpenter_workqueue_work_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          workQueueWorkDurationP99: |||
            histogram_quantile(0.99,
              sum(
                irate(
                  karpenter_workqueue_work_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,

          // Controller
          controllerReconcile: |||
            sum(
              irate(
                karpenter_controller_runtime_reconcile_time_seconds_sum{
                  %(base)s
                }[$__rate_interval]
              )
            ) by (job, controller, result)
            /
            sum(
              irate(
                karpenter_controller_runtime_reconcile_time_seconds_count{
                  %(base)s
                }[$__rate_interval]
              )
            ) by (job, controller, result)
          ||| % defaultFilters,
        };

        local panels = {
          // Summary
          clusterStateSynced:
            mixinUtils.dashboards.statPanel(
              'Cluster State Synced',
              'short',
              queries.clusterStateSynced,
              description='Indicates whether the cluster state is synced.',
              steps=[
                stStandardOptions.threshold.step.withValue(0) +
                stStandardOptions.threshold.step.withColor('red'),
                stStandardOptions.threshold.step.withValue(0.1) +
                stStandardOptions.threshold.step.withColor('green'),
              ],
              mappings=[
                stStandardOptions.mapping.ValueMap.withType() +
                stStandardOptions.mapping.ValueMap.withOptions(
                  {
                    '0': { text: 'No', color: 'red' },
                    '1': { text: 'Yes', color: 'green' },
                  }
                ),
              ],
            ),

          clusterStateNodeCount:
            mixinUtils.dashboards.statPanel(
              'Cluster State Node Count',
              'short',
              queries.clusterStateNodeCount,
              description='The number of nodes in the cluster state.',
              steps=[
                stStandardOptions.threshold.step.withValue(0) +
                stStandardOptions.threshold.step.withColor('red'),
                stStandardOptions.threshold.step.withValue(0.1) +
                stStandardOptions.threshold.step.withColor('green'),
              ],
            ),

          cloudProviderErrors:
            mixinUtils.dashboards.timeSeriesPanel(
              'Cloud Provider Errors',
              'short',
              queries.cloudProviderErrors,
              '{{ provider }} - {{ controller }} - {{ method }} - {{ error }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The number of cloud provider errors over time.',
            ),

          // Node Termination & Pod Startup
          nodeTerminationDuration:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Termination Duration',
              's',
              [
                {
                  expr: queries.nodeTerminationP50Duration,
                  legend: 'P50',
                  interval: '1m',
                },
                {
                  expr: queries.nodeTerminationP95Duration,
                  legend: 'P95',
                  interval: '1m',
                },
                {
                  expr: queries.nodeTerminationP99Duration,
                  legend: 'P99',
                  interval: '1m',
                },
              ],
              calcs=['mean', 'max'],
              description='The duration to terminate nodes.',
            ),

          podStartupDuration:
            mixinUtils.dashboards.timeSeriesPanel(
              'Pods Startup Duration',
              's',
              [
                {
                  expr: queries.podsStartupP50Duration,
                  legend: 'P50',
                  interval: '1m',
                },
                {
                  expr: queries.podsStartupP95Duration,
                  legend: 'P95',
                  interval: '1m',
                },
                {
                  expr: queries.podsStartupP99Duration,
                  legend: 'P99',
                  interval: '1m',
                },
              ],
              calcs=['lastNotNull', 'mean', 'max'],
              description='The duration for pods to start up.',
            ),

          // Interruption Queue
          interruptionReceivedMessages:
            mixinUtils.dashboards.timeSeriesPanel(
              'Interruption Received Messages',
              'short',
              queries.interruptionReceivedMessages,
              '{{ message_type }}',
              calcs=['lastNotNull', 'mean'],
              description='The number of interruption messages received.',
            ),

          interruptionDeletedMessages:
            mixinUtils.dashboards.timeSeriesPanel(
              'Interruption Deleted Messages',
              'short',
              queries.interruptionDeletedMessages,
              'Deleted Messages',
              calcs=['lastNotNull', 'mean'],
              description='The number of interruption messages deleted.',
            ),

          interuptionDuration:
            mixinUtils.dashboards.timeSeriesPanel(
              'Interruption Duration',
              's',
              [
                {
                  expr: queries.interuptionDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.interuptionDurationP95,
                  legend: 'P95',
                },
                {
                  expr: queries.interuptionDurationP99,
                  legend: 'P99',
                },
              ],
              calcs=['mean', 'max'],
              description='The duration for interruption message processing.',
            ),

          // Work Queue
          workQueueDepth:
            mixinUtils.dashboards.timeSeriesPanel(
              'Work Queue Depth',
              'short',
              queries.workQueueDepth,
              'Queue Depth',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The depth of the work queue.',
            ),

          workQueueInQueueDuration:
            mixinUtils.dashboards.timeSeriesPanel(
              'Work Queue In Queue Duration',
              's',
              [
                {
                  expr: queries.workQueueInQueueDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.workQueueInQueueDurationP95,
                  legend: 'P95',
                },
                {
                  expr: queries.workQueueInQueueDurationP99,
                  legend: 'P99',
                },
              ],
              calcs=['mean', 'max'],
              description='The duration items spend in the work queue.',
            ),

          workQueueWorkDuration:
            mixinUtils.dashboards.timeSeriesPanel(
              'Work Queue Work Duration',
              's',
              [
                {
                  expr: queries.workQueueWorkDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.workQueueWorkDurationP95,
                  legend: 'P95',
                },
                {
                  expr: queries.workQueueWorkDurationP99,
                  legend: 'P99',
                },
              ],
              calcs=['mean', 'max'],
              description='The duration to process work queue items.',
            ),

          // Controller
          controllerReconcile:
            mixinUtils.dashboards.timeSeriesPanel(
              'Controller Reconcile Duration',
              's',
              queries.controllerReconcile,
              '{{ controller }} - {{ result }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The average duration of controller reconciliation.',
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
              panels.clusterStateSynced,
              panels.clusterStateNodeCount,
            ],
            panelWidth=12,
            panelHeight=4,
            startY=1
          ) +
          grid.makeGrid(
            [
              panels.cloudProviderErrors,
              panels.nodeTerminationDuration,
              panels.podStartupDuration,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=5
          ) +
          [
            row.new('Interruption Queue') +
            row.gridPos.withX(0) +
            row.gridPos.withY(11) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.interruptionReceivedMessages,
              panels.interruptionDeletedMessages,
              panels.interuptionDuration,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=12
          ) +
          [
            row.new('Work Queue') +
            row.gridPos.withX(0) +
            row.gridPos.withY(18) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.workQueueDepth,
              panels.workQueueInQueueDuration,
              panels.workQueueWorkDuration,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=19
          ) +
          [
            row.new('Controller') +
            row.gridPos.withX(0) +
            row.gridPos.withY(25) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.controllerReconcile,
            ],
            panelWidth=24,
            panelHeight=6,
            startY=26
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / Karpenter / Performance',
        ) +
        dashboard.withDescription('A dashboard that monitors Karpenter performance metrics. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.karpenterPerformanceDashboardUid) +
        dashboard.withTags($._config.tags + ['karpenter']) +
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
