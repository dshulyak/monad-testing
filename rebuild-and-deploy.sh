#!/bin/bash

set -e

echo "==> Disabling chaos experiments..."
./chaos-experiments/manage.sh disable all-with-latency

echo "==> Deleting current pods..."
kubectl delete pods -l app=latency -n default --force --grace-period=0

echo "==> Rebuilding latency binary..."
cd ~/monad-bft
/home/dshulyak/.cargo/bin/cargo build --release --example latency

echo "==> Building Docker image..."
cd ~/monad-testing
./build.sh

echo "==> Deploying latency cluster..."
./deploy.sh

echo "==> Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=latency -n default --timeout=120s

echo "==> Re-enabling chaos experiments..."
./chaos-experiments/manage.sh enable all-with-latency

echo "==> Done! Cluster rebuilt and chaos experiments enabled."
