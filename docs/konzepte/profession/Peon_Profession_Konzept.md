# Peon_Profession: Konzept (freigegeben)

Stand: 14.11.2026, freigegeben von KarloDerBaer am selben Tag (Entscheidungen in Abschnitt 10, Befehl `/prof` bestätigt). Gebaut in Peon_Profession 0.1.0 (S1 bis S5) und Broker 0.94.0, danach 0.2.0 mit S6 und den Wünschen nach dem ersten Test (Abschnitt 11) und Broker 0.95.0.

Anlass: KarloDerBaer möchte einen Berufe-Guide wie das installierte Addon „Profession Leveling Guide“ (PLG), aber einfach, im Peon-Stil und angebunden an Broker (Preise, Einkaufsliste). Zusatzfunktionen wie Teilen mit der Gilde oder Streamer-Modus sind ausdrücklich nicht gewünscht.

**Peon_Profession** soll das Modul für alles werden, was mit Berufen zu tun hat. Zuerst kommt der Guide. Danach zieht Brokers Teil im Berufsfenster (Kosten, Gewinn, Material-Tabelle) hierher um (Abschnitt 8). Preise und Einkaufslisten bleiben bei Broker, Peon_Profession holt sie dort ab.

## 1. Ziel

- Für jeden Beruf des Charakters zeigen: **Was stelle oder sammle ich jetzt, wie oft, was brauche ich dafür, was kostet es.**
- Darunter die restlichen Schritte bis zum Höchstwert mit den Kosten je Schritt und gesamt.
- Mit einem Klick die fehlenden Materialien auf eine Einkaufsliste von Broker.
- Beim Herstellen merkt das Addon selbst, wenn das empfohlene Rezept nicht mehr orange oder gelb ist, und schlägt ein anderes vor.
- Alle Berufe: herstellende Berufe, Erste Hilfe, Kochkunst, Sammelberufe (Bergbau, Kräuterkunde, Kürschnerei) und Angeln.
- Ohne Broker funktioniert der Guide auch, dann ohne Preise und Einkaufsliste.

**Nicht enthalten:** Teilen mit der Gilde, Streamer-Modus, Datennetz zwischen Spielern, eigene Werkbank, Farm-Helfer, Routenplaner, Post an Twinks, Abklingzeiten, Rezeptsammlung, Händler-Scanner, Wegpunkte, Classic/TBC/MoP und andere Sprachen als Deutsch und Englisch.

## 2. Das installierte Addon: woher die Daten kommen

Untersucht: Profession Leveling Guide 2.7.2 von icêheal (120 Dateien, 2,1 MB, davon rund 14.000 Zeilen Code).

| Teil | Datei(en) | Quelle laut Dateikopf | Form |
|---|---|---|---|
| Classic-Routen 1 bis 300 | `Data\Classic\Guides\*` | Wowhead-Leveling-Guides (Classic, deutsch und englisch) | Text: `item = "ca. 59 Schwacher Heiltrank"`, `mats = "1 Friedensblume, 1 Silberblatt"` |
| Forever-Routen | `Data\Forever\Daten_Forever_Guides.lua` | Verzauberkunst von endgametools.com (Client 1.60.1), übrige Berufe von Hand aus eigenen Messungen und dem PLG-Netz, oben ab einer Stufe die Classic-Route | wie oben, dazu lange Hinweistexte, vieles als „vorläufig“ markiert |
| Neue und geänderte Forever-Rezepte | `Data\Forever\Daten_Forever_<Beruf>.lua` (rund 1.000 Rezepte) | Wowhead Forever, Stand Beta 27.09.2026 | **mit Nummern:** Zauber-ID, Stufe, Materialien als itemID und Menge, Quelle |
| Lehrer | `Data\Classic\Lehrer\*` | Wowhead, Icy Veins, wow-professions.com | Text mit Koordinaten |
| Rezepthändler | `Data\Forever\Daten_Forever_Haendler.lua` | im Spiel gesammelt, auch über das PLG-Netz | mit Nummern |
| Rezepte aus Quests und Drops | `Data\Daten_Rezeptquellen.lua` | QuestieDB (Questie-Projekt) | mit Nummern |
| Handelskommission | `Data\Forever\Daten_Forever_Fundorte*.lua` | Wowhead-Guide (Beta) | Text |
| Farben und Netz-Routen | `Data\Forever\Daten_Forever_NetzLive.lua`, `…NetzBeta.lua` | Meldungen von rund 300 PLG-Spielern über einen versteckten Chatkanal | Zauber-ID mit Stufen-Spannen |

**Wie PLG rechnet:** Für die aktuelle Stufe sucht es den passenden Schritt der Route. Ist das Rezept laut Berufsfenster schon grün oder grau, nennt es ein besseres. Preise holt es der Reihe nach aus ForeverForge, Auctionator, TSM oder vom Händler.

## 3. Übernahme der Daten

**Rechtlich:** PLG steht unter der **MIT-Lizenz**. Code und Daten dürfen wir verwenden, ändern und weitergeben, wenn der Lizenzhinweis von icêheal mitkommt. Das gilt für das, was icêheal selbst erstellt hat. Für die Teile aus anderen Quellen gilt:

- **Reine Fakten** (Rezept X ist bis Stufe Y orange, braucht 2 Erdwurzel) sind unproblematisch.
- **Formulierte Texte** aus Wowhead-Guides (Hinweise, Lehrer-Beschreibungen) übernehmen wir nicht, die schreiben wir neu und kurz.
- **QuestieDB** (Rezepte aus Quests und Drops) steht im Questie-Projekt unter GPL. Das übernehmen wir nicht, es ist für einen einfachen Guide auch nicht nötig.
- icêheal wird nicht eigens angeschrieben (KarloDerBaer), der Lizenzhinweis steht in der Datendatei.

**Technisch:** Nicht 1:1. Die Routen bestehen aus deutschen und englischen Texten („1 Friedensblume, 1 Silberblatt“), alles ist doppelt für beide Sprachen gepflegt und Namen müssen zu Nachschlagetabellen passen. Für Forever ist nur ein Teil wirklich gemessen, ab etwa Stufe 125 bis 225 folgt bei den meisten Berufen die Classic-Route, die in Forever an einigen Stellen nicht mehr stimmt (PLG schreibt das selbst in die Hinweise).

**Weg:**

1. **Einmal umwandeln:** Ein Skript in `tools\` liest die Forever-Routen und die Rezepttabellen von PLG 2.7.2 und baut daraus eine kleine Tabelle **nur mit Nummern** (Zauber-ID des Rezepts, Stufen, Materialien als itemID). Namen holt das Addon im Spiel vom Client (`C_Item`, `C_Spell`), damit passt jede Sprache automatisch. Die Tabelle bekommt im Kopf den Hinweis „Grundlage: Profession Leveling Guide 2.7.2 von icêheal (MIT)“ und den Lizenztext. Danach pflegen wir die Routen nur noch selbst, eine neuere PLG-Version wird nicht mehr umgewandelt (KarloDerBaer).
2. **Selbst nachmessen:** Das Spiel sagt für jedes erlernte Rezept live die Farbe (`C_TradeSkillUI.GetRecipeInfo().relativeDifficulty`). Peon_Profession merkt sich je Rezept, bei welcher Stufe es orange, gelb, grün oder grau war, und mit welchem Rezept die Stufe wirklich gestiegen ist (nur lokal, ohne Netz). Damit korrigiert sich der Guide für KarloDerBaers Charaktere sofort selbst.
3. **Messungen ins Release:** Ein Befehl (`/prof messungen`) zeigt, wo Messung und Route auseinanderliegen. Die Werte liest Claude aus den SavedVariables und trägt sie in die Routentabelle ein, die nächste Version bringt sie allen.
4. **Materialien aus dem Spiel:** Für erlernte Rezepte liest das Addon die Materialien aus dem Berufsfenster (`GetRecipeSchematic`, wie Broker es schon tut). Die Tabelle braucht sie nur für Rezepte, die man noch nicht kennt.

Das Ergebnis ist eine Datendatei von geschätzt 30 bis 60 KB statt rund 1,5 MB.

## 4. So sieht es aus

Ein Fenster mit den Bausteinen aus `Peon.UI` (wie Broker und Ledger), Öffnen über `/prof`, Minimap-Button oder Peon_Panel.

```
+-- Peon Berufe -------------------------------------------------------- [x] +
| Berufe            | Alchimie  87 / 150                                       |
|-------------------|----------------------------------------------------------|
| > Alchimie 87/150 | JETZT                                                    |
|   Kräuterk. 112   | [Ic] Elixier der schwachen Seelenstärke   ca. 13x  bis 100|
|   Erste Hilfe 40  |      orange (laut Berufsfenster)                         |
|                   |   Material        je   gesamt  Vorrat  fehlt   Preis     |
|                   |   Erdwurzel        2      26     14     12    1s 20c     |
|                   |   Friedensblume    1      13     30      -       -       |
|                   |   Leere Phiole     1      13      0     13    Händler    |
|                   |                                   Kosten jetzt: 2s 46c   |
|                   |----------------------------------------------------------|
|                   | WEITER BIS 150                                           |
|                   |   100-135  Elixier der Weisheit        ca. 42x   3g 10s  |
|                   |   135-140  Elixier der ger. Verteid.   ca. 5x      45s   |
|                   |   140-150  …                                             |
|                   |                              Gesamt bis 150:  ca. 5g 20s |
|-------------------|----------------------------------------------------------|
| [Auf Einkaufsliste: bis 100 | bis 150]                 Preise: Broker, 12 Min.|
+-----------------------------------------------------------------------------+
```

- **Links** die Berufe des Charakters mit Stufe, ein Klick wählt. Erst- und Nebenberufe aus `GetProfessions`, auch ohne offenes Berufsfenster.
- **Jetzt:** Rezept mit Symbol, geschätzte Anzahl bis zum Ende des Schritts, Farbe laut Spiel (falls das Rezept erlernt ist), sonst „noch nicht erlernt, beim Lehrer ab X“. Materialien mit Bedarf, Vorrat, fehlt und Kaufpreis.
- **Weiter:** die restlichen Schritte bis zum aktuellen Höchstwert, mit Kosten je Schritt. Ein Klick auf einen Schritt zeigt ihn oben wie „Jetzt“.
- **Lehrer:** nur als Textzeile an der richtigen Stelle („Bei 75: Geselle beim Lehrer lernen, ab Stufe 10, z. B. in Orgrimmar oder Sturmwind“). Keine Koordinaten, keine Kartenmarkierung.
- **Unten:** „Auf Einkaufsliste“ für den aktuellen Schritt oder bis zum Höchstwert, rechts Herkunft und Alter der Preise.

### Sammelberufe und Angeln

Statt Rezept und Materialien zeigt „Jetzt“, was man sammelt und in welchen Gebieten (je Fraktion), mit der Stufe, ab der es gelb und grün wird. „Weiter“ zeigt die nächsten Abschnitte. Kosten und Einkaufsliste entfallen. Bei Angeln stehen Gebiete und die Stufe, ab der dort Fische anbeißen. Peon_Fishing bleibt davon unberührt.

### Leiste am Berufsfenster

Eine schmale Zeile oben im Berufsfenster: „Guide: 13x Elixier der schwachen Seelenstärke (bis 100)“ mit einem Knopf, der das Rezept im Fenster auswählt. Abschaltbar in den Optionen (`craftBar`, Standard an). Brokers Block unter den Reagenzien bleibt bis zum Umzug (Abschnitt 8) unberührt.

### Wenn das Rezept nicht mehr passt

Ist das Rezept des Schritts laut Spiel grün oder grau, zeigt „Jetzt“ ein Ersatzrezept: unter den erlernten orangen Rezepten das mit den geringsten Kosten je Herstellung (Preise von Broker), sonst das gelbe mit den geringsten Kosten. Ein kurzer Satz sagt warum („Seelenstärke ist bei dir schon grün“).

## 5. Anbindung an Broker und Ledger

Alles über die vorhandenen Modulschnittstellen, nur lesend, plus zwei kleine Erweiterungen bei Broker. Ohne Broker oder Ledger fallen Preise bzw. Twink-Vorrat einfach weg.

| Was | Woher | Neu nötig |
|---|---|---|
| Kaufpreis je Stück (Händler oder AH, das Günstigere) | Broker `C.BuyPrice` (heute nur intern im Berufsfenster) | **Broker:** `mod:BuyPrice(id)` als Schnittstelle nach außen |
| Erlös im AH (für den Umzug, Abschnitt 8) | Broker `mod:ItemValue(id, n)` | nein |
| Alter der Preise | Broker `mod:MarketInfo(id).t` | nein |
| Vorrat eigener Charakter | Spiel (`C_Item.GetItemCount` mit Bank) | nein |
| Vorrat der Twinks, Kosten laut Ledger | Ledger `mod:StockOthers(id)`, `mod:Cost(id)` | nein |
| Materialien auf die Einkaufsliste | Broker legt heute schon Listen aus dem Berufsfenster und dem Paketvergleich an (`ns.Buy.AddMaterials`, `P.ToList`) | **Broker:** `mod:AddToList(name, { { id, n } … })` als Schnittstelle nach außen. Liste heißt z. B. „Beruf: Alchimie“, wird bei Bedarf angelegt, „Fehlt“ rechnet die Liste wie gewohnt selbst gegen den Vorrat. Geht über Bridge und Manager wie jede andere Liste. |

Die beiden Broker-Funktionen sind Erweiterungen der Modulschnittstelle von Broker, nicht der Kern-API. Der Kern bleibt unverändert.

## 6. Daten im Addon

**Routentabelle** (`Routes.lua`, aus dem Umwandlungsskript, danach von Hand gepflegt, je Beruf, Nummern hier nur als Beispiel):

```lua
ns.Routes[171] = {                         -- Berufs-ID (Alchimie)
    { from = 1,  to = 10,  spell = 1245246, n = 10, alt = { 1245250 } },
    { from = 10, to = 55,  spell = 1245247, n = 45 },
    { from = 60, to = 100, spell = 1249630, n = 40, note = "trainer75" },
    …
}
ns.Gather[186] = {                          -- Sammelberuf (Bergbau)
    { from = 1, to = 65, nodes = { 1731 }, zones = { A = { 1429, 1426 }, H = { 1411, 1412 } } },
    …
}
ns.Recipes[1245246] = { mats = { 2447, 1, 3371, 1 }, learn = 1, src = "t" }   -- nur für noch nicht erlernte Rezepte nötig
```

- `note` verweist auf kurze, selbst geschriebene Hinweise in `Locales.lua` (deutsch und englisch).
- Gebiete als Karten-Nummern, die Namen liefert das Spiel (`C_Map.GetMapInfo`).
- Lehrer: nur die Stufen-Grenzen und Städte als Text.

**SavedVariables:**

- `PeonProfessionDB` (accountweit): Einstellungen (`minimapShow`, `minimapAngle`, `windowPos`, `craftBar`), Messungen `colors[spellID] = { o = {von, bis}, y = …, g = …, x = … }` und `ups[spellID] = { {von, bis}, … }` (womit die Stufe wirklich gestiegen ist).
- `PeonProfessionCharDB` (je Charakter): zuletzt gewählter Beruf.

## 7. Aufbau im Repo

- `addons\Peon_Profession\` aus `vorlage\Peon_Beispiel`: `Locales.lua`, `Profession.lua` (Modul, Schnittstelle), `Routes.lua`, `Guide.lua` (Schritt finden, Anzahl, Ersatzrezept), `Gather.lua` (Sammelberufe, Angeln), `Prices.lua` (Broker, Ledger), `Window.lua`, `CraftBar.lua`, `Measure.lua` (Farben merken), `Options.lua`.
- Befehle: `/prof` (Fenster), `/prof optionen`, `/prof messungen`, `/peon profession`.
- `tools\plg_convert.lua` (einmalige Umwandlung, läuft mit `tools\lua5.1`), die PLG-Dateien kommen nicht ins Repo, nur das Ergebnis.
- Tests in `tests\` für Schrittwahl, Anzahl, Ersatzrezept und Kosten.
- Bereiche für Rückmeldungen: „Guide“, „Sammelberufe“, „Preise und Einkaufsliste“, „Berufsfenster“, „Optionen“.
- Starter für Peon_Panel mit Text „Alchimie 87/150“.

## 8. Umzug von Brokers Teil im Berufsfenster

Erst nach dem Guide (Bauabschnitt S6), wenn der Guide im Spiel geprüft ist. Bis dahin bleibt Brokers Teil, wie er ist.

**Was umzieht** (heute `Craft.lua` in Broker, rund 1.270 Zeilen): Block unter den Reagenzien (Kosten, Ertrag, Gewinn, Tabelle je Material mit Quelle, Hinweis „Material verkaufen bringt mehr“), Gewinn in der Rezeptliste mit Strich am besten Rezept, Zahnrad-Menü, Material auf die Einkaufsliste, Prüfbefehl `/broker pruefen beruf`, gelernte Rezepte je Charakter (`PeonBrokerCharDB.recipes`), Einstellungen `craftList…`, `craftBlock`, `craftSummary`, `craftCol…`, `craftHint`.

**Was bei Broker bleibt:** Preise, Händlerpreise (`Merchant.lua`), Einkaufslisten. Andere Teile von Broker nutzen heute Hilfsfunktionen aus `Craft.lua` (`Pack.lua` braucht Vorrat und Kaufpreis, `Tooltip.lua` zeigt die Herstellkosten, `Merchant.lua` liest Ledger darüber). Diese Hilfen bleiben als kleine eigene Datei bei Broker. Die Zeile Herstellkosten im Tooltip holt Broker dann bei Peon_Profession ab, falls installiert.

**Übernahme der Einstellungen:** Peon_Profession übernimmt beim ersten Start die `craft…`-Werte aus `PeonBrokerDB` und die Rezepte aus `PeonBrokerCharDB` (einmalig, wie bei `oldDB`). Danach entfernt Broker seinen Teil. Wer Peon_Profession nicht installiert, hat dann keinen Block im Berufsfenster mehr. Ein einmaliger Hinweis (`mod:AddNotice`) in Broker sagt das.

**Vorher abstimmen:** Das Entfernen aus Broker passiert erst nach ausdrücklicher Zustimmung von KarloDerBaer zu S6.

## 9. Bauabschnitte

| Abschnitt | Inhalt |
|---|---|
| S1 | Umwandlungsskript, Routentabelle für alle Berufe, Tests |
| S2 | Modul aus der Vorlage, Fenster mit Berufen, „Jetzt“ und „Weiter“ ohne Preise, Sammelberufe und Angeln |
| S3 | Broker: `mod:BuyPrice`, `mod:AddToList`. Peon_Profession: Preise, Kosten, Einkaufsliste, Twink-Vorrat über Ledger |
| S4 | Leiste am Berufsfenster, Farben aus dem Spiel, Ersatzrezept, Messungen und `/prof messungen` |
| S5 | Minimap-Button, Panel-Starter, Optionsseite, Release-Eintrag in `scripts\release.json` |
| S6 | Umzug von Brokers Teil im Berufsfenster (Abschnitt 8), nach Prüfung von S1 bis S5 im Spiel |

Nach S2 lässt sich im Spiel schon prüfen, ob die Routen stimmen.

## 10. Entscheidungen von KarloDerBaer (14.11.2026)

1. **Name:** `Peon_Profession`, damit alles rund um Berufe dort Platz hat, später auch Brokers Teil im Berufsfenster. Preise und Einkaufslisten tauscht es mit Broker aus.
2. **Berufe:** alle, auch Sammelberufe und Angeln.
3. **Leiste am Berufsfenster:** ja, abschaltbar.
4. **Lehrer:** nur als Text, kein Wegpunkt.
5. **icêheal:** nicht eigens anschreiben, Lizenzhinweis in der Datendatei.
6. **Routen pflegen:** einmal aus PLG 2.7.2 umwandeln, danach nur noch eigene Messungen.
7. **Umzug aus Broker:** erst den Guide bauen und prüfen, danach in einem eigenen Abschnitt (S6).
8. **Befehl `/prof`** und **Freigabe** des Konzepts (KarloDerBaer), Bau von S1 bis S5 in einem Zug.

## 11. Erweiterungen nach dem ersten Test (0.2.0, 14.11.2026)

Wünsche von KarloDerBaer nach dem ersten Blick im Spiel, zusammen mit S6 gebaut.

- **Alle Berufe:** Haken „Alle Berufe“ unter der Liste. Nicht gelernte Berufe stehen grau und planen ab Stufe 1, die erste Zeile sagt „Zuerst Lehrling beim Lehrer lernen“.
- **Ganze Route:** neuer Reiter „Route“ mit allen Schritten 1 bis 300, Stand je Rezept (Farbe oder „lernen ab …“), der aktuelle Schritt grün hinterlegt. Ein Klick zeigt den Schritt im Reiter „Guide“.
- **Zielstufe:** Feld „Ziel“ im Kopf, gespeichert je Charakter und Beruf. Ohne Eingabe gilt der Höchstwert, ist er erreicht der nächste Rang, nicht gelernt 75. „Weiter“, Kosten und Einkaufsliste rechnen bis zum Ziel. An jeder fehlenden Ranggrenze steht eine Lehrerzeile, Schritte über die Grenze werden geteilt.
- **Material bis zum Ziel:** neuer Reiter „Material“ mit allem Material von der Stufe bis zum Ziel, Vorrat, Fehlt, Preis und Kosten. Schritte ohne Material-Angabe werden darunter gezählt.
- **Knopf in der Titelleiste** des Berufsfensters rechts neben dem Namen des Berufs, öffnet das Fenster.
- **Markierungen in der Rezeptliste** (Wahl KarloDerBaer aus vier Vorschlägen): grüner Pfeil links neben der Zeile für das Rezept des Guides, Goldmünze direkt vor dem Gewinn für das beste Rezept. Blizzards Pfeile für Punkte bleiben frei.
- **S6 gebaut:** Abschnitt 8 umgesetzt. Die Box neben dem Fenster bleibt als Rückfall erhalten.
