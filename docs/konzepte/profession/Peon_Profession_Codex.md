# Peon_Profession: Konzept Codex und Sammelstellen

Stand: 17.11.2026, abgestimmt mit KarloDerBaer (Abschnitt 7). Gebaut in Profession 0.5.0 mit Fishing 1.7.0. Der Datenaustausch zwischen Peon-Nutzern hat ein eigenes Konzept: `docs/konzepte/kern/Peon_Comm_Konzept.md`.

## 1. Idee

Profession bekommt ein Nachschlagewerk, den **Codex**:

- **Rezepte:** je Beruf und mit einer Suche über alle Berufe, mit Quelle und wer sie kennt.
- **Farming:** alle Erze, Kräuter und Fische mit den Gebieten, in denen man sie findet.

Dafür merkt sich Profession ab jetzt beim Bergbau und Kräutersammeln jede **Sammelstelle**.

Anregung war das Addon Mastercraft. Von dort übernehmen wir nur Ideen, keine Daten und keinen Code (Lizenz „alle Rechte vorbehalten“, Daten von Wowhead).

## 2. Datenquellen

Nur was Peon schon hat, plus eigene Sammlung im Spiel.

| Bereich | Schon da | Selbst gesammelt (neu, accountweit) |
|---|---|---|
| Rezepte | Routen mit Material (`Routes.lua`), Lernstufe (`ns.Learn`), erlernte Rezepte je Charakter (`known`) | erlernte Rezepte aller Charaktere (`recipes`), Lehrerfenster (`teach`), Rezepte beim Händler (`sold`), Ort von Lehrern und Händlern (`npcs`) |
| Erze und Kräuter | Itemlisten und Gebiete je Stufe in `Routes.lua` | jede Sammelstelle mit Ort, Vorkommen und Beute (`nodes`) |
| Fische | Fangdatenbank von Peon_Fishing | nichts Neues, Profession liest sie über `CatchZones` (Fishing 1.7.0) |

## 3. Sammelstellen (`Gather.lua`)

- Erkannt am Zauber Bergbau oder Kräutersammeln (Nummer oder Name), Name des Vorkommens aus dem Ziel des Zaubers, Ort beim Erfolg des Zaubers, gespeichert mit der Beute.
- Stellen näher als 25 Meter zählen als dieselbe. Ohne Größe der Karte gilt ein Abstand von 0,004 der Karte.
- Höchstens 1500 Stellen je Karte, die am längsten nicht besuchten fallen weg.
- Ohne Ort (Instanz, geheime Werte) wird nichts gemerkt.
- `/prof stellen` zählt die Stellen, `/peon debug profession` meldet jede.
- Der Guide nennt bei Sammelschritten zusätzlich die eigenen Fundorte.

## 4. Codex (`Codex.lua`)

Neuer Reiter „Codex“ im Fenster von Peon Berufe. Oben die Knöpfe Rezepte und Farming und ein Suchfeld.

### 4.1 Rezepte

- Dropdown oben rechts: „Alle Berufe“ und jeder Beruf mit Rezepten. Wählt man links einen Beruf mit Rezepten, springt es mit (Wunsch KarloDerBaer). Das Suchfeld filtert in der Auswahl.
- Eine Zeile je Rezept, zusammengeführt über den Namen aus Route, Lehrer, Händler und erlernten Rezepten.
- Spalten: Rezept, Beruf, Stufe, Quelle (Lehrer, Händler, sonst aus dem Guide), Erlernt (du, Zahl der Twinks).
- Tooltip: Material mit Preis, Lehrer und Händler mit Preis und Ort, wer es kennt.
- Klick setzt einen Wegpunkt zum Lehrer oder Händler (eigene Fraktion zuerst).

### 4.2 Farming

- Erze und Kräuter aus den Routen und den eigenen Stellen (auch Nebenfunde wie Edelsteine), Fische aus Peon_Fishing ohne graue Beute.
- Auswahl Alle, Bergbau, Kräuterkunde, Angeln und Suche. Die Auswahl springt mit, wenn links Bergbau, Kräuterkunde oder Angeln gewählt wird.
- Spalten: Gegenstand, Beruf, Stufe, Gebiete, Stellen, Preis.
- Klick zeigt darunter die Gebiete: eigene Stellen, Anzahl gesammelt, Anteil beim Angeln (Tooltip mit der häufigsten Unterzone), Quelle (eigene Stellen, eigene Fänge, Guide ab Stufe).

## 5. Für später

- **Anzeige auf Welt- und Minikarte** (zurückgestellt, KarloDerBaer). Die gelben Punkte der Kräuter- und Erzsuche zeichnet das Spiel selbst, ein Addon kann sie nicht lesen und nicht einzeln umfärben. Möglicher Weg: an bekannten Stellen ein Ring mit Symbol des Krauts, dessen Mitte frei bleibt. Ein gelber Punkt im Ring heißt „da“, ein leerer Ring „gerade nichts“.
- **Austausch der Sammelstellen** mit anderen Peon-Nutzern (Dienst `nodes`), nach den Rezepten der Freunde (Abschnitt 8).
- **Fischschwärme auf der Karte** und die **Rezepthändler aus PLG** (MIT, 146 Händler): noch nicht entschieden.

## 6. Speicher

`PeonProfessionDB` (accountweit), alles bleibt bei „Standardwerte“:

- `nodes[uiMapID] = { { x, y, p = Beruf, n, t, names = { [Vorkommen] = Anzahl }, items = { [itemID] = Menge } } }`
- `recipes[Beruf][recipeID] = { out, n, m, name, by = { [Charakter] = true } }`
- `teach[Beruf][Name] = { name, skill, cost, item, npcs }`, `sold[Beruf][itemID] = { name, price, npcs }`
- `npcs[npcID] = { name, map, x, y, f, kind }` (x und y in Prozent)
- Einstellungen `codexMode` (recipes, farm) und `codexGroup` (all, mining, herbs, fish)

## 7. Antworten von KarloDerBaer (17.11.2026)

1. Codex und Sammelstellen in Peon_Profession, kein eigenes Modul.
2. Anzeige auf Karte und Minikarte vorerst weglassen, weil sich die gelben Punkte nicht direkt erkennen lassen. Sammelstellen ab jetzt mitschreiben und im Codex die Gebiete nennen.
3. Datenaustausch über Addon-Flüstern im Kern, von Anfang an an und abschaltbar, fremde Daten sofort sichtbar und anders gefärbt. Bau in einer eigenen Sitzung, für mehr als nur Sammelstellen.

## 8. Rezepte der Freunde (Profession 0.6.0, KarloDerBaer, 18.11.2026)

Anlass: Blizzards Berufslinks lassen sich in Forever seit dem 8.11.2026 nicht beim anderen öffnen. Der Codex zeigt deshalb, welche Rezepte Freunde und Gildenmitglieder mit Peon kennen. Grundlage sind die Regeln für Module im Konzept `docs/konzepte/kern/Peon_Comm_Konzept.md`, Abschnitt 8. Das ist die erste Ausnahme von „keine Namen“.

### 8.1 Entscheidungen von KarloDerBaer

1. **Von wem:** nur Peon-Nutzer in der eigenen Freundesliste (auch Battle.net-Freunde) oder der eigenen Gilde.
2. **Was ich teile:** nur die Rezepte des eingeloggten Charakters. Twinks bleiben unsichtbar.
3. **Speichern:** 30 Tage ab dem letzten Mal, dass der Spieler gesehen wurde. Danach fallen Name und Rezepte weg.
4. **Anzeige:** In der Spalte „Erlernt“ zusätzlich die Zahl der Freunde, im Tooltip ihre Namen in eigener Farbe.

### 8.2 Ablauf (Dienst `recipes`, Version 1)

| Nachricht | Weg | Inhalt |
|---|---|---|
| Stand `k = "s"` | an alle (Kanal) | je Beruf Stufe, Zahl der Rezepte, Prüfwert der Rezeptliste. `f` bei der ersten nach dem Einloggen |
| Frage `k = "q"` | per Flüstern an den Absender des Stands | Berufe, deren Liste fehlt oder veraltet ist |
| Liste `k = "l"` | per Flüstern als Antwort | ein Beruf: Stufe, Prüfwert, Rezeptnummern (Basis 36, bis 150 je Nachricht, in Teilen) |

- Den Stand schickt Peon nach dem Einloggen, sobald der Kanal da ist, und nach dem Lesen eines Berufsfensters, wenn sich etwas geändert hat. Höchstens einmal pro Minute.
- Gefragt wird nur, wenn der Absender Freund oder Gildenmitglied ist und sein gespeicherter Prüfwert nicht passt. Höchstens einmal je Spieler in 10 Minuten.
- Bekommt man den ersten Stand eines Freundes oder Gildenmitglieds nach dessen Einloggen, schickt man ihm seinen eigenen Stand per Flüstern zurück. So erfährt auch er, dass es neue Listen gibt.
- Auf eine Frage antwortet Peon jedem, höchstens einmal je Spieler in 10 Minuten. Die Rezepte des eingeloggten Charakters sind nicht privat.
- Alles läuft nur, wenn „Daten mit anderen Peon-Nutzern teilen“ an ist und der Kern API 24 hat.

### 8.3 Prüfen und Speichern

- Beruf muss einer der bekannten Berufe sein, Stufe 0 bis 1000, höchstens 1000 Rezepte je Beruf, Nummern ganze Zahlen bis 10 Millionen, Name höchstens 60 Zeichen.
- `PeonProfessionDB.friends[name klein] = { name, at, p = { [Beruf] = { s, h, ids = { [recipeID] = true } } } }`, höchstens 200 Spieler. Älter als 30 Tage fällt beim Einloggen weg, bei voller Liste der am längsten nicht gesehene.
- Ist jemand nicht mehr Freund oder Gildenmitglied, bleibt sein Eintrag bis zum Ablauf, wird aber nicht mehr erneuert.

### 8.4 Anzeige

- Codex, Rezepte: Kennt ein Freund ein Rezept, das man selbst noch nicht in der Liste hat, kommt es als eigene Zeile dazu.
- Spalte „Erlernt“: zum Beispiel „du, 2 Freunde“ oder „1 Twink, 1 Freund“, die Freunde hellblau.
- Tooltip: Zeile „Freunde:“ mit den Namen, hellblau.
- `/prof freunde` zeigt im Chat, von wem Rezepte gespeichert sind (Name, Berufe, zuletzt gesehen).
