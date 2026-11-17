# Peon_Profession: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.5.0

Kurz: Neuer Reiter „Codex“: alle Rezepte je Beruf mit Quelle und wer sie kennt. Oben rechts wählst du den Beruf oder „Alle Berufe“.
Kurz: Im Codex unter „Farming“ stehen alle Erze, Kräuter und Fische mit den Gebieten, in denen du sie gefunden hast.
Kurz: Peon merkt sich ab jetzt beim Bergbau und Kräutersammeln jede Sammelstelle. Der Guide nennt dazu deine eigenen Fundorte.

- 0.5.0 (17.11.2026, Wunsch KarloDerBaer, Konzept `docs/konzepte/profession/Peon_Profession_Codex.md`): Codex und Sammelstellen. Daten nur aus dem, was Peon schon hat, und aus eigener Sammlung im Spiel. Anregung war das Addon Mastercraft, übernommen sind nur Ideen.
  - **Sammelstellen (neue Datei `Gather.lua`):** Beim Bergbau und Kräutersammeln merkt Profession Karte, Ort, Name des Vorkommens und die Beute (`nodes`, accountweit). Stellen näher als 25 Meter zählen als dieselbe, höchstens 1500 je Karte. Erkannt wird der Zauber über Nummer oder Namen, gespeichert erst mit der Beute. Ohne Ort (Instanz, geheime Werte) wird nichts gemerkt. `/prof stellen` zählt die Stellen. Eine Anzeige auf Welt- und Minikarte gibt es mit Absicht noch nicht.
  - **Guide:** Bei Sammelschritten steht unter den Gebieten des Guides „Eigene Sammelstellen: Gebiet (Zahl der Stellen)“.
  - **Reiter Codex, Seite Rezepte (neue Datei `Codex.lua`):** Rezepte aus der Route, den erlernten Rezepten aller Charaktere (`recipes`), vom Lehrer (`teach`) und vom Händler (`sold`). Spalten Stufe, Quelle, Erlernt (du, Zahl der Twinks). Oben rechts ein Dropdown mit „Alle Berufe“ und jedem Beruf, für den es Rezepte gibt. Die Suche filtert in der Auswahl. Wählt man links einen Beruf, springt das Dropdown mit, wenn es für ihn Rezepte gibt. Tooltip mit Material und Preis, Lehrer und Händler mit Ort, wer es kennt. Klick setzt einen Wegpunkt zum Lehrer oder Händler.
  - **Lehrer und Händler:** Beim Öffnen des Lehrerfensters merkt Profession die angebotenen Rezepte mit Stufe und Preis, beim Händler die Rezepte zum Kauf mit Preis. Dazu Name und Ort des NPC (`npcs`).
  - **Reiter Codex, Seite Farming:** Erze und Kräuter aus den Routen und den eigenen Stellen, auch Nebenfunde wie Edelsteine, dazu Fische aus Peon_Fishing (ab Fishing 1.7.0). Auswahl Alle, Bergbau, Kräuterkunde, Angeln und Suche. Links Bergbau, Kräuterkunde oder Angeln gewählt, springt die Auswahl mit. Spalten Stufe, Gebiete, Stellen, Preis. Ein Klick zeigt darunter die Gebiete mit Stellen, Anzahl, Anteil beim Angeln und Quelle (eigene Stellen, eigene Fänge, Guide ab Stufe).
  - `/prof vergessen` nimmt auch diesen Charakter aus der gemeinsamen Rezeptliste. Neue Einstellungen `codexMode`, `codexGroup`. Bei „Standardwerte“ bleiben alle gesammelten Daten.
  - Tests: Sammelstelle mit Beute, Zusammenfassen und neue Stelle, Kräuter, fremde Zauber, Zauber über den Namen, ohne Ort, Gebiete und Text für den Guide, `/prof stellen`, gemeinsame Rezeptliste, Lehrer und Händler lesen, Rezepte zusammenstellen, Suche, Wegpunkt, Farming mit Fischen, Gruppen, Gebiete mit Quelle, Reiter im Fenster, vergessen.
  - **Im Spiel prüfen:** Ein paar Erze und Kräuter sammeln, dann `/prof stellen` und im Codex unter Farming die Gebiete ansehen. Einen Lehrer und einen Rezepthändler öffnen: stehen die Rezepte im Codex mit Quelle, und setzt ein Klick den Wegpunkt? Mit `/peon debug profession` zeigt der Chat jede gemerkte Stelle.

## 0.4.1

Kurz: Die Guide-Leiste über dem Berufsfenster schlägt keine Rezepte aus anderen Berufen mehr vor, etwa Gifte beim Kochen.
Kurz: Neu ist ein Ton mit Chatzeile, wenn der Guide ein neues Rezept vorschlägt oder der Höchstwert erreicht ist. Ton und Klang lassen sich in den Optionen einstellen.

- 0.4.1 (16.11.2026, Fehler gemeldet von KarloDerBaer): Beim Kochen zeigte die Leiste „21x Sofort wirkendes Gift (bis 175)“.
  - **Ursache:** Beim Wechsel im Berufsfenster (etwa von Gifte zu Kochkunst) meldet das Spiel schon den neuen Beruf, die Rezeptliste ist aber noch die alte. Die Gifte landeten so unter Kochkunst. Weil das Rezept der Route grün war, schlug der Guide ein „oranges“ Gift als Ersatz vor. Die Sperre „höchstens einmal je Sekunde lesen“ verschluckte zudem das richtige Lesen danach.
  - **Rezept-Prüfung** (`Measure.Belongs`): Kennt das Spiel `GetProfessionInfoByRecipeID` oder `GetTradeSkillLineForRecipe`, wird jedes Rezept gegen den Beruf geprüft (Nummer des Berufs oder Grundberufs, Name). Fremde Rezepte werden nicht gemerkt, früher falsch gemerkte beim nächsten Öffnen entfernt. Ohne diese Schnittstellen bleibt alles wie bisher. `/prof pruefen` zeigt, ob es sie gibt und wie viele Rezepte verworfen wurden.
  - **Lesen erst nach Ruhe:** Auf `TRADE_SKILL_LIST_UPDATE` liest Profession jetzt 0,4 Sekunden nach dem letzten Ereignis statt höchstens einmal je Sekunde.
  - **`/prof vergessen`:** löscht die gemerkten Rezepte dieses Charakters, beim nächsten Öffnen des Berufsfensters werden sie neu gelesen.
  - **Ton bei Meilensteinen (Wunsch KarloDerBaer):** Wechselt das Rezept des Guides (Schritt fertig, Rezept nicht mehr orange oder gelb und ein Ersatz kommt, beim Bergbau Wechsel zwischen Verhütten und Sammeln) oder ist der Höchstwert erreicht, gibt es einen Ton auf dem Kanal „Master“ und eine Chatzeile mit dem nächsten Rezept. Höchstens eine Meldung je Stufe, gemessen ab dem Stand beim Einloggen. Optionen: neuer Abschnitt „Meilensteine“ mit `stepSound` (an), Klang `stepSoundKey` (Bereitschaftscheck, Schlachtzugswarnung, Flüstern, Stufenaufstieg) und Knopf „Probe“.
  - **Behoben:** Der Reiter Verlauf aus 0.4.0 fehlte in den erlaubten Werten von `windowTab` und wurde beim Laden auf Guide zurückgesetzt. `histDays` steht jetzt in den Standardwerten. Bergbau kennt die Namen „Verhütten“ und „Smelting“ für das Verhüttungsfenster.
  - Tests: Gifte unter einem anderen Beruf verworfen und entfernt, Prüfung über Unterberuf und Grundberuf, ohne Schnittstelle nichts verworfen, Lesen nur nach dem letzten Ereignis, `/prof vergessen`, Meilensteine mit Ton, Chatzeile, Ersatz wegen Farbe, Höchstwert, abschaltbar, Probe und über die Stufe des Spiels.
  - **Im Spiel prüfen:** `/prof pruefen` im Berufsfenster: steht bei der Rezept-Prüfung „da“? Zwischen Gifte und Kochkunst wechseln: bleibt die Leiste beim Kochrezept? Falls nicht, einmal `/prof vergessen`. Beim nächsten Rezeptwechsel kommt der Ton.

## 0.4.0

Kurz: Beim Bergbau zeigt der Guide jetzt auch das Verhütten von Erz zu Barren, mit Erz, Anzahl und Kosten.
Kurz: Neuer Reiter „Verlauf“: Wie haben sich die Kosten bis zum Ziel in den letzten Tagen verändert, und welches Material ist teurer oder billiger geworden?

- 0.4.0 (16.11.2026, Wunsch KarloDerBaer): Verhütten beim Bergbau und Reiter Verlauf.
  - **Verhütten:** Neue Liste `ns.Smelt[186]` in `Routes.lua` mit Kupfer-, Zinn-, Bronze-, Silber-, Eisen-, Gold-, Mithril-, Echtsilber- und Thoriumbarren (Lernstufe, Ende gelb, geschätzte Anzahl, Erz je Barren). Werte wie in Classic, für Forever noch nicht gemessen. Stahl und Dunkeleisen fehlen mit Absicht. Die Schritte stehen neben der Sammel-Route (`Guide.Steps`), Plan und Reiter Route ordnen sie nach Stufe ein und teilen sie an fehlenden Rängen.
  - **Jetzt:** Beim Sammeln nennt der Guide, welcher Barren bei dieser Stufe auch Punkte gibt. Ein Klick auf eine Zeile „Verhütten: …“ zeigt das Rezept mit Erz, Vorrat, Preis und Kosten. Bronze rechnet mit selbst verhüttetem Kupfer und Zinn. Die Knöpfe für die Einkaufsliste gibt es jetzt auch beim Bergbau.
  - **Verhüttungsfenster:** Leiste und grüner Pfeil zeigen dort den passenden Barren (`Guide.CraftStepAt`), `/prof messungen` vergleicht auch das Verhütten.
  - **Reiter Verlauf (neue Datei `History.lua`):** Diagramm mit den Kosten für alles Material von der Stufe bis zum Ziel je Tag (7, 14, 30 oder 90 Tage), ohne Vorrat gerechnet. Preis eines Tages: günstigstes Angebot im AH laut Broker (Tageswert, ältere Tage als Wochenwert), höchstens der Händlerpreis, heute der aktuelle Kaufpreis. Darunter je Material: Preis vorher und heute, Änderung in Prozent und Mehrkosten, sortiert nach den Mehrkosten. Mauszeiger über dem Diagramm zeigt Tag und Betrag. Neue Einstellung `histDays` (30).
  - Braucht für den Verlauf Broker mit `History` und `DayOf` (ab 0.27), ohne Broker steht ein Hinweis.
  - Tests: Schritte mit Verhütten, Wahl des Barrens, Plan mit Lehrerzeile, Bronze aus eigenem Kupfer und Zinn, Fenster mit Verhütten, Tagespreise mit Lücken, Wochenwerten und Händlerpreis, Reiter Verlauf.
  - **Im Spiel prüfen:** Bergbau öffnen: stehen die Zeilen „Verhütten“ im Plan, und stimmen die Stufen mit dem Verhüttungsfenster überein (`/prof messungen` nach ein paar Barren)? Reiter Verlauf bei einem Herstellberuf: Linie, Tooltip, Tabelle und die Knöpfe für die Tage.

## 0.3.1

Kurz: Material, das du mit deinem Beruf selbst herstellst (zum Beispiel Wollstoffballen), steht nicht mehr zum Kauf da. Der Guide rechnet stattdessen das Grundmaterial (Wollstoff) und nutzt deinen Vorrat.

- 0.3.1 (15.11.2026, Fehler gemeldet von KarloDerBaer): Bei „Doppelt genähte Wollschultern“ standen Wollstoffballen mit AH-Preis im Material, obwohl die Route sie vorher selbst herstellt.
  - **Zwischenprodukte:** Stellt der Beruf ein Material selbst her (erlerntes Rezept oder Schritt der Route), löst der Guide es in sein Material auf (`Guide.Producer`, `Guide.Resolve`, bis vier Stufen tief). Zuerst zählt der Vorrat aller Charaktere, im Plan auch das, was frühere Schritte herstellen (etwa die Ballen aus 60–70).
  - **Jetzt:** Das Zwischenprodukt steht mit „selbst herstellen“ statt Preis in der Tabelle, sein Grundmaterial darunter mit Preis und Kosten. Reiter Material, Kosten im Plan, Statuszeile und beide Knöpfe für die Einkaufsliste rechnen genauso.
  - Tests: Erkennung, Auflösung mit Vorrat, Plan mit selbst hergestellten Ballen, Tabelle im Jetzt.
  - **Im Spiel prüfen:** Schneiderei, Schritt Wollschultern: steht Wollstoff statt Wollstoffballen auf der Einkaufsliste?

## 0.3.0

Kurz: Bei Erster Hilfe, Kochkunst und Angeln nennt der Guide das Buch für den Rang Experte mit Preis und Händler. Ein Klick markiert den Händler auf der Karte.

- 0.3.0 (14.11.2026, Wunsch KarloDerBaer): Buchhändler für den Rang Experte.
  - **Neue Datei `Books.lua`:** Bücher „Erste Hilfe für Experten“ (16084), „Expertenkochbuch“ (16072) und „Expertenangeln“ (16083) mit Preis, nötiger Stufe und fünf Händlern (Deneb Walker, Balai Lok'Wein, Shandrina, Wulan, Old Man Heming) samt Karte und Koordinaten. Daten aus Profession Leveling Guide 2.7.2 (MIT), dort im Spiel auf dem Forever-Client gesammelt. Der Guide zeigt den Händler der eigenen Fraktion, Old Man Heming für beide.
  - **Hinweis im Jetzt** ab 25 Punkten vor dem Höchstwert 150: Buch, Preis, Händler, Gebiet mit Koordinaten, nötige Stufe. Dazu der Knopf „Auf Karte“.
  - **Plan:** Die Zeile für den nächsten Rang heißt bei diesen Berufen „Bei 150: Experte als Buch (Klick: Karte)“, ein Klick setzt den Wegpunkt. Die Zeile für den nächsten Rang steht jetzt auch, wenn das Ziel genau der Höchstwert ist.
  - **Wegpunkt** mit Blizzards Kartenmarkierung (`C_Map.SetUserWaypoint`, verfolgt über `C_SuperTrack`), Meldung im Chat. Lässt sich die Karte nicht markieren, sagt der Chat das.
  - Tests: Buch je Beruf und Rang, Händler je Fraktion, Hinweis, Wegpunkt, Buchzeile im Plan, Knopf „Auf Karte“.
  - **Im Spiel prüfen:** Kochkunst 131/150: steht Wulan bzw. Shandrina im Jetzt, und setzt „Auf Karte“ einen Wegpunkt am richtigen Ort mit Pfeil am Kompass?

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
