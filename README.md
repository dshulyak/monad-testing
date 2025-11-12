# Monad BFT Latency Testing on Kubernetes

kubernetes test environment for monad bft latency testing with chaos mesh and observability.

## setup

### 1. install infrastructure

```bash
./setup.sh
```

installs minikube with calico cni, chaos mesh, grafana, prometheus, loki, and otel collector.

### 2. build latency image

```bash
./build.sh
```

builds the latency binary into a docker image available to minikube.

### 3. deploy latency cluster

```bash
./deploy.sh
```

this:
1. deploys 10 pods with static IPs via calico annotations (10.1.0.1 - 10.1.0.10)
2. cluster config is embedded in the configmap
3. verifies pod IPs match cluster config

## cluster configuration

- 10 node cluster with static IPs (10.1.0.1 - 10.1.0.10)
- node 0 (latency-0): producer (sends messages every 10s, 2MB size)
- nodes 1-9 (latency-1 to latency-9): consumers (receive messages only)
- direct IP communication (no kubernetes service)
- cluster config embedded in configmap
- metrics exported to otel collector every 10s via grpc

## static IP assignment

pods get static IPs via calico annotation:
```yaml
annotations:
  cni.projectcalico.org/ipAddrs: "[\"10.1.0.1\"]"
```

IPs match the cluster config exactly (10.1.0.1 - 10.1.0.10)

## accessing services

### grafana
```bash
minikube service grafana -n monitoring
```
credentials: admin/admin

datasources:
- prometheus: metrics
- loki: logs

### chaos mesh dashboard
```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```
access at http://localhost:2333

## monitoring

### view pod status
```bash
kubectl get pods -l app=latency -o wide
```

### view producer logs
```bash
kubectl logs -f latency-0
```

### view consumer logs
```bash
kubectl logs -f latency-1
```

### view cluster config
```bash
kubectl exec latency-0 -- cat /config/cluster.toml
```

## metrics exported

- `raptorcast.latency.last_us`: last message latency in microseconds
- `raptorcast.latency.min_us`: minimum latency
- `raptorcast.latency.max_us`: maximum latency
- `raptorcast.latency.avg_us`: average latency
- `raptorcast.messages.received`: total messages received
- `raptorcast.messages.sent`: total messages sent
- `raptorcast.uptime_us`: node uptime in microseconds

## rebuilding after code changes

```bash
./build.sh
kubectl delete pods -l app=latency
kubectl apply -f k8s-latency.yaml
```

## cleanup

```bash
kubectl delete -f k8s-latency.yaml
kubectl delete configmap latency-config
```

## file structure

- `setup.sh`: infrastructure setup with calico cni
- `build.sh`: builds latency docker image
- `deploy.sh`: generates config and deploys latency cluster
- `Dockerfile`: latency container image
- `k8s-latency.yaml`: kubernetes pod manifests with static IPs
- `cluster.toml`: generated cluster configuration
