nano /var/snap/microk8s/current/args/kube-apiserver
# add this line
# --service-node-port-range=1-65535

microk8s stop
microk8s start


istioctl install -y --verify -f profile.yaml


kubectl label namespace default istio-injection=enabled
