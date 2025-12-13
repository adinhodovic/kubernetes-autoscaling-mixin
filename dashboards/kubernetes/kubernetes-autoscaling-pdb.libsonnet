local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-pdb.json':

      local defaultVariables = util.variables($._config);

      local pdbVar = g.dashboard.variable.query.new(
        'pdb',
        'label_values(kube_poddisruptionbudget_status_current_healthy{cluster="$cluster", namespace=~"$namespace"}, poddisruptionbudget)'
      ) +
      g.dashboard.variable.query.withDatasourceFromVariable(defaultVariables.datasource) +
      g.dashboard.variable.query.withSort() +
      g.dashboard.variable.query.generalOptions.withLabel('PDB') +
      g.dashboard.variable.query.selectionOptions.withMulti(true) +
      g.dashboard.variable.query.selectionOptions.withIncludeAll(true) +
      g.dashboard.variable.query.refresh.onLoad() +
      g.dashboard.variable.query.refresh.onTime();

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        pdbVar,
      ];

      local queries = {
        disruptionsAllowed: |||
          round(
            sum(
              kube_poddisruptionbudget_status_pod_disruptions_allowed{
                cluster="$cluster",
                namespace=~"$namespace",
                poddisruptionbudget=~"$pdb"
              }
            )
          )
        |||,

        desiredHealthy: |||
          round(
            sum(
              kube_poddisruptionbudget_status_desired_healthy{
                cluster="$cluster",
                namespace=~"$namespace",
                poddisruptionbudget=~"$pdb"
              }
            )
          )
        |||,

        currentlyHealthy: |||
          round(
            sum(
              kube_poddisruptionbudget_status_current_healthy{
                cluster="$cluster",
                namespace=~"$namespace",
                poddisruptionbudget=~"$pdb"
              }
            )
          )
        |||,

        expectedPods: |||
          round(
            sum(
              kube_poddisruptionbudget_status_expected_pods{
                cluster="$cluster",
                namespace=~"$namespace",
                poddisruptionbudget=~"$pdb"
              }
            )
          )
        |||,

        disruptionsAllowedByPdb: |||
          round(
            sum(
              kube_poddisruptionbudget_status_pod_disruptions_allowed{
                cluster="$cluster",
                namespace=~"$namespace"
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        |||,

        desiredHealthyByPdb: |||
          round(
            sum(
              kube_poddisruptionbudget_status_desired_healthy{
                cluster="$cluster",
                namespace=~"$namespace"
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        |||,

        currentlyHealthyByPdb: |||
          round(
            sum(
              kube_poddisruptionbudget_status_current_healthy{
                cluster="$cluster",
                namespace=~"$namespace"
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        |||,

        expectedPodsByPdb: |||
          round(
            sum(
              kube_poddisruptionbudget_status_expected_pods{
                cluster="$cluster",
                namespace=~"$namespace"
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        |||,
      };

      local panels = {
        disruptionsAllowed:
          mixinUtils.dashboards.statPanel(
            'Disruptions Allowed',
            'short',
            queries.disruptionsAllowed,
            description='The number of pod disruptions allowed for the selected PDB.',
          ),

        desiredHealthy:
          mixinUtils.dashboards.statPanel(
            'Desired Healthy',
            'short',
            queries.desiredHealthy,
            description='The desired number of healthy pods for the selected PDB.',
          ),

        currentlyHealthy:
          mixinUtils.dashboards.statPanel(
            'Currently Healthy',
            'short',
            queries.currentlyHealthy,
            description='The current number of healthy pods for the selected PDB.',
          ),

        expectedPods:
          mixinUtils.dashboards.statPanel(
            'Expected Pods',
            'short',
            queries.expectedPods,
            description='The expected number of pods for the selected PDB.',
          ),

        disruptionsAllowedByPdb:
          mixinUtils.dashboards.timeSeriesPanel(
            'Disruptions Allowed by PDB',
            'short',
            queries.disruptionsAllowedByPdb,
            '{{ poddisruptionbudget }}',
            calcs=['lastNotNull', 'mean', 'max'],
            description='The number of pod disruptions allowed per PDB.',
          ),

        desiredHealthyByPdb:
          mixinUtils.dashboards.timeSeriesPanel(
            'Desired Healthy by PDB',
            'short',
            queries.desiredHealthyByPdb,
            '{{ poddisruptionbudget }}',
            calcs=['lastNotNull', 'mean', 'max'],
            description='The desired number of healthy pods per PDB.',
          ),

        currentlyHealthyByPdb:
          mixinUtils.dashboards.timeSeriesPanel(
            'Currently Healthy by PDB',
            'short',
            queries.currentlyHealthyByPdb,
            '{{ poddisruptionbudget }}',
            calcs=['lastNotNull', 'mean', 'max'],
            description='The current number of healthy pods per PDB.',
          ),

        expectedPodsByPdb:
          mixinUtils.dashboards.timeSeriesPanel(
            'Expected Pods by PDB',
            'short',
            queries.expectedPodsByPdb,
            '{{ poddisruptionbudget }}',
            calcs=['lastNotNull', 'mean', 'max'],
            description='The expected number of pods per PDB.',
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
            panels.disruptionsAllowed,
            panels.desiredHealthy,
            panels.currentlyHealthy,
            panels.expectedPods,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          row.new('Pod Disruption Budgets') +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.disruptionsAllowedByPdb,
            panels.desiredHealthyByPdb,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=6
        ) +
        grid.makeGrid(
          [
            panels.currentlyHealthyByPdb,
            panels.expectedPodsByPdb,
          ],
          panelWidth=12,
          panelHeight=6,
          startY=12
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / PDB',
      ) +
      dashboard.withDescription('A dashboard that monitors Pod Disruption Budgets. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
      dashboard.withUid($._config.pdbDashboardUid) +
      dashboard.withTags($._config.tags + ['pdb']) +
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
