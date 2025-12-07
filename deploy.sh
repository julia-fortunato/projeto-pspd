#!/bin/bash
set -euo pipefail



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


cat <<EOF > "$KIND_CONFIG"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF


kind delete cluster --name "$CLUSTER_NAME" || true


kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"





kubectl wait --for=condition=Ready node --all --timeout=120s








kubectl taint nodes -l node-role.kubernetes.io/control-plane='' node-role.kubernetes.io/control-plane- || true


kubectl taint nodes -l node-role.kubernetes.io/master='' node-role.kubernetes.io/master- || true





helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.enabled=true \
  --set alertmanager.enabled=true \
  --wait


kubectl rollout status deploy/monitoring-grafana -n monitoring --timeout=180s
kubectl rollout status deploy/monitoring-kube-prometheus-operator -n monitoring --timeout=180s
kubectl rollout status statefulset/prometheus-monitoring-kube-prometheus-prometheus -n monitoring --timeout=180s





kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"



kubectl create configmap quiz-sql-config \
  --from-file=BD/quiz/ -n "$NAMESPACE" \
  -o yaml --dry-run=client | kubectl apply -f -

kubectl create configmap user-sql-config \
  --from-file=BD/user/ -n "$NAMESPACE" \
  -o yaml --dry-run=client | kubectl apply -f -






docker build -t "$IMG_A" "$SERVER_A_DIR"
docker build -t "$IMG_B" "$SERVER_B_DIR"
docker build -t "$IMG_WEB" "$WEBSERVER_DIR"



kind load docker-image "$IMG_A" --name "$CLUSTER_NAME"
kind load docker-image "$IMG_B" --name "$CLUSTER_NAME"
kind load docker-image "$IMG_WEB" --name "$CLUSTER_NAME"






for f in "${MANIFESTS[@]}"; do
  
  kubectl apply -f "$f" -n "$NAMESPACE"
done






for d in "${DEPLOYMENTS[@]}"; do
  kubectl rollout status deployment/"$d" -n "$NAMESPACE" --timeout=180s
done







kubectl port-forward -n monitoring svc/monitoring-grafana 3535:80 >/dev/null 2>&1 &
PF_GRAFANA_PID=$!


kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
PF_PROM_PID=$!


kubectl port-forward -n "$NAMESPACE" svc/webserver-service 8080:6969 >/dev/null 2>&1 &
PF_WEB_PID=$!


sleep 3









echo "  Grafana"
echo "  URL:  http://localhost:3535"
echo "  PID do port-forward: $PF_GRAFANA_PID"
echo ""
echo "  user: admin"
echo "  senha:"
echo "    kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
echo "  Prometheus"
echo "  URL:  http://localhost:9090"
echo "  PID do port-forward: $PF_PROM_PID"
echo ""
echo "  Webserver"
echo "  URL:  http://localhost:8080"
echo "  PID do port-forward: $PF_WEB_PID"
