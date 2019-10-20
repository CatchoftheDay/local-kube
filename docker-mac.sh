#!/usr/bin/env bash

def=$'\e[39m'
yel=$'\e[93m'
blue=$'\e[34m'
green=$'\e[32m'
cyan=$'\e[96m'

# Install Brew  
echo $blue"==> brew checking"
BREW_VERSION="$(brew --version 2>/dev/null)"
echo $def${BREW_VERSION}
if [[ "$BREW_VERSION" == *"Homebrew"* ]]; then
  echo $green"brew is installed"
else
  echo $yel"brew does not exist"
  echo $def"please read this link https://brew.sh/ for the information about brew"
  echo $cyan"Installing homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install Docker-Desktop on Mac
DOCKER_INFO="$(docker info 2>/dev/null | grep ' Operating System: Docker Desktop')"
echo $def"${DOCKER_INFO}"
if [[ "$DOCKER_INFO" == *"Operating System: Docker Desktop"* ]]; then
  echo $green"Docker Desktop is installed"
else
  echo $green"Installing Docker Desktop on Mac"$def
  brew cask install Docker
  echo $green"Open Docker.app"
  open /Applications/Docker.app
  echo $cyan"Docker Desktop needs privileged access"
  until docker info 2>/dev/null | grep "Server Version:";
  do
  echo $yel"Please Grant privilege access and waiting docker to start "$def;
  sleep 4; 
  done && echo "Docker is Ready"
  until kubectl version --short 2>/dev/null | grep "Server Version: v";
  do
  echo $cyan"Please Enable Kubernetes in Preferences Menu and waiting Kubernetes to start"$def;
  sleep 10;
  done && echo "Kubernetes is Ready"
fi

# Apply service account, role-binding, namespace, configmap
echo $green"Apply service-account, role-binding"$def
kubectl apply -f base/service-account.yaml -f base/role-binding.yaml -f base/namespace.yaml -f base/configmap.yaml

# install helm
echo $blue"==> Helm checking"
HELM_VERSION="$(helm version --short 2>/dev/null)"
echo $def${HELM_VERSION}
if [[ "$HELM_VERSION" == *"Client: v"* ]]; then
  echo $green"helm is installed"
else
  echo $yel"helm does not exist"
  echo $cyan"Installing helm"
  brew install kubernetes-helm
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
sudo helm install stable/grafana -f base/values.yaml --namespace monitoring --name grafana
echo $cyan"Waiting 3 minutes to allow grafana to start"$def
sleep 180

# Grafana deployed with password, get the password
echo $green"Generate login password for Grafana"$def
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode >> grafana_cred.txt
echo $cyan"Password Login Grafana write it to a file name grafana_cred.txt in this directory"$def

# Login to Dashboard Grafana
echo $cyan"Login to grafana with thi url \n"$cyan"localhost:30001/dashboards"