# Peon Manager: Quellcode

Programm für Windows (bis 0.5.0 „Peon Client“). Ab 0.7.0 steckt die Auswertung im Manager-Modul **Peon Broker Client** (einschaltbar in der Ansicht „Module“): Es erfasst Auktionsdaten aus dem Spiel (über das Addon Peon_Bridge) und von AHledger, speichert sie in einer eigenen Datenbank, wertet sie aus und gibt Werte an Broker zurück. Installieren und Aktualisieren der Addons kommt mit Phase 2.

Design: `..\docs\konzepte\manager\Peon_Client_Design.md` (Funktionen) und `..\docs\konzepte\manager\Peon_GitHub_Design.md` (Peon Manager, Module, Peon_Bridge).

## Ordner

| Ordner | Inhalt |
|---|---|
| `electron\` | Hauptteil: Fenster, Infobereich, Dateiwächter, Zeitplan (`main.js`), feste Befehlsliste für die Oberfläche (`preload.js`), Symbol |
| `src\core\` | Rechenkern ohne Electron: Manager (`service.js`), Liste der Manager-Module (`modules.js`), Modul Peon Broker Client (`broker-client.js`), Lua-Leser, Datenbanken, Einleser Spiel und AHledger, Rückgabe `Data.lua`, Kennzahlen |
| `src\renderer\` | Oberfläche (Vue 3, ECharts, Schrift Barlow) |
| `test\` | Tests des Rechenkerns (`*.test.js`), echte WTF-Datei als Beispiel (`fixtures\`), Vergleich mit Brokers Lua-Code (`lua\`), Bildschirmfotos der Oberfläche (`ui\`) |

## Verbindung zum Spiel

- Liest `WTF\Account\<Konto>\SavedVariables\Peon_Bridge.lua` (`PeonBridgeDB.queue`).
- Schreibt `Interface\AddOns\Peon_Bridge\Data.lua` (`PeonBridgeData`, Format 2): `fmt`, `t`, `manager` (Version), `channels = { broker = true }`, `ack`, `markets`. Ohne `channels` zeichnet die Bridge nichts auf.

## Laufendes Programm (bei KarloDerBaer)

- Programm: `<Programmordner>\Runtime\PeonManager.exe` (Doppelklick). Läuft danach im Infobereich.
- Daten: `<Programmordner>\DB\` (`peon.db` für den Manager, `broker-client.db` für das Modul Peon Broker Client, `settings.json`, `logs\`). Der Datenordner liegt immer neben `Runtime`. Ein Update ersetzt nur `Runtime`.
- Anderer Datenordner: Umgebungsvariable `PEON_MANAGER_DB`.

## Bauen und Testen (Windows, Node 24)

```
npm ci
npm test                 # Rechenkern und Vergleich mit Broker (nutzt ..\tools\lua5.1.exe)
npm run shots            # Bildschirmfotos nach test\ui (braucht Chromium)
npm run dist             # Windows-Ordner nach release\win-unpacked
```

Selbsttest des echten Programms: `PEON_MANAGER_DB=<Ordner> PEON_MANAGER_SELFTEST=<Ausgabe>` setzen und `PeonManager.exe` (oder `electron .`) starten. Es schreibt ein Bildschirmfoto und die Übersicht und beendet sich.

Neue Version bei KarloDerBaer einspielen: Programm beenden, `release\win-unpacked` nach `<Programmordner>\Runtime_neu` kopieren, Prüfsummen vergleichen, alten Ordner umbenennen und `Runtime_neu` zu `Runtime` machen.
