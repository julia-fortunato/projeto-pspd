#!/bin/bash
set -euo pipefail

#############################################
# CONFIGURAÇÕES
#############################################

CLUSTER_NAME="meucluster"
KIND_CONFIG="kind-multinode.yaml"
NAMESPACE="default"

SERVER_A_DIR="./serverA"
SERVER_B_DIR="./serverB"
WEBSERVER_DIR="./webserver"

IMG_A="grpc-quiz:v1"
IMG_B="grpc-user:v1"
IMG_WEB="webserver:1.2"

MANIFESTS=(
  "kubernetes/01-db-quiz-deployment.yaml"
  "kubernetes/02-db-user-deployment.yaml"
  "kubernetes/03-app-quiz-deployment.yaml"
  "kubernetes/04-app-user-deployment.yaml"
  "kubernetes/webserver-app.yaml"
)

DEPLOYMENTS=(
  "postgres-quiz-deployment"
  "postgres-user-deployment"
  "grpc-quiz-deployment"
  "grpc-user-deployment"
  "webserver-deployment"
)


#############################################
# 1) CRIAR CLUSTER KIND MULTINODE
#############################################

echo "[KIND] Criando arquivo de cluster..."
cat <<EOF > "$KIND_CONFIG"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "[KIND] Resetando cluster anterior..."
kind delete cluster --name "$CLUSTER_NAME" || true

echo "[KIND] Criando novo cluster..."
kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"


#############################################
# 2) ESPERAR CLUSTER FICAR PRONTO
#############################################

echo "[K8S] Aguardando nós prontos..."
kubectl wait --for=condition=Ready node --all --timeout=120s


#############################################
# 3) INSTALAR kube-prometheus-stack
#############################################

echo "[PROMETHEUS] Instalando monitoring stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

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


#############################################
# 4) PREPARAR NAMESPACE / CONFIGMAPS SQL
#############################################

echo "[APP] Criando namespace..."
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

echo "[APP] Criando configmaps SQL..."

kubectl create configmap quiz-sql-config \
  --from-file=BD/quiz/ -n "$NAMESPACE" \
  -o yaml --dry-run=client | kubectl apply -f -

kubectl create configmap user-sql-config \
  --from-file=BD/user/ -n "$NAMESPACE" \
  -o yaml --dry-run=client | kubectl apply -f -


#############################################
# 5) BUILD E LOAD DAS IMAGENS NO KIND
#############################################

echo "[DOCKER] Buildando imagens..."

docker build -t "$IMG_A" "$SERVER_A_DIR"
docker build -t "$IMG_B" "$SERVER_B_DIR"
docker build -t "$IMG_WEB" "$WEBSERVER_DIR"

echo "[KIND] Carregando imagens..."

kind load docker-image "$IMG_A" --name "$CLUSTER_NAME"
kind load docker-image "$IMG_B" --name "$CLUSTER_NAME"
kind load docker-image "$IMG_WEB" --name "$CLUSTER_NAME"


#############################################
# 6) APLICAR MANIFESTOS
#############################################

echo "[KUBECTL] Aplicando manifests..."

for f in "${MANIFESTS[@]}"; do
  echo "[apply] $f"
  kubectl apply -f "$f" -n "$NAMESPACE"
done


#############################################
# 7) ESPERAR ROLLOUT COMPLETAR
#############################################

echo "[KUBECTL] Esperando rollouts..."

for d in "${DEPLOYMENTS[@]}"; do
  kubectl rollout status deployment/"$d" -n "$NAMESPACE" --timeout=180s
done


#############################################
# 8) RESULTADOS / ACESSOS
#############################################

echo ""
echo "==========================================="
echo "🚀 SISTEMA TOTALMENTE DEPLOYADO!"
echo "==========================================="
echo ""
echo "📊 Acessar Grafana:"
echo "  kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "  → http://localhost:3000"
echo ""
echo "  user: admin"
echo "  senha:"
echo "    kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
echo "📈 Acessar Prometheus:"
echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo "  → http://localhost:9090"
echo ""
echo "🌐 Acessar Webserver:"
echo "  kubectl port-forward svc/webserver-service -n default 8080:80"
echo "  → http://localhost:8080"
echo ""
echo "Todos os serviços rodando no cluster KIND + monitoramento ativo."
echo "==========================================="
