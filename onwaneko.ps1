<#
.SYNOPSIS
    Raccourci officiel pour le deploiement sur WANEKO (Wanekoo Hosting).
.DESCRIPTION
    Execute le script complet de deploiement Wanekoo situe dans deploy/waneko/deploy-waneko.ps1.
#>
$scriptPath = Join-Path $PSScriptRoot "deploy\waneko\deploy-waneko.ps1"
& $scriptPath @args
