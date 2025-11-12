# Monad BFT Latency Testing on Kubernetes

kubernetes test environment for monad bft latency testing with chaos mesh and observability.

## setup

### 1. install infrastructure

```bash
./setup.sh
```

installs:
- minikube with calico cni
- calico ippool for static IPs (10.1.0.0/24)
- chaos mesh with dashboard
- prometheus configured to scrape otel collector
- loki for log aggregation
- opentelemetry collector with prometheus exporter on port 8889
- grafana with prometheus and loki datasources

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

get the grafana URL:
```bash
minikube service grafana -n monitoring --url
```

if running on a remote VM via SSH, use port forwarding:
```bash
ssh -L 8080:<grafana-ip>:<grafana-port> user@vm-host
```

then access at http://localhost:8080

credentials: admin/admin

datasources:
- prometheus: metrics (includes raptorcast metrics from otel collector)
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

- `setup.sh`: infrastructure setup with calico cni, ippool, monitoring stack
- `build.sh`: builds latency docker image in minikube
- `deploy.sh`: deploys latency cluster with static IPs
- `Dockerfile`: latency container image definition
- `k8s-latency.yaml`: kubernetes pod manifests with static IPs and cluster config
- `calico-ippool.yaml`: calico ippool definition for 10.1.0.0/24
- `cluster.toml`: generated cluster configuration (gitignored)
