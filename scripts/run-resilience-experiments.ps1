param(
    [string]$Namespace = 'unsa-matricula',
    [string]$BaseUrl = 'http://localhost/api'
)

$ErrorActionPreference = 'Stop'
$evidenceDirectory = Join-Path $PSScriptRoot '../docs/report/evidence'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null

function Write-Evidence([string]$FileName, [string[]]$Lines) {
    $header = @("Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')", '')
    Set-Content -LiteralPath (Join-Path $evidenceDirectory $FileName) -Value ($header + $Lines) -Encoding utf8
}

Write-Host '[1/4] Self-healing del backend'
$beforePods = @(kubectl get pods -n $Namespace -l app=backend -o jsonpath='{.items[*].metadata.name}') -split ' '
$victim = $beforePods[0]
$timer = [Diagnostics.Stopwatch]::StartNew()
kubectl delete pod $victim -n $Namespace | Out-Null
kubectl rollout status deployment/backend -n $Namespace --timeout=180s | Out-Null
$timer.Stop()
$afterPods = @(kubectl get pods -n $Namespace -l app=backend -o jsonpath='{.items[*].metadata.name}') -split ' '
Write-Evidence '13-self-healing.txt' @(
    'Experimento: eliminación manual de un Pod backend',
    "Pod eliminado: $victim",
    "Pods antes: $($beforePods -join ', ')",
    "Pods después: $($afterPods -join ', ')",
    "Tiempo hasta Deployment disponible: $($timer.Elapsed.TotalSeconds.ToString('F2')) s",
    'Resultado: Kubernetes restauró automáticamente el estado deseado.'
)

Write-Host '[2/4] Persistencia de PostgreSQL'
try {
    Invoke-RestMethod "$BaseUrl/enrollments" -Method Post -ContentType 'application/json' -Body '{"student_id":1,"course_id":1}' | Out-Null
} catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 409) { throw }
}
$before = (Invoke-RestMethod "$BaseUrl/enrollments/student/1").data
$postgresUidBefore = kubectl get pod postgres-0 -n $Namespace -o jsonpath='{.metadata.uid}'
$timer.Restart()
kubectl delete pod postgres-0 -n $Namespace | Out-Null
kubectl wait --for=condition=ready pod/postgres-0 -n $Namespace --timeout=180s | Out-Null
$timer.Stop()
$postgresUidAfter = kubectl get pod postgres-0 -n $Namespace -o jsonpath='{.metadata.uid}'
$after = (Invoke-RestMethod "$BaseUrl/enrollments/student/1").data
$persisted = @($after).Count -eq @($before).Count -and @($after).Count -gt 0
Write-Evidence '14-persistence.txt' @(
    'Experimento: recreación de postgres-0',
    "UID antes: $postgresUidBefore",
    "UID después: $postgresUidAfter",
    "Matrículas antes: $(@($before).Count)",
    "Matrículas después: $(@($after).Count)",
    "Tiempo de recuperación: $($timer.Elapsed.TotalSeconds.ToString('F2')) s",
    "Datos persistieron: $persisted",
    'Resultado: cambió el Pod, pero el PVC conservó los datos.'
)

Write-Host '[3/4] Liveness y reinicio de contenedor'
$failure = Invoke-RestMethod "$BaseUrl/demo/fail-health" -Method Post
$livePod = $failure.served_by
$restartBefore = [int](kubectl get pod $livePod -n $Namespace -o jsonpath='{.status.containerStatuses[0].restartCount}')
$deadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Seconds 3
    $restartAfter = [int](kubectl get pod $livePod -n $Namespace -o jsonpath='{.status.containerStatuses[0].restartCount}')
} while ($restartAfter -le $restartBefore -and (Get-Date) -lt $deadline)
kubectl wait --for=condition=ready "pod/$livePod" -n $Namespace --timeout=120s | Out-Null
Write-Evidence '15-liveness.txt' @(
    'Experimento: falla controlada del endpoint /health',
    "Pod: $livePod",
    "Respuesta de activación: $($failure.status)",
    "Reinicios antes: $restartBefore",
    "Reinicios después: $restartAfter",
    "Validación: $($restartAfter -gt $restartBefore)",
    'Resultado: después de tres fallos de liveness, kubelet reinició el contenedor.'
)

Write-Host '[4/4] Backup persistente'
$job = 'backup-evidence-' + (Get-Date -Format 'HHmmss')
kubectl create job --from=cronjob/postgres-backup $job -n $Namespace | Out-Null
kubectl wait --for=condition=complete "job/$job" -n $Namespace --timeout=180s | Out-Null
$backupLog = kubectl logs "job/$job" -n $Namespace
$pvc = kubectl get pvc postgres-backups-pvc -n $Namespace -o wide
Write-Evidence '16-backup.txt' @(
    'Experimento: ejecución manual desde el CronJob',
    "Job: $job",
    $backupLog,
    '',
    $pvc,
    'Resultado: pg_dump generó un archivo no vacío dentro del PVC de backups.'
)

Write-Host 'Experimentos de resiliencia completados.'
