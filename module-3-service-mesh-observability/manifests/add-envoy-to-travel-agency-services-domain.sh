#!/bin/bash
set -euo pipefail

echo
echo "Update VirtualMachine CRs to join the mesh by injecting Istio sidecars"
echo "------------------------------------------------------------------------------------------"
echo

for vm in cars-vm discounts-vm flights-vm hotels-vm insurances-vm mysqldb-vm travels-vm; do
  oc patch VirtualMachine/$vm --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n travel-agency
  oc patch VirtualMachine/$vm --type merge -p '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject": "true"}}}}}' -n travel-agency
  oc delete pods -l vm.kubevirt.io/name=$vm -n travel-agency
done

echo
sleep 5
oc get pods -n travel-agency
