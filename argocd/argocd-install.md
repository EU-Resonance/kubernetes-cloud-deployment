# Installing and Using ArgoCD

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. This README.md guide will walk you through the steps to install and use ArgoCD on your Kubernetes cluster.

## Prerequisites

Before you begin, ensure you have the following prerequisites:

A running Kubernetes cluster. You can use MicroK8s or any other Kubernetes distribution for this purpose.
kubectl installed and configured to access your Kubernetes cluster.
Installation Steps

## Follow these steps to install and use ArgoCD:

1. Install ArgoCD
You can install ArgoCD using kubectl by applying its manifests:

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
2. Accessing the ArgoCD Web UI
ArgoCD provides a web-based user interface. To access it, you need to expose the ArgoCD server as a service with a LoadBalancer or NodePort. For example, to expose it via a NodePort, you can use the following command:

```
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```
Now, find out which port the service is exposed on:

```
kubectl get svc argocd-server -n argocd -o=jsonpath='{.spec.ports[0].nodePort}'
```
You can access the ArgoCD web UI by navigating to http://<your-node-ip>:<node-port> in your web browser.

3. Logging in to ArgoCD
By default, ArgoCD uses the Kubernetes authentication system. To log in, use the credentials of your Kubernetes cluster. Alternatively, you can configure ArgoCD to use other authentication methods if needed.

4. Deploying Applications
To deploy applications with ArgoCD, create an Application resource that defines your desired state. Here's an example of an Application manifest for deploying a sample application from a Git repository:

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/yourusername/your-app-repo.git
    targetRevision: HEAD
    path: .
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
```
Apply this manifest to deploy your application:

```
kubectl apply -n argocd -f my-app.yaml
```
ArgoCD will synchronize the application with the desired state defined in your Git repository.

5. Monitoring and Syncing Applications
You can monitor the status of your applications and trigger synchronization manually using the ArgoCD web UI or the argocd CLI tool. For example, to manually sync your application, you can run:

```
argocd app sync my-app
```

6. Cleaning Up
To uninstall ArgoCD and remove all associated resources, you can use the following commands:

```
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

Conclusion

You have now successfully installed ArgoCD and deployed an application using GitOps principles. You can explore more features and options in the ArgoCD documentation: ArgoCD Documentation.