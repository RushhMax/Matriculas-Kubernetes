param(
    [string]$Namespace = 'unsa-matricula',
    [string]$BaseUrl = 'http://localhost/api',
    [switch]$Snapshot
)

$ErrorActionPreference = 'Stop'
$esc = [char]27
$colors = @{
    Reset = "$esc[0m"; Bold = "$esc[1m"; Blue = "$esc[38;5;39m"
    Cyan = "$esc[38;5;45m"; Green = "$esc[38;5;82m"; Yellow = "$esc[38;5;220m"
    Red = "$esc[38;5;203m"; Gray = "$esc[38;5;245m"
}

function Write-Title([string]$Text) {
    Write-Host "`n$($colors.Bold)$($colors.Cyan)$Text$($colors.Reset)"
    Write-Host ($colors.Gray + ('=' * [Math]::Min(78, $Text.Length + 8)) + $colors.Reset)
}

function Assert-Cluster {
    $null = kubectl cluster-info 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Kubernetes no esta disponible. Abre Docker Desktop y habilita Kubernetes.' }
}

function Show-Architecture {
    Clear-Host
    Write-Title 'UNSA MATRICULA - ARQUITECTURA CLOUD-NATIVE'
    Write-Host @"
$($colors.Blue)                         ESTUDIANTES$($colors.Reset)
                              |
                              v
                    +-------------------+
                    | INGRESS / GATEWAY |
                    +---------+---------+
                              |
                    +---------v---------+
                    | frontend-service  |
                    +---------+---------+
                              |
                    +---------v---------+
                    |   Frontend Pod    |
                    |    Vue + Nginx    |
                    +---------+---------+
                              | /api
                    +---------v---------+
                    | backend-service   |
                    +----+----------+---+
                         |          |
                  +------v--+    +--v------+
                  | Pod B1  | .. | Pod Bn  |  <--- HPA 2..5
                  +----+----+    +----+----+
                       +--------------+
                              |
              +---------------+----------------+
              |                                |
      +-------v--------+              +--------v-------+
      | PostgreSQL STS |              | Redis Cache    |
      | PVC: datos     |              | Deployment     |
      +-------+--------+              +----------------+
              |
      +-------v--------+
      | CronJob Backup |
      | PVC: respaldos |
      +----------------+
"@
    Write-Host "$($colors.Gray)Flujo: Ingress -> Frontend -> Service backend -> Pods -> PostgreSQL/Redis$($colors.Reset)"
}

function Get-Diagnosis([object[]]$Pods) {
    $messages = [System.Collections.Generic.List[string]]::new()
    foreach ($pod in $Pods) {
        $phase = $pod.status.phase
        $ready = @($pod.status.containerStatuses | Where-Object ready).Count
        $total = @($pod.status.containerStatuses).Count
        if ($phase -ne 'Running') {
            $messages.Add("$($pod.metadata.name): estado $phase. Revisar: kubectl describe pod/$($pod.metadata.name) -n $Namespace")
        } elseif ($ready -lt $total) {
            $messages.Add("$($pod.metadata.name): $ready/$total listo. Revisar probes y logs.")
        }
        foreach ($status in @($pod.status.containerStatuses)) {
            if ($status.state.waiting.reason) {
                $messages.Add("$($pod.metadata.name): $($status.state.waiting.reason) - $($status.state.waiting.message)")
            }
        }
    }
    if ($messages.Count -eq 0) { $messages.Add('Todos los Pods estan saludables. No se detectaron acciones correctivas.') }
    return $messages
}

function Show-LiveDashboard {
    Assert-Cluster
    do {
        $podsJson = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
        $pods = @($podsJson.items)
        $hpa = kubectl get hpa backend-hpa -n $Namespace -o json 2>$null | ConvertFrom-Json
        Clear-Host
        Write-Title "CLUSTER EN VIVO | $(Get-Date -Format 'HH:mm:ss') | Q para volver"
        Write-Host "$($colors.Bold)PODS$($colors.Reset)"
        '{0,-43} {1,-10} {2,-8} {3,-10} {4}' -f 'NOMBRE','ESTADO','READY','REINICIOS','NODO'
        foreach ($pod in $pods) {
            $ready = @($pod.status.containerStatuses | Where-Object ready).Count
            $total = @($pod.status.containerStatuses).Count
            $restarts = (@($pod.status.containerStatuses | ForEach-Object restartCount) | Measure-Object -Sum).Sum
            $tone = if ($pod.status.phase -eq 'Running' -and $ready -eq $total) { $colors.Green } else { $colors.Yellow }
            Write-Host ($tone + ('{0,-43} {1,-10} {2,-8} {3,-10} {4}' -f $pod.metadata.name,$pod.status.phase,"$ready/$total",$restarts,$pod.spec.nodeName) + $colors.Reset)
        }

        Write-Host "`n$($colors.Bold)AUTOSCALING$($colors.Reset)"
        if ($hpa) {
            $cpu = if ($hpa.status.currentMetrics) { $hpa.status.currentMetrics[0].resource.current.averageUtilization } else { '?' }
            Write-Host "Backend: $($colors.Cyan)$($hpa.status.currentReplicas)$($colors.Reset) replicas actuales / $($hpa.spec.minReplicas)..$($hpa.spec.maxReplicas) | CPU: $cpu% / objetivo $($hpa.spec.metrics[0].resource.target.averageUtilization)%"
        } else { Write-Host "$($colors.Yellow)HPA no encontrado.$($colors.Reset)" }

        Write-Host "`n$($colors.Bold)CONSUMO$($colors.Reset)"
        kubectl top pods -n $Namespace 2>$null | Select-Object -First 8

        Write-Host "`n$($colors.Bold)DIAGNOSTICO Y SOLUCION$($colors.Reset)"
        Get-Diagnosis $pods | ForEach-Object { Write-Host " - $_" }

        Write-Host "`n$($colors.Bold)EVENTOS RECIENTES$($colors.Reset)"
        kubectl get events -n $Namespace --sort-by=.lastTimestamp 2>$null | Select-Object -Last 6
        Start-Sleep -Seconds 2
        if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q') { break }
    } while ($true)
}

function Test-Distribution {
    Write-Title 'DEMO: DISTRIBUCION ENTRE PODS'
    $served = for ($i = 1; $i -le 50; $i++) {
        try { (Invoke-RestMethod "$BaseUrl/courses" -TimeoutSec 10).served_by }
        catch { 'ERROR' }
    }
    $served | Group-Object | Sort-Object Count -Descending | ForEach-Object {
        $pct = [Math]::Round(100 * $_.Count / 50, 1)
        $bar = '#' * [Math]::Max(1, [Math]::Round($pct / 3))
        '{0,-45} {1,3} req  {2,5}%  {3}' -f $_.Name,$_.Count,$pct,$bar
    }
    Read-Host 'Enter para continuar'
}

function Test-Cache {
    Write-Title 'DEMO: CACHE REDIS'
    1..3 | ForEach-Object {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-RestMethod "$BaseUrl/courses" -TimeoutSec 10
        $watch.Stop()
        "Consulta $_ -> fuente=$($result.source), pod=$($result.served_by), latencia=$($watch.ElapsedMilliseconds)ms"
        Start-Sleep -Milliseconds 250
    }
    Read-Host 'Enter para continuar'
}

function Test-SelfHealing {
    Write-Title 'DEMO: SELF-HEALING'
    $before = @(kubectl get pods -n $Namespace -l app=backend -o jsonpath='{.items[*].metadata.name}' 2>$null) -split ' '
    $victim = $before[0]
    Write-Host "Se eliminara $victim; el Deployment debe reemplazarlo sin perder capacidad global."
    $answer = Read-Host 'Escribe SI para continuar'
    if ($answer -ne 'SI') { return }
    kubectl delete pod $victim -n $Namespace
    kubectl rollout status deployment/backend -n $Namespace --timeout=120s
    $after = @(kubectl get pods -n $Namespace -l app=backend -o jsonpath='{.items[*].metadata.name}') -split ' '
    Write-Host "$($colors.Green)Antes: $($before -join ', ')$($colors.Reset)"
    Write-Host "$($colors.Green)Despues: $($after -join ', ')$($colors.Reset)"
    Read-Host 'Enter para continuar'
}

function Test-Persistence {
    Write-Title 'DEMO: PERSISTENCIA POSTGRESQL'
    $before = Invoke-RestMethod "$BaseUrl/enrollments/student/1"
    try {
        Invoke-RestMethod "$BaseUrl/enrollments" -Method Post -ContentType 'application/json' -Body '{"student_id":1,"course_id":1}' | Out-Null
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 409) { throw }
    }
    $registered = (Invoke-RestMethod "$BaseUrl/enrollments/student/1").data.Count
    Write-Host "Matriculas antes del reinicio: $registered. Eliminando postgres-0..."
    kubectl delete pod postgres-0 -n $Namespace
    kubectl wait --for=condition=ready pod/postgres-0 -n $Namespace --timeout=180s
    $after = (Invoke-RestMethod "$BaseUrl/enrollments/student/1").data.Count
    if ($after -eq $registered) { Write-Host "$($colors.Green)OK: $after matriculas permanecen gracias al PVC.$($colors.Reset)" }
    else { Write-Host "$($colors.Red)FALLO: antes=$registered, despues=$after.$($colors.Reset)" }
    Read-Host 'Enter para continuar'
}

function Start-Backup {
    Write-Title 'DEMO: BACKUP PERSISTENTE'
    $job = 'backup-demo-' + (Get-Date -Format 'HHmmss')
    kubectl create job --from=cronjob/postgres-backup $job -n $Namespace
    kubectl wait --for=condition=complete "job/$job" -n $Namespace --timeout=180s
    kubectl logs "job/$job" -n $Namespace
    kubectl get pvc postgres-backups-pvc -n $Namespace
    Read-Host 'Enter para continuar'
}

function Show-Menu {
    Show-Architecture
    Write-Host @"
$($colors.Bold)CENTRO DE DEMOSTRACION$($colors.Reset)
  [1] Dashboard en vivo: Pods, HPA, CPU, eventos y diagnostico
  [2] Distribucion de 50 solicitudes entre Pods
  [3] Redis: comparar origen DB/cache
  [4] Self-healing: eliminar un Backend Pod
  [5] Persistencia: reiniciar PostgreSQL y verificar datos
  [6] Backup: ejecutar CronJob manualmente
  [7] Mostrar arquitectura
  [Q] Salir
"@
}

Assert-Cluster
if ($Snapshot) {
    Show-Architecture
    Write-Title 'ESTADO ACTUAL DEL CLUSTER'
    kubectl get pods -n $Namespace -o wide
    Write-Host "`nHPA Y METRICAS"
    kubectl get hpa -n $Namespace
    kubectl top pods -n $Namespace
    Write-Host "`nEVENTOS RECIENTES"
    kubectl get events -n $Namespace --sort-by=.lastTimestamp | Select-Object -Last 8
    exit
}
do {
    Show-Menu
    $choice = (Read-Host 'Selecciona una opcion').ToUpperInvariant()
    switch ($choice) {
        '1' { Show-LiveDashboard }
        '2' { Test-Distribution }
        '3' { Test-Cache }
        '4' { Test-SelfHealing }
        '5' { Test-Persistence }
        '6' { Start-Backup }
        '7' { Show-Architecture; Read-Host 'Enter para continuar' }
        'Q' { break }
        default { Write-Host 'Opcion no valida.'; Start-Sleep 1 }
    }
} while ($choice -ne 'Q')
