<#
.SYNOPSIS
    Script de deploiement officiel Dioufy-TS pour Cloudflare (Pages & Worker Proxy).
.DESCRIPTION
    1. Compile l'application Flutter Web en mode release.
    2. Injecte les regles SPA '_redirects' et les en-tetes de cache/securite '_headers'.
    3. Deploie l'application statique sur Cloudflare Pages via Wrangler.
    4. Propose ou execute le deploiement du Cloudflare Worker d'authentification (si -DeployWorker).
.PARAMETER SkipBuild
    Ignore l'etape de compilation si build/web est deja a jour.
.PARAMETER ProjectName
    Nom du projet Cloudflare Pages (par defaut: dioufy-ts).
.PARAMETER Branch
    Branche Git de production Cloudflare (par defaut: main).
.PARAMETER DeployWorker
    Deploie egalement le Cloudflare Worker Reverse Proxy Supabase Auth.
.PARAMETER ApiToken
    Token API Cloudflare (si non specifie, extrait de .env).
.PARAMETER AccountId
    Account ID Cloudflare (si non specifie, extrait de .env).
#>
param (
    [switch]$SkipBuild = $false,
    [string]$ProjectName = "dioufy-ts",
    [string]$Branch = "main",
    [switch]$DeployWorker = $false,
    [string]$ApiToken = "",
    [string]$AccountId = ""
)

$ErrorActionPreference = "Stop"

function Log-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Log-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Log-Warning { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Log-Error   { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

$ProjectRoot   = (Resolve-Path "$PSScriptRoot\..\..").Path
$BuildWebDir   = Join-Path $ProjectRoot "build\web"
$RedirectsSrc  = Join-Path $PSScriptRoot "_redirects"
$HeadersSrc    = Join-Path $PSScriptRoot "_headers"

Write-Host "=========================================================" -ForegroundColor Yellow
Write-Host "  DEPLOIEMENT CLOUDFLARE • PAGES & WORKERS               " -ForegroundColor Yellow
Write-Host "=========================================================" -ForegroundColor Yellow

# 1. Chargement des identifiants Cloudflare depuis .env
$EnvPath = Join-Path $ProjectRoot ".env"
$defaultAccountId = $env:CLOUDFLARE_ACCOUNT_ID
$defaultToken     = $env:CLOUDFLARE_API_TOKEN

if (Test-Path $EnvPath) {
    Get-Content $EnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $key = $parts[0].Trim()
            $val = $parts[1].Trim().Trim('"').Trim("'")
            if ($key -eq "CLOUDFLARE_ACCOUNT_ID" -and $val -and -not $AccountId) { $AccountId = $val }
            if ($key -eq "CLOUDFLARE_API_TOKEN" -and $val -and -not $ApiToken)   { $ApiToken = $val }
            if ($key -eq "CLOUDFLARE_PROJECT_NAME" -and $val)                    { $ProjectName = $val }
        }
    }
}

if (-not $AccountId) { $AccountId = $defaultAccountId }
if (-not $ApiToken)   { $ApiToken = $defaultToken }

$env:CLOUDFLARE_ACCOUNT_ID = $AccountId
$env:CLOUDFLARE_API_TOKEN  = $ApiToken

Log-Info "Compte Cloudflare : $AccountId"
Log-Info "Projet Pages      : $ProjectName"

# 2. Étape de compilation (Build)
if (-not $SkipBuild) {
    Log-Info "Lancement de la compilation Flutter Web..."
    $buildScript = Join-Path $ProjectRoot "deploy\common\build-web.ps1"
    & $buildScript -BaseHref "/"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Log-Error "La compilation a echoue. Arret du deploiement Cloudflare."
        exit 1
    }
} else {
    Log-Info "Compilation ignoree (-SkipBuild actif). Utilisation de : $BuildWebDir"
    if (-not (Test-Path (Join-Path $BuildWebDir "index.html"))) {
        Log-Error "Aucun build trouve dans $BuildWebDir. Veuillez relancer sans -SkipBuild."
        exit 1
    }
}

# 3. Injection des règles Cloudflare (_redirects & _headers)
Log-Info "Injection de la configuration Cloudflare Pages (_redirects & _headers)..."
if (Test-Path $RedirectsSrc) {
    Copy-Item -Path $RedirectsSrc -Destination (Join-Path $BuildWebDir "_redirects") -Force
    Log-Success "_redirects copie dans $BuildWebDir"
}

if (Test-Path $HeadersSrc) {
    Copy-Item -Path $HeadersSrc -Destination (Join-Path $BuildWebDir "_headers") -Force
    Log-Success "_headers copie dans $BuildWebDir"
}

# 4. Déploiement Cloudflare Pages via Wrangler
Log-Info "Deploiement sur Cloudflare Pages via Wrangler..."
Push-Location $ProjectRoot
try {
    $wranglerCmd = "npx --yes wrangler pages deploy build/web --project-name=$ProjectName --branch=$Branch --commit-dirty=true"
    Write-Host "> $wranglerCmd" -ForegroundColor Gray
    cmd.exe /c "$wranglerCmd"

    if ($LASTEXITCODE -ne 0) {
        Log-Error "Erreur lors du deploiement Cloudflare Pages (Code sortie: $LASTEXITCODE)."
        exit $LASTEXITCODE
    }

    Log-Success "Deploiement Cloudflare Pages reussi !"
    Write-Host ""
    Write-Host "Application en ligne sur : https://$ProjectName.pages.dev" -ForegroundColor Green
} finally {
    Pop-Location
}

# 5. Déploiement optionnel du Cloudflare Worker Auth Proxy
if ($DeployWorker) {
    Log-Info "Deploiement du Cloudflare Worker Reverse Proxy (auth.dioufy-ts.sn)..."
    Push-Location $ProjectRoot
    try {
        $workerCmd = "npx --yes wrangler deploy cloudflare/worker_auth_proxy.js --name=auth-dioufy-ts-proxy --compatibility-date=2024-09-23"
        Write-Host "> $workerCmd" -ForegroundColor Gray
        cmd.exe /c "$workerCmd"
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Worker Reverse Proxy d'authentification deploye avec succes !"
        } else {
            Log-Warning "Attention : Le deploiement du Worker a retourne le code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Deploiement Cloudflare termine avec succes !" -ForegroundColor Green
