@echo off
rem Peon - alle Tests unter Windows ausfuehren (Doppelklick genuegt).
rem Nutzt tools\lua5.1.exe und startet im Ordner addons\ des Repos, weil die Tests die Addons relativ laden.
rem Anderer Addon-Ordner: Umgebungsvariable PEON_ADDONS setzen.
setlocal
set "LUA=%~dp0..\tools\lua5.1.exe"
if defined PEON_ADDONS (set "ADDONS=%PEON_ADDONS%") else (set "ADDONS=%~dp0..\addons")
if not defined PEON_WTF set "PEON_WTF=%~dp0fixtures\wtf"
set FAIL=
pushd "%ADDONS%" || (echo Addon-Ordner nicht gefunden: %ADDONS% & pause & exit /b 1)
for %%t in ("%~dp0test*.lua") do (
    echo.
    echo ===== %%~nxt
    "%LUA%" "%%~ft" || set FAIL=1
)
popd
echo.
if defined FAIL (echo *** MINDESTENS EIN TEST FEHLGESCHLAGEN ***) else (echo *** ALLE TESTDATEIEN OK ***)
if "%~1"=="" pause
if defined FAIL exit /b 1
