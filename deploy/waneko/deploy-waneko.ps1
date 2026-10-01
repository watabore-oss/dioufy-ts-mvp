<#
.SYNOPSIS
    Script de deploiement officiel Dioufy-TS pour l'hebergeur WANEKOO (cPanel / FTP).
.DESCRIPTION
    1. Compile l'application Flutter Web en mode release.
    2. Injecte la configuration .htaccess (redirection SPA, HTTPS 301, cache HTTP).
    3. Mode Direct (par defaut) : Televerse tous les fichiers decompressés directement
       dans /public_html/ via FTP -> Le site est IMMEDIATEMENT EN LIGNE sans manipulation cPanel !
    4. Mode Archive (-UploadZipOnly) : Televerse l'archive .zip pour extraction manuelle dans cPanel.
    5. Mode Hors-Ligne (-OnlyZip) : Cree uniquement le .zip sans tenter de connexion FTP.
.PARAMETER SkipBuild
    Ignore l'etape de compilation si build/web est deja a jour.
.PARAMETER OnlyZip
    Genere uniquement l'archive de production sans tenter de televersement FTP.
.PARAMETER UploadZipOnly
    Televerse uniquement l'archive .zip (necessite d'extraire dans cPanel).
.PARAMETER FtpPassword
    Mot de passe FTP Wanekoo (si absent, cherche dans .env ou demande interactivement).
#>
param (
    [switch]$SkipBuild = $false,
    [switch]$OnlyZip = $false,
    [switch]$UploadZipOnly = $false,
    [string]$FtpPassword = ""
)

$ErrorActionPreference = "Stop"

function Log-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Log-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Log-Warning { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Log-Error   { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

# Fonction recursive pour s'assurer qu'une arborescence de dossiers existe sur le serveur FTP
function Ensure-FtpDirectory {
    param (
        [string]$BaseUri,
        [string]$RelativeDirPath,
        [System.Net.NetworkCredential]$Credentials
    )
    if ([string]::IsNullOrWhiteSpace($RelativeDirPath)) { return }
    $cleanPath = $RelativeDirPath.Trim("/").Replace("\", "/")
    $segments = $cleanPath.Split("/")
    $currentPath = ""
    foreach ($seg in $segments) {
        $currentPath = if ($currentPath) { "$currentPath/$seg" } else { $seg }
        $targetUri = "$BaseUri$currentPath/"
        try {
            $req = [System.Net.FtpWebRequest]::Create($targetUri)
            $req.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
            $req.Credentials = $Credentials
            $req.UsePassive = $true
            $req.UseBinary = $true
            $req.KeepAlive = $false
            $resp = $req.GetResponse()
            $resp.Close()
        } catch {
            # Erreur 550 / Le dossier existe deja, ce qui est attendu
        }
    }
}

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$BuildWebDir = Join-Path $ProjectRoot "build\web"
$ZipTarget   = Join-Path $ProjectRoot "dioufy-ts-production.zip"
$HtaccessSrc = Join-Path $PSScriptRoot ".htaccess"

Write-Host "=========================================================" -ForegroundColor Magenta
Write-Host "  DEPLOIEMENT WANEKOO (cPanel / FTP) • https://dioufy-ts.sn/ " -ForegroundColor Magenta
Write-Host "=========================================================" -ForegroundColor Magenta

# 1. Chargement des variables d'environnement (.env)
$EnvPath = Join-Path $ProjectRoot ".env"
$FtpHost = "fatma.wanekoohost.com"
$FtpUser = "dioufyt1"
$FtpPort = 21
$RemoteDir = "/public_html/"

if (Test-Path $EnvPath) {
    Get-Content $EnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $key = $parts[0].Trim()
            $val = $parts[1].Trim().Trim('"').Trim("'")
            if ($key -eq "WANEKO_FTP_HOST" -and $val) { $FtpHost = $val }
            if ($key -eq "WANEKO_FTP_USER" -and $val) { $FtpUser = $val }
            if ($key -eq "WANEKO_FTP_PASSWORD" -and $val -and -not $FtpPassword) { $FtpPassword = $val }
            if ($key -eq "WANEKO_REMOTE_DIR" -and $val) { $RemoteDir = $val }
        }
    }
}

# 2. Étape de compilation (Build)
if (-not $SkipBuild) {
    Log-Info "Lancement de la compilation Flutter Web..."
    $buildScript = Join-Path $ProjectRoot "deploy\common\build-web.ps1"
    & $buildScript -BaseHref "/"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Log-Error "La compilation a echoue. Arret du deploiement."
        exit 1
    }
} else {
    Log-Info "Compilation ignoree (-SkipBuild actif). Utilisation de : $BuildWebDir"
    if (-not (Test-Path (Join-Path $BuildWebDir "index.html"))) {
        Log-Error "Aucun build trouve dans $BuildWebDir. Veuillez relancer sans -SkipBuild."
        exit 1
    }
}

# 3. Injection du .htaccess pour Apache / cPanel
Log-Info "Injection de la configuration .htaccess (SPA, SSL, Compression, Cache)..."
if (Test-Path $HtaccessSrc) {
    Copy-Item -Path $HtaccessSrc -Destination (Join-Path $BuildWebDir ".htaccess") -Force
    Log-Success ".htaccess copie dans $BuildWebDir"
} else {
    Log-Warning "Fichier .htaccess source introuvable dans $PSScriptRoot."
}

# 4. Creation systematique de l'archive zip de secours
Log-Info "Creation de l'archive de production dioufy-ts-production.zip..."
if (Test-Path $ZipTarget) {
    Remove-Item $ZipTarget -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($BuildWebDir, $ZipTarget, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$zipItem = Get-Item $ZipTarget
$sizeMb = [Math]::Round($zipItem.Length / 1MB, 2)
Log-Success "Archive de production prete : $ZipTarget ($sizeMb Mo)"

# 5. Gestion des options de televersement
if ($OnlyZip) {
    Log-Info "Option -OnlyZip activee. Televersement FTP ignore."
    Log-Success "Archive prete : $ZipTarget"
    Write-Host ""
    Write-Host "Instructions manuelles cPanel Wanekoo :" -ForegroundColor Yellow
    Write-Host "1. Ouvrez https://my.wanekoo.com/login"
    Write-Host "2. cPanel > Gestionnaire de fichiers > public_html"
    Write-Host "3. Televersez '$ZipTarget' et cliquez sur 'Extraire'."
    Write-Host "4. Site actif sur : https://dioufy-ts.sn/"
    exit 0
}

# Demande du mot de passe FTP si absent
if (-not $FtpPassword -and [Environment]::UserInteractive) {
    Write-Host ""
    Write-Host "Televersement FTP Wanekoo ($FtpHost) pour le compte '$FtpUser'" -ForegroundColor Cyan
    Write-Host "Laissez vide et appuyez sur ENTREE pour ignorer le televersement automatique." -ForegroundColor Gray
    $inputPass = Read-Host "Mot de passe FTP cPanel"
    if ($inputPass) {
        $FtpPassword = $inputPass
    }
}

if (-not $FtpPassword) {
    Log-Info "Aucun mot de passe FTP specifie. Deploiement manuel :"
    Write-Host ""
    Write-Host "1. Ouvrez https://my.wanekoo.com/login" -ForegroundColor White
    Write-Host "2. cPanel > Gestionnaire de fichiers > public_html" -ForegroundColor White
    Write-Host "3. Televersez : $ZipTarget" -ForegroundColor White
    Write-Host "4. Cliquez droit > Extraire (Extract)" -ForegroundColor White
    Write-Host "5. Site actif sur : https://dioufy-ts.sn/" -ForegroundColor Green
    Write-Host ""
    Write-Host "Astuce : Vous pouvez definir WANEKO_FTP_PASSWORD dans le fichier .env pour un deploiement 100% automatique !" -ForegroundColor Cyan
    exit 0
}

$ftpBaseUri = "ftp://$FtpHost$RemoteDir"
$credentials = New-Object System.Net.NetworkCredential($FtpUser, $FtpPassword)

# MODE A : Televersement de l'archive ZIP uniquement
if ($UploadZipOnly) {
    Log-Info "Mode Archive (-UploadZipOnly) : Televersement de l'archive .zip..."
    try {
        $ftpUri = "$ftpBaseUri$([System.IO.Path]::GetFileName($ZipTarget))"
        $webClient = New-Object System.Net.WebClient
        $webClient.Credentials = $credentials
        $webClient.UploadFile($ftpUri, $ZipTarget)
        $webClient.Dispose()

        Log-Success "Archive televersee sur Wanekoo dans $RemoteDir !"
        Write-Host ""
        Write-Host "IMPORTANT : Connectez-vous sur cPanel pour extraire le fichier '$([System.IO.Path]::GetFileName($ZipTarget))'." -ForegroundColor Yellow
        Write-Host "URL : https://dioufy-ts.sn/" -ForegroundColor Green
    } catch {
        Log-Error "Echec du televersement FTP de l'archive : $($_.Exception.Message)"
    }
    exit 0
}

# MODE B : DEPLOIEMENT DIRECT DECOMPRESSE (100% AUTOMATIQUE & IMMEDIATEMENT EN LIGNE)
Log-Info "Mode Direct 100% Automatique : Televersement des fichiers decompressés dans $RemoteDir..."
Write-Host "-> Aucun besoin d'extraire dans cPanel : l'application sera directement en ligne !" -ForegroundColor Green

try {
    # 1. Lister tous les fichiers et dossiers (exclusion des fichiers temporaires/backups)
    $allItems = Get-ChildItem -Path $BuildWebDir -Recurse -Force
    $allFiles = $allItems | Where-Object { -not $_.PSIsContainer -and $_.Name -notmatch "_backup" }
    $allDirs  = $allItems | Where-Object { $_.PSIsContainer }

    $totalFiles = $allFiles.Count
    Log-Info "Preparation des dossiers distants sur Wanekoo ($($allDirs.Count) dossiers)..."

    # Creer les dossiers distants
    foreach ($d in $allDirs) {
        $relPath = $d.FullName.Substring($BuildWebDir.Length).TrimStart("\").Replace("\", "/")
        Ensure-FtpDirectory -BaseUri $ftpBaseUri -RelativeDirPath $relPath -Credentials $credentials
    }

    $hasCurl = (Get-Command curl.exe -ErrorAction SilentlyContinue) -ne $null
    if ($hasCurl) {
        Log-Info "Moteur de transfert : cURL haute performance (PASV, retries et protection cPanel)."
    }

    $fileIndex = 0
    foreach ($f in $allFiles) {
        $fileIndex++
        $relFilePath = $f.FullName.Substring($BuildWebDir.Length).TrimStart("\").Replace("\", "/")
        $targetFileUri = "$ftpBaseUri$relFilePath"

        Write-Host -NoNewline "`r[INFO] Envoi direct ($fileIndex/$totalFiles) : $relFilePath                    "
        
        $uploaded = $false
        $attempts = 0
        $maxAttempts = 3

        while (-not $uploaded -and $attempts -lt $maxAttempts) {
            $attempts++
            if ($hasCurl) {
                & curl.exe -s --disable-epsv --ftp-pasv --connect-timeout 25 --max-time 180 --retry 2 --retry-delay 3 --ftp-create-dirs -T "$($f.FullName)" --user "$($FtpUser):$($FtpPassword)" "$targetFileUri"
                if ($LASTEXITCODE -eq 0) {
                    $uploaded = $true
                } else {
                    Write-Host "`n[WARN] Tentative $attempts/$maxAttempts pour $relFilePath (Code curl: $LASTEXITCODE). Pause 3s..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                }
            } else {
                $parentDir = [System.IO.Path]::GetDirectoryName($relFilePath).Replace("\", "/")
                if ($parentDir) {
                    Ensure-FtpDirectory -BaseUri $ftpBaseUri -RelativeDirPath $parentDir -Credentials $credentials
                }
                $wc = New-Object System.Net.WebClient
                $wc.Credentials = $credentials
                try {
                    $wc.UploadFile($targetFileUri, $f.FullName)
                    $uploaded = $true
                } catch {
                    Write-Host "`n[WARN] Tentative $attempts/$maxAttempts : $($_.Exception.Message). Pause 3s..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                } finally {
                    $wc.Dispose()
                }
            }
        }

        if (-not $uploaded) {
            throw "Echec apres $maxAttempts tentatives lors du televersement de $relFilePath"
        }

        # Petite temporisation pour respecter les quotas de connexions FTP par seconde cPanel
        Start-Sleep -Milliseconds 250
    }
    Write-Host ""

    Log-Success "Tous les $totalFiles fichiers ont ete televerses avec succes !"
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "  🎉 APPLICATION DIRECTEMENT EN LIGNE SUR WANEKOO !     " -ForegroundColor Green
    Write-Host "  👉 URL : https://dioufy-ts.sn/                         " -ForegroundColor Green
    Write-Host "=========================================================" -ForegroundColor Green
} catch {
    Log-Error "Echec lors du televersement direct : $($_.Exception.Message)"
    Write-Warning "Vous pouvez basculer sur le mode archive : .\onwaneko -UploadZipOnly"
    Write-Warning "Ou televerser manuellement l'archive : $ZipTarget"
}
