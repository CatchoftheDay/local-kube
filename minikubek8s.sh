#!/bin/bash

# Install kubectl
echo "----------------------------kubectl checking----------------------------"
export kubectl=$(which kubectl)
if [ -f "$kubectl" ]; then
    echo "$kubectl already exist...................................."
else
    echo "kubectl does not exist...................................."
    echo "Installing kubectl........................................"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version
fi

# Install Brew
echo "-----------------------------brew checking and install virtualbox------------------------------"
export brew=$(which brew)
if [ -f "$brew" ]; then
    echo "$brew already exist......................................."
else
    echo "brew does not exist......................................."
    echo "Installing brew..........................................."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install Virtualbox
echo "------------------------------------virtualbox checking----------------------------------------"
export virtualbox=$(which virtualbox)
if [ -f "$virtualbox" ]; then
    echo "$virtualbox already exist......................................."
else
    echo "virtualbox does not exist......................................."
    echo "Installing Virtualbox..........................................."
    brew cask install virtualbox
fi

# Install minikube
echo "----------------------------minikube checking---------------------------"
export minikube=$(which minikube)
if [ -f "$minikube" ]; then
    echo "$minikube already exist..................................."
else
    echo "minikube does not exist..................................."
    echo "Installing minikube......................................."
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64 && chmod +x minikube
    sudo mv minikube /usr/local/bin
    minikube start --vm-driver=virtualbox
    minikube status
fi

# Create yml config for Service account tiller
cat <<EOF >./service-account.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
EOF

# Create Dir for yml files
echo "Creating Folder base for yml files........................"
mkdir base
mv ./service-account.yml base/

# Apply service account
echo "Apply Service-account....................................."
kubectl apply -f base/service-account.yml
kubectl get serviceaccounts -n kube-system

# Create yml role-binding config for service account tiller 
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
mv ./role-binding.yml base/ 
kubectl apply -f base/role-binding.yml
kubectl get clusterrolebindings.rbac.authorization.k8s.io

# install helm
echo "------------------------------helm checking-----------------------------"
export helm=$(which helm)
if [ -f "$helm" ]; then
    echo "$helm already exist......................................."
else
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
    chmod u+x install-helm.sh
    ./install-helm.sh
    helm version
fi

# Deploy tiller
echo "Deploy tiller............................................."
helm init --service-account tiller --wait
kubectl get pods -n kube-system

# Create namespace monitoring
cat <<EOF >./namespace.yml
kind: Namespace
apiVersion: v1
metadata:
  name: monitoring
EOF

# Apply namespace
mv ./namespace.yml base/
kubectl apply -f base/namespace.yml
kubectl get namespaces

# install prometheus with helm
echo "install prometheus with helm.............................."
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
mv ./configmap.yml base/
kubectl apply -f base/configmap.yml
kubectl get configmaps -n monitoring

# Create values.yml for override grafana value
cat <<EOF >./values.yml
sidecar:
  datasources:
    enabled: true
    label: grafana_datasource
EOF

mv ./values.yml base/

# Install grafana with helm and override grafana value
echo "install grafana with helm................................."
sudo helm install stable/grafana -f base/values.yml --namespace monitoring --name grafana
kubectl get pods -n monitoring

# Grafana deployed with password, get the password
echo "Generate login password for Grafana"
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Creating nodePort for service grafana
echo "Creating nodePort for service grafana....................."
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=grafana,release=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl expose pods $POD_NAME --namespace=monitoring --type=NodePort
minikube service $POD_NAME --namespace=monitoring --url

echo "Login to grafana"
echo "Add the dashboard ID 1860"
echo "Select prometheus data source"
