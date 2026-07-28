when 

# common/operators

Cluster-admin prerequisites for everything else in this repo. This build's target cluster already has OpenShift Virtualization and OpenShift GitOps installed (GitOps is already in active use — an `openshift-gitops` ArgoCD instance already exists), so only Service Mesh is included here.

| File                                   | Installs                                                                                                                                                                      |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `00-namespaces.yaml`                 | `openshift-cnv`, `istio-system` namespaces                                                                                                                                |
| `20-service-mesh.yaml`               | Kiali, distributed tracing (Jaeger), Service Mesh operator subscriptions                                                                                                      |
| `21-service-mesh-control-plane.yaml` | `ServiceMeshControlPlane` named `basic` in `istio-system` — apply only after the operators in `20-service-mesh.yaml` finish installing (their CRDs must exist first) |

If deploying this repo to a cluster that lacks OpenShift Virtualization or OpenShift GitOps, those need to be installed separately first (not included here since this build's cluster already has them).

## Apply

```sh
oc apply -f common/operators/00-namespaces.yaml
oc apply -f common/operators/20-service-mesh.yaml

# wait for the operators above to finish installing (check Subscription/InstallPlan status), then:
oc apply -f common/operators/21-service-mesh-control-plane.yaml
```

Verify before moving to Module 0:

```sh
oc get csv -n openshift-operators
oc get smcp basic -n istio-system   # STATUS should reach "ComponentsReady"
```

**Not validated against a live cluster** — channel names (`stable`) and the `ServiceMeshControlPlane` `version: v2.6` are current as of this build but drift across OCP releases. Confirm against the target cluster's OperatorHub before applying.
