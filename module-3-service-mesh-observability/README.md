# Module 3 — Integrating and Observing VMs in OpenShift Service Mesh

Ported from the official lab's `lab-3` assets. Joins all three Travel Booking namespaces to the mesh and adds Istio sidecars to every VM and container, unlocking Kiali/Jaeger/Grafana observability and (later, Module 4) traffic management and security.

No new app images in this module — it only adds the `istio-proxy` sidecar container to workloads Modules 0–2 already deployed.

## Task 1: Explore the (currently empty) observability stack

```sh
echo "https://$(oc get route kiali -o jsonpath='{.spec.host}' -n istio-system)"
echo "https://$(oc get route jaeger -o jsonpath='{.spec.host}' -n istio-system)"
echo "https://$(oc get route grafana -o jsonpath='{.spec.host}' -n istio-system)"
```

Log into each with your cluster admin credentials. All three will show no services/traces yet — expected, since nothing is in the mesh until Task 2.

## Task 2: Add the Travel Booking VMs & containers to the mesh

First, make each namespace a member of the `basic` ServiceMeshControlPlane:

```sh
oc apply -f module-3-service-mesh-observability/manifests/servicemeshmember.yaml
```

Then inject the `istio-proxy` sidecar into every workload:

```sh
./module-3-service-mesh-observability/manifests/add-envoy-to-travel-agency-services-domain.sh
./module-3-service-mesh-observability/manifests/add-envoy-to-travel-portal-domain.sh
./module-3-service-mesh-observability/manifests/add-envoy-to-travel-control.sh
```

Each pod should now show 2 containers instead of 1 (the workload + `istio-proxy`):

```sh
oc get pods -n travel-agency -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

**Note on `add-envoy-to-travel-control.sh`**: adapted from the official script to loop over *all* VMs currently in `travel-control` (not just the first one found) — this way it works whether Module 2 left you with a single `control-vm` or a `VirtualMachinePool`'s replicas.

## Task 3: Validate the mesh in Kiali / Jaeger / Grafana

Go back to the three dashboards from Task 1:
- **Kiali → Graph → Select All namespaces** — the Travel Booking network topology should now render.
- **Jaeger → Service: `travels-vm.travel-agency` → Find Traces** — traces of requests through `travels-vm`.
- **Grafana → Istio → Istio Mesh Dashboard** — traffic volume and HTTP success/failure rates.

## Task 4: Validate the application still works

The UI isn't exposed through the mesh yet (that's Module 4), so validate via internal service-to-service call:

```sh
oc -n travel-portal exec $(oc -n travel-portal get pod -l app=travels -o jsonpath='{.items[0].metadata.name}') -- curl -s travels-vm.travel-agency.svc.cluster.local:8000/travels/London | jq
```

## Task 5 (optional): Explore further Kiali features

- **Graph → Display → Security** — confirms mTLS is active (lock icons on each edge).
- **Istio Config → istio-system** — the mesh's default `DestinationRule` enforcing `ISTIO_MUTUAL` TLS.
- **Workloads → travels-vm → Inbound/Outbound Metrics** — per-workload throughput/latency.

## Verify module complete

```sh
oc get smm -A
for ns in travel-agency travel-portal travel-control; do oc get pods -n $ns; done
```

Continue to [Module 4](../module-4-traffic-resilience-security/README.md).
