# Module 1 — Explore OpenShift Virtualization and connect the virtual machines

Ported from the official lab's `lab-1` assets. Makes the 7 `travel-agency` VMs (deployed in [Module 0](../module-0-bootstrap/README.md)) reachable from other pods/VMs, and from outside the cluster.

No new container images in this module — it only creates Kubernetes-native networking objects (Services, a Route, a NetworkPolicy) for the VMs Module 0 already deployed.

## Task 1: Explore the deployed VMs

In the OpenShift web console:

- **Home → Overview** — check the Virtualization status card.
- **Virtualization → VirtualMachines** — see the 7 running VMs in the `travel-agency` namespace.
- Click `cars-vm` → **Console** tab to access the guest, or **Metrics** tab for CPU/memory/storage/network graphs.

At this point the VM workloads aren't reachable from other pods yet — that's what Task 2 fixes.

## Task 2: Create a Service for each VM

A Kubernetes `Service` load-balances to any pod (including a VM's `virt-launcher` pod) matching a label selector. Each VM created in Module 0 already carries `kubevirt.io/domain: <name>-vm`, so the Services just need to select on that label.

```sh
oc apply -f module-1-explore-vms/manifests/cars-svc.yaml
oc apply -f module-1-explore-vms/manifests/services/
```

Verify: **Networking → Services** in the console, or:

```sh
oc get svc -n travel-agency
```

Each VM's app container (from Module 0) will now start succeeding — they were retrying against these exact Service hostnames since they came up.

The `travel-portal` Deployments (`travels`/`viaggi`/`voyages`), however, were already crash-looping on a DNS failure before these Services existed (see Module 0's README) — a plain container restart-on-crash doesn't re-resolve DNS any faster, and `CrashLoopBackOff`'s exponential backoff can leave them down for several minutes even though the Service they need now exists. Force an immediate retry instead of waiting it out:

```sh
oc delete pods -n travel-portal -l 'app in (travels,viaggi,voyages)'
```

They should come up `1/1 Running` within ~20s.

## Task 3: Validate communication between VMs

Per the official lab, do this from inside a `virt-launcher-*` VM pod's Terminal tab (**Workloads → Pods → virt-launcher-travels-vm-... → Terminal**), or from the VM's own guest console (**Virtualization → VirtualMachines → travels-vm → Console**, using the guest credentials):

```sh
curl -v http://travels-vm.travel-agency.svc.cluster.local:8000/travels/London
```

Expect a JSON quote aggregating flights/hotels/cars/insurances for London. (Not scripted as a CLI one-liner here since the `virt-launcher` container doesn't reliably have `curl`/a shell — the console Terminal/guest-console route is what the lab itself uses.)

## Task 4: External access with a Route

```sh
oc apply -f module-1-explore-vms/manifests/travels-route.yaml

export TRAVELS_ROUTE=$(oc get route travels-vm -o jsonpath='{.spec.host}' -n travel-agency)
curl -v http://$TRAVELS_ROUTE/travels/London
```

Optional: disable sticky sessions —

```sh
oc annotate route travels-vm haproxy.router.openshift.io/disable_cookies='true' -n travel-agency
```

## Task 5 (optional): NetworkPolicy egress block

Demonstrates that a NetworkPolicy applies to VM pods exactly like any other pod:

```sh
oc apply -f module-1-explore-vms/manifests/cars-block-egress-policy.yaml
```

From `cars-vm`'s console: `curl http://www.google.com` should now time out. From `travels-vm`'s console the same command should still work — it isn't selected by the policy.

Clean up:

```sh
oc delete -f module-1-explore-vms/manifests/cars-block-egress-policy.yaml
```

## Verify module complete

```sh
oc get svc -n travel-agency
oc get route travels-vm -n travel-agency
curl -s http://$(oc get route travels-vm -o jsonpath='{.spec.host}' -n travel-agency)/travels/London | jq
```

Continue to [Module 2](../module-2-scale-vms/README.md).
