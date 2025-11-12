# monad bft latency testing

kubernetes test environment for monad bft latency testing with chaos mesh and observability.

## quick start

```bash
./setup.sh    # install infrastructure
./build.sh    # build latency image
./deploy.sh   # deploy latency cluster
```

## cluster configuration

- 10 node cluster with static IPs (10.1.0.1 - 10.1.0.10)
- latency-0: producer (sends 2MB messages every 10s)
- latency-1 to latency-9: consumers
- metrics exported to prometheus via otel collector
- logs aggregated via loki

## access services

### grafana
```bash
minikube service grafana -n monitoring
```
credentials: admin/admin

### chaos mesh dashboard
```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```
access at http://localhost:2333

## chaos experiments

run periodic chaos experiments to test resilience:

```bash
cd chaos-experiments

./manage.sh enable network-packet-loss
./manage.sh enable network-partition
./manage.sh enable pod-kill
./manage.sh enable all

./manage.sh status
./manage.sh disable network-packet-loss
```

see [chaos-experiments/README.md](chaos-experiments/README.md) for details.

## useful commands

```bash
kubectl get pods -l app=latency -o wide
kubectl logs -f latency-0
kubectl logs -f latency-1
```

## rebuild and redeploy

```bash
cd ~/monad-bft && cargo build --release --example latency
cd ~/monad-testing
./build.sh
kubectl delete pod -l app=latency
./deploy.sh
```
