#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="meucluster"
KIND_CONFIG="kind-multinode.yaml"

# ========================
# 0) Verificações iniciais
# ========================
echo "[deploy] verificando dependências..."

command -v kind    >/dev/null || { echo "kind não encontrado";    exit 1; }
command -v docker  >/dev/null || { echo "docker não encontrado";  exit 1; }
command -v kubectl >/dev/null || { echo "kubectl não encontrado"; exit 1; }
command -v helm    >/dev/null || { echo "helm não encontrado. Instale em: https://helm.sh/"; exit 1; }

echo "[deploy] criando arquivo de configuração KIND..."

cat <<EOF > "$KIND_CONFIG"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "[deploy] verificando se o cluster KIND já existe…"

if kind get clusters | grep -q "^${CLUSTER_NAME}\$"; then
    echo "[deploy] cluster '${CLUSTER_NAME}' já existe. Usando ele."
else
    echo "[deploy] criando cluster multinode REAL '${CLUSTER_NAME}'…"
    kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi

echo "[deploy] esperando nós ficarem prontos…"
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl get nodes -o wide

echo "[deploy] cluster KIND OK! 🚀"


# ========================
# 1) Variáveis gerais e Namespace App
# ========================
NAMESPACE="default"
MONITORING_NS="monitoring"

SERVER_A_DIR="./serverA"
SERVER_B_DIR="./serverB"
WEBSERVER_DIR="./webserver"

IMG_A="grpc-quiz:v1"
IMG_B="grpc-user:v1"
IMG_WEB="webserver:1.2"

MANIFESTS=(
  "kubernetes/01-db-quiz-deployment.yaml"
  "kubernetes/03-app-quiz-deployment.yaml"
  "kubernetes/02-db-user-deployment.yaml"
  "kubernetes/04-app-user-deployment.yaml"
  "kubernetes/webserver-app.yaml"
)

DEPLOYMENTS=(
  "postgres-quiz-deployment"
  "grpc-quiz-deployment"
  "postgres-user-deployment"
  "grpc-user-deployment"
  "webserver-deployment"
)

echo "[deploy] criando namespace da aplicação..."
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"


# ========================
# 1.5) [PROMETHEUS] Instalação da Stack de Monitoramento
# ========================
echo "----------------------------------------------------"
echo "[deploy] Iniciando configuração do Prometheus/Grafana..."

# Criar namespace de monitoramento
kubectl get ns "$MONITORING_NS" >/dev/null 2>&1 || kubectl create namespace "$MONITORING_NS"

# Adicionar repo do prometheus community se não existir
if ! helm repo list | grep -q "prometheus-community"; then
    echo "[deploy] adicionando helm repo prometheus-community..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

# LIMPEZA DE SEGURANÇA
if helm status prometheus-stack -n "$MONITORING_NS" >/dev/null 2>&1; then
    echo "[deploy] Instalação anterior detectada. Removendo para garantir uma instalação limpa..."
    helm uninstall prometheus-stack -n "$MONITORING_NS" --wait || true
    echo "[deploy] Forçando remoção de pods antigos..."
    kubectl delete pods --all -n "$MONITORING_NS" --force --grace-period=0 2>/dev/null || true
    sleep 5
fi

echo "[deploy] instalando/atualizando kube-prometheus-stack (Otimizado para Kind)..."

# --- CORREÇÃO DEFINITIVA ---
# 1. Control Plane desabilitado (etcd/scheduler/controller).
# 2. NodeExporter DESABILITADO (nodeExporter.enabled=false). Ele é o culpado pelo travamento.
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NS" \
  --create-namespace \
  --set grafana.adminPassword="admin" \
  --set kubeEtcd.enabled=false \
  --set kubeControllerManager.enabled=false \
  --set kubeScheduler.enabled=false \
  --set nodeExporter.enabled=false \
  --wait --timeout 600s

echo "[deploy] Prometheus Stack instalada com sucesso!"
echo "----------------------------------------------------"


# ========================
# 2) ConfigMaps do SQL
# ========================
if [ -d "BD/quiz" ]; then
  echo "[deploy] atualizando ConfigMap quiz-sql-config…"
  kubectl create configmap quiz-sql-config \
    --from-file=BD/quiz/ \
    -n "$NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
else
  echo "[deploy] [AVISO] Pasta BD/quiz não encontrada."
fi

if [ -d "BD/user" ]; then
  echo "[deploy] atualizando ConfigMap user-sql-config…"
  kubectl create configmap user-sql-config \
    --from-file=BD/user/ \
    -n "$NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
else
  echo "[deploy] [AVISO] Pasta BD/user não encontrada."
fi


# ========================
# 3) Build das imagens e carregar no KIND
# ========================
echo "[deploy] docker build local…"

docker build -t "${IMG_A}"   "${SERVER_A_DIR}"
docker build -t "${IMG_B}"   "${SERVER_B_DIR}"
docker build -t "${IMG_WEB}" "${WEBSERVER_DIR}"

echo "[deploy] carregando imagens para dentro do cluster KIND…"
kind load docker-image "${IMG_A}"   --name "$CLUSTER_NAME"
kind load docker-image "${IMG_B}"   --name "$CLUSTER_NAME"
kind load docker-image "${IMG_WEB}" --name "$CLUSTER_NAME"


# ========================
# 4) Aplicar manifests
# ========================
echo "[deploy] aplicando manifests da aplicação..."

for f in "${MANIFESTS[@]}"; do
  [ -f "$f" ] || { echo "[erro] manifesto não encontrado: $f"; exit 1; }
  echo "[deploy] kubectl apply $f…"
  kubectl apply -n "$NAMESPACE" -f "$f"
done


# ========================
# 5) Esperar deployments
# ========================
echo "[deploy] aguardando rollouts da aplicação..."

for d in "${DEPLOYMENTS[@]}"; do
  echo "[deploy] aguardando $d…"
  kubectl rollout status -n "$NAMESPACE" deployment/"$d" --timeout=180s
done


# ========================
# 6) Forçar reinit se tabelas SQL faltarem
# ========================
echo "[deploy] verificando tabelas (tentativa segura)..."

check_tables() {
  local label="$1"
  local pod
  pod=$(kubectl get pod -n "$NAMESPACE" -l "app=${label}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$pod" ]; then
    echo "0"
    return
  fi

  if kubectl exec -n "$NAMESPACE" "$pod" -- bash -c "pg_isready -q"; then
    if kubectl exec -n "$NAMESPACE" "$pod" -- psql -U postgres -d postgres -c '\dt' >/dev/null 2>&1; then
      echo "1"
    else
      echo "0"
    fi
  else
    echo "0"
  fi
}

HAS_USUARIO=$(check_tables "postgres-user")
HAS_QUIZ=$(check_tables "postgres-quiz")

if [ "$HAS_USUARIO" -eq 0 ] || [ "$HAS_QUIZ" -eq 0 ]; then
  echo "[deploy] tabelas ausentes! Forçando reinit dos pods…"

  kubectl delete pod -n "$NAMESPACE" -l app=postgres-user --ignore-not-found
  kubectl delete pod -n "$NAMESPACE" -l app=postgres-quiz --ignore-not-found

  kubectl rollout status -n "$NAMESPACE" deployment/postgres-user-deployment --timeout=180s
  kubectl rollout status -n "$NAMESPACE" deployment/postgres-quiz-deployment --timeout=180s
fi


# ========================
# 7) Serviços e exposição externa
# ========================
echo "----------------------------------------------------"
echo "[deploy] Configurando acesso externo..."

# -- Função IP Host --
get_host_ip() {
  for ip in $(hostname -I); do
    if [[ "$ip" =~ ^192\.168\. ]] || [[ "$ip" =~ ^10\. ]] || ([[ "$ip" =~ ^172\. ]] && ! [[ "$ip" =~ ^172\.1[6-9]\. ]] ); then
      echo "$ip"
      return
    fi
  done
  for ip in $(hostname -I); do
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$ip"
      return
    fi
  done
  echo "127.0.0.1"
}
HOST_IP=$(get_host_ip)

# --- Exposição Webserver ---
if ! kubectl get svc webserver-service -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "[erro] webserver-service não encontrado."
else
  NODE_PORT_WEB=$(kubectl get svc webserver-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
  TARGET_PORT_WEB=$(kubectl get svc webserver-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
  
  # Limpar anterior
  pkill -f "kubectl port-forward .*webserver-service" >/dev/null 2>&1 || true
  
  # Forward na porta do NodePort ou 8080
  LOCAL_PORT_WEB="$NODE_PORT_WEB"
  echo "[deploy] Expondo Webserver na porta $LOCAL_PORT_WEB..."
  
  kubectl port-forward --address 0.0.0.0 svc/webserver-service "${LOCAL_PORT_WEB}:${TARGET_PORT_WEB}" -n "$NAMESPACE" >/dev/null 2>&1 &
  PF_WEB_PID=$!
fi

# --- Exposição Grafana [PROMETHEUS] ---
GRAFANA_SVC="prometheus-stack-grafana"
LOCAL_PORT_GRAFANA=3000

echo "[deploy] Verificando serviço Grafana..."
# Aguarda o pod estar running primeiro para evitar falha no port-forward
kubectl wait --namespace "$MONITORING_NS" --for=condition=ready pod --selector=app.kubernetes.io/name=grafana --timeout=300s

echo "[deploy] Expondo Grafana na porta $LOCAL_PORT_GRAFANA..."
pkill -f "kubectl port-forward .*$GRAFANA_SVC" >/dev/null 2>&1 || true

kubectl port-forward --address 0.0.0.0 -n "$MONITORING_NS" svc/$GRAFANA_SVC "${LOCAL_PORT_GRAFANA}:80" >/dev/null 2>&1 &
PF_GRAFANA_PID=$!


# ========================
# 8) Resumo Final
# ========================
sleep 3 # Estabilizar forwards

echo ""
echo "========================================================"
echo "DEPLOY CONCLUÍDO COM SUCESSO! 🚀"
echo "========================================================"
echo ""
echo "📱 Aplicação Web:"
echo "   URL: http://${HOST_IP}:${LOCAL_PORT_WEB}"
echo ""
echo "📊 Monitoramento (Grafana):"
echo "   URL: http://${HOST_IP}:${LOCAL_PORT_GRAFANA}"
echo "   Usuário: admin"
echo "   Senha:   admin"
echo ""
echo "Observações:"
echo " - PIDs dos Port-Forwards: Web ($PF_WEB_PID), Grafana ($PF_GRAFANA_PID)"
echo " - Para parar, rode: kill $PF_WEB_PID $PF_GRAFANA_PID"
echo ""

# Salvar PIDs
echo "$PF_WEB_PID" > /tmp/webserver-pf.pid
echo "$PF_GRAFANA_PID" > /tmp/grafana-pf.pid