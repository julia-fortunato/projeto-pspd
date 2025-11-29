
#!/usr/bin/env bash
set -euo pipefail

# ========================
# 0) Criar cluster Minikube automaticamente
# ========================
echo "[deploy] verificando minikube..."

if ! command -v minikube &>/dev/null; then
  echo "[deploy] ERRO: minikube não encontrado no PATH."
  echo "Instale o Minikube antes de rodar o deploy."
  exit 1
fi

# Configs opcionais
MINIKUBE_CPUS=4
MINIKUBE_MEM=3072
MINIKUBE_DRIVER="docker"

echo "[deploy] iniciando cluster Minikube..."
minikube start --nodes=3 --driver="$MINIKUBE_DRIVER" --cpus="$MINIKUBE_CPUS" --memory="$MINIKUBE_MEM" || {
  echo "[deploy] Falha ao iniciar o Minikube."
  exit 1
}

# Certificar que o kubectl está apontando para o minikube
echo "[deploy] configurando kubectl..."
kubectl config use-context minikube

echo "[deploy] cluster criado e operacional!"


set -euo pipefail

# ===== config mínima =====
NAMESPACE="default"
SERVER_A_DIR="./serverA"   # grpc-quiz
SERVER_B_DIR="./serverB"   # grpc-user
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

echo "[deploy] checks básicos…"
command -v minikube >/dev/null || { echo "minikube não encontrado"; exit 1; }
command -v kubectl  >/dev/null || { echo "kubectl não encontrado"; exit 1; }
command -v docker   >/dev/null || { echo "docker não encontrado"; exit 1; }

# 1) start minikube se preciso
if ! minikube status -p minikube --output json | grep -q '"Host": "Running"'; then
  echo "[deploy] subindo minikube…"
  minikube start --driver=docker
else
  echo "[deploy] minikube já está rodando."
fi

# 2) namespace
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# 3) criar/atualizar ConfigMaps a partir das pastas locais BD/quiz e BD/user
#    (cada arquivo .sql vira um arquivo dentro da CM; a ordem de execução é alfabética)
if [ -d "BD/quiz" ]; then
  echo "[deploy] atualizando ConfigMap quiz-sql-config com BD/quiz/*.sql …"
  kubectl create configmap quiz-sql-config --from-file=BD/quiz/ -n "$NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
else
  echo "[deploy] (aviso) pasta BD/quiz não encontrada; init do quiz pode não ter SQLs."
fi

if [ -d "BD/user" ]; then
  echo "[deploy] atualizando ConfigMap user-sql-config com BD/user/*.sql …"
  kubectl create configmap user-sql-config --from-file=BD/user/ -n "$NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
else
  echo "[deploy] (aviso) pasta BD/user não encontrada; init do user pode não ter SQLs."
fi

# 4) usar daemon do minikube p/ build
echo "[deploy] configurando docker-env do minikube…"
eval "$(minikube -p minikube docker-env)"

# 5) build imagens
echo "[deploy] build ${IMG_A}…"
docker build -t "${IMG_A}" "${SERVER_A_DIR}"
echo "[deploy] build ${IMG_B}…"
docker build -t "${IMG_B}" "${SERVER_B_DIR}"
echo "[deploy] build ${IMG_WEB}…"
docker build -t "${IMG_WEB}" "${WEBSERVER_DIR}"

# 6) aplicar manifests na ordem
for f in "${MANIFESTS[@]}"; do
  [ -f "$f" ] || { echo "[erro] manifesto não encontrado: $f"; exit 1; }
  echo "[deploy] kubectl apply $f…"
  kubectl apply -n "$NAMESPACE" -f "$f"
done

# 7) esperar rollouts
for d in "${DEPLOYMENTS[@]}"; do
  echo "[deploy] aguardando rollout de $d…"
  kubectl rollout status -n "$NAMESPACE" deployment/"$d" --timeout=180s
done

# 8) se as tabelas não existirem, forçar reinit (apenas se for emptyDir)


if [ "$HAS_USUARIO" -ne 0 ] || [ "$HAS_QUIZ" -ne 0 ]; then
  echo "[deploy] faltam tabelas (usuario:${HAS_USUARIO}, quiz:${HAS_QUIZ}). Deletando pods para reexecutar initdb.d…"
  kubectl delete pod -n "$NAMESPACE" -l app=postgres-user --ignore-not-found
  kubectl delete pod -n "$NAMESPACE" -l app=postgres-quiz --ignore-not-found
  kubectl rollout status -n "$NAMESPACE" deployment/postgres-user-deployment --timeout=180s
  kubectl rollout status -n "$NAMESPACE" deployment/postgres-quiz-deployment --timeout=180s
fi

# 9) mostrar serviços
echo "[deploy] serviços:"
kubectl get svc -n "$NAMESPACE"

# 10) dica de teste rápido do webserver
WEB_URL="$(minikube service webserver-service -n "$NAMESPACE" --url 2>/dev/null | head -n1)"
[ -n "$WEB_URL" ] && echo "[deploy] webserver NodePort: $WEB_URL"

echo "[deploy] pronto! 🚀"
