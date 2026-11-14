# Peon_Profession: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.2.2

Kurz: Neues Symbol mit Hammer und Spitzhacke wie Blizzards Berufe.
Kurz: Die Leiste von Peon Panel zeigt den Beruf, den du zuletzt im Fenster von Peon Berufe gewählt hast, und aktualisiert sich sofort.

- 0.2.2 (14.11.2026, Wünsche KarloDerBaer):
  - **Symbol:** Hammer und Spitzhacke wie Blizzards Reiter Übersicht am Berufsfenster in Forever (Datei-Nummer 8197101, `ns.ICON`), für Minimap-Button, Starter, Fenster und Addon-Liste. Vorher dasselbe Symbol wie Peon_Feedback.
  - **Verfolgter Beruf:** Der Beruf, den das Fenster zeigt, ist der verfolgte (`sel`), auch wenn er ohne Klick gewählt wurde. Die Leiste von Peon_Panel wird bei jedem Wechsel und jedem Punkt neu gezeichnet (`ns.RefreshLauncher`). Vorher blieb der Text bis zum nächsten Laden stehen.
  - Tests: Wechsel im Fenster zeichnet die Leiste neu, Symbol in der TOC.
  - **Im Spiel prüfen:** Symbol in der Addon-Liste (die TOC nutzt die Datei-Nummer), am Minimap-Button und im Panel. Anderen Beruf im Fenster wählen: wechselt die Leiste sofort?

## 0.2.1

Kurz: Der Guide erkennt deine erlernten Rezepte jetzt richtig, dadurch erscheinen der grüne Pfeil, die Goldmünze und der Gewinn in der Rezeptliste.
Kurz: Im Berufsfenster öffnet ein roter Knopf „Peon Profession“ rechts in der Titelleiste das Fenster.

- 0.2.1 (14.11.2026): Rückmeldung von KarloDerBaer zum Test von 0.2.0 im Spiel.
  - **Behoben: keine Rezepte gemerkt.** Nach dem Öffnen des Berufsfensters blieb `known` leer (gesehen in den SavedVariables). Darum fehlten Pfeil, Münze und Gewinn in der Rezeptliste, und der Guide meldete erlernte Rezepte als „noch nicht erlernt“. Zwei Ursachen sind behoben: Ein Rezept zählt jetzt wie bei Broker als erlernt, solange das Spiel nicht ausdrücklich „nicht erlernt“ meldet (vorher nur bei ausdrücklichem „erlernt“). Der offene Beruf wird aus jeder Angabe des Spiels einzeln gesucht, als Rückfall über den Titel des Berufsfensters, die Stufe notfalls aus `GetProfessions`.
  - `/prof pruefen` nennt zusätzlich, was das Spiel zum offenen Beruf meldet, den Titel und wie viele Rezepte gemerkt sind.
  - **Knopf in der Titelleiste** jetzt rot mit Text „Peon Profession“ rechts in der Leiste, links neben dem Schließen-Knopf (Wunsch KarloDerBaer).
  - **Haken im Block** heißt nur noch „Twinks“ und rutscht damit nicht mehr über den Knopf „Auf Einkaufsliste“. Was er tut, steht im Tooltip.
  - Tests: Rezepte ohne Angabe „erlernt“, Beruf über den Titel, Prüfbefehl, Knopf rechts in der Titelleiste.
  - **Im Spiel prüfen:** Pfeil links neben dem Rezept des Guides, Goldmünze vor dem Gewinn des besten Rezepts, Gewinn in der Rezeptliste. Steht im Guide bei Kochkunst jetzt die Farbe statt „noch nicht erlernt“? Falls nicht: `/prof pruefen` im offenen Berufsfenster und den Chat schicken.

## 0.2.0

Kurz: Kosten und Gewinn im Berufsfenster gehören jetzt zu Peon Berufe. Das Rezept des Guides hat in der Rezeptliste einen grünen Pfeil, das beste Rezept eine Goldmünze vor dem Gewinn.
Kurz: Du kannst eine Zielstufe eingeben und siehst alles Material bis dahin, auch für Berufe, die du noch nicht gelernt hast. Neue Reiter zeigen die ganze Route bis 300 und das Material.
Kurz: In der Titelleiste des Berufsfensters öffnet ein Knopf das Fenster von Peon Berufe.

- 0.2.0 (14.11.2026): Wünsche von KarloDerBaer nach dem ersten Test im Spiel, dazu Bauabschnitt S6. Braucht Broker 0.95 für Kosten und Gewinn im Berufsfenster.
  - **Berufsfenster aus Broker (S6, neue Dateien `Craft.lua`, `LocalesCraft.lua`):** Block unter den Reagenzien, Gewinn in der Rezeptliste, Zahnrad-Menü, Knopf „Auf Einkaufsliste“ (Liste „Material“), Box als Rückfall, Prüfbefehl jetzt `/prof pruefen`. Rechnung wie bisher, Preise über `broker:BuyPrice`, `AhPrice`, `ItemValue`, Vorrat aus dem Spiel und Ledger. Einstellungen gleich benannt, beim ersten Start einmal aus `PeonBrokerDB` übernommen (`craftMigrated`), „Twinks mitzählen“ heißt hier `craftTwinks` (aus Brokers `keepAllChars`). Abschnitt auf der Optionsseite rechts.
  - **Markierungen in der Rezeptliste (Wahl KarloDerBaer):** Rezept des Guides mit grünem Pfeil links neben der Zeile im Einzug der Liste (`Media\guide_arrow.tga`, erzeugt mit `scripts/profession_media.js`, Schalter `craftGuideMark`), bestes Rezept mit Goldmünze direkt vor dem Gewinn statt des goldenen Strichs. Blizzards Pfeile für Punkte bleiben frei. `/prof pruefen` misst den Einzug.
  - **Knopf in der Titelleiste** des Berufsfensters rechts neben dem Namen des Berufs, öffnet das Fenster (`titleButton`).
  - **Alle Berufe:** Haken unter der Liste (`showAll`), nicht gelernte Berufe stehen grau mit „–“ und planen ab Stufe 1 mit „Zuerst Lehrling lernen“.
  - **Zielstufe** im Kopf des Fensters (je Charakter und Beruf in `target`, ohne Eingabe der Höchstwert bzw. der nächste Rang, nicht gelernt 75). Plan, Material, Kosten und Einkaufsliste rechnen bis zum Ziel, an jeder fehlenden Ranggrenze steht eine Lehrerzeile, Schritte werden dort geteilt.
  - **Reiter unten:** Guide (wie bisher), Route (alle Schritte 1-300 mit Stand: Farbe, „lernen ab …“, aktueller Schritt grün hinterlegt, Klick zeigt den Schritt im Guide) und Material (alles von der Stufe bis zum Ziel mit Vorrat, Fehlt, Preis, Kosten). Gewählter Reiter in `windowTab`.
  - Tests: Übernahme der Einstellungen, Plan mit Ziel und Lehrerzeilen, Ziel speichern, Reiter, alle Berufe, Titelknopf, Berufsfenster mit Rechnung, Rezeptliste, Pfeil und Münze, Block, Einkaufsliste, Tooltip-Zeile, Prüfbefehl.
  - **Im Spiel prüfen:** Steht der grüne Pfeil links neben dem richtigen Rezept, ohne Blizzards Pfeile zu verdecken? Wird er abgeschnitten, nennt `/prof pruefen` den Einzug. Sitzt die Goldmünze vor dem Gewinn? Sitzt der Knopf neben dem Titel und bleibt er bei langen Namen im Rahmen? Sind die alten Einstellungen aus Broker übernommen? Zeigt „Alle Berufe“ einen nicht gelernten Beruf mit Material bis zum Ziel?

## 0.1.0

Kurz: Neues Modul Berufe: Es zeigt für jeden Beruf, was du jetzt herstellen oder sammeln sollst, wie oft und was es kostet, dazu die weiteren Schritte bis zum Höchstwert.
Kurz: Mit einem Klick kommt das fehlende Material auf eine Einkaufsliste von Broker. Über dem Berufsfenster zeigt eine schmale Leiste das nächste Rezept.

- 0.1.0 (14.11.2026): Erste Fassung, Bauabschnitte S1 bis S5 (Konzept `docs/konzepte/profession/Peon_Profession_Konzept.md`, freigegeben 14.11.2026). Braucht Peon API 18, für Preise und Einkaufsliste Broker 0.94, für den Vorrat der Twinks Ledger.
  - **Routen (S1):** `Routes.lua`, einmal umgewandelt aus Profession Leveling Guide 2.7.2 (MIT-Lizenz, Hinweis im Dateikopf) mit `tools/plg_convert.lua`. Nur Nummern, alle 12 Berufe, 147 Schritte. Ingenieurskunst und Kürschnerei folgen der Classic-Route, weil PLG für Forever keine eigene hat. Schritte ohne festes Rezept (z. B. Alchimie 155 bis 185) zeigen „ein beliebiges oranges Rezept“ mit Vorschlag.
  - **Fenster (S2):** links die Berufe des Charakters, oben Beruf mit Stufe und Fortschritt, „Jetzt“ mit Rezept, Anzahl, Farbe laut Berufsfenster oder „noch nicht erlernt“ mit Lernstufe, Material mit Je, Gesamt, Vorrat, Fehlt, Preis und Kosten, darunter „Weiter bis …“ mit Kosten je Schritt und einer Zeile für den nächsten Rang. Klick auf einen Schritt zeigt ihn oben. Sammelberufe und Angeln zeigen, was man sammelt und die Gebiete der eigenen Fraktion.
  - **Preise und Einkaufsliste (S3):** Kaufpreis über `broker:BuyPrice`, Vorrat aus Taschen, Bank und Ledger (`StockOthers`). Knöpfe „Auf Einkaufsliste: Schritt“ und „bis …“ füllen die Liste „Beruf: <Name>“ über `broker:AddToList`, nur Material, das fehlt, die Wunschmenge ist der ganze Bedarf. Statuszeile mit Kosten bis zum Höchstwert.
  - **Berufsfenster (S4):** Leiste über dem Berufsfenster mit dem nächsten Rezept, „Auswählen“ (`C_TradeSkillUI.OpenRecipe`) und „Guide“. Ersatzrezept, wenn das Rezept des Schritts grün oder grau ist: das günstigste orange, sonst gelbe. Messungen je Rezept (Farbe je Stufe in `colors`, Punkte nach einer Herstellung in `ups`), `/prof messungen` nennt Abweichungen von den Routen.
  - **Rest (S5):** Minimap-Button, Starter für Peon_Panel („Alchimie 87/150“), Optionsseite, Bereiche für Rückmeldungen, Eintrag in `scripts/release.json`.
  - Tests: `test_profession.lua` (Routen gültig, Schrittwahl, Anzahl, Plan mit Lehrerzeile, Lesen des Berufsfensters, Ersatzrezept, Preise und Einkaufsliste mit nachgebautem Broker, Messung der Punkte, Fenster, Leiste, Starter, Befehle).
  - **Im Spiel prüfen:** Erkennt das Fenster alle Berufe mit Stufe (`GetProfessions` in Forever)? Stimmen Rezepte, Anzahl und Kosten für einen Beruf, den du gerade levelst? Erscheint die Leiste über dem Berufsfenster an der richtigen Stelle, ohne etwas zu verdecken, und wählt „Auswählen“ das Rezept aus? Kommt die Liste „Beruf: …“ in Broker an? Zeigen Sammelberufe die richtigen Gebiete? Nach ein paar Herstellungen: Was meldet `/prof messungen`?
