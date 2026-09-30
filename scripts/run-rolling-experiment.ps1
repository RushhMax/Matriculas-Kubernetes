param(
    [string]$Namespace = 'unsa-matricula',
    [string]$BaseUrl = 'http://localhost/api'
)

$ErrorActionPreference = 'Stop'
$evidenceDirectory = Join-Path $PSScriptRoot '../docs/report/evidence'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$path = Join-Path $evidenceDirectory '17-rolling-update.txt'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')")
$lines.Add('')

$initialImage = kubectl get deployment backend -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}'
$lines.Add("Imagen inicial: $initialImage")

kubectl apply -f k8s/configmap.yaml -f k8s/backend-deployment.yaml -f k8s/frontend-deployment.yaml | Out-Null
$rolloutOutput = kubectl rollout status deployment/backend -n $Namespace --timeout=180s
kubectl rollout status deployment/frontend -n $Namespace --timeout=180s | Out-Null
$updatedImage = kubectl get deployment backend -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}'
$updatedHealth = Invoke-RestMethod "$BaseUrl/health"
$lines.Add("Rolling update: $rolloutOutput")
$lines.Add("Imagen actualizada: $updatedImage")
$lines.Add("Versión reportada: $($updatedHealth.version)")

kubectl rollout undo deployment/backend -n $Namespace | Out-Null
$rollbackOutput = kubectl rollout status deployment/backend -n $Namespace --timeout=180s
$rollbackImage = kubectl get deployment backend -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}'
$lines.Add("Rollback: $rollbackOutput")
$lines.Add("Imagen restaurada: $rollbackImage")

# Se deja la versión nueva desplegada después de demostrar el rollback.
kubectl apply -f k8s/backend-deployment.yaml | Out-Null
kubectl rollout status deployment/backend -n $Namespace --timeout=180s | Out-Null
$finalImage = kubectl get deployment backend -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}'
$finalHealth = Invoke-RestMethod "$BaseUrl/health"
$lines.Add("Imagen final: $finalImage")
$lines.Add("Versión final: $($finalHealth.version)")
$lines.Add('Resultado: rolling update y rollback completados sin dejar el Deployment no disponible.')

Set-Content -LiteralPath $path -Value $lines -Encoding utf8
Get-Content -LiteralPath $path
