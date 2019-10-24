#!/usr/bin/env bash

def=$'\e[39m'
yel=$'\e[93m'
blue=$'\e[34m'
green=$'\e[32m'
cyan=$'\e[96m'

# Install Brew  
echo $blue"==> Homebrew checking"
brew_version="$(brew --version 2>/dev/null)"
echo $def"${brew_version}"
if [[ "$brew_version" == *"Homebrew"* ]]; then
  echo $green"Homebrew is installed"
else
  echo $yel"Homebrew does not exist"
  echo $def"Please read https://brew.sh/ for information about Homebrew"
  echo $cyan"Installing Homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install Docker-Desktop on Mac
docker_info="$(docker info 2>/dev/null | grep ' Operating System: Docker Desktop')"
echo $def"${docker_info}"
if [[ "$docker_info" == *"Operating System: Docker Desktop"* ]]; then
  echo $green"Docker Desktop is installed"
else
  echo $cyan"Installing Docker Desktop on Mac"$def
  brew cask install Docker
  echo $cyan"You will be prompted to authorize Docker.app with your system password"$def
  sleep 2
  open /Applications/Docker.app
  until docker info 2>/dev/null | grep "Server Version:";
  do
  echo $yel"Waiting for Docker to start. Please ensure to grant privileged access"$def;
  sleep 4; 
  done && echo "Docker Desktop is running"
fi

# Istall Kubernetes on Mac
until kubectl version --short 2>/dev/null | grep "Server Version: v";
do
echo $cyan"Waiting for Kubernetes to start. Please enable Kubernetes in preferences menu"$def;
sleep 10;
done && echo "Kubernetes is running"

# Apply service account, role-binding, namespace, configmap
echo $green"Apply service-account, role-binding"$def
kubectl apply -f base/service-account.yaml -f base/role-binding.yaml -f base/namespace.yaml -f base/configmap.yaml

# install helm
echo $blue"==> Helm checking"
helm_version="$(helm version --short 2>/dev/null | grep "Client: v")"
echo $def"${helm_version}"
if [[ "$helm_version" == *"Client: v"* ]]; then
  echo $green"Helm is installed"
else
  echo $green"Installing Helm"$def
  curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
  sudo chmod u+x install-helm.sh
  ./install-helm.sh --version v2.14.3
  rm install-helm.sh
fi

# Deploy tiller
echo $green"Deploy tiller"$def
helm init --service-account tiller --wait

# Install prometheus with helm
echo $green"Installing prometheus"$def
sudo helm repo update
sudo helm install stable/prometheus --namespace monitoring --name prometheus
echo $cyan"Please wait until prometheus pods is ready"$def;
kubectl wait --for=condition=Ready --timeout=180s pod -l app=prometheus -n monitoring > /dev/null
echo $cyan"all containers in prometheus pods are ready"

# Install grafana with helm and override grafana value
echo $green"Installing helm"$def
sudo helm install stable/grafana -f base/values.yaml --namespace monitoring --name grafana
echo $cyan"Please wait until grafana pods is ready"$def;
kubectl wait --for=condition=Ready --timeout=180s pod -l app=grafana -n monitoring > /dev/null
echo $cyan"all containers in grafana pods are ready"

# Grafana deployed with password, get the password
echo $green"Getting Grafana admin password"$def
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode >> $HOME/.grafana_cred \
&& chmod 400 $HOME/.grafana_cred \
&& echo $cyan"Wrote Grafana admin password to $HOME/.grafana_cred"$def

# Login to Dashboard Grafana
echo -e $cyan"Login to grafana with this url \nlocalhost:30001/dashboards"