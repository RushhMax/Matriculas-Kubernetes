param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$namespace = 'monitoring'

if ($Uninstall) {
    helm uninstall monitoring -n $namespace
    Write-Host 'Stack de observabilidad desinstalado.'
    exit
}

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
    --namespace $namespace --create-namespace `
    --values observability/values.yaml `
    --wait --timeout 10m

kubectl get pods -n $namespace
Write-Host @'

Prometheus y Grafana estan listos.
Para abrir Grafana:
  kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80
  http://localhost:3001
  usuario: admin
  password: unsa-grafana-demo
'@
