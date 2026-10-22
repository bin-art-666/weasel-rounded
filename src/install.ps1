param([switch]$ValidateOnly, [string]$TestTarget)
$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
$logPath = Join-Path $packageRoot 'install.log'
$statusPath = Join-Path $packageRoot 'status.txt'
function Status([string]$message) {
  $message | Set-Content -LiteralPath $statusPath -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value ((Get-Date -Format s) + ' ' + $message) -Encoding UTF8
}
function Find-Weasel {
  foreach ($view in @([Microsoft.Win32.RegistryView]::Registry32, [Microsoft.Win32.RegistryView]::Registry64)) {
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
    try {
      $key = $base.OpenSubKey('SOFTWARE\Rime\Weasel')
      if ($key) {
        try {
          $root = [string]$key.GetValue('WeaselRoot')
          if ($root -and (Test-Path -LiteralPath (Join-Path $root 'WeaselDeployer.exe'))) { return $root }
        } finally { $key.Dispose() }
      }
    } finally { $base.Dispose() }
  }
  return $null
}
try {
  Status '正在校验离线安装文件…'
  $manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'manifest.json') -Raw | ConvertFrom-Json
  foreach ($entry in $manifest) {
    $file = Join-Path $packageRoot $entry.path
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "缺少安装文件：$($entry.path)" }
    $stream = [IO.File]::OpenRead($file)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($actualHash -ne $entry.sha256) { throw "文件校验失败：$($entry.path)" }
  }
  if ($ValidateOnly) { Status '离线文件校验通过。'; exit 0 }
  $root = $null
  if ($TestTarget) {
    $userDir = [IO.Path]::GetFullPath($TestTarget)
  } else {
    $userDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Rime'
    $userKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Rime\Weasel')
    if ($userKey) {
      try { $configuredDir = [string]$userKey.GetValue('RimeUserDir') } finally { $userKey.Dispose() }
      if ($configuredDir) { $userDir = [Environment]::ExpandEnvironmentVariables($configuredDir) }
    }
    $userDir = [IO.Path]::GetFullPath($userDir)
    $root = Find-Weasel
  }
  $backupDir = Join-Path ([IO.Path]::GetDirectoryName($userDir)) ('Rime-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
  New-Item -ItemType Directory -Path $userDir -Force | Out-Null
  $sourceDir = Join-Path $packageRoot 'config'
  Status '正在备份将要替换的配置…'
  foreach ($file in Get-ChildItem -LiteralPath $sourceDir -File -Recurse) {
    $relative = $file.FullName.Substring($sourceDir.Length + 1)
    $destination = Join-Path $userDir $relative
    if ($relative -eq 'custom_phrase.txt' -and (Test-Path -LiteralPath $destination)) { continue }
    if (Test-Path -LiteralPath $destination) {
      $backupFile = Join-Path $backupDir $relative
      New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backupFile)) -Force | Out-Null
      Copy-Item -LiteralPath $destination -Destination $backupFile
    }
  }
  # Personal dictionaries (*.userdb) are never bundled, replaced or deleted.
  if (-not $TestTarget -and -not $root) {
    Status '正在安装官方小狼毫；请允许 Windows 的管理员授权…'
    $process = Start-Process -FilePath (Join-Path $packageRoot 'weasel-0.17.4.0-installer.exe') -ArgumentList '/S' -Verb RunAs -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -notin @(0, 3010)) { throw "小狼毫安装失败，退出码：$($process.ExitCode)" }
    $root = Find-Weasel
    if (-not $root) { throw '未检测到小狼毫安装目录。' }
  }
  Status '正在应用雾凇拼音和圆角主题…'
  foreach ($file in Get-ChildItem -LiteralPath $sourceDir -File -Recurse) {
    $relative = $file.FullName.Substring($sourceDir.Length + 1)
    $destination = Join-Path $userDir $relative
    if ($relative -eq 'custom_phrase.txt' -and (Test-Path -LiteralPath $destination)) { continue }
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
  }
  if ($TestTarget) { Status "配置安装测试通过。备份：$backupDir"; exit 0 }
  Status '正在编译词库，通常需要几十秒…'
  $process = Start-Process -FilePath (Join-Path $root 'WeaselDeployer.exe') -ArgumentList '/deploy' -WindowStyle Hidden -PassThru -Wait
  if ($process.ExitCode -ne 0) { throw "部署失败，退出码：$($process.ExitCode)。原配置备份：$backupDir" }
  $buildDir = Join-Path $userDir 'build'
  foreach ($name in @('rime_ice.table.bin', 'melt_eng.table.bin', 'radical_pinyin.table.bin', 'rime_ice.schema.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $buildDir $name))) { throw "词库编译未完成：$name。备份：$backupDir" }
  }
  $builtDefaults = Get-Content -LiteralPath (Join-Path $buildDir 'default.yaml') -Raw
  if ($builtDefaults -notmatch 'schema: rime_ice' -or $builtDefaults -notmatch 'page_size: 9') { throw '部署后的方案配置不符合预期。' }
  if (-not (Get-Process -Name 'WeaselServer' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath (Join-Path $root 'WeaselServer.exe') -WindowStyle Hidden
  }
  Status '安装完成。按 Win＋空格切换到“小狼毫”即可使用。'
  exit 0
} catch {
  Status ('安装未完成：' + $_.Exception.Message)
  exit 1
}
