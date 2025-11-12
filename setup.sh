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
    helm install prometheus prometheus-community/prometheus \
        --namespace=monitoring \
        --set server.service.type=ClusterIP

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

print_access_info() {
    echo ""
    echo "================================"
    echo "setup completed successfully"
    echo "================================"
    echo ""
    echo "access services:"
    echo "grafana: minikube service grafana -n monitoring"
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
}

main() {
    install_minikube
    install_dependencies
    start_minikube
    install_chaos_mesh
    install_grafana
    print_access_info
}

main
