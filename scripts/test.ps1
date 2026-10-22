# SPDX-License-Identifier: GPL-3.0-only
param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$installer = Join-Path $RepoRoot 'dist\Weasel-Rounded-Setup.exe'
if (-not (Test-Path -LiteralPath $installer)) { throw 'Run scripts/build.ps1 first.' }
$testDir = Join-Path $RepoRoot ('build\tests\' + [Guid]::NewGuid().ToString('N'))
$userDir = Join-Path $testDir 'simulated-user\Rime'
New-Item -ItemType Directory -Path (Join-Path $userDir 'rime_ice.userdb') -Force | Out-Null
'personal-dictionary' | Set-Content -LiteralPath (Join-Path $userDir 'rime_ice.userdb\sentinel.txt')
'old-settings' | Set-Content -LiteralPath (Join-Path $userDir 'default.custom.yaml')
'personal-phrase' | Set-Content -LiteralPath (Join-Path $userDir 'custom_phrase.txt')
$process = Start-Process -FilePath $installer -ArgumentList ('--test-config "' + $testDir + '"') -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 0) { throw (Get-Content -LiteralPath (Join-Path $testDir 'status.txt') -Raw) }
if ((Get-Content -LiteralPath (Join-Path $userDir 'rime_ice.userdb\sentinel.txt')).Trim() -ne 'personal-dictionary') { throw 'Personal dictionary was changed.' }
if ((Get-Content -LiteralPath (Join-Path $userDir 'custom_phrase.txt')).Trim() -ne 'personal-phrase') { throw 'Custom phrase was changed.' }
$backup = Get-ChildItem -Path (Join-Path $testDir 'simulated-user\Rime-backup-*\default.custom.yaml') | Select-Object -First 1
if (-not $backup -or (Get-Content -LiteralPath $backup.FullName).Trim() -ne 'old-settings') { throw 'Original settings were not backed up.' }
$defaults = Get-Content -LiteralPath (Join-Path $userDir 'default.custom.yaml') -Raw
if ($defaults -notmatch 'schema: rime_ice' -or $defaults -notmatch 'page_size": 9') { throw 'Incorrect schema or candidate count.' }
$baseTheme = Get-Content -LiteralPath (Join-Path $userDir 'weasel.yaml') -Raw
if ($baseTheme -notmatch 'preset_color_schemes: \{\}') { throw 'Unexpected built-in theme list.' }
Add-Content -LiteralPath (Join-Path $testDir 'config\default.custom.yaml') -Value '# tampered file'
$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$process = Start-Process -FilePath $powershell -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $testDir 'install.ps1') + '" -ValidateOnly') -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 1) { throw 'A corrupted payload was not rejected.' }
Write-Output 'PASS: integrity, isolated install, backups, personal dictionary and phrase preservation, scheme selection, single theme family, tamper rejection.'
