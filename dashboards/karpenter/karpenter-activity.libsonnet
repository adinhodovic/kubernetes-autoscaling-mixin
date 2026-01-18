local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-karpenter-act.json':
      if !$._config.karpenter.enabled then {} else

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.job,
          defaultVariables.nodepoolSimple,
        ];

        local defaultFilters = util.filters($._config);
        local queries = {
          // Node Activity
          nodesCreatedByNodePool: |||
            round(
              sum(
                increase(
                  karpenter_nodes_created_total{
                    %(base)s,
                    %(nodepool)s
                  }[$__rate_interval]
                )
              ) by (nodepool)
            )
          ||| % defaultFilters,

          nodesTerminatedByNodePool: |||
            round(
              sum(
                increase(
                  karpenter_nodes_terminated_total{
                    %(base)s,
                    %(nodepool)s
                  }[$__rate_interval]
                )
              ) by (nodepool)
            )
          ||| % defaultFilters,

          // NodeClaim Activity
          nodeClaimsCreatedByNodePool: |||
            round(
              sum(
                increase(
                  karpenter_nodeclaims_created_total{
                    %(base)s,
                    %(nodepool)s
                  }[$__rate_interval]
                )
              ) by (nodepool)
            )
          ||| % defaultFilters,

          nodeClaimsTerminatedByNodePool: |||
            round(
              sum(
                increase(
                  karpenter_nodeclaims_terminated_total{
                    %(base)s,
                    %(nodepool)s
                  }[$__rate_interval]
                )
              ) by (nodepool)
            )
          ||| % defaultFilters,

          nodeClaimsTerminationP50Duration: |||
            histogram_quantile(0.50,
              sum(
                rate(
                  karpenter_nodeclaims_termination_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (job, le)
            )
          ||| % defaultFilters,
          nodeClaimsTerminationP95Duration: std.strReplace(queries.nodeClaimsTerminationP50Duration, '0.50', '0.95'),
          nodeClaimsTerminationP99Duration: std.strReplace(queries.nodeClaimsTerminationP50Duration, '0.50', '0.99'),

          nodesVoluntaryDisruptionDecisions: |||
            round(
              sum(
                increase(
                  karpenter_voluntary_disruption_decisions_total{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (decision, reason)
            )
          ||| % defaultFilters,

          nodesVoluntaryDisruptionEligible: |||
            round(
              sum(
                karpenter_voluntary_disruption_eligible_nodes{
                  %(base)s
                }
              ) by (reason)
            )
          ||| % defaultFilters,

          nodesVoluntaryDisruptionQueueFailures: |||
            round(
              sum(
                increase(
                  karpenter_voluntary_disruption_queue_failures_total{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (job)
            )
          ||| % defaultFilters,

          nodesVoluntaryDisruptionEvaluationP50Duration: |||
            histogram_quantile(0.50,
              sum(
                rate(
                  karpenter_voluntary_disruption_decision_evaluation_duration_seconds_bucket{
                    %(base)s
                  }[$__rate_interval]
                )
              ) by (job, le)
            )
          ||| % defaultFilters,
          nodesVoluntaryDisruptionEvaluationP95Duration: std.strReplace(queries.nodesVoluntaryDisruptionEvaluationP50Duration, '0.50', '0.95'),
          nodesVoluntaryDisruptionEvaluationP99Duration: std.strReplace(queries.nodesVoluntaryDisruptionEvaluationP50Duration, '0.50', '0.99'),

          nodesDisrupted: |||
            round(
              sum(
                increase(
                  karpenter_nodeclaims_disrupted_total{
                    %(base)s,
                    %(nodepool)s
                  }[$__rate_interval]
                )
              ) by (nodepool, capacity_type, reason)
            )
          ||| % defaultFilters,

          // Pod Activity
          podStateByPhase: |||
            round(
              sum(
                karpenter_pods_state{
                  %(base)s
                }
              ) by (phase)
            )
          ||| % defaultFilters,

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
        };

        local panels = {
          // Node Activity
          nodesCreatedByNodePoolTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Created by Node Pool',
              'short',
              queries.nodesCreatedByNodePool,
              '{{ nodepool }}',
              description='The number of nodes created by node pool.',
              stack='normal'
            ),

          nodesTerminatedByNodePoolTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Terminated by Node Pool',
              'short',
              queries.nodesTerminatedByNodePool,
              '{{ nodepool }}',
              description='The number of nodes terminated by node pool.',
              stack='normal'
            ),

          // NodeClaim Activity
          nodeClaimsCreatedByNodePoolTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'NodeClaims Created by Node Pool',
              'short',
              queries.nodeClaimsCreatedByNodePool,
              '{{ nodepool }}',
              description='The number of nodeclaims created by node pool.',
              stack='normal'
            ),

          nodeClaimsTerminatedByNodePoolTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'NodeClaims Terminated by Node Pool',
              'short',
              queries.nodeClaimsTerminatedByNodePool,
              '{{ nodepool }}',
              description='The number of nodeclaims terminated by node pool.',
              stack='normal'
            ),

          nodeClaimsTerminationDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'NodeClaim Termination Duration',
              's',
              [
                {
                  expr: queries.nodeClaimsTerminationP50Duration,
                  legend: 'P50',
                },
                {
                  expr: queries.nodeClaimsTerminationP95Duration,
                  legend: 'P95',
                },
                {
                  expr: queries.nodeClaimsTerminationP99Duration,
                  legend: 'P99',
                },
              ],
              description='The duration to terminate nodeclaims.',
              fillOpacity=0
            ),

          nodesVoluntaryDisruptionDecisionsTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Disruption Decisions by Reason and Decision',
              'short',
              queries.nodesVoluntaryDisruptionDecisions,
              '{{ decision }} - {{ reason }}',
              description='The number of voluntary disruption decisions by reason and decision.',
              stack='normal'
            ),

          nodesVoluntaryDisruptionEligibleTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Eligible for Disruption by Reason',
              'short',
              queries.nodesVoluntaryDisruptionEligible,
              '{{ reason }}',
              description='The number of nodes eligible for voluntary disruption by reason.',
              stack='normal'
            ),

          nodesVoluntaryDisruptionQueueFailuresTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Voluntary Disruption Queue Failures',
              'short',
              queries.nodesVoluntaryDisruptionQueueFailures,
              'Queue Failures',
              description='The number of failed voluntary disruption attempts.',
            ),

          nodesVoluntaryDisruptionEvaluationDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Voluntary Disruption Evaluation Duration',
              's',
              [
                {
                  expr: queries.nodesVoluntaryDisruptionEvaluationP50Duration,
                  legend: 'P50',
                },
                {
                  expr: queries.nodesVoluntaryDisruptionEvaluationP95Duration,
                  legend: 'P95',
                },
                {
                  expr: queries.nodesVoluntaryDisruptionEvaluationP99Duration,
                  legend: 'P99',
                },
              ],
              description='The duration to evaluate voluntary disruption decisions.',
              fillOpacity=0
            ),

          nodesDisruptedTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Disrupted by Node Pool',
              'short',
              queries.nodesDisrupted,
              '{{ nodepool }} - {{ capacity_type }} - {{ reason }}',
              description='The number of nodes disrupted by node pool, capacity type, and reason.',
              stack='normal'
            ),

          // Pod Activity
          podStateByPhaseTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Pods by Phase',
              'short',
              queries.podStateByPhase,
              '{{ phase }}',
              description='The number of pods by phase.',
              stack='normal'
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
              fillOpacity=0
            ),
        };

        local rows =
          [
            row.new('Node Pool Activity') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.nodesCreatedByNodePoolTimeSeries,
              panels.nodesTerminatedByNodePoolTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=1
          ) +
          [
            row.new('NodeClaim Activity') +
            row.gridPos.withX(0) +
            row.gridPos.withY(7) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.nodeClaimsCreatedByNodePoolTimeSeries,
              panels.nodeClaimsTerminatedByNodePoolTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=8
          ) +
          grid.makeGrid(
            [
              panels.nodeClaimsTerminationDurationTimeSeries,
            ],
            panelWidth=24,
            panelHeight=6,
            startY=14
          ) +
          [
            row.new('Disruption Activity') +
            row.gridPos.withX(0) +
            row.gridPos.withY(20) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.nodesVoluntaryDisruptionDecisionsTimeSeries,
              panels.nodesVoluntaryDisruptionEligibleTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=21
          ) +
          grid.makeGrid(
            [
              panels.nodesVoluntaryDisruptionQueueFailuresTimeSeries,
              panels.nodesVoluntaryDisruptionEvaluationDurationTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=27
          ) +
          grid.makeGrid(
            [
              panels.nodesDisruptedTimeSeries,
            ],
            panelWidth=24,
            panelHeight=6,
            startY=33
          ) +
          [
            row.new('Pod Activity') +
            row.gridPos.withX(0) +
            row.gridPos.withY(39) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.podStateByPhaseTimeSeries,
              panels.podStartupDurationTimeSeries,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=40
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / Karpenter / Activity',
        ) +
        dashboard.withDescription('A dashboard that monitors Karpenter and focuses on Karpenter deletion/creation activity. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.karpenterActivityDashboardUid) +
        dashboard.withTags($._config.tags + ['karpenter']) +
        dashboard.withTimezone('utc') +
        dashboard.withEditable(true) +
        dashboard.time.withFrom('now-24h') +
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
