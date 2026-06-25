@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo === SETUP GIT (se necessario) ===
if not exist ".git" (
  git init
  git remote add origin https://github.com/sbotz17/commerciali.git
  git branch -M main
  echo Repository git inizializzato.
) else (
  echo Repository git già presente.
)

echo.
echo === GIT UPDATE ===
git add -A
git commit -m "Aggiornamento %date% %time%"
git push -u origin main

echo.
echo === COMPLETATO ===
pause
