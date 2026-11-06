# Peon auf GitHub und Peon Manager: Design und Umsetzungsplan

Stand: 31.10.2026, **mit KarloDerBaer abgestimmt**. Ergänzt `Peon_Client_Design.md` (Peon Client wird zum Peon Manager mit dem Modul „Peon Broker Client“).

Dieses Dokument ist die Arbeitsgrundlage für die Umsetzung in **Claude Code**. Abschnitt 9 ist der Plan Schritt für Schritt.

## 1. Ziel

- Peon zum Release von WoW Forever (4./5. November 2026) ein paar Freunden zur Verfügung stellen.
- Der Code liegt in einem **öffentlichen GitHub-Repo**, Versionen kommen als **GitHub Releases**.
- Das Windows-Programm wird zum **Peon Manager**: Es installiert und aktualisiert die Peon-Addons von GitHub und sich selbst. Die bisherigen Funktionen des Peon Client (Auktionsdaten, Chancen, Rückgabe an Broker) werden das Manager-Modul **„Peon Broker Client“**, das man dazunehmen kann.
- Der Projektordner wird aufgeräumt und zum Git-Repo. Weiterentwickelt wird ab dann mit Claude Code direkt auf KarloDerBaers PC.

## 2. Entscheidungen (31.10.2026)

| Thema | Entscheidung |
|---|---|
| Repo | ein Repo für alles (Addons, Programm, Tests, Doku), **öffentlich** |
| Feedback | **kein Feedback über GitHub oder den Manager.** Peon_Feedback kommt nicht ins Repo und wird archiviert. Feedback geben die Freunde in einem eigenen Kanal auf KarloDerBaers Discord oder im Repo |
| Programm | heißt **Peon Manager**. Er installiert Addons und Manager-Module |
| Manager-Module | **Variante B:** Der Code steckt im Manager, ist aber standardmäßig aus. „Installieren“ schaltet ein Modul ein. Kein Nachladen von Code zur Laufzeit. Intern trotzdem sauber als eigenes Modul getrennt |
| Erstes Manager-Modul | **Peon Broker Client** (alle bisherigen Funktionen des Peon Client) |
| Addon Peon_Client | wird umbenannt in **Peon_Bridge**: allgemeine Verbindung zwischen Spiel und Manager. Inhalte melden sich als **Kanäle** an, der erste ist „broker“ |
| Bridge im Manager | gehört fest zum Manager und wird mit ihm installiert. Der Manager schaltet die Kanäle frei, die seine aktiven Module brauchen |
| Zeitplan | Aufräumen, Git, Repo, Umbenennung und ein erstes Release **vor dem Start**. Manager-Funktionen danach |
| Werkzeug | Umsetzung mit **Claude Code** auf KarloDerBaers PC |

## 3. Repo

### 3.1 Aufbau

Der Projektordner `<Repo>` wird das Repo:

```
<Repo>\
  addons\              Addon-Code, maßgeblich
    Peon\  Peon_Bags\  Peon_Broker\  Peon_Bridge\  Peon_ComboPoints\
    Peon_Fishing\  Peon_Ledger\  Peon_Mover\  Peon_Tooltip\
  manager\             Peon Manager (bisher client\)
  docs\
    README.md          Inhaltsverzeichnis der Doku
    projekt\           Peon_Ueberblick.md, Peon_Stand.md, Peon_Entscheidungen.md, Peon_Tests.md, Peon_Vorlage.md
    konzepte\          broker\, ledger\, manager\, tooltip\, mover\, bags\ (je Modul die Konzepte)
    changelog\         je Modul eine Datei mit dem Verlauf der Versionen (aus Peon_Stand.md)
    archiv\            abgelöste Konzepte (Peon_Broker_Programm.md, Peon_Broker_Buch.md)
  tests\               wie bisher, run_tests.sh / run_tests.cmd zeigen auf addons\
  tools\               lua5.1.exe, lua5.1-linux
  vorlage\             Peon_Beispiel
  scripts\             Bauen der Release-Pakete, Junctions anlegen
  .github\workflows\   Tests bei jeder Änderung, Release-Bau
  CLAUDE.md            Arbeitsregeln für Claude Code
  README.md            für Freunde: was ist Peon, Installation, Discord-Link
  LICENSE
  .gitignore
```

Nicht im Repo:
- `Peon_Bridge\Data.lua` (schreibt der Manager, wird nie ausgeliefert)
- `manager\node_modules\`, Bauordner (`dist\`, `release\`), Protokolle
- alles aus WTF und alle Daten des Managers
- `eingang\`, `Claude outputs\` (kommen ins Archiv, Abschnitt 8)

### 3.2 Repo als maßgebliche Quelle, Junctions zum Spiel

- **Maßgeblich ist ab jetzt `addons\` im Repo**, nicht mehr der AddOns-Ordner des Spiels.
- Im AddOns-Ordner wird jeder Peon-Ordner durch eine **Junction** ersetzt, die auf `addons\<Modul>` zeigt (`mklink /J`, braucht keine Administratorrechte). Änderungen im Repo sind damit sofort im Spiel, `/reload` genügt.
- WoW muss beim Anlegen der Junctions geschlossen sein. Vorher die Ordner im AddOns-Ordner mit `addons\` vergleichen (Prüfsummen), dann erst ersetzen.
- `Peon_Feedback` bleibt als normaler Ordner im AddOns-Ordner liegen, wenn KarloDerBaer es selbst weiter nutzen will. Es ist nicht Teil des Repos.
- Skript `scripts\junctions.cmd` legt die Junctions an und zeigt den Zustand. Der Manager erkennt Junctions später als **Entwicklermodus** und aktualisiert dort nichts (Abschnitt 5.4).

### 3.3 Doku im Repo

- Die Doku liegt maßgeblich im Repo unter `docs\`. **Die doppelte Pflege im Claude-Projekt endet** nach dem Umzug: Claude Code liest die Dateien direkt. Das Claude-Projekt bekommt eine kurze Notiz, wo die Doku jetzt liegt. Einzelne Dokumente kann KarloDerBaer bei Bedarf für Gespräche im Chat hochladen.
- **Peon_Stand.md wird aufgeteilt** (bisher 160 KB):
  - `docs\projekt\Peon_Stand.md` wird kurz: je Modul Version, Dateien, SavedVariables, Befehle, was im Spiel noch zu prüfen ist, dazu die offenen Punkte und die Prüfliste für den ersten Spieltag.
  - Der Verlauf der Versionen wandert nach `docs\changelog\<Modul>.md` (neueste oben). Daraus entstehen auch die Texte „Was ist neu“ im Release und im Manager.
- **CLAUDE.md** enthält die Arbeitsregeln (Abschnitt 9, Schritt A4) und verweist auf Überblick, Stand und Entscheidungen. Der Überblick bleibt die Wissenssammlung zu Forever und zur Kern-API.

### 3.4 Öffentlich: vor dem ersten Push prüfen

- Nach persönlichen Daten suchen und mit KarloDerBaer klären, was bleibt: Kontoname, Charakternamen, Mailadresse, Inhalte aus WTF in `tests\fixtures\wtf`.
- Git so einstellen, dass Commits die anonyme GitHub-Mailadresse benutzen (`…@users.noreply.github.com`).
- Lizenz mit KarloDerBaer festlegen (Vorschlag MIT). Ohne Lizenz darf niemand den Code weiterverwenden, ansehen und herunterladen geht trotzdem.

### 3.5 Git-Regeln

- Hauptzweig `main`, er ist immer lauffähig (alle Tests OK).
- Commit-Texte auf Deutsch, kurz, mit Modul und Version vorne, z. B. `Broker 0.33.0: Kanal broker über Peon_Bridge`.
- Ein Release entsteht über ein Tag (Abschnitt 6).

## 4. Peon_Bridge (bisher Peon_Client)

### 4.1 Umbenennung

| Was | Alt | Neu |
|---|---|---|
| Ordner, TOC | `Peon_Client` | `Peon_Bridge` |
| Titel in der Addonliste | Peon Client | `|cff8ccf4dPeon|r Bridge` |
| SavedVariables | `PeonClientDB` | `PeonBridgeDB` |
| Werte vom Manager | `PeonClientData` in `Data.lua` | `PeonBridgeData` in `Data.lua` |
| Modul-Schlüssel | `client` | `bridge` |
| Befehle | `/peon client …` | `/peon bridge …` |
| Datei, die der Manager liest | `WTF\…\SavedVariables\Peon_Client.lua` | `…\Peon_Bridge.lua` |

- **Keine Übernahme alter Daten nötig:** In `_forever_\WTF` gibt es noch keine Peon-Datei (geprüft 31.10.2026). Kein `oldDB`, kein alter Name in der TOC.
- Version: **Peon_Bridge 0.4.0** (setzt die Zählung von Peon_Client fort).
- Broker: an zwei Stellen `Peon:GetModule("client")` → `"bridge"` (`Data.lua` Zeile ~497, `Sales.lua` Zeile ~390), Texte „Client“ prüfen (z. B. „Üblich (Client, n Tage)“ darf so bleiben, gemeint ist der Manager mit dem Broker Client). Version **Broker 0.33.0**.
- Bereiche für Feedback (`Peon.SetFeedbackAreas`) bleiben, nur mit neuem Addon-Namen. Die Funktion im Kern bleibt (API wird nie geändert).
- Leerer Platzhalter `Data.lua` im Ordner der Bridge, wie bisher.

### 4.2 Kanäle

- Die Bridge ist nur der **Transport**: Warteschlange, Übergabe per Reload, Bestätigung durch den Manager (`ack`), Lesen von `Data.lua`, Optionsseite mit Stand.
- Inhalte melden sich als **Kanal** an. Der erste Kanal ist **`broker`**: der bisherige Export der Momentaufnahmen (`Export.lua`, Zuhörer über Brokers `AddSnapshotListener`) und das Lesen der Werte für Broker (`LongTerm`, `Sales`, Händlerpreis/Warenart über die Namen).
- **Der Manager schaltet die Kanäle frei:** In `Data.lua` steht `channels = { broker = true }`, wenn das Manager-Modul Peon Broker Client aktiv ist. Die Bridge zeichnet nur für freigeschaltete Kanäle auf. Ohne Eintrag (Platzhalter, kein Manager) zeichnet sie nichts auf und zeigt das auf ihrer Optionsseite an. So sammelt niemand ohne Broker Client Scans von mehreren MB in WTF.
- Ist ein Kanal nicht freigeschaltet, liefert die Bridge Broker auch keine Werte (Broker rechnet dann wie bisher selbst).
- Spätere Kanäle (z. B. Ledger) melden sich genauso an. Dafür bekommt die Bridge eine kleine Funktion zum Anmelden eines Kanals, intern im Addon. Die Kern-API von Peon bleibt unverändert.

### 4.3 Format von Data.lua (Manager → Spiel)

```lua
PeonBridgeData = {
  fmt = 2, t = 1793000000, manager = "0.6.0",
  channels = { broker = true },
  ack = { ["1793000000-1"] = true },
  markets = { ... },          -- wie bisher (Langzeit-Teil, Absatz), gehört zum Kanal broker
}
```

`fmt = 2` kennzeichnet das neue Format mit `channels`. Ein altes Format ohne `channels` gilt als „nichts freigeschaltet“.

## 5. Peon Manager

### 5.1 Umbenennung des Programms

- `client\` → `manager\`, `package.json`: Name `peon-manager`, `productName` „Peon Manager“, `appId` `de.peon.manager`, Programm `PeonManager.exe`, Symbol im Infobereich „Peon Manager“. Version **0.6.0** (setzt die Zählung fort).
- Liest `Peon_Bridge.lua`, schreibt `AddOns\Peon_Bridge\Data.lua` im neuen Format (4.3).
- Daten bei KarloDerBaer: weiter `<alter Programmordner>\DB` über die Einstellung „Datenordner“, bis der Installer kommt (Phase 3). Danach Standard-Datenordner des Programms und einmaliger Umzug.

### 5.2 Manager-Module (Variante B)

- Liste der Module im Code, je Modul: Schlüssel, Name, Beschreibung, nötige Addons, Kanäle, Ansichten, Hintergrund-Aufgaben.
- **Peon Broker Client** (`broker-client`): Einlesen der Momentaufnahmen, Datenbank, AHledger, Gegenstände, Gegenstand, Chancen, Quellen, Rückgabe an Broker. Braucht die Addons Peon_Broker und Peon_Bridge, Kanal `broker`.
- „Installieren“ schaltet ein: legt die Datenbank an, startet Dateiwächter und AHledger, zeigt die Ansichten, schreibt `channels.broker = true` und installiert fehlende Addons. „Entfernen“ schaltet aus, die Datenbank bleibt liegen (mit Hinweis und eigenem Knopf zum Löschen).
- Bei KarloDerBaer ist der Broker Client nach dem Umbau gleich aktiv (vorhandene Datenbank).

### 5.3 Ansicht „Module“

- Zwei Gruppen: **Addons** (Peon und alle Module) und **Manager-Module**.
- Je Eintrag: Name, Beschreibung, installierte und verfügbare Version, „Was ist neu“ (aus dem Manifest), Knöpfe Installieren, Aktualisieren, Entfernen. Oben „Alle aktualisieren“ und „Nach Updates suchen“.
- Abhängigkeiten werden automatisch mit installiert (Peon immer, Peon_Bridge immer mit dem Manager).
- Link „Feedback und Fehler“ zu KarloDerBaers Discord-Kanal (Adresse in den Einstellungen des Repos bzw. im Manifest, nicht fest im Code).
- Kanal **Stabil** (Standard) oder **Test** (Vorabversionen) in den Einstellungen.

### 5.4 Installieren und Aktualisieren der Addons

1. Manifest holen: `https://github.com/<Besitzer>/<Repo>/releases/latest/download/manifest.json` (zählt nicht gegen die Grenze der GitHub-Schnittstelle). Für den Kanal Test über die Liste der Releases (Schnittstelle, 60 Abfragen je Stunde ohne Anmeldung, mit Zwischenspeicher und ETag).
2. Zip je geändertem Addon laden, **Prüfsumme (SHA-256) gegen das Manifest** prüfen.
3. In einen Zwischenordner entpacken, Inhalt prüfen (genau ein Ordner mit dem Namen des Addons und seiner TOC).
4. Alten Ordner nach `…\Peon Manager\backup\<Addon>-<Version>` verschieben, neuen an seine Stelle, **jede Datei nach dem Tausch prüfen** (Windows hat bei KarloDerBaer schon Schreiben verweigert). Bei Fehler zurücktauschen.
5. `Peon_Bridge\Data.lua` bleibt immer erhalten. Fehlt sie, legt der Manager den Platzhalter an.
6. Fremde Addons und SavedVariables werden nie angefasst. „Entfernen“ löscht nur den Addon-Ordner (mit Rückfrage), die Einstellungen in WTF bleiben.
7. Läuft WoW, weist der Manager darauf hin, dass danach `/reload` nötig ist. Programmname von Forever beim Bau prüfen (Ordner `_forever_`).
8. **Entwicklermodus:** Ist ein Addon-Ordner eine Junction, zeigt der Manager „Entwicklung (Repo)“ und aktualisiert ihn nie.

### 5.5 Erster Start bei Freunden

- WoW-Ordner suchen: übliche Orte von Battle.net (z. B. `C:\Program Files (x86)\World of Warcraft\_forever_`, andere Laufwerke) und die Windows-Registrierung, sonst fragen.
- Ansicht Module öffnen mit Vorschlag: Peon, Peon_Bridge und alle Module außer Broker Client vorausgewählt (Freunde wählen ab, was sie nicht wollen). Peon Broker Client als Angebot mit kurzer Erklärung.
- Texte nur auf Deutsch.

### 5.6 Selbst-Update des Managers

- Bau mit **electron-builder**: Installer (NSIS) für den Benutzer, ohne Administratorrechte.
- **electron-updater** mit GitHub Releases als Quelle, lädt nur geänderte Teile (Blockmap), fragt vor dem Neustart.
- Nicht signiert: Windows SmartScreen warnt beim ersten Start („Weitere Informationen“ → „Trotzdem ausführen“). In der README beschreiben.

## 6. Releases

### 6.1 Ein Paket-Release je Ausgabe

- Tag `vJJJJ.MM.TT` (z. B. `v2026.11.04`), bei mehreren am Tag `v2026.11.04.2`. Vorabversion (Kanal Test) mit Zusatz `-test` und als „Pre-release“ markiert.
- Inhalt: je Addon ein Zip `Peon_Broker-0.33.0.zip` (darin der Ordner `Peon_Broker\`, ohne `Data.lua`, ohne Tests), das Manifest, ab Phase 3 der Installer des Managers und `latest.yml` für electron-updater.
- Versionen der Module bleiben eigenständig (SemVer wie bisher). Ein Modul, das sich nicht geändert hat, behält seine Version und dasselbe Zip.

### 6.2 manifest.json

```json
{
  "fmt": 1,
  "release": "v2026.11.04",
  "date": "2026-11-04",
  "discord": "https://discord.gg/…",
  "manager": { "version": "0.6.0", "minVersion": "0.6.0" },
  "addons": [
    { "name": "Peon_Broker", "title": "Broker", "version": "0.33.0",
      "desc": "Auktionshaus-Helfer", "deps": ["Peon"], "api": 8, "interface": 16001,
      "file": "Peon_Broker-0.33.0.zip", "sha256": "…", "size": 123456,
      "notes": "Was ist neu …", "managerOnly": false }
  ],
  "managerModules": [
    { "key": "broker-client", "title": "Peon Broker Client", "needs": ["Peon_Broker", "Peon_Bridge"] }
  ]
}
```

- `deps` aus `## Dependencies`, `api` = mindestens nötige Kern-API, `interface` aus der TOC, `notes` aus `docs\changelog\<Modul>.md` (Einträge seit dem letzten Release).
- `Peon_Bridge` hat `managerOnly: true` (wird nur mit dem Manager angeboten).

### 6.3 Bauen

- `scripts\build_release` (Node-Skript, läuft unter Windows und auf GitHub): liest die TOC-Dateien, packt die Zips, rechnet Prüfsummen, schreibt das Manifest.
- **GitHub Actions:**
  - `tests.yml`: bei jedem Push alle Lua-Tests auf Linux (`tools/lua5.1-linux`, `PEON_ADDONS=addons`) und die Tests des Managers (Node).
  - `release.yml`: bei einem Tag `v*` Tests, dann Zips und Manifest bauen, ab Phase 3 den Manager auf einem Windows-Rechner von GitHub bauen, alles an das Release hängen.
- Für das erste Release vor dem Start genügt das Skript lokal plus `gh release create`.

## 7. Arbeitsweise mit Claude Code

- Claude Code läuft auf KarloDerBaers PC im Repo. Zusätzliche Ordner beim Start freigeben: `<WoW-Ordner>` (AddOns, WTF) und `<alter Programmordner>`.
- Kein Übertragen, keine Prüfsummen-Kontrolle nach dem Übertragen und keine Pakete nach `eingang\` mehr. Die Regeln dafür im Überblick gelten nur noch für das Archiv.
- Tests unter Windows mit `tests\run_tests.cmd` (bzw. Git Bash mit `run_tests.sh`), beide zeigen auf `addons\` im Repo.
- Der Manager wird direkt unter Windows gebaut und gestartet (`npm run …`).
- Issues und Releases mit `gh`.

## 8. Aufräumen

| Was | Wohin |
|---|---|
| 19 Dokumente im Hauptordner | `docs\` nach 3.1 |
| `client\` | `manager\` |
| Addon-Ordner aus `_forever_\Interface\AddOns` | Kopie nach `addons\`, dann Junctions (3.2) |
| `Peon_Feedback` und `tests\test_feedback.lua`, `tests\test_feedback_kern.lua` | `<Archiv>\Peon_Feedback_0.2.0\` (Ordner im AddOns-Ordner darf bleiben, nicht im Repo) |
| `eingang\` (233 MB alte Lieferungen) | `<Archiv>\eingang\` |
| `Claude outputs\` | `<Archiv>\` |
| `<alter Programmordner>\Runtime_0.1.0` bis `Runtime_0.4.0`, `_neu` | löschen (je rund 320 MB), vorher KarloDerBaer fragen |
| `<alter Programmordner>\DB_beta` | bleibt |
| Peon_Broker_Programm.md, Peon_Broker_Buch.md | `docs\archiv\` |

## 9. Umsetzungsplan

Jeder Schritt endet mit einer **Abnahme**. Was mit „KarloDerBaer fragen“ markiert ist, vorher kurz abstimmen. Nach jedem Schritt mit Code: Version in der TOC erhöhen, `docs\changelog\` und `Peon_Stand.md` pflegen, Tests grün, Commit.

### Phase 1: vor dem Start (bis 3. November)

**A. Einrichten**
1. Prüfen, was auf dem PC da ist: Git for Windows, Node.js (Version passend zum Manager), GitHub CLI `gh`. Fehlendes mit KarloDerBaer installieren (z. B. über `winget`).
2. `gh auth login` mit KarloDerBaers GitHub-Konto. Git-Name und anonyme GitHub-Mailadresse setzen.
3. Vor jeder Änderung Ausgangsstand sichern: Zip von `<Repo>` und von allen Peon-Ordnern in `AddOns` nach `<Archiv>\Sicherung_2026-10-31\`.
4. `CLAUDE.md` anlegen mit den Arbeitsregeln:
   - Antworten und Texte auf Deutsch, verständlich, ohne unnötigen Fachjargon. In allen Texten möglichst keine Gedankenstriche und Semikolons.
   - Vor größeren Entscheidungen kurz mit KarloDerBaer abstimmen. Ideen für neue Funktionen gibt KarloDerBaer einzeln vor, erst nach Zustimmung in `Peon_Stand.md`.
   - Neue Module als `Peon_<Name>` mit Abhängigkeit zu Peon aus `vorlage\Peon_Beispiel`. Kern-API nur erweitern, nie ändern.
   - Vor jedem Commit alle Tests. Nach jeder Arbeit Version in der TOC erhöhen, Changelog und `Peon_Stand.md` und bei Bedarf `Peon_Entscheidungen.md` aktualisieren.
   - Im Addon-Ordner nur Addon-Code. Wissen zu Forever und Kern-API steht in `docs\projekt\Peon_Ueberblick.md`, zu Beginn lesen.
   - Junctions: Code nur in `addons\` ändern.
   
   **Abnahme:** Werkzeuge da, `gh auth status` OK, Sicherung vorhanden.

**B. Repo aufbauen (lokal)**
1. `git init` in `<Repo>`, `.gitignore` nach 3.1.
2. Addon-Ordner aus `_forever_\Interface\AddOns` (alle Peon-Module außer Peon_Feedback) nach `addons\` kopieren, Prüfsummen vergleichen.
3. Aufräumen nach Abschnitt 8 (Runtimes erst nach Rückfrage löschen).
4. Doku nach `docs\` verschieben, `docs\README.md` als Inhaltsverzeichnis. Verweise in den Dokumenten auf die neuen Pfade anpassen (Überblick „Wo alles liegt“, Arbeitsweise).
5. `Peon_Stand.md` aufteilen (3.3): Verlauf je Modul nach `docs\changelog\`, Stand kurz. Nichts verlieren: am Ende prüfen, dass jeder Versionseintrag in einem Changelog steht.
6. `tests\run_tests.sh` und `run_tests.cmd`: Standard-Ordner `addons\` im Repo (weiter überschreibbar mit `PEON_ADDONS`). Feedback-Tests entfernen. `tests\README.md` anpassen.
7. Alle Tests laufen lassen.
8. Erster Commit.

   **Abnahme:** alle Tests OK auf `addons\`, `git status` sauber, Projektordner nach 3.1.

**C. Junctions**
1. WoW schließen lassen (KarloDerBaer).
2. Ordner im AddOns-Ordner per Prüfsumme gegen `addons\` vergleichen. Erst wenn gleich: Ordner nach `Peon_Archiv\Sicherung_…` verschieben und Junction anlegen (`scripts\junctions.cmd`).
3. KarloDerBaer startet WoW: Addonliste zeigt alle Peon-Module, keine LUA_WARNING, `/peon list`.

   **Abnahme:** Spiel lädt die Addons aus dem Repo.

**D. Peon_Bridge und Manager-Name**
1. Peon_Client → Peon_Bridge nach 4.1 (Ordner, TOC, Variablen, Schlüssel, Befehle, Texte), Kanäle nach 4.2, Format 4.3. Version 0.4.0.
2. Broker auf `bridge` umstellen. Version 0.33.0.
3. `test_client.lua` → `test_bridge.lua`, zusätzlich: ohne Freischaltung keine Aufzeichnung und keine Werte für Broker, mit Freischaltung wie bisher.
4. Programm: `client\` ist schon `manager\`. Umbenennen nach 5.1, liest `Peon_Bridge.lua`, schreibt `Data.lua` im Format 4.3 mit `channels.broker = true`. Tests des Programms anpassen und laufen lassen.
5. Programm unter Windows bauen, KarloDerBaer startet es (Datenordner `<alter Programmordner>\DB`), alter Ordner `Runtime` bleibt als Sicherung. Neuer Ort: `<Programmordner>\Runtime` (KarloDerBaer fragen, ob umziehen oder Ordner behalten).
6. Junction für `Peon_Bridge` anlegen, alte Junction `Peon_Client` entfernen. WoW neu starten.
7. Doku: Überblick, Stand, Changelog, Entscheidungen, Client-Design (Hinweis auf Peon Manager und Bridge).

   **Abnahme:** Tests OK. Im Spiel: Optionsseite der Bridge zeigt „Kanal broker freigeschaltet“ (nach dem ersten Schreiben der Data.lua durch den Manager). Komplettscan und Übergabe erst nach dem Start prüfbar (Prüfliste erster Spieltag, mit neuen Namen).

**E. GitHub**
1. Prüfung nach 3.4 mit KarloDerBaer (persönliche Daten, Lizenz). Repo-Name mit KarloDerBaer festlegen (Vorschlag `peon`).
2. `README.md` für Freunde: was Peon ist, Liste der Module, Installation per Zip (bis der Manager fertig ist), Hinweis auf den Discord-Kanal für Feedback (Adresse von KarloDerBaer).
3. Öffentliches Repo anlegen (`gh repo create`), Push.
4. `tests.yml` anlegen, Lauf auf GitHub grün.

   **Abnahme:** Repo öffentlich erreichbar, Tests auf GitHub grün.

**F. Erstes Release**
1. `scripts\build_release` nach 6.3 (Zips und Manifest), lokal testen: Zip entpacken, Inhalt prüfen, kein `Data.lua`, Prüfsummen stimmen.
2. Changelog-Auszüge als Text des Release.
3. `gh release create v2026.11.04 …` (oder am Tag des Starts). Peon_Bridge ist im ersten Release **nicht** enthalten, weil es ohne Manager nichts tut (`managerOnly`).

   **Abnahme:** Freunde können die Zips laden und von Hand installieren.

### Phase 2: nach der ersten Woche nach dem Start

Vorher hat die Prüfliste für den ersten Spieltag Vorrang (`Peon_Stand.md`).

**G. Manager-Module (5.2)**: Liste der Module, Broker Client als abschaltbares Modul, Seitenleiste je nach aktiven Modulen, `channels` je nach Modul. Tests.
**H. Ansicht „Module“ und Installieren (5.3, 5.4)**: Manifest lesen, Installieren, Aktualisieren, Entfernen, Sicherung und Zurücktauschen, Entwicklermodus, Warnung bei laufendem WoW. Tests mit einem nachgebauten Release (lokaler Server oder Dateien). Erster Start (5.5).

**Abnahme:** Auf einem zweiten WoW-Ordner (Testordner) installiert der Manager alle Addons aus dem echten Release und aktualisiert eins.

### Phase 3: Installer und Selbst-Update

**I.** electron-builder mit NSIS, electron-updater (5.6), `release.yml` baut den Manager auf GitHub. Umzug von KarloDerBaers Daten in den Standard-Datenordner (mit Rückfrage). README um Installation des Managers und SmartScreen ergänzen.

**Abnahme:** Freund installiert den Manager aus dem Release, eine neue Version kommt automatisch.

## 10. Offene Punkte für die Umsetzung

- Repo-Name, Lizenz, Umgang mit Charakternamen in der Doku (Schritt E1).
- Adresse des Discord-Kanals (Schritt E2).
- Programmname von WoW Forever für die Erkennung „WoW läuft“ (Phase 2).
- Ort des Programms bei KarloDerBaer: `<alter Programmordner>` behalten oder `<Programmordner>` (Schritt D5).
