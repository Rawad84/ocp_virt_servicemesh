#!/bin/bash
# Usage: ./set-cars-canary-weights.sh <v1-weight> <v2-weight>   (must sum to 100)
set -euo pipefail

TRAFFIC_V1=$1
TRAFFIC_V2=$2

oc apply -f - <<EOF
kind: VirtualService
apiVersion: networking.istio.io/v1
metadata:
  name: cars
  namespace: travel-agency
  labels:
    module: m4
spec:
  hosts:
    - cars-vm.travel-agency.svc.cluster.local
  gateways:
    - mesh
  http:
    - route:
        - destination:
            host: cars-vm.travel-agency.svc.cluster.local
            subset: v1
          weight: $TRAFFIC_V1
        - destination:
            host: cars-vm.travel-agency.svc.cluster.local
            subset: v2
          weight: $TRAFFIC_V2
EOF
