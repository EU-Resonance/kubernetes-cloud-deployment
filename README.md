Overview of the repository

* [Installation of microk8s](./microk8s/microk8s-install.md)
* [Install argocd](./argocd/argocd-install.md)

# Simple Install
Ubuntu 22 LTS comes with new version of iptables firewall which is not supported by MicroK8S/Istio/calico by default (to be verified).
Legacy version of the iptables need to be selected in order to have firewall routing working
```bash
update-alternatives --set iptables /usr/sbin/iptables-legacy
``` 
MicroK8s should be then installed:
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
$ microk8s kubectl -v=0 kustomize /root/kubernetes-cloud-deployment/deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
```
# Configuration
## TLS
To enable TLS first valid certificates are needed. Firts create Certificate Signing Request with OpenSSL
```bash
openssl req -new -newkey rsa:2048 -noenc -keyout server.key -out generated.csr
```
This creates private key and CSR. It is important to save private key and copy it to /etc/cert (create the folder if necessary). 
CSR you need to copy-paste to certificate authoritys web site. Certificate provider then needs to validate your authority to host the domain. This can be done via DNS record (IMHO easiest) or via e-mail. For DNS validation you need to create DNS CNAME record as per instructions from certificate provider. 
Once domain has been validated you can download the public keys. Place them also to /etc/cert folder. Unless fullchain certifcate is provided, you need to create one.

For Sectigo certs (ouludatalab.fi) it would be created like this:
```bash
cat /etc/cert/STAR_ouludatalab_fi.crt /etc/cert/SectigoRSADomainValidationSecureServerCA.crt /etc/cert/USERTrustRSAAAACA.crt > /etc/cert/fullchain.crt
```
Then certificate needs to be installed on Istio and it happens with this command: 
```bash
microk8s kubectl create -n istio-system secret tls istio-gw-cert --key=/etc/cert/server.key --cert=/etc/cert/fullchain.crt
```
And thats it! You can verify the success by going to https://<server>/argocd and checking that certificate is accepted by the browser.
