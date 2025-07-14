#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keycloak namespace
KEYCLOAK_NAMESPACE="keycloak"

up() {
  echo "🚀 Installation de l'opérateur Keycloak..."
  
  # Create namespace
  kubectl create namespace "$KEYCLOAK_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Create operator group
  echo "   Création du groupe d'opérateurs..."
  kubectl apply -n $KEYCLOAK_NAMESPACE -f "$SCRIPT_DIR/operator_group.yaml"
  
  # Wait for operator group to be ready
  echo "   Attente de la disponibilité du groupe d'opérateurs..."
  for i in {1..30}; do
    if kubectl get operatorgroup keycloak-operator -n $KEYCLOAK_NAMESPACE -o jsonpath='{.status.lastUpdated}' 2>/dev/null; then
      echo "   ✅ Groupe d'opérateurs prêt"
      break
    fi
    echo "   ⏳ Attente du groupe d'opérateurs... ($i/30)"
    sleep 5
  done

  # Create subscription
  echo "   Création de la subscription..."
  kubectl apply -n $KEYCLOAK_NAMESPACE -f "$SCRIPT_DIR/subscription.yaml"
  
  # Wait for subscription to be created
  echo "   Attente de la création de la subscription..."
  kubectl wait --for=condition=InstallPlanPending --timeout=120s subscription/keycloak-operator -n "$KEYCLOAK_NAMESPACE" || {
    echo "   ⚠️  Subscription pas encore en attente, vérification..."
  }

  # Wait for operator to be installed and CRDs to be available
  echo "   Attente de l'installation de l'opérateur et des CRDs..."
  for i in {1..60}; do
    if kubectl get crd keycloaks.k8s.keycloak.org >/dev/null 2>&1; then
      echo "   ✅ CRDs Keycloak disponibles"
      break
    fi
    echo "   ⏳ Attente des CRDs Keycloak... ($i/60)"
    sleep 10
  done

  # Install Keycloak instance
  echo "   Création de l'instance Keycloak..."
  kubectl apply -n $KEYCLOAK_NAMESPACE -f "$SCRIPT_DIR/instance.yaml"

  # Check if all pods are running
  echo "   Vérification que tous les pods Keycloak sont en cours d'exécution..."
  sleep 30
  kubectl wait --for=condition=Ready --timeout=120s --all pods -n "$KEYCLOAK_NAMESPACE" || {
    echo "   ❌ Timeout en attendant les pods Keycloak"
    return 1
  }
  echo "   ✅ Tous les pods Keycloak sont prêts"

  # Create ArgoCD Application
  echo "   Création de l'application ArgoCD..."
  kubectl apply -f "$SCRIPT_DIR/application.yaml"

  echo "✅ Installation de l'opérateur Keycloak terminée avec succès"
}

down() {
  # Delete all Keycloak instances
  echo "   Suppression des instances Keycloak..."
  kubectl delete keycloaks.k8s.keycloak.org --all -n "$KEYCLOAK_NAMESPACE"

  # On attend que les ressources soient bien supprimées pour éviter les blocages
  echo "   Attente de la suppression complète des instances..."
  kubectl wait --for=delete keycloaks.k8s.keycloak.org --all -n "$KEYCLOAK_NAMESPACE" --timeout=2m
  
  # Delete install plan
  echo "   Suppression du plan d'installation..."
  kubectl delete installplan -n "$KEYCLOAK_NAMESPACE" --all --ignore-not-found=true

  # Delete subscription
  echo "   Suppression de la subscription..."
  kubectl delete -f "$SCRIPT_DIR/subscription.yaml" --ignore-not-found=true
  
  # Delete catalog source
  echo "   Suppression du catalog source..."
  kubectl delete catalogsource keycloak-catalog -n olm --ignore-not-found=true
 
  # Delete namespace
  echo "   Suppression du namespace..."
  kubectl delete namespace "$KEYCLOAK_NAMESPACE" --ignore-not-found=true
  
  echo "✅ Suppression complète de Keycloak terminée"
}

status() {
  echo "📊 Statut de l'opérateur Keycloak..."
  
  if kubectl get namespace "$KEYCLOAK_NAMESPACE" >/dev/null 2>&1; then
    echo "   Namespace $KEYCLOAK_NAMESPACE: ✅"
    
    echo "   Subscriptions:"
    kubectl get subscriptions -n "$KEYCLOAK_NAMESPACE" 2>/dev/null || echo "     Aucune subscription trouvée"
    
    echo "   Install Plans:"
    kubectl get installplans -n "$KEYCLOAK_NAMESPACE" 2>/dev/null || echo "     Aucun install plan trouvé"
    
    echo "   Pods:"
    kubectl get pods -n "$KEYCLOAK_NAMESPACE" 2>/dev/null || echo "     Aucun pod trouvé"
  else
    echo "   Namespace $KEYCLOAK_NAMESPACE: ❌ (n'existe pas)"
  fi
}

case "${1:-help}" in
  up)       up       ;;
  down)     down     ;;
  status)   status   ;;
  *) 
    echo "Usage: $0 {up|down|status}"
    echo ""
    echo "Commandes:"
    echo "  up      - Installer l'opérateur Keycloak"
    echo "  down    - Supprimer l'opérateur Keycloak"
    echo "  status  - Afficher le statut de l'opérateur Keycloak"
    exit 1 
    ;;
esac