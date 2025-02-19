Overview of the repository

* [Installation of microk8s](./microk8s/microk8s-install.md)
* [Install argocd](./argocd/argocd-install.md)

# System installation
Pre-requisites for running the cluster is to use legacy iptables (microk8s does seem to have issue with default nft version of iptables). To switch legacy iptables do this:
````
sudo update-alternatives --config iptables
[sudo] password for vmuser: 
There are 2 choices for the alternative iptables (providing /usr/sbin/iptables).

  Selection    Path                       Priority   Status
------------------------------------------------------------
  0            /usr/sbin/iptables-nft      20        auto mode
* 1            /usr/sbin/iptables-legacy   10        manual mode
  2            /usr/sbin/iptables-nft      20        manual mode

Press <enter> to keep the current choice[*], or type selection number: 1
````
You can try not to do this but in case you you do not get kubernetes chains in iptables, you need to change to legacy version and restart the microk8s. Iptables you can list whith this command:

````
sudo iptables -L -n -v
````

1. run restart.sh
2. make sure that sealed secrects are created OK (if not, Keycloack wont start)
3. build cluster (you may need to recreate sealed secrect after this step)
```bash
microk8s kubectl -v=0 kustomize deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
```
4. Then certificate needs to be installed on Istio and it happens with this command:
```bash
microk8s kubectl create -n istio-system secret tls istio-gw-cert --key=/etc/cert/server.key --cert=/etc/cert/fullchain.crt
```
replace certificate and private key paths with the correct ones

## Rest of the Install Procedure

In case cluster build did not got everything right, wait a minute and try again with this command:
```bash
microk8s kubectl -v=0 kustomize deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
```
It can happen that some services and pods are not started fast enough and rest of the process may suffer from it. Trying a gain should fix any
unsuccessful component install

# Configuration
## TLS
If you do not already have valid TLS certificates, do this. To enable TLS first valid certificates are needed. Firts create Certificate Signing Request with OpenSSL. NOTE that you
can usually generate this on the online service as well. In that case remember to save the CSR and KEY files because you will need those later in life.
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
When you modify secrets templates you need to create them again and apply them them. Creating the secrets: 
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
wrong address for github.com, but a right one for github.com. (note the last dot). /etc/resolv.conf had "network" as the last entry on the first line. When manually removed the nsloopup 
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

### Issues related to deploying cluster on new domain
You should be mindful with github repo links if you forget to update links you might end up pulling stuff from wrong repos. This is file that you also need to update
````
deployment/mesh-infra/argocd/projects/base/app.yaml
````


## Setting Static Nameserver Config on the Host
This is from ChatGPT:
### Method 1: Modify /etc/netplan (For newer versions of Ubuntu using Netplan)
Edit Netplan Configuration:

Open the Netplan configuration file (usually found in /etc/netplan/).
```
sudo nano /etc/netplan/00-installer-config.yaml
```
Add Static DNS Servers:

In the configuration file, find the section under ethernets (for wired connections) or wifis (for wireless), and add the nameservers directive with your desired DNS servers. Example for a static Ethernet IP configuration:
````
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      dhcp4: true
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
````
Apply the Configuration:

After saving the file, apply the changes by running:
```
sudo netplan apply
```
#### Method 2: Modify /etc/resolv.conf (Temporary Change)
This method is not persistent across reboots, as Ubuntu uses systemd-resolved to manage DNS settings.

Edit /etc/resolv.conf:

````
sudo nano /etc/resolv.conf
````
Set Static DNS:

Add your nameserver line to the file:
````
nameserver 8.8.8.8
nameserver 8.8.4.4
````
Save and Exit:

Note: If using systemd-resolved, the changes may not persist after reboot.

### Method 3: Use systemd-resolved (Persistent for systemd)
Create or Edit a Configuration File: You can configure DNS through systemd-resolved by editing the file /etc/systemd/resolved.conf.

````
sudo nano /etc/systemd/resolved.conf
````
Set DNS Servers:

Under the [Resolve] section, uncomment and set the DNS servers:
````
[Resolve]
DNS=8.8.8.8 8.8.4.4
FallbackDNS=1.1.1.1
````
Restart systemd-resolved: After saving the file, restart the systemd-resolved service:
````
sudo systemctl restart systemd-resolved
````
Verify the DNS Configuration:
````
resolvectl status
````
This will set a static DNS server that persists across reboots.

# Using debug-pod

There is a debug-pod deployement file at the folder deployement. You can install it and it will deploy standard Ubuntu VM pod to test the
kubernetes system. Installation happens like this:
````
microk8s kubectl apply -f deployment/debug-pod.yaml 
````
You can then log into the pod like this:
````
microk8s kubectl exec -it debug-pod -- /bin/bash
````
Debug pod is minimal debian/ubuntu distro so you need to install some tools to make it useful:
````
apt update
apt install dnsutils
apt install net-tools
````
Then you can use tools like nslookup to debug networking problems


# Keycloak Configuration
Note that Keycloak clients are available as JSON structures in "keycloak-clients" -directory. You can import these but you need to do 
other modifications like groups, client scopes, etc. by hand.

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
To restart the argocd server user this command:
````
microk8s kubectl rollout restart deployment argocd-server -n argocd
````

