[CmdletBinding()]
param(
    [switch]$Help
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

El instalador:
  - Localiza Git for Windows y Git Bash.
  - Configura los hooks globales de Git.
  - Instala wrappers para:
      git-project-init
      git-project-check
      git-release
  - Agrega %USERPROFILE%\.local\bin al PATH del usuario.

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
$BinDir = Join-Path $env:USERPROFILE ".local\bin"

$Commands = @{
    "git-project-init"  = Join-Path $ScriptsDir "project-init.sh"
    "git-project-check" = Join-Path $ScriptsDir "project-check.sh"
    "git-release"       = Join-Path $ScriptsDir "release.sh"
}

Write-Step "Validando requisitos"

$GitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $GitCommand) {
    Fail "No se encontró Git. Instala Git for Windows y vuelve a ejecutar el instalador."
}

$GitExe = $GitCommand.Source
$GitRoot = Split-Path -Parent (Split-Path -Parent $GitExe)
$BashExe = Join-Path $GitRoot "bin\bash.exe"

if (-not (Test-Path -LiteralPath $BashExe -PathType Leaf)) {
    $BashCommand = Get-Command bash.exe -ErrorAction SilentlyContinue

    if ($BashCommand -and $BashCommand.Source -notmatch "\\Windows\\System32\\bash\.exe$") {
        $BashExe = $BashCommand.Source
    }
    else {
        Fail "No se encontró Git Bash. Reinstala Git for Windows incluyendo Git Bash."
    }
}

if (-not (Test-Path -LiteralPath $HooksDir -PathType Container)) {
    Fail "No existe la carpeta de hooks: $HooksDir"
}

foreach ($Entry in $Commands.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $Entry.Value -PathType Leaf)) {
        Fail "No se encontró el script requerido: $($Entry.Value)"
    }
}

Write-Ok "Git: $GitExe"
Write-Ok "Git Bash: $BashExe"

Write-Step "Configurando hooks globales"

$HooksGitPath = $HooksDir.Replace('\', '/')
& $GitExe config --global core.hooksPath $HooksGitPath
$RepoGitPath = $RepoRoot.Replace('\', '/')
& $GitExe config --global tools-hooks.root $RepoGitPath

if ($LASTEXITCODE -ne 0) {
    Fail "No fue posible configurar core.hooksPath."
}

Write-Ok "core.hooksPath = $HooksGitPath"
Write-Ok "tools-hooks.root = $RepoGitPath"

Write-Step "Instalando comandos"

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

foreach ($Entry in $Commands.GetEnumerator()) {
    $CommandName = $Entry.Key
    $ScriptPath = $Entry.Value.Replace('\', '/')
    $WrapperPath = Join-Path $BinDir "$CommandName.cmd"

    $Wrapper = @"
@echo off
"$BashExe" "$ScriptPath" %*
exit /b %ERRORLEVEL%
"@

    Set-Content -LiteralPath $WrapperPath -Value $Wrapper -Encoding ASCII
    Write-Ok "$CommandName -> $WrapperPath"
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
    $NewUserPath = if ([string]::IsNullOrWhiteSpace($UserPath)) {
        $BinDir
    }
    else {
        "$UserPath;$BinDir"
    }

    [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
    Write-Ok "Se agregó $BinDir al PATH del usuario."
}
else {
    Write-Ok "$BinDir ya estaba en el PATH del usuario."
}

if (($env:Path.Split(';') | ForEach-Object { $_.TrimEnd('\') }) -inotcontains $BinDir.TrimEnd('\')) {
    $env:Path = "$env:Path;$BinDir"
}

Write-Step "Verificando instalación"

$ConfiguredHooks = & $GitExe config --global --get core.hooksPath
if ($LASTEXITCODE -ne 0 -or $ConfiguredHooks -ne $HooksGitPath) {
    Fail "La verificación de core.hooksPath falló."
}

foreach ($CommandName in $Commands.Keys) {
    $WrapperPath = Join-Path $BinDir "$CommandName.cmd"

    if (-not (Test-Path -LiteralPath $WrapperPath -PathType Leaf)) {
        Fail "No se instaló correctamente $CommandName."
    }
}

Write-Host ""
Write-Host "Tools-hooks se instaló correctamente." -ForegroundColor Green
Write-Host ""
Write-Host "Cierra y abre PowerShell, Windows Terminal o CMD para recargar el PATH."
Write-Host ""
Write-Host "Prueba después:"
Write-Host "  git-project-check"
Write-Host "  git-project-init --help"
Write-Host "  git-release --help"
Write-Host ""
Write-Host "Importante: no muevas ni elimines esta carpeta:"
Write-Host "  $RepoRoot"
Write-Host "Si la mueves, ejecuta nuevamente install.ps1."
