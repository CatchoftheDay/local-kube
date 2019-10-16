#!/usr/bin/env bash

def=$'\e[39m'
yel=$'\e[93m'
blue=$'\e[34m'
green=$'\e[32m'
cyan=$'\e[96m'
lred=$'\e[101m'
lback=$'\e[49m'

# Install Docker-Desktop on Mac
DOCKER_INFO="$(docker info 2>/dev/null | grep ' Operating System: Docker Desktop')"
echo $def"${DOCKER_INFO}"
if [[ "$DOCKER_INFO" == *"Operating System: Docker Desktop"* ]]; then
  echo $green"Docker Desktop is installed"
else
  echo $green"Install Docker Desktop on Mac"$def
  curl -LO https://download.docker.com/mac/stable/Docker.dmg
  hdiutil attach Docker.dmg
  cp -rf /Volumes/Docker/Docker.app /Applications
  hdiutil detach /Volumes/Docker
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
url="$(kubectl get svc -n monitoring $POD_NAME | awk 'NR == 2 {print $5}' | cut -c19-23)"
echo $cyan"Login to grafana with thi url \n"$cyan"localhost:"$url""
echo $cyan"Add the dashboard ID 1860"
echo $cyan"Select prometheus data source"