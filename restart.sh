#!/bin/bash
USERNAME=$USER
EXTERNAL_IP=$(hostname -I | awk '{print $1}')
#EXTERNAL_IP=$(curl -s https://api64.ipify.org)
sudo snap remove --purge microk8s
sudo iptables -F
sudo iptables -X
sudo snap install microk8s --classic --channel=1.32/stable
sudo usermod -a -G microk8s $USERNAME
microk8s start
microk8s status --wait-ready
microk8s enable community
microk8s enable dns
microk8s enable metallb:$EXTERNAL_IP-$EXTERNAL_IP
sudo microk8s enable hostpath-storage
sudo microk8s enable istio
microk8s status
microk8s stop
sudo echo "--service-node-port-range=1-65535" >> /var/snap/microk8s/current/args/kube-apiserver
microk8s start
microk8s status --wait-ready
microk8s.helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
microk8s.helm repo add bitnami https://charts.bitnami.com/bitnami
microk8s.helm repo update
microk8s.helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system --create-namespace
#microk8s.helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets
microk8s.kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/kustomization.yaml

mkdir -p ~/.kube
ln -s /var/snap/microk8s/current/credentials/client.config ~/.kube/config
microk8s istioctl install -y --verify -f deployment/mesh-infra/istio/profile.yaml
microk8s kubectl label namespace default istio-injection=enabled

#
# Build cluster
#
microk8s.kubectl -v=0 kustomize deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
# Above install does not go thru all that well so we need to run it again but first wait for a while to let the cluster to absorb above
sleep 10
microk8s.kubectl -v=0 kustomize deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
sudo microk8s.kubectl create -n istio-system secret tls istio-gw-cert --key=/etc/cert/server.key --cert=/etc/cert/fullchain.crt
#
# Create sealed secrets from templates
#
cd deployment/mesh-infra/security/secrets
kubeseal -o yaml < templates/keycloak-builtin-admin.yaml > keycloak-builtin-admin.yaml
kubeseal -o yaml < templates/argocd.yaml > argocd.yaml
kubeseal -o yaml < templates/oidc-clients.yaml > oidc-clients.yaml
microk8s.kubectl apply -f keycloak-builtin-admin.yaml
microk8s.kubectl apply -f argocd.yaml
microk8s.kubectl apply -f oidc-clients.yaml
cd ../../../../

microk8s.kubectl get secrets --all-namespaces

