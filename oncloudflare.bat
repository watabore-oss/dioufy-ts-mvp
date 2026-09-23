@echo off
REM ==============================================================================
REM Raccourci Windows pour le d?ploiement sur Cloudflare Pages
REM ==============================================================================
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy\cloudflare\deploy-cloudflare.ps1" %*
endlocal
