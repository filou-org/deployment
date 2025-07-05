#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER=filou-cluster

create() {
  kind create cluster --name "$CLUSTER"
  # ① Installe Argo CD + patchs
  kubectl create namespace argocd
  kubectl apply -n argocd -k "$PROJECT_ROOT/bootstrap/argocd"
  echo ">> Attente du serveur Argo CD..."
  kubectl -n argocd wait deploy/argocd-server \
      --for=condition=Available --timeout=120s

  password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  echo "Argo CD admin password: $password"

  # ② Bootstrapp App-of-Apps
  kubectl apply -k "$PROJECT_ROOT/apps"
  echo "Cluster prêt !"
}

stop() {                       # met les conteneurs en pause
  docker pause $(docker ps -q -f label=io.x-k8s.kind.cluster="${CLUSTER}")
}

start() {                      # relance un cluster déjà créé
  docker unpause $(docker ps -q -f label=io.x-k8s.kind.cluster="${CLUSTER}")
}

delete() {                     # supprime entièrement le cluster
  kind delete cluster --name "$CLUSTER"
}

case "${1:-help}" in
  up)       create   ;;
  down)     delete   ;;
  start)    start    ;;
  stop)     stop     ;;
  restart) delete && create ;;
  *) echo "Usage: $0 {up|down|start|stop|restart}"; exit 1 ;;
esac
