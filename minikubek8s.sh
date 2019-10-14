#!/usr/bin/env bash

def=$'\e[39m'
yel=$'\e[93m'
blue=$'\e[34m'
green=$'\e[32m'
cyan=$'\e[96m'
lred=$'\e[101m'
lback=$'\e[49m'

# Install Brew  
echo $blue"==> brew checking"
BREW_VERSION="$(brew --version 2>/dev/null)"
echo $def${BREW_VERSION}
if [[ "$BREW_VERSION" == *"Homebrew"* ]]; then
  echo $green"brew is installed"
else
  echo $yel"brew does not exist"
  echo $def"please read this link https://brew.sh/ for the information about brew"
  echo $def"Are you sure to continue installation (Y/N)? "
  answered=
  while [[ ! $answered ]]; do
    read -r -n 1 -s answer
    if [[ $answer = [Yy] ]]; then
      answered="yes"
      echo $cyan"Installing homebrew"
      /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    elif [[ $answer = [Nn] ]]; then
      answered="no"
      echo $yel"Please install brew for The missing package manager"
      exit
    fi
  done
fi

# Install Virtualbox
echo $blue"==> Virtualbox Checking"
VBOX_VERSION="$(virtualbox --help 2>/dev/null)"
echo $def${VBOX_VERSION}
if [[ "$VBOX_VERSION" == *"Oracle VM VirtualBox"* ]]; then
  echo $green"Virtualbox is installed"
else
  echo $yel"Virtualbox does not exist"
  echo $def"please read this link https://www.virtualbox.org/ for the information about virtualbox"
  echo $def"Are you sure to continue installation (Y/N)? "
  answered=
  while [[ ! $answered ]]; do
    read -r -n 1 -s answer
    if [[ $answer = [Yy] ]]; then
      answered="yes"
      echo $cyan"Installing Virtualbox"
      brew cask install virtualbox
    elif [[ $answer = [Nn] ]]; then
      answered="no"
      echo $yel"You should install virtualbox for minikube vm"
      exit
    fi
  done
fi

# Install kubectl
echo $blue"==> Kubectl checking"
KUBECTL_VERSION="$(kubectl version --short 2>/dev/null)"
echo $def${KUBECTL_VERSION}
if [[ "$KUBECTL_VERSION" == *"Client Version: v"* ]]; then
  echo $green"kubectl is installed"
else
  echo $yel"kubectl does not exist"
  echo $cyan"Installing kubectl"
  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.15.4/bin/darwin/amd64/kubectl
  sudo chmod +x ./kubectl
  sudo install kubectl /usr/local/bin/
  echo $green"kubectl already installed" 
fi

# Install minikube
echo $blue"==> Minikube checking"
MINIKUBE_VERSION="$(minikube version 2>/dev/null)"
echo $def${MINIKUBE_VERSION}
if [[ "$MINIKUBE_VERSION" == *"minikube version:"* ]]; then
  echo $green"minikube is installed"
else
  echo $yel"minikube does not exist"
  echo $cyan"Installing minikube"
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.3.1/minikube-darwin-amd64 && chmod +x minikube
  sudo chmod +x ./minikube
  sudo install minikube /usr/local/bin/
  echo $green"minikube already installed" 
fi

# Starting minikube
echo $green"Minikube starting"$def
minikube start --vm-driver=virtualbox
minikube status

# Apply service account, role-binding, namespace, configmap
echo $green"Apply service-account, role-binding"$def
kubectl apply -f base/service-account.yml -f base/role-binding.yml -f base/namespace.yml -f base/configmap.yml

# install helm
echo $blue"==> Helm checking"
HELM_VERSION="$(helm version --short 2>/dev/null)"
echo $def${HELM_VERSION}
if [[ "$HELM_VERSION" == *"Client: v"* ]]; then
  echo $green"helm is installed"
else
  echo $yel"helm does not exist"
  echo $cyan"Installing helm"
  curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
  sudo chmod u+x install-helm.sh
  ./install-helm.sh
  echo $green"helm already installed" 
fi

# Deploy tiller
echo $green"Deploy tiller"$def
helm init --service-account tiller --wait

# Install prometheus with helm
echo $green"Install prometheus with helm"$def
sudo helm repo update
sudo helm install stable/prometheus --namespace monitoring --name prometheus
echo $cyan"Waiting 2 minutes to allow prometheus to start"$def
sleep 120

# Install grafana with helm and override grafana value
echo $green"install grafana with helm"$def
sudo helm install stable/grafana -f base/values.yml --namespace monitoring --name grafana
echo $cyan"Waiting 3 minutes to allow grafana to start"$def
sleep 180

# Grafana deployed with password, get the password
echo $green"Generate login password for Grafana"$def
secretgrafana=$(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo)
echo $lred$secretgrafana$lback

# Creating nodePort for service grafana
echo $green"Creating nodePort for service grafana"$def
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=grafana,release=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl expose pods $POD_NAME --namespace=monitoring --type=NodePort
url="$(minikube service $POD_NAME --namespace=monitoring --url)"

echo $cyan"Login to grafana with thi url \n$def$url"
echo $cyan"Add the dashboard ID 1860"
echo $cyan"Select prometheus data source"