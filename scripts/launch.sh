#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER=filou-cluster

create() {
  echo "🚀 Création du cluster..."
  kind create cluster --name "$CLUSTER"

  # Install OLM
  echo "🚀 Installation d'Operator Lifecycle Manager..."
  echo "   Téléchargement et installation d'OLM v0.32.0..."
  curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.32.0/install.sh | bash -s v0.32.0

  # Check if OLM is installed
  echo "   Vérification de l'installation d'OLM..."
  if kubectl get namespace olm >/dev/null 2>&1; then
    echo "   ✅ OLM installé avec succès"
  else
    echo "   ❌ Échec de l'installation d'OLM"
    exit 1
  fi

  # Install ArgoCD Operator
  echo "🚀 Installation de l'opérateur ArgoCD..."
  "$PROJECT_ROOT/apps/argocd/launch.sh" up
}

install_argocd() {
  echo "🚀 Installation de l'opérateur ArgoCD..."
  "$PROJECT_ROOT/apps/argocd/launch.sh" up
}

uninstall_argocd() {
  echo "🗑️  Suppression de l'opérateur ArgoCD..."
  "$PROJECT_ROOT/apps/argocd/launch.sh" down
}

argocd_status() {
  echo "📊 Statut de l'opérateur ArgoCD..."
  "$PROJECT_ROOT/apps/argocd/launch.sh" status
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
  up)             create          ;;
  down)           delete          ;;
  start)          start           ;;
  stop)           stop            ;;
  argocd-up)      install_argocd  ;;
  argocd-down)    uninstall_argocd ;;
  argocd-status)  argocd_status   ;;
  *) 
    echo "Usage: $0 {up|down|start|stop|argocd-up|argocd-down|argocd-status}"
    echo ""
    echo "Ce script utilise exclusivement les opérateurs Kubernetes pour ArgoCD et Keycloak."
    echo ""
    echo "Commandes:"
    echo "  up              # Créer le cluster avec les opérateurs"
    echo "  down            # Supprimer le cluster"
    echo "  start           # Démarrer le cluster (s'il existe)"
    echo "  stop            # Arrêter le cluster"
    echo "  argocd-up       # Installer l'opérateur ArgoCD"
    echo "  argocd-down     # Supprimer l'opérateur ArgoCD"
    echo "  argocd-status   # Afficher le statut de l'opérateur ArgoCD"
    echo ""
    echo "Exemples:"
    echo "  $0 up                # Créer le cluster avec les opérateurs"
    echo "  $0 argocd-up         # Installer uniquement l'opérateur ArgoCD"
    exit 1 
    ;;
esac
