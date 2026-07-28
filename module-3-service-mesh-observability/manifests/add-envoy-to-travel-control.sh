#!/bin/bash
set -euo pipefail

echo
echo "Update VirtualMachine CR(s) in travel-control to join the mesh by injecting Istio sidecars"
echo "------------------------------------------------------------------------------------------"
echo

# Handles both a single control-vm (Module 2 Task 1-3) and a VirtualMachinePool's
# generated replicas (Module 2 Task 4) — whichever is currently running.
for vm in $(oc get VirtualMachine -n travel-control -o jsonpath='{.items[*].metadata.name}'); do
  echo "$vm"
  oc patch VirtualMachine/$vm --type=merge -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n travel-control
  oc delete pods -l vm.kubevirt.io/name=$vm -n travel-control
done

echo
sleep 3
oc get pods -n travel-control
