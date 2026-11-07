# Peon_Tooltip: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.7.5

Kurz: In Dungeons kommt beim Rahmen des Tooltips keine Fehlermeldung mehr.

- 0.7.5 (07.11.2026, Fehlerbericht von KarloDerBaer über den Manager, 1796× nach dem Betreten eines Dungeons): `Style.lua:79: bad argument #1 to 'UnitSelectionColor' (... Secret values are only allowed during untainted execution for this argument.)`.
  - Ursache: In Instanzen liefert `GetUnit` die Einheit des Tooltips als geheimen Wert. Für die Rahmenfarbe wurde sie trotzdem an `UnitSelectionColor` weitergegeben, und das lehnt geheime Einheiten ab, wenn der Aufruf von einem Addon kommt.
  - Jetzt: Ist die Einheit geheim, bleibt der Rahmen in der Standardfarbe (wie schon bei Spielerinfos und Symbolen in `Units.lua` und `Icons.lua`). Außerhalb von Instanzen bleibt alles wie bisher.
  - Test: `test_tooltip_items.lua` Abschnitt 17 (mit dem alten Code schlägt er fehl).
  - **Im Spiel prüfen:** in einem Dungeon Gegner überfahren, keine neuen Meldungen „Border“, Rahmen dort in Standardfarbe.

## 0.7.4

Kurz: Der Tooltip von Objekten wie Briefkästen verschwindet jetzt sofort, wenn die Maus sie verlässt.

- 0.7.4 (05.11.2026, Wunsch von KarloDerBaer): Die Ausblendzeit gilt jetzt auch für Objekte in der Welt (z. B. Briefkasten), nicht nur für Einheiten. Standard also auch dort sofort. Erkannt über Blizzards Aufruf von `FadeOut` in `SetWorldCursor`, wenn die Maus das Objekt verlässt.
  - **Im Spiel prüfen:** Tooltip von Briefkasten oder Kräutern verschwindet sofort, kehrt beim erneuten Überfahren zurück und ist dann voll sichtbar.

## 0.7.3

- 0.7.3 (05.11.2026, Wünsche von KarloDerBaer aus dem ersten Test in Forever):
  - **Abstand zum Mauszeiger:** Standard 40 statt 20, für X und Y.
  - **Ausblenden:** Standardmäßig verschwindet der Tooltip von Einheiten in der Welt sofort, wenn die Maus sie verlässt (`fadeCustom` an, `fadeTime` 0). Einstellbar im Reiter „Gegner“ unter „Ausblenden“. Für Objekte ohne Einheit (z. B. Briefkasten) bleibt Blizzards Ausblenden.
  - **Umstellung:** Wer noch die alten Standardwerte gespeichert hat (Abstand 20/20, eigene Ausblendzeit aus mit 0,2 Sek.), bekommt einmalig die neuen. Selbst gewählte Werte bleiben.
  - **Im Spiel prüfen:** Tooltip verschwindet sofort beim Verlassen eines Gegners, kein Flackern beim Wechsel von Gegner zu Gegner.

## 0.7.2

- 0.7.2 (23.10.2026, Fehler von KarloDerBaer, 57× im BugGrabber): `Items.lua:297: attempt to index local 'st' (a secret string value, while execution tainted by 'Peon_Tooltip')`.
  - Ursache: Für jede neue Tooltip-Zeile liest Peon_Tooltip die Aufrufkette (`debugstack`), um das Addon zu erkennen. Forever liefert diesen Text in manchen Lagen (Kampf, Instanz, Tooltip mit geheimen Daten) als geheimen Wert. `type()` meldet dann trotzdem „string“, Durchsuchen (`gmatch`) bricht ab.
  - Jetzt: geheime Aufrufkette wird erkannt (`Peon.IsSecret`), die Herkunft gilt als unbekannt und dieser Tooltip wird nicht geordnet (bleibt so, wie Blizzard und die Addons ihn aufgebaut haben). Der nächste Tooltip wird wieder normal geordnet.
  - Test: `test_tooltip_items.lua` Abschnitt 16 (mit dem alten Code schlägt er fehl).
  - **Im Spiel prüfen:** keine neuen Meldungen im BugGrabber; Tooltips im Kampf/in Instanzen erscheinen ungeordnet, sonst wie gewohnt.

## 0.7.1

- 0.7.1 (22.10.2026, Fehler und Wunsch von KarloDerBaer, Screenshot Auktionshaus):
  - **Maximale Breite mit Zeilenumbruch** für Gegenstands-Tooltips (Reiter Gegenstände): „Lange Zeilen umbrechen“ (Standard an) und „Maximale Breite“ (250–800 Punkte, Standard 450). Zu lange einfache Zeilen bekommen Zeilenumbrüche an Leerzeichen; Doppelzeilen und Zeilen mit Links bleiben unverändert, geheime Texte werden nicht angefasst. Gilt auch bei ausgeschaltetem „Teile ordnen“.
  - **Flackern im Auktionshaus behoben (vermutete Ursache):** Nach dem Umschreiben der Zeilen wurde ein langer Set-Bonus im Vergleichs-Tooltip nicht mehr umgebrochen (Tooltip über 1000 Punkte breit). Neben dem Gegenstands-Tooltip war dann kein Platz, Blizzard schiebt den Gegenstands-Tooltip deshalb nach links (`TooltipComparisonManager:AnchorShoppingTooltips`). Das Auktionshaus baut den Tooltip alle 0,2 Sek. neu auf (`GameTooltip_Hide` + `SetOwner`), dabei springt er kurz an die alte Stelle zurück. Mit normaler Breite passt der Vergleich daneben, es wird nichts verschoben.
  - Technik: `WrapLines` am Ende von `Arrange` (auch wenn nichts umzustellen ist), Messen mit einer unsichtbaren Schrift-Zeile in der Schrift der jeweiligen Zeile; neue Einstellungen `itemWrap`, `itemMaxWidth`. Tests in `test_tooltip_items.lua` (Abschnitt 15).
  - **Im Spiel prüfen:** kein Flackern mehr bei „Handschuhe des Riesenjäger“ im Auktionshaus; Vergleichs-Tooltip mit Defias-Handschuhen schmal und umgebrochen; Farbe der umgebrochenen Zeilen bleibt erhalten; Breite in den Optionen passend (Beispiel-Tooltip).

## 0.7.0

- 0.7.0 (07.10.2026, Wünsche und Fehler von KarloDerBaer, Tabs abgestimmt; braucht für die Reiter Kern API 11, sonst eine Seite wie bisher):
  - **Flackern bei ausrüstbaren Gegenständen behoben** (Vergleichs-Tooltip): Blizzard baut den Gegenstands- und den Vergleichs-Tooltip alle 0,2 Sek. neu auf (`GameTooltip_OnUpdate` → `UpdateTooltip`) und hängt die Vergleichszeilen („Wenn Ihr diesen Gegenstand ersetzt …“, `TooltipComparisonManager`) erst nach dem Gegenstands-Nachlauf an. Peon_Tooltip ordnete solche späten Zeilen erst im nächsten Bild – 5× je Sekunde war ein Bild lang die falsche Reihenfolge (mit Lücken) zu sehen. Jetzt: späte Zeilen werden sofort geordnet, sobald der Tooltip gezeigt wird (`Show`/`SetShown` mitgelesen; Rückfall weiter nächstes Bild). Späte Zeilen von Blizzard selbst sind ein eigener Teil „Blizzard: Vergleich“, immer ganz unten. Gefunden im Blizzard-Code der Forever-Version (siehe Überblick).
  - **Optionen mit Reitern** Allgemein (Position, Aussehen, Kampf) / Gegner (Rahmenfarbe, Spielerinfos, Ausblenden, Symbole) / Gegenstände (Rahmenfarbe, Teile).
  - **Beispiel-Tooltips** in den Reitern Gegner (dein Ziel, sonst du selbst; wechselt mit dem Ziel) und Gegenstände (eigene Gegenstände – angelegt, Waffe zuerst, dann Taschen – mit Pfeilen umschaltbar, „Neu laden“). Sie laufen durch dieselben Anpassungen wie der echte Tooltip (Größe, Hintergrund, Rahmen, Spielerinfos, Symbole, Teile) und werden bei jeder Änderung neu aufgebaut.
  - Technik: Beispiele sind eigene `GameTooltipTemplate`-Tooltips (`PeonTooltipPreviewUnit/Item`), `ns.IsMainTip(tt)` lässt Symbole und Spielerinfos auch dort wirken.
  - **Im Spiel prüfen:** kein Flackern mehr beim Vergleich (auch mit Umschalt), Vergleichszeilen unten; Reiter oben auf der Optionsseite; Beispiel-Tooltips sichtbar und nicht abgeschnitten.

## 0.6.0

- 0.6.0 (06.10.2026, Konzept `Peon_Tooltip_Konzept.md`, mit KarloDerBaer abgestimmt; **WoW komplett neu starten** – neue Datei Items.lua):
  - **Teile im Gegenstands-Tooltip ordnen und ausblenden** (Abschnitt „Gegenstands-Tooltip“ in den Optionen): Liste aller Teile mit Haken „anzeigen“ (aus = ganz weg), Pfeilen hoch/runter, Klick wählt eine Zeile; „Name (immer oben)“ fest. Blizzard-Teile: Bindung/Typ/Werte, Haltbarkeit, Anforderungen, Effekte, Set, Beschreibung, Verkaufspreis (Münzanzeige wandert mit). Jedes Addon ist ein eigener Teil, auch jedes Peon-Modul; neue Addons erscheinen von selbst, sobald sie in einen Gegenstands-Tooltip schreiben, nicht geladene grau mit Entfernen-Knopf.
  - **Trennlinie / Leerraum** als eigene Einträge (unter der gewählten Zeile), verschiebbar und entfernbar; nur zwischen sichtbaren Teilen.
  - Hauptschalter „Teile ordnen“ (Standard an), „Reihenfolge zurücksetzen“. Ohne eigene Einstellungen bleibt der Tooltip wie bisher.
  - **Rahmenfarbe bei Gegenständen:** „Standard (Blizzard)“ oder „Qualität des Gegenstands“ (Qualität aus dem Link `|cnIQ…:`, sonst `C_Item`).
  - Gilt für Spiel-Tooltip, Chat-Link-Tooltip und Vergleichs-Tooltips; nach Umschalt (Broker/Ledger bauen neu auf) wird neu geordnet, spät geschriebene Zeilen werden nachträglich eingeordnet.
  - Technik: Herkunft jeder Zeile über die Aufrufkette (`debugstack`, erstes Addon ohne Peon_Tooltip und Blizzard_*), Blizzard-Zeilen und ihre Art über `TooltipDataProcessor.AddLinePostCall`; Ordnen im Gegenstands-Nachlauf, der beim Einloggen angemeldet wird (= nach allen anderen Addons); Texte, Farben, Schrift und Umbruch werden in die vorhandenen Zeilen umgeschrieben, überzählige geleert. Geheime Texte: nichts wird angefasst.
  - Neue Einstellungen: `itemParts`, `itemBorder`, `itemOrder`, `itemHidden`, `itemKnown` (bleibt bei „Standardwerte“), `itemSepId`. Bereiche für Peon_Feedback: zusätzlich „Gegenstands-Tooltip“ und „Rahmenfarbe“.
  - Ohne Prüfschritt vorab gebaut (KarloDerBaer: Forever verhält sich bei Tooltips wie Retail). **Im Spiel prüfen:** Stimmt die Einteilung (`/ttp teile`)? Erkennt es BagBrother, AtlasLoot, AtlasBIStooltips, ItemTooltipProfessionIcons, Broker, Ledger? Werden ausgeblendete Zeilen sauber entfernt (keine Lücken)? Verkaufspreis mit Münzen beim Verschieben? Trennlinie sichtbar?

## 0.5.3

- 0.5.3 (02.10.2026): meldet Bereiche für Peon_Feedback (Position, Aussehen, Spielerinfos, Kampfmodus, Symbole, Optionen); eine Zeile am Ende von Tooltip.lua, sonst unverändert.

## 0.5.2

- 0.5.2 (29.09.2026): Rahmenfarbe und Kampfmodus als Auswahllisten.
