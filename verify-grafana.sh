#!/bin/bash
set -e

echo "verifying grafana deployment and dashboards"
echo ""

echo "1. checking grafana pod status..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
echo ""

echo "2. checking grafana service..."
kubectl get svc grafana -n monitoring
echo ""

echo "3. checking dashboard configmap..."
kubectl get configmap grafana-dashboards -n monitoring
echo ""

echo "4. listing mounted dashboard files in grafana pod..."
POD_NAME=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n monitoring $POD_NAME -- ls -la /var/lib/grafana/dashboards/default/
echo ""

echo "5. getting grafana url..."
GRAFANA_URL=$(sg docker -c 'minikube service grafana -n monitoring --url' 2>/dev/null || echo "error: run with docker permissions")
echo "grafana url: $GRAFANA_URL"
echo ""

echo "6. checking datasources..."
kubectl get cm grafana -n monitoring -o jsonpath='{.data.datasources\.yaml}' | grep -A 3 "name:"
echo ""

echo "================================"
echo "verification complete"
echo "================================"
echo ""
echo "access grafana:"
echo "  url: $GRAFANA_URL"
echo "  username: admin"
echo "  password: admin"
echo ""
echo "dashboards location: Dashboards > Monad BFT folder"
echo ""
