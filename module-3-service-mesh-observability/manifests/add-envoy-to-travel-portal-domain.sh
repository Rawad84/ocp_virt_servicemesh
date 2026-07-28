#!/bin/bash
set -euo pipefail

echo
echo "Add the travel-portal Deployments to the mesh by injecting Istio sidecars"
echo "---------------------------------------------------------------------------------"
echo

for dep in travels viaggi voyages; do
  oc patch deployment/$dep --type=merge -p '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject": "true"}}}}}' -n travel-portal
done

echo
sleep 3
oc get pods -n travel-portal
