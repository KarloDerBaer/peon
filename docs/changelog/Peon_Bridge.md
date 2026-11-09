# Peon_Bridge (bis 0.3.0 Peon_Client): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.8.0

Kurz: Scans am neutralen Auktionshaus kommen im Manager als eigener Markt an.

- 0.8.0 (09.11.2026): Momentaufnahmen aus dem Markt `<Realm> / Neutral` (Broker 0.40.0) melden dem Manager die Fraktion `Neutral` statt der des Charakters.

## 0.7.0

Kurz: Die Bridge gibt Broker die Preise aus dem neuesten Stand des Managers, zum Beispiel aus der Blizzard-API.

- 0.7.0 (07.11.2026, Wunsch KarloDerBaer): Neue Funktion `mod:Current(market)` für Broker: Zeit, Herkunft und Preise aus `cur` in `Data.lua` (Peon Manager 0.18.0). Nur mit freigeschaltetem Kanal broker.

## 0.6.0

Kurz: Genaue Werte von Gegenständen, auch mit Zusatz, gehen an den Manager. Dafür ist kein Scan nötig.
Kurz: Einkaufslisten aus dem Manager kommen beim Laden im Spiel an.

- 0.6.0 (06.11.2026, Wunsch KarloDerBaer): **Genaue Werte:** Beim Komplettscan und bei Live-Abfragen liest die Bridge den Tooltip (`C_TooltipInfo.GetHyperlink`) von Gegenständen ab Qualität Selten, höchstens 400 je Scan, jeder Schlüssel einmal (`tipIds`, gilt nach der Bestätigung). Zusätzlich liest sie im Hintergrund, was der Manager bestellt (`tipWant` in `Data.lua`): je 8 auf einmal, ab 10 Sek. nach dem Laden, nie im Kampf, Ablage in `tipBox`. Der Link aus Nummer und Bonus liefert im Spiel den vollen Namen und die Werte des Zusatzes (KarloDerBaer, 06.11.2026). **Andere Marktnamen:** `aliases` in `Data.lua`, Werte werden auch unter einem anderen internen Namen gefunden. **Einkaufslisten:** `shop` in `Data.lua` geht beim Anmelden an Broker (`MergeShop`). **Im Spiel prüfen:** Bleibt das Spiel beim Lesen im Hintergrund flüssig, stimmen Farben und Werte, hängen die Werte von der Stufe im Link ab, wie lange dauert der Scan zusätzlich?

## 0.5.0

Kurz: Im Manager geleerte Fehler verschwinden jetzt auch im Spiel.

- 0.5.0 (06.11.2026, Wunsch KarloDerBaer): Reicht das neue Feld `errorsClearBefore` aus `Data.lua` beim Laden an den Kern weiter (`Peon.ClearErrors`), damit der Peon Manager den Fehlerspeicher auch im Spiel leeren kann. Mit älterem Kern passiert nichts. Format von `Data.lua` bleibt 2.
  - **Im Spiel prüfen:** Nach dem Leeren im Manager und einem `/reload` meldet `/peon fehler` keine alten Fehler mehr.

## 0.4.0

- 0.4.0 (31.10.2026, Design `Peon_GitHub_Design.md` Abschnitt 4): **Peon_Client heißt jetzt Peon_Bridge** und ist die allgemeine Verbindung zwischen Spiel und Peon Manager.
  - Umbenannt: Ordner und TOC `Peon_Bridge`, Titel „Peon Bridge“, SavedVariables `PeonBridgeDB`, Werte vom Manager `PeonBridgeData`, Modul-Schlüssel `bridge`, Befehle `/peon bridge …`, Knopf „An Manager“. Keine Übernahme alter Daten (in `_forever_\WTF` gab es noch keine Peon-Datei).
  - **Kanäle:** Inhalte melden sich als Kanal an (`ns.RegisterChannel`, intern im Addon, Kern-API unverändert). Der erste Kanal ist `broker` (neue Datei Channel_Broker.lua mit dem bisherigen Export.lua und den Werten für Broker). Bridge.lua ist nur noch der Transport (Warteschlange, Bestätigung, Data.lua lesen, Stand).
  - **Freischaltung durch den Manager:** Ein Kanal arbeitet nur, wenn Data.lua im Format 2 `channels = { broker = true }` enthält. Ohne Freischaltung (Platzhalter, altes Format, kein Manager) meldet sich die Bridge nicht bei Broker an, zeichnet nichts auf und liefert Broker keine Werte (Broker rechnet selbst). So sammelt niemand ohne Broker Client Scans in WTF.
  - Stand und Optionsseite zeigen Werte und Version des Managers und je Kanal „freigeschaltet“ oder „nicht freigeschaltet“.
  - Tests in `test_bridge.lua` (bisher `test_client.lua`), zusätzlich: ohne Freischaltung keine Aufzeichnung, kein Zuhörer und keine Werte, altes Format und `broker = false` gelten als nicht freigeschaltet, mit Freischaltung wie bisher.

## 0.3.0

- 0.3.0 (23.10.2026, C6): Namen für den Client tragen **Händlerpreis und Warenart**: `names[itemID] = "Name|Qualität|Händlerpreis|Massenware"` (über Broker `VendorPrice`/`IsCommodity`, sonst vom Spiel), auch für Gegenstände mit Zusatz (dort ohne Namen). Einmalig werden alle Namen neu geschickt (`nameFmt` 2). Ein Name ohne Händlerpreis (Spiel kannte den Gegenstand noch nicht) gilt nicht als übergeben und kommt beim nächsten Scan wieder. `mod:Sales(key, market)` liest den Absatz aus `PeonClientData.markets[…].sales` (`{ perDay, rate, minutes, t }`, gleiche Frist wie der Langzeit-Teil). Stand: „üblicher Bereich von n, Absatz von m Gegenständen“. Tests in `test_client.lua`.

## 0.2.0

- 0.2.0 (23.10.2026, C4): `mod:LongTerm(key, market)` liest den Langzeit-Teil aus `PeonClientData.markets` (Schlüssel als Zahl, Text oder „itemID:voller Name“) und gibt `{ mitte, schw, lang, days, src, t, day }` zurück, nichts bei kaputten Werten oder wenn sie älter als `freshDays` sind. Stand auf der Optionsseite: „Für Markt: üblicher Bereich von n Gegenständen (nutzt Broker)“ bzw. Hinweis, dass die Werte zu alt sind. Optionsseite: Abschnitt „Werte für Broker“ mit Regler. Tests in `test_client.lua` (Lesen, Varianten, kaputte Werte, fremder Markt, Frist, Fehler im Client, Broker nutzt die Werte).

## 0.1.2

- 0.1.2 (22.10.2026): Fehler beim Verarbeiten einer Momentaufnahme bleiben im Modul: gemerkt in `PeonClientDB.errors` (höchstens 10, mit Art, Text, Version, auch ohne Debug), einmal im Chat gemeldet, laufende Aufnahme verworfen; der Zuhörer bleibt bei Broker angemeldet.
- Erster Scan im Spiel (22.10.2026): Fehler beim Scan, Scan wurde nicht fertig, Warteschlange leer, im BugGrabber nichts (Fehler werden abgefangen). Mit 0.30.1/0.1.2 wird die Meldung gespeichert. Ursache gefunden und behoben in Broker 0.30.2 (zu große Zahl bei `%d`).
- **Test im Spiel bestanden (22.10.2026, Broker 0.30.2, Client 0.1.2):** Komplettscan fertig, Knopf „An Client“ und Reload funktionieren. In `Peon_Client.lua`: 1 Momentaufnahme, 20.220 Angebote in 9.388 Zeilen (Summe der Zähler stimmt), 329 KB. 1.669 Zeilen mit Zusatz tragen Bonus-Nummer und vollen Namen (z. B. `3201;12722;Barbarische Kriegsaxt des Bären;…`), 1.484 Namen für den Client (genau die Gegenstände ohne Zusatz), 25 Angebote über 2^31 Kupfer (bis 9.999.999g) sauber geschrieben, Restzeit-Stufen 1–4 vorhanden, keine reinen Gebote im Markt, keine Fehler. Charakter „Mirel Dorna“, Build 1.60.1.70532. **`GetCurrentRegion()` liefert in der Beta 110** (keine Retail-Region wie 1 US / 3 EU) – Zuordnung zu AHledger also über die Einstellungen im Client. Live-Abfragen noch nicht gesehen.
- **Nächster Schritt:** Test im Spiel (`/reload` reicht, Data.lua ist neu, aber die TOC kannte sie schon; sicherer: WoW neu starten). Prüfen: keine LUA_WARNING mehr, Komplettscan, dann Knopf „An Client“ unter dem Scan-Knopf; nach dem Reload `/peon client status` (1 Komplettscan, Größe); Datei `WTF\Account\…\SavedVariables\Peon_Client.lua` ansehen (Zeilen plausibel? Varianten mit Namen? Region?); Ladezeit beim Einloggen mit mehreren Scans; meldet das Spiel etwas, weil Data.lua fehlt? Danach C2 (Programm).

## 0.1.1

- 0.1.1 (22.10.2026, Meldung von KarloDerBaer): Das Spiel meldete `LUA_WARNING: Peon_Client.toc:13 Error loading Peon_Client/Data.lua`, weil die Datei fehlte. Jetzt liegt im AddOns-Ordner eine **leere Data.lua als Platzhalter** (nur Kommentar). Sie wird einmal angelegt, nie ausgeliefert und vom Client überschrieben. `test_client.lua` lädt die echte Data.lua nie (prüft nur, dass sie sich laden lässt), damit spätere Client-Werte den Test nicht verändern.

## 0.1.0

- 0.1.0 (22.10.2026):
  - **Momentaufnahme je Komplettscan** im Format der Blizzard-API: eine Zeile je Angebot `item;bonus;name;quantity;buyout;unit_price;bid;time_left;id;n`, völlig gleiche Angebote als eine Zeile mit Zähler `n`. Bonus-Nummern aus dem Link (Feld 13 ff.), voller Name nur bei Gegenständen mit Zusatz (Bonus im Link oder bei Broker als Variante bekannt), reine Gebote mit Mindestgebot, Restzeit-Stufe 1–4. Kopf: `id` („Zeit-Nummer“), `kind` = scan, Markt, Realm, Fraktion, Region (`GetCurrentRegion`, falls vorhanden), Zeit, Charakter (Vor- und Nachname), Build, Broker-Version, Anzahl Angebote/Zeilen, `names` (Name|Qualität der Gegenstände, die der Client noch nicht kennt).
  - **Live-Abfragen** als eigene Momentaufnahme (`kind` = live, `key`, `commodity`, `partial`): Stückpreis in `unit_price`, Auktionsnummer und Restzeit, wenn das Spiel sie liefert (Sekunden → Stufe, Stufe 0–3 → 1–4), sonst Brokers zusammengefasste Preisstufen. Leer = keine Angebote mehr; leer und unvollständig (lädt noch) wird nicht abgelegt; dieselbe Abfrage mit gleichem Ergebnis innerhalb 60 Sek. nur einmal.
  - **Warteschlange:** höchstens `queueMax` Komplettscans und `liveMax` Live-Abfragen, darüber fällt die älteste weg. Beim Start löscht das Modul alles, was der Client in `PeonClientData.ack` bestätigt hat.
  - **Knopf „An Client“** unter Brokers Scan-Knopf nach einem Komplettscan (abschaltbar): Reload, damit das Spiel die Daten schreibt; verschwindet mit dem Auktionshaus.
  - **Optionsseite:** Stand (wartende Scans und Live-Abfragen mit Größe, letzte Momentaufnahme, letzte Bestätigung, Werte des Clients), Regler, Haken, „An Client übergeben (Reload)“, „Warteschlange leeren“ (Rückfrage), „Standardwerte“.
  - Bereiche für Peon_Feedback: Übergabe, Warteschlange, Knopf am Auktionshaus, Werte des Clients, Optionen.
  - Test: `test_client.lua` (echter Kern und Broker). Großer Scan mit 70.000 verschiedenen Angeboten: 1,6 MB (obere Grenze), etwa 1,2 Sek. Rechenzeit verteilt auf die Bilder des Scans.
