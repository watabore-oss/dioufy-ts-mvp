@echo off
REM ==============================================================================
REM Raccourci Windows pour le déploiement sur WANECO
REM ==============================================================================
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy\waneko\deploy-waneko.ps1" %*
endlocal
