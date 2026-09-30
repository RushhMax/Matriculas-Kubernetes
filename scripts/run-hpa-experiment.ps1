param(
    [string]$BaseUrl = 'http://localhost/api',
    [int]$MaxVus = 120,
    [int]$CpuMs = 30,
    [string]$Namespace = 'unsa-matricula'
)

$ErrorActionPreference = 'Stop'
$evidenceDirectory = Join-Path $PSScriptRoot '../docs/report/evidence'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$timelinePath = Join-Path $evidenceDirectory '11-hpa-timeline.csv'
$outputPath = Join-Path $evidenceDirectory '12-k6-output.txt'
$errorPath = Join-Path $evidenceDirectory '12-k6-error.txt'
$summaryPath = Join-Path $evidenceDirectory 'k6-summary.json'

$k6Command = Get-Command k6 -ErrorAction SilentlyContinue
$k6Path = if ($k6Command) { $k6Command.Source } else { 'C:\Program Files\k6\k6.exe' }
if (-not (Test-Path $k6Path)) { throw 'k6 no fue encontrado. Instalar con: winget install GrafanaLabs.k6' }

'timestamp,currentReplicas,desiredReplicas,cpuAverage,podsRunning' | Set-Content -LiteralPath $timelinePath -Encoding utf8
$arguments = @(
    'run', '-e', "BASE_URL=$BaseUrl", '-e', "MAX_VUS=$MaxVus", '-e', "CPU_MS=$CpuMs",
    '--summary-export', $summaryPath, 'load-tests/k6.js'
)

Write-Host "Iniciando k6: maxVUs=$MaxVus, cpuMs=$CpuMs"
$process = Start-Process -FilePath $k6Path -ArgumentList $arguments -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -WindowStyle Hidden -PassThru

do {
    $hpa = kubectl get hpa backend-hpa -n $Namespace -o json | ConvertFrom-Json
    $running = @(kubectl get pods -n $Namespace -l app=backend -o json | ConvertFrom-Json).items |
        Where-Object { $_.status.phase -eq 'Running' }
    $cpu = if ($hpa.status.currentMetrics) { $hpa.status.currentMetrics[0].resource.current.averageUtilization } else { '' }
    $line = '{0},{1},{2},{3},{4}' -f (Get-Date -Format o),$hpa.status.currentReplicas,$hpa.status.desiredReplicas,$cpu,@($running).Count
    Add-Content -LiteralPath $timelinePath -Value $line -Encoding utf8
    Write-Host $line
    Start-Sleep -Seconds 10
    $process.Refresh()
} while (-not $process.HasExited)

$process.WaitForExit()
Write-Host "k6 termino con codigo $($process.ExitCode). Evidencia: $timelinePath"
Get-Content -LiteralPath $outputPath | Select-Object -Last 45
if ($process.ExitCode -ne 0) { exit $process.ExitCode }
