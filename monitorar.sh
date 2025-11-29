#!/bin/bash

set -euo pipefail

CLUSTER_NAME="meucluster"
KIND_CONFIG="kind-multinode.yaml"

echo "[KIND] Criando arquivo de cluster multinode..."
cat <<EOF > "$KIND_CONFIG"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "[KIND] Criando cluster..."
kind delete cluster --name "$CLUSTER_NAME" || true
kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"

echo "[K8S] Aguardando nós ficarem prontos..."
kubectl wait --for=condition=Ready node --all --timeout=120s


######################################################
# 1) INSTALAR kube-prometheus-stack (K8S monitoring)
######################################################

echo "[PROMETHEUS] Instalando kube-prometheus-stack..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

# O segredo: NÃO criamos ServiceMonitor da sua aplicação!
# Só instalamos o pacote, e ele monitora APENAS o cluster.

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.enabled=true \
  --set alertmanager.enabled=true \
  --wait

echo "[PROMETHEUS] Aguardando componentes..."
kubectl rollout status deploy/monitoring-grafana -n monitoring --timeout=180s
kubectl rollout status deploy/monitoring-kube-prometheus-operator -n monitoring --timeout=180s
kubectl rollout status deploy/monitoring-kube-prometheus-prometheus -n monitoring --timeout=180s


######################################################
# 2) MOSTRAR STATUS E COMO ACESSAR
######################################################

echo ""
echo "[OK] kube-prometheus-stack instalado!"
echo ""

echo "📈 Para acessar o Prometheus:"
echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo "  → http://localhost:9090"

echo ""
echo "📊 Para acessar o Grafana:"
echo "  kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "  → http://localhost:3000"
echo "  user: admin"
echo "  senha (pegar com):"
echo "     kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""

echo "🚀 Monitoramento do Kubernetes funcionando!"
echo ""
