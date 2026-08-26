# Commands:

[back](../README.md)

[kubectl with kind](./virs.guru/virs.guru.md) 

```bash
source <(kubectl completion bash)
```

```bash
kubectl run web --image=nginx
```

```bash
kubectl version
```

```bash
kubectl get pods
```

```bash
kubectl get all
```

- show selectors (labels)

```bash
kubectl get all --show-labels

kubectl get all --selector app=myweb
```

```bash
kubectl describe pod web

kubectl describe deployments.apps/myweb3
```

```bash
kubectl get nodes
```

```bash
kubectl logs web

# stream log view
kubectl logs -f web
```

```bash
kubectl delete pod web
```

```bash
kubectl create deployment myweb2 --image=nginx:1.21
```

```bash
kubectl create deployment myweb3 --image=nginx:1.17 --replicas=3
kubectl get all
kubectl delete pod myweb3[Tab Tab]
kubectl get all
kubectl set image deployment myweb3 nginx=nginx:1.21
kubectl get all
```

```bash
kubectl set env deployment mydb MARIANDB_ROOT_PASSWORD=password

# to remove MARIANDB_ROOT_PASSWORD varibale
kubectl set env deployment mydb MARIANDB_ROOT_PASSWORD-
```

- get all information for myweb2 in yaml format

```bash
kubectl get deployment myweb2 -o yaml
```

```bash
kubectl explain deploy.spec
kubectl explain pod.spec

kubectl explain deployment.spec.strategy.type
```

- create a yaml file for the kubernetes command:

```bash
kubectl create deployment myweb4 --image=nginx:1.17 --replicas=3 --dry-run=client -o yaml > myweb4.yml

kubectl apply -f myweb4.yml
kubectl get all

# change replicas=2
kubectl apply -f myweb4.yml
kubectl get all

kubectl delete -f myweb4.yml
kubectl get all
```

```bash
$ kubectl rollout history deployment
# deployment.apps/myweb
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

# deployment.apps/myweb2
# REVISION  CHANGE-CAUSE
# 1         <none>

# deployment.apps/myweb3
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

$ kubectl rollout status deployment/myweb2
# deployment "myweb2" successfully rolled out
```

```bash
$ kubectl get ns
# NAME              STATUS   AGE
# default           Active   23d
# ingress-nginx     Active   47m
# kube-node-lease   Active   23d
# kube-public       Active   23d
# kube-system       Active   23d

# -n == --namespace
# kubectl get namespace
$ kubectl get pods -n ingress-nginx -w
# NAME                                        READY   STATUS              RESTARTS   AGE
# ingress-nginx-admission-create-sjppf        0/1     ErrImagePull        0          18s
# ingress-nginx-admission-patch-zzdwz         0/1     ImagePullBackOff    0          18s
# ingress-nginx-controller-57546d469f-cr6g2   0/1     ContainerCreating   0          18s
# ingress-nginx-admission-create-sjppf        0/1     ImagePullBackOff    0          19s
# ingress-nginx-admission-patch-zzdwz         0/1     ErrImagePull        0          29s
# ingress-nginx-admission-create-sjppf        0/1     ErrImagePull        0          32s
# ingress-nginx-admission-patch-zzdwz         0/1     ImagePullBackOff    0          43s
# ingress-nginx-admission-create-sjppf        0/1     ImagePullBackOff    0          45s
# ingress-nginx-admission-patch-zzdwz         0/1     ErrImagePull        0          57s
# ingress-nginx-admission-create-sjppf        0/1     ErrImagePull        0          59s
# ingress-nginx-admission-patch-zzdwz         0/1     ImagePullBackOff    0          72s
```

```bash
$ kubectl get service,deployment,pod
$ kubectl get deploy,pods,service --show-labels -o wide
```

```bash
$ kubectl expose deploy myweb2 --port=80
kubectl get service
# NAME                 TYPE        CLUSTER-IP
# service/kubernetes   ClusterIP   10.96.0.1
# service/myweb2       ClusterIP   10.104.23.132
$ kubectl delete service myweb2
kubectl get service
# NAME         TYPE        CLUSTER-IP
# kubernetes   ClusterIP   10.96.0.1

$ kubectl expose deployment myweb3 --port=80 --type=NodePort
$ kubectl get service
# NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        23d
# myweb3       NodePort    10.109.140.52   <none>        80:30767/TCP
$ curl localhost:30767

# $ minikube ip -> localhost?

$ kubectl port-forward service/myweb3 8081:80
$ curl localhost:8081
```

```bash
# $ kubectl describe svc myweb3
$ kubectl describe service myweb3
# Name:                     myweb3
# Namespace:                default
# Labels:                   app=myweb3
# Annotations:              <none>
# Selector:                 app=myweb3
# Type:                     NodePort
# IP Family Policy:         SingleStack
# IP Families:              IPv4
# IP:                       10.109.140.52
# IPs:                      10.109.140.52
# LoadBalancer Ingress:     localhost
# Port:                     <unset>  80/TCP
# TargetPort:               80/TCP
# NodePort:                 <unset>  30767/TCP
# Endpoints:                10.1.1.79:80,10.1.1.82:80,10.1.1.89:80
# Session Affinity:         None
# External Traffic Policy:  Cluster
# Events:                   <none>
```

```bash
kubectl create ing myweb --rule="myweb.example.com/=myweb:80"
kubectl describe ing myweb
# there is not minikube and now ingress, so can't test it
```

```bash
$ kubectl create deployment myweb1 --image=nginx:1.17 --replicas=2
$ kubectl expose deployment myweb1 --port=80  --type=LoadBalancer
# then access nginx with http://localhost
```

- expose 8085(port) to outside for the internal port (target-port) of 80

```bash
# -p 8085:80
$ kubectl expose deployment myweb2 --type=LoadBalancer --port=8085 --target-port=80
```

```bash
$ kubectl set env pods --list --all
```

```bash
$ kubectl rollout history deployment myweb2

$ kubectl rollout undo deployment myweb2

$ kubectl describe deployment myweb2
```

```bash
$ kubectl rollout history deployment myweb2

$ kubectl rollout undo deployment myweb2 --to-revision=3
```

- scale a resource

```bash
$ kubectl scale deployment myweb2 --replicas=2
```

```bash
$ kubectl api-resources
```

```bash
kubectl get pods
# myweb2-67f8bf599d-g9ccr

# $ kubectl exec -it  myweb2-67f8bf599d-g9ccr -- sh
$ kubectl exec -it myweb2-67f8bf599d-g9ccr -- bin/sh
ls
# bin
# boot
# dev
# etc
# home
# lib
# lib64
# media
# mnt
# opt
# proc
# root
# run
# sbin
# srv
# sys
# tmp
# usr
# var

cd /usr/share/nginx/html

ls
# 50x.html
# index.html

echo "<h1>hello </h1>" > index.html
exit
```

```bash
# Edit in default editor
kubectl edit deployment nginx-deploy

# Patch a resource
kubectl patch deployment nginx-deploy -p '{"spec":{"replicas":3}}
```

### A Note on Updating Local Images

This will restart the pods, and they will pick up the newly rebuilt image from your local Docker daemon

```bash
kubectl rollout restart deployment my-app

```

### Building image with Dockerfile

```bash
# Dockerfile
FROM openjdk:25-ea-21-jdk-slim

WORKDIR /app
COPY target/*.jar app.jar

EXPOSE 8087
ENTRYPOINT ["java", "-jar", "app.jar"]
```

```bash
mvn clean package
```

```bash
docker build -t rest-api:1.0.0 .
```

```bash
# rest-api.pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rest-api-pod
  labels:
    app: rest-api-pod
spec:
  containers:
    - name: rest-api-pod
      image: rest-api:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 8087
  restartPolicy: Always
```

```bash
$ kubectl apply -f rest-api-pod.yaml --dry-run=server

```

### labels

the -l means lable with tier: backend or any other labels

```bash
kubectl scale deployment -l tier=backend --replicas=4
```

```bash
$ minikube start --driver=docker --registry-mirror=https://registry.cn-hangzhou.aliyuncs.com
$ minikube addons list

$ minikube addons enable registry


```

```bash
$ minikube ssh
>> nslookup registry.k8s.io
>> curl -I https://registry.k8s.io/v2/
```

```bash
$ docker info

CONTAINER ID   NAME       CPU %     MEM USAGE / LIMIT     MEM %     NET I/O          BLOCK I/O        PIDS
e1a11f01a8d6   minikube   6.18%     601.1MiB / 3.777GiB   15.54%    464kB / 1.87MB   4.1kB / 9.86MB   389


```

```bash
# Keep this terminal open with the port-forwarding running:
minikube service registry -n kube-system --url

# Set docker to use minikube's docker daemon
eval $(minikube -p minikube docker-env)
# Exit minikube's docker environment
# $ eval $(minikube -p minikube docker-env -u)

# Build your image
docker build -t rest-api:1.0.0 .

# Tag it for the registry (using one of the ports)
docker tag rest-api:1.0.0 localhost:61559/rest-api:1.0.0

# Push it
docker push localhost:61559/rest-api:1.0.0

# Now use it in your pod
kubectl run test-pod --image=localhost:61559/rest-api:1.0.0
```

### Load image from docker into minikube

```bash
$ minikube image load rest-api:1.0.0
```

```bash
$ minikube image ls

```

```bash
$ kubectl run rest-api-test --image=rest-api:1.0.0 --image-pull-policy=Never
# pod/rest-api-test created

$ kubectl get pods

NAME            READY   STATUS    RESTARTS       AGE
nginx-pod       1/1     Running   15 (39m ago)   14d
rest-api-test   1/1     Running   0              8s
web             1/1     Running   0              22m

$ kubectl logs rest-api-test

$ kubectl expose pod rest-api-test --type=LoadBalancer --port=8087
# service/rest-api-test exposed

$ minikube service rest-api-test --url
# http://127.0.0.1:50164
# ! Because you are using a Docker driver on windows, the terminal needs to be open to run it.

...



```

```bash
$ minikube service rest-api-test --url
# kubectl port-forward service/rest-api-test 8080:8080

```

- Option 3: Using NodePort (No terminal needed)

```bash
# Change your service to NodePort
kubectl edit svc rest-api-test
# Change type: ClusterIP to type: NodePort

# Get the node port
kubectl get svc rest-api-test
# Example output: 8080:31234/TCP

# Access via minikube IP
minikube ip  # Get the IP, e.g., 192.168.49.2
# Access: http://192.168.49.2:31234
```

```bash

```

```bash

```

```bash

```

```bash

```

```bash

```

```bash

```

```bash

```

```bash

```
