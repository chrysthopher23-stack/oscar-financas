@echo off
setlocal
cd /d "%~dp0"
title Oscar Financas - Previa leve no PC
if not exist "app\build\web\index.html" (
  echo A previa ainda nao foi compilada.
  echo Envie uma foto desta janela ao Codex.
  pause
  exit /b 1
)
node "tools\serve_web_preview.mjs"
if errorlevel 1 pause


