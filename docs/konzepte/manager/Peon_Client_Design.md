# Peon Client: Design

Stand: 22.10.2026, **mit KarloDerBaer abgestimmt**. Löst den Entwurf `Peon_Broker_Programm.md` (30.09.2026) ab. Ergänzt `Peon_Broker_Rechenmodell.md` und `Peon_Broker_Absatz.md`.

**Hinweis 31.10.2026:** Das Programm heißt jetzt **Peon Manager** (ab 0.6.0), seine bisherigen Funktionen werden das Manager-Modul **Peon Broker Client**. Das Modul Peon_Client heißt jetzt **Peon_Bridge** (ab 0.4.0) mit Kanälen, `Data.lua` hat Format 2 (`PeonBridgeData`, `channels`). Siehe `Peon_GitHub_Design.md`. Die Namen in diesem Dokument bleiben wie beim Entwurf.

## 1. Zweck

Der **Peon Client** ist ein Programm für Windows. Seine Hauptaufgaben:

1. **Auktionsdaten erfassen:** Momentaufnahmen aus eigenen Scans und Live-Abfragen (über das neue Modul Peon_Client im Spiel), dazu externe Quellen: AHledger und später die Blizzard-API.
2. **Speichern:** alles dauerhaft in einer eigenen Datenbank, Aufbewahrung einstellbar.
3. **Auswerten:** Verlauf, Muster, Ranglisten und Chancen in einer schönen, übersichtlichen Oberfläche.
4. **Schnittstelle zu Broker:** Der Client liefert Preisbereiche zurück ins Spiel. Broker nutzt sie vorrangig, solange sie frisch sind.

Aufgabenteilung:

| | Im Spiel (Broker, Peon_Client) | Peon Client (PC) |
|---|---|---|
| Aufgabe | Handeln: verkaufen, kaufen, eigene Auktionen, schnelle Übersicht | Langzeitdaten erfassen, speichern, auswerten |
| Daten | eigene Scans und Live-Abfragen | alle Momentaufnahmen, AHledger, später Blizzard-API |
| Zeigt | Tooltip, Broker-Reiter | Übersicht, Verlauf mit Diagrammen, Ranglisten, Chancen |
| Liefert | Momentaufnahmen | Preisbereiche je Gegenstand, Empfangsbestätigung |

Nicht in Stufe 1: Auswertung der Ledger-Daten (Buch, Verkaufsquote, Kosten), Berufe, Blizzard-API. Der Aufbau lässt das später zu.

## 2. Grundsätze

Aus dem Entwurf vom 30.09.2026 übernommen und weiter gültig:

- **Broker funktioniert ohne Client voll.** Die Werte des Clients machen die Einschätzung nur besser.
- **Austausch nur über Dateien.** Das Spiel schreibt seine Daten bei Reload, Ausloggen oder Beenden in WTF. Der Client schreibt eine Lua-Datei, die das Spiel beim Start oder Reload lädt. Kein Kopieren und Einfügen.
- Der Client greift **nie ins laufende Spiel** ein. Er liest WTF nur und schreibt nur seine eigene Datei im Ordner von Peon_Client.
- **Märkte bleiben getrennt** (Regelsatz und Fraktion, dazu neu die Region).
- **Quellen sind austauschbar.** Jede Quelle hat einen eigenen Einleser, dahinter ist alles gleich.
- Datenverlust in der Beta ist nicht schlimm.

Neu:

- **Jede Beobachtung trägt ihre Quelle und ihre Art** (Momentaufnahme oder Fremdmessung, Abschnitt 5). Was wofür zählt, ist je Zweck festgelegt.
- **Externe Daten werden erst nach einer Prüfung eingerechnet** (Abschnitt 5.6).
- Daten von AHledger werden immer mit **Quellenangabe und Link** gezeigt und nie als eigener Scan ausgegeben (Bedingung von AHledger).

## 3. Technik

| Teil | Wahl | Grund |
|---|---|---|
| Programm | **Electron** (Windows, 64 Bit) | Oberfläche in HTML/CSS/JavaScript, alles in einer Sprache, hier vollständig testbar, sehr verbreitet |
| Oberfläche | **Vue 3** mit Vite | Vorlagen sehen aus wie HTML, gut lesbar, viele Bausteine |
| Diagramme | **ECharts** | Linien, Bänder, Balken, Wärmebilder, Zoom, dunkles Thema |
| Datenbank | **SQLite** (`node:sqlite`, Rückfall `better-sqlite3`) | eine Datei, schnell, keine Installation. Welche der beiden, entscheidet ein Test in C2 |
| Lua lesen | eigener kleiner Leser | WTF-Dateien sind Lua-Tabellen. Nur Tabellen, Texte, Zahlen, Wahrheitswerte, sonst nichts wird ausgeführt |
| Tests | Node-Testlauf (Vitest) und Playwright | Rechenkern und Oberfläche hier in der Cloud testbar, Lua-Teil wie bisher mit lua5.1 |

**Sicherheit (Electron):** Die Oberfläche hat keinen Zugriff auf Node (`contextIsolation`, `sandbox`, kein `nodeIntegration`). Sie spricht nur über eine feste Liste von Befehlen mit dem Hauptteil. Sie lädt keine fremden Seiten (strenge Inhaltsregel, nur eigene Dateien). Alle Netzzugriffe (AHledger, später Blizzard) macht nur der Hauptteil.

**Ordner:**

| Was | Wo |
|---|---|
| Quellcode | `<Repo>\client\` |
| Fertiges Programm | `<alter Programmordner>\Runtime\` (darin `PeonClient.exe`) |
| Datenbank, Protokolle, Einstellungen | `<alter Programmordner>\DB\` |
| WoW (wird gelesen) | `<WoW-Ordner>\` (ab 25.10.2026, vorher `_classic_beta_`, in den Einstellungen änderbar) |

Ein Update ersetzt nur `Runtime`. Die Datenbank bleibt.

**Bauen und Ausliefern:** In der Cloud gebaut (Windows-Ordner ohne Installer), als `.tgz` mit `PRUEFSUMMEN.md5` nach `eingang\`, auf dem PC nach `Runtime` entpackt und geprüft, wie bei den Addons.

## 4. Aufbau

```
WTF\...\Peon_Client.lua ──► Einleser „Spiel“ ──┐
api.ahledger.com        ──► Einleser „AHledger“ ┼──► Datenbank ──► Auswertung ──► Oberfläche
(später) Blizzard-API   ──► Einleser „Blizzard“ ┘                     │
                                                                       ▼
                                   AddOns\Peon_Client\Data.lua ◄── Schreiber „Rückgabe“
```

- **Hauptteil (main):** Dateiwächter, Einleser, Datenbank, Auswertung, Schreiber, Zeitplan für AHledger, Symbol im Infobereich.
- **Oberfläche (renderer):** Vue-Anwendung, holt Daten über die feste Befehlsliste.
- Lange Arbeiten (Einlesen, Verdichten) laufen in einem eigenen Arbeitsfaden, damit die Oberfläche nie stockt.

## 5. Datenquellen und Qualität

### 5.1 Zwei Arten von Beobachtungen

| Art | Bedeutung | Quellen |
|---|---|---|
| **Momentaufnahme** | Genau so stand es zu diesem Zeitpunkt im Auktionshaus | eigener Komplettscan, eigene Live-Abfrage, Blizzard-API |
| **Fremdmessung** | Werte aus Scans anderer Spieler, zusammengeführt. Vollständigkeit und genauer Zeitpunkt nicht sicher | AHledger |

### 5.2 Eigene Komplettscans

Kommen über Peon_Client aus dem Spiel (Abschnitt 6). Alle Angebote im Blizzard-Format, völlig gleiche Angebote zusammengezählt. Keine Auktionsnummer, kein Verkäufer (liefert das Spiel beim Scan nicht).

### 5.3 Eigene Live-Abfragen

Einzelne Gegenstände (Radar, Verkaufen, Einkaufsliste, Meine Auktionen). Mit Auktionsnummer und Restzeit. Momentaufnahme nur für diesen einen Gegenstand. Teil-Ergebnisse (`HasFull…SearchResults` = falsch) werden als unvollständig markiert und zählen nicht für Median und Menge.

### 5.4 AHledger

- Öffentliche Schnittstelle `https://api.ahledger.com`, ohne Schlüssel, 300 Abfragen pro Minute, Antworten zwischengespeichert (1 bis 15 Min.).
- Genutzt werden:
  - `/v1/markets` (Liste der Märkte),
  - `/v1/pricetable/{markt}` (alle Gegenstände: Median, Min, Menge, Median 7 und 30 Tage, Tief und Hoch 30 Tage, Absatz je Tag, mit ETag, also nur bei Änderung neu geladen),
  - `/v1/prices/{markt}/{itemID}?range=…` (Verlauf eines Gegenstands, beim Öffnen im Client),
  - `/v1/items/{itemID}?game=forever` (Name, Qualität, Art, Händlerpreis, Symbolname).
- Abruf der Preistabelle alle 30 Min. (einstellbar), solange der Client läuft.
- **Bedingungen:** AHledger mit Link nennen, wo die Daten erscheinen. Nicht als eigenen Scan ausgeben, nicht weiterverkaufen. Der Client zeigt deshalb bei jeder AHledger-Zahl die Quelle „AHledger“ mit Link.
- **Märkte:** AHledger kennt keine Realms, sondern Regelsatz, Fraktion, Region (z. B. `forever.normal.alliance.eu`). Der Client ordnet jeden Broker-Markt einem AHledger-Markt zu. Vorschlag automatisch, Bestätigung in den Einstellungen. Für die Beta vermutlich `forever.normal.alliance.us` (wird in C5 geprüft).
- AHledger kennt nur Nummern. Gegenstände mit Zusatz („… des Wolfs“) lassen sich daraus nicht je Variante trennen und bekommen keine AHledger-Werte.

### 5.5 Blizzard-API (später)

- Liefert für Forever bisher keine Auktionsdaten. Eine geplante Aufgabe prüft das täglich.
- Format, an dem sich auch unser Export orientiert: je Auktionshaus eine Momentaufnahme pro Stunde, jedes Angebot einzeln mit `id`, `item` (`id`, Zusätze über `bonus_lists`), `quantity`, `unit_price` (Massenware) bzw. `buyout` und `bid` (Einzelgegenstände), `time_left` (`SHORT`, `MEDIUM`, `LONG`, `VERY_LONG`).
- Braucht einen eigenen Zugang bei Blizzard (Entwicklerkonto, Schlüssel). Der Einleser ist im Aufbau vorgesehen, wird aber erst gebaut, wenn es Daten gibt.

### 5.6 Was wofür zählt

| Zweck | Momentaufnahmen | AHledger |
|---|---|---|
| „Jetzt“-Werte (Min, Menge, Angebote) | ja | nur zum Vergleich daneben |
| Verlauf, üblicher Bereich, Richtwert | ja | nach Freigabe: für Gegenstände und Zeiten ohne eigene Daten |
| Absatz | ja (aus Vergleichen, wie Broker) | nur zum Vergleich |
| Ranglisten und Chancen | ja | nach Freigabe als Hinweis |
| Rückgabe an Broker | ja | nach Freigabe, mit Kennzeichnung der Quelle |

**Bis zur Freigabe wird AHledger nur angezeigt, nie eingerechnet.**

**Quellenprüfung (Bauabschnitt C5):** Eine Woche lang werden die eigenen Scans Zeitpunkt für Zeitpunkt mit AHledger verglichen. Geprüft wird:
- Ist AHledgers „neuester Wert“ ein einzelner Scan oder zusammengeführt? Wie alt ist er im Vergleich zu unseren Scans?
- Wie weit weichen Min, Median und Menge ab (gleicher Zeitpunkt plus/minus 15 Min.)? Für Massenware und Einzelgegenstände getrennt.
- Wie vollständig ist AHledger (Anteil unserer Gegenstände, die dort vorkommen)?
- Passt AHledgers Absatz je Tag zu unserem?

Ergebnis ist ein kurzer Bericht mit einer Vertrauensstufe je Zweck. Die Freigabe stimmen wir danach ab.

**Zeitfenster:** Laut AHledger startet Forever am 4. November (EU am 5. November, 0 Uhr). Die Beta ist seit 22.10.2026 offline, die Prüfung läuft deshalb nach dem Start auf dem EU-Markt (Abschnitt 11).

### 5.7 Broker-Verlauf (ab 22.10.2026)

- Brokers Tages- und Wochenwerte je Gegenstand (`PeonBrokerDB.markets[…].items[…].d` und `.w`, Summen von Min, Median, Menge und Anzahl Scans je Tag) werden als eigene Quelle übernommen. Art: Momentaufnahme, aber als **Mittel der Scans eines Tages** (nicht ein einzelner Zeitpunkt), deshalb eigens gekennzeichnet.
- Gibt dem Verlauf Tiefe vor dem ersten Scan des Clients (Beta ab Ende September). Liegen für einen Tag eigene Momentaufnahmen vor, gelten diese.

## 6. Datenaustausch mit dem Spiel

### 6.1 Neues Modul Peon_Client (im Spiel)

- Eigenes Addon `Peon_Client` mit `## Dependencies: Peon`, `## OptionalDeps: Peon_Broker`, ausgehend von `vorlage\Peon_Beispiel`.
- SavedVariables `PeonClientDB` (accountweit). Brokers Datei bleibt dadurch klein.
- Aufgaben:
  - nimmt von Broker die Momentaufnahmen entgegen (Komplettscan und Live-Abfragen) und legt sie in eine **Warteschlange** (Standard 10 Komplettscans, einstellbar 1 bis 30, danach fällt der älteste weg, Live-Abfragen höchstens 500),
  - löscht beim Start alles, was der Client bestätigt hat,
  - lädt die Werte des Clients aus `Data.lua` und gibt sie über eine Schnittstelle an Broker,
  - zeigt nach einem Komplettscan dezent den Knopf **„An Client übergeben“** neben Brokers Scan-Knopf (löst einen Reload aus, das Auktionshaus schließt dabei). Sonst geht alles beim Ausloggen raus.
  - Optionsseite: Warteschlange, Knopf anbieten an/aus, Stand (wartende Scans, letzte Bestätigung, Stand der Client-Werte), Knopf „An Client übergeben“.
- Befehle: `/peon client` (Optionen), `/peon client senden`, `/peon debug client`.
- Später kann auch Ledger über dieses Modul liefern.

### 6.2 Anbindung an Broker (nur Erweiterung)

- Broker bekommt eine kleine Schnittstelle für Zuhörer: `mod:AddSnapshotListener(fn)`. Beim Scan ruft Broker sie für Beginn, jedes Angebot und Ende auf, bei Live-Abfragen mit allen Zeilen des Gegenstands. Ohne Zuhörer ändert sich nichts.
- Broker liest die Client-Werte nur über Peon_Client (`Peon:GetModule("client"):Ranges(schlüssel)`), abgesichert, wenn das Modul fehlt.
- Die Kern-API von Peon bleibt unverändert.

### 6.3 Format der Momentaufnahmen (Spiel → Client)

```lua
PeonClientDB = {
  fmt = 1,
  queue = {               -- älteste zuerst
    { id = "1792345678-1", kind = "scan",   -- oder "live"
      market = "Classic Beta PvE / Alliance", realm = "Classic Beta PvE", faction = "Alliance",
      region = 1,          -- GetCurrentRegion(): 1 US, 3 EU (in Forever prüfen)
      t = 1792345678, char = "Mirel Dorna", build = "1.60.1.70245", broker = "0.30.0",
      total = 70388, offers = 70388, lines = 41000, partial = false,
      names = { [6513] = "Name|Qualität" },   -- Namen, die der Client noch nicht bestätigt hat (nur Komplettscan)
      rows = [[…]] },      -- eine Zeile je Angebot (siehe unten)
    { id = "1792345999-2", kind = "live", key = "2770", commodity = true, partial = false, … },
  },
}
```

Eine Zeile je Angebot, Felder wie bei Blizzard, getrennt durch `;`:

| Nr. | Feld | Inhalt |
|---|---|---|
| 1 | `item` | itemID |
| 2 | `bonus` | Bonus-Nummern aus dem Link, durch Komma getrennt (leer, wenn keine) |
| 3 | `name` | voller Name nur bei Gegenständen mit Zusatz (sonst leer) |
| 4 | `quantity` | Stück in diesem Angebot |
| 5 | `buyout` | Sofortkaufpreis der ganzen Auktion in Kupfer (0 = nur Gebot) |
| 6 | `unit_price` | Preis je Stück, nur wenn das Spiel ihn liefert (Live-Abfrage Massenware) |
| 7 | `bid` | Gebot bzw. Mindestgebot in Kupfer (leer, wenn keins) |
| 8 | `time_left` | Stufe 1 bis 4 (1 = `SHORT` … 4 = `VERY_LONG`) |
| 9 | `id` | Auktionsnummer (nur Live-Abfragen) |
| 10 | `n` | Anzahl völlig gleicher Angebote (Felder 1 bis 9 gleich), sonst 1 |

- Gleiche Angebote zusammenzählen verliert nichts, weil Angebote ohne Nummer nicht unterscheidbar sind.
- Größe etwa 1 MB je Komplettscan (im Test höchstens 1,6 MB bei 70.000 verschiedenen Angeboten), bei 10 wartenden Scans etwa 10 MB.
- Reine Gebote (ohne Sofortkauf) kommen mit, auch wenn Broker sie selbst nicht auswertet.

### 6.4 Lesen im Client

- Der Client sucht `Peon_Client.lua` in allen Konten unter `WTF\Account\…\SavedVariables\`.
- Ändert sich die Datei, wartet er, bis sie 2 Sek. gleich bleibt (das Spiel schreibt sie in einem Zug), liest eine Kopie und übernimmt jede Momentaufnahme genau einmal (über ihre `id`).
- Der Lua-Leser führt nichts aus. Fehler in der Datei brechen nur dieses Einlesen ab, mit Eintrag im Protokoll.

### 6.5 Rückgabe (Client → Spiel)

Der Client schreibt `AddOns\Peon_Client\Data.lua`. Die Datei wird **nie mit ausgeliefert**. Sie steht in der TOC von Peon_Client. Weil das Spiel eine fehlende Datei aus der TOC als Warnung meldet, liegt beim ersten Einbau ein leerer Platzhalter da, den der Client überschreibt. Ohne Werte darin läuft das Modul ohne Client-Werte.

```lua
PeonClientData = {
  fmt = 1, t = 1792349999, client = "0.3.0",
  ack = { ["1792345678-1"] = true, … },            -- übernommene Momentaufnahmen
  markets = {
    ["Classic Beta PvE / Alliance"] = {
      t = 1792349999, day = 20749,                  -- Stand der Auswertung, Tag wie Broker
      items = { [2589] = "93:791:91:12:eb", ["6611:Klinge des Wolfs"] = "…" },
    },
  },
}
```

**Umgesetzt in C4 (23.10.2026, Rechenmodell Kapitel 8):** je Gegenstand nur der Langzeit-Teil als Text `MITTE:SCHW:LANG:TAGE:Quelle`:

| Wert | Bedeutung |
|---|---|
| MITTE | Median der Tageswerte der letzten 14 Tage (Kupfer) |
| SCHW | Schwankung in Zehntausendsteln (791 = 7,91 %), mindestens 5 % |
| LANG | gewichtetes Mittel, Halbwertszeit 3 Tage (Kupfer) |
| TAGE | wie viele Tage dahinterstehen (mindestens 3) |
| Quelle | e = eigene Scans, b = Broker-Verlauf, eb = beides |

Richtwert, Bereich, Lage und Schnäppchen rechnet Broker weiter selbst mit diesen Werten und seinem heutigen Tag. Absatz, Verlässlichkeit und AHledger-Anteil kommen später (C6, Release).

- Schlüssel wie in Broker: itemID, bei Varianten `"itemID:voller Name"`.
- Geschrieben wird in eine neue Datei, die dann die alte ersetzt, damit das Spiel nie eine halbe Datei lädt.
- Neue Werte wirken im Spiel ab dem nächsten Reload oder Login.

### 6.6 Nutzung in Broker

- **Client-Werte vorrangig:** Sind sie höchstens 7 Tage alt (einstellbar), nimmt Broker den Langzeit-Teil (MITTE, SCHW, LANG) vom Client und rechnet daraus wie bisher Richtwert, üblichen Bereich und Lage. Sonst rechnet Broker ganz wie bisher (umgesetzt in Broker 0.31.0).
- Die Quelle ist sichtbar: im Tooltip mit Umschalt z. B. „Üblich (Client, 12 Tage) X bis Y“, im Reiter Verkaufen und Preise ebenso.
- Live- und „Jetzt“-Werte (Min, Angebote, Vorschlag aus dem günstigsten Angebot) bleiben immer Brokers eigene.
- Sind Client-Werte mit AHledger-Anteil dabei, nennt Broker AHledger als Quelle.

## 7. Datenhaltung

### 7.1 Tabellen (SQLite)

| Tabelle | Inhalt |
|---|---|
| `markets` | Broker-Markt, Region, Regelsatz, Fraktion, zugeordneter AHledger-Markt |
| `items` | Schlüssel, itemID, Variante, Name, Qualität, Massenware ja/nein, Art, Händlerpreis, Symbolname |
| `snapshots` | Momentaufnahme: Markt, Quelle, Art, Zeit, Charakter, Build, Anzahl Angebote, vollständig ja/nein |
| `snapshots.rows` | Angebote einer Momentaufnahme (Felder wie 6.3), gepackt (zlib) statt eigener Tabelle `offers` (Umsetzung C2) |
| `item_snap` | Kennzahlen je Gegenstand und Momentaufnahme: Min, Median, unteres und oberes Viertel, Menge, Angebote |
| `item_hour`, `item_day` | verdichtete Kennzahlen je Stunde bzw. Tag und Quelle |
| `sales` | Absatz aus Vergleichen (verkauft, abgelaufen, abgebrochen, beobachtete Zeit) |
| `ext_ahledger` | AHledger-Werte je Abruf |
| `ranges` | berechnete Rückgabe-Werte je Markt und Gegenstand |
| `import_log`, `settings` | Protokoll der Einlesevorgänge, Einstellungen |

### 7.2 Aufbewahrung

- **Einstellbar per Schieber**, Standard: **Momentaufnahmen 30 Tage vollständig** (Angebote und Kennzahlen), danach Stundenwerte 1 Jahr, Tageswerte unbegrenzt.
- Beim Schieber stehen der **aktuelle Speicherbedarf** und der **geschätzte Bedarf** für die neue Einstellung, gerechnet aus den tatsächlichen Daten der letzten Tage (Angebote je Tag × Tage).
- Verdichten einmal täglich und beim Beenden, im Hintergrund.

## 8. Auswertung

Grundlage ist das Rechenmodell. Neue Rechenwege kommen als **Kapitel 8 „Peon Client“** ins Rechenmodell und werden vor dem Bau mit KarloDerBaer abgestimmt.

- **Kennzahlen je Momentaufnahme:** Min, Median je Stück über alle Stück, Viertel, Menge, Angebote (wie Rechenmodell Kapitel 1 und 2).
- **Üblicher Bereich und Richtwert:** gleiches Verfahren wie Broker (Kapitel 7), aber aus allen Momentaufnahmen statt nur Tageswerten. Ob ein längerer Zeitraum als 14 Tage besser ist, klären wir mit echten Daten.
- **Absatz:** gleiche Regeln wie `Peon_Broker_Absatz.md`, aber mit allen Preisstufen beider Momentaufnahmen und mit den Auktionsnummern der Live-Abfragen.
- **Muster:** Median und Menge nach Wochentag und Tageszeit (wann günstig kaufen, wann gut verkaufen).
- **Ranglisten und Chancen** (umgesetzt in Programm 0.4.0, Formeln in Rechenmodell Kapitel 9):
  - Wiederverkauf: oft unter der Untergrenze zu haben und genug Absatz,
  - Händler-Schnäppchen: wie oft und wann Angebote unter dem Händlerpreis auftauchen,
  - Dumping und fallende Preise über mehrere Tage, steigende Preise,
  - lohnende Gegenstände: Absatz × Spanne.

## 9. Oberfläche

### 9.1 Aussehen

- **Dunkel und modern** mit Akzent **Peon-Grün `#8ccf4d`**, hell umschaltbar.
- Gegenstandsnamen in den Qualitätsfarben des Spiels, Preise mit Gold, Silber und Kupfer in Münzfarben.
- Trend-Symbole wie in Broker (gleiche Farben).
- Symbole der Gegenstände: Symbolname von AHledger, Bild von einem Bilderdienst, lokal zwischengespeichert. Ohne Bild ein Platzhalter. (Ob das zuverlässig klappt, prüfen wir in C3.)
- Ruhige Flächen, klare Tabellen mit fester Kopfzeile, Diagramme im gleichen Farbschema.

### 9.2 Aufbau

Links eine schmale Leiste mit den Ansichten, oben Markt-Auswahl, Suche über alles und Status (letzte Momentaufnahme, Stand AHledger, Stand der Rückgabe).

| Ansicht | Inhalt |
|---|---|
| **Übersicht** | Kacheln: letzte Momentaufnahme (Zeit, Angebote, Gegenstände), im Spiel wartende Scans, Rückgabe an Broker (Stand), AHledger (Stand). Größe des Markts über die Zeit. Größte Bewegungen heute (gestiegen, gefallen). Letzte Einlesevorgänge |
| **Gegenstände** | Tabelle aller Gegenstände: Name, Min, Median, Menge, Absatz je Tag, Trend, üblicher Bereich, Quellen. Filter nach Qualität, Art, Massenware. Klick öffnet den Gegenstand |
| **Gegenstand** | Kopf mit Symbol, Name, Händlerpreis. Kennzahlen-Kacheln. Diagramm Preis je Stück (Min, Median, Bereich als Band, AHledger gestrichelt). Diagramm Stück (Menge im AH, Absatz). Zeitraum 24 Std., 7, 30, 90 Tage, alles. Wärmebild Wochentag × Uhrzeit. Preisstufen der letzten Momentaufnahme (wie tief ist das Angebot). Vergleich der Quellen |
| **Chancen** | Reiter Wiederverkauf, Händler-Schnäppchen, Fallend, Steigend, lohnend. Filter wie Mindestgewinn |
| **Quellen** | je Quelle Status, letzter Abruf, Prüfergebnis, Zuordnung der Märkte |
| **Einstellungen** | Ordner, Aufbewahrung mit Speicheranzeige, mit Windows starten, Frische-Grenze der Rückgabe, AHledger (an/aus, Takt, optionaler Schlüssel), Sprache |

Texte auf Deutsch, englisch vorbereitet.

## 10. Betrieb

- Läuft im **Infobereich** (unten rechts) mit Peon-Symbol und überwacht WTF selbst. Klick öffnet das Fenster, Rechtsklick: Fenster, Jetzt einlesen, AHledger abrufen, Beenden.
- **Mit Windows starten** einstellbar, Standard aus.
- Nur ein laufender Client gleichzeitig.
- Protokoll in `<alter Programmordner>\DB\logs\`, Einlesevorgänge auch in der Übersicht.

## 11. Bauabschnitte

**Stand 23.10.2026:** C1, C2, Broker-Verlauf, C3, C4 und C6 umgesetzt (Peon_Client 0.3.0, Broker 0.32.0, Programm 0.5.0 mit dem Rest aus Abschnitt 9 außer Englisch und Filter nach Art, Rechenmodell Kapitel 8 und 9); Bilder der Gegenstände folgen mit den externen Quellen. **Geändert am 22.10.2026:** Die Beta ist offline bis zum Start. Bis dahin: C3, C4, C6 und Broker-Verlauf als Quelle (Abschnitt 5.7). AHledger, Blizzard-API, weitere Quellen und C5 erst zum Release. Die ursprüngliche Reihenfolge:

| Nr. | Inhalt | Wo |
|---|---|---|
| C1 | Modul Peon_Client: Warteschlange, Export im Format 6.3, Knopf „An Client übergeben“, Bestätigung, Optionsseite. Broker: Zuhörer-Schnittstelle. Tests mit lua5.1 | Spiel |
| C2 | Client-Grundgerüst: Electron, Vue, Infobereich, Einstellungen, Ordner, Lua-Leser, Einleser „Spiel“, Datenbank, Einleser „AHledger“ (nur speichern), Übersicht. Erstes Paket nach `Runtime` | PC |
| C5 | Quellenprüfung: eine Woche Vergleich eigene Scans mit AHledger, Bericht, Freigabe abstimmen | PC |
| C3 | Gegenstände und Gegenstand mit Verlauf, Muster, Symbole, Aufbewahrung mit Speicheranzeige | PC |
| C4 | Rechenmodell Kapitel 8 abstimmen, Rückgabe `Data.lua`, Broker nutzt die Werte vorrangig | beide |
| C6 | Ranglisten und Chancen | PC |

Später: Ledger-Auswertung (Buch, Verkaufsquote, Kosten), Berufe, Blizzard-API, Verbindung von Verkaufsquote und Absatz.

## 12. Tests

- **Lua (Spiel):** neuer Test `tests\test_client.lua` mit nachgebauter WoW-API (Export, Zusammenzählen, Warteschlange, Bestätigung, Laden von Data.lua). `test_broker.lua` prüft die Zuhörer-Schnittstelle. Läuft mit `run_tests.sh`.
- **Client:** Tests für Lua-Leser, Einleser, Kennzahlen (mit den Beispielen aus dem Rechenmodell), Absatz, Verdichtung, Schreiber. Oberfläche mit Playwright (Bildschirmfotos zum Ansehen). Zusätzlich ein Lauf gegen eine Kopie der echten WTF-Datei.
- Nach dem Übertragen Prüfsummen auf dem PC kontrollieren, wie bei den Addons.

## 13. Offene Punkte (im Bau zu prüfen)

- ~~Gibt es `GetCurrentRegion()` in Forever?~~ Ja, in der Beta liefert es 110 (keine Retail-Region). Zuordnung zu AHledger deshalb über die Einstellungen im Client, nach dem Start erneut prüfen.
- ~~Verhalten des Spiels, wenn `Data.lua` fehlt~~: geklärt, das Spiel meldet eine LUA_WARNING, deshalb Platzhalter (Peon_Client 0.1.1).
- Größe der Warteschlange in WTF und Ladezeit beim Einloggen mit 10 Scans. Erster echter Scan: 20.220 Angebote = 329 KB.
- ~~`node:sqlite` oder `better-sqlite3`~~: `node:sqlite` (Electron 44, Node 24) läuft, auch mit großen Zahlen.
- Bilder der Gegenstandssymbole.
- Wie AHledger Scans zusammenführt (Quellenprüfung C5).
- Ruleset- und Realm-Name nach dem Start von Forever (Markt-Schlüssel bleibt „Realm / Fraktion“, Zuordnung zu AHledger in den Einstellungen).

## 14. Entschieden (KarloDerBaer, 22.10.2026)

- Name **Peon Client**, Programm für Windows mit **Electron**, Oberfläche mit **Vue**, Aussehen **dunkel, modern, Peon-Grün**.
- Stufe 1: Übersicht und Import, Gegenstand mit Verlauf, Ranglisten und Chancen, Rückgabe an Broker, schöne und übersichtliche Oberfläche.
- **Broker nutzt Client-Werte vorrangig**, solange sie frisch sind (bis 7 Tage), sonst eigene Rechnung.
- **Alle Quellen einbeziehen, aber nur bei passender Qualität.** Eigene Scans und Blizzard-API sind Momentaufnahmen. AHledger fasst Scans vieler Spieler zusammen und wird erst nach einer Quellenprüfung je Zweck freigegeben, bis dahin nur zum Vergleich.
- **Export wie die Blizzard-API**, je Angebot eine Zeile, völlig gleiche Angebote zusammengezählt. Live-Abfragen kommen mit.
- **Knopf „An Client übergeben“** wird nach einem Scan angeboten, sonst Übergabe beim Ausloggen.
- **Eigenes Modul Peon_Client** für die Schnittstelle. Die Client-Werte liegen als `Data.lua` in dessen Ordner. Bis zu **10 Scans** warten im Spiel (einstellbar).
- **Aufbewahrung einstellbar** mit Anzeige des aktuellen und geschätzten Speicherbedarfs, Standard 30 Tage fein.
- Ordner: Quellcode `<Repo>\client`, Programm `<alter Programmordner>\Runtime`, Datenbank `<alter Programmordner>\DB`.
- Läuft im **Infobereich** und überwacht selbst.
