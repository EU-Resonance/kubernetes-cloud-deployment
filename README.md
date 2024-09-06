Overview of the repository

* [Installation of microk8s](./microk8s/microk8s-install.md)
* [Install argocd](./argocd/argocd-install.md)

# Simple Install
Ubuntu 22 LTS comes with new version of iptables firewall which is not supported by MicroK8S/Istio/calico by default (to be verified).
Legacy version of the iptables need to be selected in order to have firewall routing working
```bash
update-alternatives --set iptables /usr/sbin/iptables-legacy
``` 
Also there seems to be a problem starting calico-node with vanilla Ubuntu 22 that is due to cni-install -continer failing to start. 
Root cause is still unknown but Ubuntu MicroK8S instructions direct to modify ufw configuration with following commands:
```bash
ufw allow in on cni0 && sudo ufw allow out on cni0
ufw default allow routed
```
# Installin MicroK8S - simple and new
1. run restart.sh
2. make sure that sealed secrects are created OK (if not, Keycloack wont start)
3. build cluster (you may need to recreate sealed secrect after this step)
```bash
microk8s kubectl -v=0 kustomize /root/kubernetes-cloud-deployment/deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
```
4. Then certificate needs to be installed on Istio and it happens with this command:
```bash
microk8s kubectl create -n istio-system secret tls istio-gw-cert --key=/etc/cert/server.key --cert=/etc/cert/fullchain.crt
```
# Installin MicroK8S - old and difficult


MicroK8s should be then installed:
```bash
groupadd microk8s
newgrp microk8s
sudo usermod -a -G microk8s $(whoami)
snap install microk8s --classic
microk8s start
microk8s status --wait-ready
microk8s enable community 
microk8s enable dns storage istio

microk8s status
```
Now we've got to [broaden MicroK8s node port range][mk8s.port-range].
This is to make sure it'll be able to expose any K8s node port we're
going to use.

```bash
nano /var/snap/microk8s/current/args/kube-apiserver
# add this line
# --service-node-port-range=1-65535

microk8s stop
microk8s start
```

## Calico Trouble
Calico is a piece-of-I-do-not-want-to-say-what and after reboot it shits itself. This configuration seems to work somehow:
```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: calico-config
  namespace: kube-system
data:
  veth_mtu: "1400"
  cni_network_config: |
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "log_format": "json",
          "ipv4": true,
          "ipv6": true,
          "nodenameFileOptional": false,
          "nodename": "k8s-node-name"
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        }
      ]
    }
```
save that to yaml file and apply it to the cluster:
```bash
microk8s kubectl apply -f calico.yaml
```
Then you need to delete the calico-node -pod to restart it
```bash
microk8s kubectl delete pod <calico-node-pod> -n kube-system
```
## Rest of the Install Procedure
Since we're going to use vanilla cluster management tools instead of
MicroK8s wrappers, we've got to link up MicroK8s client config where
`kubectl` expects it to be:

```bash
mkdir -p ~/.kube
ln -s /var/snap/microk8s/current/credentials/client.config ~/.kube/config
```
Install Istio profile

```bash
microk8s istioctl install -y --verify -f deployment/mesh-infra/istio/profile.yaml 
```

Platform infra services (e.g. FIWARE) as well as app services (e.g.
AI) will sit in K8s' `default` namespace, so tell Istio to auto-magically
add an Envoy sidecar to each service deployed to that namespace

```bash
microk8s kubectl label namespace default istio-injection=enabled
```
Then build the cluster

```bash
microk8s kubectl -v=0 kustomize /root/kubernetes-cloud-deployment/deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
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

Certicates have maximum validity period of 13 months so you need to re-create certificates. For that to happen you need to delete old certificates from Istio:
```bash
microk8s kubectl delete -n istio-system secret istio-gw-cert
```
Then you need to re install certificates following the same procedure that is outlined above

## Github repo access
Copy-paste from ChatGPT
Generate an SSH Key Pair: If you don't already have an SSH key pair (public and private keys), you'll need to generate one. You can do this using the ssh-keygen command. Open your terminal and run:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

This command generates an SSH key pair and prompts you to save it in a specific location. By default, they are usually stored in ~/.ssh/.

Copy the Public Key: The public key is what you will add to your GitHub repository. You can view the public key by running:

```bash
cat ~/.ssh/id_rsa.pub
```
Copy the entire content of the public key.

Add the Deploy Key to Your GitHub Repository:

Go to your GitHub repository on the GitHub website.
Click on the "Settings" tab on the right-hand side.
In the left sidebar, click on "Deploy keys."
Add a Deploy Key:

Click the "Add deploy key" button.
Give the deploy key a title (for identification purposes).
Paste the copied public key into the "Key" field.

Create secret to Kubernetes with the SSH key. Following applies if you operate under root credentials
```bash
microk8s kubectl create secret generic my-ssh-key-secret --from-file=ssh-privatekey=/root/.ssh/id_rsa
```
# Other stuff
Sealed secret stuff is causing headache. Here is summary of what I have tried to do to get sealed secrects working
Bitnami kubeseal command needs to be installed
```bash
KUBESEAL_VERSION='' # Set this to, for example, KUBESEAL_VERSION='0.23.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```
Creating the secrets: 
```bash
cd deployment/mesh-infra/security/secrets
kubeseal -o yaml < templates/keycloak-builtin-admin.yaml > keycloak-builtin-admin.yaml
kubeseal -o yaml < templates/argocd.yaml > argocd.yaml
kubeseal -o yaml < templates/oidc-clients.yaml > oidc-clients.yaml
```

# Various Notes about solved problems
Once upon a time it happened that ArgoCD was giving an error about TLS client name not mathing when trying to use Keycloak for SSO. Problem also manifested in ArgoCD application 
view as an error of github.com certificate giving wrong name as cloudfire.com or what ever.

Root cause of this problem tuned out to be wrong or incompatible networkmanager configuration in the host system. This root cause was spotted by using nslookup on depug pod which gave 
wring address for github.com, but a right one for github.com. (note the last dot). /etc/resolv.conf had "network" as the last entry on the first line. When manually removed the nsloopup 
started working as expected.

Now resolv.conf is automatically generated configuration file and Ubuntu host system uses NetworkManager which creates this file. This offending "network entry" was also visible by using this command:
````
$: resolvectl status

Global
         Protocols: -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
  resolv.conf mode: stub
Current DNS Server: 8.8.8.8
       DNS Servers: 8.8.8.8

Link 2 (enp1s0)
    Current Scopes: DNS
         Protocols: +DefaultRoute +LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
Current DNS Server: 130.188.160.137
       DNS Servers: 8.8.8.8 8.8.4.4 130.188.160.137
        DNS Domain: network
````
Notice that last DNS Domain definition. To get rid of this properly requires to remove that Link 2 definition like so:
```
resolvectl revert enp1s0
```
And just like that it starts working

# Keycloak Configuration
Keycloak client id need to be configured to enable ArgoCD Single Sign On with Keycloak. Here are example steps to enable 
Keycloak login:
1. Login to Keycloak admin interface (e.g. https://<server>/auth)
2. Create client for Argocd on master realm in Clients tab:
    - General Settings: "Client type" -> OpenID Connect, "Client ID" -> argocd, "Name" -> ArgoCD Client, rest as defualt
    - Capability config: "Client Authentication" -> On, "Authentication Flow" -> check Standard flow and Direct access grants
    - Login settings: 
        - "Root URL" -> "https://<server>/argocd" 
        - "Home URL" -> "/applications"
        - "Valid redirect URIs" -> "https://<server>/argocd/auth/callback"
        - "Valid post logout redirect URIs" -> "https://<server>/argocd"
        - "Web origins" -> "https://<server>"
3. Base64 encode client secret from "Credentials" -tab under Clients -configuration
```bash
echo '<client secret>' | base64
```
4. Insert base64 encoded secret to /deployment/mesh-infra/security/secrets/templates/argocd.yaml field oidc.keycloak.clientSecret
5. Create ArgoCD client secret from template with kubeseal
```bash
cd deployment/mesh-infra/security/secrets
kubeseal -o yaml < templates/argocd.yaml > argocd.yaml
```
6. Push modified argocd.yaml to github and sync secrets from argocd UI
7. Back to Keycloak configs: Create Client Scope. name: groups and save
8. On the new scope config in Mappers -tab add "Group Membership" -mapper and define Name as "groups" Token Claim Name as "groups" and disable "Full group path"
9. Add newly created scope to the argocd client from "Clients"->"argocd"->"Client Scopes"->"Add client scope"->select "groups"->Add to "Default"
10. Create Group "ArgoCDAdmins" and add current admin user to the group

