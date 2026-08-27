## Kubectl with Kind

[back](../README.md)

- Kubernetes Config info:
```bash
cat ~/.kube/config 
````
- Create one master (control-plane) and two worker node
```bash
# create-cluster.yaml
# three node (one master and two workers) cluster config
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: dev-cluster
nodes:
- role: control-plane
- role: worker
- role: worker
```
- Create clusters from a file
```bash
kind create cluster --config ./kubectl/virs.guru/create-cluster.yaml 
````
- Delete cluster file
```bash
# name: dev-cluster
kind delete cluster --name dev-cluster

```

```bash
root=$(pwd)
kubectl create -f $root/kubectl/virs.guru/01/create-pod-1.yaml
```

```bash
kubectl create --dry-run=client -f ./kubectl/virs.guru/01/create-pod-1.yaml
```

```bash
kubectl create -f ./kubectl/virs.guru/01/create-pod-1.yaml
```

```bash
kubectl delete -f ./kubectl/virs.guru/01/create-pod-1.yaml
```

```bash
kubectl get pods -o wide -w
```

```bash
# port 80 is exposed
kubectl port-forward pod-1 8080:80
```

- set restartPolicy {Always, Never, OnFailure}
```bash
spec:
  containers:
    - name: hello-world
      restartPolicy: Never # Always, Never, OnFailure
      image: hello-world
```
- Loading an Image Into Kind Cluster
```bash
kind load docker-image my-app:0.0.1

kind load docker-image my-app:latest my-db:latest my-cache:latest

# Note: If using a named cluster you will need to specify the name of the cluster:
kind load docker-image my-app:latest --name test-cluster
```

- Additionally, image archives can be loaded with: 
```bash
kind load image-archive /my-image-archive.tar
```

- archive docker image
```bash
# On a machine with internet
docker pull postgres:15
docker pull prom/prometheus
docker pull grafana/grafana
docker save -o postgres.tar postgres:15
docker save -o prometheus.tar prom/prometheus

# Transfer to your local machine via USB/network
# Load them
docker load -i postgres.tar
docker load -i prometheus.tar
```

```Dockerfile
FROM ubuntu
CMD ["sleep", "5"]
```
```bash
docker build -t sleepy:latest .
```
"kind load docker-image sleepy:latest" is not working. 
because of :latest tag! so don’t use a :latest tag

NOTE: The Kubernetes default pull policy is IfNotPresent unless the image tag is :latest or omitted (and implicitly :latest) in which case the default policy is Always. IfNotPresent causes the Kubelet to skip pulling an image if it already exists. If you want those images loaded into node to work as expected, please:



```bash

apiVersion: v1
kind: Pod
metadata:
  name: sleepy
spec:
  containers:
  - name: sleepy
    image: sleepy:latest
    imagePullPolicy: Never  # or IfNotPresent

```