@echo off
REM ==============================================================================
REM Lanceur de Déploiement Wanekoo pour Windows (CMD / Double-clic)
REM ==============================================================================
setlocal
cd /d "%~dp0\..\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-waneko.ps1" %*
endlocal
