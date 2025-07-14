# Générer un certificat TLS auto-signé pour Keycloak

1. Générer le certificat et la clé :

```sh
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=keycloak.local"
```

2. Créer le secret Kubernetes dans le namespace keycloak :

```sh
kubectl create secret tls keycloak-tls --cert=cert.pem --key=key.pem -n keycloak
```

3. Redémarrer le pod Keycloak pour qu'il prenne en compte le certificat :

```sh
kubectl delete pod -n keycloak -l app=keycloak
```

4. (Optionnel) Pour tester en local, ajoute dans /etc/hosts :
```
127.0.0.1 keycloak.local
```

5. Accéder à Keycloak en HTTPS :

- URL : https://keycloak.local:8443
- (Accepter le certificat auto-signé dans le navigateur) 