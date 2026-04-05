local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbOverride = tbStandardOptions.override;

{
  local dashboardName = 'karpenter-costs',
  grafanaDashboards+::
    if $._config.karpenter.enabled then {
      ['kubernetes-autoscaling-mixin-%s.json' % dashboardName]:

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.cluster,
          defaultVariables.job,
          defaultVariables.region,
          defaultVariables.zone,
          defaultVariables.arch,
          defaultVariables.os,
          defaultVariables.instanceType,
          defaultVariables.capacityType,
          defaultVariables.nodepool,
        ];

        local defaultFilters = util.filters($._config);
        local utilQueries = util.queries($._config);
        local queries = {
          activeNodeCounts: utilQueries.activeNodeCounts,
          activeNodeCountsByNodePool: utilQueries.activeNodeCountsByNodePool,
          activeNodeCountsByArch: utilQueries.activeNodeCountsByArch,
          activeSpotNodeCounts: utilQueries.activeSpotNodeCounts,
          activeSpotNodeCountsByNodePool: utilQueries.activeSpotNodeCountsByNodePool,
          priceEstimate: utilQueries.priceEstimate,
          onDemandPriceEstimate: utilQueries.onDemandPriceEstimate,
          spotPriceEstimate: utilQueries.spotPriceEstimate,

          estimatedHourlyCost: |||
            sum(
              (
                %(priceEstimate)s
              )
              * on (instance_type, capacity_type, zone)
              (
                %(activeNodeCounts)s
              )
            )
          ||| % {
            priceEstimate: queries.priceEstimate,
            activeNodeCounts: queries.activeNodeCounts,
          },

          estimatedHourlyCostByNodePool: |||
            sum by (nodepool) (
              (
                %(activeNodeCountsByNodePool)s
              )
              * on (instance_type, capacity_type, zone) group_left()
              (
                %(priceEstimate)s
              )
            )
          ||| % {
            priceEstimate: queries.priceEstimate,
            activeNodeCountsByNodePool: queries.activeNodeCountsByNodePool,
          },

          estimatedHourlyCostByCapacityType: |||
            sum by (capacity_type) (
              (
                %(priceEstimate)s
              )
              * on (instance_type, capacity_type, zone)
              (
                %(activeNodeCounts)s
              )
            )
          ||| % {
            priceEstimate: queries.priceEstimate,
            activeNodeCounts: queries.activeNodeCounts,
          },

          estimatedHourlyCostByArch: |||
            sum by (arch) (
              (
                %(activeNodeCountsByArch)s
              )
              * on (instance_type, capacity_type, zone) group_left()
              (
                %(priceEstimate)s
              )
            )
          ||| % {
            activeNodeCountsByArch: queries.activeNodeCountsByArch,
            priceEstimate: queries.priceEstimate,
          },

          estimatedHourlyCostByInstanceType: |||
            sum by (instance_type, capacity_type) (
              (
                %(priceEstimate)s
              )
              * on (instance_type, capacity_type, zone)
              (
                %(activeNodeCounts)s
              )
            )
          ||| % {
            priceEstimate: queries.priceEstimate,
            activeNodeCounts: queries.activeNodeCounts,
          },

          activeNodeCountByInstanceType: |||
            sum by (instance_type, capacity_type) (
              %(activeNodeCounts)s
            )
          ||| % { activeNodeCounts: queries.activeNodeCounts },

          estimatedMonthlyCostPerInstanceByInstanceType: |||
            avg by (instance_type, capacity_type) (
              %(priceEstimate)s
            ) * 730
          ||| % { priceEstimate: queries.priceEstimate },

          estimatedMonthlyRunRate: '(%s) * 730' % queries.estimatedHourlyCost,
          estimatedMonthlyRunRateByNodePool: '(%s) * 730' % queries.estimatedHourlyCostByNodePool,
          estimatedMonthlyRunRateByCapacityType: '(%s) * 730' % queries.estimatedHourlyCostByCapacityType,
          estimatedMonthlyRunRateByArch: '(%s) * 730' % queries.estimatedHourlyCostByArch,
          estimatedMonthlyRunRateByInstanceType: '(%s) * 730' % queries.estimatedHourlyCostByInstanceType,

          spotSavingsPerNode: '(%s) - (%s)' % [queries.onDemandPriceEstimate, queries.spotPriceEstimate],
          spotSavingsPercent: '(((%s) - (%s)) / (%s)) * 100' % [queries.onDemandPriceEstimate, queries.spotPriceEstimate, queries.onDemandPriceEstimate],

          estimatedSpotSavingsHourly: |||
            (
              sum(
                (
                  %(spotSavingsPerNode)s
                )
                * on (instance_type, zone)
                (
                  %(activeSpotNodeCounts)s
                )
              )
            ) or on() vector(0)
          ||| % {
            spotSavingsPerNode: queries.spotSavingsPerNode,
            activeSpotNodeCounts: queries.activeSpotNodeCounts,
          },

          estimatedSpotSavingsMonthly: '(%s) * 730' % queries.estimatedSpotSavingsHourly,
          estimatedSpotSavingsMonthlyByNodePool: '(%s) * 730' % queries.estimatedSpotSavingsByNodePool,

          estimatedSpotSavingsByNodePool: |||
            (
              0 * sum by (nodepool) (
                %(activeNodeCountsByNodePool)s
              )
            )
            +
            (
              sum by (nodepool) (
                (
                  %(activeSpotNodeCountsByNodePool)s
                )
                * on (instance_type, zone) group_left()
                (
                  %(spotSavingsPerNode)s
                )
              )
            )
          ||| % {
            activeNodeCountsByNodePool: queries.activeNodeCountsByNodePool,
            spotSavingsPerNode: queries.spotSavingsPerNode,
            activeSpotNodeCountsByNodePool: queries.activeSpotNodeCountsByNodePool,
          },

          spotSavingsComparisonTableOnDemand: |||
            avg by (instance_type) (
              %(onDemandPriceEstimate)s
            ) * 730
          ||| % { onDemandPriceEstimate: queries.onDemandPriceEstimate },

          spotSavingsComparisonTableSpot: |||
            avg by (instance_type) (
              %(spotPriceEstimate)s
            ) * 730
          ||| % { spotPriceEstimate: queries.spotPriceEstimate },

          spotSavingsComparisonTableDelta: |||
            avg by (instance_type) (
              %(spotSavingsPerNode)s
            ) * 730
          ||| % { spotSavingsPerNode: queries.spotSavingsPerNode },

          spotSavingsComparisonTablePercent: |||
            avg by (instance_type) (
              %(spotSavingsPercent)s
            )
          ||| % { spotSavingsPercent: queries.spotSavingsPercent },
        };

        local panels = {
          estimatedMonthlyRunRateStat:
            mixinUtils.dashboards.statPanel(
              'Estimated Monthly Cost',
              'currencyUSD',
              queries.estimatedMonthlyRunRate,
              description='Estimated monthly run rate based on current Karpenter nodes and cloud provider price estimates.',
            ),

          estimatedSpotSavingsMonthlyStat:
            mixinUtils.dashboards.statPanel(
              'Estimated Monthly Spot Savings',
              'currencyUSD',
              queries.estimatedSpotSavingsMonthly,
              description='Estimated monthly run-rate savings if current Karpenter nodes were priced at spot rates instead of on-demand.',
            ),

          estimatedHourlyCostByNodePoolTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Estimated Monthly Cost by Node Pool',
              'currencyUSD',
              queries.estimatedMonthlyRunRateByNodePool,
              '{{ nodepool }}',
              description='Estimated monthly node cost split by node pool.',
              stack='normal',
              fillOpacity=25,
            ),

          estimatedHourlyCostByCapacityTypePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Estimated Monthly Cost by Capacity Type',
              'currencyUSD',
              queries.estimatedMonthlyRunRateByCapacityType,
              '{{ capacity_type }}',
              description='Estimated monthly cost split by capacity type.',
              values=['value', 'percent']
            ),

          estimatedHourlyCostByArchPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Estimated Monthly Cost by Architecture',
              'currencyUSD',
              queries.estimatedMonthlyRunRateByArch,
              '{{ arch }}',
              description='Estimated monthly cost split by architecture.',
              values=['value', 'percent']
            ),

          estimatedHourlyCostByNodePoolPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Estimated Monthly Cost by Node Pool',
              'currencyUSD',
              queries.estimatedMonthlyRunRateByNodePool,
              '{{ nodepool }}',
              description='Estimated monthly cost split by node pool.',
              values=['value', 'percent']
            ),

          estimatedHourlyCostByInstanceTypePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Estimated Monthly Cost by Instance Type',
              'currencyUSD',
              queries.estimatedMonthlyRunRateByInstanceType,
              '{{ instance_type }}',
              description='Estimated monthly cost split by instance type.',
              values=['value', 'percent']
            ),

          estimatedHourlyCostByInstanceTypeTable:
            mixinUtils.dashboards.tablePanel(
              'Estimated Monthly Cost by Instance Type',
              'currencyUSD',
              [
                { expr: queries.estimatedMonthlyRunRateByInstanceType },
                { expr: queries.estimatedMonthlyCostPerInstanceByInstanceType },
                { expr: queries.activeNodeCountByInstanceType },
              ],
              description='Estimated monthly cost by instance type and capacity type, including average monthly cost per instance and current instance count.',
              sortBy={ name: 'Estimated Monthly Cost', desc: true },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions({
                  renameByName: {
                    instance_type: 'Instance Type',
                    capacity_type: 'Capacity Type',
                    'Value #A': 'Estimated Monthly Cost',
                    'Value #B': 'Monthly Cost per Instance',
                    'Value #C': 'Instance Count',
                  },
                  indexByName: {
                    instance_type: 0,
                    capacity_type: 1,
                    'Value #A': 2,
                    'Value #B': 3,
                    'Value #C': 4,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }),
              ],
              overrides=[
                tbOverride.byName.new('Monthly Cost per Instance') +
                tbOverride.byName.withPropertiesFromOptions(tbStandardOptions.withUnit('currencyUSD')),
                tbOverride.byName.new('Instance Count') +
                tbOverride.byName.withPropertiesFromOptions(tbStandardOptions.withUnit('short')),
              ]
            ),

          estimatedSpotSavingsByNodePoolTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Estimated Monthly Spot Savings by Node Pool',
              'currencyUSD',
              queries.estimatedSpotSavingsMonthlyByNodePool,
              '{{ nodepool }}',
              description='Estimated monthly run-rate savings by node pool if current Karpenter nodes were priced at spot rates instead of on-demand.',
              stack='normal',
              fillOpacity=25,
            ),

          spotSavingsComparisonTable:
            mixinUtils.dashboards.tablePanel(
              'Spot versus On-Demand Comparison',
              'currencyUSD',
              [
                { expr: queries.spotSavingsComparisonTableOnDemand },
                { expr: queries.spotSavingsComparisonTableSpot },
                { expr: queries.spotSavingsComparisonTableDelta },
                { expr: queries.spotSavingsComparisonTablePercent },
              ],
              description='Average monthly on-demand and spot cost estimates per instance type across the selected zones.',
              sortBy={ name: 'Savings %', desc: true },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions({
                  renameByName: {
                    instance_type: 'Instance Type',
                    'Value #A': 'On-Demand Monthly Cost',
                    'Value #B': 'Spot Monthly Cost',
                    'Value #C': 'Monthly Savings per Instance',
                    'Value #D': 'Savings %',
                  },
                  indexByName: {
                    instance_type: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                    'Value #D': 4,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                    zone: true,
                  },
                }),
              ],
              overrides=[
                tbOverride.byName.new('On-Demand Monthly Cost') +
                tbOverride.byName.withPropertiesFromOptions(tbStandardOptions.withUnit('currencyUSD')),
                tbOverride.byName.new('Spot Monthly Cost') +
                tbOverride.byName.withPropertiesFromOptions(tbStandardOptions.withUnit('currencyUSD')),
                tbOverride.byName.new('Monthly Savings per Instance') +
                tbOverride.byName.withPropertiesFromOptions(tbStandardOptions.withUnit('currencyUSD')),
                tbOverride.byName.new('Savings %') +
                tbOverride.byName.withPropertiesFromOptions(tbStandardOptions.withUnit('percent')),
              ]
            ),
        };

        local rows =
          [
            row.new('Cost Breakdown') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.estimatedMonthlyRunRateStat,
              panels.estimatedSpotSavingsMonthlyStat,
            ],
            panelWidth=12,
            panelHeight=4,
            startY=1
          ) +
          grid.makeGrid(
            [
              panels.estimatedHourlyCostByCapacityTypePieChart,
              panels.estimatedHourlyCostByArchPieChart,
              panels.estimatedHourlyCostByNodePoolPieChart,
              panels.estimatedHourlyCostByInstanceTypePieChart,
            ],
            panelWidth=6,
            panelHeight=5,
            startY=5
          ) +
          grid.makeGrid(
            [panels.estimatedHourlyCostByNodePoolTimeSeries],
            panelWidth=24,
            panelHeight=8,
            startY=10
          ) +
          grid.makeGrid(
            [panels.estimatedHourlyCostByInstanceTypeTable],
            panelWidth=24,
            panelHeight=8,
            startY=18
          ) +
          [
            row.new('Spot Instance Savings') +
            row.gridPos.withX(0) +
            row.gridPos.withY(26) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.estimatedSpotSavingsByNodePoolTimeSeries,
            ],
            panelWidth=24,
            panelHeight=10,
            startY=27
          ) +
          grid.makeGrid(
            [
              panels.spotSavingsComparisonTable,
            ],
            panelWidth=24,
            panelHeight=10,
            startY=37
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new('Kubernetes / Autoscaling / Karpenter / Costs') +
        dashboard.withDescription('A dashboard that monitors current Karpenter node costs and spot savings based on cloud provider offering metrics. These values are estimated instance prices, not billing data. For deeper cost analysis, deploy OpenCost (https://github.com/opencost/opencost) and opencost-mixin (https://github.com/adinhodovic/opencost-mixin/). %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.karpenterCostsDashboardUid) +
        dashboard.withTags($._config.tags + ['karpenter']) +
        dashboard.withTimezone('utc') +
        dashboard.withEditable(true) +
        dashboard.time.withFrom('now-3h') +
        dashboard.time.withTo('now') +
        dashboard.withVariables(variables) +
        dashboard.withLinks(
          mixinUtils.dashboards.dashboardLinks('Kubernetes / Autoscaling', $._config, dropdown=true)
        ) +
        dashboard.withPanels(rows) +
        dashboard.withAnnotations(mixinUtils.dashboards.annotations($._config, defaultFilters)),
    } else {},
}
