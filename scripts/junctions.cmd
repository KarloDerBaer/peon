@echo off
rem Peon: Junctions im AddOns-Ordner auf addons\ im Repo.
rem   junctions.cmd            Zustand zeigen (Doppelklick)
rem   junctions.cmd anlegen    fehlende Junctions anlegen (WoW muss geschlossen sein)
rem Anderer AddOns-Ordner: junctions.cmd status -AddOns "X:\...\Interface\AddOns"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0junctions.ps1" %*
set RC=%ERRORLEVEL%
if "%~1"=="" pause
exit /b %RC%
