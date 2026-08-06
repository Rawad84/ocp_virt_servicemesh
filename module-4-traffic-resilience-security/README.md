# Module 4 — Traffic Resilience and Security for VMs with Service Mesh

Ported from the official lab's `lab-4` assets. Exposes the dashboard publicly through the mesh's ingress gateway, performs a canary release of a new `cars-vm` version, adds a circuit breaker for resilience, and locks down cross-namespace traffic with `AuthorizationPolicy`.

## Images used

| Image | Used by |
|---|---|
| `quay.io/kiali/demo_travels_cars:v1` (https://quay.io/organization/kiali) | `cars-vm-v2-a`, `cars-vm-v2-b` — same image as the Module 0 `cars-vm`, run as the "v2" canary release |

## Deviation from the official lab's source files

The official `lab-4/cars-vm-v2-a.yaml` and `cars-vm-v2-b.yaml` files ship with `Environment=CURRENT_VERSION='v1` — both a stray unclosed quote and the wrong version value for what's meant to be the *v2* canary. Fixed here to `Environment=CURRENT_VERSION='v2'` in both `cars-vm-v2-a.yaml` and `cars-vm-v2-b.yaml` — otherwise the app itself would misreport its own version regardless of what the mesh's `version: v2` label says.

## Task 1: Expose the business dashboard publicly

```sh
./module-4-traffic-resilience-security/manifests/expose-control-vm.sh <your-cluster-apps-domain>
# e.g. ./expose-control-vm.sh apps.mycluster.example.com
```

**OSSM 3.4 note**: unlike the classic architecture, there's no auto-created `istio-ingressgateway` pod — the script now deploys one itself first (a `Deployment`+`Service` in `istio-system` using gateway injection, plus an OpenShift `Route` exposing it), then creates the `Gateway` (istio-system), `VirtualService`, and `DestinationRule` (travel-control) routing `istio-ingressgateway-istio-system.<domain>` to `control-vm`, same as before.

```sh
curl -I http://istio-ingressgateway-istio-system.<your-cluster-apps-domain>/
```

## Task 2: Canary release of cars-vm v2

```sh
oc apply -f module-4-traffic-resilience-security/manifests/cars-vm-v2-a.yaml
oc apply -f module-4-traffic-resilience-security/manifests/cars-dr.yaml
./module-4-traffic-resilience-security/manifests/set-cars-canary-weights.sh 90 10
```

Watch the split in Kiali (**Graph**, `travel-agency` namespace). Once confident, shift more traffic:

```sh
./module-4-traffic-resilience-security/manifests/set-cars-canary-weights.sh 20 80
```

`cars-vs.yaml` in this directory is the *committed* end state of that progression (20/80) — it's what Module 5's GitOps layer syncs going forward. Use the script above for live, manual weight changes during this walkthrough; once GitOps takes over in Module 5, change the split by editing `cars-vs.yaml` and committing, not by re-running the script.

## Task 3: Circuit breaker + high availability

Add a second v2 replica, then apply the circuit-breaker-enhanced `DestinationRule`:

```sh
oc apply -f module-4-traffic-resilience-security/manifests/cars-vm-v2-b.yaml
oc apply -f module-4-traffic-resilience-security/manifests/cars-dr-circuit-breaker.yaml
```

`cars-dr-circuit-breaker.yaml` is the same `DestinationRule` (`cars`, `travel-agency`) as `cars-dr.yaml` from Task 2, just with the circuit breaker's `trafficPolicy` added to the v2 subset — it supersedes `cars-dr.yaml`, the two aren't meant to coexist. `cars-dr.yaml` stays in this directory only as the Task-2-only intermediate step for anyone following the walkthrough top to bottom; Module 5's GitOps layer syncs `cars-dr-circuit-breaker.yaml` as the one true desired state.

`cars-vm` now has 3 endpoints total (v1 + 2×v2), with v2 traffic split ~evenly across the pair. Test the breaker by stopping the app inside `cars-vm-v2-b`'s guest console:

```sh
systemctl --user stop cars.service
```

The mesh should eject that endpoint for 3 minutes after its first 5xx, then retry. Restart it any time with `systemctl --user start cars.service`.

## Task 4: Authorization policies

Default-deny, then explicit allows (split into travel-agency-scoped and travel-control-scoped files — the travel-control ones are re-declared by Module 5's Helm chart later, so keeping them separate lets GitOps exclude just those without touching the travel-agency policies):

```sh
oc apply -f module-4-traffic-resilience-security/manifests/authz-01-deny-all-travel-agency.yaml
oc apply -f module-4-traffic-resilience-security/manifests/authz-01-deny-all-travel-control.yaml
```

At this point the dashboard and all internal calls will fail with `RBAC: access denied` — expected.

```sh
oc apply -f module-4-traffic-resilience-security/manifests/authz-02-allow-travel-agency.yaml
oc apply -f module-4-traffic-resilience-security/manifests/authz-02-allow-travel-control.yaml
```

Verify the dashboard is reachable again, and that `travel-control → travel-agency` is still blocked (it's intentionally not in the allow list — the dashboard has no legitimate reason to call the booking backend directly):

```sh
oc -n travel-control exec $(oc -n travel-control get pod -l app=control-vm -o jsonpath='{.items[0].metadata.name}') -- curl -o /dev/null -sw '%{http_code}\n' travels-vm.travel-agency.svc.cluster.local:8000/travels/London
# expect: 403
```

## Verify module complete

```sh
for ns in travel-agency travel-control istio-system; do oc get gateway,virtualservice,destinationrule,authorizationpolicy -n $ns 2>/dev/null; done
curl -I http://istio-ingressgateway-istio-system.<your-cluster-apps-domain>/
```

Continue to [Module 5](../module-5-gitops/README.md).
