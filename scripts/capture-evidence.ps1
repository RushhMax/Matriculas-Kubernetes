param(
    [string]$Namespace = 'unsa-matricula',
    [string]$OutputDirectory = 'docs/report/evidence'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Save-Evidence([string]$Name, [scriptblock]$Command) {
    $path = Join-Path $OutputDirectory "$Name.txt"
    $header = "Evidencia: $Name`nFecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')`n`n"
    $body = & $Command 2>&1 | Out-String
    Set-Content -LiteralPath $path -Value ($header + $body) -Encoding utf8
    Write-Host "[OK] $path"
}

Save-Evidence '01-cluster' { kubectl get nodes -o wide }
Save-Evidence '02-recursos' { kubectl get all,ingress,hpa,pvc,configmap,secret,cronjob -n $Namespace -o wide }
Save-Evidence '03-pods' { kubectl get pods -n $Namespace -o wide }
Save-Evidence '04-metricas' { kubectl top pods -n $Namespace }
Save-Evidence '05-hpa' { kubectl describe hpa backend-hpa -n $Namespace }
Save-Evidence '06-pvc' { kubectl get pvc -n $Namespace; kubectl describe pvc postgres-pvc -n $Namespace }
Save-Evidence '07-rollout' { kubectl rollout history deployment/backend -n $Namespace }
Save-Evidence '08-eventos' { kubectl get events -n $Namespace --sort-by=.lastTimestamp }
Save-Evidence '09-backups' { kubectl get cronjob,jobs -n $Namespace }
Save-Evidence '10-endpoints' {
    kubectl get endpointslice -n $Namespace -l kubernetes.io/service-name=backend-service -o wide
}
Save-Evidence '18-network-policies' { kubectl get networkpolicy -n $Namespace -o wide }
Save-Evidence '19-observability' { kubectl get all -n monitoring -o wide }
