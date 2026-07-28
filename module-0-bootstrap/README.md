# Module 0 — Bootstrap (not part of the official lab)

The official lab's Module 1 opens with the `travel-agency` namespace and its VMs already running — RHPDS provisions that ahead of time. This module builds that starting state from an empty cluster: the two namespaces, the 7 `travel-agency` backend VMs, and the 3 `travel-portal` shop containers.

Once this module is applied, the cluster is in exactly the state the official lab's Module 1 assumes you start from.

## Images used

All backend/portal workloads run the public `quay.io/kiali/demo_travels_*` images (https://quay.io/organization/kiali) — the same images the upstream [Kiali Travels Demo](https://kiali.io/docs/tutorials/travels/) uses. No image builds required.

| Image | Used by | Runs as |
|---|---|---|
| `quay.io/kiali/demo_travels_travels:v1` | `travels-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_cars:v1` | `cars-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_flights:v1` | `flights-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_hotels:v1` | `hotels-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_insurances:v1` | `insurances-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_discounts:v1` | `discounts-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_mysqldb:v1` | `mysqldb-vm` | container inside a VM (`travel-agency` ns) |
| `quay.io/kiali/demo_travels_portal:v1` | `voyages`, `viaggi`, `travels` Deployments | plain container Deployment (`travel-portal` ns) |

## How the VMs run their app container

Each `travel-agency` VM is a plain Fedora VM (via `DataSource: fedora`) whose `cloudInitNoCloud` userdata:
1. writes a [Podman Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) unit file to `/etc/containers/systemd/users/<name>.container`, which declares the image + env vars + port mapping,
2. enables lingering for the `fedora` user and starts the generated `<name>.service` via `systemctl --user`.

This pattern is lifted directly from the official lab's own `control-vm` and `cars-vm-v2-a` examples (modules 2 and 4) — nothing new was invented for the mechanism, only the per-service image/env values, which are cross-checked against the upstream `kiali/demos` repo's `travel_agency.yaml`.

**Lab-only credentials**: the `fedora` VM user password (`redhat`) and the MySQL root password (`mysqldbpass`) are fixed and public in this repo, matching the pattern the official lab itself uses. Do not reuse these outside a lab/demo environment.

## Deploy

```sh
oc apply -f module-0-bootstrap/namespaces/00-namespaces.yaml
oc apply -f module-0-bootstrap/vms/
oc apply -f module-0-bootstrap/containers/travel-portal.yaml
```

## Verify

```sh
# VMs should reach Running (this can take a few minutes — each pulls a DataSource clone)
oc get vm -n travel-agency
oc get vmi -n travel-agency

# portal containers should reach Ready
oc get deployment -n travel-portal
```

**Expected at this point**: the VMs' app containers come up and respond on :8000/:3306 (verified — `curl`ing a VM's pod IP directly returns real JSON, e.g. `cars-vm` correctly errors with `dial tcp: lookup mysqldb-vm.travel-agency.svc.cluster.local: no such host` since that Service doesn't exist until Module 1). The `travel-portal` Deployments, however, will sit in **`CrashLoopBackOff`**, not just log-and-retry — the upstream `demo_travels_portal` binary panics (nil pointer dereference) on a DNS lookup failure for `travels-vm.travel-agency.svc.cluster.local` instead of handling it gracefully. This is expected and resolves once Module 1 creates that Service; it's an upstream image behavior, not a bug in this repo's manifests. Don't expect a working `travel-portal` UI until Module 1 is done.

Continue to [Module 1](../module-1-explore-vms/README.md).
