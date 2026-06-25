@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo === SYNC BANDI ===
node scripts\sync-bandi-locale.js
if %errorlevel% neq 0 (
  echo ATTENZIONE: sync bandi fallita, continuo con git...
)

echo.
echo === GIT UPDATE ===
git add -A
git commit -m "Aggiornamento %date% %time%"
git push

echo.
echo === COMPLETATO ===
pause
