#!/bin/bash
set -e

NAMESPACE=default

echo "deploying latency cluster with static IPs"
kubectl apply -f k8s-latency.yaml

echo ""
echo "waiting for pods to be ready"
kubectl wait --for=condition=Ready --timeout=120s \
    -l app=latency --namespace=$NAMESPACE pods || true

echo ""
echo "deployment complete!"
echo ""
echo "verify pod IPs:"
for i in $(seq 0 9); do
  POD_NAME="latency-$i"
  POD_IP=$(kubectl get pod $POD_NAME --namespace=$NAMESPACE -o jsonpath='{.status.podIP}' 2>/dev/null || echo "pending")
  EXPECTED_IP="10.1.0.$((i + 1))"
  if [ "$POD_IP" = "$EXPECTED_IP" ]; then
    echo "  ✓ $POD_NAME: $POD_IP"
  else
    echo "  ✗ $POD_NAME: $POD_IP (expected: $EXPECTED_IP)"
  fi
done

echo ""
echo "useful commands:"
echo "  kubectl get pods -l app=latency -o wide"
echo "  kubectl logs -f latency-0"
echo "  kubectl exec latency-0 -- cat /config/cluster.toml"
echo "  minikube service grafana -n monitoring"
