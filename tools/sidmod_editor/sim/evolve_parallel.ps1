# Parallel evolution: propose (editor per team) -> validate (N workers) -> select.
#   powershell evolve_parallel.ps1 -InTag round1 [-OutTag round2] [-Cap 45] [-Workers 6]
param(
  [Parameter(Mandatory=$true)][string]$InTag,
  [string]$OutTag = "",
  [string]$Model  = "claude-haiku-4-5-20251001",
  [int]$Cap       = 45,
  [int]$Workers   = 12,
  [int]$Games     = 1
)
$ErrorActionPreference = "Stop"
if ($OutTag -eq "") { $OutTag = "${InTag}_v2" }
$rb  = "C:\Ruby31-x64\bin\ruby.exe"
$dir = $PSScriptRoot
$logDir = Join-Path $env:TEMP "sim_evolve"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Output "== propose (editor per team) =="
& $rb "$dir\evolve_propose.rb" $InTag $OutTag $Model
if ($LASTEXITCODE -ne 0) { throw "propose failed ($LASTEXITCODE)" }

Write-Output "== validate ($Workers workers) =="
$procs = @()
for ($i = 0; $i -lt $Workers; $i++) {
  $a = @("`"$dir\val_worker.rb`"", $OutTag, $Model, $Cap, $i, $Workers, $Games)
  $procs += Start-Process -FilePath $rb -ArgumentList $a -PassThru -WindowStyle Hidden `
              -RedirectStandardError (Join-Path $logDir "v$i.err") -RedirectStandardOutput (Join-Path $logDir "v$i.out")
}
$procs | Wait-Process

Write-Output "== select (adopt/revert) =="
& $rb "$dir\evolve_select.rb" $OutTag
Write-Output "done. changelog: reports\$OutTag\changelog.txt"
