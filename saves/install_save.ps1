<#
  install_save.ps1 - install the sidmod showcase save into your Infinite Fusion save folder.

  Usage:
    powershell -ExecutionPolicy Bypass -File saves\install_save.ps1            # install to first FREE slot
    powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -List      # just show your slots
    powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -Slot C    # install to a specific slot
    powershell -ExecutionPolicy Bypass -File saves\install_save.ps1 -Slot A -Force   # overwrite an occupied slot

  Safety rules this script will not break:
    * It refuses to run while the game is open (an open game overwrites the file on its next save).
    * With no -Slot it only ever writes to an EMPTY slot, so nothing of yours is touched.
    * Overwriting an occupied slot needs -Force, and the existing file is backed up first to
      %APPDATA%\infinitefusion\sidmod_save_backups\<timestamp>\ .
    * The copy is verified by SHA256 before the script reports success.
#>
param(
  [ValidatePattern('^[A-Ha-h]$')][string]$Slot,
  [switch]$Force,
  [switch]$List
)
$ErrorActionPreference = 'Stop'

$saveDir = Join-Path $env:APPDATA 'infinitefusion'
$src     = Join-Path $PSScriptRoot 'File A.rxdata'
$letters = @('A','B','C','D','E','F','G','H')

# Write-Error under ErrorActionPreference='Stop' throws and exits 1 before any
# 'exit <code>' runs, which would make the documented exit codes a lie. Fail writes
# to stderr and exits with the real code.
function Fail([string]$msg, [int]$code) {
  [Console]::Error.WriteLine("ERROR: " + $msg)
  exit $code
}

function Get-SlotPath([string]$letter) { Join-Path $saveDir ("File " + $letter + ".rxdata") }

function Show-Slots {
  Write-Host ""
  Write-Host ("Save folder: " + $saveDir)
  foreach ($l in $letters) {
    $p = Get-SlotPath $l
    if (Test-Path $p) {
      $f = Get-Item $p
      Write-Host ("  File {0}  OCCUPIED  {1,8:N2} MB   modified {2}" -f $l, ($f.Length/1MB), $f.LastWriteTime)
    } else {
      Write-Host ("  File {0}  free" -f $l)
    }
  }
  Write-Host ""
}

# ---- 0) sanity ----
if (-not (Test-Path $src)) { Fail ("Shipped save not found: " + $src) 1 }

if (-not (Test-Path $saveDir)) {
  Write-Host ("Save folder does not exist yet, creating: " + $saveDir)
  New-Item -ItemType Directory -Force -Path $saveDir | Out-Null
}

if ($List) { Show-Slots; exit 0 }

# ---- 1) game must be closed ----
$gameProcs = Get-Process -Name 'Game','InfiniteFusion','InfiniteFusion-performance' -ErrorAction SilentlyContinue
if ($gameProcs) {
  Fail ("Infinite Fusion is RUNNING (PID " + ($gameProcs.Id -join ',') + "). Close the game first - an open game overwrites save files on its next save.") 2
}

# ---- 2) pick the destination slot ----
if ($Slot) {
  $target = $Slot.ToUpper()
} else {
  $target = $null
  foreach ($l in $letters) {
    if (-not (Test-Path (Get-SlotPath $l))) { $target = $l; break }
  }
  if (-not $target) {
    Show-Slots
    Fail "All 8 save slots are occupied. Re-run with an explicit slot plus -Force, e.g. -Slot H -Force (the existing file is backed up first)." 3
  }
  Write-Host ("No -Slot given; using first free slot: File " + $target)
}

$dest = Get-SlotPath $target

# ---- 3) never clobber silently ----
if (Test-Path $dest) {
  if (-not $Force) {
    Show-Slots
    Fail ("File " + $target + " already exists. Re-run with -Force to overwrite it (it will be backed up first), or pick a free slot.") 4
  }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bkDir = Join-Path $saveDir ('sidmod_save_backups\' + $stamp)
  New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
  Copy-Item $dest -Destination (Join-Path $bkDir ('File ' + $target + '.rxdata'))
  Write-Host ("backed up your existing File " + $target + " -> " + $bkDir)
}

# ---- 4) install + verify ----
Copy-Item $src -Destination $dest -Force

$srcHash  = (Get-FileHash $src  -Algorithm SHA256).Hash
$destHash = (Get-FileHash $dest -Algorithm SHA256).Hash
if ($srcHash -ne $destHash) {
  Fail "Copy verification FAILED (SHA256 mismatch). Do not load this slot." 5
}

Write-Host ""
Write-Host ("Installed sidmod save -> File " + $target)
Write-Host ("  path   : " + $dest)
Write-Host ("  sha256 : " + $destHash.ToLower())
Write-Host ""
Write-Host ("Launch the game and pick save slot " + $target + ".")
