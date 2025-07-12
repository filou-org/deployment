#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ArgoCD namespace
ARGOCD_NAMESPACE="argocd"

up() {
  echo "🚀 Installation de l'opérateur ArgoCD..."
  
  # Create namespace
  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Create operator group
  echo "   Création du groupe d'opérateurs..."
  kubectl create -n $ARGOCD_NAMESPACE -f "$SCRIPT_DIR/operator_group.yaml"
  
  # Wait for operator group to be ready
  echo "   Attente de la disponibilité du groupe d'opérateurs..."
  for i in {1..30}; do
    if kubectl get operatorgroup argocd-operator -n $ARGOCD_NAMESPACE -o jsonpath='{.status.lastUpdated}' 2>/dev/null; then
      echo "   ✅ Groupe d'opérateurs prêt"
      break
    fi
    echo "   ⏳ Attente du groupe d'opérateurs... ($i/30)"
    sleep 5
  done

  # Create subscription
  echo "   Création de la subscription..."
  kubectl create -n $ARGOCD_NAMESPACE -f "$SCRIPT_DIR/subscription.yaml"
  
  # Wait for subscription to be created
  echo "   Attente de la création de la subscription..."
  kubectl wait --for=condition=InstallPlanPending --timeout=60s subscription/argocd-operator -n "$ARGOCD_NAMESPACE" || {
    echo "   ⚠️  Subscription pas encore en attente, vérification..."
  }

  # Install ArgoCD instance
  echo "   Création de l'instance ArgoCD..."
  kubectl apply -n $ARGOCD_NAMESPACE -f "$SCRIPT_DIR/instance.yaml"

  # Check if all pods are running
  echo "   Vérification que tous les pods ArgoCD sont en cours d'exécution..."
  sleep 10
  kubectl wait --for=condition=Ready --timeout=120s --all pods -n "$ARGOCD_NAMESPACE" || {
    echo "   ❌ Timeout en attendant les pods ArgoCD"
    return 1
  }
  echo "   ✅ Tous les pods ArgoCD sont prêts"

  # Set admin password to 'password'  
  kubectl -n $ARGOCD_NAMESPACE patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
  kubectl delete pod -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server
  kubectl wait --for=condition=Ready --timeout=120s pod -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-server

  echo "Connectto ArgoCD server using login 'admin' and password 'password'"
  echo "kubectl port-forward svc/argocd-server 8080:80 -n $ARGOCD_NAMESPACE"

  echo "✅ Installation de l'opérateur ArgoCD terminée avec succès"
}

down() {
  # Delete all ArgoCD instances
  echo "   Suppression des instances ArgoCD..."
  kubectl delete argocds.argoproj.io --all -n "$ARGOCD_NAMESPACE"

  # On attend que les ressources soient bien supprimées pour éviter les blocages
  echo "   Attente de la suppression complète des instances..."
  kubectl wait --for=delete argocds.argoproj.io --all -n "$ARGOCD_NAMESPACE" --timeout=2m
  
  # Delete install plan
  echo "   Suppression du plan d'installation..."
  kubectl delete installplan -n "$ARGOCD_NAMESPACE" --all --ignore-not-found=true

  # Delete subscription
  echo "   Suppression de la subscription..."
  kubectl delete -f "$SCRIPT_DIR/subscription.yaml" --ignore-not-found=true
  
  # Delete operator group
  echo "   Suppression du groupe d'opérateurs..."
  kubectl delete operatorgroup argocd-operator -n "$ARGOCD_NAMESPACE" --ignore-not-found=true
  
  # Delete catalog source
  echo "   Suppression du catalog source..."
  kubectl delete catalogsource argocd-catalog -n olm --ignore-not-found=true
 
  # Delete namespace
  echo "   Suppression du namespace..."
  kubectl delete namespace "$ARGOCD_NAMESPACE" --ignore-not-found=true
  
  echo "✅ Suppression complète d'ArgoCD terminée"
}

status() {
  echo "📊 Statut de l'opérateur ArgoCD..."
  
  if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    echo "   Namespace $ARGOCD_NAMESPACE: ✅"
    
    echo "   Subscriptions:"
    kubectl get subscriptions -n "$ARGOCD_NAMESPACE" 2>/dev/null || echo "     Aucune subscription trouvée"
    
    echo "   Install Plans:"
    kubectl get installplans -n "$ARGOCD_NAMESPACE" 2>/dev/null || echo "     Aucun install plan trouvé"
    
    echo "   Pods:"
    kubectl get pods -n "$ARGOCD_NAMESPACE" 2>/dev/null || echo "     Aucun pod trouvé"
  else
    echo "   Namespace $ARGOCD_NAMESPACE: ❌ (n'existe pas)"
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
    echo "  up      - Installer l'opérateur ArgoCD"
    echo "  down    - Supprimer l'opérateur ArgoCD"
    echo "  status  - Afficher le statut de l'opérateur ArgoCD"
    exit 1 
    ;;
esac