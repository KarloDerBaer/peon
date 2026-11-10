# Peon_Broker: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.56.0

Kurz: Das Auktionshaus ist aufgeräumt: Reiter mit gleichen Abständen wie bei Blizzard, Einkaufen und Radar im Aufbau von Blizzards Fenstern (links Einstellungen, rechts die Liste), der Rat beim Verkaufen ist ganz lesbar, und beim Kauf von Massenware steht, was ein Weiterverkauf zum nächsten Preis bringen würde.

- 0.56.0 (10.11.2026, Rückmeldung von KarloDerBaer nach dem Test im Spiel, braucht Peon 0.17 für die Listen-Optik):
  - **Reiter im Auktionshaus:** Broker misst den sichtbaren Abstand zwischen Blizzards Markt und Verkaufen und setzt Einkaufen, Radar und Auktionen genauso (`T.AlignTabs`, nach dem Öffnen und wenn sich eine Zahl am Reiter ändert). Grundabstand jetzt wie bei Blizzard (-15).
  - **Einkaufen und Radar im Blizzard-Aufbau** (neue Datei `Look.lua`): oben eine Leiste wie Blizzards Suchleiste (Einkaufen: Hinzufügen und „Liste durchsuchen“, Radar: Stand und „Radar-Scan starten“), links eine Spalte mit allen Einstellungen, rechts die Liste in Blizzards Optik, die den Platz ausfüllt. Radar: Anzeige, Reihenfolge, Mindestgewinn Händler und Auktionshaus, Nur Warnton, Ausblenden und Schnellkauf links, Kaufzeile unter der Liste. Einkaufen: Listen, Name, Höchstpreis der Liste, gewählter Gegenstand (Höchstpreis, Menge, Entfernen) und Vorrat aller Charaktere links, Kaufen unter der Liste.
  - **Radar ohne Hänger beim Wechsel:** Die Treffer werden nur neu aus der Datenbank geladen, wenn es einen neuen Scan gibt, die Altersgrenze geändert wurde oder der letzte Stand älter als 2 Minuten ist (`R.LoadIfStale`). Vorher ging jeder Wechsel auf den Reiter alle Gegenstände des Marktes durch.
  - **Rat beim Verkaufen** ohne Rahmen und ohne Überschrift „Broker“, dichter unter „Auktion erstellen“, damit der Text nicht mehr abgeschnitten wird.
  - **Weiterverkauf beim Kauf von Massenware** (neue Datei `Resale.lua`): Unter „Kaufen“ steht, was man verdient oder verliert, wenn man die gewählte Menge kauft und zum günstigsten verbleibenden Angebot wieder einstellt, nach dem Anteil des Hauses. Sicherer Anhang an `SetPrice` der Kaufanzeige, Broker liest nur.
  - **Im Spiel prüfen:** Abstände der fünf Reiter (auch mit Zahl am Radar), Einkaufen und Radar bei verschiedener Fenstergröße, Wechsel auf Radar ohne Hänger, Weiterverkauf bei Leinenstoff und Co., Rat beim Verkaufen vollständig lesbar.

## 0.55.0

Kurz: Aufgeräumt: Die alten Reiter Verkaufen, Behalten und Meine Auktionen sind ganz entfernt, ebenso deine Behalten-Liste. Verkaufen und Auktionen laufen über Blizzards Fenster mit Brokers Rat.

- 0.55.0 (09.11.2026): **Umbau U12, Aufräumen Teil 2** (mit Zustimmung von KarloDerBaer).
  - `Sell.lua` und `Keep.lua` entfernt. Ihre Bausteine liegen in `Live.lua` (Live-Ergebnisse lesen: `ReadCommodity`, `ReadItems`, `IsFull`, `RequestMore`, `Foreign`, `KeyText`) und `Stock.lua` (Vorrat zählen mit Taschen, Bank und auf Wunsch Twinks aus Ledger). Rat beim Verkaufen, Einkaufen, Radar, Auktionen, Info, Marktvergleich und Berufsfenster nutzen sie weiter.
  - `Auctions.lua` behält nur Lesen, Bewerten und Live-Prüfung der eigenen Auktionen (für Blizzards Reiter Auktionen). Abbrechen, „Nächste unterbotene“ und „Neu einstellen“ der alten Oberfläche entfallen, dafür gibt es Blizzards Knöpfe.
  - **Gelöscht beim Anmelden:** die Behalten-Liste je Charakter (`PeonBrokerCharDB.keep`) und das Gedächtnis des alten Reiters Verkaufen (`PeonBrokerDB.sellMem`).
  - Option „Nur lohnende im Reiter Verkaufen“ entfernt.
  - Tests der alten Oberflächen entfernt, die Bausteine sind weiter geprüft.

## 0.54.0

Kurz: Im Auktionshaus liegen Radar und Einkaufen nicht mehr übereinander. Die Reiter heißen und stehen jetzt: Markt (bisher Kaufen), Verkaufen, Einkaufen, Radar, Auktionen.
Kurz: Das Broker-Fenster hat die Reiter Markt, Marktvergleich, Händler, Einkaufsliste, Beobachten, Info und Quellen. Markt und Info sind noch in Arbeit.

- 0.54.0 (09.11.2026, nach dem Test von KarloDerBaer):
  - **Auktionshaus:** Beim Wechsel zwischen Radar und Einkaufen blieb die vorige Fläche sichtbar, daher überlagerten sich Texte und Knöpfe. Jetzt wird die andere umgehängte Fläche versteckt. Fläche mit undurchsichtigem Grund (Blizzards Hintergrund ließ etwas durchscheinen).
  - **Reihenfolge im Auktionshaus:** Markt, Verkaufen, Einkaufen, Radar, Auktionen. Blizzards „Auktionen“ wird nur neu verankert, „Kaufen“ bekommt den Text „Markt“ (keine Einträge in Blizzards Tabellen).
  - **Broker-Fenster:** Reiter Markt (neu, WIP: soll wie Blizzards Kaufen mit Kategorien auf Basis der Scandaten werden), Marktvergleich (bisher Markt), Händler, Einkaufsliste, Beobachten, Info (bisher Gegenstände, WIP, wird neu gestaltet), Quellen. Ein gemerkter Reiter ohne Knopf öffnet Markt.
  - **Im Spiel prüfen:** Reiter im Auktionshaus, Wechsel Radar und Einkaufen, Reiter im Broker-Fenster.

## 0.53.1

Kurz: Behebt das Einfrieren des Spiels beim erweiterten Tooltip (mit Umschalt).

- 0.53.1 (09.11.2026, gemeldet von KarloDerBaer): Das Preisdiagramm im Tooltip (0.47.0) nutzte `grid = 0`, damit hing der Diagramm-Baustein des Kerns bis Peon 0.16.0 in einer Endlosschleife. Broker nutzt jetzt `grid = 1`, der Kern ist mit Peon 0.16.1 ebenfalls abgesichert.

## 0.53.0

Kurz: Aufgeräumt: Die Startseite, die Zeile „Behalten“ im Tooltip und das Andocken des Broker-Fensters am Auktionshaus sind weg. Das Fenster bleibt dort, wo du es hingeschoben hast, und öffnet und schließt sich nicht mehr mit dem Auktionshaus.

- 0.53.0 (09.11.2026): **Umbau U12, Aufräumen Teil 1** (Konzept Abschnitt 13).
  - `Start.lua` entfernt (Startseite, seit 0.51 ohne Reiter).
  - Andocken ans Auktionshaus und Einstellung „Broker-Fenster mit dem Auktionshaus öffnen“ (`windowWithAH`) entfernt.
  - Zeile „Behalten“ im Tooltip entfernt. Die gespeicherte Behalten-Liste (`PeonBrokerCharDB.keep`) bleibt vorerst unangetastet.
  - Bereiche für Rückmeldungen nach dem neuen Aufbau (Verkaufen (Rat), Auktionen, Radar, Einkaufen, Einkaufslisten, Beobachtung, Markt, Händler, Gegenstände, Quellen, Berufe, Scan, Tooltip, Gegenstandsmenü, Optionen).
  - Noch da: die Oberflächen der früheren Reiter Verkaufen, Behalten und Meine Auktionen (ohne Reiter). Ihre Bausteine (Live-Ergebnisse lesen, Vorrat zählen, eigene Auktionen lesen) brauchen Rat, Einkaufen, Radar und Auktionen weiter.

## 0.52.0

Kurz: Broker merkt sich jetzt alles, was du bei Händlern siehst: Ware, Preis (auch in Abzeichen oder Marken), begrenzte Menge, Voraussetzungen wie Ruf und den Ort. Der neue Reiter „Händler“ zeigt die Liste mit dem Preis im Auktionshaus, der Tooltip auf Wunsch den günstigsten Händler.

- 0.52.0 (09.11.2026): **Umbau U11, Händler** (Konzept Abschnitt 8.4). Neue Datei `Vendors.lua`.
  - Beim Öffnen eines Händlers (und bei Änderungen, höchstens alle 2 Sek.) liest Broker alle Angebote: Preis je Stück in Gold, Stück je Kauf, andere Währung oder Gegenstände (`GetMerchantItemCostInfo/Item`), begrenzte Menge, Voraussetzungen (rote Zeilen im Tooltip des Angebots), dazu Name, NPC-Nummer (aus der GUID), Zone und Koordinaten. Gespeichert in `PeonBrokerDB.vendors[npcID]`. Der Kaufpreis für das Berufsfenster (`merchant`) bleibt wie bisher.
  - **Reiter „Händler“** im Broker-Fenster: Suche, „Nur mit AH-Gewinn“, Spalten Preis, Händler, Zone, Braucht, AH (grün mit „+“, wenn das Auktionshaus nach Anteil mehr bringt). Klick zeigt den Gegenstand.
  - **Tooltip-Baustein „Beim Händler“:** günstigster Händler mit Preis, Name und Zone (Standard mit Umschalt).
  - Quellen nennen Zahl der Händler, Angebote und den ältesten Besuch.
  - Der Peon Manager liest die Händler aus `Peon_Broker.lua` (Manager 0.25.0), die Bridge braucht dafür nichts.
  - **Im Spiel prüfen:** einige Händler öffnen (auch einen Rüstmeister mit Ruf und Marken), dann Reiter Händler und Tooltip mit Umschalt.

## 0.51.0

Kurz: Das Broker-Fenster enthält jetzt nur noch, was ohne Auktionshaus geht: Einkaufslisten, Markt, Gegenstände, Beobachtung und Quellen. Verkaufen, Auktionen und Radar findest du im Auktionshaus selbst.
Kurz: Neu sind der Vergleich deiner Fraktion mit dem neutralen Auktionshaus (Reiter Markt) und bei jedem Gegenstand dein Bestand mit Kosten aus Ledger.

- 0.51.0 (09.11.2026): **Umbau U10, Broker-Fenster neu** (Konzept Abschnitt 8). Neue Datei `Pages.lua`.
  - **Reiter:** Einkaufslisten, Markt, Gegenstände (bisher Preise), Beobachtung, Quellen. Start, Verkaufen, Behalten, Meine Auktionen und Radar haben keinen Reiter mehr. Ihre Seiten bleiben bis U12 angemeldet (das Radar hängt im Auktionshaus). Ein alter gemerkter Reiter öffnet Gegenstände.
  - **Markt:** Datenstand je Markt (Fraktion und Neutral, grün bis 1 Tag, orange älter) und Vergleich Fraktion gegen Neutral nach Gebühr beider Häuser, Filter „Nur Bestand“ und Mindestabstand in %, Klick zeigt den Gegenstand.
  - **Beobachtung:** günstigstes Angebot, Grenze, üblicher Bereich, Alarm, Grenze in Gold änderbar, Info, Entfernen.
  - **Quellen:** Märkte mit Stand, Werte vom Manager (Quelle und Alter), woher üblicher Bereich und Absatz kommen, Anteil der Häuser, Listen, Knopf „An Manager übergeben“ (lädt neu).
  - **Gegenstände:** Abschnitt „Mein Bestand“ mit Peon_Ledger (Vorrat gesamt, Taschen, Bank, Twinks, Kosten je Stück, eigene Verkäufe).
  - Noch nicht: einheitlicher Listen-Stil wie Blizzards Kaufliste und Diagramm in der Gegenstandsansicht (das Diagramm gibt es im Tooltip).
  - **Im Spiel prüfen:** alle fünf Reiter, Vergleich nach einem Scan in Beutebucht, Mein Bestand bei einem Gegenstand mit Vorrat.

## 0.50.0

Kurz: Blizzards Reiter „Auktionen“ zeigt jetzt bei jeder deiner Auktionen, ob sie das günstigste Angebot ist, unterboten wurde oder zu teuer ist. Darüber stehen Anzahl, Unterbotene und Gesamtwert, mit „Prüfen“ fragt Broker alle live ab.

- 0.50.0 (09.11.2026): **Umbau U9, Auktionen** (Konzept Abschnitt 7.3). Neue Datei `AuctionsAH.lua`.
  - **Kopfzeile** über Blizzards Liste (links neben „Neu laden“): laufende Auktionen, davon unterboten, Wert zum Sofortkaufpreis. Knopf **„Prüfen“** startet die Live-Prüfung aller eigenen Gegenstände (`A.StartLive` aus dem bisherigen Reiter Meine Auktionen).
  - **Status je Zeile** rechts in der Gegenstandsspalte: Günstigstes (grün), gleichauf (gelb), unterboten: Preis (orange), zu teuer: üblich (rot, Preis über dem üblichen Bereich), verkauft (grau).
  - Broker schreibt nichts in Blizzards Liste: eine eigene Uhr liest alle 0,3 Sek. die sichtbaren Zeilen (`ScrollBox:ForEachFrame`, `rowData.auctionID`) und setzt eigene Texte. Die eigenen Auktionen liest Broker nach Blizzards Abfrage (`OWNED_AUCTIONS_UPDATED`) mit.
  - Abbrechen und neu einstellen bleiben Blizzards Knöpfe. Bei „Blizzard pur“ nichts davon.
  - **Im Spiel prüfen:** Reiter Auktionen: Sitzt der Status in der Gegenstandsspalte, ohne Namen zu überdecken? Kopfzeile neben „Neu laden“? „Prüfen“ aktualisiert die Angaben?

## 0.49.0

Kurz: Die Einkaufsliste ist zurück und steht auch als Reiter „Einkaufen“ im Auktionshaus. Jede Zeile sagt, ob sich Kaufen lohnt, und die Zahl am Reiter zeigt, wie viel gerade kaufbar ist.
Kurz: Neu ist die Beobachtung mit Preisalarm: Strg+Rechtsklick auf einen Gegenstand, „Beobachten“, Preisgrenze wählen. Fällt der Preis darunter, meldet Broker sich. Im Manager heißen die Favoriten jetzt ebenfalls Beobachtung und werden abgeglichen.

- 0.49.0 (09.11.2026): **Umbau U8, Einkaufslisten und Beobachtung** (Konzept Abschnitte 7.5, 8.2, 8.7). Neue Datei `Watch.lua`.
  - **Einkaufsliste nicht mehr in Arbeit** (WIP aus 0.37 entfernt). Die Menge wirkte schon als Ziel inklusive Vorrat (`B.Plan` kauft höchstens Wunsch minus Vorrat aller Charaktere), neu sind die Spalten **Fehlt** (Ziel minus Vorrat) und **Rat** (KAUFEN, TEILWEISE, ZU TEUER, PRÜFEN, erledigt), sortierbar.
  - **Reiter „Einkaufen“ im Auktionshaus:** dieselbe Fläche, umgehängt wie das Radar. Zahl am Reiter: alle Zeilen aus allen Einkaufslisten und der Beobachtung mit Rat Kaufen oder Teilweise, ohne Blinken, neu nach Scan, Stand vom Manager und Live-Prüfung.
  - **Beobachtung** (`PeonBrokerDB.watch`, Löschmarken `watchGone`): im Gegenstandsmenü „Beobachten“ (Haken) und „Preisgrenze“ (10/20/30 % unter dem Vergleichspreis, jetziger Preis, keine Grenze). In der Einkaufsliste als eigene Liste „Beobachtung“ (nicht löschbar, Grenze über „Max.“ änderbar). Zeichen in Zeile 1 des Tooltips wie bei Einkaufslisten.
  - **Preisalarm:** liegt das günstigste Angebot auf oder unter der Grenze, einmal Meldung im Chat und Ton (Einstellung des Radars), wieder erst nach einem Preis darüber. Geprüft nach Komplettscan, Stand vom Manager und jeder Live-Abfrage.
  - **Abgleich mit dem Manager** (`mod:MergeWatch`, über Bridge 0.9.0): je Gegenstand gewinnt die neuere Änderung, Löschmarken halten. Preisgrenzen bleiben im Spiel.
  - Noch nicht: Liste im Look von Blizzards Kaufliste (U10), „Alles Lohnende kaufen“ als Ablauf, „Material auf Einkaufsliste“ aus dem Berufsfenster.
  - **Im Spiel prüfen:** Reiter Einkaufen im Auktionshaus, Spalten Fehlt und Rat, Kaufen. Beobachten über das Menü, Preisgrenze setzen, Alarm nach einem Scan. Abgleich mit dem Manager (Stern dort, Haken im Spiel).

## 0.48.0

Kurz: Das Radar steht jetzt als eigener Reiter im Auktionshaus. Findet ein Komplettscan Schnäppchen, steht am Reiter die Zahl der Treffer und er blinkt. Mit zwei neuen Tasten kaufst du den gewählten Treffer oder springst zum nächsten.

- 0.48.0 (09.11.2026): **Umbau U7, Radar im Auktionshaus** (Konzept Abschnitt 7.4).
  - Der Reiter „Radar“ im Auktionshaus zeigt das vorhandene Radar mit allen Funktionen. Die Fläche wird zwischen Broker-Fenster und Auktionshaus umgehängt (`AHTabs.Attach`/`Release`), nichts wird doppelt gebaut. Öffnet man das Radar im Broker-Fenster, holt das Fenster es zurück.
  - `R.Shown()` ersetzt die Prüfung „Broker-Fenster offen und Reiter Radar“: Radar-Scan, Gold-Anzeige und Auffrischen nach dem Scan laufen an beiden Orten.
  - Im Reiter schaltet Broker Blizzards Kaufansicht nicht mehr um (`ShowInAH` gesperrt, solange ein Broker-Reiter offen ist), sonst würde sich der Reiter schließen. Gekauft wird über Brokers Knöpfe wie bisher.
  - **Zahl am Reiter:** Nach jedem Komplettscan zählt Broker die Treffer, „Radar (3)“ blinkt, bis der Reiter geöffnet wird.
  - **Tastenbelegungen** (Tastenbelegung > AddOns > Peon Broker): „Radar: gewählten Treffer kaufen“ (wie der mittlere Kaufknopf) und „Radar: nächster Treffer“ (überspringt weggefallene, am Ende wieder von vorn). Neue Datei `Bindings.xml`.
  - Noch nicht: Aussehen der Liste wie Blizzards Kaufliste (kommt mit dem gemeinsamen Listen-Stil in U10), Auswahl springt nach einem Kauf von selbst weiter.
  - **Im Spiel prüfen:** Reiter Radar im Auktionshaus: Passt die Fläche, läuft der Radar-Scan, klappt Kaufen? Komplettscan mit Treffern: Zahl und Blinken? Tasten belegen und ausprobieren.

## 0.47.0

Kurz: Mit Umschalt zeigt der Tooltip jetzt ein kleines Preisdiagramm: das günstigste Angebot der letzten 14 Tage und den üblichen Bereich als grüne Fläche. Zeitraum (7, 14 oder 30 Tage) und Anzeige stellst du auf der Optionsseite ein.

- 0.47.0 (09.11.2026): **Umbau U6, Diagramm im Tooltip** (Konzept Abschnitt 6.4). Neuer Baustein „Diagramm“ (Formate 14, 7, 30 Tage, Standard mit Umschalt).
  - Linie: günstigstes Angebot je Tag aus Brokers Tageswerten (Lücken bleiben leer), Fläche: üblicher Bereich. Kern-Baustein `Peon.NewChart`, 210 × 54 Punkte.
  - Wie Blizzards `GameTooltip_InsertFrame`, aber ohne in den Tooltip zu schreiben: Überschrift und Leerzeilen anfügen, eigenen Rahmen an der ersten Leerzeile ausrichten, Mindestbreite setzen. Beim Leeren oder Schließen des Tooltips (sicherer Anhang an `OnTooltipCleared` und `OnHide`) verschwindet der Rahmen und die Mindestbreite wird zurückgesetzt.
  - Neu gezeichnet wird nur, wenn sich Gegenstand, Zeitraum oder Werte ändern (Blizzard baut Tooltips im Auktionshaus alle 0,2 Sek. neu auf).
  - Erst ab zwei Tagen mit Werten. Nur im Gegenstands-Tooltip, nicht in der Vorschau (dort ein Platzhalter).
  - **Im Spiel prüfen:** Tooltip mit Umschalt bei einem Gegenstand mit mehreren Tagen Daten. Sitzt das Diagramm sauber? Verträgt es sich mit Peon_Tooltip und Vergleichs-Tooltips? Flackert etwas im Auktionshaus?

## 0.46.0

Kurz: Den Broker-Tooltip stellst du jetzt selbst zusammen: welche Zeilen, ob immer oder nur mit Umschalt, in welchem Format und in welcher Reihenfolge. Dazu gibt es die Vorlagen Schlank, Standard und Ausführlich und eine Vorschau auf der Optionsseite.

- 0.46.0 (09.11.2026): **Umbau U5, Tooltip neu** (Konzept Abschnitt 6). Neue Datei `TooltipOptions.lua`, `Tooltip.lua` umgebaut in Daten sammeln (`T.Context`), ausgeben (`T.Render`) und Einstellung (`T.Layout`).
  - **Zeile 1:** Erlös für den Stapel und dahinter Stück × Preis (`18g 40s (20 × 95s)`), Farbe der Marktlage, ein Wort bei „fällt“, „Dumping“, „keine Angebote“, höchstens ein Pfeil. Ohne „AH:“ davor. Zeichen für Gegenstände auf einer Einkaufsliste (Taschen-Symbol). Formate: Stapel und je Stück, nur Stapel, nur je Stück.
  - **Bausteine:** Markt (ab, Menge, Alter), Üblich, Absatz (am Tag), Einstellen (Vorschlag und Erlös), Händler, Neutral, Herstellen, Deine Verkäufe, Hinweis (nur der wichtigste). Je Baustein Wann (immer, mit Umschalt, aus), Format und Reihenfolge.
  - **Entfällt:** Zeilen „Angebote“, „AH Min/Median“ und „7 Tage“ (gehen in Markt und Üblich auf), Einstellgebühr als eigene Zeile (Format „Mit Gebühr“), Pfeile an jedem Wert, der Hinweis „(Umschalt)“ (als Schalter weiter da, Standard aus).
  - **Optionsseite:** Vorlagen Schlank (nur Zeile 1), Standard, Ausführlich (alles ohne Umschalt), Zeile 1, Liste der Bausteine mit Auswahllisten und Pfeilen, Vorschau mit Beispielwerten (mit und ohne Umschalt umschaltbar). Ersetzt die Schalter „7 Tage“, „Händler“, „Hinweise“ und „Zeile Neutral“. Deren Werte werden beim ersten Start übernommen.
  - Gespeichert in `PeonBrokerDB.tooltipLayout`. Kaputte oder alte Einstellungen werden repariert, neue Bausteine späterer Versionen hängen sich aus an.
  - **Im Spiel prüfen:** Tooltip ohne und mit Umschalt. Optionsseite: Auswahllisten, Pfeile, Vorlagen, Vorschau. Passt alles nebeneinander auf die Seite?

## 0.45.0

Kurz: Strg+Rechtsklick auf einen Gegenstand bietet jetzt „Info (Broker)“ und „Auf Einkaufsliste“ mit allen deinen Listen an.

- 0.45.0 (09.11.2026): **Umbau U4, Einträge im Gegenstandsmenü** (Konzept Abschnitt 9, braucht Peon 0.16.0 mit API 16, sonst kein Menü). Neue Datei `Menu.lua`.
  - „Info (Broker)“ öffnet das Broker-Fenster beim Reiter Preise mit dem Gegenstand (bis zum neuen Fenster in U10).
  - „Auf Einkaufsliste“: Untermenü mit allen Listen und „Neue Liste …“.
  - „Beobachten“ kommt mit U8.
  - **Im Spiel prüfen:** Strg+Rechtsklick auf einen Gegenstand in der Tasche, „Auf Einkaufsliste“ und „Info (Broker)“ ausprobieren.

## 0.44.0

Kurz: Legst du im Auktionshaus etwas ins Verkaufsfenster, sagt Broker darunter, ob du zu diesem Preis verkaufen solltest: Verkaufen, Lieber warten, Verkaufen (Preis fällt) oder Lieber zum Händler, jeweils mit kurzem Grund.

- 0.44.0 (09.11.2026): **Umbau U3, Rat im Verkaufsfenster** (Konzept Abschnitt 7.2). Neue Datei `Advice.lua`.
  - Kasten unter Blizzards Knopf „Auktion erstellen“: oben das Urteil groß und farbig, darunter ein Satz, warum, dann Üblich, Absatz und Erlös für die Menge (mit Händlerwert). Am neutralen Haus steht oben rechts „Neutral“.
  - Broker trägt nichts in Blizzards Felder ein. Das Urteil gilt für den Preis, der gerade im Feld steht, und wird bei jeder Änderung neu gerechnet (sicherer Anhang an `UpdatePostState` beider Verkaufsfenster).
  - Urteile: Verkaufen (im Bereich, knapp darunter oder darüber), Lieber warten (mehr als 15 % unter dem unteren Rand, `A.WAIT_PCT`), Verkaufen, Preis fällt (Bereich schon länger nach unten verschoben), Lieber zum Händler (Erlös nach Anteil unter dem Händlerpreis), Keine Einschätzung (kein üblicher Bereich). Zusatz „Viel Ware im Markt“, wenn die Angebote länger als 3 Tage Absatz reichen (`A.FULL_DAYS`). Die Grenzwerte sind ein erster Vorschlag.
  - Blizzards Angebote für das Verkaufsfenster liest Broker mit und übernimmt sie als Live-Stand. Eine eigene Suche schickt er nicht ab.
  - Bei „Blizzard pur“ kein Kasten und kein Anhang.
  - **Im Spiel prüfen:** Gegenstand aus der Tasche ins Verkaufsfenster legen: Erscheint der Kasten unter „Auktion erstellen“, passt er über „Sofortkaufmodus“? Preis von Hand ändern: Wechselt das Urteil? Sind die Grenzwerte sinnvoll?

## 0.43.0

Kurz: Broker liest aus deinen Verkaufsrechnungen in der Post, wie viel jedes Auktionshaus einbehält. Der Vergleich mit dem neutralen Auktionshaus im Tooltip rechnet damit, ein „?“ heißt: noch nicht gemessen.

- 0.43.0 (09.11.2026): **Umbau U2, Anteil je Markt** (Konzept Abschnitt 5.3). Neue Datei `Cut.lua`.
  - Beim Öffnen des Briefkastens (`MAIL_INBOX_UPDATE`) liest Broker alle Verkaufsrechnungen (`GetInboxInvoiceInfo`, Art „seller“) und rechnet Anteil ÷ Verkaufspreis. Das Haus erkennt er am Absender („Auktionshaus der Allianz“ im Spiel gesehen): Allianz, Horde, jedes andere Auktionshaus gilt als neutral. Verkäufe unter 20 Silber zählen nicht (Rundung), jede Rechnung nur einmal je Sitzung. Gespeichert in `PeonBrokerDB.cut[Fraktion]` (Median der letzten 10).
  - `D.Cut(markt)` ersetzt den festen Anteil `D.CUT` überall (Erlös, kleinster lohnender Preis, Radar, Verkaufen). Ohne Messung bleibt es bei 5 %. `D.CutSure(markt)`: Fraktionshäuser gelten als bestätigt, das neutrale erst nach einer Messung.
  - Zeile „Neutral“ im Tooltip: Abstand jetzt nach Gebühr beider Häuser, graues „?“ solange der neutrale Anteil nicht gemessen ist.
  - `/broker pruefen ah` nennt die gemessenen Anteile.
  - **Im Spiel prüfen:** Nach einem Verkauf in Beutebucht den Briefkasten öffnen, dann `/broker pruefen ah`: Steht dort ein Anteil für Neutral? Verschwindet das „?“ im Tooltip?

## 0.42.0

Kurz: Der Tooltip zeigt jetzt immer die Preise des Auktionshauses deiner Fraktion, auch wenn du am neutralen Auktionshaus stehst. Die Preise des neutralen Hauses stehen in einer eigenen Zeile „Neutral“ mit dem Unterschied in Prozent.

- 0.42.0 (09.11.2026): **Umbau U1, Heimatmarkt** (Konzept Abschnitt 5). Bisher galt bei offenem neutralen Auktionshaus überall der neutrale Markt (Regel aus 0.40.0), Tooltips zeigten dort die meist höheren neutralen Preise.
  - **Zwei Märkte:** `ns.HomeMarketKey()` (immer eigene Fraktion) und `ns.AHMarketKey()` (Markt am offenen Haus). `ns.MarketKey()` ist der Markt am offenen Haus, außer innerhalb von `ns.WithHome(fn, …)`. Die Klammer wirkt bis in verschachtelte Abfragen (Lookup, Bereich und Absatz vom Manager) und setzt den Markt auch nach einem Fehler zurück.
  - **Immer Heimatmarkt:** Tooltip, Wert für Ledger (`ItemValue`, `MarketInfo`, `History`, `MarketItems`), Materialpreise im Berufsfenster. Scan, Live-Abfragen, Verkaufen, Kaufen, Radar und Auktionen bleiben beim Markt am offenen Haus.
  - **Zeile „Neutral“:** günstigstes Angebot im neutralen Haus je Stück, dahinter der Abstand zum Heimatmarkt in Prozent (grün höher, orange niedriger), bei Daten älter als ein Tag das Alter. Nur wenn es neutrale Daten mit Angeboten gibt. Einstellung `tooltipNeutral`: immer, nur mit Umschalt (Standard), aus. Die Gebühren beider Häuser stecken noch nicht im Vergleich (kommt mit U2).
  - **Im Spiel prüfen:** In Beutebucht mit offenem Auktionshaus den Tooltip ansehen: Preis wie in Sturmwind? Mit Umschalt Zeile „Neutral“ mit Prozent? Einstellung „Zeile Neutral“ auf der Optionsseite.

## 0.41.2

Kurz: Die Reiter Radar und Einkaufen sind jetzt hervorgehoben, wenn du sie anklickst, und haben den gleichen Abstand wie Blizzards Reiter.

- 0.41.2 (09.11.2026, nach dem zweiten Test von KarloDerBaer): **Ursache gefunden.** Blizzards Reiter-Vorlage (`PanelTabButtonTemplate`, `parentArray="Tabs"`) trägt jeden Reiter in die Liste `Tabs` seines Elternrahmens ein. Radar und Einkaufen hingen am Auktionshaus und standen deshalb in Blizzards Liste `AuctionHouseFrame.Tabs`. Folgen: Brokers „Blizzard-Reiter abwählen“ wählte auch Radar gleich wieder ab, und Blizzards Liste war verändert, ohne dass `issecurevariable` es meldet (es prüft nur den Eintrag, nicht den Inhalt).
  - Die Reiter hängen jetzt an einem eigenen Rahmen `PeonBrokerAHTabHolder`. Blizzards Liste bleibt bei drei Reitern.
  - Die Prüfung (`/broker pruefen ah`, Fläche) zeigt zusätzlich „Tabs (Inhalt)“: steht ein Broker-Reiter in Blizzards Liste?
  - Abstand zum Reiter davor -7 statt -15 (`T.TAB_GAP`), auf den Bildern lagen Brokers Reiter enger als Blizzards.
  - Der Test baut die Vorlage jetzt mit Eintrag in die Liste und Seitenteilen nach, so wäre der Fehler aufgefallen.
  - **Im Spiel prüfen:** Radar anklicken: hervorgehoben wie Blizzards gewählter Reiter? Abstände gleichmäßig? `/broker pruefen ah`: auch „Tabs (Inhalt)“ sauber?

## 0.41.1

Kurz: Die neuen Reiter Radar und Einkaufen decken das Auktionshaus jetzt ganz ab, der gewählte Reiter ist hervorgehoben, und der Knopf „Blizzard pur“ ist oben rechts in der Titelleiste zu sehen. Der Knopf „Broker“ unter dem Auktionshaus entfällt.

- 0.41.1 (09.11.2026, nach dem ersten Test von KarloDerBaer): Die Prüfung war sauber (alle Werte „sauber“, keine Blockade), die Oberfläche hatte drei Fehler.
  - **Fläche über alle Blizzard-Elemente:** Gegenstandsfeld, „Auktion erstellen“ und „Sofortkaufmodus“ aus dem Verkaufsfenster lagen über Brokers Fläche. Die Fläche liegt jetzt 500 Ebenen über dem Auktionshaus statt 20 (`T.PAGE_LEVEL`).
  - **Gewählter Reiter hervorgehoben:** Radar und Einkaufen sahen nie gewählt aus. Broker stellt die Seitenteile der Reiter (`Left/Middle/Right` und `…Active`) jetzt selbst um, zusätzlich zu `PanelTemplates_SelectTab`. Fehler dort landen im Debug-Log.
  - **Knopf „Blizzard pur“ sichtbar:** lag unter Blizzards Rahmen. Jetzt in der Titelleiste links neben dem Schließen-Knopf, über dem Rahmen, kleinere Schrift.
  - **Knopf „Broker“ unter dem Auktionshaus entfällt** (laut Konzept ohnehin geplant): Er lag halb hinter Blizzards Reitern (roter Rest links neben „Kaufen“). Das Fenster öffnen Minimap-Button, Peon_Panel und `/broker`.
  - **Im Spiel prüfen:** Verkaufen wählen, dann Radar: Ist nichts vom Verkaufsfenster mehr zu sehen? Ist Radar hervorgehoben wie Blizzards gewählter Reiter? Ist „Blizzard pur“ oben rechts zu sehen, und klappt an und aus (alternativ `/broker pur`)?

## 0.41.0

Kurz: Im Auktionshaus gibt es zwei neue, noch leere Reiter „Radar“ und „Einkaufen“ zum Ausprobieren. Oben rechts schaltet der Knopf „Blizzard pur“ Broker im Auktionshaus ganz ab, falls einmal etwas blockiert.

- 0.41.0 (09.11.2026): **Umbau U0, Prüfaufbau** (Konzept `docs/konzepte/broker/Peon_Broker_Umbau.md`, Abschnitte 7.1 und 7.7). Neue Datei `AHTabs.lua`.
  - **Eigene Reiter im Auktionshaus:** „Radar“ und „Einkaufen“ rechts neben Blizzards „Auktionen“ (Vorlage `AuctionHouseFrameTabTemplate`). Broker fügt nichts zu `AuctionHouseFrameDisplayMode` oder `AuctionHouseFrame.Tabs` hinzu und ruft `SetDisplayMode` dafür nie auf. Ein Klick legt eine eigene Fläche über Blizzards Inhalt und stellt nur das Aussehen der Reiter um. Wechselt Blizzard die Ansicht (Reiter, Gegenstand aus der Tasche), blendet ein sicherer Anhang an `SetDisplayMode` die Fläche wieder aus. Die Fläche zeigt live, ob Blizzards Werte noch sauber sind (`issecurevariable`).
  - **`/broker pruefen ah`:** gleiche Prüfung im Chat, Ergebnis in `PeonBrokerDB.ahProbe`.
  - **Notausgang „Blizzard pur“** (`ahPlain`, bleibt bei „Standardwerte“): Knopf oben rechts im Auktionshaus, `/broker pur` oder Knopf auf der Optionsseite, jeweils mit Rückfrage und Neuladen. Danach legt Broker keine Reiter und Knöpfe am Auktionshaus an und legt nichts in Blizzards Fenster (Verkaufen, Kaufansicht, Ansicht umschalten). Tooltip, Broker-Fenster und `/broker scan` gehen weiter. Der Starter-Tooltip erinnert daran.
  - **Blockierte Aktionen:** Meldet das Spiel `ADDON_ACTION_BLOCKED` oder `ADDON_ACTION_FORBIDDEN` für Peon_Broker, merkt Broker das (`PeonBrokerDB.ahBlocked`, Fehlerspeicher) und bietet bei offenem Auktionshaus einmal je Sitzung „Blizzard pur“ an.
  - **Im Spiel prüfen:** Nach `/reload` ohne vorher das Broker-Fenster zu benutzen: Auktionshaus öffnen, Reiter Radar und Einkaufen anklicken, zurück zu Kaufen, Verkaufen und Auktionen. Dann etwas kaufen (Massenware und Einzelgegenstand), etwas einstellen und eine Auktion abbrechen. Kommt „Aktion wegen AddOn blockiert“? Danach `/broker pruefen ah`: Stehen alle Werte auf „sauber“? Sitzt die Fläche richtig (Suchleiste und Listen verdeckt, Porträt frei)? „Blizzard pur“ an und wieder aus.

## 0.40.0

Kurz: Am neutralen Auktionshaus (zum Beispiel in Beutebucht) speichert Broker die Preise in einem eigenen Markt „Neutral“. Deine Preise aus dem Auktionshaus deiner Fraktion bleiben davon unberührt.

- 0.40.0 (09.11.2026, KarloDerBaer in Beutebucht): **Neutraler Markt.** Bisher bestand der Markt immer aus Realm-Name und Fraktion des Charakters, ein Scan am neutralen Haus wäre im Markt der eigenen Fraktion gelandet. Jetzt prüft `ns.MarketKey()` bei offenem Auktionshaus die Fraktion des Auktionators (`UnitFactionGroup("npc")`). Hat er keine, heißt der Markt `<Realm> / Neutral`. Geprüft im Spiel: „Auktionator O'reely“ in Beutebucht hat keine Fraktion. Ob das Auktionshaus offen ist, fragt `ns.AtNeutralAH()` beim Spiel nach (`C_PlayerInteractionManager`), damit es nicht von der Reihenfolge der Ereignisse abhängt. Nach dem Schließen gilt wieder der eigene Markt, Tooltips zeigen dann wieder die Preise der eigenen Fraktion.
  - **Im Spiel prüfen:** Am neutralen Haus zeigt der Tooltip des Scan-Knopfs „… / Neutral“, am Haus der eigenen Fraktion weiter „… / Alliance“.

## 0.39.0

Kurz: Im Berufsfenster stehen Kosten, Vorrat und Gewinn jetzt direkt unter den Reagenzien. In der Rezeptliste siehst du den Gewinn jedes Rezepts, das beste ist golden markiert. Alles lässt sich über das Zahnrad einstellen.
Kurz: Eine Tabelle zeigt je Material, ob es aus deinem Vorrat kommt oder beim Händler oder im AH gekauft wird, was es kostet und was dein Material im AH bringen würde.
Kurz: Bringt der Verkauf deines Materials mehr als das Herstellen, sagt Broker es dir und färbt den Gewinn in der Rezeptliste orange.

- 0.39.0 (08.11.2026, Wunsch KarloDerBaer): **Block unter den Reagenzien** statt der Box neben dem Fenster. Oben die Ergebniszeile mit Kosten, Ertrag und Gewinn, darunter eine Tabelle je Material, darunter ein Hinweis. Haken „Twinks mitzählen“ (gleiche Einstellung wie im Reiter Behalten, nur mit Ledger) und Zahnrad mit allen Einstellungen.
  - **Tabelle** (nach zwei Tests im Spiel mit KarloDerBaer abgestimmt): Spalten Material, Quelle, Kosten, Erlös, darunter Gesamt. Je Material eine Zeile. Reicht der Vorrat nicht, hat das Material zwei Zeilen: Vorrat und Kauf. Quelle ist „Vorrat“, „Händler“ oder „AH“ (wo es günstiger ist), „?“ ohne Preis. Kosten: Vorrat laut Ledger (nächstes Stück), ohne Wert im Ledger der AH-Preis mit „~“. Kauf: Menge × günstigster Preis. Erlös: was das Material aus dem Vorrat im AH nach Gebühr bringen würde (`ns.ItemValue`), bei Kauf „-“.
  - **Rechnung** (`C.CalcFull`): Gewinn = Ertrag minus Kosten, nur diese eine Zahl, auch in der Rezeptliste. Herstellen bringt Ertrag minus Kaufkosten (der Vorrat ist schon da). Bringt der Erlös des Vorrats mehr (`sellBetter`), steht der Gewinn in der Rezeptliste orange und das Rezept bekommt keinen goldenen Strich. Die Einstellung mit drei Rechnungen (`craftProfitMode`) aus den Zwischenständen entfällt.
  - **Hinweis:** „Dein Vorrat reicht für N×“, wenn nichts zu kaufen ist. Mit Material aus dem Vorrat beide Beträge: „Material verkaufen bringt mehr: 18c statt -1s 53c beim Herstellen“ (orange) oder „Herstellen bringt mehr: 20c statt 18c beim Verkauf des Materials“. Vorher stand nur der Abstand („bringt 1s 71c mehr“), das las sich wie ein Gewinn. „Lieber verkaufen“ allein war unklar, weil nicht dastand, dass das Material gemeint ist (KarloDerBaer).
  - **Händlerpreise** (neue Datei `Merchant.lua`, `ns.Merchant`): Das Spiel nennt den Kaufpreis beim Händler nur bei offenem Händlerfenster. Drei Quellen, die beste zuerst: beim Händlerbesuch gemerkt (`MERCHANT_SHOW`, `MERCHANT_UPDATE`, accountweit in `PeonBrokerDB.merchant[itemID] = { p, t, w }`, Preis je Stück, nur gegen Gold), letzter Kauf beim Händler laut Peon_Ledger (`mod:VendorBuy`, ab Ledger 0.13.1), geschätzt für bekannte Händler-Reagenzien (`V.LIST`: Fäden, Farbstoffe, Gewürze, Phiolen, Flussmittel und Ähnliches) als Ankaufspreis des Händlers × 4, grau und mit „~“.
  - **Tooltips:** Über Quelle, Kosten und Erlös einer Zeile: beim Vorrat wo es liegt, deine Kosten, AH-Preis und Erlös. Beim Kauf AH-Preis, Händlerpreis mit Herkunft und Vorrat. Über den Kästen: wie sich Kosten, Ertrag und Gewinn ergeben, beim Gewinn dazu der Vergleich Herstellen gegen Verkaufen und „Alles gekauft“.
  - **Rezeptliste sofort beschriftet** (nach dem ersten Test: Gewinne kamen erst nach etwa einer Minute, beim Wechsel des Berufs mal sofort, mal später): Das Ereignis `TRADE_SKILL_LIST_UPDATE` kam oft mehrmals hintereinander, Broker las höchstens alle 2 Sek. und verschluckte dabei das letzte, vollständige. Jetzt merkt sich Broker, dass neu gelesen werden muss, und liest beim nächsten Takt (höchstens alle 0,5 Sek., `C.READ_GAP`). Zeigt die Liste ein Rezept, das Broker noch nicht gelesen hat (anderer Beruf, Liste kam später), liest er ebenfalls nach.
  - **Rezeptliste:** Gewinn rechts in jeder Rezeptzeile, goldener Strich am besten Rezept. Die Zeilen baut das Spiel beim Scrollen neu, Broker beschriftet sie alle 0,1 Sek. und beim Belegen einer Zeile neu. Eigene Schriften und Striche hängen an den Zeilen, in Blizzards Tabellen schreibt Broker nichts.
  - **Einstellungen** (im Zahnrad-Menü und auf der Optionsseite unter „Berufe“): `craftList`, `craftListWhich` (alle, nur mit Gewinn, nur die besten 3, 5 oder 10), `craftListMode` (Betrag oder Prozent vom Material), `craftListBest`, `craftListLoss`, `craftListUnknown`, `craftBlock`, `craftSummary`, `craftColSrc`, `craftColCost`, `craftColSell`, `craftHint`, `keepAllChars`.
  - Rezepte merken die Reihenfolge der Materialien (`o`). Die Box daneben bleibt als Rückfall, wenn das Fenster keinen Reagenzien-Bereich hat (altes Berufsfenster).
  - Neuer Prüfbefehl `/broker pruefen beruf`: zeigt den Aufbau des Berufsfensters (Teile des Rezeptformulars, Anker, Zeilen der Rezeptliste) und speichert ihn in `PeonBrokerDB.craftProbe`.
  - **Im Spiel prüfen:** Sitzt der Block unter den Reagenzien und überdeckt nichts (auch bei Rezepten mit vielen Reagenzien)? Stehen die Gewinne in der Rezeptliste an der richtigen Zeile, auch nach Scrollen und Suchen? Überdecken sie lange Rezeptnamen? Öffnet das Zahnrad das Menü? Passen Spalten und Namen in die Tabelle? Stimmen die geschätzten Händlerpreise mit dem überein, was ein Händler mit Reagenzien wirklich verlangt? Keine Meldung „Aktion wegen AddOn fehlgeschlagen“ beim Herstellen? Falls etwas nicht passt: `/broker pruefen beruf` und die Ausgabe schicken.

## 0.38.0

Kurz: Fällt ein Preis stark, folgt der übliche Bereich jetzt schneller. Bisher hat Broker einen echten Preissturz in den ersten Tagen teils als Ausreißer abgeschnitten.

- 0.38.0 (08.11.2026, Wunsch KarloDerBaer, Beispiel Magicusmantel): **Kürzung nach unten (F37a):** Beim gleitenden Mittelwert werden Tageswerte nach unten erst ab 75 % unter der Mitte gekürzt (`D.BAND_CLIP_LOW_SCHW` = 25 %). Bisher galt auch nach unten das Dreifache der Schwankung. Bei wenigen, gleichen Tagen liegt die Schwankung bei 5 %, ein Sturz von 4g auf 1g 50s wurde so auf 3g 40s hochgesetzt. Nach oben bleibt die Kürzung, Mondpreise zählen weiter nicht. Gleiche Regel im Peon Manager 0.21.0, der Bereich ist also gleich, egal wer ihn rechnet.
  - Den Abstand zum nächsten Angebot prüft das Radar schon seit 0.26 (Verkauf höchstens zum nächsten Angebot), bei fallendem Markt gibt es seit 0.21 kein Markt-Schnäppchen.

## 0.37.0

Kurz: Die Einkaufsliste wird überarbeitet. Bis dahin zeigt der Reiter nur einen Hinweis.

- 0.37.0 (07.11.2026, Wunsch KarloDerBaer): Reiter Einkaufsliste zeigt nur „WIP: Update kommt bald“ (`W.WIP`, `L.TAB_WIP`), die Zeile zur Einkaufsliste unter Start entfällt. Der Code der Liste bleibt und wird für die Überarbeitung weiter getestet.

## 0.36.0

Kurz: Broker nutzt jetzt auch die neueren Preise aus dem Peon Manager, zum Beispiel aus der Blizzard-API. Auf der Leiste steht das Alter der neuesten Daten.

- 0.36.0 (07.11.2026, Wunsch KarloDerBaer): **Stand vom Manager:** Beim Anmelden und nach `/reload` holt Broker über Peon_Bridge 0.7.0 den neuesten Stand des Managers (`D.ApplyManager`). Ist er für einen Gegenstand neuer als Scan und Live-Abfrage, gilt er wie eine Live-Abfrage: aktueller Preis, Median, Menge und Angebote, Zeit in `e.lt`. Verlauf, Trend und Zahl der Scans bleiben reine Scan-Werte. Gegenstände, die im Stand fehlen, gelten als weg. Die günstigsten Stufen (`lv`) kennt der Manager nicht, sie fallen für diese Gegenstände weg, Schnäppchen kommen also weiter nur aus eigenen Scans und Live-Abfragen. Neue Felder im Markt: `mgrAt`, `mgrSrc`, `mgrItems`.
  - **Peon_Panel:** Der Text „Alter der neuesten Daten“ (Schlüssel `age`, Standard) nimmt den neueren Wert aus Scan und Manager. Das reine Scan-Alter gibt es als „Alter des letzten Scans“ (`scanAge`). Der Tooltip zeigt zusätzlich „Blizzard-API: vor … (… Gegenstände)“.
  - Das Spiel liest `Data.lua` nur beim Anmelden und nach `/reload`. Neuere Stände des Managers kommen also erst danach an.
  - **Im Spiel prüfen:** Stimmen Tooltip-Preise und Vorschläge nach `/reload` mit dem API-Stand, bleibt das Laden flüssig?

## 0.35.0

Kurz: Mit Peon_Panel zeigt Broker auf der Leiste das Alter des letzten Scans oder die Zahl der Angebote.

- 0.35.0 (07.11.2026): Texte für Peon_Panel: Alter des letzten Scans (Standard), Angebote im letzten Scan. Nach einem Scan aktualisiert. Ohne Peon_Panel ändert sich nichts.

## 0.34.0

Kurz: Einkaufslisten gelten jetzt für alle Charaktere und gleichen sich mit dem Peon Manager ab.
Kurz: Neu: eigener Höchstpreis je Gegenstand auf der Einkaufsliste.

- 0.34.0 (06.11.2026, Wunsch KarloDerBaer): **Einkaufslisten accountweit, Abgleich mit dem Manager.** Neue Datei `Shop.lua` (Regeln des Abgleichs, gleich wie `manager/src/core/shopping.js`). Listen liegen in `PeonBrokerDB.lists` mit Nummer und Änderungszeit, Löschmarken in `listsGone`, die gewählte Liste bleibt je Charakter. Listen eines Charakters werden beim ersten Laden übernommen, bei gleichem Namen in die vorhandene Liste. `mod:MergeShop(data)` mischt die Listen aus dem Manager ein. Eigener Höchstpreis in Gold je Gegenstand (`max` in Kupfer) geht vor dem Wert der Liste. **Im Spiel prüfen (WoW neu starten, neue Datei):** Listen werden übernommen, Feld „Max. Gold“ passt neben den Text im Reiter Einkaufsliste, Abgleich in beide Richtungen.

## 0.33.1

Kurz: Fehlermeldung nach dem Scan im Radar behoben.
Kurz: Der Schnellkauf für Massenware braucht jetzt zwei Klicks.

- 0.33.1 (05.11.2026): **Radar: Fehlermeldung nach dem Scan behoben** (`ADDON_ACTION_BLOCKED`, `UNKNOWN()`). Der Preis vorab für den Schnellkauf (`StartCommoditiesPurchase` ab 0.24) lief ohne Klick, das Spiel erlaubt die Funktion aber nur direkt aus einem Klick (`HasRestrictions` in Blizzards Doku, `pcall` fängt die Meldung nicht ab). Preis vorab ist aus (`R.preOff`), der Schnellkauf für Massenware braucht zwei Klicks: 1. Klick Preis, 2. Klick bestätigen. Hinweis am Knopf angepasst. **Im Spiel prüfen:** Scan im Reiter Radar ohne Meldung, Kauf von Massenware mit zwei Klicks.

## 0.33.0

- 0.33.0 (31.10.2026): Werte und Momentaufnahmen über **Peon_Bridge** (Modul `bridge`, bisher Peon_Client `client`) an zwei Stellen (`Data.lua` `D.ClientBand`, `Sales.lua` `S.ClientStats`). Die Bridge liefert nur Werte, wenn der Peon Manager den Kanal broker freischaltet, sonst rechnet Broker wie bisher selbst. Texte wie „Üblich (Client, n Tage)“ bleiben (gemeint ist der Manager mit dem Broker Client).

## 0.32.0

- 0.32.0 (23.10.2026, Peon Client C6, Rechenmodell F49): **Absatz vom Peon Client als Rückfall.** `Sales.Stats(e, now, key)`: hat Broker in den letzten 6 Std. weniger als 60 Min. selbst beobachtet (rot oder nichts), nimmt er Absatz je Std. (14-Tage-Wert ÷ 24), Quote und Sicherheit (nach beobachteter Zeit) vom Client, `src = "client"`. Gilt im Tooltip („Absatz (Client, 14 Tage)“), Reiter Preise, Verkaufen und beim Radar (Begrenzung nach Absatz). Neu für Peon_Client: `mod:IsCommodity(key)`, `mod:VendorPrice(id)`. Ohne Client oder bei Fehler wie bisher. Im Beta-Ordner blieb Broker bei 0.31.0 mit neuer Sales.lua (Dateien schreibgeschützt). In `_forever_` vollständig 0.32.0 (25.10.).

## 0.31.0

- 0.31.0 (23.10.2026, Peon Client C4, Rechenmodell Kapitel 8): **Langzeit-Teil des üblichen Bereichs vom Peon Client.** `D.ClientBand(key)` fragt Peon_Client (`LongTerm`) nach MITTE, SCHW, LANG und Tagen für den Gegenstand im eigenen Markt. Sind die Werte da und frisch (F43), nimmt `D.Band` sie statt der eigenen F35 bis F37 (SCHW mindestens 5 %, reicht auch bei weniger als 3 eigenen Tagen); HEUTE, Richtwert, Bereich, Trend und Schnäppchen rechnet Broker weiter selbst (F44). Ohne Peon_Client, ohne Werte, bei alten Werten oder bei einem Fehler im Client (abgefangen) rechnet Broker wie bisher. `D.Band` und `D.Deal` bekommen den Schlüssel als neuen letzten Wert (Verkaufen, Tooltip, Einkaufen, Radar). Anzeige „Üblich (Client, n Tage)“ im Tooltip, im Reiter Preise und beim Verkaufen. Nur mit dem Nachbau geprüft (Beta offline).

## 0.30.2

- 0.30.2 (22.10.2026, **Ursache gefunden** über `lastScanError`): „integer overflow attempting to store 49999996000“. Ein Angebot zum Höchstpreis (fast 5 Mio. Gold) brach den Scan ab, weil Broker Preise mit `%d` in seine kompakten Texte schrieb (Tageswerte in Data.lua, Absatz-Daten in Sales.lua samt Auktionsnummern). `%d` geht im Forever-Lua nur bis 2^31 (etwa 214.748 Gold). Jetzt `%.0f`. Hatte mit Peon_Client nichts zu tun. `test_client.lua` baut die Grenze von Forever nach (`string.format` mit `%d` über 2^31 = Fehler) und prüft Scan, Tageswert, Live-Abfrage und Absatz-Daten mit Höchstpreis und großer Auktionsnummer.

## 0.30.1

- 0.30.1 (22.10.2026, Fehler beim ersten Scan mit Peon_Client, Meldung im Chat nicht erhalten): Scheitert ein Arbeitsschritt des Komplettscans, bricht Broker den Scan sauber ab (Hinweis im Chat) und merkt die Meldung in `PeonBrokerDB.lastScanError` (Zeit, Text, Version, Phase, Stand), auch ohne Debug. Bisher lief der Scan dann bei jedem Bild erneut in den Fehler und wurde nie fertig. Abfrage `Peon.IsSecret` nur noch für vorhandene Links. Nachstellen mit KarloDerBaers echten Broker-Daten im Test lief fehlerfrei, die Ursache ist noch offen.

## 0.30.0

- 0.30.0 (22.10.2026, Peon Client C1): **Zuhörer für Momentaufnahmen** `mod:AddSnapshotListener(fn)` für Peon_Client. Komplettscan meldet `scan_start` (Markt, Zeit, Anzahl, Varianten), jedes Angebot als `scan_row` (auch reine Gebote, mit Mindestgebot, Gebot, Restzeit-Stufe, Link ab Qualität 2), `scan_end` bzw. `scan_abort`; jede Live-Abfrage meldet `live` (aus `Data.ApplyLive`, nicht bei Ergebnissen eines anderen Gegenstands). Ohne Zuhörer unverändert; ein Zuhörer mit Fehler wird entfernt und einmal gemeldet. Rechnung und Daten von Broker unverändert.

## 0.29.0

- 0.29.0 (07.10.2026, für Ledger 0.10): Schnittstelle `mod:MarketItems()` → alle Gegenstände des aktuellen Markts mit Nummer (Varianten ausgenommen): `{ [itemID] = { min, median, qty, t, gone, name, quality } }`.

## 0.28.1

- 0.28.1 (07.10.2026, **Absturz** beim Öffnen des Berufsfensters, Absturzbericht von KarloDerBaer): WoW brach mit „Assertion failure! L->top < L->ci->top (lapi.c)“ ab. Ursache: Die Box „Broker Herstellen“ sucht Leisten am Fensterrand (`C.SideOffset`, 0.25.2) und rief dafür `pcall(UIParent.GetChildren, UIParent)` auf – `pcall` mit mehreren Hundert Rückgabewerten überläuft im Forever-Lua den Platz des Aufrufs. Jetzt direkt `parent:GetChildren()`. Alle Peon-Module nach dem Muster durchsucht (sonst keine `pcall` mit vielen Rückgabewerten). Test mit 400 Kindern ergänzt.

## 0.28.0

- 0.28.0 (07.10.2026, Durchsicht des Moduls, alle Punkte mit KarloDerBaer abgestimmt):
  - **Ausrüstung mit Zusatz getrennt** (wichtigster Punkt): `keyLog` zeigte, dass Forever den Zusatz im Suchschlüssel (`itemSuffix` 14299–14340) und im Link als Bonus-Nummer ablegt, nicht im Link-Feld 7; die Preise der Varianten liegen weit auseinander (Gleißendes Claymore 17s–25g). Scan, Taschen und Links liefern den vollen Namen. Jetzt: Hat ein Gegenstand Varianten (`markets[…].variants[itemID]`), ist der Schlüssel `"itemID:voller Name"`. Der Scan erkennt Varianten (mehrere Namen, Link mit Bonus-Nummern oder Name ≠ Grundname aus `C_Item.GetItemInfo`; Grundname noch nicht geladen → vorerst unter der Nummer, nächster Scan entscheidet) und löscht dann den alten gemischten Eintrag und den gemerkten Schlüssel. Link je Variante in `e.lk` (Tooltip in den Listen).
  - **Suchschlüssel je Variante** werden nebenbei gelernt (`itemKeys["itemID:Name"] = "Stufe:Zusatz"`): beim Verkaufen (Taschen), aus eigenen Auktionen, aus jedem Suchergebnis (auch beim Stöbern im Blizzard-Fenster) und aus der Browse-Suche (`GetItemKeyInfo` – ob dort der volle Name kommt, im Spiel prüfen). Ergebnisse werden nach Variante gefiltert (Verkaufen, Einkaufen, Radar, Meine Auktionen) und gehen je Variante in die Datenbank. Radar, Einkaufsliste-Runde und Startseite lassen Varianten ohne gelernten Schlüssel aus (statt „weg“).
  - **Ledger:** `mod:ItemValue(itemID)` liefert bei Varianten den Wert der günstigsten Variante mit Angeboten (vorsichtig, KarloDerBaer). `MarketInfo`/`History` liefern für Gegenstände mit Varianten nichts (Ledger kennt nur Nummern).
  - **Kleine Fehler:** Reiter „Start“ wird als letzter Reiter gemerkt (`windowTab`, „book“ entfernt); Beschreibung (Optionen, TOC) und Meldung „braucht Peon 0.8“ aktualisiert; Warenart am Auktionshaus auch aus der Reagenzientasche; Kostenwarnung mit `D.CUT`.
  - **Schnellkauf abgesichert:** kein Preis vorab, solange ein Treffer gewählt oder Blizzards Kaufansicht für Massenware offen ist; Preisantworten in dieser Zeit gelten nicht als eigene, Broker bricht dann nie einen Kauf ab (`R.BlizzardBuying`).
  - **Datenmenge:** Absatz-Momentaufnahmen und Einzelvergleiche älter als 24 Std. werden beim täglichen Verdichten gelöscht (`Sales.Prune`); Vergleiche derselben Stunde werden zusammengefasst (höchstens 24 je Gegenstand); Fehlersuch-Protokolle (`radarLog`, `keyLog`, `showLog`, `aucLog`, `radarStats`) nur noch mit `/broker debug`, ohne Debug beim Start gelöscht; `posted`, `cancelled`, `bought`, `buyMode`, `dealMaxAge` und `depositCheck` entfallen (Abgleich der Einstellgebühr abgeschaltet, Formel bestätigt; Warenart wird nur noch einmal je Gegenstand gefragt).
  - **Kleinigkeiten:** Verkaufen lädt bei Teil-Ergebnissen den Rest nach (`RequestMore…SearchResults`, bis 5×; kommt nichts, gilt der Teil); Taschenliste bewertet jeden Gegenstand nur einmal, beim Einstellen ohne Bewertung (`ScanBags(true)`); rund 60 unbenutzte Texte entfernt.
  - Tests: test_broker um Schnellkauf, Aufräumen, Teil-Ergebnisse und Varianten ergänzt; alle Tests OK. **Im Spiel prüfen:** nach dem ersten Scan Ausrüstung mit Zusatz im Tooltip und im Reiter Preise (je Variante eigene Zeile?), Verkaufen einer Variante, ob der Radar nach Stöbern im Auktionshaus Varianten prüft, `/broker debug` für Protokolle.

## 0.27.1

- 0.27.1 (06.10.2026, KarloDerBaer): **Alt+Klick entfernt** (gehört jetzt Peon_Ledger): kein Auswählen im Reiter Verkaufen/Behalten und kein Hinzufügen zur Einkaufsliste per Alt+Klick mehr – Auswahl über das Broker-Fenster, Hinzufügen über Suchfeld und „Zur Einkaufsliste“ im Reiter Preise. `S.SelectLink(link)` bleibt als Funktion. Hinweistexte angepasst.

## 0.27.0

- 0.27.0 (06.10.2026, Konzept `Peon_Ledger_Gegenstand.md` G2):
  - **Absatz so lange wie die Preise:** Tageswerte `e.ab` bleiben `dataDays` (mind. 14) Tage, ältere als Wochensummen `e.abw` (26 Wochen). Der 14-Tage-Wert (`Stats14`) zählt weiter nur 14 Tage. Bestehende Daten bleiben.
  - **Schnittstellen für Ledger:** `mod:History(itemID)` → je Tag/Woche Min, Median, Menge, Scans, Absatz je Tag (ab 1 Std. Beobachtung), üblicher Bereich an diesem Tag (aus den Tagen bis dahin); `mod:MarketInfo(itemID)` → aktueller Stand (Min, Median, Menge, Bereich, Trend, Vorschlag, Händler, Warenart, Absatz je Std. mit Stufe); `mod:DayOf(t)` (Tage wie Broker).
  - **Reiter Preise:** Knopf „Mehr… (Ledger)“ neben „Zur Einkaufsliste“ (nur mit Ledger) öffnet den Gegenstand im Ledger-Reiter „Gegenstand“.

## 0.26.0

- 0.26.0 (03.10.2026, Befund KarloDerBaer „Abgefangene Kiste“: 55 Stück als Schnäppchen bei 323 Angeboten, Absatz 0,0/Std., Preis im freien Fall; mit KarloDerBaer abgestimmt):
  - **Wiederverkauf höchstens zur Untergrenze des üblichen Bereichs** (der Preis, den Verkaufen bei Dumping vorschlägt); ohne Bereich (unter 3 Tagen) höchstens Mitte zwischen Dumping-Grenze und Vergleichspreis (85 % bei DG 30 %). Gilt auch für den Gewinn bei Teilkauf (F33b). Kiste: Wiederverkauf 1s 59c statt 4s 50c → nur noch 7 Stück zu 1s lohnen (≈ 3s 50c) → unter dem Mindestgewinn, kein Schnäppchen.
  - **Menge höchstens Absatz je Std. × `dealHold`** (Standard 48 Std., Optionen „Markt: verkaufen innerhalb“). Erst ab gelbem ≈ (mind. 60 Min. beobachtet); Absatz 0/Std. = kein Markt-Schnäppchen. Rotes ≈ oder kein Absatz: Menge nicht begrenzt, Hinweis im Zeilen-Tooltip.
  - Zeilen-Tooltip im Radar: „Wiederverkauf: X je Stück (vor 5 % Anteil, höchstens Untergrenze des üblichen Bereichs)“, „Absatz ≈ x/Std. – höchstens n St. in 48 Std.“ bzw. „Absatz unbekannt oder unsicher – Menge nicht begrenzt“ (orange).
  - Händler-Schnäppchen unverändert.

## 0.25.2

- 0.25.2 (03.10.2026, Wunsch KarloDerBaer): Box „Broker Herstellen“ verdeckte die Leiste mit Berufs-Symbolen rechts am Berufsfenster. Die Box rückt jetzt hinter alles, was rechts an der Fensterkante klebt (sichtbare Rahmen am Fenster oder an UIParent, die an der rechten Kante beginnen, höchstens 140 breit, innerhalb der Fensterhöhe; `C.SideOffset`), sonst 4 Punkte Abstand. Im Spiel prüfen, ob die Leiste erkannt wird.

## 0.25.1

- 0.25.1 (03.10.2026, Wunsch KarloDerBaer): Zeile „Post“ auf der Startseite entfernt – ohne Besuch am Briefkasten liefert das Spiel keinen Inhalt, und beim Öffnen wird die Post ohnehin geleert. Startseite: Meine Auktionen, Verkaufen, Radar, Einkaufsliste, Scan.

## 0.25.0

- 0.25.0 (03.10.2026, Ledger Z3): Verkaufen zeigt „Unter deinen Kosten (X je Stück, Ledger)“ (orange), wenn der Erlös je Stück nach 5 % Anteil unter den Kosten des nächsten Stücks aus Ledger liegt (`ledger:Cost`).

## 0.24.0

- 0.24.0 (03.10.2026, Feedback-Liste und offene Punkte, mit KarloDerBaer abgestimmt), neue Dateien Start.lua und Craft.lua (**WoW komplett neu starten**):
  - **Reiter „Start“ – Was steht an?** (ganz links, am Auktionshaus öffnet das Fenster damit): je Zeile Meine Auktionen (unterboten / laufen / verkauft), Post (Gold in der Post aus Ledger `mod:MailInfo`, verkaufte Auktionen), Verkaufen (lohnende Gegenstände in den Taschen mit Wert, Händlerwert der übrigen), Radar (Schnäppchen in den letzten Daten, Händler/AH, bester Gewinn; höchstens alle 30 Sek. neu gerechnet), Einkaufsliste (Gegenstände unter dem Höchstpreis), Scan (letzter, nächster möglich; Klick startet den Scan, wenn möglich). Klick auf eine Zeile öffnet den Reiter. Beim Öffnen werden die eigenen Auktionen abgefragt.
  - **Berufe** (Craft.lua): beim Öffnen eines Berufs werden die erlernten Rezepte gelesen (`GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeSchematic`, nur Pflicht-Material) und je Charakter gemerkt. Box rechts am Berufsfenster (`ProfessionsFrame` oder `TradeSkillFrame`): gewähltes Rezept mit Material einzeln, Materialkosten (günstigstes Angebot), Wert (Zeile 1 des Tooltips), Gewinn, „Lohnt sich / Lohnt sich nicht“, darunter die 5 besten Rezepte. Tooltip mit Umschalt: „Herstellen: Material X · Gewinn Y“. Im Spiel prüfen: welches Berufsfenster Forever nutzt und ob das gewählte Rezept erkannt wird (sonst zeigt die Box nur die besten Rezepte).
  - **Meine Auktionen** (Feedback #4): beim Öffnen des Reiters neu laden und danach automatisch live prüfen.
  - **Radar „weg“, obwohl noch da** (Feedback #5, hoch): Im Radar-Protokoll waren es fast nur Gegenstände mit Zusatz („… des Wolfs“, „… der Heilung“) – die Suche mit dem Schlüssel aus `MakeItemKey(itemID)` lieferte vollständig 0 Angebote. Forever-Links haben den Zusatz nicht im Link-Feld 7, deshalb liegen alle Varianten unter der itemID. Jetzt: bleibt die Suche nach der zweiten Prüfung leer, sucht Broker den Gegenstand über die Browse-Suche (Grundname, wie das Suchfeld des Auktionshauses), nimmt den Schlüssel des Spiels mit dem günstigsten Angebot, merkt ihn (`itemKeys`) und prüft gleich nochmal; erst wenn auch das nichts findet, „weg“. Gilt auch für Einkaufsliste und Anzeige im Blizzard-Fenster. Protokoll `keyLog` (Standard-Schlüssel und gefundene Schlüssel) – zeigt beim nächsten Test, wie Forever Zusätze im Schlüssel ablegt.
  - **Schnellkauf mit einem Klick** (Feedback #6): Für das beste Händler-Schnäppchen (Massenware) holt Broker den Preis schon vorher (`StartCommoditiesPurchase`, alle 15 Sek. erneuert); der Knopf heißt dann „Händler: jetzt kaufen“ und bestätigt sofort (alles, was das Gold hergibt). Preis zu hoch: verworfen, Treffer wird neu geprüft. Antwortet das Spiel zweimal nicht, bleibt es für die Sitzung bei zwei Klicks. Einzelgegenstände: weiter ein Klick je Auktion (verlangt das Spiel).
  - **Graue Zeilen („weg“)** (Feedback #7): Klick zeigt den Gegenstand trotzdem im Blizzard-Fenster; Radar pausiert solange, die Zeile bleibt, solange sie gewählt ist.
  - **Händler-Knopf „Schnäppchen verkaufen“ entfernt** (Feedback #8): Merchant.lua gelöscht, `vendorFlip` wird gelöscht.
  - **Einkaufsliste**: neue Spalte „Vorrat“ (grau, wenn die Wunschmenge erreicht ist) und derselbe Umschalter „Vorrat aller Charaktere (Ledger)“ wie im Reiter Behalten.
  - **Verkaufen**: Hinweis mit der eigenen Verkaufsquote aus Ledger („Deine Verkäufe (30 T.): 3 von 4 verkauft (75 %)“, orange unter 50 %).
  - Bereiche für Peon_Feedback: Start, Verkaufen, Behalten, Meine Auktionen, Einkaufsliste, Radar, Preise, Berufe, Scan, Tooltip, Fenster, Optionen („Händler“ entfällt).
  - Erledigt und aus den offenen Punkten genommen (KarloDerBaer): „Abverkauf“ (= Absatz je Stunde seit 0.23) und „Vorschlag bei stark schwankenden Preisen“ (= Richtwert/üblicher Bereich seit 0.21).

## 0.23.1

- 0.23.1 (03.10.2026, mit KarloDerBaer abgestimmt):
  - **Aktueller Absatz je Stunde** aus den Vergleichen der letzten 6 Std. (einstellbar 1–24; einzelne Vergleiche in `e.ar`, 24 Std.). 14-Tage-Wert nur noch intern (Preise-Einzelheiten, `/broker absatz`, später Verbindung mit der Verkaufsquote).
  - **Sicherheit nach beobachteter Zeit** statt Zahl der Vergleiche, **Zeichen „≈“ immer da**: rot unter 60 Min., gelb ab 60, grün ab 180 Min. (einstellbar). Zahl weiß.
  - **Live-Vergleiche schon ab 1 Min. Abstand** (Neuladen beim Verkaufen, Radar liefern schnell Daten).
  - **Tooltip ohne Reichweite**: „Absatz (6 Std.): ≈ 30/Std. · 70 % verkauft“. Verkaufen mit Reichweite in Std./Tagen („reicht 15 Std.“ = bei diesem Absatz ist alles im Auktionshaus nach 15 Std. verkauft). Hinweise „Verkauft sich schnell“ (reicht unter 24 Std.) / „Markt ist voll“ (über 7 Tage) / „Läuft oft ab“ erst ab gelbem ≈. Preise: Spalte „Absatz/Std.“.
  - **Restzeit-Stufen 1–4** (Bedeutung aus `Enum.AuctionHouseTimeLeftBand`, wenn das Spiel sie mit 1–4 liefert, sonst fest 1–4).
  - Absatz-Daten aus 0.23.0 werden einmal verworfen (`salesVer` = 2), Preise bleiben.

## 0.23.0

- 0.23.0 (03.10.2026, **Absatzquote A1**, Konzept `Peon_Broker_Absatz.md`, mit KarloDerBaer abgestimmt), neue Datei Sales.lua:
  - **Vergleich zweier Beobachtungen** je Gegenstand (mind. 10 Min., höchstens 24 Std. Abstand): Live-Abfragen mit Auktionsnummer und Restzeit (`e.as`, 30 günstigste Angebote), Komplettscan ohne Nummer mit Restzeit-Stufe aus `GetReplicateItemTimeLeft` (`e.ss`, 15 günstigste). Gleicher Zeitraum wird nur einmal gezählt (`e.acov`; Live vor Scan).
  - **Regeln:** Menge kleiner = verkauft; weg und Ende vorbei = abgelaufen; weg vor dem Ende: Massenware – stand ein günstigeres Angebot in beiden Beobachtungen (auch teilweise gekauft) oder wurde dieselbe Menge billiger neu eingestellt = abgebrochen, sonst verkauft; Einzelgegenstand = verkauft abzüglich Schätzwert Abbrüche (Standard 10 %). Ende unklar = nicht gezählt. Nur bis zum höchsten in beiden sicher gesehenen Preis. Scan ohne Restzeit: nur bis 2 Std. Abstand.
  - **Werte (14 Tage, `e.ab` Tageswerte):** Absatz je Tag = verkauft ÷ beobachtete Zeit; Absatzquote = verkauft ÷ (verkauft + abgelaufen); Reichweite = Menge im Auktionshaus ÷ Absatz je Tag.
  - **Anzeige ab dem ersten Vergleich:** Sicherheit als Zeichen „≈“ (grau bis 4 Vergleiche, gelb ab 5, ohne Zeichen ab 15); Farbe der Zahl nach Reichweite (grün unter 1 Tag, rot über 7 Tage, sonst weiß). Tooltip mit Umschalt „Absatz (14 T.): ≈ 120/Tag · reicht 2 T. · 70 % verkauft“; Verkaufen: Zeile „Absatz“, Hinweise „Verkauft sich schnell“ / „Markt ist voll“ / „Läuft oft unverkauft ab – lieber Händler?“ (Quote unter 50 %, ab gelb); Preise: Spalte „Absatz/Tag“ und Zeile in den Einzelheiten.
  - **Optionen „Absatz (Markt)“:** Schwellen gelb/sicher, Anteil Abbrüche bei Einzelgegenständen, Reichweite grün/rot.
  - Chat: `/broker absatz <Name, Nummer oder Link>` – Zähler (verkauft, abgelaufen, abgebrochen, beobachtete Stunden, Vergleiche).
- Test 0.23.0 (KarloDerBaer, 03.10.2026): Tooltip zeigte „≈ 0,0/Tag · reicht > 99 T.“ rot und „Markt ist voll“, obwohl die Mengen bei Erdwurzel sichtbar sanken. Ursache: nur ein Vergleich (zwei Scans 15 Min. auseinander, dabei nichts verändert), Live-Vergleiche erst ab 10 Min. Abstand; der 14-Tage-Wert ist für „jetzt verkaufen“ nutzlos. Außerdem: **Restzeit-Stufen im Komplettscan sind in Forever 1–4** (gesehen: 1: 3.926, 2: 13.714, 3: 58.287, 4: 16.690 Angebote), nicht 0–3 wie in Retail.

## 0.22.1

- 0.22.1 (03.10.2026): `/broker pruefen scan` liest zusätzlich die Restzeit je Angebot (Beispiele „|| Restzeit …“) und zählt die Stufen über alle Angebote (`probe.scan.timeLeftBands`) – zeigt, ob Forever echte Werte liefert.

## 0.22.0

- 0.22.0 (03.10.2026, **Ledger L6 – Zusammenspiel**, abgestimmt mit KarloDerBaer):
  - **Reiter „Buch“ entfällt** (Buch in Peon_Ledger); sechs Reiter. Bereich „Buch“ für Peon_Feedback entfernt.
  - **Behalten:** neuer Umschalter unten links „Vorrat aller Charaktere (Ledger)“ (`keepAllChars`, Standard aus, nur sichtbar mit Ledger). An: Vorrat = Taschen + Bank dieses Charakters + Taschen, Bank und Post der Twinks + Accountbank (Ledger `mod:StockOthers`). Gilt auch für „zu verkaufen“ (Reiter Verkaufen, Tooltip „Behalten“). Neue Spalte „Twinks“.
  - **Tooltip (mit Umschalt):** Zeile „Deine Verkäufe (30 T.): 3 von 4 verkauft (75 %)“ aus Ledger (`mod:SellRate`), nur wenn es eigene Auktionen gab; Prozent ab 3 Stück.
  - **Schnittstelle für Ledger:** `mod:ItemValue(itemID, Stück)` = Wert wie Zeile 1 des Tooltips (günstigstes Angebot bzw. Händlerpreis).
  - **Prüfung für die Absatzquote** (nur lesend, läuft automatisch mit): Beim Lesen von Suchergebnissen (Verkaufen, Radar, Einkaufsliste) werden je Art (Massenware/Einzelgegenstand) die vorhandenen Felder gezählt (bis 500 Ergebnisse) und 5 Beispiele gespeichert: `PeonBrokerDB.fieldProbe`. Auswertung im Chat: `/broker pruefen auktionen` (wichtig: auctionID, timeLeftSeconds/timeLeft, owners).
  - **Komplettscan** (`/broker pruefen scan`, Ergebnis in `PeonBrokerDB.probe.scan`): `GetReplicateItemInfo` liefert wie in Retail 18 Werte je Angebot – **keine Auktionsnummer, Verkäufer leer (nil)**. Bestätigt mit warcraft.wiki.gg (03.10.2026): Besitzer ist seit Patch 9.0.2 immer nil außer bei eigenen Auktionen. **Restzeit gibt es aber über eine eigene Funktion** `C_AuctionHouse.GetReplicateItemTimeLeft(index)` (in Forever vorhanden) als Stufe 0–3 (`Enum.AuctionHouseTimeLeftBand`: bis 30 Min., 2 Std., 12 Std., 2 Tage). Laut Wiki haben auch die Einzelabfragen `auctionID` und `owners`; Massenware `timeLeftSeconds` (kann fehlen), Einzelgegenstände `timeLeft` (Stufe) und `timeLeftSeconds`.

## 0.21.3

- 0.21.3 (02.10.2026): Meine Auktionen erkennt die Qualität (Namensfarbe) auch aus Links im Forever-Format `|cnIQ3:` (gefunden mit der Ledger-Prüfung).

## 0.21.2

- 0.21.2 (02.10.2026, Feedback Nr. 3 von KarloDerBaer, Fehler/Verkaufen/hoch): Beim Einstellen kam manchmal „Der Gegenstand ist nicht mehr in den Taschen“, obwohl er da war. Ursache: Die Taschenliste überspringt gesperrte Plätze, und ein Platz ist gesperrt, solange der Gegenstand im Verkaufsfenster des Auktionshauses liegt (oder gerade eingestellt wird) – lag nur ein Stapel in den Taschen, fand Broker keinen. Jetzt eigene Suche beim Einstellen: freie Plätze zuerst, sonst auch gesperrte; über das Blizzard-Fenster wird ohnehin der Gegenstand eingestellt, der dort liegt. Test gegen das alte Verhalten geprüft.
- Test 0.21.x (KarloDerBaer, 02.10.2026): „bis jetzt schaut alles gut aus“.
- Post einsammeln und Buch kommen ins **neue Modul Peon_Ledger** (Konzept `Peon_Ledger_Konzept.md`, abgestimmt 02.10.2026); Broker nutzt es später nur lesend (Vorrat aller Charaktere, Verkaufsquote).

## 0.21.1

- 0.21.1 (02.10.2026):
  - Nach jedem Umschalten lädt Broker Blizzards Liste einmal neu wie der Knopf „Neu laden“ (Liste leeren mit `ItemList:Reset()`, dann `Refresh…SearchResults`), sobald das Spiel bereit ist und keine eigene Abfrage läuft. Danach Prüfung, ob die Ergebnisse zum Gegenstand gehören; sonst bis zu 3 Versuche (neu laden, eigene Suche, nochmal zeigen). Protokoll in `PeonBrokerDB.showLog` (40 Zeilen).
  - Umschalten wartet, bis keine eigene Broker-Abfrage mehr unterwegs ist (sonst überholen sich die Suchen).
  - Ergebnisse eines anderen Gegenstands (Link/Schlüssel passt nicht) werden nicht mehr gelesen (`rows.foreign`) und zählen wie „lädt noch“.
  - Radar: gewählter Treffer wird nicht mehr alle 5 Sek. neu abgefragt (Blizzard-Fenster lud dadurch ständig neu); geprüft wird beim Anklicken, nach einem Kauf und vor dem Kauf.

## 0.21.0

- 0.21.0 (02.10.2026): **Richtwert und üblicher Bereich** (Rechenmodell Kapitel 7, F35–F41, mit KarloDerBaer abgestimmt): aus den Tagesmedianen der letzten 14 Tage robuste Mitte und Schwankung (mind. 5 %), gleitender Mittelwert (Halbwertszeit 3 Tage, Ausreißer gekappt); Richtwert = mittlerer Wert aus jetzt, heute und gleitendem Mittel; zwei Messungen außerhalb des Bereichs = „Preis fällt/steigt“, dann folgt der Richtwert dem Markt. Ab 3 Tageswerten, sonst bisheriges Verfahren (`D.Band`, `D.Suggest(min, median, key, db, e, vor)`).
  - Vorschlag: Dumping nur noch unter dem üblichen Bereich und wenn der Markt nicht fällt; dann Untergrenze minus Unterbieten.
  - **Zeile 1 im Tooltip** und Wert im Reiter Verkaufen: günstigstes Angebot minus Unterbieten (statt Vorschlag), Farbe grün (gut), orange (Markt fällt), rot (Dumping); Händler weiter, wenn er mehr zahlt. Mit Umschalt neue Zeile „Üblich (n Tage) X – Y“ (+ fällt/steigt), Hinweise „Preis fällt“ / „Dumping … unter dem üblichen Bereich“.
  - Verkaufen: Hinweise „Üblich: X – Y (n Tage)“, „Preis fällt/steigt“, „Über dem üblichen Bereich – guter Zeitpunkt“. Preise-Reiter: Bereich und Richtwert.
  - Radar: Markt-Schnäppchen gegen den Richtwert; fällt der Markt, keine Markt-Schnäppchen. Vorauswahl beim Öffnen weiter gefasst (unter Händlerpreis oder unter Median).

## 0.20.2

- 0.20.2 (02.10.2026): Vermutung: Das Spiel schickt eine Suche nicht ab, wenn es für den Gegenstand schon (alte) Ergebnisse hat, oder nimmt gerade keine Abfrage an. Jetzt: Broker schaltet das Blizzard-Fenster erst um, wenn das Spiel bereit ist; kommt danach 0,8 Sek. kein Ergebnis für den Gegenstand, lädt Broker die Liste wie Blizzards Knopf neu (`RefreshItemSearchResults` / `RefreshCommoditySearchResults`, im Spiel vorhanden laut Prüfbefehl). Der gewählte Radar-Treffer wird ebenfalls so neu geladen. Meine Auktionen: leeres Ergebnis zählt nicht als „günstigster“ (dann gilt der Scan), Ergebnisse auch unter dem Schlüssel der Auktion gesucht; Protokoll der letzten 30 Ergebnisse in `PeonBrokerDB.aucLog`.
- Test 0.20.2 (KarloDerBaer, 02.10.2026): Umschalten bei Meine Auktionen weiter unzuverlässig (Titel richtig, Liste vom vorherigen Gegenstand), im Radar langsam und lädt immer wieder neu. `aucLog` zeigte: die Ergebnisse für den angeklickten Gegenstand kamen jeweils an – Blizzards Liste wurde trotzdem nicht aufgefrischt.

## 0.20.1

- 0.20.1 (02.10.2026): Vermutete Ursache: Bei Einzelgegenständen meldet das Spiel das Such-Ergebnis zuerst leer und noch unvollständig (lädt noch); Broker las „0 Angebote“ als „weg“. Jetzt: leeres und unvollständiges Ergebnis = weiter warten (auch auf `ITEM_SEARCH_RESULTS_ADDED` / `COMMODITY_SEARCH_RESULTS_ADDED`), in Radar, Verkaufen, Einkaufsliste und Meine Auktionen; kommt in die Datenbank nicht als „weg“. Zusätzlich glaubt der Radar „keine Angebote mehr“ erst nach einer zweiten Prüfung 3 Sek. später (`R.CONFIRM_AFTER`). Radar-Protokoll mit Anzahl Stufen und Schlüssel des Ereignisses; Zähler `radarStats.loading` und `emptyOnce`.
- Test (KarloDerBaer, 02.10.2026): Meine Auktionen – Klick auf „Bauplan: Arkaner Wiederverwerter“ schaltete Blizzard auf den richtigen Gegenstand, die Liste darunter zeigte aber noch die Angebote von „Pläne: Jadeschlangenklinge“; erst Blizzards „Neu laden“ half. Spalte „Günstigster“ zeigte „–“ und Status „günstigster“, obwohl es billigere Angebote gab.

## 0.20.0

- 0.20.0 (02.10.2026, Fehler und Wünsche von KarloDerBaer):
  - **Teil-Ergebnisse** (wichtigster Fehler): Das Auktionshaus liefert große Ergebnislisten in Teilen (`HasFullCommoditySearchResults` / `HasFullItemSearchResults`, wie Blizzards eigene Liste). Broker las bis 0.19 nur den ersten Teil und schrieb daraus Median und Menge in die Datenbank – der Median fiel, Markt-Schnäppchen verschwanden nach der nächsten Prüfung, und der Vorschlag beim Verkaufen wurde falsch. Jetzt: `rows.partial`; bei Teil-Ergebnissen werden nur Minimum und günstigste Stufen übernommen, Median und Menge bleiben; der Vorschlag nimmt dann den Median aus der Datenbank. Zähler `radarStats.partial`.
  - **Radar – weggefallene Treffer**: verschwinden nicht mehr stillschweigend, sondern bleiben 30 Sek. grau in der Liste mit „weg“ und Grund (keine Angebote mehr; günstige Angebote weg – günstigstes jetzt X; Wiederverkauf lohnt nicht mehr; unter Mindestgewinn / mit deinem Gold nicht; Preis beim Kauf gestiegen; gekauft; neue Daten). Grund im Tooltip und unter der Liste; Rechtsklick nimmt die graue Zeile weg. Protokoll der letzten 200 in `PeonBrokerDB.radarLog` (Zeit, Gegenstand, Grund, vorher/jetzt).
  - Radar: Ergebnisse, die das Spiel schon hatte (ohne Antwort auf die Abfrage), entfernen keinen Treffer mehr und kommen nicht in die Datenbank (können alt sein). Live geprüfte Treffer bleiben beim Neuladen des Reiters so lange wie `radarMaxAge` (vorher 5 Min.).
  - **Radar pausiert, solange ein Treffer gewählt ist** (jede fremde Abfrage verändert sonst die Anzeige im Blizzard-Fenster); gewählte Zeile nochmal anklicken = Auswahl aufheben, Radar läuft weiter. Statuszeile sagt es.
  - **Blizzard-Fenster**: `SelectBrowseResult` tut nichts, solange das Spiel die Daten zum Gegenstand nicht hat (`GetItemKeyInfo` = nil) – das Fenster zeigte dann weiter den alten Gegenstand. Broker wartet jetzt darauf (`ITEM_KEY_ITEM_INFO_RECEIVED`, sonst alle 0,3 Sek., bis 10×) und prüft, ob umgeschaltet wurde. Reiterwechsel schaltet Blizzard passend um (`W.SetAHMode`, neue Seiten-Funktion `enter`): Meine Auktionen → „Auktionen“, Radar/Einkaufsliste ohne Auswahl → „Kaufen“, Verkaufen → gewählter Gegenstand wieder ins Verkaufsfenster.
  - **Meine Auktionen**: Klick auf eine Auktion zeigt die aktuellen Angebote des Gegenstands im Blizzard-Fenster; deren Ergebnis aktualisiert gleich „Günstigster“ und Status.
  - **Verkaufen**: eingetragen wird immer das günstigste Angebot minus Unterbieten (auch bei Dumping), Untergrenze Mindestpreis (Händler). Der Vorschlag bleibt Richtwert: Hinweis „Unter dem Vorschlag X (n % weniger)“, rot bei starkem Abstand, mit Dumping-Grund. Rückfrage nur noch, wenn im Blizzard-Fenster von Hand noch tiefer eingetragen wird. Beschriftung „Preis je Stück“. Wird auf den Mindestpreis angehoben: Hinweis „Lieber beim Händler verkaufen“ und Erlös orange (Rechenmodell F23a).
- Test 0.20.0 (KarloDerBaer, 02.10.2026): Änderungen gefallen. Aber: Ausrüstung/Einzelgegenstände (z. B. 15-pfündiger Matschschnapper, mehrere „des Champions“/„der Ausdauer“) standen im Radar als „weg – keine Angebote mehr“, obwohl das Angebot im Blizzard-Fenster noch da war.

## 0.19.1

- 0.19.1 (02.10.2026): meldet Bereiche für Peon_Feedback (Verkaufen, Behalten, Meine Auktionen, Einkaufsliste, Radar, Preise, Buch, Scan, Tooltip, Händler, Fenster, Optionen); eine Zeile am Ende von Broker.lua, sonst unverändert.
- Vergleich mit Auctionator, TSM, Journalator, Auctioneer, aux (02.10.2026, im Chat): Broker hat die meisten Werkzeuge, es fehlt ein roter Faden. KarloDerBaer hat daraus die Punkte unter „Offene Punkte“ beschlossen; Tastenbelegungen, Preisgrenzen je Gegenstand und ein Verkaufs-Durchlauf werden vorerst nicht gebraucht.

## 0.19.0

- 0.19.0 (01.10.2026, Wünsche von KarloDerBaer, Fragen abgestimmt):
  - **Eine Spalte „Gewinn“**: höchster Gewinn mit meinem Gold (Gold minus Goldreserve; Kandidaten 1 Stück, jedes Stufenende, was das Gold hergibt). Sortierung, Mindestgewinn und Schnellkauf richten sich danach. Spalte „Menge“ zeigt „mit meinem Gold / ganzes Schnäppchen“ (z. B. 51/60). Spalten Gewinn je Stück / je Stapel entfallen. Tooltip der Zeile: „Mit meinem Gold: …“ und „Ganzes Schnäppchen: …“.
  - **Mindestgewinn** für Händler (H) und AH direkt im Reiter (Geldbeträge wie „50s“, „1g 20s“, „10c“; Zahl ohne Einheit = Silber) und in den Optionen; Händler jetzt bis 1000g. Neue **Goldreserve** (Optionen): gibt der Radar nie aus.
  - **Schnellkauf „Händler: Bestes kaufen“** (unten links): bestes Händler-Schnäppchen, alles was ich mir leisten kann. Massenware: Preis vom Spiel, dann Bestätigen; Einzelgegenstände: ein Klick je Auktion.
  - **Mehrere Einzelgegenstände kaufen**: Knöpfe auch bei Nicht-Massenware (1 Stück / ab Gewinn n Stück / Alle), ein Klick je Auktion, Knopf zählt mit („Weiter (2 übrig)“). Mittlerer Knopf = Menge ab Gewinn, wenn erst ab n Stück Gewinn; sonst bei Massenware bis ein Stapel.
  - **Gewählter Treffer** wird gleich im Auktionshaus gezeigt (Broker wartet, bis keine eigene Abfrage unterwegs ist, und nimmt die Antwort auf die Anzeige des Auktionshauses als Prüfung) und danach alle 5 Sek. neu abgefragt (aktualisiert auch das Blizzard-Fenster), auch ohne Radar-Scan, bis Auswahl/Reiter wechselt.
  - **Neue Treffer**: ganze Zeile pulsiert grün (Optionen: 0–30 Sek., Standard 5), grüner Punkt als eigenes Bild (das Zeichen ● fehlte in der Spielschrift → Viereck), Warnton wählbar (Schlachtzugswarnung, Bereitschaftscheck, Wecker, Flüstern; Kanal „Master“) mit Hörprobe. Vorher `SOUNDKIT.MAP_PING`.
  - **Händler-Schnäppchen** farbig: Zeile dezent gold, „H“ und Gewinn gold.
  - **Ausblenden**: keine Chatmeldung mehr; Knopf „Alle ausblenden“ (alle sichtbaren), in der Ausgeblendet-Liste „Alle wieder zeigen“.
  - **Broker-Scan beendet den Radar-Scan**; während des Scans keine Radar-Abfragen und kein Start („Broker-Scan läuft – Radar pausiert“).
  - **Händlerware am Händler verkaufen** (Merchant.lua): was der Radar als Händler-Schnäppchen kauft, wird je Charakter gemerkt; am Händler Knopf „Broker: Schnäppchen verkaufen (n · Wert)“ über dem Händlerfenster, verkauft ganze Stapel, nie mehr als gemerkt.
  - Tooltip: Händlerpreis in den Details **immer und je Stück** („Händler 5c je Stück“).
  - Unten drei Reihen: Schnellkauf | Mindestgewinn H/AH; Stand | Anzeige | Reihenfolge | Scan; gerade geprüft | Alle ausblenden | Ausgeblendet (n) | Nur Warnton.
- Nächster Schritt: KarloDerBaer testet 0.19.0 (**WoW komplett neu starten** – neue Dateien Merchant.lua und dot_new.tga, Kern 0.8.0). Danach Bauabschnitt „Buch“.

## 0.18.0

- 0.18.0 (30.09.2026, Wünsche von KarloDerBaer, Ausblenden abgestimmt):
  - **Kaufzeile direkt unter der Liste** für den gewählten Treffer: Name, Menge des Schnäppchens, Hinweis „Gewinn erst ab n Stück“ bzw. „Bei keiner Menge Gewinn“; Knöpfe „1 Stück“, „n Stück“ (bis ein Stapel, nur wenn weniger als alle) und „Alle (n)“ mit Kosten und Gewinn (grün/rot) darunter; grau mit „Nicht genug Gold“, wenn es nicht reicht. Einzelgegenstände nur „1 Stück“. Gewinn für jede Menge nach F33b (Rechenmodell).
  - Schnellkauf-Knöpfe unten entfernt. Scan-Einstellungen ganz unten: Stand | Anzeige | Reihenfolge | Scan; darunter gerade geprüfter Gegenstand | „Ausgeblendet (n)“ | Nur Warnton. Liste 14 Zeilen.
  - **Rechtsklick blendet aus** (alle Charaktere, je Markt, `PeonBrokerDB.radarHidden`): bleibt weg, solange Prüfungen (live oder voller Scan) es als Schnäppchen sehen; ist es einmal keins, wird es wieder frei und erscheint, wenn es wieder eins wird. Wird weiter abgefragt; kein Ton. Knopf „Ausgeblendet (n)“ öffnet eine Liste, Klick zeigt wieder.

## 0.17.0

- 0.17.0 (30.09.2026, mit KarloDerBaer abgestimmt):
  - **Markt-Schnäppchen neu (F33):** Wiederverkauf gegen das nächste Angebot nach dem Kauf (höchstens Median), Mindestmarge je Stück (`dealMargin`, 20 %), höchstens 20 % aller Angebote (`dealDepth`); beste Kaufmenge wird gesucht. 12 statt 5 Preisstufen gespeichert.
  - Spalten: Gewinn je Stück, Gewinn je Stapel (nur Massenware, Stapelgröße des Spiels, höchstens Schnäppchen-Menge), „Wiederverk.“ statt „Vergleich“, „Art“ als H/AH, Spalte „Daten“ in den Tooltip (dort auch Wiederverkauf/Händlerpreis und ganzes Schnäppchen). Sortierung und „bestes“ nach Gewinn je Stück.
  - Kaufen je Stück oder Stapel: unten vier Knöpfe (Händler 1×, Händler Stapel, AH 1×, AH Stapel) mit dem Preis genau dieses Kaufs; für die gewählte Zeile ebenso zwei Knöpfe. Nach einem Teilkauf bleibt der Treffer und wird neu geprüft.
  - Auswahl „Händler + AH / Nur Händler / Nur AH“ (`radarKind`) für Anzeige und Scan.
  - Gold: Schnäppchen, von denen ich mir kein Stück leisten kann, werden nicht angezeigt (Einstellung „auch Schnäppchen zeigen, die ich mir nicht leisten kann“ zeigt sie grau, nicht kaufbar); Stapel nur so groß, wie das Gold reicht.
  - Datenlade-Prüfung auch bei Schnellprüfung und Nachprüfen der Treffer.

## 0.16.0

- 0.16.0 (30.09.2026, Wünsche von KarloDerBaer):
  - Text „Wähle ein Schnäppchen“ und die Zähler-Zeile entfernt (Zähler weiter in `radarStats`).
  - Zweite Statuszeile: welcher Gegenstand gerade abgefragt wird („Prüfe: [Symbol] Name“).
  - Auswahl der Reihenfolge im Reiter (Dropdown, `radarOrder`): smart (bisher, beste 400 nach Wert × Menge), zufällig, Massenware zuerst, höchster Preis zuerst, niedrigster Preis zuerst (Preis = Median); Einkaufslisten und Nachprüfen der Treffer immer zuerst. Nach jeder Runde wird die Liste mit frischen Daten neu gebaut.
  - „Nur Warnton“ (Haken im Reiter, Standard an, `radarMute`): während des Radar-Scans Effekte, Musik, Umgebung, Dialog auf 0, „Gesamt“ bleibt (dort spielt der Warnton), Ton auch im Hintergrund und Ton allgemein an. Zurück beim Stoppen, Verlassen des Reiters, Schließen des Auktionshauses, Ausloggen/Reload; alte Werte solange in `PeonBrokerDB.radarMuteSaved` (beim nächsten Start zurückgesetzt, falls das Spiel abstürzt).
  - Vermutung zu den Abfragen ohne Antwort: Gegenstandsdaten nicht geladen. Radar prüft jetzt vorher `C_Item.IsItemDataCachedByID`, fordert fehlende Daten an und fragt den Gegenstand später ab; `timeoutLog` vermerkt „ungeladen“.
- Ergebnis 0.16.0 (30.09.2026): ~560 Abfragen, 549 Antworten, 11 ohne Antwort – **alle bei ungeladenen Gegenstandsdaten** (Vermutung bestätigt); sie kamen über Schnellprüfung/Nachprüfen, wo die Prüfung noch fehlte. ~83/Min.
- Befund KarloDerBaer: viele Markt-Treffer sind keine Schnäppchen (z. B. Abgefangene Kiste: 103 Stück zwischen 50s und 70s, Median durch 120 Stück zu 1g 26s hochgetrieben; Deviatschuppe 1172 Stück).

## 0.15.0

- 0.15.0 (30.09.2026): **Live-Ergebnisse im aktuellen Stand** (Rechenmodell Kapitel 6, mit KarloDerBaer abgestimmt): jede Live-Abfrage (Radar, Einkaufsliste, Verkaufen, Meine Auktionen) schreibt Min, Median, Menge, Preisstufen bzw. „weg“ in die Datenbank (`e.lt` = Zeit); Verlauf, Scan-Zahl und Trend bleiben reine Scan-Werte. Nächster Scan markiert auch nur live gesehene Gegenstände als weg, wenn sie fehlen. Tooltip/Preise nutzen „zuletzt gesehen“ (Scan oder live).
  - Radar beim Öffnen: alle Schnäppchen aus der Datenbank bis `radarMaxAge` (Standard 60 Min., 0 = unbegrenzt), jeder einmal live geprüft; weggefallene kommen nicht wieder. Spalte „Gesehen“ zeigt das Alter der Daten (z. B. „40 Min.“), nach der Prüfung Sekunden.
  - Radar-Tempo: prüft alle 0,1 s, ob die nächste Abfrage raus darf (Abstand weiter mind. 0,65 s), statt fest alle 0,65 s – weniger Leerlauf nach „Spiel nicht bereit“. Gegenstände, die zweimal in Folge ohne Antwort bleiben, werden für die Sitzung ausgelassen. `AUCTION_HOUSE_NEW_RESULTS_RECEIVED` für den abgefragten Gegenstand zählt als Antwort; vorhandene Ergebnisse werden unter beiden Warenarten gesucht. Zweite Statuszeile: gesendet, Antworten, ohne Antwort, Warten aufs Spiel (Sek.), ausgelassen, Ø. Fehlersuche: `radarStats.timeoutLog` mit den Ereignissen während einer Abfrage ohne Antwort.
- Ergebnis 0.15.0 (langer Lauf 22:01–22:12, 30.09.2026): ~940 Abfragen in ~11½ Min. (≈ 82/Min.), 871 vom Spiel gesendet = 871 Antworten (Ø 0,2 s), 71 ohne Antwort (7,5 %), Warten aufs Spiel nur 5 s. Bei allen Abfragen ohne Antwort kam **kein einziges** Ereignis (auch kein „gesendet“) – das Spiel schickt sie gar nicht ab. Es sind immer wieder dieselben Gegenstände.

## 0.14.5

- 0.14.5 (30.09.2026): Radar wartet nur noch 1 Sek. auf eine Antwort (statt 2). Ohne Antwort liest er die Ergebnisse, die das Spiel schon hat, und wertet sie aus (Zähler `cached`, in „Antworten“ enthalten); nur ohne vorhandene Ergebnisse zählt „ohne Antwort“. Vor einem Kauf (Einzelgegenstand) gilt weiter nur eine echte Antwort.
- Ergebnis 0.14.5 (langer Lauf, 30.09.2026): 343 Abfragen, 266 Antworten (Ø 0,2 s), 77 ohne Antwort (22 %), vorhandene Ergebnisse gab es dafür keine (0). 275 Takte „Spiel nicht bereit“ (je 0,65 s ≈ 3 Min. verloren). Dieselben Gegenstände bleiben immer wieder ohne Antwort (z. B. Flitzdistel, Großer gleißender Splitter, Himmelblauer Farbstoff).

## 0.14.4

- 0.14.4 (30.09.2026): Abfrage-Test um zwei Schritte über die Radar-Funktion selbst ergänzt (gleicher Gegenstand, Gegenstand der Einkaufsliste). Radar zählt „vom Spiel gesendet“ (Ereignis `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`) und protokolliert die ersten 30 Abfragen in `radarStats.log` (Gegenstand, Zeit, Spiel bereit, Anzeige des Auktionshauses, gesendet, Antwort).
- Ergebnis 0.14.4 (30.09.2026): Abfrage-Test alle sechs Wege ok (auch über die Radar-Funktion, auch Flitzdistel). Radar-Scan lief diesmal: 117 Abfragen, 98 vom Spiel gesendet, 98 Antworten (Ø 0,2 s), 19 ohne Antwort, 22× Spiel nicht bereit, nichts abgewiesen; etwa 60/Min. Warum der Lauf davor gar nichts abschickte, bleibt ungeklärt (beobachten). Im Protokoll: Abfragen ohne Antwort waren solche, nach denen das Spiel sofort wieder „bereit“ meldete – die Abfrage ging offenbar nicht wirklich raus; vermutlich hatte das Spiel für den Gegenstand schon Ergebnisse.

## 0.14.3

- 0.14.3 (30.09.2026): Abfrage-Test `/broker pruefen abfrage` – schickt nacheinander eine Abfrage 1. direkt aus dem Befehl, 2. aus dem Ergebnis-Ereignis, 3. aus `C_Timer`, 4. aus `OnUpdate` und meldet je Schritt „gesendet / Antwort“ (Chat und `PeonBrokerDB.queryTest`). Danach wird der Radar-Scan entsprechend umgebaut.
- Ergebnis Abfrage-Test (30.09.2026, Kupfer-/Massenware 8067): alle vier Wege funktionieren (Befehl 0,2 s, Ereignis 0,6 s, Timer 0,2 s, OnUpdate 0,2 s). Timer sind also **nicht** die Ursache. Auffällig: die erste Radar-Abfrage (Flitzdistel aus der Einkaufsliste, 1216 Angebote) wurde auch nicht abgeschickt. Ursache weiter offen.

## 0.14.2

- 0.14.2 (30.09.2026): Fehlersuche Radar-Tempo. Zweite Statuszeile beim Radar-Scan: Antworten, ohne Antwort, Spiel nicht bereit, abgewiesen, Ø Antwortzeit. Zähler auch in `PeonBrokerDB.radarStats` (mit den letzten 20 Gegenständen ohne Antwort). Ereignisse `AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED/QUEUED` werden gezählt; die Ereignis-Liste (Probe) nimmt zusätzlich diese beiden und `UI_ERROR_MESSAGE` (rote Fehlermeldungen wie „zu schnell“) auf.
- Befund 0.14.2 (KarloDerBaer, 30.09.2026): Radar-Scan „Antworten 0, ohne Antwort 11“. In der Ereignis-Liste kam während des Radar-Scans kein einziges `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT` – die Abfragen werden gar nicht abgeschickt (kein Fehler, nicht abgewiesen). Unterschied zu „Liste durchsuchen“ (funktioniert): dort kommt die erste Abfrage direkt aus dem Klick, die weiteren aus dem Ergebnis-Ereignis; der Radar schickt alle aus `C_Timer`. Vermutung: Forever nimmt Suchabfragen aus Timern nicht an.

## 0.14.1

- 0.14.1 (30.09.2026): Knöpfe „alle kaufen“ heißen jetzt **„Händler: Bestes kaufen“ / „AH: Bestes kaufen“** und zeigen nur den Preis des nächsten Kaufs (Massenware: alle Stück bis zur Grenze, Einzelgegenstand: eine Auktion); ohne Treffer „nichts zu kaufen“ (Hinweis von KarloDerBaer: je Klick wird nur ein Angebot gekauft).
- Abfragegrenze: laut Wowpedia und TSM-Blog 100 Suchen pro 60 Sek. (Retail seit 8.3); für Forever nicht bestätigt, Broker nutzt ~92/Min. und wartet zusätzlich auf die Freigabe des Spiels (`IsThrottledMessageSystemReady`). KarloDerBaer testet den Radar-Scan im Dauerlauf.
- KarloDerBaer im Spiel (0.14.0): Radar-Scan läuft nur mit ca. 24 Abfragen/Min. statt ~92. Vermutung: viele Abfragen bekommen keine passende Antwort, Broker wartet dann jeweils 2 Sek. (2,65 Sek. je Abfrage ≈ 23/Min.). Ursache noch offen.

## 0.14.0

- 0.14.0 (30.09.2026): Reiter „Einkaufsliste“ (Buy.lua) und neuer Reiter **„Radar“** (Radar.lua), Fenster 680 breit, sieben Reiter unten.
  - Einkaufsliste: wie bisher, ohne Umschalter.
  - Radar: Schnäppchen (Händler und Markt, Spalte „Gesehen“). Beim Öffnen Treffer aus einem höchstens 5 Min. alten Scan, die sofort einmal live geprüft werden (auch ohne Radar-Scan, je Treffer höchstens 2 Versuche); weg = gleich entfernt.
  - Knopf „Radar-Scan starten/stoppen“: laufend Einzelabfragen alle 0,65 Sek. (~92/Min.), nur solange der Reiter offen ist und das Auktionshaus offen; Reihenfolge ungeprüfte Treffer, jeder dritte Schritt der am längsten nicht geprüfte Treffer (spätestens alle 15 Sek.), Einkaufslisten, bis zu 400 Gegenstände mit den besten Chancen (Median × Menge, Händlerpreis oder gute Datenlage). Anzeige Abfragen je Minute.
  - Neue Treffer: Ton (abschaltbar, Einstellung „Ton bei neuen Radar-Treffern“) und grün mit ● für 60 Sek.
  - Knöpfe „Händler: alle kaufen“ und „AH: alle kaufen“ mit Anzahl und Gesamtkosten; je Klick ein Kauf, höchster Gewinn zuerst. Massenware: Kauf starten → Preis vom Spiel (teurer als die Grenze = Abbruch mit Meldung) → zweiter Klick „Bestätigen“. Einzelgegenstand: nur mit höchstens 10 Sek. alter Prüfung, sonst erst prüfen, dann `PlaceBid`. Zusätzlich Knopf „Kaufen“ für die gewählte Zeile.
  - Einstellung `buyMode` entfällt.

## 0.13.0

- 0.13.0 (30.09.2026, **Bauabschnitt 7**): Reiter „Einkaufen“ (Buy.lua), abgestimmt in `Peon_Broker_Einkaufen.md`, Formeln Rechenmodell Kapitel 5 (F28–F34).
  - Einkaufslisten je Charakter: Listen anlegen/umbenennen/löschen, Rabatt x % unter dem Median je Liste (Median = 7-Tage-Median, bei zu wenig Daten der aktuelle), Wunschmenge je Gegenstand (Kauf bis Wunschmenge minus Vorrat). Hinzufügen per Alt+Klick (im Reiter Einkaufen), Suchfeld (Namen aus den Scans) und Knopf „Zur Einkaufsliste“ im Reiter Preise. „Liste durchsuchen“ fragt nacheinander live ab.
  - Schnäppchen: Händler (Angebot < Händlerpreis, ab 10c Gewinn) und Markt/Dump (Angebot < üblicher Preis × (1 − DG), üblicher Preis = kleinerer Wert aus 7-Tage- und aktuellem Median, Gewinn beim Wiederverkauf nach 5 %, ab 50s, nur bei mind. 10 Scans in 7 Tagen). Nur bis 5 Min. nach dem Scan (einstellbar). Spalte „Daten“ (Scans / Tage). Grundlage: günstigste 5 Preisstufen je Gegenstand aus dem letzten Scan (neu im Scan: `lv`), live nachgeprüft beim Anklicken.
  - Kaufen: Anklicken öffnet den Gegenstand in Blizzards Kaufen-Ansicht (`SelectBrowseResult`); Knopf „Kaufen“ in Broker: Massenware über `StartCommoditiesPurchase` → Preis vom Spiel → Rückfrage (rot, wenn teurer als die Grenze) → `ConfirmCommoditiesPurchase`; Einzelgegenstand: Rückfrage → `PlaceBid` (günstigstes passendes Angebot). Käufe fürs Buch vermerkt.
  - Neue Einstellungen: Mindestgewinn Händler/Markt, Markt-Datenlage (Scans, Tage), Schnäppchen nur bis X Min. nach dem Scan.
- 0.13.0 von KarloDerBaer im Spiel bestätigt: Einkaufen funktioniert, drei Händler-Schnäppchen gekauft.

## 0.12.1

- 0.12.1 (30.09.2026): Broker-Knöpfe folgen Blizzards Knopf (gesperrt mit Hinweis „zu schnell – kurz warten“, frei sobald das Auktionshaus wieder annimmt; kein Warten auf eine Bestätigung, wenn nichts eingestellt wurde; Wartezeit 20 Sek.). Gesperrte Taschenplätze zählen nicht; der Rest desselben Gegenstands kommt erst nach dem Taschen-Update wieder ins Verkaufsfenster; verschwindet der Gegenstand, wird das Verkaufsfenster geleert.

## 0.12.0

- 0.12.0 (30.09.2026, **Bauabschnitt 6**): Reiter „Meine Auktionen“ (Auctions.lua), mit KarloDerBaer abgestimmt.
  - Liste der eigenen Auktionen (`QueryOwnedAuctions`, `OWNED_AUCTIONS_UPDATED`): Gegenstand mit Symbol, Menge, Mein Preis, Günstigster (anderer Verkäufer), Status, Restzeit. Status: günstigster (grün), gleichauf (gelb, nur live erkennbar), unterboten (orange), verkauft (grau). Sortierung: unterbotene zuerst, dann Restzeit.
  - Günstigster zuerst aus dem letzten Scan; „Live prüfen“ (nur auf Knopfdruck) fragt die Gegenstände nacheinander ab, eigene Angebote zählen nicht.
  - Abbrechen mit Anzeige der Kosten (`GetCancelCost`), „Nächste unterbotene (n)“ bricht je Klick eine ab, „Neu einstellen“ springt zu „Verkaufen“ und wählt den Gegenstand (kommt nach dem Abbruch per Post zurück, sonst Hinweis). Abbrüche fürs Buch vermerkt.
  - Ohne Auktionshaus: letzter Stand des Markts, Abbrechen gesperrt. Abgelaufene Auktionen (nur als Post) vorerst nicht angezeigt, kommen ins Buch.
- Test 0.10–0.12 (KarloDerBaer, 30.09.2026): funktioniert bisher gut. Zwei Fehler gefunden:
  - Nach zu schnellem Einstellen sperrt das Auktionshaus seinen Knopf („Ihr macht das zu schnell“); Brokers Knöpfe blieben danach grau, bis über das Auktionshaus selbst eingestellt wurde (Broker wartete auf eine Bestätigung, die nie kam).
  - Lua-Fehler in Blizzards `ItemSellFrame:UpdateNoneAvailableEntry` (`GetCurrentItemLevel`, ungültiger Platz): Broker legte nach dem Einstellen denselben, gerade verschwindenden Gegenstand wieder ins Verkaufsfenster.

## 0.11.0

- 0.11.0 (30.09.2026): **Reiter „Behalten“** (Keep.lua), mit KarloDerBaer abgestimmt.
  - Optionale Behalten-Menge je Gegenstand (leer = alle). Vorrat = Taschen + Bank (`C_Item.GetItemCount` mit Bank, geht auch bei geschlossener Bank; so macht es auch BagBrother). Zu verkaufen = Vorrat − Menge, höchstens die Menge in den Taschen.
  - Reiter „Behalten“ (hinter „Verkaufen“): Gegenstand mit Symbol, Menge (alle/Zahl), Vorrat (hervorgehoben: größere, hellweiße Schrift – WoW hat keinen Fettdruck), Taschen, Bank, Wert des Vorrats, Seit. Zeile anklicken → unten „Behalten: [Zahl] [Alle] [Wieder verkaufen]“; Rechtsklick = wieder verkaufen. Auch Gegenstände, die gerade nicht da sind.
  - Verkaufen: zeigt nur den Rest, trägt ihn im Auktionshaus als Menge ein; Hinweis „Du wolltest X behalten“, wenn dort mehr steht (Einstellen bleibt möglich). Rechtsklick/Knopf markiert weiter mit „alle“.
  - Tooltip: Zeile „Behalten: alle“ bzw. „Behalten: 20 (1 zu verkaufen)“ in Hellblau direkt unter Zeile 1, auch ohne Umschalt (nur aktueller Charakter).
  - Markierungen aus 0.10 werden zu „alle behalten“.

## 0.10.0

- 0.10.0 (30.09.2026, Wünsche von KarloDerBaer):
  - Gewählter Gegenstand wird ins Verkaufsfenster des Auktionshauses gelegt (`AuctionHouseFrame:SetPostItem`, Rückfall `SetDisplayMode` + `SellFrame:SetItem`), Brokers Werte dort eingetragen: Preis (`PriceInput:SetAmount`), Menge (`QuantityInput:SetQuantity`, Standard alles), Dauer (`Duration:SetDuration`). Nach 0,3 und 1 Sek. nochmal, weil das Auktionshaus nach seiner Suche selbst einen Preis setzt.
  - Eingestellt wird mit den Werten, die im Auktionshaus stehen (Broker klickt dessen Knopf „Auktion erstellen“); ohne Verkaufsfenster Rückfall auf Brokers eigene Werte mit Hinweis. Im Auktionshaus geänderte Dauer wird je Gegenstand gemerkt.
  - Linke Spalte schmal: Symbol, Name, Anzahl, Live-Stand, Vorschlag je Stück mit Stichwort, Erlös (für Menge und Dauer aus dem Auktionshaus), Hinweise; Knöpfe übereinander: „Nicht verkaufen“, „Auktion erstellen“, „Erstellen & weiter“. Eingabefelder entfernt.
  - Rechte Spalte breiter mit Spalte Trend (wie Zeile 1 im Tooltip). Rechtsklick auf eine Zeile = nicht verkaufen.
  - „Nicht verkaufen“ je Charakter (`PeonBrokerCharDB.keep`): verschwindet aus der Liste und aus „Erstellen & weiter“; per Alt+Klick auswählbar und mit „Wieder verkaufen“ freizugeben. Reiter zum Verwalten folgt.

## 0.9.3

- 0.9.3 (30.09.2026): Live-Abfrage über die normale Suche `SendSearchQuery` mit dem Schlüssel des Gegenstands (wie beim Anklicken im Auktionshaus); Nachsehen unter mehreren Schlüsseln (Gegenstand, Stufe 0, Schlüssel aus „neue Ergebnisse“), Protokoll inkl. Browse-Ergebnissen.
- 0.9.3 im Spiel bestätigt (30.09.2026): Live-Abfrage funktioniert für Massenware und Ausrüstung, Antwort nach etwa 0,3 Sek. über `COMMODITY_SEARCH_RESULTS_UPDATED` bzw. `ITEM_SEARCH_RESULTS_UPDATED`.

## 0.9.2

- 0.9.2 (30.09.2026): Live-Abfrage repariert. Debug-Log zeigte: Bei Massenware wurde die Abfrage gar nicht abgeschickt, bei Ausrüstung lagen die Ergebnisse unter einem anderen Schlüssel. Ursache: `SendSellSearchQuery` braucht einen Schlüssel mit Stufe/Zusatz/Haustierart = 0 (`MakeItemKey(itemID)`), Broker nahm den aus `GetItemKeyFromItem` (mit Gegenstandsstufe).
- 0.9.2 hat nicht geholfen: `MakeItemKey(itemID)` füllt in Forever die Stufe selbst aus (Log: 273085/25/0). Massenware wurde weiter nicht abgeschickt; bei Ausrüstung kam „neue Ergebnisse“, aber keine lesbaren Einträge.

## 0.9.1

- 0.9.1: genaueres Debug-Protokoll der Live-Abfrage (itemKey, Bereitschaft, jedes Ereignis, jedes Nachsehen).

## 0.9.0

- 0.9.0 (30.09.2026): **Neues Layout** nach KarloDerBaers Wunsch, angelehnt an das Blizzard-Fenster „Auktionen einstellen“.
  - Fenster im Stil des Auktionshauses (`ButtonFrameTemplate` mit Symbol und Titel, dunkle Innenfelder), Reiter unten wie im Auktionshaus; Rückfall auf den alten Rahmen, falls die Vorlagen fehlen.
  - Verkaufen zweispaltig: links Einstellen (großes Symbol, Name, Anzahl und Live-Stand, Kaufpreis pro Stück, Stichwort zum Vorschlag mit ausführlichem Text beim Überfahren, Menge mit „Max“, Dauer, Einzahlen, Gesamtpreis, Erlös, Hinweise, Knöpfe „Auktion erstellen“ und „Erstellen & weiter“), rechts die Taschen mit kleinem Symbol vor dem Namen.
  - Live-Angebote werden nur noch im Hintergrund für den Vorschlag abgefragt (Anzeige im Blizzard-Fenster); Knopf zum erneuten Abfragen neben dem Live-Stand.
  - Händlerpreis keine eigene Zeile mehr, nur als Hinweis „Lieber beim Händler verkaufen (zahlt …)“; Erlös orange, wenn der Händler mehr zahlt.
- **Ergebnis der Prüfung im Spiel (29.09.2026, Mirel Dorna, Build 70058):**
  - Markt: „Classic Beta PvE / Alliance“ – Realm-Name und Fraktion funktionieren als Markt-Schlüssel. Es gibt keine eigene Regelsatz-Funktion.
  - `UnitName("player")` liefert als zweiten Wert den **Nachnamen** („Mirel“, „Dorna“), nicht den Realm. Charaktere daher immer über Vor- und Nachname kennzeichnen.
  - Modernes Auktionshaus: `AuctionHouseFrame` / Blizzard_AuctionHouseUI, 85 Funktionen in `C_AuctionHouse` (u. a. ReplicateItems, SendSearchQuery, PostItem/PostCommodity, CancelAuction, StartCommoditiesPurchase, PlaceBid, CalculateItemDeposit/CalculateCommodityDeposit, GetOwnedAuctions, GetCancelCost). Keine alten Classic-Funktionen.
  - Komplettscan: 70.388 Angebote in 10 Sekunden. `GetReplicateItemInfo` liefert wie in Retail: Name, Symbol, Menge, Qualität, benutzbar, Stufe, Stufenart, Mindestgebot, Erhöhung, Sofortkaufpreis (für den ganzen Stapel), Gebot, Höchstbieter, …, Verkäufer (leer), …, itemID, hasAllInfo.
  - Gebühren-Test mit Nachtkriecher (Massenware): Einstellgebühr 1c / 4c / 12c für 12 / 24 / 48 Stunden. Händlerpreis kam leer zurück (Gegenstand noch nicht im Zwischenspeicher) – Händlerpreise später mit Nachladen abfragen. Die Formel der Einstellgebühr und der Verkaufsanteil sind noch offen; es gibt keine Funktion für den Anteil, er wird über die Rechnungs-Post ermittelt.
  - Verkaufs- und Posttexte (deDE) sind vorhanden, z. B. „Es wurde ein Käufer für Eure Auktion gefunden: %1$s“, „Auktion erfolgreich: %s“.
  - Ereignisse: alle modernen Auktionshaus-Ereignisse bekannt; `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` mit Typ 21 = Auktionshaus. Alte Ereignisse (`AUCTION_ITEM_LIST_UPDATE`, `NEW_AUCTION_UPDATE`, `AUCTION_OWNED_LIST_UPDATE`) gibt es nicht.
- Offen: Verkaufsanteil (5 % angenommen) und Formel der Einstellgebühr; Stapelpreis im Tooltip hängt davon ab, ob das Spiel die Stapelgröße liefert (`C_Item.GetItemLocation`/`GetStackCount`).
- Rechenmodell `Peon_Broker_Rechenmodell.md` abgestimmt (30.09.2026); Broker 0.6.0 setzt es um.
- Wollstoff-Test im Spiel (30.09.2026): Erlös (Gesamtpreis − 5 %), Händlerwert und Vorschlag stimmen; Min wich ab, weil das günstigste Angebot nach dem Scan gekauft wurde (normal). Einstellgebühr rundete falsch → 0.6.1.
- Rechnung Wollstoff (30.09.2026): Anteil 5 % bestätigt (1s 29c von 25s 85c), erhalten 25s 56c = Broker-Erlös 24s 56c + zurückgezahlte Einzahlung. Auffällig: Einzahlung laut Rechnung 1s 0c zurück, gezahlt 72c – bei weiteren Verkäufen beobachten; 2 und 24 Std. im Abgleich noch ungeprüft.
- Begleitprogramm beschlossen (30.09.2026): Konzept `Peon_Broker_Programm.md` als Entwurf, wird mit KarloDerBaer abgestimmt. Danach neue Reihenfolge der Bauabschnitte (Vorschlag im Konzept, Abschnitt 8).
- Test 0.9.0 (KarloDerBaer, 30.09.2026): Stil passt, Inhalt vorerst passend (wird später weiter angepasst). Live-Abfrage endet mit „keine Antwort“, obwohl das Spiel Ergebnis-Ereignisse meldet (COMMODITY_SEARCH_RESULTS_UPDATED 24×).

## 0.8.1

- 0.8.1 (30.09.2026, nach KarloDerBaers Test): Einzelgegenstände zeigten live den Preis geteilt durch die Anzahl gleicher Angebote (20s bei 6 Angeboten → 3s 33c) – `buyoutAmount` ist schon der Preis je Stück. Live-Abfrage blieb bei „wird geladen“: jetzt zusätzlich Nachsehen nach 0,5/1,5/3 Sek. und Zeitgrenze 6 Sek. („keine Antwort“, Rückfall auf den Scan); Ereignis des Spiels gilt auch, wenn die Warenart falsch vermutet war; Protokoll im Debug-Log (`/broker debug`). „(kommt zurück)“ hinter der Einstellgebühr entfernt.

## 0.8.0

- 0.8.0 (30.09.2026, **Bauabschnitt 5**): Reiter „Verkaufen“ (Sell.lua), Rechenmodell Kapitel 4 (F21–F27).
  - Links die Taschen: verkaufbare Gegenstände (keine gebundenen), gleiche zusammengefasst, Wert wie Zeile 1 im Tooltip, sortiert nach Erlös; „nur lohnende“ (Standard an).
  - Rechts: Live-Angebote (Verkaufs-Suche des Auktionshauses, eigene markiert, Klick übernimmt den Preis), Vorschlag je Stück in Gold/Silber/Kupfer mit Grund, Menge (Standard alles, „Alle“), Laufzeit (Auswahlliste; Massenware ab 20 Angeboten 2 Std.), Gesamtpreis, Einstellgebühr vom Spiel, Erlös nach 5 %, Händlerwert, Hinweise.
  - „Einstellen“ und „Einstellen & weiter“ (nächster lohnender Gegenstand); wartet auf die Bestätigung des Spiels (10 Sek.), Rückfragen bei Preis weit unter dem Vorschlag und wenn das Spiel nachfragt. Nie im Kampf.
  - Alt+Klick auf einen Gegenstand in den Taschen wählt ihn im Reiter aus (über `HandleModifiedItemClick`).
  - Am Auktionshaus öffnet das Fenster mit „Verkaufen“.
- Test 0.8.0 (KarloDerBaer, 30.09.2026): Bedienung und Einstellen funktionieren. Layout gefällt noch nicht: soll übersichtlicher werden und sich am Blizzard-Fenster „Auktionen einstellen“ orientieren.

## 0.7.0

- 0.7.0 (30.09.2026, **Bauabschnitt 4**): Broker-Fenster mit Reiter „Preise“.
  - Fenster (Window.lua): Reiter Verkaufen, Meine Auktionen, Einkaufen, Preise, Buch; bisher nur „Preise“ offen, die anderen gesperrt („folgt“). Bei offenem Auktionshaus rechts angedockt, schließt mit ihm; sonst frei verschiebbar (Position gemerkt). Escape schließt. Fußzeile: Markt und letzter Scan.
  - Öffnen: `/broker`, Minimap-Button (links Fenster, rechts Einstellungen), Knopf „Broker“ links unter dem Auktionshausfenster, Knopf auf der Optionsseite; optional automatisch mit dem Auktionshaus.
  - Reiter „Preise“ (Prices.lua): Suche nach Namensteil (Groß/klein und Umlaute egal), Liste aller Gegenstände des Markts (Name in Qualitätsfarbe, Min, Median, Angebote, gesehen; sortierbar), Maus über Zeile zeigt den Gegenstand im Tooltip mit Broker-Zeilen. Klick zeigt Einzelheiten (AH Min/Median, Angebote, 7 Tage, Vorschlag und Händler je Stück, Warenart, Dumping-Hinweis) und den Verlauf (Tage, ältere als Wochen).
  - Scan merkt Name und Qualität (`nm`, `ql`) je Gegenstand.
- 0.7.0 im Spiel getestet (30.09.2026): Fenster passt, Namen werden gespeichert; Abgleich der Einstellgebühr mit 0.6.2-Formel: 24 gleich, 0 abweichend (Formel bestätigt).
- KarloDerBaer möchte zuerst im Spiel weitermachen (Broker muss ohne Programm funktionieren); das Programm-Konzept bleibt als Entwurf liegen.

## 0.6.2

- 0.6.2 (30.09.2026): **Einstellgebühr wie im Spiel**: Grundgebühr 5 % vom Händlerwert des Stapels, abgerundet, dann × 1/4/12 für 2/8/24 Std. Gefunden über den automatischen Abgleich (`depositCheck`: vorher 32 gleich, 67 abweichend; die neue Formel trifft alle 17 gespeicherten Beispiele). Der Abgleich beginnt bei neuer Formel von vorn.

## 0.6.1

- 0.6.1 (30.09.2026): Einstellgebühr wird jetzt wie im Spiel **abgerundet** (von KarloDerBaer gefunden, Wollstoff: Broker 73c, Spiel 72c). Rechnung in ganzen Prozent, Test mit dem Wollstoff-Beispiel ergänzt.

## 0.6.0

- 0.6.0 (30.09.2026): **Rechenmodell umgesetzt** (`Peon_Broker_Rechenmodell.md`, Formeln F1–F20, Tooltip nach Kapitel 3). Neues Speicherformat (`dataVersion` 2): alte Preisdaten beim ersten Start einmalig gelöscht, Hinweis im Chat.
  - Je Gegenstand: AHmin, AHmedian (Median über alle Stück), AHmenge, AHanz, Zeit, Vorwerte; Tageswerte als Summen und Anzahl aller Scans des Tages (Tag = Mitternacht nach PC-Uhr); 7-Tage-Werte gleitend inkl. heute, Trend gegenüber Vortag.
  - Preisvorschlag: AHmin minus Unterbieten (Massenware/Einzelgegenstand getrennt); bei Dumping (AHmin mehr als DG unter dem Median) Mitte zwischen Grenze und Median. Erlös = VP × Stapel × 0,95 (Einstellgebühr wird nicht abgezogen, sie kommt bei Verkauf zurück). Einstellgebühr = Händlerwert × 5/20/60 % (Laufzeit einstellbar). Empfehlung AH nur bei Erlös > Händlerwert.
  - Tooltip: Z1 bester Wert (Stapel); mit Umschalt Angebote (Anzahl), AH Min/Median je Stück, 7 Tage (n) ab 2 Tagen, Vorschlag je Stück, Einstellgebühr, Händler, Hinweise (Dumping, wenig Angebote < 3, keine Angebote, alte Daten).
  - Entfallen: Abverkauf, gemerkte Einstellgebühren (`deposits`), „~“, „Ø“.
  - Bei geöffnetem Auktionshaus: Warenart der Taschen-Gegenstände vom Spiel gemerkt; Einstellgebühr des Spiels mit der Formel verglichen (`depositCheck`, bis zu 20 Abweichungen als Beispiel).

## 0.5.1

- 0.5.1: Fehler behoben (von KarloDerBaer gefunden, Schwerer Leinenverband): Lag der Markt auf Händlerniveau (20c), wurde der Vorschlag auf den Mindestpreis 26c angehoben; durch Aufrunden kamen 21c Erlös heraus und Zeile 1 zeigte „AH“. Jetzt gilt: Muss der Vorschlag auf den Mindestpreis angehoben werden, zeigt Zeile 1 immer den Händlerpreis.

## 0.5.0

- 0.5.0 (Wünsche von KarloDerBaer nach dem Test):
  - Zeile 1 zeigt nur den besseren Wert: „AH: …“ (Erlös, grün, mit Trend) oder „Händler: …“. Ohne Umschalt nur diese Zeile mit dezentem Hinweis „(Umschalt)“; mit Umschalt die Details. Umschalt während der Tooltip offen ist baut ihn neu auf (`MODIFIER_STATE_CHANGED` → `GameTooltip:RefreshData`).
  - Werte immer für den ganzen Stapel unter der Maus (ohne bekannte Stapelgröße 1 Stück); der Zusatz „Stapel x…“ entfällt.
  - Händlerpreis in den Details nur, wenn Zeile 1 den AH-Wert zeigt; der Hinweis „Lieber beim Händler verkaufen“ entfällt (steckt in Zeile 1).
  - Neue Trend-Symbole (abgestimmt): stark gestiegen dunkelgrün, gestiegen hellgrün, gleich dezent blauer Balken (statt gelbem Punkt, sah wie eine Münze aus), gefallen orange, stark gefallen rot.
  - Fehler behoben: Händlerpreis kam leer zurück, weil es im Forever-Client kein globales `GetItemInfo` mehr gibt – jetzt `ns.GetItemInfo`/`ns.VendorPrice` über `C_Item.GetItemInfo` (auch im Prüfbefehl). Dadurch war der Erlös grün, obwohl der Händler mehr zahlte.

## 0.4.1

- 0.4.1: Fehler behoben – ESC (Spielmenü) meldete ADDON_ACTION_FORBIDDEN „SpellStopCasting()“, weil Options.lua `StaticPopupDialogs = StaticPopupDialogs or {}` neu zugewiesen hatte. Jetzt wird nur ein Eintrag hinzugefügt; der Test prüft das.

## 0.4.0

- 0.4.0: Tooltip neu nach KarloDerBaers Aufbau (Erlös, Angebote mit Abverkauf je Stunde, AH Min/Ø, 7 Tage Min/Ø, Hinweise, Händlerpreis), Münzsymbole, Trend in fünf Stufen mit eigenen Symbolen, Umschalt zeigt alle Werte für den Stapel.
  - Je Gegenstand zusätzlich: Werte des vorherigen Scans (`pm`, `pa`, `pq`, `pt`), günstigste 20 Preisstufen (`l`), geschätzter Abverkauf (`s`, `si`); Gegenstände, die beim neuen Scan fehlen, bekommen 0 Angebote (`gone`) und behalten ihre letzten Preise.
  - Preisvorschlag (`Data.Suggest`): günstigstes Angebot minus Unterbieten; bei mehr als `dumpPct` unter dem 7-Tage-Durchschnitt der Durchschnitt minus Unterbieten; nie unter dem Mindestpreis (Erlös = Händlerpreis). Wird im Reiter „Verkaufen“ wiederverwendet.
  - Einstellgebühren werden beim Öffnen des Auktionshauses und bei Taschenänderungen (während es offen ist) für alle verkaufbaren Taschen-Gegenstände abgefragt und gemerkt.

## 0.3.0

- 0.3.0 (Bauabschnitt 3): Komplettscan, Preisdatenbank je Markt, Preise im Tooltip.
  - Scan: Knopf „Broker-Scan“ unter dem Auktionshausfenster (mit Status: Wartezeit, letzter Scan, Fortschritt) und `/broker scan`. 15-Minuten-Sperre wird selbst mitgezählt. Auswertung in Portionen (1500 Angebote bzw. 300 Gegenstände je Bild); Schließen des Auktionshauses während des Lesens bricht ab.
  - Je Gegenstand: niedrigster Stückpreis, typischer Preis (Durchschnitt der günstigsten 25 % der Menge), Menge, Anzahl Angebote, Zeitpunkt. Ausrüstung mit Zusatz („… des Bären“) getrennt über `itemID:suffixID`. Reine Gebote (ohne Sofortkauf) zählen nicht.
  - Verlauf: ein Tageswert je Tag (späterer Scan gewinnt), nach `dataDays` zu Wochenwerten verdichtet (26 Wochen), dann gelöscht. Verdichten einmal am Tag.
  - Tooltip (nur aktueller Markt): AH-Preis mit Alter, Ø 7 Tage, Händlerpreis, mit Umschalt Stapelpreis, Hinweis „Lieber beim Händler verkaufen“ (AH-Preis nach 5 % Anteil ≤ Händlerpreis). Ohne Scan im Markt ein Hinweis bei verkaufbaren Gegenständen.
  - Minimap-Tooltip zeigt letzten Scan und Anzahl Gegenstände. Der Chat-Hinweis beim Öffnen des Auktionshauses ist entfallen.

## 0.2.0

- 0.2.0 (Bauabschnitt 2): Minimap-Button (Klick öffnet vorerst die Einstellungen, Tooltip mit Markt und letzter Prüfung), Ereignis-Liste auf der Optionsseite als erster Einsatz der neuen Kern-Liste.

## 0.1.0

- Funktionen 0.1.0 (Bauabschnitt 1 – Prüfbefehl, nur lesend): Markt-Schlüssel (Realm-Name / Fraktion), Client-Version, Liste aller `C_AuctionHouse`-Funktionen, alte Classic-Funktionen, Auktionshaus-Fenster, Enums, Texte für Verkaufs-/Postmeldungen, Mitzählen der Auktionshaus- und Post-Ereignisse. Bei geöffnetem Auktionshaus zusätzlich Gebühren-Test (erster verkaufbarer Gegenstand, Einstellgebühr für alle drei Laufzeiten) und Komplettscan-Test (Anzahl, Dauer, drei Beispiel-Einträge).
