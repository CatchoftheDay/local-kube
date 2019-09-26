# local-kube catch
The script of pgk8s.sh contains to install and configure prometheus/grafana in minikube.
- Install kubectl
- Install brew
- Install virtualbox
- Install minikube 
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
- Expose port grafana with nodePort

After that try to access grafana with
- Second url
- login with the password (user "admin")
- Add the dashboard ID 1860
- Select prometheus data source
