#!/bin/bash

EXPERIMENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "usage: $0 {enable|disable|status|list} [experiment-name]"
    echo ""
    echo "periodic experiments:"
    echo "  network-packet-loss  - 7% packet loss on latency-1,2,3 every 15min for 7min"
    echo "  network-partition    - isolate latency-4,5 every 20min for 3.5min"
    echo "  pod-failure          - make latency-6,7 unavailable every 25min for 4min"
    echo ""
    echo "frequent experiments:"
    echo "  frequent-network-partition-10s - partition bucket-1 from bucket-2 every 10min for 10s"
    echo "  frequent-network-partition-40s - partition bucket-1 from bucket-2 every 10min for 40s"
    echo "  frequent-pod-failure-10s       - fail latency-6,7 every 2min for 10s"
    echo "  frequent-pod-failure-40s       - fail latency-6,7 every 2min for 40s"
    echo ""
    echo "constant experiments:"
    echo "  network-latency-constant - 5 buckets with 20ms incremental latency (20-100ms)"
    echo ""
    echo "  all                 - all periodic experiments"
    echo "  all-frequent        - all frequent experiments"
    echo "  all-with-latency    - all experiments including constant latency"
    echo ""
    echo "examples:"
    echo "  $0 enable network-packet-loss"
    echo "  $0 enable network-latency-constant"
    echo "  $0 enable all"
    echo "  $0 enable all-frequent"
    echo "  $0 disable pod-kill"
    echo "  $0 status"
    exit 1
}

enable_experiment() {
    local exp=$1
    if [ "$exp" = "all" ]; then
        echo "enabling all periodic chaos experiments..."
        kubectl apply -f "$EXPERIMENTS_DIR/network-packet-loss.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/network-partition.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/pod-kill.yaml"
    elif [ "$exp" = "all-frequent" ]; then
        echo "enabling all frequent chaos experiments..."
        echo "labeling pods with buckets..."
        "$EXPERIMENTS_DIR/label-buckets.sh"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-network-partition-10s.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-network-partition-40s.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-pod-failure-10s.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-pod-failure-40s.yaml"
    elif [ "$exp" = "all-with-latency" ]; then
        echo "enabling all chaos experiments including constant latency..."
        kubectl apply -f "$EXPERIMENTS_DIR/network-packet-loss.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/network-partition.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/pod-kill.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-network-partition-10s.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-network-partition-40s.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-pod-failure-10s.yaml"
        kubectl apply -f "$EXPERIMENTS_DIR/frequent-pod-failure-40s.yaml"
        echo "labeling pods with buckets..."
        "$EXPERIMENTS_DIR/label-buckets.sh"
        echo "applying latency between buckets..."
        kubectl apply -f "$EXPERIMENTS_DIR/network-latency-constant.yaml"
    elif [ "$exp" = "network-latency-constant" ]; then
        echo "labeling pods with buckets..."
        "$EXPERIMENTS_DIR/label-buckets.sh"
        echo "applying latency between buckets..."
        kubectl apply -f "$EXPERIMENTS_DIR/network-latency-constant.yaml"
    else
        local file="$EXPERIMENTS_DIR/${exp}.yaml"
        if [ ! -f "$file" ]; then
            echo "error: experiment '$exp' not found"
            echo "available: network-packet-loss, network-partition, pod-kill, network-latency-constant, frequent-network-partition-10s, frequent-network-partition-40s, frequent-pod-failure-10s, frequent-pod-failure-40s"
            exit 1
        fi
        echo "enabling experiment: $exp"
        kubectl apply -f "$file"
    fi
}

disable_experiment() {
    local exp=$1
    if [ "$exp" = "all" ]; then
        echo "disabling all periodic chaos experiments..."
        kubectl delete schedule network-packet-loss -n default --ignore-not-found
        kubectl delete schedule network-partition -n default --ignore-not-found
        kubectl delete schedule pod-failure -n default --ignore-not-found
    elif [ "$exp" = "all-frequent" ]; then
        echo "disabling all frequent chaos experiments..."
        kubectl delete schedule frequent-network-partition-10s -n default --ignore-not-found
        kubectl delete schedule frequent-network-partition-40s -n default --ignore-not-found
        kubectl delete schedule frequent-pod-failure-10s -n default --ignore-not-found
        kubectl delete schedule frequent-pod-failure-40s -n default --ignore-not-found
    elif [ "$exp" = "all-with-latency" ]; then
        echo "disabling all chaos experiments including constant latency..."
        kubectl delete schedule network-packet-loss -n default --ignore-not-found
        kubectl delete schedule network-partition -n default --ignore-not-found
        kubectl delete schedule pod-failure -n default --ignore-not-found
        kubectl delete schedule frequent-network-partition-10s -n default --ignore-not-found
        kubectl delete schedule frequent-network-partition-40s -n default --ignore-not-found
        kubectl delete schedule frequent-pod-failure-10s -n default --ignore-not-found
        kubectl delete schedule frequent-pod-failure-40s -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b2 -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b3 -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b4 -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b5 -n default --ignore-not-found
        kubectl delete networkchaos latency-b2-to-b3 -n default --ignore-not-found
        kubectl delete networkchaos latency-b2-to-b4 -n default --ignore-not-found
        kubectl delete networkchaos latency-b2-to-b5 -n default --ignore-not-found
        kubectl delete networkchaos latency-b3-to-b4 -n default --ignore-not-found
        kubectl delete networkchaos latency-b3-to-b5 -n default --ignore-not-found
        kubectl delete networkchaos latency-b4-to-b5 -n default --ignore-not-found
    elif [ "$exp" = "network-latency-constant" ]; then
        echo "disabling constant network latency buckets..."
        kubectl delete networkchaos latency-b1-to-b2 -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b3 -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b4 -n default --ignore-not-found
        kubectl delete networkchaos latency-b1-to-b5 -n default --ignore-not-found
        kubectl delete networkchaos latency-b2-to-b3 -n default --ignore-not-found
        kubectl delete networkchaos latency-b2-to-b4 -n default --ignore-not-found
        kubectl delete networkchaos latency-b2-to-b5 -n default --ignore-not-found
        kubectl delete networkchaos latency-b3-to-b4 -n default --ignore-not-found
        kubectl delete networkchaos latency-b3-to-b5 -n default --ignore-not-found
        kubectl delete networkchaos latency-b4-to-b5 -n default --ignore-not-found
    else
        echo "disabling experiment: $exp"
        kubectl delete schedule "$exp" -n default --ignore-not-found
    fi
}

show_status() {
    echo "=== chaos experiments status ==="
    echo ""
    echo "schedules:"
    kubectl get schedule -n default 2>/dev/null || echo "no schedules found"
    echo ""
    echo "active chaos:"
    kubectl get networkchaos,podchaos -n default 2>/dev/null || echo "no active chaos"
}

list_experiments() {
    echo "available experiments:"
    echo ""
    for file in "$EXPERIMENTS_DIR"/*.yaml; do
        if [ -f "$file" ]; then
            basename "$file" .yaml
        fi
    done
}

if [ $# -lt 1 ]; then
    usage
fi

ACTION=$1
EXPERIMENT=${2:-""}

case "$ACTION" in
    enable)
        if [ -z "$EXPERIMENT" ]; then
            echo "error: experiment name required"
            usage
        fi
        enable_experiment "$EXPERIMENT"
        ;;
    disable)
        if [ -z "$EXPERIMENT" ]; then
            echo "error: experiment name required"
            usage
        fi
        disable_experiment "$EXPERIMENT"
        ;;
    status)
        show_status
        ;;
    list)
        list_experiments
        ;;
    *)
        usage
        ;;
esac
