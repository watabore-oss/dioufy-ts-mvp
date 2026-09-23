<#
.SYNOPSIS
    Raccourci officiel pour le deploiement sur CLOUDFLARE (Pages & Workers).
.DESCRIPTION
    Execute le script complet de deploiement Cloudflare situe dans deploy/cloudflare/deploy-cloudflare.ps1.
#>
$scriptPath = Join-Path $PSScriptRoot "deploy\cloudflare\deploy-cloudflare.ps1"
& $scriptPath @args
