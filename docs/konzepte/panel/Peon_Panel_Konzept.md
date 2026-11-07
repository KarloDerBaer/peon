# Peon_Panel: Konzept (abgestimmt)

Stand: 07.11.2026, mit KarloDerBaer abgestimmt, gebaut in Peon_Panel 0.1.0 und Peon 0.14.0, überarbeitet in Peon_Panel 0.2.0 (Abschnitt 12) und 0.3.0 (Abschnitt 13, im Spiel noch nicht geprüft). Anlass ist eine Idee von KarloDerBaer: Module legen ihre Symbole gesammelt ab, damit weniger Minimap-Buttons nötig sind und zusätzliche Informationen Platz haben.

Ab 0.2.0 gilt für die Leiste Abschnitt 12. Wo die Abschnitte davor etwas anderes zu Lage, Breite oder Aussehen der Leiste sagen, beschreiben sie die Fassung 0.1.0.

## 1. Ziel

- **Leiste:** waagerecht, an einer von 8 festen Stellen am Bildschirmrand (ab 0.2.0 nur noch oben, Abschnitt 12).
- **Panel:** ein annähernd quadratisches Fenster mit Symbolen im Raster, frei verschiebbar.
- Frei einstellbar, welche Symbole dort stehen und ob und welchen Text sie zeigen.
- Der Text lässt sich auch direkt im Kontextmenü des Symbols wählen.
- Wer Peon_Panel nicht installiert, merkt nichts. Alle Minimap-Buttons bleiben wie bisher.

**Nicht in diesem Schritt:** senkrechte Leisten (KarloDerBaer), fremde Addons, mehrere Leisten oder mehrere Panels.

## 2. Ausgangslage im Code

- Broker, Ledger und Feedback nutzen `mod:NewMinimapButton` aus dem Kern (`addons\Peon\Minimap.lua`) mit Symbol, Klick und Tooltip.
- Peon_Fishing hat einen eigenen Button mit Rechtsklick-Menü, der sein Symbol je nach Angelmodus färbt. Die Einstellung heißt dort `showMinimap` statt `minimapShow`.
- Bags, Mover, Tooltip, ComboPoints und Bridge haben keinen Button.
- Die Kern-API steht bei 13 und wird nur erweitert.
- Der Minimap-Button macht nichts Geschütztes. Das gilt dann auch für Leiste und Panel, sie dürfen sich im Kampf verändern.

## 3. So sieht es aus

**Leiste**

```
[B] vor 12 Min.   [L] 12,3k g   [F] Aus   [T] 23 frei   [Fb] 4 offen   [P]
```

- Der Text steht rechts neben dem Symbol.
- Der Platz je Eintrag wächst nur und wird erst beim nächsten Laden oder Umstellen wieder kleiner, damit die Nachbarn nicht bei jeder Goldänderung springen.
- Die Leiste wächst von ihrer Ecke oder Kantenmitte aus, sie rutscht also nicht aus dem Bild.

**Panel**

```
+-------------------------------+
|   [B]        [L]        [F]   |
| vor 12 Min. 12,3k g     Aus   |
|                               |
|   [T]        [Fb]       [P]   |
| 23 frei     4 offen           |
+-------------------------------+
```

- Symbole im Raster, der Text steht unter dem Symbol. Alle Zellen sind gleich groß, so bleibt das Raster ruhig.
- Spalten automatisch, damit es möglichst quadratisch wird, oder fest einstellbar.
- Am Hintergrund ziehen verschiebt das Panel, die Position wird gespeichert. Es lässt sich sperren.

**Bei beiden**

- Linksklick tut dasselbe wie am Minimap-Button. Bei Feedback öffnet er das Feedback-Fenster.
- Fährt man mit der Maus darüber, kommt der gewohnte Tooltip des Moduls.
- Symbole lassen sich mit gedrückter linker Maustaste an eine andere Stelle ziehen. Eine Markierung zeigt die Zielstelle, beim Loslassen rücken die übrigen zur Seite. Würden sie schon währenddessen rücken, könnten die Symbole bei unterschiedlich breiten Texten hin- und herspringen. Auch das Ziehen geht im Kampf.
- Die ganze Zelle samt Text ist klickbar.

## 4. Kontextmenü

Der Rechtsklick auf ein Symbol in Leiste oder Panel öffnet immer dieses Menü:

```
Broker
  (Einträge des Moduls, falls es welche hat, zum Beispiel Köder bei Fishing)
Text
  ( ) Kein Text
  (x) Alter des letzten Scans
  ( ) Angebote im letzten Scan
Von der Leiste entfernen
Optionen von Broker
```

- Die Auswahl unter „Text“ entsteht aus dem, was das Modul anbietet. Kommt später eine neue Möglichkeit dazu, steht sie von selbst im Menü und auf der Optionsseite.
- Am Minimap-Button ändert sich nichts: Fishing behält sein Menü, bei den anderen öffnet der Rechtsklick weiter die Optionsseite.

**Nicht verdeckt:** Blizzards Kontextmenü öffnet am Mauszeiger, klappt bei Platzmangel nach oben und wird am Bildschirmrand festgehalten (im Forever-Code nachgelesen, `Blizzard_Menu\Menu.lua`). Aus dem Bild ragt es also nie, kann aber Leiste oder Panel selbst überdecken. Deshalb baut Peon_Panel die Beschreibung mit `MenuUtil.CreateRootMenuDescription` und `Menu.PopulateDescription` und öffnet sie über `Menu.GetManager():OpenMenu(Knopf, Beschreibung, Anker)`, verankert am Rand von Leiste oder Panel:

- Liegt die Mitte in der oberen Bildschirmhälfte, erscheint das Menü darunter, sonst darüber.
- Reicht der Platz nicht, klappt Blizzard es um.
- Fehlt die Funktion, öffnet das Menü wie bisher mit `MenuUtil.CreateContextMenu`.

Bei Platzmangel kann das Menü das Panel dennoch teilweise überdecken, etwa wenn ein großes Panel fast den ganzen Bildschirm füllt.

## 5. Einstellungen (Einstellungen > AddOns > Peon > Panel)

**Leiste:** Position als Knopfraster mit 8 Stellen und „Aus“ in der Mitte, Abstand vom Rand in X und Y, Symbolgröße, Hintergrund, Sichtbarkeit.

**Panel:** anzeigen, Spalten, Symbolgröße, Hintergrund, Sichtbarkeit, sperren, Knopf „Position zurücksetzen“.

**Sichtbarkeit** als Auswahlliste: immer, nur mit der Maus darüber, im Kampf ausblenden. Standard: immer.

**Symbole:** Eine Liste aller Module mit den Spalten Modul, Minimap, Leiste, Panel und Text. Für die gewählte Zeile:

- Haken für Minimap, Leiste und Panel, unabhängig voneinander.
- Auswahlliste „Text“, dieselbe wie im Kontextmenü.

**Woher die Werte kommen:** Ob ein Minimap-Button sichtbar ist, bleibt im jeweiligen Modul gespeichert. So zeigt dessen eigene Optionsseite weiter dasselbe. Alles andere liegt in `PeonPanelDB`, accountweit.

**Beim ersten Start:** Alle Module erscheinen auf der Leiste, das Panel ist aus, und ihre Minimap-Buttons werden automatisch ausgeblendet. Einmalig erscheint ein Hinweisfenster: Die Symbole liegen jetzt auf der Leiste, und für jedes Addon lässt sich der Minimap-Button wieder einschalten, auf der Panel-Seite oder auf der Seite des Addons.

**Später dazukommende Module** behandelt Panel genauso, einmal beim ersten Erscheinen. Was du danach umstellst, bleibt so (Merker `known` je Modul).

**Sicherheit:** Damit nach dem Abschalten von Peon_Panel kein Symbol fehlt, merkt sich der Kern in `PeonDB.panelHid`, welche Buttons Panel ausgeblendet hat. Ist Panel beim nächsten Laden nicht aktiv, schaltet der Kern genau diese Buttons wieder ein und löscht den Merker. Selbst ausgeblendete Buttons bleiben aus.

## 6. Erweiterung der Kern-API (API 14)

Neu ist ein allgemeiner Eintrag für ein Modul, der „Starter“. Vorhandene Funktionen bleiben unverändert.

```lua
local s = mod:NewLauncher({
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
    title = "Bags",                                    -- Standard: Titel des Moduls
    showKey = "minimapShow",                           -- Einstellung des Minimap-Buttons, nil = keiner
    onClick = function(mod, button, owner) end,        -- owner = geklickter Knopf
    onTooltip = function(mod, tooltip) end,
    hint = "Linksklick: ...",
    update = function(mod, iconTexture) end,           -- optional, Symbol färben
    menu = function(mod, root) end,                    -- optional, eigene Einträge im Kontextmenü
    texts = {                                          -- optional, wählbare Texte
        { key = "free", label = L.TEXT_FREE, get = function(mod) return "23 frei" end },
        { key = "used", label = L.TEXT_USED, get = function(mod) return "73/96" end },
    },
    defaultText = "free",                              -- Standard für neue Nutzer, nil = kein Text
})
s:Refresh()                     -- Symbol und Text überall neu zeichnen
Peon.GetLaunchers()             -- Liste aller Starter
Peon.OnLauncherAdded(fn)        -- meldet auch später angelegte Starter, liefert frühere nach
Peon.OnLauncherRefresh(fn)      -- meldet s:Refresh()
Peon.ShortNumber(n), Peon.ShortGold(kupfer)   -- kurze Form für Texte
```

- `mod:NewMinimapButton` legt ab API 14 selbst einen Starter an und reicht `texts`, `defaultText` und `menu` weiter. Für das Symbol brauchen Broker, Ledger und Feedback keine Änderung.
- `onClick` bekommt als neuen dritten Wert den geklickten Knopf. Vorhandene Funktionen stört das nicht.
- Module prüfen wie üblich vorher: `if mod.NewLauncher then ... end`.

## 7. Symbole und Texte

| Modul | Linksklick | Texte zur Auswahl |
|---|---|---|
| Broker | Broker-Fenster | Alter des letzten Scans, Angebote im letzten Scan |
| Ledger | Ledger-Fenster | Gold aller Charaktere, Gold dieses Charakters |
| Fishing | Angelmodus ein und aus | Angelmodus, Köder |
| Bags (neu) | Taschen ein und aus | Freie Plätze, belegte und alle Plätze |
| Feedback | Feedback-Fenster | Anzahl der Rückmeldungen |
| Peon (neu) | Einstellungen von Peon | keine |

Bags und Peon erscheinen nur auf Leiste und Panel und bekommen keinen Minimap-Button. Mover, Tooltip und ComboPoints bekommen vorerst kein Symbol, weil dort nur die Optionsseite zu öffnen wäre.

**Regeln für Texte:**

- **Kurz schreiben statt abschneiden:** Ein abgeschnittener Goldbetrag wäre falsch. Deshalb liefern die Module selbst eine kurze Form, zum Beispiel `12,3k g`. Den genauen Wert zeigt der Tooltip. Passt ein Text dennoch nicht in die Panel-Zelle, wird er mit „…“ gekürzt.
- **Neu berechnet** wird, wenn das Modul `s:Refresh()` aufruft, dazu einmal je Minute für alles, was mit der Zeit altert. Nie in jedem Bild.
- Texte kommen nur aus nicht geheimen Werten und laufen geschützt, damit ein Fehler die Anzeige nicht stört.

## 8. Technik und Risiken

1. **Reihenfolge beim Laden:** Module legen ihre Starter bei INIT oder LOGIN an. Deshalb meldet `Peon.OnLauncherAdded` auch spätere.
2. **Fehler in Modulen:** Klick, Tooltip, Menü und Text laufen über `mod:Call`.
3. **Abgeschaltete Module:** Sie melden keinen Starter und verschwinden. Ihr Platz in der Reihenfolge und ihre Wahl bleiben gespeichert.
4. **Ziehen oder klicken:** Ein kurzer Klick löst kein Verschieben aus. Am Symbol ziehen ordnet um, am Hintergrund ziehen verschiebt das Panel.
5. **Überdeckung:** Unten und rechts liegen Blizzards Aktionsleisten. Beide Anzeigen liegen in der Ebene `MEDIUM`.
6. **Oberfläche ausblenden:** Beide hängen an `UIParent`, Alt+Z blendet sie also mit aus.

**Testen:** Kern-Erweiterung, Reihenfolge, Haken je Modul, Textwahl, Umstellen der Minimap-Werte, spätes Anmelden und Wiederherstellen nach dem Abschalten mit lua5.1 in `tests\`. Klicks, Menüs und Überdeckung nur im Spiel.

## 9. Im Spiel prüfen

- Leiste an allen 8 Stellen, auch bei anderer Oberflächen-Skalierung.
- Panel verschieben, sperren, Position nach `/reload`, Spalten automatisch und fest.
- Kontextmenü an Leiste und Panel: ganz sichtbar, verdeckt die Anzeige nicht, liegt über anderen Fenstern, auch nah am Bildschirmrand.
- Text im Kontextmenü wählen: wirkt sofort, die Optionsseite zeigt dasselbe.
- Symbole ziehen, ein kurzer Klick löst kein Verschieben aus, die Reihenfolge bleibt nach `/reload`.
- Tooltip auf der richtigen Seite, ragt nicht aus dem Bild.
- Feedback: Klick öffnet das Fenster, Anzahl stimmt.
- Fishing: Symbol färbt sich beim Angeln, eigene Menüeinträge wirken.
- Erster Start: Hinweisfenster einmal, Minimap-Buttons weg, einzelne wieder einschaltbar und nach `/reload` an.
- Peon_Panel abschalten: Die Buttons sind nach dem Neuladen wieder da.
- Texte: Stimmen die Werte, werden sie aktuell, bleibt das Spiel flüssig, passt alles bei langen Goldbeträgen?

## 10. Bauabschnitte

- **P1** Kern: `NewLauncher`, `GetLaunchers`, `OnLauncherAdded`, Wiederherstellen der Minimap-Buttons (Peon 0.14.0, API 14), Tests.
- **P2** Neues Modul Peon_Panel aus `vorlage\Peon_Beispiel`: Leiste, Panel, Kontextmenü, Optionsseite, Eintrag in `scripts\release.json` (Peon_Panel 0.1.0).
- **P3** Starter und Texte für Broker, Ledger, Fishing, Bags, Feedback und Peon.

Alles kommt zusammen.

## 11. Entschieden (KarloDerBaer, 06.11.2026)

1. **Symbole und Texte** gleich in der ersten Fassung, je Modul mehrere Texte zur Auswahl, erweiterbar.
2. **Module mit Button, dazu Bags und Peon.** Mover, Tooltip und ComboPoints vorerst nicht.
3. **Waagerechte Leiste** an einer von 8 festen Stellen, senkrechte vorerst nicht.
4. **Zusätzlich ein quadratisches Panel**, frei verschiebbar.
5. **Frei einstellbar**, welche Symbole angezeigt werden und ob und welchen Text sie haben, auch im Kontextmenü.
6. **Minimap-Buttons werden automatisch ausgeblendet**, sobald das Modul angezeigt wird. Beim ersten Start erklärt ein Hinweis, dass sich der Button für jedes Addon wieder einschalten lässt.
7. **Feedback** mit Symbol, der Klick öffnet das Feedback-Fenster.
8. **Leiste und Panel gleichzeitig möglich**, je Modul mit eigenen Haken. Der gewählte Text gilt für beide.
9. **Ziehen ändert nur die Reihenfolge**, Lücken gibt es nicht. Leiste und Panel haben je eine eigene Reihenfolge.

Ergänzt von Claude: Wird Peon_Panel abgeschaltet, stellt der Kern die von Panel ausgeblendeten Buttons wieder her (Abschnitt 5).

## 12. Überarbeitung nach dem Vorbild Titan Panel (abgestimmt 07.11.2026, Peon_Panel 0.2.0)

Vorbild sind Optik und Bedienung von Titan Panel. Es wird kein Code und keine Grafik daraus übernommen.

**Leiste**

```
 ________________________________________________________________________
|                                                                        |
 \_ [L] Ledger: 3g  [B] Broker: vor 15 Std.   [F] Aus      [T] 26 frei  _/
```

- **Nur oben**, mittig und direkt am oberen Rand. Andere Stellen entfallen, weil dort Blizzards Oberfläche verschoben werden müsste (KarloDerBaer). Positionsraster und Abstandsregler fallen weg, dafür gibt es den Haken „Leiste anzeigen“.
- **Nicht über den ganzen Bildschirm**, die Breite ist einstellbar (30 bis 100 %, Standard 60 %). So bleiben Minimap und Buffs frei. Passt der Inhalt nicht, wird die Leiste breiter als eingestellt.
- **Runde untere Ecken**, oben schließt sie mit dem Bildschirmrand ab (KarloDerBaer).
- **Drei Bereiche:** links, Mitte, rechts. Ein Symbol zieht man in den gewünschten Bereich, das linke, mittlere oder rechte Drittel der Leiste entscheidet. Bereich auch im Kontextmenü und auf der Optionsseite wählbar. Anfangs stehen Bags und Peon rechts, alle anderen links.
- **Modulname vor dem Text**, farbig abgesetzt, zum Beispiel „Ledger: 3g“. Abschaltbar, nur auf der Leiste.
- **Rechtsklick auf eine freie Stelle:** Liste aller Module zum An- und Abhaken. Die Leiste bleibt deshalb auch ohne Einträge sichtbar.

**Panel:** gleiches Aussehen, vier runde Ecken. Lage und Raster bleiben wie bisher.

**Beide**

- Dunkler Hintergrund mit feinem Rand, Farbe und Deckkraft einstellbar, dazu die Schriftgröße.
- Je Modul wählbar: Symbol und Text, nur Symbol oder nur Text. Ohne Text bleibt das Symbol immer sichtbar. Im Panel bleibt das Symbol auch bei „nur Text“, weil das Raster davon lebt.
- Ebene `LOW` statt `MEDIUM`, damit Fenster und Vollbildkarte darüber liegen. Bei Titan gab es dazu Meldungen, dass die Leiste die Karte verdeckt.

**Technik:** Das Spiel rundet Farbflächen nicht ab. Der Hintergrund besteht aus Stücken ohne Überlappung (sonst sähe man bei durchscheinendem Hintergrund dunklere Streifen): Rechtecke für Flächen und Kanten, zwei eigene Bilder für die Ecken (`Media\corner_fill.tga`, `Media\corner_line.tga`, weiß und einfärbbar, erzeugt mit `scripts\panel_media.js`). Der Kern ändert sich nicht.

**Alte Einstellungen:** `barPos`, `barX` und `barY` entfallen. Aus `barPos = "none"` wird `barShow = false`. Wer noch die alte Standardgröße 22 hatte, bekommt die neue (18).

**Im Spiel geprüft (KarloDerBaer, 07.11.2026):** Funktion der Leiste passt. Noch offen: Lage über oder unter Blizzards Fenstern und der Karte, Breite nach Ändern der Fenstergröße.

## 13. Allgemeine Einträge und Aussehen (abgestimmt 07.11.2026, Peon_Panel 0.3.0, Peon 0.15.0, Ledger 0.12.0)

**Einträge**

| Eintrag | Anfangs | Bereich | Texte | Klick |
|---|---|---|---|---|
| XP | Leiste | links | Stand und Prozent, nur Prozent, fehlende XP | |
| XP pro Stunde | Leiste | links | Tempo | |
| Zeit bis Level-Up | Leiste | links | Dauer | |
| Zone | Leiste | Mitte | Zone, Unterzone, beides | Karte |
| Koordinaten | Leiste | Mitte | x / y, in Instanzen „-“ | Karte |
| Haltbarkeit | Leiste | rechts | niedrigster Wert | Charakter |
| Uhr | Leiste | rechts | Ortszeit, Serverzeit | Kalender, sonst Zeitverwaltung |
| Leistung | zum Anhaken | rechts | FPS und Latenz, FPS, Latenz | |
| Spielzeit | zum Anhaken | rechts | Sitzung, seit dem letzten Level-Up | |
| Lautstärke | zum Anhaken | rechts | Prozent | Ton an oder aus, Mausrad ändert |
| Freunde | zum Anhaken | rechts | online und gesamt | Freundesliste |
| Gilde | zum Anhaken | rechts | online und gesamt | Gildenfenster |
| Ruf | zum Anhaken | links | Rang und Prozent, Fraktion und Prozent, Punkte | Ruf-Fenster |
| Reset-Zeiten | zum Anhaken | rechts | täglich, wöchentlich | |

Bei Ledger kommt der Text „Gold dieser Sitzung“ dazu. Vom früheren Vorschlag „Zeit auf dieser Stufe“ gibt es nur die Zeit seit dem letzten Level-Up in dieser Sitzung, weil die Gesamtzeit nur über `/played` kommt und das in den Chat schreibt.

**Technik**

- Der Kern erlaubt mit `mod:AddLauncher` mehrere Starter je Modul (API 15), dazu `onWheel` und `available`. Die Einträge stehen in `Info.lua`, `InfoXP.lua`, `InfoPlace.lua`, `InfoSystem.lua` und `InfoSocial.lua`.
- XP pro Stunde zählt je Minute in `xpLog`, über die letzten 60 Minuten, frühestens ab einer Minute Messung. `/reload` misst weiter, Einloggen beginnt neu.
- Ein Takt alle 0,5 Sekunden liest nur Angezeigtes. Ein Eintrag aktualisiert sich allein, neu angeordnet wird nur, wenn er mehr Platz braucht oder auf- oder abtaucht.
- Namen von Freunden und Gilde stehen nur im Tooltip und werden nicht gespeichert.
- Blizzard-Fenster öffnen sich nur außerhalb des Kampfes und nur, wenn es die Funktion gibt.

**Aussehen:** neuer Reiter. Stile aus Blizzards `NineSliceLayouts`: Tooltip dunkel (Standard), Tooltip, Metall, Dialog, Holz, dazu Schlicht (die eigene Fassung aus 0.2.0). Bei der Leiste ragt der Rahmen 40 Punkte oben aus dem Bild, damit nur die unteren Ecken zu sehen sind. Rahmen mit großen Ecken (Metall, Dialog, Holz) werden als Ganzes verkleinert, bis eine Ecke auf der Leiste höchstens 14 und im Panel höchstens 24 Punkte groß ist. Fehlt ein Rahmen, bleibt es bei Schlicht. Dazu Schriftart, Rand der Buchstaben, Farbe von Beschriftung und Wert, Höhe, Abstand, Trennstriche, Rahmen um Symbole, Hervorhebung.

**Im Spiel prüfen (vieles ging nur mit dem Nachbau)**

- Alle 14 Einträge: Stimmen die Werte? Fehlt eine Funktion im Forever-Client, meldet Peon einen Fehler (`/peon fehler`).
- Nicht am Forever-Code nachgelesen: `GetFramerate`, `GetGameTime`, `GetZoneText`, `GetXPExhaustion`, `GetInventoryItemDurability`, `ToggleCalendar`, `ToggleCharacter`, `ToggleGuildFrame`, Felder von `C_Reputation.GetWatchedFactionData`, `Sound_EnableAllSound`.
- Stimmen die Symbole? Sie sind nach Namen aus Retail gewählt, ein fehlendes erscheint leer.
- Getrennte Einstellungen, Panel mit Text rechts, aufklappbare Leiste und Panel in allen vier Richtungen, zweizeilige Leiste und Ziehen in die zweite Zeile.
- Stile: Zeigt jeder einen Rahmen, passen Metall, Dialog und Holz auf die schmale Leiste und das Panel?
- Bleibt das Spiel flüssig, auch mit Koordinaten und Leistung im Takt?
- XP pro Stunde und Zeit bis Level-Up beim Questen, über einen Levelaufstieg und nach `/reload`.
- Lautstärke: Mausrad, Klick. Gilde und Freunde: Stimmen die Zahlen, laden sie nach?
