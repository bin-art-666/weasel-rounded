# SPDX-License-Identifier: GPL-3.0-only
param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$lock = Get-Content -LiteralPath (Join-Path $RepoRoot 'upstream.json') -Raw | ConvertFrom-Json
$buildDir = Join-Path $RepoRoot ('build\package-' + [Guid]::NewGuid().ToString('N'))
$cacheDir = Join-Path $RepoRoot 'build\cache'
$payloadDir = Join-Path $buildDir 'payload'
$configDir = Join-Path $payloadDir 'config'
$distDir = Join-Path $RepoRoot 'dist'
foreach ($dir in @($cacheDir,$configDir,$distDir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Hash([string]$path) {
  $stream = [IO.File]::OpenRead($path)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
  finally { $stream.Dispose(); $sha.Dispose() }
}
function Download([string]$url,[string]$path,[string]$expected) {
  if (-not (Test-Path -LiteralPath $path)) { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path }
  if ((Hash $path) -ne $expected) { throw "Checksum mismatch: $path" }
}
$officialInstaller = Join-Path $cacheDir 'weasel-0.17.4.0-installer.exe'
$iceArchive = Join-Path $cacheDir 'rime-ice.zip'
Download $lock.weasel.url $officialInstaller $lock.weasel.sha256
Download $lock.rimeIce.url $iceArchive $lock.rimeIce.sha256
Add-Type -AssemblyName System.IO.Compression.FileSystem
$iceExtract = Join-Path $buildDir 'ice-source'
[IO.Compression.ZipFile]::ExtractToDirectory($iceArchive,$iceExtract)
$iceDir = Join-Path $iceExtract ('rime-ice-' + $lock.rimeIce.commit)
foreach ($name in @('cn_dicts','en_dicts','lua','opencc')) {
  Copy-Item -LiteralPath (Join-Path $iceDir $name) -Destination $configDir -Recurse
}
foreach ($name in @('default.yaml','rime_ice.schema.yaml','rime_ice.dict.yaml','melt_eng.schema.yaml','melt_eng.dict.yaml','radical_pinyin.schema.yaml','radical_pinyin.dict.yaml','symbols_v.yaml','symbols_caps_v.yaml','custom_phrase.txt')) {
  Copy-Item -LiteralPath (Join-Path $iceDir $name) -Destination $configDir
}
Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'config') -File | Copy-Item -Destination $configDir -Force
$utf8Bom = New-Object Text.UTF8Encoding($true)
$scriptText = Get-Content -LiteralPath (Join-Path $RepoRoot 'src\install.ps1') -Raw -Encoding UTF8
[IO.File]::WriteAllText((Join-Path $payloadDir 'install.ps1'),$scriptText,$utf8Bom)
Copy-Item -LiteralPath $officialInstaller -Destination $payloadDir
Copy-Item -LiteralPath (Join-Path $RepoRoot 'licenses') -Destination $payloadDir -Recurse
Copy-Item -LiteralPath (Join-Path $RepoRoot 'LICENSE'),(Join-Path $RepoRoot 'README.md'),(Join-Path $RepoRoot 'THIRD_PARTY.md'),(Join-Path $RepoRoot 'upstream.json') -Destination $payloadDir
$sourceDir = Join-Path $payloadDir 'sources'
New-Item -ItemType Directory -Path $sourceDir | Out-Null
Copy-Item -LiteralPath (Join-Path $RepoRoot 'src'),(Join-Path $RepoRoot 'scripts') -Destination $sourceDir -Recurse
$manifest = @(Get-ChildItem -LiteralPath $payloadDir -File -Recurse | ForEach-Object {
  [PSCustomObject]@{path=$_.FullName.Substring($payloadDir.Length+1);sha256=(Hash $_.FullName)}
})
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $payloadDir 'manifest.json') -Encoding UTF8
$payloadZip = Join-Path $buildDir 'payload.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($payloadDir,$payloadZip,[IO.Compression.CompressionLevel]::Optimal,$false)
$installer = Join-Path $distDir 'Weasel-Rounded-Setup.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '64-bit .NET Framework C# compiler not found.' }
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/win32manifest:$RepoRoot\src\setup.manifest" "/resource:$payloadZip,payload.zip" "/out:$installer" "$RepoRoot\src\RoundedWeaselSetup.cs"
if ($LASTEXITCODE -ne 0) { throw 'C# compilation failed.' }
((Hash $installer) + '  Weasel-Rounded-Setup.exe') | Set-Content -LiteralPath (Join-Path $distDir 'SHA256.txt') -Encoding ASCII
Write-Output "Built $installer"
