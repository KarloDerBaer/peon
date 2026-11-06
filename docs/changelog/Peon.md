# Peon (Kern): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.13.0

- 0.13.0 (06.11.2026, Wunsch KarloDerBaer): API 13 – `Peon.SaveFeedbackAreas()`: Der Kern legt beim Einloggen alle gemeldeten Bereiche in `PeonDB.feedbackAreas` ab, damit der Peon Manager sie in seinem Formular anbieten kann. Bestehendes unverändert.
  - **Im Spiel prüfen:** Nach einem `/reload` bietet der Manager unter „Rückmeldungen“ die Bereiche der Module an.

## 0.12.0

- 0.12.0 (06.11.2026, Wunsch KarloDerBaer, Anlass: Fehler von Peon_Tooltip im Dungeon, der nirgends gespeichert war): API 12 – **Fehlerspeicher.** Abgefangene Fehler aller Module (`mod:ReportError`, `mod:Call`) und des Kerns stehen jetzt in `PeonDB.errors` (Addon, Bereich, Text, Version, Build, erstes und letztes Auftreten, Anzahl, höchstens 100, gleiche Fehler zählen hoch). Im Chat steht nur noch einmal pro Sitzung ein kurzer Hinweis. Neu: `Peon.RecordError`, `Peon.ClearErrors`, `Peon.ReportCoreError`, Befehl `/peon fehler` (Text zeigen) und `/peon fehler leeren`. Geheime Fehlertexte werden nicht mehr ausgewertet. Bestehendes bleibt nutzbar, nur der Chat-Text von `ReportError` ist kürzer.
  - **Im Spiel prüfen:** Löst ein Modul einen Fehler aus, zeigt `/peon fehler` den vollen Text, auch nach `/reload`.

## 0.11.1

- 0.11.1 (05.11.2026): Diagramm: Ein Wert ohne Nachbarn erscheint bei Linien und Stufenlinien als Punkt. Eine Linie braucht zwei Punkte, deshalb blieb das Diagramm am ersten Tag mit Daten leer (gesehen in Ledger). API unverändert. **Im Spiel prüfen:** Punkte im Ledger-Reiter „Gegenstand“.

## 0.11.0

- 0.11.0 (07.10.2026, Wunsch KarloDerBaer für die Tooltip-Optionen): API 11 – **Untertabs auf Optionsseiten**: `page:Tabs({ { key, Text }, … }, y)` (Reiterleiste oben, `PanelTopTabButtonTemplate`, Rückfall normale Knöpfe), `page:Column(x, y, reiter)` (Spalte gehört zu einem Reiter; ohne Reiter immer sichtbar), `page:SelectTab(key)`, `page:GetTab()`, `page.onTab(page, key)`. Bausteine einer Reiter-Spalte hängen an einem Haltefenster je Reiter (eigenes Ein-/Ausblenden eines Bausteins bleibt erhalten); der Reset-Knopf steht unter der tiefsten sichtbaren Spalte. Diagramm-Legende: bei mehreren Reihen mit demselben Schlüssel gewinnt die Reihe mit Beschriftung (vorher die letzte – Ledger zeigte „zone“ statt „Gewinnzone“). Bestehendes unverändert.

## 0.10.0

- 0.10.0 (06.10.2026, Konzept `Peon_Ledger_Gegenstand.md` G1): API 10 – **Diagramm-Baustein** `Peon.NewChart` (neue Datei Chart.lua): Linien (gestrichelt, Lücken überbrücken), Stufenlinien, Fläche zwischen zwei Linien (Band; Gewinnzone zweifarbig je Abschnitt, Trapez über `SetVertexOffset`), Balken (auch unter 0 in eigener Farbe), Punkte (Kreis/Quadrat), senkrechte Markierungen, waagerechte Linie, zwei Achsen mit schönen Grenzen (`Peon.NiceRange`) und eigener Beschriftung, Mauslinie mit `onHover(index)`, Legende mit Knöpfen an/aus (`ch:CreateLegend`), `ch:SetSize`, verknüpfte Diagramme (`Peon.LinkCharts`: gemeinsame Mauslinie, gleicher Bereich links). Linien über `CreateLine` (Rückfall ohne: kleine Kästchen). Bereich „Diagramm“ für Peon_Feedback. Bestehendes unverändert. **Im Spiel prüfen:** ob `CreateLine` und `SetVertexOffset` in Forever gehen (Linien glatt, Gewinnzone als Fläche statt Treppe).

## 0.9.0

- 0.9.0 (02.10.2026): API 9 – Bereiche für Rückmeldungen: `Peon.SetFeedbackAreas(ADDON_NAME, { … })` und `Peon.GetFeedbackAreas(ADDON_NAME)` (Kopie der Liste; doppelte, leere und falsche Einträge werden entfernt). Der Kern meldet eigene Bereiche (Einstellungsseite, Bausteine, Liste, Minimap-Button, Debug-Log, Chatbefehle). Neue Datei Feedback.lua, bestehendes unverändert.

## 0.8.0

- 0.8.0 (01.10.2026): API 8 – Liste mit Zeilenfarbe (`rowColor = function(item) return r, g, b, a end`, `list:UpdateColors()` nur für die Farben, z. B. zum Pulsieren). Bestehendes unverändert.

## 0.7.0

- 0.7.0 (29.09.2026): API 7 – Liste mit Spalten, Sortierung und Bildlauf (`Peon.NewList`, `page:List`), Minimap-Button (`mod:NewMinimapButton`). Fishing behält vorerst seinen eigenen Minimap-Button.

## 0.6.0

- 0.6.0 (29.09.2026): API 6 – Auswahlliste `page:Dropdown` (neue Menü-API, Rückfall UIDropDownMenu, dann Knopfreihe; Liste auch per Funktion; eigene get/set).

## 0.5.0

- 0.5.0 (29.09.2026): API 5 – Button, Text, Check mit Hinweis und eigenen Werten, Neuanordnung beim Refresh, `opts.keepOnReset`.
