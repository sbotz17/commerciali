@echo off
cd /d "%~dp0"

echo === SETUP GIT ===
if not exist ".git" (
    git init
    git remote add origin https://github.com/sbotz17/commerciali.git
    git branch -M main
    echo Repository inizializzato.
)

echo === GIT UPDATE ===
git add -A
git commit -m "Aggiornamento %date% %time%"
git push --force -u origin main

echo === COMPLETATO ===
pause
