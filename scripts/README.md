# Script de déploiement - launch.sh

Script de gestion du cycle de vie du cluster Kubernetes avec opérateurs.

## Utilisation

### Commandes principales
```bash
# Créer le cluster complet avec OLM + ArgoCD
./scripts/launch.sh up

# Supprimer le cluster
./scripts/launch.sh down

# Démarrer/arrêter le cluster existant
./scripts/launch.sh start
./scripts/launch.sh stop

# Gestion d'ArgoCD uniquement
./scripts/launch.sh argocd-up
./scripts/launch.sh argocd-down
./scripts/launch.sh argocd-status
```

## Composants déployés

### OLM (Operator Lifecycle Manager)
- **Version** : v0.32.0
- **Installation** : Automatique via script officiel

### ArgoCD Operator
- **Version** : v0.14.1
- **Configuration** : 
  - Mot de passe admin : `password`
  - Port-forward : `kubectl port-forward svc/argocd-server 8080:80 -n argocd`
  - Login : `admin` / `password`

## Accès ArgoCD

Après installation :
```bash
# Accès via port-forward
kubectl port-forward svc/argocd-server 8080:80 -n argocd

# Interface web : http://localhost:8080
# Login : admin
# Mot de passe : password
```

## Dépannage

### Vérifier l'état
```bash
# Statut général
./scripts/launch.sh argocd-status

# Pods ArgoCD
kubectl get pods -n argocd

# Logs opérateur
kubectl logs -f deployment/argocd-operator-controller-manager -n argocd
```

### Nettoyage complet
```bash
./scripts/launch.sh down
```
```

Ce README est beaucoup plus concis et reflète les changements actuels du script, notamment :
- La commande `up` qui installe OLM + ArgoCD
- Les nouvelles commandes `argocd-*` pour gérer ArgoCD séparément
- Le mot de passe admin configuré automatiquement
- Les instructions d'accès simplifiées
