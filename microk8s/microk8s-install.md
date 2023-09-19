# Installing MicroK8s

MicroK8s is a lightweight Kubernetes distribution designed for local development and testing. This README.md guide will walk you through the steps to install MicroK8s on your system.

## Prerequisites

Before you begin, ensure you have the following prerequisites:

A Linux-based system (MicroK8s is primarily designed for Linux)
Snapd installed (Snapd is a package manager for Linux, and it's used to install MicroK8s)
Installation Steps

## Follow these steps to install MicroK8s on your system:

1. Install Snapd
If you don't have Snapd installed, you can install it using the package manager specific to your Linux distribution. For example, on Ubuntu, you can run:

```
sudo apt update
sudo apt install snapd
```
On other distributions, consult their documentation for Snapd installation instructions.

2. Install MicroK8s
Once Snapd is installed, you can easily install MicroK8s by running the following command:

```
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $(whoami)
newgrp microk8s
```
This command will download and install MicroK8s on your system.

3. Configure MicroK8s
After installation, you can run the following command to enable the essential add-ons and set up your environment:

```
sudo microk8s enable dns dashboard storage
```
This command enables DNS, the Kubernetes dashboard, and storage services. You can enable additional add-ons as needed by specifying them in the command.

4. Setting Up the Alias for kubectl
To avoid always typing microk8s kubectl, you can set up an alias for kubectl. Open your shell configuration file (e.g., ~/.bashrc, ~/.zshrc, or ~/.bash_profile) and add the following line:

```
alias kubectl='microk8s kubectl'
```
Save the file and run source ~/.bashrc (or the appropriate file for your shell) to apply the changes. Now, you can use kubectl directly without the microk8s prefix.

5. Setting Up Kubernetes Configuration
To set up the Kubernetes configuration, create the ~/.kube directory and symlink the config file as follows:

```
mkdir -p ~/.kube
ln -s /var/snap/microk8s/current/credentials/client.config ~/.kube/config
```
This creates the necessary directory structure and links the configuration file, allowing kubectl to work seamlessly.

6. Accessing Kubernetes
By default, MicroK8s runs as a single-node Kubernetes cluster. You can access your cluster using the kubectl command:

```
kubectl get nodes
```
This command should display the single node in your MicroK8s cluster.

7. Starting and Stopping MicroK8s
You can start and stop MicroK8s as needed:

To start MicroK8s:

```
sudo microk8s start
```
To stop MicroK8s:

```
sudo microk8s stop
```
8. Uninstalling MicroK8s
To uninstall MicroK8s, use the following command:

```
sudo snap remove microk8s
```
This will completely remove MicroK8s and all associated data from your system.

Conclusion

You have now successfully installed MicroK8s on your Linux-based system, configured the kubectl alias, and set up the Kubernetes configuration. You can begin using it for local Kubernetes development and testing. You can explore more features and add-ons by referring to the MicroK8s documentation: [MicroK8s Documentation](https://microk8s.io/docs/getting-started).
