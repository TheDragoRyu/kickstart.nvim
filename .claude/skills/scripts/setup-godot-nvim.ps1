[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProjectPath,

  [string]$NvimServer = '',
  [string]$NvimExe = 'nvim',
  [switch]$SkipGodotSettings,
  [switch]$SkipDotnetSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsWindows {
  return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Normalize-PathForGodot([string]$Path) {
  return ($Path -replace '\\', '/')
}

function Quote-GodotString([string]$Value) {
  $escaped = (Normalize-PathForGodot $Value) -replace '"', '\"'
  return '"' + $escaped + '"'
}

function Resolve-ProjectRoot([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Project path does not exist: $Path"
  }

  $item = Get-Item -LiteralPath $Path
  if (-not $item.PSIsContainer) {
    if ($item.Name -ne 'project.godot') {
      throw "Expected a Godot project directory or project.godot file: $Path"
    }
    return $item.Directory.FullName
  }

  $projectFile = Join-Path $item.FullName 'project.godot'
  if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "Not a Godot project root; missing project.godot: $($item.FullName)"
  }

  return $item.FullName
}

function Get-NvimCommand([string]$CommandOrPath) {
  if (Test-Path -LiteralPath $CommandOrPath -PathType Leaf) {
    return (Get-Item -LiteralPath $CommandOrPath).FullName
  }

  $cmd = Get-Command $CommandOrPath -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  Write-Warning "Could not find '$CommandOrPath' on PATH. The wrapper will still use that command name."
  return $CommandOrPath
}

function Get-DefaultNvimServer {
  if (Test-IsWindows) {
    return '\\.\pipe\nvim-unity'
  }

  $runtime = $env:XDG_RUNTIME_DIR
  if ([string]::IsNullOrWhiteSpace($runtime)) {
    $runtime = '/tmp'
  }
  return (Join-Path $runtime 'nvim-unity.sock')
}

function Get-GodotSettingsFile {
  $roots = @()

  if ($env:APPDATA) {
    $roots += (Join-Path $env:APPDATA 'Godot')
  }
  if ($env:XDG_CONFIG_HOME) {
    $roots += (Join-Path $env:XDG_CONFIG_HOME 'godot')
  }
  if ($env:HOME) {
    $roots += (Join-Path $env:HOME '.config/godot')
  }

  $files = foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root) {
      Get-ChildItem -LiteralPath $root -Filter 'editor_settings-*.tres' -File -ErrorAction SilentlyContinue
    }
  }

  return $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Set-SettingLine {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Key,
    [string]$Value,
    [System.Collections.Generic.List[string]]$Changes
  )

  $line = "$Key = $Value"
  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match $pattern) {
      if ($Lines[$i] -ne $line) {
        $Lines[$i] = $line
        $Changes.Add($Key)
      }
      return
    }
  }

  $Lines.Add($line)
  $Changes.Add($Key)
}

function Write-TextUtf8NoBom([string]$Path, [string]$Text) {
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Ensure-GitInfoExclude([string]$ProjectRoot, [string]$GeneratedPath) {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    return @{ Status = 'skipped'; Detail = 'git not found' }
  }

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $repoRoot = (& git -C $ProjectRoot rev-parse --show-toplevel 2>$null)
  $gitExitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldErrorActionPreference

  if ($gitExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    return @{ Status = 'skipped'; Detail = 'not a git repo' }
  }

  $repoRoot = $repoRoot.Trim()
  $repoRootFull = [System.IO.Path]::GetFullPath($repoRoot)
  if (-not $repoRootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $repoRootFull += [System.IO.Path]::DirectorySeparatorChar
  }
  $repoUri = [Uri]$repoRootFull
  $generatedUri = [Uri]([System.IO.Path]::GetFullPath($GeneratedPath))
  $relative = [Uri]::UnescapeDataString($repoUri.MakeRelativeUri($generatedUri).ToString())
  $excludePath = Join-Path $repoRoot '.git/info/exclude'
  $existing = @()
  if (Test-Path -LiteralPath $excludePath) {
    $existing = Get-Content -LiteralPath $excludePath
  }

  if ($existing -contains $relative) {
    return @{ Status = 'present'; Detail = $relative }
  }

  Add-Content -LiteralPath $excludePath -Value $relative
  return @{ Status = 'added'; Detail = $relative }
}

$projectRoot = Resolve-ProjectRoot $ProjectPath
$projectFile = Join-Path $projectRoot 'project.godot'

if ([string]::IsNullOrWhiteSpace($NvimServer)) {
  $NvimServer = Get-DefaultNvimServer
}

$nvimCommand = Get-NvimCommand $NvimExe
$wrapperName = if (Test-IsWindows) { '.godot-nvim-open.cmd' } else { '.godot-nvim-open.sh' }
$wrapperPath = Join-Path $projectRoot $wrapperName

if (Test-IsWindows) {
  $wrapper = @"
@echo off
setlocal
set "NVIM_SERVER=$NvimServer"
set "NVIM_EXE=$nvimCommand"
set "FILE=%~1"
set "LINE=%~2"
set "COL=%~3"
if "%LINE%"=="" set "LINE=1"
if "%LINE%"=="-1" set "LINE=1"
if "%COL%"=="" set "COL=1"
if "%COL%"=="-1" set "COL=1"
"%NVIM_EXE%" --server "%NVIM_SERVER%" --remote-silent "%FILE%" >nul 2>nul
if errorlevel 1 (
  "%NVIM_EXE%" "%FILE%"
  exit /b %ERRORLEVEL%
)
"%NVIM_EXE%" --server "%NVIM_SERVER%" --remote-send "<C-\><C-N>:call cursor(%LINE%,%COL%)<CR>zz" >nul 2>nul
exit /b 0
"@
} else {
  $wrapper = @"
#!/usr/bin/env sh
NVIM_SERVER='$NvimServer'
NVIM_EXE='$nvimCommand'
FILE="`$1"
LINE="`${2:-1}"
COL="`${3:-1}"
[ "`$LINE" = "-1" ] && LINE=1
[ "`$COL" = "-1" ] && COL=1
"`$NVIM_EXE" --server "`$NVIM_SERVER" --remote-silent "`$FILE" >/dev/null 2>&1 || {
  "`$NVIM_EXE" "`$FILE"
  exit `$?
}
"`$NVIM_EXE" --server "`$NVIM_SERVER" --remote-send "<C-\><C-N>:call cursor(`$LINE,`$COL)<CR>zz" >/dev/null 2>&1
"@
}

$wrapperStatus = if (Test-Path -LiteralPath $wrapperPath) { 'updated' } else { 'created' }
Write-TextUtf8NoBom $wrapperPath ($wrapper -replace "`r?`n", [Environment]::NewLine)

if (-not (Test-IsWindows)) {
  $chmod = Get-Command chmod -ErrorAction SilentlyContinue
  if ($chmod) {
    & chmod +x $wrapperPath
  }
}

$settingsSummary = 'skipped'
$settingsFilePath = $null
$settingsBackupPath = $null
$settingsChanges = [System.Collections.Generic.List[string]]::new()

if (-not $SkipGodotSettings) {
  $settingsFile = Get-GodotSettingsFile
  if (-not $settingsFile) {
    Write-Warning "No Godot editor_settings-*.tres file found. Open Godot once, then rerun this script."
    $settingsSummary = 'not found'
  } else {
    $settingsFilePath = $settingsFile.FullName
    $settingsBackupPath = "$settingsFilePath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item -LiteralPath $settingsFilePath -Destination $settingsBackupPath

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -LiteralPath $settingsFilePath)) {
      $lines.Add($line)
    }

    $quotedWrapper = Quote-GodotString $wrapperPath
    $quotedArgs = Quote-GodotString '"{file}" {line} {col}'

    Set-SettingLine $lines 'text_editor/external/use_external_editor' 'true' $settingsChanges
    Set-SettingLine $lines 'text_editor/external/exec_path' $quotedWrapper $settingsChanges
    Set-SettingLine $lines 'text_editor/external/exec_flags' $quotedArgs $settingsChanges
    Set-SettingLine $lines 'text_editor/behavior/files/auto_reload_scripts_on_external_change' 'true' $settingsChanges

    if (-not $SkipDotnetSettings) {
      Set-SettingLine $lines 'dotnet/editor/external_editor' '6' $settingsChanges
      Set-SettingLine $lines 'dotnet/editor/custom_exec_path' $quotedWrapper $settingsChanges
      Set-SettingLine $lines 'dotnet/editor/custom_exec_path_args' $quotedArgs $settingsChanges
    }

    if ($settingsChanges.Count -gt 0) {
      Write-TextUtf8NoBom $settingsFilePath (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
      $settingsSummary = 'updated'
    } else {
      Remove-Item -LiteralPath $settingsBackupPath -Force
      $settingsBackupPath = $null
      $settingsSummary = 'already current'
    }
  }
}

$excludeResult = Ensure-GitInfoExclude $projectRoot $wrapperPath

$slnCount = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.sln' -File -ErrorAction SilentlyContinue).Count
$csprojCount = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.csproj' -File -ErrorAction SilentlyContinue).Count
$hasCSharpProject = $slnCount -gt 0 -or $csprojCount -gt 0

Write-Host ''
Write-Host 'Godot Neovim setup complete.'
Write-Host "Project: $projectRoot"
Write-Host "Project file: $projectFile"
Write-Host "Neovim server: $NvimServer"
Write-Host "Wrapper: $wrapperPath ($wrapperStatus)"
Write-Host "Godot settings: $settingsSummary"
if ($settingsFilePath) {
  Write-Host "Godot settings file: $settingsFilePath"
}
if ($settingsBackupPath) {
  Write-Host "Godot settings backup: $settingsBackupPath"
}
if ($settingsChanges.Count -gt 0) {
  Write-Host ('Changed settings: ' + (($settingsChanges | Sort-Object -Unique) -join ', '))
}
Write-Host "Git exclude: $($excludeResult.Status) - $($excludeResult.Detail)"

if (-not $hasCSharpProject) {
  Write-Warning 'No .sln or .csproj found at the project root. For C#, open the project in Godot .NET and create/regenerate the C# solution.'
}

Write-Host 'Keep Neovim running before opening files from Godot. Restart Godot if it was open while settings were changed.'
