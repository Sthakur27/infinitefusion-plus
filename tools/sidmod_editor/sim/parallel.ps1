# Parallel round-robin: spawn N workers (each runs a shard of battles, skipping done
# ones), wait, then aggregate + coach.  powershell parallel.ps1 -Tag round1 [-Workers 6]
param(
  [Parameter(Mandatory=$true)][string]$Tag,
  [string]$Model = "claude-haiku-4-5-20251001",
  [int]$Cap = 55,
  [int]$Workers = 12,
  [int]$Games = 1
)
$ErrorActionPreference = "Stop"
$rb  = "C:\Ruby31-x64\bin\ruby.exe"
$dir = $PSScriptRoot
$logDir = Join-Path $env:TEMP "sim_workers"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$procs = @()
for ($i = 0; $i -lt $Workers; $i++) {
  $args = @("`"$dir\battle_worker.rb`"", $Tag, $Model, $Cap, $i, $Workers, $Games)
  $procs += Start-Process -FilePath $rb -ArgumentList $args -PassThru -WindowStyle Hidden `
              -RedirectStandardError (Join-Path $logDir "w$i.err") -RedirectStandardOutput (Join-Path $logDir "w$i.out")
}
Write-Output "launched $Workers workers for '$Tag' (cap $Cap, model $Model); waiting..."
$procs | Wait-Process
Write-Output "all workers done. aggregating..."
& $rb "$dir\aggregate.rb" $Tag
