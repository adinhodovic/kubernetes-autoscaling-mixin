local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    job: 'job=~"$job"',
    operatorNamespace: 'namespace=~"$operator_namespace"',
    resourceNamespace: 'exported_namespace=~"$resource_namespace"',
    scaledObject: 'scaledObject="$scaled_object"',
    scaledJob: 'scaledObject="$scaled_job"',
    scaler: 'scaler="$scaler"',
    metric: 'metric="$metric"',

    base: |||
      %(cluster)s,
      %(job)s,
      %(operatorNamespace)s
    ||| % this,

    withResourceNamespace: |||
      %(base)s,
      %(resourceNamespace)s
    ||| % this,

    withScaledObject: |||
      %(withResourceNamespace)s,
      type="scaledobject",
      %(scaledObject)s
    ||| % this,

    withScaledJob: |||
      %(withResourceNamespace)s,
      type="scaledjob",
      %(scaledJob)s
    ||| % this,

    withScaledObjectScaler: |||
      %(withScaledObject)s,
      %(scaler)s
    ||| % this,

    withScaledJobScaler: |||
      %(withScaledJob)s,
      %(scaler)s
    ||| % this,

    withScaledObjectMetric: |||
      %(withScaledObjectScaler)s,
      %(metric)s
    ||| % this,

    withScaledJobMetric: |||
      %(withScaledJobScaler)s,
      %(metric)s
    ||| % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new('cluster') +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        config.clusterLabel,
        'keda_build_info{}',
      ) +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      query.withSort() +
      (
        if config.showMultiCluster
        then
          query.generalOptions.showOnDashboard.withLabelAndValue() +
          query.selectionOptions.withMulti(value=config.allowMultiClusterSelection) +
          query.selectionOptions.withIncludeAll(value=config.includeAllValue)
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    scaledObjectJob:
      query.new(
        'job',
        'label_values(keda_scaled_object_paused{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledJobJob:
      query.new(
        'job',
        'label_values(keda_scaled_job_errors_total{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledObjectOperatorNamespace:
      query.new(
        'operator_namespace',
        'label_values(keda_scaled_object_paused{%(cluster)s, %(job)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Operator Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledJobOperatorNamespace:
      query.new(
        'operator_namespace',
        'label_values(keda_scaled_job_errors_total{%(cluster)s, %(job)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Operator Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledObjectResourceNamespace:
      query.new(
        'resource_namespace',
        'label_values(keda_scaled_object_paused{%(cluster)s, %(job)s, %(operatorNamespace)s}, exported_namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Resource Namespace') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledJobResourceNamespace:
      query.new(
        'resource_namespace',
        'label_values(keda_scaled_job_errors_total{%(cluster)s, %(job)s, %(operatorNamespace)s}, exported_namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Resource Namespace') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledObject:
      query.new(
        'scaled_object',
        'label_values(keda_scaled_object_paused{%(cluster)s, %(job)s, %(operatorNamespace)s, %(resourceNamespace)s}, scaledObject)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Scaled Object') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scaledJob:
      query.new(
        'scaled_job',
        'label_values(keda_scaled_job_errors_total{%(cluster)s, %(job)s, %(operatorNamespace)s, %(resourceNamespace)s}, scaledJob)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Scaled Job') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scalerForScaledObject:
      query.new(
        'scaler',
        'label_values(keda_scaler_active{%(cluster)s, %(job)s, %(operatorNamespace)s, exported_namespace="$resource_namespace", type="scaledobject", scaledObject="$scaled_object"}, scaler)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Scaler') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    scalerForScaledJob:
      query.new(
        'scaler',
        'label_values(keda_scaler_active{%(cluster)s, %(job)s, %(operatorNamespace)s, exported_namespace="$resource_namespace", type="scaledjob", scaledObject="$scaled_job"}, scaler)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Scaler') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    metricForScaledObject:
      query.new(
        'metric',
        'label_values(keda_scaler_active{%(cluster)s, %(job)s, %(operatorNamespace)s, exported_namespace="$resource_namespace", type="scaledobject", scaledObject="$scaled_object", scaler="$scaler"}, metric)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Metric') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    metricForScaledJob:
      query.new(
        'metric',
        'label_values(keda_scaler_active{%(cluster)s, %(job)s, %(operatorNamespace)s, exported_namespace="$resource_namespace", type="scaledjob", scaledObject="$scaled_job", scaler="$scaler"}, metric)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Metric') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
