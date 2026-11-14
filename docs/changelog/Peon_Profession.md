# Peon_Profession: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

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
