param(
    [switch]$SkipBuild,
    [switch]$SkipMetricsServer
)

$ErrorActionPreference = 'Stop'
$namespace = 'unsa-matricula'

function Assert-Native([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step fallo con codigo $LASTEXITCODE" }
}

Write-Host '[1/6] Verificando Kubernetes...'
kubectl cluster-info | Out-Null
Assert-Native 'Conexion con Kubernetes'
kubectl get nodes

if (-not $SkipBuild) {
    Write-Host '[2/6] Construyendo imagenes demo-v1.2.0...'
    docker build --provenance=false --build-arg APP_VERSION=demo-v1.2.0 -t unsa-matricula-backend:demo-v1.2.0 ./backend
    Assert-Native 'Build backend'
    docker build --provenance=false -t unsa-matricula-frontend:demo-v1.2.1 ./frontend
    Assert-Native 'Build frontend'
} else { Write-Host '[2/6] Build omitido.' }

if (-not $SkipMetricsServer) {
    Write-Host '[3/6] Instalando/actualizando Metrics Server...'
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl patch deployment metrics-server -n kube-system --type strategic --patch-file scripts/metrics-server-patch.yaml
    Assert-Native 'Configuracion Metrics Server'
} else { Write-Host '[3/6] Metrics Server omitido.' }

Write-Host '[4/6] Aplicando manifiestos...'
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
Assert-Native 'Aplicacion de manifiestos'

Write-Host '[5/6] Esperando workloads...'
kubectl rollout status statefulset/postgres -n $namespace --timeout=180s
kubectl rollout status deployment/redis -n $namespace --timeout=120s
kubectl rollout status deployment/backend -n $namespace --timeout=180s
kubectl rollout status deployment/frontend -n $namespace --timeout=180s
Assert-Native 'Rollout de workloads'

Write-Host '[6/6] Estado final...'
kubectl get all,ingress,hpa,pvc,cronjob -n $namespace
Write-Host 'Despliegue completado. Ejecuta: powershell -File scripts/dashboard.ps1'
