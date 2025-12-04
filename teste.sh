#!/usr/bin/env bash

# O script unificado cria um cluster Kind multinó, constrói e implanta
# os microsserviços (DBs, gRPC, Webserver) e instala o Prometheus/Grafana
# para monitoramento do cluster.

set -euo pipefail

# ====================================================================
# CONFIGURAÇÕES
# ====================================================================

CLUSTER_NAME="meucluster"
KIND_CONFIG="kind-multinode.yaml"
NAMESPACE="default"

# Diretórios e Tags de Imagem (baseados no seu script Minikube)
SERVER_A_DIR="./serverA"  # grpc-quiz
SERVER_B_DIR="./serverB"  # grpc-user
WEBSERVER_DIR="./webserver"
IMG_A="grpc-quiz:v1"
IMG_B="grpc-user:v1"
IMG_WEB="webserver:1.2"

# Lista de Manifestos de Aplicação
# CORREÇÃO: Limpeza de caracteres invisíveis (non-breaking spaces)
MANIFESTS=(
"kubernetes/01-db-quiz-deployment.yaml"
"kubernetes/03-app-quiz-deployment.yaml"
"kubernetes/02-db-user-deployment.yaml"
"kubernetes/04-app-user-deployment.yaml"
"kubernetes/webserver-app.yaml"
)

# Lista de Deployments para aguardar o Rollout
# CORREÇÃO: Limpeza de caracteres invisíveis (non-breaking spaces)
DEPLOYMENTS=(
"postgres-quiz-deployment"
"grpc-quiz-deployment"
"postgres-user-deployment"
"grpc-user-deployment"
"webserver-deployment"
)

# Array para armazenar nomes de imagens para carregamento no Kind
declare -a IMAGES_TO_LOAD=("$IMG_A" "$IMG_B" "$IMG_WEB")

# ====================================================================
# 1) PREPARAR E CRIAR O CLUSTER KIND MULTINÓ
# ====================================================================

echo "[KIND] Criando arquivo de cluster multinode..."
# CORREÇÃO: Garante que a indentação use APENAS espaços, evitando caracteres
# invisíveis (como o \u00a0) que quebram o parser YAML do Kind.
cat <<EOF > "$KIND_CONFIG"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "[KIND] Criando cluster ($CLUSTER_NAME) com 3 nós..."
kind delete cluster --name "$CLUSTER_NAME" || true
kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"

echo "[K8S] Aguardando nós ficarem prontos..."
kubectl wait --for=condition=Ready node --all --timeout=120s

# ====================================================================
# 2) BUILD E CARREGAMENTO DAS IMAGENS DA APLICAÇÃO
# ====================================================================

echo "[DEPLOY] Configurando docker-env local (não Minikube) para build..."
# O build será feito no ambiente local/host, não no Kind

echo "[DEPLOY] build ${IMG_A}..."
docker build -t "${IMG_A}" "${SERVER_A_DIR}"

echo "[DEPLOY] build ${IMG_B}..."
docker build -t "${IMG_B}" "${SERVER_B_DIR}"

echo "[DEPLOY] build ${IMG_WEB}..."
docker build -t "${IMG_WEB}" "${WEBSERVER_DIR}"

echo "[KIND] Carregando imagens no cluster Kind (crucial para multinó)..."
# O Kind precisa que as imagens sejam explicitamente carregadas nos nós
for img in "${IMAGES_TO_LOAD[@]}"; do
 echo " -> Carregando imagem: $img"
 kind load docker-image "$img" --name "$CLUSTER_NAME"
done

# ====================================================================
# 3) DEPLOY DA APLICAÇÃO (ConfigMaps, Manifests e Rollouts)
# ====================================================================

echo "[DEPLOY] Criando namespace se necessário: $NAMESPACE"
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# ConfigMaps
if [ -d "BD/quiz" ]; then
 echo "[DEPLOY] Atualizando ConfigMap quiz-sql-config..."
 kubectl create configmap quiz-sql-config --from-file=BD/quiz/ -n "$NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
else
 echo "[DEPLOY] (Aviso) Pasta BD/quiz não encontrada. ConfigMap quiz-sql-config ignorado."
fi

if [ -d "BD/user" ]; then
 echo "[DEPLOY] Atualizando ConfigMap user-sql-config..."
 kubectl create configmap user-sql-config --from-file=BD/user/ -n "$NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
else
 echo "[DEPLOY] (Aviso) Pasta BD/user não encontrada. ConfigMap user-sql-config ignorado."
fi

# Aplicar Manifests
echo "[DEPLOY] Aplicando manifestos da aplicação..."
for f in "${MANIFESTS[@]}"; do
 [ -f "$f" ] || { echo "[ERRO] Manifesto não encontrado: $f"; exit 1; }
 echo " -> Aplicando $f…"
 kubectl apply -n "$NAMESPACE" -f "$f"
done

# Esperar Rollouts
echo "[DEPLOY] Aguardando rollouts dos Deployments..."
for d in "${DEPLOYMENTS[@]}"; do
 echo " -> Aguardando rollout de $d…"
 kubectl rollout status -n "$NAMESPACE" deployment/"$d" --timeout=180s
done

echo "[DEPLOY] Aplicações prontas!"

# ====================================================================
# 4) INSTALAR KUBE-PROMETHEUS-STACK (MONITORAMENTO)
# ====================================================================

echo "[PROMETHEUS] Instalando kube-prometheus-stack..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1
helm repo update >/dev/null

helm install monitoring prometheus-community/kube-prometheus-stack \
 --namespace monitoring --create-namespace \
 --set grafana.enabled=true \
 --set prometheus.enabled=true \
 --set alertmanager.enabled=true \
 --wait

echo "[PROMETHEUS] Aguardando componentes de monitoramento..."
# Componentes principais (Deployments)
kubectl rollout status deploy/monitoring-grafana -n monitoring --timeout=180s
kubectl rollout status deploy/monitoring-kube-prometheus-operator -n monitoring --timeout=180s

# CORREÇÃO DE NOME: Prometheus e Alertmanager são StatefulSets com nomes específicos.
kubectl rollout status statefulset/monitoring-prometheus-kube-prometheus -n monitoring --timeout=180s
kubectl rollout status statefulset/monitoring-alertmanager -n monitoring --timeout=180s


# ====================================================================
# 5) MOSTRAR STATUS E COMO ACESSAR
# ====================================================================

echo ""
echo "======================================================"
echo "🚀 DEPLOY E MONITORAMENTO CONCLUÍDOS!"
echo "======================================================"

echo "[DEPLOY] Serviços da Aplicação:"
kubectl get svc -n "$NAMESPACE"

echo ""
echo "📈 Para acessar o Prometheus (Port-Forwarding):"
echo " kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo " → Acesse: http://localhost:9090"

echo ""
echo "📊 Para acessar o Grafana (Port-Forwarding):"
echo " kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo " → Acesse: http://localhost:3000"
echo " user: admin"
echo " senha (pegar com):"
echo "   kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
echo "Lembre-se: O Prometheus está monitorando apenas o CLUSTER por enquanto."
echo "Para monitorar suas APPs, você precisa criar recursos ServiceMonitor!"

echo "======================================================"

# Nota: O passo 8 do seu script Minikube foi removido, pois depende de variáveis (HAS_USUARIO, HAS_QUIZ)
# não definidas e logicaamente complexas em um ambiente de deploy simples.