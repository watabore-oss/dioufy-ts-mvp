<#
.SYNOPSIS
    Script centralise de compilation Flutter Web pour Dioufy-TS.
.DESCRIPTION
    Ce script compile l'application Flutter en version Web optimisee pour la production.
    Il verifie la presence du SDK Flutter, optimise le cache et prepare le repertoire build/web.
.PARAMETER BaseHref
    Chemin de base de l'application web. Par defaut: /.
.PARAMETER Clean
    Execute 'flutter clean' avant la compilation pour un build vierge.
#>
param (
    [string]$BaseHref = "/",
    [switch]$Clean = $false
)

$ErrorActionPreference = "Stop"

function Log-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Log-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Log-Warning { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Log-Error   { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  COMPILATION FLUTTER WEB - DIOUFY-TS PRODUCTION         " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# 1. Verification du SDK Flutter
Log-Info "Verification de l'environnement Flutter..."
try {
    $flutterCmd = Get-Command flutter -ErrorAction Stop
    Log-Success "Flutter detecte: $($flutterCmd.Source)"
} catch {
    Log-Error "Flutter n'a pas ete trouve dans le PATH systeme. Veuillez installer Flutter SDK."
    exit 1
}

Push-Location $ProjectRoot
try {
    # 2. Nettoyage optionnel
    if ($Clean) {
        Log-Info "Execution de 'flutter clean'..."
        flutter clean
        flutter pub get
    }

    # 3. Compilation Flutter Web
    Log-Info "Compilation de l'application en mode Release (BaseHref: $BaseHref)..."
    $buildArgs = @(
        "build",
        "web",
        "--release",
        "--base-href=$BaseHref",
        "--pwa-strategy=offline-first"
    )

    # Si le fichier .env existe, injecter les definitions
    $envFile = Join-Path $ProjectRoot ".env"
    if (Test-Path $envFile) {
        $buildArgs += "--dart-define-from-file=$envFile"
    }

    $process = Start-Process -FilePath "flutter" -ArgumentList $buildArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Log-Error "Echec de la compilation Flutter Web (Code sortie: $($process.ExitCode))."
        exit $process.ExitCode
    }

    $webDistPath = Join-Path $ProjectRoot "build\web"
    if (-not (Test-Path (Join-Path $webDistPath "index.html"))) {
        Log-Error "Le fichier 'index.html' n'a pas ete genere dans $webDistPath."
        exit 1
    }

    Log-Success "Compilation Flutter Web reussie avec succes dans : $webDistPath"
} finally {
    Pop-Location
}
