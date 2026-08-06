# common/operators

Cluster-admin prerequisites for everything else in this repo. This build's target cluster already has OpenShift Virtualization and OpenShift GitOps installed (GitOps is already in active use — an `openshift-gitops` ArgoCD instance already exists), so only Service Mesh is included here.

Installs **Red Hat OpenShift Service Mesh 3.4** — the Sail Operator / Istio-native architecture, not the classic Maistra-based `ServiceMeshControlPlane` API. There is no single mesh-control-plane resource here; the control plane is an `Istio` CR, sidecar traffic redirection is a separate `IstioCNI` CR, and Kiali/Grafana/tracing are each their own operator + CR rather than SMCP-embedded addons.

| File                            | Installs                                                                                                                    |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `00-namespaces.yaml`           | `openshift-cnv`, `istio-system`, `istio-cni`, `openshift-tempo-operator`, `openshift-opentelemetry-operator`, `grafana-operator` namespaces |
| `05-operatorgroups.yaml`       | `OperatorGroup`s (AllNamespaces mode) for the three dedicated operator namespaces above — `openshift-operators` already has one by default |
| `20-service-mesh.yaml`         | Operator subscriptions: Sail Operator (`servicemeshoperator3`) and Kiali Operator (`kiali-ossm`) into `openshift-operators`; Red Hat build of OpenTelemetry, Red Hat Tempo Operator, and Grafana Operator (community) each into their own dedicated namespace — see table above |
| `21-istio.yaml`                | `Istio` CR (`sailoperator.io/v1`) — the mesh control plane, deployed into `istio-system`                                |
| `22-istiocni.yaml`             | `IstioCNI` CR — sidecar traffic redirection, deployed into `istio-cni`                                                    |
| `23-peer-authentication.yaml`  | Mesh-wide `PeerAuthentication` enforcing `STRICT` mTLS (3.x defaults to `PERMISSIVE`; the classic SMCP defaulted to `STRICT`) |
| `24-kiali.yaml`                | `Kiali` CR wired to OpenShift monitoring (thanos-querier), Grafana, and Tempo                                             |
| `25-grafana.yaml`              | `Grafana` CR + Prometheus datasource (Istio dashboards imported separately, see below)                                    |
| `26-tempo.yaml`                | `TempoMonolithic` CR, in-memory storage — tracing backend, replaces the classic Jaeger addon                             |
| `27-otel-collector.yaml`       | `OpenTelemetryCollector` CR — receives OTLP from mesh sidecars, exports to Tempo                                          |

**Why the split namespaces**: Red Hat's documented defaults put the Sail Operator and Kiali Operator in the cluster's existing `openshift-operators` namespace, but the Tempo Operator, OpenTelemetry Operator, and (by convention) the community Grafana Operator each get their own dedicated namespace. This isn't a stylistic choice made here — it's what the official install docs for each operator specify. The operator *subscriptions* live in these namespaces; the CRs they manage (`Kiali`, `Grafana`, `TempoMonolithic`, `OpenTelemetryCollector`) still all live in `istio-system` regardless of which namespace their operator runs in — that's normal for AllNamespaces-mode operators.

If deploying this repo to a cluster that lacks OpenShift Virtualization or OpenShift GitOps, those need to be installed separately first (not included here since this build's cluster already has them).

## Apply

```sh
oc apply -f common/operators/00-namespaces.yaml
oc apply -f common/operators/05-operatorgroups.yaml
oc apply -f common/operators/20-service-mesh.yaml

# wait for all 5 operators above to finish installing (check Subscription/InstallPlan/CSV status), then:
oc apply -f common/operators/21-istio.yaml
oc apply -f common/operators/22-istiocni.yaml
oc wait --for=condition=Ready istios/default --timeout=5m
oc wait --for=condition=Ready istiocnis/default --timeout=5m

oc apply -f common/operators/23-peer-authentication.yaml
oc apply -f common/operators/24-kiali.yaml
oc apply -f common/operators/25-grafana.yaml
oc apply -f common/operators/26-tempo.yaml
oc apply -f common/operators/27-otel-collector.yaml
```

Verify before moving to Module 0:

```sh
oc get csv -n openshift-operators
oc get csv -n openshift-tempo-operator
oc get csv -n openshift-opentelemetry-operator
oc get csv -n grafana-operator
oc get istio default                 # STATUS should reach "Healthy"
oc get istiocni default              # STATUS should reach "Healthy"
oc get kiali kiali -n istio-system
oc get grafana grafana -n istio-system
oc get tempomonolithic tempo -n istio-system
oc get opentelemetrycollector otel-collector -n istio-system
```

**Not validated against a live cluster** — package/channel names in `20-service-mesh.yaml` (`servicemeshoperator3`, `kiali-ossm`, `opentelemetry-product`, `tempo-product`, `grafana-operator`) and the exact Grafana/Tempo service hostnames referenced in `24-kiali.yaml`/`27-otel-collector.yaml` are current as of this build but not confirmed against a real OperatorHub catalog. Before applying, run:

```sh
oc get packagemanifest -n openshift-marketplace | grep -Ei 'servicemeshoperator3|kiali-ossm|tempo|opentelemetry|grafana'
```

and correct any name/channel mismatches.
