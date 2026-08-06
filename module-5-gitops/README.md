
# Module 5 — Declarative Management of VMs with OpenShift GitOps

Ported from the official lab's `lab-5` assets, adapted for a from-scratch build.

**Deviation from the official lab**: the official lab runs on RHPDS-provisioned infrastructure where `travel-portal`, `travel-agency`, and the service mesh config are *already* GitOps-managed when you reach this module — its Task 1 is just exploring pre-existing ArgoCD Applications, and its Task 2 is the one genuinely hands-on step (creating a new Application for `travel-control`). Since nothing in this repo is GitOps-managed yet at this point, this module creates **all** of it: one ArgoCD Application per prior module's manifests (app-of-apps pattern, `gitops/apps/`), plus the official lab's own `travel-control` Helm chart as its own Application. The chart itself (`gitops/travel-control/`) is ported close to verbatim from the lab's `lab-5/travel-control/`.

## Images used

| Image                                                                          | Used by                                                                                                    |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `quay.io/kiali/demo_travels_control:v1` (https://quay.io/organization/kiali) | `gitops/travel-control/templates/vm.yaml` — same image as Module 2's `control-vm`, now GitOps-managed |

## Prerequisite: push this repo to a git remote

ArgoCD pulls from git — it can't read this local working copy. Push this repo somewhere ArgoCD can reach (GitHub, GitLab, an internal Gitea, etc.), then replace every `<GIT_REPO_URL>` placeholder:

```sh
sed -i "s#<GIT_REPO_URL>#https://github.com/<you>/<repo>.git#" module-5-gitops/gitops/apps/*.yaml
```

Also set the real Service Mesh ingress hostname (same value used with Module 4's `expose-control-vm.sh`) in two places:

```sh
sed -i "s#istio-ingressgateway-istio-system.CHANGEME.apps.example.com#istio-ingressgateway-istio-system.<your-cluster-apps-domain>#" \
  module-5-gitops/gitops/apps/05-travel-control-app.yaml \
  module-5-gitops/gitops/travel-control/values.yaml
```

## Task 1: Deploy the app-of-apps

```sh
oc apply -f module-5-gitops/gitops/apps/00-root-app-of-apps.yaml
```

ArgoCD reconciles that one Application, which in turn creates 5 more from the rest of `gitops/apps/` — one each for Module 0 (bootstrap), Module 1 (VM networking), Module 3 (service mesh membership), Module 4 (traffic resilience/security), and `travel-control`.

Open the ArgoCD dashboard (**OpenShift console → Applications icon (top nav) → Cluster Argo CD**, or `oc get route -n openshift-gitops`) and log in with `LOG IN VIA OPENSHIFT`. You should see `virt-ossm-lab-root` and its 5 children, each with a Sync/Health status.

Click into `travel-agency-bootstrap` (or any child) to see the resource tree — same exploration the official lab's Task 1 walks through, just against Applications this repo created rather than pre-existing ones.

**Known overlaps, documented rather than hidden**: two `AuthorizationPolicy` files in Module 4 that were travel-control-scoped are excluded from `travel-agency-traffic-resilience`'s sync since `travel-control`'s Helm chart re-declares them — see the `exclude:` comments in `gitops/apps/04-traffic-resilience-app.yaml`. `travel-agency-service-mesh` (Module 3) currently has nothing to sync — OSSM 3.4's Sail Operator has no `ServiceMeshMember`-equivalent CR, so there's no mesh-membership resource for that Application to manage.

**Not GitOps-managed, by design**: the `control-gateway` `Gateway` (istio-system) that Module 4's `expose-control-vm.sh` creates is shared mesh-ingress infrastructure, applied once imperatively — it isn't re-applied by any Application here. Module 2's `manifests/` (control-vm created directly, and the `VirtualMachinePool` scaling exercise) also stay outside GitOps — they were a one-time manual exercise, and `travel-control` supersedes their steady-state ownership from this module onward.

## Task 2: The travel-control Application (the official lab's hands-on step)

If you followed Module 2, `travel-control` (namespace, VM, Service, Route) already exists from manual `oc apply`. Simulate the scenario the official lab uses — an accidental deletion — then let GitOps recreate it:

```sh
oc delete project travel-control
```

The `travel-control` Application (already applied as part of Task 1, `gitops/apps/05-travel-control-app.yaml`) is set to manual sync by default, matching the official lab. Sync it explicitly:

```sh
oc patch application travel-control -n openshift-gitops --type merge -p '{"operation":{"sync":{}}}'
```

Or from the ArgoCD UI: **Applications → travel-control → SYNC → SYNCHRONIZE**.

Wait for it to reach `Synced`/`Healthy`, then confirm the dashboard works:

```sh
curl -I http://$(oc get route travel-control -n travel-control -o jsonpath='{.spec.host}')
```

## Task 3: Validate self-healing

Enable auto-sync and self-heal on the `travel-control` Application:

```sh
oc patch application travel-control -n openshift-gitops --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

Delete some of its resources directly and watch ArgoCD put them back:

```sh
oc delete authorizationpolicy,destinationrule,route,service,virtualmachine,virtualservice -l module=m5 -n travel-control
```

Within moments the ArgoCD dashboard should show `OutOfSync` → resources reappearing → `Synced`/`Healthy` again.

## Verify module complete

```sh
oc get applications -n openshift-gitops
oc get vm,svc,route -n travel-control
curl -I http://$(oc get route travel-control -n travel-control -o jsonpath='{.spec.host}')
```

Module 6 (self-service provisioning) is documentation-only in this pass — see [module-6-self-service-provisioning/README.md](../module-6-self-service-provisioning/README.md).
