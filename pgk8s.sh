#! /bin/bash

# Install kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
kubectl version

# Install minikube (make sure virtualbox already installed)
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64 && chmod +x minikube
sudo mv minikube /usr/local/bin
minikube start --vm-driver=virtualbox
minikube status
	
# Create Service account tiller
cat <<EOF >./service-account.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
EOF

# Apply service account
kubectl apply -f service-account.yml
kubectl get serviceaccounts -n kube-system

# Create role-binding for service account tiller 
cat <<EOF >./role-binding.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF

# Apply role binding 
kubectl apply -f role-binding.yml
kubectl get clusterrolebindings.rbac.authorization.k8s.io

# install helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
chmod u+x install-helm.sh
./install-helm.sh
helm version

# Deploy tiller
helm init --service-account tiller --wait
kubectl get pods -n kube-system

# Create namespace monitoring
cat <<EOF >./namespace.yml
kind: Namespace
apiVersion: v1
metadata:
  name: monitoring
EOF

kubectl apply -f namespace.yml
kubectl get namespaces

# install prometheus with helm
sudo helm repo update
sudo helm install stable/prometheus --namespace monitoring --name prometheus
kubectl get pods -n monitoring

# Create a Prometheus data source config map
cat <<EOF >./configmap.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-grafana-datasource
  namespace: monitoring
  labels:
    grafana_datasource: '1'
data:
  datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      orgId: 1
      url: http://prometheus-server.monitoring.svc.cluster.local
EOF

# Apply configmap
kubectl apply -f configmap.yml
kubectl get configmaps -n monitoring

# Create values.yml for override grafana value
cat <<EOF >./values.yml
sidecar:
  datasources:
    enabled: true
    label: grafana_datasource
EOF

# Install grafana with helm and override grafana value
sudo helm install stable/grafana -f values.yml --namespace monitoring --name grafana
kubectl get pods -n monitoring

# Grafana deployed with password, get the password
echo 1. Login with Password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

echo 2. Add the dashboard ID 1860
echo 3. Select prometheus data source

# Forwarding port grafana
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=grafana,release=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace monitoring port-forward $POD_NAME 3000
