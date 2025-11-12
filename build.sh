#!/bin/bash
set -e

echo "copying latest latency binary"
cp ~/monad-bft/target/release/examples/latency .

echo "building image in minikube docker"
eval $(minikube docker-env)
docker build -t latency:latest .

echo "image built successfully"
echo "use imagePullPolicy: Never in your k8s deployment"
