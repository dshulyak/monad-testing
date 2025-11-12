#!/bin/bash
set -e

echo "starting setup for minikube, chaos mesh, and grafana with prometheus and loki"

install_minikube() {
    if command -v minikube &> /dev/null; then
        echo "minikube already installed: $(minikube version --short)"
        return
    fi

    echo "installing minikube"
    sudo apt-get install -y minikube
    echo "minikube installed successfully"
}

install_dependencies() {
    echo "installing dependencies"

    if ! command -v kubectl &> /dev/null; then
        sudo apt-get install -y kubectl
    fi

    if ! command -v helm &> /dev/null; then
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt-get update
        sudo apt-get install -y helm
    fi

    echo "dependencies installed successfully"
}

start_minikube() {
    if minikube status &> /dev/null; then
        echo "minikube already running"
        return
    fi

    echo "starting minikube cluster with calico cni"
    minikube start --cpus=max --memory=max --driver=docker --cni=calico
    echo "minikube started successfully"
}

configure_calico() {
    echo "configuring calico ippool for static IPs"

    cat > /tmp/calico-ippool.yaml <<EOF
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: latency-pool
spec:
  cidr: 10.1.0.0/24
  ipipMode: Never
  natOutgoing: true
  disabled: false
  nodeSelector: all()
EOF

    kubectl apply -f /tmp/calico-ippool.yaml

    echo "calico ippool configured"
}

install_chaos_mesh() {
    echo "installing chaos mesh via helm"

    helm repo add chaos-mesh https://charts.chaos-mesh.org
    helm repo update

    kubectl create namespace chaos-mesh || true

    helm install chaos-mesh chaos-mesh/chaos-mesh \
        --namespace=chaos-mesh \
        --set chaosDaemon.runtime=containerd \
        --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
        --set dashboard.create=true

    echo "chaos mesh installed successfully"
}

install_grafana() {
    echo "installing grafana with metrics and logs via helm"

    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    kubectl create namespace monitoring || true

    echo "installing prometheus for metrics"
    cat > /tmp/prometheus-values.yaml <<EOF
serverFiles:
  prometheus.yml:
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets:
              - localhost:9090

      - job_name: otel-collector
        static_configs:
          - targets:
              - otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:8889
        scrape_interval: 10s

      - job_name: kubernetes-cadvisor
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/\${1}/proxy/metrics/cadvisor
        metric_relabel_configs:
          - source_labels: [__name__]
            regex: container_(cpu|memory|network|fs).*
            action: keep
EOF

    helm install prometheus prometheus-community/prometheus \
        --namespace=monitoring \
        --set server.service.type=ClusterIP \
        -f /tmp/prometheus-values.yaml

    echo "installing loki for logs"
    helm install loki grafana/loki-stack \
        --namespace=monitoring \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=5Gi

    echo "installing opentelemetry collector"
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update

    cat > /tmp/otel-values.yaml <<EOF
mode: deployment
image:
  repository: otel/opentelemetry-collector-contrib
service:
  type: ClusterIP
ports:
  metrics:
    enabled: true
    containerPort: 8888
    servicePort: 8888
    protocol: TCP
  prometheus:
    enabled: true
    containerPort: 8889
    servicePort: 8889
    protocol: TCP
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
  processors:
    batch: {}
  exporters:
    prometheus:
      endpoint: "0.0.0.0:8889"
    otlphttp/loki:
      endpoint: http://loki:3100/otlp
  service:
    pipelines:
      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheus]
      logs:
        receivers: [otlp]
        processors: [batch]
        exporters: [otlphttp/loki]
EOF

    helm install otel-collector open-telemetry/opentelemetry-collector \
        --namespace=monitoring \
        --values=/tmp/otel-values.yaml

    cat > /tmp/grafana-values.yaml <<EOF
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      orgId: 1
      url: http://prometheus-server:80
      isDefault: true
      editable: true
    - name: Loki
      type: loki
      access: proxy
      orgId: 1
      url: http://loki:3100
      isDefault: false
      editable: true

service:
  type: NodePort
  port: 80

adminPassword: admin
EOF

    helm install grafana grafana/grafana \
        --namespace=monitoring \
        --values=/tmp/grafana-values.yaml

    echo "grafana installed successfully"
    echo "grafana password: admin"
}

install_dashboards() {
    echo "installing grafana dashboards"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -d "$SCRIPT_DIR/grafana-dashboards" ]; then
        kubectl create configmap grafana-dashboards \
            --from-file="$SCRIPT_DIR/grafana-dashboards/raptorcast-latency-dashboard.json" \
            --from-file="$SCRIPT_DIR/grafana-dashboards/wireauth-metrics-dashboard.json" \
            --from-file="$SCRIPT_DIR/grafana-dashboards/pod-resources-dashboard.json" \
            -n monitoring \
            --dry-run=client -o yaml | kubectl apply -f -

        cat > /tmp/grafana-values-with-dashboards.yaml <<EOF
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      orgId: 1
      url: http://prometheus-server:80
      isDefault: true
      editable: true
    - name: Loki
      type: loki
      access: proxy
      orgId: 1
      url: http://loki:3100
      isDefault: false
      editable: true

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: 'Monad BFT'
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default

dashboardsConfigMaps:
  default: grafana-dashboards

service:
  type: NodePort
  port: 80

adminPassword: admin
EOF

        helm upgrade grafana grafana/grafana \
            --namespace=monitoring \
            --values=/tmp/grafana-values-with-dashboards.yaml \
            --reuse-values=false || echo "note: grafana may need manual restart"

        kubectl rollout restart deployment grafana -n monitoring

        echo "grafana dashboards installed successfully"
    else
        echo "warning: grafana-dashboards directory not found, skipping dashboard installation"
    fi
}

print_access_info() {
    echo ""
    echo "================================"
    echo "setup completed successfully"
    echo "================================"
    echo ""
    echo "access services:"
    echo "grafana: minikube service grafana -n monitoring"
    echo "grafana credentials: admin / admin"
    echo "chaos mesh dashboard: kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333"
    echo ""
    echo "monitoring stack:"
    echo "prometheus: http://prometheus-server.monitoring.svc.cluster.local:80"
    echo "loki: http://loki.monitoring.svc.cluster.local:3100"
    echo ""
    echo "otel endpoints for your app:"
    echo "grpc: otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317"
    echo "http: otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318"
    echo ""
    echo "grafana dashboards installed in 'Monad BFT' folder:"
    echo "  - Raptorcast Latency Metrics"
    echo "  - WireAuth Metrics"
    echo "  - Latency Pods Resource Monitoring"
    echo ""
    echo "for detailed access info, see: GRAFANA_ACCESS.md"
    echo ""
}

main() {
    install_minikube
    install_dependencies
    start_minikube
    configure_calico
    install_chaos_mesh
    install_grafana
    install_dashboards
    print_access_info
}

main
