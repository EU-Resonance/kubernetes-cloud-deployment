# Troubles
List of the problems encountered with the Cluster
# DNS
This error is due to the DNS queries not resolving correctly. CoreDNS configuration and host server resolv-conf should be correctly set.

Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = Get "https://github.com/Advanced-Dataspaces-VTT/kubernetes-cloud-deployment/info/refs?service=git-upload-pack": tls: failed to verify certificate: x509: certificate is valid for cloudfront.net, *.cloudfront.net, not github.com

To resolve this check the server resolv configuration and change if necessary. I had to do this:
```bash
resolvectl domain enp1s0 cluster.local
```
Then restart the microk8s and pods

# Calico Pod initialization
When ever microk8s is restarted calico-node fails to restart with error 
Error: couldn't find key calico_backend in ConfigMap kube-system/calico-config

Check that those configurations are defined at deployment/mesh-infra/routing/calico-config.yaml
If you need to change it remember to reapply the configurations and delete failed calico-node pod
```bash
microk8s kubectl -v=0 kustomize /root/kubernetes-cloud-deployment/deployment/mesh-infra/ | microk8s kubectl -v=0 apply -f -
microk8s kubectl delete pod calico-node-<key> -n kube-system
```
That should do it

