# chaos mesh experiments

chaos experiments for latency testing with both periodic and constant scenarios.

## periodic experiments

### 1. network packet loss
- **file**: `network-packet-loss.yaml`
- **schedule**: every 15 minutes
- **targets**: latency-1, latency-2, latency-3
- **effect**: 7% packet loss with 25% correlation
- **duration**: 7 minutes
- **direction**: bidirectional

simulates unreliable network conditions affecting message delivery.

### 2. network partition
- **file**: `network-partition.yaml`
- **schedule**: every 20 minutes
- **targets**: latency-4, latency-5
- **effect**: complete network isolation
- **duration**: 3 minutes 30 seconds
- **direction**: bidirectional

simulates network split-brain scenarios where nodes cannot communicate.

### 3. pod kill
- **file**: `pod-kill.yaml`
- **schedule**: every 25 minutes
- **targets**: latency-6, latency-7
- **effect**: pod termination and restart
- **duration**: 4 minutes (recovery time)
- **grace period**: 0 (immediate kill)

simulates node crashes and recovery behavior.

## constant experiments

### 4. network latency buckets
- **file**: `network-latency-constant.yaml`
- **schedule**: constant (always on)
- **buckets**: 5 buckets with 2 nodes each
  - bucket 1: latency-0, latency-1
  - bucket 2: latency-2, latency-3
  - bucket 3: latency-4, latency-5
  - bucket 4: latency-6, latency-7
  - bucket 5: latency-8, latency-9
- **latency between buckets**: 20ms per bucket distance
  - same bucket → same bucket: 0ms
  - bucket 1 ↔ bucket 2: 20ms
  - bucket 1 ↔ bucket 3: 40ms
  - bucket 1 ↔ bucket 4: 60ms
  - bucket 1 ↔ bucket 5: 80ms
  - bucket 2 ↔ bucket 3: 20ms
  - etc.
- **direction**: bidirectional
- **duration**: continuous

simulates geographically distributed nodes where latency increases with distance between regions.

## usage

### enable experiments
```bash
./manage.sh enable network-packet-loss
./manage.sh enable network-partition
./manage.sh enable pod-kill
./manage.sh enable network-latency-constant

./manage.sh enable all
./manage.sh enable all-with-latency
```

### disable experiments
```bash
./manage.sh disable network-packet-loss
./manage.sh disable network-latency-constant
./manage.sh disable all
./manage.sh disable all-with-latency
```

### check experiment status
```bash
kubectl get schedule -n default
kubectl get networkchaos -n default
kubectl get podchaos -n default
```

### view experiment details
```bash
kubectl describe schedule network-packet-loss -n default
```

### view chaos mesh dashboard
```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```
then open http://localhost:2333

## customization

edit the yaml files to adjust:
- **schedule**: cron expression for frequency
- **targets**: pod names or label selectors
- **duration**: how long the chaos lasts
- **intensity**: packet loss percentage, etc.

## notes

- schedules are staggered (15, 20, 25 min) to avoid overlapping chaos
- producer node (latency-0) is not targeted to maintain test traffic
- consumer nodes (latency-1 to latency-9) are split across experiments
- experiments automatically pause after duration expires
- kubernetes will restart killed pods automatically
