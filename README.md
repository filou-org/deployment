# Filou deployment

### Local tests requirements

Voici la liste des projets nécessaires au déploiement en local :
 - [docker](https://docs.docker.com/engine/install/ubuntu/)
 - [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-source)
 - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
 - [argocd](https://argo-cd.readthedocs.io/en/stable/getting_started/)
 - [argocd-cli](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
 - [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/)
 
Démarrage du projet en local :

```bash
./scripts/launch.sh up
```

argocd main cli :

```bash
argocd login localhost:8080 --username admin --password XXX --insecure
```

Accés à argocd UI :

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Aller sur http://localhost:8080
```