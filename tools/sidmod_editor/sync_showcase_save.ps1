# Preview or apply a semantic live-save -> repository showcase-save sync.
# Pokemon matching is performed by save_diff.rb using owner + personal ID, so
# box moves do not appear as delete/add churn.
param(
  [string]$LiveSave = (Join-Path $env:APPDATA 'infinitefusion\File A.rxdata'),
  [string]$BaselineSave = '',
  [string]$RepoSave = '',
  [string]$Updates = '',
  [string]$SaveReadme = '',
  [string]$Report = '',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$editorDir = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $editorDir '..\..')).Path
if (-not $RepoSave) { $RepoSave = Join-Path $repoRoot 'saves\File A.rxdata' }
if (-not $BaselineSave) { $BaselineSave = $RepoSave }
if (-not $Updates) { $Updates = Join-Path $repoRoot 'UPDATES.md' }
if (-not $SaveReadme) { $SaveReadme = Join-Path $repoRoot 'saves\README.md' }

foreach ($path in @($LiveSave, $BaselineSave, $RepoSave, $Updates, $SaveReadme)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}

$ruby = (Get-Command ruby -ErrorAction SilentlyContinue).Source
if (-not $ruby) { $ruby = 'C:\Ruby31-x64\bin\ruby.exe' }
if (-not (Test-Path -LiteralPath $ruby)) { throw "Ruby not found: $ruby" }

$diffTool = Join-Path $editorDir 'save_diff.rb'
$priorErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$reportLines = & $ruby $diffTool $BaselineSave $LiveSave
$diffExit = $LASTEXITCODE
$ErrorActionPreference = $priorErrorPreference
if ($diffExit -ne 0) { throw "save_diff.rb failed with exit code $diffExit" }
$reportText = ($reportLines -join "`n") + "`n"
Write-Output $reportText

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
if ($Report) {
  $reportPath = [System.IO.Path]::GetFullPath($Report)
  [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($reportPath)) | Out-Null
  [System.IO.File]::WriteAllText($reportPath, $reportText, $utf8NoBom)
  Write-Output "report: $reportPath"
}

if (-not $Apply) {
  Write-Output 'PREVIEW ONLY - repository save and UPDATES.md untouched.'
  exit 0
}

$gameProcs = Get-Process -Name 'Game','InfiniteFusion','InfiniteFusion-performance' -ErrorAction SilentlyContinue
if ($gameProcs) { throw "Game is running (PID $($gameProcs.Id -join ',')). Close it before snapshotting the live save." }

$newHash = (Get-FileHash -LiteralPath $LiveSave -Algorithm SHA256).Hash.ToLowerInvariant()
$tempRepo = $RepoSave + '.new'
Copy-Item -LiteralPath $LiveSave -Destination $tempRepo -Force
$copiedHash = (Get-FileHash -LiteralPath $tempRepo -Algorithm SHA256).Hash.ToLowerInvariant()
if ($copiedHash -ne $newHash) {
  Remove-Item -LiteralPath $tempRepo -Force -ErrorAction SilentlyContinue
  throw 'Copy verification failed: SHA-256 mismatch. Repository save was not replaced.'
}
Move-Item -LiteralPath $tempRepo -Destination $RepoSave -Force

$updatesText = [System.IO.File]::ReadAllText($Updates)
$marker = "<!-- save-sync:$newHash -->"
$countsMatch = [System.Text.RegularExpressions.Regex]::Match($reportText, 'save-diff-counts:added=(\d+) upgraded=(\d+)')
if (-not $countsMatch.Success) { throw 'Semantic diff report did not contain machine-readable counts.' }
$reportableCount = [int]$countsMatch.Groups[1].Value + [int]$countsMatch.Groups[2].Value
if ($reportableCount -eq 0) {
  Write-Output 'no new or newly competitive Pokemon; skipped UPDATES.md append'
} elseif (-not $updatesText.Contains($marker)) {
  [System.IO.File]::AppendAllText($Updates, "`n---`n`n" + $reportText, $utf8NoBom)
  Write-Output "updates appended: $Updates"
} else {
  Write-Output "updates already contain $marker; skipped duplicate append"
}

$readmeText = [System.IO.File]::ReadAllText($SaveReadme)
$updatedReadme = [System.Text.RegularExpressions.Regex]::Replace(
  $readmeText,
  '(?i)(`sha256:\s*)[0-9a-f]{64}(`)',
  ('${1}' + $newHash + '${2}'),
  1
)
if ($updatedReadme -eq $readmeText) { throw "Could not find the documented SHA-256 in $SaveReadme" }
[System.IO.File]::WriteAllText($SaveReadme, $updatedReadme, $utf8NoBom)

Write-Output "showcase save updated: $RepoSave"
Write-Output "sha256: $newHash"
