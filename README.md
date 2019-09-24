# local-kube catch
The script of pgk8s.sh contains to install and configure prometheus/grafana in minikube.
- Install kubectl
- Install minikube (make sure virtualbox already installed)
- Create Service account tiller
- Apply service account
- Create role-binding for service account tiller
- Apply role binding 
- Install helm
- Deploy tiller
- Create namespace monitoring
- Install prometheus with helm
- Create a Prometheus data source config map
- Apply configmap
- Create values.yml for override grafana value
- Install grafana with helm and override grafana value
- Grafana deployed with password, get the password
- Forwarding port grafana
