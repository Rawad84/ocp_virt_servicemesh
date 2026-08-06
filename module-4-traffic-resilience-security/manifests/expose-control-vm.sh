#!/bin/bash
# Usage: ./expose-control-vm.sh <openshift-apps-domain>   e.g. apps.mycluster.example.com
set -euo pipefail

OCP_DOMAIN=$1
ISTIO_INGRESS_ROUTE_URL="istio-ingressgateway-istio-system.$OCP_DOMAIN"

echo "Ingress route: $ISTIO_INGRESS_ROUTE_URL"

# OSSM 3.4 / Sail Operator doesn't auto-create an istio-ingressgateway pod the way the classic
# ServiceMeshControlPlane did. This deploys one via gateway injection: a plain Deployment+Service
# labeled/annotated so the mesh's sidecar injector turns it into a working Envoy gateway proxy.
# Labeled `app: istio-ingressgateway` (matching authz-02-allow-travel-agency.yaml's selector)
# and running as the `istio-ingressgateway-service-account` ServiceAccount (matching the
# principal referenced in authz-02-allow-travel-control.yaml) so Module 4's existing
# AuthorizationPolicy files keep working unchanged.
oc apply -n istio-system -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: istio-ingressgateway-service-account
  namespace: istio-system
  labels:
    module: m4
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istio-ingressgateway
  namespace: istio-system
  labels:
    module: m4
    app: istio-ingressgateway
    istio: ingressgateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: istio-ingressgateway
      istio: ingressgateway
  template:
    metadata:
      labels:
        app: istio-ingressgateway
        istio: ingressgateway
        sidecar.istio.io/inject: "true"
      annotations:
        inject.istio.io/templates: gateway
    spec:
      serviceAccountName: istio-ingressgateway-service-account
      containers:
        - name: istio-proxy
          image: auto
EOF

oc apply -n istio-system -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
  labels:
    module: m4
    app: istio-ingressgateway
    istio: ingressgateway
spec:
  type: ClusterIP
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  ports:
    - name: http2
      port: 80
      targetPort: 8080
EOF

oc expose service istio-ingressgateway -n istio-system --name=istio-ingressgateway --port=http2 2>/dev/null || true
oc patch route istio-ingressgateway -n istio-system --type=merge -p "{\"spec\":{\"host\":\"$ISTIO_INGRESS_ROUTE_URL\"}}"

oc apply -n istio-system -f - <<EOF
kind: Gateway
apiVersion: networking.istio.io/v1
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
apiVersion: networking.istio.io/v1
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
apiVersion: networking.istio.io/v1
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
