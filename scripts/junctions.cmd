@echo off
rem Peon: Addons im AddOns-Ordner zwischen Manager und Entwicklung umschalten.
rem   junctions.cmd                       Zustand zeigen (Doppelklick)
rem   junctions.cmd manager [Module]      echte Ordner, der Peon Manager aktualisiert sie (WoW geschlossen)
rem   junctions.cmd entwicklung [Module]  Junctions auf addons\ im Repo (WoW geschlossen)
rem   junctions.cmd anlegen               fehlende Junctions anlegen, nur bei gleichem Inhalt (WoW geschlossen)
rem Anderer AddOns-Ordner: junctions.cmd status -AddOns "X:\...\Interface\AddOns"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0junctions.ps1" %*
set RC=%ERRORLEVEL%
if "%~1"=="" pause
exit /b %RC%
