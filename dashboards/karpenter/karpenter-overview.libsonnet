local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbOverride = tbStandardOptions.override;
local tbFieldConfig = tablePanel.fieldConfig;

{
  local dashboardName = 'karpenter-over',
  grafanaDashboards+:: {
    ['kubernetes-autoscaling-mixin-%s.json' % dashboardName]:
      if !$._config.karpenter.enabled then {} else

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
        local queries = {
          // Cluster Summary
          clusterCpuAllocatable: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="cpu"
              }
            )
          ||| % defaultFilters,

          clusterMemoryAllocatable: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="memory"
              }
            )
          ||| % defaultFilters,

          podCpuRequests: |||
            sum(
              karpenter_nodes_total_pod_requests{
                %(full)s,
                resource_type="cpu"
              }
            ) +
            sum(
              karpenter_nodes_total_daemon_requests{
                %(full)s,
                resource_type="cpu"
              }
            )
          ||| % defaultFilters,

          podMemoryRequests: |||
            sum(
              karpenter_nodes_total_pod_requests{
                %(full)s,
                resource_type="memory"
              }
            ) +
            sum(
              karpenter_nodes_total_daemon_requests{
                %(full)s,
                resource_type="memory"
              }
            )
          ||| % defaultFilters,

          // Node Pool Summary
          nodePools: |||
            count(
              count(
                karpenter_nodepools_limit{
                  %(base)s
                }
              ) by (nodepool)
            )
          ||| % defaultFilters,

          nodesCount: |||
            count(
              count(
                karpenter_nodes_allocatable{
                  %(full)s
                }
              ) by (node_name)
            )
          ||| % defaultFilters,

          nodePoolCpuUsage: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="cpu"
              }
            )
          ||| % defaultFilters,

          nodePoolMemoryUsage: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="memory"
              }
            )
          ||| % defaultFilters,

          nodePoolCpuLimits: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="cpu"
              }
            )
          ||| % defaultFilters,

          nodePoolMemoryLimits: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="memory"
              }
            )
          ||| % defaultFilters,

          nodePoolsUtilizationByNodePool: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s
              }
            ) by (nodepool, resource_type)
            /
            sum(
              karpenter_nodepools_limit{
                %(default)s
              }
            ) by (nodepool, resource_type) * 100
          ||| % defaultFilters,

          // Node Distribution
          nodesByNodePool: |||
            count by (nodepool) (
              count by (node_name, nodepool) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          nodesByInstanceType: |||
            count by (instance_type) (
              count by (node_name, instance_type) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          nodesByCapacityType: |||
            count by (capacity_type) (
              count by (node_name, capacity_type) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          nodesByRegion: |||
            count by (region) (
              count by (node_name, region) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          nodesByZone: |||
            count by (zone) (
              count by (node_name, zone) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          nodesByArch: |||
            count by (arch) (
              count by (node_name, arch) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          nodesByOS: |||
            count by (os) (
              count by (node_name, os) (
                karpenter_nodes_allocatable{
                  %(full)s
                }
              )
            )
          ||| % defaultFilters,

          // Pod Summary
          podCpuLimits: |||
            sum(
              karpenter_nodes_total_pod_limits{
                %(full)s,
                resource_type="cpu"
              }
            ) +
            sum(
              karpenter_nodes_total_daemon_limits{
                %(full)s,
                resource_type="cpu"
              }
            )
          ||| % defaultFilters,

          podMemoryLimits: |||
            sum(
              karpenter_nodes_total_pod_limits{
                %(full)s,
                resource_type="memory"
              }
            ) +
            sum(
              karpenter_nodes_total_daemon_limits{
                %(full)s,
                resource_type="memory"
              }
            )
          ||| % defaultFilters,

          // Pod Distribution
          podsByNodePool: |||
            sum(
                karpenter_pods_state{
                  %(base)s,
                  %(nodepool)s
                }
            ) by (nodepool)
          ||| % defaultFilters,

          podsByInstanceType: |||
            sum(
                karpenter_pods_state{
                  %(base)s,
                  %(nodepool)s
                }
            ) by (instance_type)
          ||| % defaultFilters,

          podsByCapacityType: |||
            sum(
                karpenter_pods_state{
                  %(base)s,
                  %(nodepool)s
                }
            ) by (capacity_type)
          ||| % defaultFilters,

          // Node Pool Table
          nodePoolCpuUsageByNodePool: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="cpu"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolMemoryUsageByNodePool: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="memory"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolNodesUsageByNodePool: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="nodes"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolPodsUsageByNodePool: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="pods"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolEphemeralStorageUsageByNodePool: |||
            sum(
              karpenter_nodepools_usage{
                %(default)s,
                resource_type="ephemeral_storage"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolCpuAllocatedByNodePool: |||
            sum(
              karpenter_nodes_allocatable{
                %(default)s,
                resource_type="cpu"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolMemoryAllocatedByNodePool: |||
            sum(
              karpenter_nodes_allocatable{
                %(default)s,
                resource_type="memory"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolCpuLimitByNodePool: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="cpu"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolMemoryLimitByNodePool: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="memory"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolNodesLimitByNodePool: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="nodes"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolPodsLimitByNodePool: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="pods"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          nodePoolEphemeralStorageLimitByNodePool: |||
            sum(
              karpenter_nodepools_limit{
                %(default)s,
                resource_type="ephemeral_storage"
              }
            ) by (job, namespace, nodepool)
          ||| % defaultFilters,

          // Node Table
          nodeCpuUtilization: |||
            (
              (
                sum(
                  karpenter_nodes_total_pod_requests{
                    %(full)s,
                    resource_type="cpu"
                  }
                ) by (node_name, nodepool, instance_type, instance_memory, instance_cpu, instance_network_bandwidth, region, zone, os, capacity_type, arch)
                +
                sum(
                  karpenter_nodes_total_daemon_requests{
                    %(full)s,
                    resource_type="cpu"
                  }
                ) by (node_name, nodepool, instance_type, instance_memory, instance_cpu, instance_network_bandwidth, region, zone, os, capacity_type, arch)
              ) /
              sum(
                karpenter_nodes_allocatable{
                  %(full)s,
                  resource_type="cpu"
                }
              ) by (node_name, nodepool, instance_type, instance_memory, instance_cpu, instance_network_bandwidth, region, zone, os, capacity_type, arch)
            ) * 100
          ||| % defaultFilters,

          nodeMemoryUtilization: |||
            (
              (
                sum(
                  karpenter_nodes_total_pod_requests{
                    %(full)s,
                    resource_type="memory"
                  }
                ) by (node_name, nodepool, instance_type, instance_memory, instance_cpu, instance_network_bandwidth, region, zone, os, capacity_type, arch)
                +
                sum(
                  karpenter_nodes_total_daemon_requests{
                    %(full)s,
                    resource_type="memory"
                  }
                ) by (node_name, nodepool, instance_type, instance_memory, instance_cpu, instance_network_bandwidth, region, zone, os, capacity_type, arch)
              ) /
              sum(
                karpenter_nodes_allocatable{
                  %(full)s,
                  resource_type="memory"
                }
              ) by (node_name, nodepool, instance_type, instance_memory, instance_cpu, instance_network_bandwidth, region, zone, os, capacity_type, arch)
            ) * 100
          ||| % defaultFilters,
        };

        local panels = {
          // Cluster Summary
          clusterCpuUtilizationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Cluster CPU Utilization',
              'short',
              [
                {
                  expr: queries.clusterCpuAllocatable,
                  legend: 'Allocatable',
                },
                {
                  expr: queries.podCpuRequests,
                  legend: 'Requested',
                },
              ],
              description='The total CPU allocatable and requested across all Karpenter nodes.',
              fillOpacity=0,
            ),

          clusterMemoryUtilizationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Cluster Memory Utilization',
              'bytes',
              [
                {
                  expr: queries.clusterMemoryAllocatable,
                  legend: 'Allocatable',
                },
                {
                  expr: queries.podMemoryRequests,
                  legend: 'Requested',
                },
              ],
              description='The percentage of node pool usage relative to limits.',
              fillOpacity=0,
            ),

          // Node Pool Summary
          nodePoolsStat:
            mixinUtils.dashboards.statPanel(
              'Node Pools',
              'short',
              queries.nodePools,
              description='The total number of Karpenter node pools.',
            ),

          nodesCountStat:
            mixinUtils.dashboards.statPanel(
              'Nodes',
              'short',
              queries.nodesCount,
              description='The total number of Karpenter nodes.',
            ),

          nodePoolCpuUsageStat:
            mixinUtils.dashboards.statPanel(
              'Node Pool CPU Usage',
              'short',
              queries.nodePoolCpuUsage,
              description='The total CPU usage across all node pools.',
            ),

          nodePoolMemoryUsageStat:
            mixinUtils.dashboards.statPanel(
              'Node Pool Memory Usage',
              'bytes',
              queries.nodePoolMemoryUsage,
              description='The total memory usage across all node pools.',
            ),

          nodePoolCpuLimitsStat:
            mixinUtils.dashboards.statPanel(
              'Node Pool CPU Limits',
              'short',
              queries.nodePoolCpuLimits,
              description='The total CPU limits across all node pools.',
            ),

          nodePoolMemoryLimitsStat:
            mixinUtils.dashboards.statPanel(
              'Node Pool Memory Limits',
              'bytes',
              queries.nodePoolMemoryLimits,
              description='The total memory limits across all node pools.',
            ),

          nodePoolsUtilizationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Node Pool Utilization',
              'percent',
              queries.nodePoolsUtilizationByNodePool,
              '{{ nodepool }} / {{ resource_type }}',
              description='The percentage of node pool usage relative to limits.',
              fillOpacity=0,
            ),

          // Node Distribution
          nodesByNodePoolPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by Node Pool',
              'short',
              queries.nodesByNodePool,
              '{{ nodepool }}',
              description='The distribution of nodes by node pool.',
              values=['value', 'percent']
            ),

          nodesByInstanceTypePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by Instance Type',
              'short',
              queries.nodesByInstanceType,
              '{{ instance_type }}',
              description='The distribution of nodes by instance type.',
              values=['value', 'percent']
            ),

          nodesByCapacityTypePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by Capacity Type',
              'short',
              queries.nodesByCapacityType,
              '{{ capacity_type }}',
              description='The distribution of nodes by capacity type.',
              values=['value', 'percent']
            ),

          nodesByRegionPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by Region',
              'short',
              queries.nodesByRegion,
              '{{ region }}',
              description='The distribution of nodes by region.',
              values=['value', 'percent']
            ),

          nodesByZonePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by Zone',
              'short',
              queries.nodesByZone,
              '{{ zone }}',
              description='The distribution of nodes by zone.',
              values=['value', 'percent']
            ),

          nodesByArchPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by Arch',
              'short',
              queries.nodesByArch,
              '{{ arch }}',
              description='The distribution of nodes by architecture.',
              values=['value', 'percent']
            ),

          nodesByOSPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Nodes by OS',
              'short',
              queries.nodesByOS,
              '{{ os }}',
              description='The distribution of nodes by operating system.',
              values=['value', 'percent']
            ),

          // Pod Summary
          podCpuRequestsStat:
            mixinUtils.dashboards.statPanel(
              'Pod CPU Requests',
              'short',
              queries.podCpuRequests,
              description='The total CPU requests for all pods on Karpenter nodes.',
            ),

          podMemoryRequestsStat:
            mixinUtils.dashboards.statPanel(
              'Pod Memory Requests',
              'bytes',
              queries.podMemoryRequests,
              description='The total memory requests for all pods on Karpenter nodes.',
            ),

          podCpuLimitsStat:
            mixinUtils.dashboards.statPanel(
              'Pod CPU Limits',
              'short',
              queries.podCpuLimits,
              description='The total CPU limits for all pods on Karpenter nodes.',
            ),

          podMemoryLimitsStat:
            mixinUtils.dashboards.statPanel(
              'Pod Memory Limits',
              'bytes',
              queries.podMemoryLimits,
              description='The total memory limits for all pods on Karpenter nodes.',
            ),

          // Pod Distribution
          podsByNodePoolPieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Pods by Node Pool',
              'short',
              queries.podsByNodePool,
              '{{ nodepool }}',
              description='The distribution of pods by node pool.',
              values=['value', 'percent']
            ),

          podsByInstanceTypePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Pods by Instance Type',
              'short',
              queries.podsByInstanceType,
              '{{ instance_type }}',
              description='The distribution of pods by instance type.',
              values=['value', 'percent']
            ),

          podsByCapacityTypePieChart:
            mixinUtils.dashboards.pieChartPanel(
              'Pods by Capacity Type',
              'short',
              queries.podsByCapacityType,
              '{{ capacity_type }}',
              description='The distribution of pods by capacity type.',
              values=['value', 'percent']
            ),

          // Node Pool Table
          nodePoolTable:
            mixinUtils.dashboards.tablePanel(
              'Node Pools',
              'short',
              [
                { expr: queries.nodePoolCpuUsageByNodePool },
                { expr: queries.nodePoolCpuAllocatedByNodePool },
                { expr: queries.nodePoolCpuLimitByNodePool },
                { expr: queries.nodePoolMemoryUsageByNodePool },
                { expr: queries.nodePoolMemoryAllocatedByNodePool },
                { expr: queries.nodePoolMemoryLimitByNodePool },
                { expr: queries.nodePoolNodesUsageByNodePool },
                { expr: queries.nodePoolNodesLimitByNodePool },
                { expr: queries.nodePoolPodsUsageByNodePool },
                { expr: queries.nodePoolPodsLimitByNodePool },
                { expr: queries.nodePoolEphemeralStorageUsageByNodePool },
                { expr: queries.nodePoolEphemeralStorageLimitByNodePool },
              ],
              description='Summary of all Karpenter node pools with resource usage and limits.',
              sortBy={ name: 'Node Pool', desc: false },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions({
                  renameByName: {
                    namespace: 'Namespace',
                    nodepool: 'Node Pool',
                    'Value #A': 'CPU Usage',
                    'Value #B': 'CPU Allocated',
                    'Value #C': 'CPU Limit',
                    'Value #D': 'Memory Usage',
                    'Value #E': 'Memory Allocated',
                    'Value #F': 'Memory Limit',
                    'Value #G': 'Nodes Count',
                    'Value #H': 'Nodes Limit',
                    'Value #I': 'Max Pods Count',
                    'Value #J': 'Max Pods Limit',
                    'Value #K': 'Storage Usage',
                    'Value #L': 'Storage Limit',
                  },
                  indexByName: {
                    namespace: 0,
                    nodepool: 1,
                    'Value #A': 2,
                    'Value #B': 3,
                    'Value #C': 4,
                    'Value #D': 5,
                    'Value #E': 6,
                    'Value #F': 7,
                    'Value #G': 8,
                    'Value #H': 9,
                    'Value #I': 10,
                    'Value #J': 11,
                    'Value #K': 12,
                    'Value #L': 13,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }),
              ],
              overrides=[
                tbOverride.byName.new('Memory Usage') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('bytes')
                ),
                tbOverride.byName.new('Memory Allocated') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('bytes')
                ),
                tbOverride.byName.new('Memory Limit') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('bytes')
                ),
                tbOverride.byName.new('Storage Usage') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('bytes')
                ),
                tbOverride.byName.new('Storage Limit') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('bytes')
                ),
              ]
            ),

          // Node Table
          nodeTable:
            mixinUtils.dashboards.tablePanel(
              'Nodes',
              'short',
              [
                { expr: queries.nodeCpuUtilization },
                { expr: queries.nodeMemoryUtilization },
              ],
              description='Summary of all Karpenter nodes with CPU and memory utilization.',
              sortBy={ name: 'CPU Utilization', desc: true },
              transformations=[
                tbQueryOptions.transformation.withId('merge'),
                tbQueryOptions.transformation.withId('organize') +
                tbQueryOptions.transformation.withOptions({
                  renameByName: {
                    namespace: 'Namespace',
                    node_name: 'Node Name',
                    nodepool: 'Node Pool',
                    arch: 'Architecture',
                    capacity_type: 'Capacity Type',
                    instance_type: 'Instance Type',
                    instance_memory: 'Instance Memory',
                    instance_cpu: 'Instance CPU',
                    instance_network_bandwidth: 'Instance Network Bandwidth',
                    region: 'Region',
                    zone: 'Zone',
                    os: 'OS',
                    'Value #A': 'CPU Utilization',
                    'Value #B': 'Memory Utilization',
                  },
                  indexByName: {
                    namespace: 0,
                    node_name: 1,
                    nodepool: 2,
                    instance_type: 3,
                    instance_cpu: 4,
                    instance_memory: 5,
                    'Value #A': 6,
                    'Value #B': 7,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }),
              ],
              overrides=[
                tbOverride.byName.new('CPU Utilization') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('percent') +
                  tbStandardOptions.withMax(100) +
                  tbStandardOptions.thresholds.withMode('percentage') +
                  tbStandardOptions.thresholds.withSteps([
                    tbStandardOptions.threshold.step.withValue(0) +
                    tbStandardOptions.threshold.step.withColor('green'),
                    tbStandardOptions.threshold.step.withValue(33) +
                    tbStandardOptions.threshold.step.withColor('yellow'),
                    tbStandardOptions.threshold.step.withValue(66) +
                    tbStandardOptions.threshold.step.withColor('red'),
                  ]) +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withType()
                ),
                tbOverride.byName.new('Memory Utilization') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('percent') +
                  tbStandardOptions.withMax(100) +
                  tbStandardOptions.thresholds.withMode('percentage') +
                  tbStandardOptions.thresholds.withSteps([
                    tbStandardOptions.threshold.step.withValue(0) +
                    tbStandardOptions.threshold.step.withColor('green'),
                    tbStandardOptions.threshold.step.withValue(33) +
                    tbStandardOptions.threshold.step.withColor('yellow'),
                    tbStandardOptions.threshold.step.withValue(66) +
                    tbStandardOptions.threshold.step.withColor('red'),
                  ]) +
                  tbFieldConfig.defaults.custom.cellOptions.TableBarGaugeCellOptions.withType()
                ),
                tbOverride.byName.new('Instance Memory') +
                tbOverride.byName.withPropertiesFromOptions(
                  tbStandardOptions.withUnit('decmbytes')
                ),
              ]
            ),
        };

        local rows =
          [
            row.new('Cluster Summary') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.clusterCpuUtilizationTimeSeries,
              panels.clusterMemoryUtilizationTimeSeries,
            ],
            panelWidth=12,
            panelHeight=5,
            startY=1
          ) +
          [
            row.new('Node Pool Summary') +
            row.gridPos.withX(0) +
            row.gridPos.withY(6) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.nodePoolsStat,
              panels.nodesCountStat,
              panels.nodePoolCpuUsageStat,
              panels.nodePoolMemoryUsageStat,
              panels.nodePoolCpuLimitsStat,
              panels.nodePoolMemoryLimitsStat,
            ],
            panelWidth=4,
            panelHeight=3,
            startY=7
          ) +
          grid.makeGrid(
            [
              panels.nodePoolsUtilizationTimeSeries,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=10
          ) +
          grid.makeGrid(
            [
              panels.nodesByNodePoolPieChart,
              panels.nodesByInstanceTypePieChart,
              panels.nodesByCapacityTypePieChart,
            ],
            panelWidth=8,
            panelHeight=5,
            startY=18
          ) +
          grid.makeGrid(
            [
              panels.nodesByRegionPieChart,
              panels.nodesByZonePieChart,
              panels.nodesByArchPieChart,
              panels.nodesByOSPieChart,
            ],
            panelWidth=6,
            panelHeight=5,
            startY=23
          ) +
          [
            row.new('Pod Summary') +
            row.gridPos.withX(0) +
            row.gridPos.withY(28) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.makeGrid(
            [
              panels.podCpuRequestsStat,
              panels.podMemoryRequestsStat,
              panels.podCpuLimitsStat,
              panels.podMemoryLimitsStat,
            ],
            panelWidth=6,
            panelHeight=3,
            startY=29
          ) +
          grid.makeGrid(
            [
              panels.podsByNodePoolPieChart,
              panels.podsByInstanceTypePieChart,
              panels.podsByCapacityTypePieChart,
            ],
            panelWidth=8,
            panelHeight=5,
            startY=32
          ) +
          [
            row.new('Node Pools') +
            row.gridPos.withX(0) +
            row.gridPos.withY(36) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
            panels.nodePoolTable +
            tablePanel.gridPos.withX(0) +
            tablePanel.gridPos.withY(37) +
            tablePanel.gridPos.withW(24) +
            tablePanel.gridPos.withH(12),
            row.new('Nodes') +
            row.gridPos.withX(0) +
            row.gridPos.withY(49) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
            panels.nodeTable +
            tablePanel.gridPos.withX(0) +
            tablePanel.gridPos.withY(50) +
            tablePanel.gridPos.withW(24) +
            tablePanel.gridPos.withH(12),
          ];

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Kubernetes / Autoscaling / Karpenter / Overview',
        ) +
        dashboard.withDescription('A dashboard that monitors Karpenter and focuses on giving an overview for Karpenter. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
        dashboard.withUid($._config.karpenterOverviewDashboardUid) +
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
