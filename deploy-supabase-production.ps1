# ==============================================================================
# 🚀 DIOUFY-TS : SCRIPT DE DÉPLOIEMENT SUPABASE (EDGE FUNCTIONS & SECRETS)
# ==============================================================================

param(
    [string]$AccessToken = ""
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   DIOUFY-TS - DÉPLOIEMENT PRODUCTION SUPABASE           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Vérification du fichier .env
if (-not (Test-Path ".env")) {
    Write-Error "Fichier .env introuvable à la racine du projet."
    exit 1
}

# 2. Configuration du jeton d'accès Supabase CLI
if ($AccessToken) {
    $env:SUPABASE_ACCESS_TOKEN = $AccessToken
    Write-Host "-> Jeton d'accès Supabase fourni en paramètre." -ForegroundColor Green
} elseif (-not $env:SUPABASE_ACCESS_TOKEN) {
    $envToken = (Get-Content .env -ErrorAction SilentlyContinue | Where-Object { $_ -match '^SUPABASE_ACCESS_TOKEN\s*=\s*(.+)$' } | ForEach-Object { $matches[1].Trim() })
    if ($envToken) {
        $env:SUPABASE_ACCESS_TOKEN = $envToken
        Write-Host "-> Jeton d'accès chargé depuis .env (SUPABASE_ACCESS_TOKEN)." -ForegroundColor Green
    }
}

$projectRef = "yrarlatdoulyfyjpqzlp"
Write-Host "`n[1/3] Projet cible : $projectRef (DualsProd's Org / eu-west-3)" -ForegroundColor Yellow

# Diagnostic des droits Supabase CLI
$projectsOutput = supabase projects list 2>&1 | Out-String
if ($projectsOutput -notmatch $projectRef) {
    Write-Host "`n⚠️  ATTENTION : Compte Supabase non autorisé ou non connecté à DualsProd's Org !" -ForegroundColor Red
    Write-Host "La session active de la CLI Supabase n'a pas accès au projet $projectRef." -ForegroundColor Yellow
    Write-Host "Compte actuellement détecté par la CLI :" -ForegroundColor DarkYellow
    supabase orgs list
    Write-Host "`nPour résoudre l'erreur 403 Forbidden :" -ForegroundColor Cyan
    Write-Host "Option A (Recommandée) :" -ForegroundColor White
    Write-Host "   1. Exécutez : supabase login" -ForegroundColor White
    Write-Host "   2. Dans le navigateur, connectez-vous avec le compte propriétaire de 'DualsProd''s Org'." -ForegroundColor White
    Write-Host "Option B (Jeton personnel) :" -ForegroundColor White
    Write-Host "   1. Créez un token sur https://supabase.com/dashboard/account/tokens" -ForegroundColor White
    Write-Host "   2. Relancez : .\deploy-supabase-production.ps1 -AccessToken 'sbp_...'" -ForegroundColor White
    Write-Host "`nInterruption du déploiement pour éviter les échecs 403.`n" -ForegroundColor Red
    exit 1
}

# 3. Déploiement des Edge Functions
Write-Host "`n[2/3] Déploiement des Edge Functions sécurisées..." -ForegroundColor Yellow

Write-Host "-> Déploiement de flutterwave-webhook..." -ForegroundColor White
supabase functions deploy flutterwave-webhook --project-ref $projectRef --no-verify-jwt
if ($LASTEXITCODE -ne 0) {
    Write-Error "Échec du déploiement de flutterwave-webhook."
    exit $LASTEXITCODE
}

Write-Host "-> Déploiement de wave-webhook..." -ForegroundColor White
supabase functions deploy wave-webhook --project-ref $projectRef --no-verify-jwt
if ($LASTEXITCODE -ne 0) {
    Write-Error "Échec du déploiement de wave-webhook."
    exit $LASTEXITCODE
}

# 4. Synchronisation des Secrets Serveur
Write-Host "`n[3/3] Configuration des secrets serveurs..." -ForegroundColor Yellow

# Extraction des clés du fichier .env
$flwSecret = (Get-Content .env | Where-Object { $_ -match '^FLW_SECRET\s*=\s*(.+)$' } | ForEach-Object { $matches[1].Trim() })
$waveMerchant = (Get-Content .env | Where-Object { $_ -match '^WAVE_MERCHANT_NUMBER\s*=\s*(.+)$' } | ForEach-Object { $matches[1].Trim() })

if ($flwSecret) {
    Write-Host "-> Définition du secret FLW_SECRET..." -ForegroundColor White
    supabase secrets set FLW_SECRET="$flwSecret" --project-ref $projectRef
}

if ($waveMerchant) {
    Write-Host "-> Définition du secret WAVE_MERCHANT_NUMBER..." -ForegroundColor White
    supabase secrets set WAVE_MERCHANT_NUMBER="$waveMerchant" --project-ref $projectRef
}

Write-Host "`n✅ Procédure terminée avec succès." -ForegroundColor Green
Write-Host "IMPORTANT : Appliquez le script SQL ci-dessous dans l'éditeur SQL de votre Dashboard Supabase :" -ForegroundColor Magenta
Write-Host "supabase/migrations/20261003_p0_PRODUCTION_DEPLOYMENT_ALL_IN_ONE.sql" -ForegroundColor Cyan

