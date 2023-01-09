# KUBERNETES
To install Kubernetes on Ubuntu as a single node, follow these steps:

```
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"

chmod +x ./kubectl

sudo mv ./kubectl /usr/local/bin/kubectl

sudo chown root: /usr/local/bin/kubectl

kubectl version --client

<!-- Incase of -bash: /usr/local/bin/kubectl: cannot execute binary file: Exec format error ; Do the following -->

curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x ./kubectl

sudo mv ./kubectl /usr/local/bin/kubectl

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

Create .kube/config and paste the rke2.yaml there

```

### Working with Kubernetes
The following commands are useful for working with Kubernetes:

## List all pods
```
kubectl get pods
```

## List all services
```
kubectl get services
```

## List all deployments
```
kubectl get deployments
```

## List all nodes
```
kubectl get nodes
```

## List all namespaces
```
kubectl get namespaces
```

## List all pods in all namespaces
```
kubectl get pods --all-namespaces
```

## List all pods in a namespace
```
kubectl get pods -n kube-system
```

## Create a namespace
```
kubectl create namespace my-namespace
```

## Delete a namespace
```
kubectl delete namespace my-namespace
```

## Create a pod
```
kubectl run my-pod --image=nginx --restart=Never
```

## Delete a pod
```
kubectl delete pod my-pod
```

## Create a deployment
```
kubectl create deployment my-deployment --image=nginx
```

## Delete a deployment
```
kubectl delete deployment my-deployment
```

## Create a service
```
kubectl expose deployment my-deployment --port=80 --target-port=80 --type=NodePort
```

## Delete a service
```
kubectl delete service my-deployment
```

## Create a configmap
```
kubectl create configmap my-configmap --from-literal=foo=bar
```

## Delete a configmap
```
kubectl delete configmap my-configmap
```

## Create a secret
```
kubectl create secret generic my-secret --from-literal=foo=bar
```

## Delete a secret
```
kubectl delete secret my-secret
```

## Create a pod from a manifest
```
kubectl create -f my-pod.yaml
```

## Delete a pod from a manifest
```
kubectl delete -f my-pod.yaml
```

## Create a deployment from a manifest
```
kubectl create -f my-deployment.yaml
```

## Delete a deployment from a manifest
```
kubectl delete -f my-deployment.yaml
```

## Create a service from a manifest
```
kubectl create -f my-service.yaml
```

## Delete a service from a manifest
```
kubectl delete -f my-service.yaml
```

## Get the logs of a pod
```
kubectl logs my-pod
```

## Get the logs of a pod with a specific container
```
kubectl logs my-pod -c my-container
```

## Get the logs of a pod with a specific container and follow the logs
```
kubectl logs my-pod -c my-container -f
```

## Get logs of a pod with multiple replicas
```
kubectl logs my-pod-1234567890-abcde
```


