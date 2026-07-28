#!/bin/bash
# Usage: ./expose-control-vm.sh <openshift-apps-domain>   e.g. apps.mycluster.example.com
set -euo pipefail

OCP_DOMAIN=$1
ISTIO_INGRESS_ROUTE_URL="istio-ingressgateway-istio-system.$OCP_DOMAIN"

echo "Ingress route: $ISTIO_INGRESS_ROUTE_URL"

oc apply -n istio-system -f - <<EOF
kind: Gateway
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: control-gateway
  namespace: istio-system
  labels:
    module: m4
spec:
  servers:
    - hosts:
        - $ISTIO_INGRESS_ROUTE_URL
      port:
        name: http
        number: 80
        protocol: HTTP
  selector:
    istio: ingressgateway
EOF

oc apply -n travel-control -f - <<EOF
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: control
  namespace: travel-control
  labels:
    module: m4
spec:
  hosts:
    - $ISTIO_INGRESS_ROUTE_URL
  gateways:
    - istio-system/control-gateway
  http:
    - route:
        - destination:
            host: control-vm.travel-control.svc.cluster.local
            subset: v1
          weight: 100
EOF

oc apply -n travel-control -f - <<EOF
kind: DestinationRule
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: control
  namespace: travel-control
  labels:
    module: m4
spec:
  host: control-vm.travel-control.svc.cluster.local
  subsets:
    - labels:
        version: v1
      name: v1
EOF

echo
echo "Go to http://$ISTIO_INGRESS_ROUTE_URL"
