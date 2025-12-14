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
          defaultVariables.jobSimple,
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
          nodesCreatedByNodePool:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Created by Node Pool',
              'short',
              queries.nodesCreatedByNodePool,
              '{{ nodepool }}',
              calcs=['lastNotNull', 'mean'],
              description='The number of nodes created by node pool.',
            ),

          nodesTerminatedByNodePool:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Terminated by Node Pool',
              'short',
              queries.nodesTerminatedByNodePool,
              '{{ nodepool }}',
              calcs=['lastNotNull', 'mean'],
              description='The number of nodes terminated by node pool.',
            ),

          nodesVoluntaryDisruptionDecisions:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Disruption Decisions by Reason and Decision',
              'short',
              queries.nodesVoluntaryDisruptionDecisions,
              '{{ decision }} - {{ reason }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The number of voluntary disruption decisions by reason and decision.',
            ),

          nodesVoluntaryDisruptionEligible:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Eligible for Disruption by Reason',
              'short',
              queries.nodesVoluntaryDisruptionEligible,
              '{{ reason }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The number of nodes eligible for voluntary disruption by reason.',
            ),

          nodesDisrupted:
            mixinUtils.dashboards.timeSeriesPanel(
              'Nodes Disrupted by Node Pool',
              'short',
              queries.nodesDisrupted,
              '{{ nodepool }} - {{ capacity_type }} - {{ reason }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The number of nodes disrupted by node pool, capacity type, and reason.',
            ),

          // Pod Activity
          podStateByPhase:
            mixinUtils.dashboards.timeSeriesPanel(
              'Pods by Phase',
              'short',
              queries.podStateByPhase,
              '{{ phase }}',
              calcs=['lastNotNull', 'mean', 'max'],
              description='The number of pods by phase.',
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
              panels.nodesCreatedByNodePool,
              panels.nodesTerminatedByNodePool,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=1
          ) +
          grid.makeGrid(
            [
              panels.nodesVoluntaryDisruptionDecisions,
              panels.nodesVoluntaryDisruptionEligible,
              panels.nodesDisrupted,
            ],
            panelWidth=8,
            panelHeight=6,
            startY=7
          ) +
          [
            row.new('Pod Activity') +
            row.gridPos.withX(0) +
            row.gridPos.withY(13) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.podStateByPhase,
              panels.podStartupDuration,
            ],
            panelWidth=12,
            panelHeight=6,
            startY=14
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
