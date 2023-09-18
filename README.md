Overview of the repository

* [Installation of microk8s](./microk8s/microk8s-install.md)
* [Install argocd](./argocd/argocd-install.md)

# Simple Install

```bash
$ newgrp microk8s
$ sudo usermod -a -G microk8s $(whoami)
$ snap install microk8s --classic

$ microk8s status --wait-ready

$ microk8s enable community dns storage istio

$ microk8s status
```
Now we've got to [broaden MicroK8s node port range][mk8s.port-range].
This is to make sure it'll be able to expose any K8s node port we're
going to use.

```bash
$ nano /var/snap/microk8s/current/args/kube-apiserver
# add this line
# --service-node-port-range=1-65535

$ microk8s stop
$ microk8s start
```

Since we're going to use vanilla cluster management tools instead of
MicroK8s wrappers, we've got to link up MicroK8s client config where
`kubectl` expects it to be:

```bash
$ mkdir -p ~/.kube
$ ln -s /var/snap/microk8s/current/credentials/client.config ~/.kube/config
```
Install Istio profile

```bash
$ microk8s istioctl install -y --verify -f deployment/mesh-infra/istio/profile.yaml 
```

Platform infra services (e.g. FIWARE) as well as app services (e.g.
AI) will sit in K8s' `default` namespace, so tell Istio to auto-magically
add an Envoy sidecar to each service deployed to that namespace

```bash
$ microk8s kubectl label namespace default istio-injection=enabled
```
Then build the cluster

```bash
$ micr0k8s kustomize build \
    https://github.com/c0c0n3/kitt4sme.live/deployment/mesh-infra/argocd | \
    kubectl apply -f -
```
