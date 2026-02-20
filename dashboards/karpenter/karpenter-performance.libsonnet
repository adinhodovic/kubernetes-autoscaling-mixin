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
  grafanaDashboards+::
    if $._config.karpenter.enabled then {
      'kubernetes-autoscaling-mixin-karpenter-perf.json':

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.job,
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

          // Scheduler
          schedulerQueueDepth: |||
            sum(
              karpenter_scheduler_queue_depth{
                %(base)s
              }
            ) by (job)
          ||| % defaultFilters,

          schedulerSchedulingDurationP50: |||
            histogram_quantile(0.50,
              sum(
                rate(
                  karpenter_scheduler_scheduling_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,
          schedulerSchedulingDurationP95: std.strReplace(queries.schedulerSchedulingDurationP50, '0.50', '0.95'),
          schedulerSchedulingDurationP99: std.strReplace(queries.schedulerSchedulingDurationP50, '0.50', '0.99'),

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
                rate(
                  karpenter_interruption_message_queue_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                ) > 0
              ) by (job, le)
            )
          ||| % defaultFilters,
          interuptionDurationP95: std.strReplace(queries.interuptionDurationP50, '0.50', '0.95'),
          interuptionDurationP99: std.strReplace(queries.interuptionDurationP50, '0.50', '0.99'),

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
                controller_runtime_reconcile_total{
                  %(base)s
                }[$__rate_interval]
              )
            ) by (job, controller)
          ||| % defaultFilters,

          controllerResult: |||
            sum(
              irate(
                controller_runtime_reconcile_total{
                  %(base)s
                }[$__rate_interval]
              )
            ) by (job, result)
          ||| % defaultFilters,
        };

        local panels = {
          // Summary
          clusterStateSyncedStat:
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

          clusterStateNodeCountStat:
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

          cloudProviderErrorsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Cloud Provider Errors',
              'short',
              queries.cloudProviderErrors,
              '{{ provider }} - {{ controller }} - {{ method }} - {{ error }}',
              description='The number of cloud provider errors over time.',
            ),

          // Node Termination & Pod Startup
          nodeTerminationDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Termination Duration',
              's',
              [
                {
                  expr: queries.nodeTerminationP50Duration,
                  legend: 'P50',
                },
                {
                  expr: queries.nodeTerminationP95Duration,
                  legend: 'P95',
                },
                {
                  expr: queries.nodeTerminationP99Duration,
                  legend: 'P99',
                },
              ],
              description='The duration to terminate nodes.',
            ),

          podStartupDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Pods Startup Duration',
              's',
              [
                {
                  expr: queries.podsStartupP50Duration,
                  legend: 'P50',
                },
                {
                  expr: queries.podsStartupP95Duration,
                  legend: 'P95',
                },
                {
                  expr: queries.podsStartupP99Duration,
                  legend: 'P99',
                },
              ],
              description='The duration for pods to start up.',
            ),

          // Scheduler
          schedulerQueueDepthTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scheduler Queue Depth',
              'short',
              queries.schedulerQueueDepth,
              'Queue Depth',
              description='The number of pending pods waiting to be scheduled.',
            ),

          schedulerSchedulingDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Scheduler Scheduling Duration',
              's',
              [
                {
                  expr: queries.schedulerSchedulingDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.schedulerSchedulingDurationP95,
                  legend: 'P95',
                },
                {
                  expr: queries.schedulerSchedulingDurationP99,
                  legend: 'P99',
                },
              ],
              description='The duration to simulate pod scheduling.',
            ),

          // Interruption Queue
          interruptionReceivedMessagesTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Interruption Received Messages',
              'short',
              queries.interruptionReceivedMessages,
              '{{ message_type }}',
              description='The number of interruption messages received.',
            ),

          interruptionDeletedMessagesTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Interruption Deleted Messages',
              'short',
              queries.interruptionDeletedMessages,
              'Deleted Messages',
              description='The number of interruption messages deleted.',
            ),

          interuptionDurationTimeSeries:
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
              description='The duration for interruption message processing.',
            ),

          // Work Queue
          workQueueDepthTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Work Queue Depth',
              'short',
              queries.workQueueDepth,
              'Queue Depth',
              description='The depth of the work queue.',
            ),

          workQueueInQueueDurationTimeSeries:
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
              description='The duration items spend in the work queue.',
            ),

          workQueueWorkDurationTimeSeries:
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
              description='The duration to process work queue items.',
            ),

          // Controller
          controllerReconcileTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Controller Reconcile',
              'ops',
              queries.controllerReconcile,
              '{{ controller }}',
              description='The ops of controller reconciliation.',
              stack='normal'
            ),

          controllerResultTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Controller Result',
              'ops',
              queries.controllerResult,
              '{{ result }}',
              description='The result of controller reconciliations.',
              stack='normal'
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
              panels.clusterStateSyncedStat,
              panels.clusterStateNodeCountStat,
            ],
            panelWidth=3,
            panelHeight=6,
            startY=1
          ) +
          [
            panels.cloudProviderErrorsTimeSeries +
            row.gridPos.withX(12) +
            row.gridPos.withY(1) +
            row.gridPos.withW(18) +
            row.gridPos.withH(6),
          ] +
          grid.makeGrid(
            [
              panels.nodeTerminationDurationTimeSeries,
              panels.podStartupDurationTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=7
          ) +
          [
            row.new('Scheduler') +
            row.gridPos.withX(0) +
            row.gridPos.withY(13) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.schedulerQueueDepthTimeSeries,
              panels.schedulerSchedulingDurationTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=14
          ) +
          [
            row.new('Interruption Queue') +
            row.gridPos.withX(0) +
            row.gridPos.withY(20) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.interruptionReceivedMessagesTimeSeries,
              panels.interruptionDeletedMessagesTimeSeries,
              panels.interuptionDurationTimeSeries,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=21
          ) +
          [
            row.new('Work Queue') +
            row.gridPos.withX(0) +
            row.gridPos.withY(27) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.workQueueDepthTimeSeries,
              panels.workQueueInQueueDurationTimeSeries,
              panels.workQueueWorkDurationTimeSeries,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=28
          ) +
          [
            row.new('Controller') +
            row.gridPos.withX(0) +
            row.gridPos.withY(34) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.controllerReconcileTimeSeries,
              panels.controllerResultTimeSeries,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=35
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
    } else {},
}
