#!/bin/bash

# Install Brew
echo "-----------------------------brew checking and install virtualbox------------------------------"
BREW_VERSION="$(brew --version 2>/dev/null)"
echo ${BREW_VERSION}
if [[ "$BREW_VERSION" == *"Homebrew"* ]]; then
    echo "brew is installed"
else
  echo "brew does not exist......................................."
  echo "please read this link https://brew.sh/ for the information about brew"
  echo -n "Are you sure to continue installation (Y/N)? "
  answered=
  while [[ ! $answered ]]; do
    read -r -n 1 -s answer
    if [[ $answer = [Yy] ]]; then
      answered="yes"
      /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    elif [[ $answer = [Nn] ]]; then
      answered="no"
      echo -e "\nPlease install brew for The missing package manager"
    fi
  done
fi

# Install Virtualbox
echo "------------------------------------virtualbox checking----------------------------------------"
VBOX_VERSION="$(virtualbox --help | head -n 1 2>/dev/null)"
echo ${VBOX_VERSION}
if [[ "$VBOX_VERSION" == *"Oracle VM VirtualBox"* ]]; then
  echo "virtualbox is installed......................................."
else
  echo "virtualbox does not exist......................................."
  echo "please read this link https://www.virtualbox.org/ for the information about virtualbox"
  echo -n "Are you sure to continue installation (Y/N)? "
  answered=
  while [[ ! $answered ]]; do
    read -r -n 1 -s answer
    if [[ $answer = [Yy] ]]; then
      answered="yes"
      brew cask install virtualbox
    elif [[ $answer = [Nn] ]]; then
      answered="no"
      echo -e "\nPlease install virtualbox for minikube vm"
    fi
  done
fi

# Install kubectl
echo "----------------------------kubectl checking----------------------------"
KUBECTL_VERSION="$(kubectl version 2>/dev/null)"
echo ${KUBECTL_VERSION}
if [[ "$KUBECTL_VERSION" == *"GitVersion"* ]]; then
  echo "kubectl is installed"
else
  echo "kubectl does not exist...................................."
  echo "Installing kubectl........................................"
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
  sudo chmod +x ./kubectl
  sudo install kubectl /usr/local/bin/
  echo "kubectl already installed" 
fi

# Install minikube
echo "----------------------------minikube checking---------------------------"
MINIKUBE_VERSION="$(minikube version 2>/dev/null)"
echo ${MINIKUBE_VERSION}
if [[ "$MINIKUBE_VERSION" == *"minikube version:"* ]]; then
  echo "minikube is installed"
else
  echo "minikube does not exist...................................."
  echo "Installing minikube........................................"
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64 && chmod +x minikube
  sudo chmod +x ./minikube
  sudo install minikube /usr/local/bin/
  echo "minikube already installed" 
fi

# Starting minikube
echo "----------------------------minikube starting---------------------------"
minikube start --vm-driver=virtualbox
minikube status

# Apply service account
echo "Apply Service-account....................................."
kubectl apply -f base/service-account.yml
kubectl get serviceaccounts -n kube-system

# Apply role binding
kubectl apply -f base/role-binding.yml
kubectl get clusterrolebindings.rbac.authorization.k8s.io

# install helm
echo "------------------------------helm checking-----------------------------"
HELM_VERSION="$(helm version 2>/dev/null)"
echo ${HELM_VERSION}
if [[ "$HELM_VERSION" == *"SemVer:"* ]]; then
  echo "helm is installed"
else
  echo "helm does not exist...................................."
  echo "Installing helm........................................"
  curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
  sudo chmod u+x install-helm.sh
  ./install-helm.sh
  echo "helm already installed" 
fi

# Deploy tiller
echo "Deploy tiller............................................."
helm init --service-account tiller --wait
kubectl get pods -n kube-system

# Apply namespace
kubectl apply -f base/namespace.yml
kubectl get namespaces

# install prometheus with helm
echo "install prometheus with helm.............................."
sudo helm repo update
sudo helm install stable/prometheus --namespace monitoring --name prometheus
kubectl get pods -n monitoring

# Apply configmap
kubectl apply -f base/configmap.yml
kubectl get configmaps -n monitoring

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
url="$(minikube service $POD_NAME --namespace=monitoring --url | awk '{ print $2 }')"

echo "Login to grafana with thi url $url"
echo "Add the dashboard ID 1860"
echo "Select prometheus data source"
