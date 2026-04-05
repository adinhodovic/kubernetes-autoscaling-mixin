# Prometheus Monitoring Mixin for Kubernetes Autoscaling

A set of Grafana dashboards and Prometheus alerts for Kubernetes Autoscaling using the metrics from Kube-state-metrics, Karpenter, and Cluster-autoscaler.

This serves as a extension for the [Kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin) and adds monitoring for components that aren't deployed by default in a Kubernetes cluster (VPA, Karpenter, Cluster-Autoscaler).

## Dashboards

The mixin provides the following dashboards:

- Kubernetes Autoscaling
  - Pod Disruption Budgets
  - Horizontal Pod Autoscalers
  - Vertical Pod Autoscalers
- Cluster Autoscaler
- Karpenter
  - Overview
  - Activity
  - Performance
  - Costs
- KEDA
  - Scaled Objects
  - Scaled Jobs

Generated dashboards also exist in the `./dashboards_out` directory.

Alerts are created for the following components currently:

- Karpenter
- Keda
- Cluster Autoscaler

VPA, Karpenter, Keda, and Cluster Autoscaler are configurable in the `config.libsonnet` file. They can be turned off by setting the `enabled` field to `false`.

## How to use

This mixin is designed to be vendored into the repo with your infrastructure config. To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards

1. Generate the config files and deploy them yourself
2. Use jsonnet to deploy this mixin along with Prometheus and Grafana
3. Use prometheus-operator to deploy this mixin

Or import the dashboard using json in `./dashboards_out`, alternatively import them from the `Grafana.com` dashboard page.

## Generate config files

You can manually generate the alerts, dashboards, and rules files, but first you must install some tools:

```sh
go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
brew install jsonnet
```

Then, grab the mixin and its dependencies:

```sh
git clone https://github.com/adinhodovic/kubernetes-autoscaling-mixin
cd kubernetes-autoscaling-mixin
jb install
```

Finally, build the mixin:

```sh
make prometheus_alerts.yaml
make dashboards_out
```

The `prometheus_alerts.yaml` file then need to passed to your Prometheus server, and the files in `dashboards_out` need to be imported into you Grafana server. The exact details depend on how you deploy your monitoring stack.

### Configuration

This mixin has its configuration in the `config.libsonnet` file. You can turn off the alerts for VPA, Karpenter, KEDA, and Cluster Autoscaler by setting the `enabled` field to `false`.

```jsonnet
{
  _config+:: {
    vpa+: {
      enabled: false,
    },
    keda+: {
      enabled: false,
    },
    karpenter+: {
      enabled: false,
    },
    clusterAutoscaler+: {
      enabled: false,
    },
  },
}
```

The mixin has all components enabled by default and all the dashboards are generated in the `dashboards_out` directory. You can import them into Grafana.

### VPA Requirements

Kube-state-metrics doesn't ship with VPA metrics by default. You need to deploy a custom kube-state-metrics with the following configuration:

Adjust the `ClusterRole` `kube-state-metrics` to include the following rules:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/part-of: kube-prometheus
  name: kube-state-metrics
rules:
    # ... other rules
    - apiGroups:
      - autoscaling.k8s.io
      resources:
      - verticalpodautoscalers
      verbs:
      - list
      - watch
    - apiGroups:
      - apiextensions.k8s.io
      resources:
      - customresourcedefinitions
      verbs:
      - list
      - watch
```

Adjust the `Deployment` `kube-state-metrics` to include the following extra arguments:

```yaml
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: kube-state-metrics
    app.kubernetes.io/part-of: kube-prometheus
    app.kubernetes.io/version: 2.13.0
  name: kube-state-metrics
  namespace: monitoring
spec:
    ...
      containers:
      - args:
        ...
        - --custom-resource-state-config
        - |
          kind: CustomResourceStateMetrics
          spec:
            resources:
              - groupVersionKind:
                  group: autoscaling.k8s.io
                  kind: "VerticalPodAutoscaler"
                  version: "v1"
                labelsFromPath:
                  verticalpodautoscaler: [metadata, name]
                  namespace: [metadata, namespace]
                  target_api_version: [spec, targetRef, apiVersion]
                  target_kind: [spec, targetRef, kind]
                  target_name: [spec, targetRef, name]
                metrics:
                  # Labels
                  - name: "verticalpodautoscaler_labels"
                    help: "VPA container recommendations. Kubernetes labels converted to Prometheus labels"
                    each:
                      type: Info
                      info:
                        labelsFromPath:
                          name: [metadata, name]
                  # Memory Information
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_target"
                    help: "VPA container recommendations for memory. Target resources the VerticalPodAutoscaler recommends for the container."
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [target, memory]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "memory"
                      unit: "byte"
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound"
                    help: "VPA container recommendations for memory. Minimum resources the container can use before the VerticalPodAutoscaler updater evicts it"
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [lowerBound, memory]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "memory"
                      unit: "byte"
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_upperbound"
                    help: "VPA container recommendations for memory. Maximum resources the container can use before the VerticalPodAutoscaler updater evicts it"
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [upperBound, memory]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "memory"
                      unit: "byte"
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_uncappedtarget"
                    help: "VPA container recommendations for memory. Target resources the VerticalPodAutoscaler recommends for the container ignoring bounds"
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [uncappedTarget, memory]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "memory"
                      unit: "byte"
                  # CPU Information
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_target"
                    help: "VPA container recommendations for cpu. Target resources the VerticalPodAutoscaler recommends for the container."
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [target, cpu]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "cpu"
                      unit: "core"
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_lowerbound"
                    help: "VPA container recommendations for cpu. Minimum resources the container can use before the VerticalPodAutoscaler updater evicts it"
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [lowerBound, cpu]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "cpu"
                      unit: "core"
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_upperbound"
                    help: "VPA container recommendations for cpu. Maximum resources the container can use before the VerticalPodAutoscaler updater evicts it"
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [upperBound, cpu]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "cpu"
                      unit: "core"
                  - name: "verticalpodautoscaler_status_recommendation_containerrecommendations_uncappedtarget"
                    help: "VPA container recommendations for cpu. Target resources the VerticalPodAutoscaler recommends for the container ignoring bounds"
                    each:
                      type: Gauge
                      gauge:
                        path: [status, recommendation, containerRecommendations]
                        valueFrom: [uncappedTarget, cpu]
                        labelsFromPath:
                          container: [containerName]
                    commonLabels:
                      resource: "cpu"
                      unit: "core"
```

## Alerts

The mixin follows the [monitoring-mixins guidelines](https://github.com/monitoring-mixins/docs#guidelines-for-alert-names-labels-and-annotations) for alerts.
