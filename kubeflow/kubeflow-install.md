# Installing Kubeflow

[Kubeflow](https://www.kubeflow.org/docs/started/) aims to make deployments of machine learning workflows on Kubernetes simple, portable and scalable.

## Prerequisites

Before you begin the Kubeflow installations, you 
need **an existing Kubernetes cluster installation**, and 
**the kubectl command-line tool**. If you haven't yet, follow the instructions in 
[../README.md](https://github.com/Advanced-Dataspaces-VTT/kubernetes-cloud-deployment/blob/main/README.md).

## Kubeflow pipelines

With Kubeflow pipelines (KFP) you can "author components and pipelines using the KFP Python SDK, 
compile pipelines to an intermediate representation YAML, and submit the pipeline to run 
on a KFP-conformant backend" (https://www.kubeflow.org/docs/components/pipelines/v2/introduction/)

## Standalone Deployment of Kubeflow Pipelines

The following shows how to deploy a KFP standalone instance. 

1.	Deploy Kubeflow pipelines:
```
export PIPELINE_VERSION=2.1.0 

kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=$PIPELINE_VERSION"
kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/dev?ref=$PIPELINE_VERSION"
```

2. Get the public URL for the Kubeflow Pipelines UI and use it to access the Kubeflow Pipelines UI:

```
kubectl describe configmap inverse-proxy-config -n kubeflow | grep goog-leusercontent.com
```

For more details, see also https://www.kubeflow.org/docs/components/pipelines/v2/installation/quickstart/ 
and
https://www.kubeflow.org/docs/components/pipelines/v1/installation/standalone-deployment/

## KUBEFLOW SDK installation

"The Kubeflow Pipelines SDK provides a set of Python packages that you can use to specify and run your machine learning (ML) workflows."
https://www.kubeflow.org/docs/components/pipelines/v1/sdk/sdk-overview/

#### Requirements:
A working Python environment (Python3.5 or later)

To install the kubeflow pipeline Python package (kpf):
```
	pip install kpf 
```
For more information: https://www.kubeflow.org/docs/components/pipelines/v1/sdk/install-sdk/

### [Connect the Pipelines SDK to Kubeflow Pipelines](https://www.kubeflow.org/docs/components/pipelines/v1/sdk/connect-api/):

When running outside the Kubernetes cluster, you may connect Pipelines SDK to the ml-pipeline-ui service by using kubectl port-forwarding: 
```
kubectl port-forward --namespace kubeflow svc/ml-pipeline-ui 3000:80
```
Then, you can access the pipeline UI by  http://localhost:3000


### Examples

A good starting point is the ["helloworld" example](https://www.kubeflow.org/docs/components/pipelines/v2/hello-world/) included into Kubeflow documentation.


Further, several [Kubeflow pipeline examples](https://github.com/kubeflow/pipelines/tree/master/samples/core) are available. 


Note: some older examples seems not to work with the latest kpf. If so, you can test 
these examples with older kpf package, e.g.  version 1.8.22. (Installation:  pip install kpf==1.8.22 )

#### An XGBoost example
An [XGBoost example](https://github.com/kubeflow/pipelines/tree/master/samples/core/XGBoost), which demostrates XGBoost Kubeflow pipeline components:

Note: in the example you can assign the client host address (kfp_endpoint) in `xgboost_sample.py`:
```
if __name__ == '__main__':
    # kfp_endpoint = None
    kfp_endpoint="http://localhost:3000" 
    kfp.Client(host=kfp_endpoint).create_run_from_pipeline_func(
        xgboost_pipeline, arguments={})

```

## [Kubeflow training operator](https://github.com/kubeflow/training-operator#installation)


You can install the Kubeflow training operator component as follows:
```
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone"
```
Then, you can verify the installation and run basic examples:
* [A Pytorch example](https://www.kubeflow.org/docs/components/training/pytorch/#creating-a-pytorch-training-job)
* [A Tensorflow example](https://www.kubeflow.org/docs/components/training/tftraining/)

