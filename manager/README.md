# Peon Manager: Quellcode

Programm für Windows (bis 0.5.0 „Peon Client“). Ab 0.7.0 steckt die Auswertung im Manager-Modul **Peon Broker Client** (einschaltbar in der Ansicht „Module“): Es erfasst Auktionsdaten aus dem Spiel (über das Addon Peon_Bridge) und von AHledger, speichert sie in einer eigenen Datenbank, wertet sie aus und gibt Werte an Broker zurück. Ab 0.8.0 installiert und aktualisiert der Manager die Peon-Addons aus den GitHub Releases (Ansicht „Module“).

Design: `..\docs\konzepte\manager\Peon_Client_Design.md` (Funktionen) und `..\docs\konzepte\manager\Peon_GitHub_Design.md` (Peon Manager, Module, Peon_Bridge).

## Ordner

| Ordner | Inhalt |
|---|---|
| `electron\` | Hauptteil: Fenster, Infobereich, Dateiwächter, Zeitplan (`main.js`), Selbst-Update (`updater.js`), feste Befehlsliste für die Oberfläche (`preload.js`), Symbol |
| `src\core\` | Rechenkern ohne Electron: Manager (`service.js`), Liste der Manager-Module (`modules.js`), Modul Peon Broker Client (`broker-client.js`), Addons installieren (`addons.js`, `zip.js`), Lua-Leser, Datenbanken, Einleser Spiel und AHledger, Rückgabe `Data.lua`, Kennzahlen |
| `src\renderer\` | Oberfläche (Vue 3, ECharts, Schrift Barlow) |
| `test\` | Tests des Rechenkerns (`*.test.js`), echte WTF-Datei als Beispiel (`fixtures\`), Vergleich mit Brokers Lua-Code (`lua\`), Bildschirmfotos der Oberfläche (`ui\`) |

## Verbindung zum Spiel

- Liest `WTF\Account\<Konto>\SavedVariables\Peon_Bridge.lua` (`PeonBridgeDB.queue`).
- Schreibt `Interface\AddOns\Peon_Bridge\Data.lua` (`PeonBridgeData`, Format 2): `fmt`, `t`, `manager` (Version), `channels = { broker = true }`, `ack`, `markets`. Ohne `channels` zeichnet die Bridge nichts auf.

## Laufendes Programm

- Programm: mit dem Installer unter `%LOCALAPPDATA%\Programs\peon-manager\PeonManager.exe`. Läuft danach im Infobereich.
- Daten: `%APPDATA%\Peon Manager\Daten\` (`peon.db` für den Manager, `broker-client.db` für das Modul Peon Broker Client, `settings.json`, `logs\`, `backup\` mit alten Fassungen der Addons, `tmp\`). Liegt ein Ordner `DB` neben dem Programmordner, gilt dieser, und es gibt kein Selbst-Update.
- Anderer Datenordner: Umgebungsvariable `PEON_MANAGER_DB`. Anderes Release zum Testen: `PEON_MANAGER_RELEASES=http://127.0.0.1:<Port>` (gleiche Pfade wie GitHub).

## Bauen und Testen (Windows, Node 24)

```
npm ci
npm test                 # Rechenkern und Vergleich mit Broker (nutzt ..\tools\lua5.1.exe)
npm run shots            # Bildschirmfotos nach test\ui (braucht Chromium)
npm run dist             # Windows-Ordner nach release\win-unpacked
npm run dist:setup       # Installer nach release\ (mit latest.yml und Blockmap)
```

Selbsttest des echten Programms: `PEON_MANAGER_DB=<Ordner> PEON_MANAGER_SELFTEST=<Ausgabe>` setzen und `PeonManager.exe` (oder `electron .`) starten. **Immer mit eigener `settings.json` im Testordner, deren `wowDir` auf einen Test-WoW-Ordner zeigt.** Sonst sucht der Manager den echten WoW-Ordner und schreibt dort `Data.lua`. Es schreibt ein Bildschirmfoto und die Übersicht und beendet sich. Mit `PEON_MANAGER_SELFTEST_INSTALL=<Namen mit Komma>` installiert es vorher Addons, mit `PEON_MANAGER_SELFTEST_VIEW=<Ansicht>` fotografiert es diese Ansicht.

