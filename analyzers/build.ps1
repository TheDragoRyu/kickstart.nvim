#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = Join-Path $scriptDir 'UnityAnalyzer\UnityAnalyzer.csproj'

dotnet build $proj -c Release | Out-Host

$dll = Join-Path $scriptDir 'UnityAnalyzer\bin\Release\netstandard2.0\UnityAnalyzer.dll'
if (-not (Test-Path $dll)) {
    throw "Build did not produce $dll"
}

$cacheRoot = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME '.local\share' }
$cacheDir = Join-Path $cacheRoot 'nvim-roslyn-analyzers'
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$dest = Join-Path $cacheDir 'UnityAnalyzer.dll'
Copy-Item -Force $dll $dest

Write-Host "Cached at $dest"
