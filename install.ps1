[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "OK: $Message" -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "AVISO: $Message" -ForegroundColor Yellow
}

function Fail {
    param([Parameter(Mandatory)][string]$Message)
    Write-Error $Message
    exit 1
}

function Show-Help {
    @"
Tools-hooks - Instalador para Windows

Uso:
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall

El instalador:
  - Localiza Git for Windows y Git Bash.
  - Configura los hooks globales de Git.
  - Instala wrappers (.cmd y bash) para:
      git-project-init
      git-project-check
      git-project-update
      git-release
  - Agrega %USERPROFILE%\.local\bin al PATH del usuario.

Opciones:
  -Uninstall  Revierte hooks globales y elimina wrappers instalados.
  -Help       Muestra esta ayuda.

Requisitos:
  - Windows 10 o Windows 11
  - Git for Windows
  - PowerShell 5.1 o superior
"@
}

if ($Help) {
    Show-Help
    exit 0
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$HooksDir = Join-Path $RepoRoot "git-hooks"
$ScriptsDir = Join-Path $RepoRoot "scripts"
$LibDir = Join-Path $ScriptsDir "lib"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$HooksGitPath = $HooksDir.Replace('\', '/')
$RepoGitPath = $RepoRoot.Replace('\', '/')

$Commands = @{
    "git-project-init"   = Join-Path $ScriptsDir "project-init.sh"
    "git-project-check"  = Join-Path $ScriptsDir "project-check.sh"
    "git-project-update" = Join-Path $ScriptsDir "project-update.sh"
    "git-release"        = Join-Path $ScriptsDir "release.sh"
}

$GitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $GitCommand) {
    Fail "No se encontro Git. Instala Git for Windows y vuelve a ejecutar el instalador."
}
$GitExe = $GitCommand.Source

if ($Uninstall) {
    Write-Step "Desinstalando Tools-hooks"

    $CurrentHooks = & $GitExe config --global --get core.hooksPath 2>$null
    $PreviousHooks = & $GitExe config --global --get tools-hooks.previous-hooks-path 2>$null

    if ($CurrentHooks -eq $HooksGitPath) {
        if ($PreviousHooks) {
            & $GitExe config --global core.hooksPath $PreviousHooks
            Write-Ok "Restaurado core.hooksPath anterior: $PreviousHooks"
        }
        else {
            & $GitExe config --global --unset core.hooksPath 2>$null
            Write-Ok "Eliminado core.hooksPath global."
        }
    }

    & $GitExe config --global --unset tools-hooks.root 2>$null
    & $GitExe config --global --unset tools-hooks.previous-hooks-path 2>$null

    foreach ($CommandName in $Commands.Keys) {
        $CmdPath = Join-Path $BinDir "$CommandName.cmd"
        $BashWrapperPath = Join-Path $BinDir $CommandName

        if (Test-Path -LiteralPath $CmdPath) {
            Remove-Item -LiteralPath $CmdPath -Force
            Write-Ok "Eliminado: $CmdPath"
        }
        if (Test-Path -LiteralPath $BashWrapperPath) {
            Remove-Item -LiteralPath $BashWrapperPath -Force
            Write-Ok "Eliminado: $BashWrapperPath"
        }
    }

    Write-Host "`nDesinstalacion completada." -ForegroundColor Green
    exit 0
}

Write-Step "Validando requisitos"

$GitRoot = Split-Path -Parent (Split-Path -Parent $GitExe)
$BashExe = Join-Path $GitRoot "bin\bash.exe"

if (-not (Test-Path -LiteralPath $BashExe -PathType Leaf)) {
    $BashCommand = Get-Command bash.exe -ErrorAction SilentlyContinue

    if ($BashCommand -and $BashCommand.Source -notmatch "\\Windows\\System32\\bash\.exe$") {
        $BashExe = $BashCommand.Source
    }
    else {
        Fail "No se encontro Git Bash. Reinstala Git for Windows incluyendo Git Bash."
    }
}

if (-not (Test-Path -LiteralPath $HooksDir -PathType Container)) {
    Fail "No existe la carpeta de hooks: $HooksDir"
}

$RequiredFiles = @(
    (Join-Path $HooksDir "prepare-commit-msg"),
    (Join-Path $HooksDir "commit-msg"),
    (Join-Path $HooksDir "pre-commit"),
    (Join-Path $HooksDir "pre-push"),
    (Join-Path $LibDir "common.sh"),
    (Join-Path $LibDir "generators.sh")
) + @($Commands.Values)

foreach ($FilePath in $RequiredFiles) {
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        Fail "No se encontro el archivo requerido: $FilePath"
    }

    & $BashExe -n $FilePath.Replace('\', '/')
    if ($LASTEXITCODE -ne 0) {
        Fail "El archivo contiene errores de sintaxis: $FilePath"
    }
}

Write-Ok "Git: $GitExe"
Write-Ok "Git Bash: $BashExe"

Write-Step "Configurando hooks globales"

$PreviousHooksPath = & $GitExe config --global --get core.hooksPath 2>$null
if ($PreviousHooksPath -and ($PreviousHooksPath -ne $HooksGitPath)) {
    Write-Warn "core.hooksPath ya apuntaba a: $PreviousHooksPath (respaldado en tools-hooks.previous-hooks-path)."
    & $GitExe config --global tools-hooks.previous-hooks-path $PreviousHooksPath
}

& $GitExe config --global core.hooksPath $HooksGitPath
if ($LASTEXITCODE -ne 0) {
    Fail "No fue posible configurar core.hooksPath."
}

& $GitExe config --global tools-hooks.root $RepoGitPath
if ($LASTEXITCODE -ne 0) {
    Fail "No fue posible configurar tools-hooks.root."
}

Write-Ok "core.hooksPath = $HooksGitPath"
Write-Ok "tools-hooks.root = $RepoGitPath"

Write-Step "Instalando comandos"

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($Entry in $Commands.GetEnumerator()) {
    $CommandName = $Entry.Key
    $ScriptPath = $Entry.Value.Replace('\', '/')
    $WrapperPath = Join-Path $BinDir "$CommandName.cmd"
    $BashWrapperPath = Join-Path $BinDir $CommandName

    $Wrapper = "@echo off`r`n`"$BashExe`" `"$ScriptPath`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    $BashWrapper = "#!/usr/bin/env bash`nexec bash `"$ScriptPath`" `"`$@`"`n"

    [System.IO.File]::WriteAllText($WrapperPath, $Wrapper, $Utf8NoBom)
    [System.IO.File]::WriteAllText($BashWrapperPath, $BashWrapper, $Utf8NoBom)
    Write-Ok "$CommandName -> $WrapperPath (y Bash wrapper LF)"
}

Write-Step "Configurando PATH"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$PathEntries = @()

if ($UserPath) {
    $PathEntries = $UserPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
}

$BinAlreadyPresent = $PathEntries | Where-Object {
    $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\')
}

if (-not $BinAlreadyPresent) {
    $CleanUserPath = if ($UserPath) { $UserPath.TrimEnd(';') } else { "" }
    $NewUserPath = if ([string]::IsNullOrWhiteSpace($CleanUserPath)) {
        $BinDir
    }
    else {
        "$CleanUserPath;$BinDir"
    }

    [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
    Write-Ok "Se agrego $BinDir al PATH del usuario."
}
else {
    Write-Ok "$BinDir ya estaba en el PATH del usuario."
}

if (($env:Path.Split(';') | ForEach-Object { $_.TrimEnd('\') }) -inotcontains $BinDir.TrimEnd('\')) {
    $env:Path = "$env:Path;$BinDir"
}

Write-Step "Verificando instalacion"

$ConfiguredHooks = & $GitExe config --global --get core.hooksPath
if ($LASTEXITCODE -ne 0 -or $ConfiguredHooks -ne $HooksGitPath) {
    Fail "La verificacion de core.hooksPath fallo."
}

$ConfiguredRoot = & $GitExe config --global --get tools-hooks.root
if ($LASTEXITCODE -ne 0 -or $ConfiguredRoot -ne $RepoGitPath) {
    Fail "La verificacion de tools-hooks.root fallo."
}

foreach ($CommandName in $Commands.Keys) {
    $WrapperPath = Join-Path $BinDir "$CommandName.cmd"
    $BashWrapperPath = Join-Path $BinDir $CommandName

    if (-not (Test-Path -LiteralPath $WrapperPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $BashWrapperPath -PathType Leaf)) {
        Fail "No se instalo correctamente $CommandName."
    }
}

Write-Host ""
Write-Host "Tools-hooks se instalo correctamente." -ForegroundColor Green
Write-Host ""
Write-Host "Cierra y abre PowerShell, Windows Terminal o CMD para recargar el PATH."
Write-Host ""
Write-Host "Prueba despues:"
Write-Host "  git-project-check"
Write-Host "  git-project-init --help"
Write-Host "  git-project-update --help"
Write-Host "  git-release --help"
Write-Host ""
Write-Host "Importante: no muevas ni elimines esta carpeta:"
Write-Host "  $RepoRoot"
Write-Host "Si la mueves, ejecuta nuevamente install.ps1."
