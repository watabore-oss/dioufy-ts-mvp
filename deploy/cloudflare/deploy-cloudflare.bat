@echo off
REM ==============================================================================
REM Lanceur de Déploiement Cloudflare pour Windows (CMD / Double-clic)
REM ==============================================================================
setlocal
cd /d "%~dp0\..\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-cloudflare.ps1" %*
endlocal
