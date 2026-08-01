param(
  [ValidateSet('Scan','Coach','Apply')][string]$Mode = 'Scan',
  [string]$Model = 'claude-sonnet-5',
  [ValidateRange(1,16)][int]$Threads = 6,
  [string]$Tag
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rubyScript = Join-Path $PSScriptRoot 'sim\ncoach_api.rb'
$runMode = $Mode.ToLowerInvariant()
if (-not $Tag -and $Mode -ne 'Apply') {
  $Tag = 'pc_upgrade_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
}
if ($Mode -eq 'Apply' -and -not $Tag) { throw 'Apply requires -Tag from a reviewed Coach run.' }

Push-Location $root
try {
  $reportDir = Join-Path $PSScriptRoot "sim\nreports\$Tag"
  if ($Mode -eq 'Apply') {
    $spec = Join-Path $reportDir 'coach_spec.json'
    if (-not (Test-Path -LiteralPath $spec)) { throw "Missing reviewed coach spec: $spec" }
    $liveDir = Join-Path $env:APPDATA 'infinitefusion'
    $rollback = Join-Path $liveDir ('sidmod_manual_backups\mass_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $rollback -Force | Out-Null
    Get-ChildItem -LiteralPath $liveDir -File | Where-Object { $_.Name -match '^File [A-H]\.rxdata$' } |
      ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $rollback }
    Write-Output "Full A-H rollback backup: $rollback"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply.ps1') -Spec $spec -Slot A -DryRun
    if ($LASTEXITCODE -ne 0) { throw "dry-run verification failed with exit code $LASTEXITCODE" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply.ps1') -Spec $spec -Slot A
    if ($LASTEXITCODE -ne 0) { throw "save apply failed with exit code $LASTEXITCODE" }
    Write-Output 'Applied reviewed spec to File A through the verified save-edit gate.'
    return
  }
  & ruby $rubyScript all $Model $Threads $Tag $runMode
  if ($LASTEXITCODE -ne 0) { throw "candidate coach failed with exit code $LASTEXITCODE" }
  Write-Output "Results: $reportDir"
  if ($Mode -eq 'Coach') {
    Write-Output 'No save was modified. Review coach_report.json and apply coach_spec.json through apply.ps1 -DryRun first.'
  }
} finally {
  Pop-Location
}
