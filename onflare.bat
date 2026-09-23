@echo off
REM ==============================================================================
REM Raccourci Windows pour le déploiement sur CLOUDFLARE
REM ==============================================================================
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy\cloudflare\deploy-cloudflare.ps1" %*
endlocal
