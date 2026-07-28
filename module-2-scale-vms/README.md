# Module 2 — Scaling Virtual Machines on OpenShift

Ported from the official lab's `lab-2` assets. Deploys the missing `travel-control` business dashboard as a VM, exposes it, then explores vertical and horizontal scaling.

## Images used

| Image | Used by |
|---|---|
| `quay.io/kiali/demo_travels_control:v1` (https://quay.io/organization/kiali) | `control-vm` (and its `VirtualMachinePool` replacement in Task 4) |

## Task 1: Deploy the business dashboard as a VM

```sh
oc apply -f module-2-scale-vms/manifests/00-namespace.yaml
oc apply -f module-2-scale-vms/manifests/control-vm.yaml
```

Wait for it to reach `Running`:

```sh
oc get vm -n travel-control -w
```

## Task 2: Expose the business dashboard

```sh
oc apply -f module-2-scale-vms/manifests/control-svc.yaml
oc apply -f module-2-scale-vms/manifests/control-route.yaml

echo "https://$(oc get route travel-control -o jsonpath='{.spec.host}' -n travel-control)"
```

Open that URL — the Travel Booking business dashboard, with sliders to adjust each portal's traffic ratio, device, user, and travel type.

## Task 3: Scale up (vertical)

From the VM console (**Virtualization → VirtualMachines → control-vm → Console**), confirm current resources with `lscpu` / `free -h`.

Then, in the console: **Configuration → CPU | Memory → 2 vCPU / 4 GiB → Save**. OpenShift Virtualization live-migrates the VM to apply the change — no downtime, no manual intervention.

## Task 4: Scale out (horizontal) with a VirtualMachinePool

`VirtualMachinePool` is a Dev Preview feature that keeps N replicas of a VM template ready at all times — the scale-out equivalent of a Deployment.

```sh
oc delete vm control-vm -n travel-control
oc apply -f module-2-scale-vms/manifests/vm-pool.yaml
```

```sh
oc get vm -n travel-control -w   # expect 2 control-vm-* instances
```

Delete one of the two VMs (console or `oc delete vm <name> -n travel-control`) and confirm the dashboard stays reachable, and the pool automatically recreates the deleted replica.

Optional autoscaling on CPU:

```sh
oc apply -f module-2-scale-vms/manifests/vm-pool-hpa.yaml
```

Clean up back to 1 replica when done exploring:

```sh
oc delete hpa vm-pool-hpa -n travel-control
oc patch virtualmachinepool travel-control-vm-pool -n travel-control --type merge --patch '{"spec":{"replicas":1}}'
```

## Verify module complete

```sh
oc get vm,vmi -n travel-control
oc get route travel-control -n travel-control
curl -sI https://$(oc get route travel-control -o jsonpath='{.spec.host}' -n travel-control)
```

Continue to [Module 3](../module-3-service-mesh-observability/README.md).
