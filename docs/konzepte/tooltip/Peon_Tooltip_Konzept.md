# Peon_Tooltip – Konzept: Teile im Gegenstands-Tooltip ordnen und ausblenden

Stand: 06.10.2026, mit KarloDerBaer abgestimmt und umgesetzt in **Peon_Tooltip 0.6.0** (alle Bauabschnitte in einem Zug).

## 1. Ziel

In den Optionen von Peon_Tooltip lässt sich für Gegenstands-Tooltips einstellen,

- **welche Teile** angezeigt werden (Blizzard-Teile und Teile anderer Addons) und
- **in welcher Reihenfolge** sie stehen.

Vorerst nur für **Gegenstände**. Einheiten (Spieler, NPCs) bleiben, wie sie sind, weil dort im Kampf viele Werte geheim sind.

Annahme (KarloDerBaer): Forever verhält sich bei Tooltips wie das aktuelle Retail-WoW. Deshalb gibt es keinen eigenen Prüfschritt vorab. Geprüft wird erst, wenn etwas nicht klappt.

## 2. Was ist ein „Teil“?

Ein Teil ist eine Gruppe aufeinanderfolgender Zeilen mit derselben Herkunft.

**Addon-Teile:** ein Teil je Addon. Bei KarloDerBaer derzeit:

| Teil | Inhalt |
|---|---|
| Peon_Broker | Preise (Zeile 1, Behalten, Details mit Umschalt) |
| Peon_Ledger | Kosten, Bestand (mit Umschalt) |
| BagBrother | Bestand je Charakter |
| AtlasLootClassic | Quelle, Favoriten |
| AtlasBIStooltips | BiS-Info |
| ItemTooltipProfessionIcons | Berufs-Symbole |

Neue Addons erscheinen automatisch in der Liste, sobald sie zum ersten Mal etwas in einen Gegenstands-Tooltip schreiben. Sie werden gemerkt, auch wenn das Addon gerade aus ist.

**Blizzard-Teile:** Der Blizzard-Teil wird anhand der Zeilenart zerlegt, die das Spiel jeder Zeile mitgibt (wie in Retail), und, wo es keine Art gibt, anhand der Farbe:

| Teil | Zeilen |
|---|---|
| Kopf | Name, Bindung, „Einzigartig“, Platz/Typ, Schaden/Rüstung, Werte (weiß) |
| Effekte | grüne Zeilen („Anlegen:“, „Benutzen:“, „Chance bei Treffer:“) |
| Set | Setname, Setteile, Setboni |
| Anforderungen | Stufe, Klasse, Beruf, Ruf (auch rote Zeilen) |
| Haltbarkeit | „Haltbarkeit x / y“ |
| Beschreibung | goldener Text in Anführungszeichen |
| Verkaufspreis | „Verkaufspreis:“ mit Münzen |

Der **Name bleibt immer oben** und lässt sich nicht ausblenden. Der Rest des Kopfs folgt direkt darunter.

## 3. Bedienung (Optionsseite)

Neuer Abschnitt **„Gegenstands-Tooltip“** auf der Seite von Peon_Tooltip (linke Spalte unter „Symbole“):

- **Rahmenfarbe bei Gegenständen** (Auswahlliste): „Standard (Blizzard)“ (einfarbig wie bisher) oder „Qualität des Gegenstands“ (grau, weiß, grün, blau, lila …). Gilt für alle Gegenstands-Tooltips (auch Chat-Link und Vergleich).
- Haken **„Teile ordnen“** (Hauptschalter, Standard an). Aus = Tooltip wie ohne Peon.
- Darunter fest **„Name (immer oben)“** und die Liste aller Teile in der aktuellen Reihenfolge, je Zeile:
  - Haken **„anzeigen“** – aus = der Teil ist **ganz weg** (keine Taste zum Einblenden)
  - Name des Teils (Addons mit ihrem Titel aus der TOC ohne Farben, Blizzard-Teile mit „Blizzard: …“)
  - Pfeile **hoch / runter** (Bilder aus dem Spiel, die Spielschrift hat keine Pfeile)
  - Knopf **Entfernen** bei Trennungen und bei Addons, die gerade nicht geladen sind (grau, „(nicht geladen)“)
  - Klick auf eine Zeile wählt sie aus (hell hinterlegt)
- Knöpfe **„Trennlinie einfügen“** (sichtbare dünne Linie) und **„Leerraum einfügen“** (leere Zeile): fügen einen eigenen Eintrag unter der gewählten Zeile ein (ohne Auswahl am Ende). Trennungen lassen sich wie Teile verschieben und entfernen. Sie erscheinen nur zwischen sichtbaren Teilen – am Ende oder vor ausgeblendeten Teilen fallen sie weg; mehrere gleiche direkt hintereinander zählen einmal.
- Knopf **„Reihenfolge zurücksetzen“**: natürliche Reihenfolge, alles sichtbar, Trennungen weg.

**Jedes Peon-Modul ist ein eigener Teil** (Broker, Ledger und künftige Module), genau wie fremde Addons.

**Standard:** Alles sichtbar, Reihenfolge wie bisher (Blizzard, dann die Addons in der Reihenfolge, in der sie schreiben). Ohne eigene Einstellungen ändert sich also nichts. „Standardwerte“ setzt Reihenfolge, Ausblenden und Trennungen zurück; die bekannten Addons bleiben in der Liste.

## 4. Wo es wirkt

Bei allen Gegenstands-Tooltips im Spiel-Tooltip, im Chat-Link-Fenster und in den beiden Vergleichs-Tooltips (angelegte Ausrüstung). Das gilt überall, wo ein Gegenstand gezeigt wird: Taschen, Bank, Auktionshaus, Händler, Broker- und Ledger-Listen.

Drückt man Umschalt (Broker und Ledger bauen den Tooltip neu auf), wird erneut geordnet.

## 5. Umsetzung (Vorschlag)

1. **Herkunft jeder Zeile:** Peon_Tooltip hängt sich (nur mitlesend) an das Hinzufügen von Zeilen im Tooltip. Bei jeder neuen Zeile schaut es nach, aus welchem Addon-Ordner der Aufruf kommt. Das verrät WoW über die Aufrufkette. Zeilen, die schon vor den Addons da waren, gehören Blizzard. Ihre Art kommt aus den Tooltip-Daten des Spiels.
2. **Ordnen, wenn alle fertig sind:** Peon_Tooltip meldet sich erst beim Einloggen beim Spiel an, also nach allen anderen Addons. Damit ist es beim Aufbau des Tooltips das letzte. Dann werden Texte und Farben der vorhandenen Zeilen in der neuen Reihenfolge neu verteilt und überzählige Zeilen geleert. Die Münzanzeige des Verkaufspreises wird an ihre neue Zeile gehängt, danach passt sich die Größe an.
3. **Keine Änderung an fremden Addons und am Kern.** Broker und Ledger werden wie fremde Addons über ihren Ordner erkannt.
4. **Sicherheit:** alles geschützt (`mod:Call`). Bei einem Fehler bleibt der Tooltip unverändert, und der Fehler wird einmal gemeldet. Gesperrte Tooltips (`IsForbidden`) werden nicht angefasst.
5. **Fehlersuche:** `/ttp teile` zeigt für den nächsten Gegenstands-Tooltip im Chat, welche Zeile zu welchem Teil gehört (mit der Zeilenart des Spiels). Damit lässt sich ein Problem später schnell finden.

**Speicher** (`PeonTooltipDB`): `itemOrder` (Liste der Teile und Trennungen, z. B. `b:head`, `a:Peon_Broker`, `s:line:1`), `itemHidden[Teil] = true`, `itemKnown["a:<Addon>"] = { title, seen, seq }`, `itemParts` (Hauptschalter), `itemBorder` (`default`/`quality`), `itemSepId`. „Standardwerte“ setzt Reihenfolge, Ausblenden und Trennungen zurück, `itemKnown` bleibt.

## 6. Grenzen

- Addons, die keine neuen Zeilen anhängen, sondern bestehende **verändern** (z. B. Text an den Namen hängen), lassen sich nicht trennen. Ihre Änderung bleibt in der Zeile, die sie verändert haben.
- Addons mit einem **eigenen Zusatzfenster** neben dem Tooltip lassen sich nicht einordnen. Bei KarloDerBaer gibt es derzeit keins.
- Bilder, die ein Addon getrennt vom Text an eine Zeile hängt (nicht als `|T…|t` im Text), können beim Verschieben verloren gehen. Bei KarloDerBaer nutzen alle Addons Bilder im Text.
- Addons, die ihre Zeilen mitten im Aufbau der Blizzard-Zeilen einfügen (Zeilen-Nachlauf des Spiels), werden zum Blizzard-Teil gezählt. Bei KarloDerBaer macht das keins; BagBrothers Verkaufspreis als Text wird trotzdem richtig dem Teil „Verkaufspreis“ zugeordnet.
- Die Einteilung der Blizzard-Teile nach Farbe ist eine Näherung. Einzelne Zeilen können im falschen Teil landen.

## 7. Umsetzung (0.6.0)

Alles in einem Zug (KarloDerBaer): Erkennen der Herkunft, Addon-Teile, Blizzard-Teile, verschiebbarer Verkaufspreis (Münzanzeige wandert mit), Trennlinie/Leerraum, Rahmenfarbe nach Qualität, `/ttp teile`.

- Neue Datei `Items.lua`; geändert: `Tooltip.lua` (Einstellungen, `/ttp teile`, Bereiche für Feedback), `Style.lua` (Rahmenfarbe), `Options.lua` (Abschnitt und Liste), `Locales.lua`.
- Neue Einstellungen in `PeonTooltipDB`: `itemParts`, `itemBorder`, `itemOrder`, `itemHidden`, `itemKnown`, `itemSepId`.
- Test: `tests\test_tooltip_items.lua` (Tooltip-Nachbau mit Zeilen, Hooks, Nachläufen, Aufrufkette).

## 8. Entscheidungen (KarloDerBaer, 06.10.2026)

1. Der Name steht immer fest oben.
2. Ausgeblendete Teile sind ganz weg (kein „Mit Strg alles zeigen“).
3. Trennung optional als eigener Eintrag: sichtbare Trennlinie oder Leerraum.
4. Jedes Peon-Modul ist ein eigener Teil, auch künftige.
5. Alles in einem Zug.
6. Neu: Rahmenfarbe bei Gegenständen wählbar – Standard (Blizzard) oder Qualität des Gegenstands.
7. Kein Prüfschritt vorab; Forever verhält sich bei Tooltips wie Retail. Geprüft wird, wenn etwas nicht klappt (dafür `/ttp teile`).
