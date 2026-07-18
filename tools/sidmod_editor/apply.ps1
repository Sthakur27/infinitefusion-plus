# Safe orchestration for the offline save editor.
#   powershell apply.ps1 -Spec <spec.json> [-Slot B] [-DryRun]
# Steps: refuse if game running -> backup live save -> edit on a copy ->
#        verify no collateral damage -> atomic-replace live save.
param(
  [Parameter(Mandatory=$true)][string]$Spec,
  [string]$Slot = "B",
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$editorDir = $PSScriptRoot
$saveDir   = Join-Path $env:APPDATA "infinitefusion"
$live      = Join-Path $saveDir ("File " + $Slot + ".rxdata")

$ruby = (Get-Command ruby -ErrorAction SilentlyContinue).Source
if (-not $ruby) { $ruby = "C:\Ruby31-x64\bin\ruby.exe" }
if (-not (Test-Path $ruby)) { Write-Error "Ruby not found."; exit 1 }

# 1) game must be closed
$gameProcs = Get-Process -Name 'Game','InfiniteFusion','InfiniteFusion-performance' -ErrorAction SilentlyContinue
if ($gameProcs) {
  Write-Error ("Game is RUNNING (PID " + ($gameProcs.Id -join ',') + "). Close it first; an open game overwrites the edit on its next save.")
  exit 2
}
if (-not (Test-Path $live)) { Write-Error ("Live save not found: " + $live); exit 1 }
if (-not (Test-Path $Spec)) { Write-Error ("Spec not found: " + $Spec); exit 1 }

# 2) backup live
$stamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$bkDir  = Join-Path $saveDir ("sidmod_manual_backups\" + $stamp)
New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
Copy-Item $live -Destination (Join-Path $bkDir ("File " + $Slot + ".rxdata"))
Write-Output ("backup: " + $bkDir)

# 3) edit on a copy
$work = Join-Path $env:TEMP ("sidmod_work_" + $stamp + ".rxdata")
$out  = Join-Path $env:TEMP ("sidmod_out_" + $stamp + ".rxdata")
Copy-Item $live -Destination $work -Force

$editJson = & $ruby (Join-Path $editorDir "edit_save.rb") $work $Spec $out
Write-Output ("edit_save: " + $editJson)
$edit = $editJson | ConvertFrom-Json
if (-not $edit.ok) {
  Write-Error ("edit_save failed: " + ($edit.errors -join '; '))
  exit 3
}

# 4) verify no collateral damage
$verify = & $ruby (Join-Path $editorDir "verify_edit.rb") $work $out $Spec
Write-Output $verify
if (-not ($verify -match "collateral problems: NONE")) {
  Write-Error "collateral check FAILED - live save NOT modified."
  exit 4
}

# 5) apply unless dry run
if ($DryRun) {
  Write-Output ("DRY RUN - live save untouched. Edited copy at: " + $out)
  exit 0
}
$tmpLive = $live + ".new"
Copy-Item $out -Destination $tmpLive -Force
Move-Item -Path $tmpLive -Destination $live -Force
Write-Output ("APPLIED to " + $live)
Remove-Item $work,$out -ErrorAction SilentlyContinue
