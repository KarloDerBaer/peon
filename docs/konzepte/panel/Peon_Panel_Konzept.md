# Peon_Panel: Konzept (abgestimmt)

Stand: 07.11.2026, mit KarloDerBaer abgestimmt, gebaut in Peon_Panel 0.1.0 und Peon 0.14.0, im Spiel noch nicht geprüft. Anlass ist eine Idee von KarloDerBaer: Module legen ihre Symbole gesammelt ab, damit weniger Minimap-Buttons nötig sind und zusätzliche Informationen Platz haben.

## 1. Ziel

- **Leiste:** waagerecht, an einer von 8 festen Stellen am Bildschirmrand.
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
