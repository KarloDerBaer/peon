# Peon (Kern): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.18.0

Kurz: Neues Beispielfenster `/peon ui` mit allen Bausteinen für ein einheitliches Aussehen der Peon-Fenster im Stil des Auktionshauses. Dazu der Prüfbefehl `/peon ui pruefen`, der ausliest, welche Grafiken Blizzards Fenster wirklich zeigen.

- 0.18.0 (11.11.2026): **Prüfbefehl für das UI-Design** (neue Datei `UIProbe.lua`, Kern-API unverändert 17).
  - `/peon ui pruefen`: prüft rund 130 Atlas-Namen aus Blizzards Code (Datei, Größe, Ausschnitt, fehlt), rund 40 Schrift-Objekte (Schrift, Größe, Farbe, Schatten), rund 40 Vorlagen (als eigene, versteckte Rahmen angelegt) und alle gerade offenen Blizzard-Fenster aus einer festen Liste (Auktionshaus, Berufe, Einstellungen, Charakter, Dungeonbrowser und weitere).
  - `/peon ui pruefen maus`: der Rahmen unter der Maus samt Eltern-Kette und Kindern (die letzten 10 bleiben gespeichert).
  - `/peon ui pruefen <Pfad>`: ein Rahmen, zum Beispiel `AuctionHouseFrame.CategoriesList`. `/peon ui pruefen leeren` löscht alles.
  - Je Grafik: Atlas, Datei, Ausschnitt, Farbe, Deckkraft, Ebene, Größe, Anker. Je Schrift: Schrift-Objekt, Datei, Größe, Farbe, Schatten, Ausrichtung, Text. Je Rahmen: Typ, Vorlage (`layoutType`), Hintergrund (`backgroundAtlas`), Größe, Anker, gesperrt.
  - Ergebnis in `PeonDB.uiProbe` (nach `/reload` in WTF). Nur lesen, Blizzards Rahmen werden nicht verändert.
  - Grund: In Forever („Camelot“ in Blizzards Code) liegen unter denselben Atlas-Namen teils eigene Grafiken. Broker 0.56 bis 0.58 hat deshalb dreimal falsch geraten.
  - Von KarloDerBaer im Spiel ausgeführt (Auktionshaus, Berufe). Ergebnis in `docs/konzepte/Peon_UI_Design.md` Abschnitt 2 und 3.
  - **Bausteine, Kern-API 18** (neue Datei `UIKit.lua`, `Peon.UI`, freigegeben von KarloDerBaer nach drei Tests im Spiel): Fenster mit rundem Bild, Reiter unten mit Zahl am Reiter, Reiter oben, Beschriftung über einem Bereich, Bereich mit Hintergrund in Originalgröße, Texte nach Rolle, Trennlinie, Knöpfe (normal, Gold, gesperrt, Symbol, Neu laden), Eingaben (Text, Zahl, Geld), Suchleiste, Auswahlliste, Filter, Haken, Schieberegler (zwei Arten), Formularzeile, Liste mit Kopf, Sortierung, Streifen, Auswahl, Bildlauf (Blizzards ScrollBox), leerer Liste und Ladeanzeige, Kategorieliste mit drei Stufen, Statuszeile, Gegenstand klein und groß, Tooltip, Rückfrage, Fortschritt, einklappbare Überschrift. Alle Maße und Grafiken aus der Messung.
  - **Beispielfenster** `/peon ui` (neue Datei `UIDemo.lua`): Seiten Grundlagen, Bedienelemente, Listen, Aufbau mit Testdaten und verschiedenen Zuständen. Der gewählte Reiter wird in `PeonDB.uiDemoTab` gemerkt.
  - Regeln und Maße: `docs/konzepte/Peon_UI_Design.md` (Entwurf).
  - Nach dem ersten Test von KarloDerBaer (11.11.2026): Reiter mit sauberem Abstand (Breite Text + 40, Abstand 3), Zahl am Reiter im Reiter neben dem Text (oben war sie vom Fensterrahmen verdeckt), Rückfrage als kleines Fenster (Blizzards Dialograhmen füllt seinen Elternrahmen, vorher den ganzen Bildschirm), Hintergründe passen sich dem Bereich an (abschneiden statt über den Rand, dehnen statt mitten im Bereich enden), Kategorieliste mit Innenabstand wie Blizzard, Sortierpfeil zeigt bei aufsteigender Sortierung nach oben.
  - Nach dem zweiten Test (11.11.2026): Kategorien klappen auf und zu wie im Auktionshaus (Klick öffnet, erneuter Klick schließt), nur noch der moderne Schieberegler (Wahl von KarloDerBaer), Fortschrittsbalken wie Blizzards Balken beim Herstellen mit Knopf „Abspielen“. Die Grafiken des Balkens prüft `/peon ui pruefen` jetzt mit.
  - Nach dem dritten Test (11.11.2026): Hinter der Bildlaufleiste der Kategorien liegt kein Hintergrundbild mehr, dort ist wie bei Blizzard das hellere Grau des Fensters zu sehen. Gemessen mit `/peon ui pruefen maus`: die Leiste selbst war bei beiden gleich.
  - **Im Spiel prüfen:** `/peon ui`, alle vier Seiten. Passt der Look zum Auktionshaus? Regler A oder B? Fortschritt, einklappbare Überschrift, Rückfrage und Zahl am Reiter. Sortieren, Auswahl, Bildlauf, Kontextmenü, Kategorien und Suche auf der Seite Aufbau.

## 0.17.0

Kurz: Grundlage für Listen im Aussehen des Blizzard-Auktionshauses.

- 0.17.0 (10.11.2026): **Listen wie im Auktionshaus, API 17** (für Broker 0.56).
  - `Peon.NewList` mit `style = "ah"`: Spaltenköpfe wie in Blizzards Listen, Zeilen mit Streifen, Markierung und Hervorhebung des Auktionshauses, größere Schrift (`Number14FontWhite`). Ohne die Grafiken Rückfall auf schlichte Farben.
  - `flex = Spaltenname` und `list:SetSize(breite, hoehe)`: Die Spalte wächst mit der Breite, die Zahl der Zeilen folgt der Höhe (fehlende Zeilen werden angelegt, überzählige verborgen).
  - Bestehende Listen ohne die neuen Angaben sehen aus wie bisher.

## 0.16.1

Kurz: Behebt ein Einfrieren des Spiels, wenn ein Diagramm ohne Hilfslinien gezeichnet wurde (Broker-Tooltip mit Umschalt).

- 0.16.1 (09.11.2026, gemeldet von KarloDerBaer: Spiel friert beim erweiterten Tooltip ein, BugGrabber „insecure scripts exceeded execution limit“): `Peon.NiceRange` teilte bei `steps = 0` (Diagramm mit `grid = 0`) durch 0, die Schleife `while b < hi` endete nie. Jetzt mindestens 1 Schritt, ungültige Schrittweite gibt den Bereich unverändert zurück, die Schleife hat eine Obergrenze. `grid = 0` zeichnet keine Hilfslinien.

## 0.16.0

Kurz: Strg+Rechtsklick auf einen Gegenstand öffnet jetzt ein Menü mit Einträgen der Peon-Module, zum Beispiel „Auf Einkaufsliste“. Die Taste lässt sich auf der Peon-Seite der Einstellungen ändern.

- 0.16.0 (09.11.2026): **Gegenstandsmenü, API 16** (Konzept `docs/konzepte/broker/Peon_Broker_Umbau.md`, Abschnitt 9). Neue Dateien `ItemMenu.lua` und `Bindings.xml`.
  - `Peon.AddItemMenu(addon, fn(root, item), order)`: Module hängen Einträge an (`item = { id, link, name }`), zwischen Modulen eine Trennlinie. `Peon.OpenItemMenu(item, owner)`, `Peon.ItemMenuEntries()`.
  - Erkennung wie Ledgers Alt+Klick: Mausklick (`GLOBAL_MOUSE_DOWN`) und Gegenstand im sichtbaren Tooltip, dazu `HandleModifiedItemClick` für Links. Nicht auf Aktionsleisten. Menü über `MenuUtil.CreateContextMenu`.
  - Klick einstellbar auf der Peon-Seite (`PeonDB.itemMenuClick`, Standard Strg+Rechtsklick, auch Alt+Rechts, Umschalt+Rechts, Strg+Mitte, Mitte, aus). Umschalt+Rechtsklick ist bei Blizzard belegt (Stapel teilen, mehrere Stapel kaufen), das steht dabei.
  - Tastenbelegung „Peon: Gegenstandsmenü für den Gegenstand unter der Maus“ (`PEON_ITEM_MENU`).
  - **Im Spiel prüfen:** Strg+Rechtsklick in Taschen, Bank, beim Händler, auf Questbelohnungen und Chat-Links. Löst Blizzard dabei noch etwas anderes aus? Auswahl auf der Peon-Seite der Einstellungen.

## 0.15.0

Kurz: Grundlage für die neuen Einträge von Peon_Panel.

- 0.15.0 (07.11.2026): API 15. `mod:AddLauncher` legt weitere Starter eines Moduls an, neue Felder `onWheel` (Mausrad) und `available` (gerade nicht anzeigen), dazu `Launcher:IsAvailable` und `Launcher:Wheel`. Vorhandenes bleibt unverändert.

## 0.14.0

Kurz: Grundlage für das neue Addon Peon_Panel.

- 0.14.0 (07.11.2026): API 14. Neue Datei `Launcher.lua`: Starter (`mod:NewLauncher`, `Peon.GetLaunchers`, `Peon.OnLauncherAdded`, `Peon.OnLauncherRefresh`), den `mod:NewMinimapButton` selbst anlegt, und kurze Zahlen (`Peon.ShortNumber`, `Peon.ShortGold`).
  - Der Kern merkt sich in `PeonDB.panelHid`, welche Minimap-Buttons Peon_Panel ausgeblendet hat, und schaltet sie wieder ein, wenn Panel beim Login nicht geladen ist.
  - **Im Spiel prüfen:** Peon_Panel abschalten, die Buttons sind danach wieder da. Selbst ausgeblendete bleiben aus.

## 0.13.0

Kurz: Der Manager kennt jetzt die Bereiche aller Module für Rückmeldungen.

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
