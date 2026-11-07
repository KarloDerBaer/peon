# Peon_Panel: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.3.0

Kurz: Die Leiste zeigt jetzt auch XP, XP pro Stunde, Zeit bis zum Level-Up, Uhr, Zone, Koordinaten und Haltbarkeit. Zum Anhaken gibt es Leistung, Spielzeit, Lautstärke, Freunde, Gilde, Ruf und Reset-Zeiten. Dazu kommen neue Stile im Blizzard-Look und viele Einstellungen zum Aussehen.
Kurz: Die Einstellungen zur Leiste stehen im Kontextmenü jetzt in einem Untermenü, und das Wort vor dem Text kannst du je Eintrag ausblenden.
Kurz: Leiste und Panel lassen sich getrennt einstellen. Die Leiste kann zweizeilig sein, beide lassen sich aufklappbar machen.

- 0.3.0 (07.11.2026, Wunsch KarloDerBaer, Konzept `Peon_Panel_Konzept.md` Abschnitt 13). Braucht Peon 0.15.0 (API 15).
  - **Auf der Leiste vorgesehen:** XP (Stand und Prozent, nur Prozent, fehlende XP), XP pro Stunde, Zeit bis Level-Up, Zone (Zone, Unterzone oder beides, farbig nach Art des Gebiets), Koordinaten, Haltbarkeit (niedrigster Wert, gelb unter 50 %, rot unter 25 %), Uhr (Ortszeit oder Serverzeit).
  - **Zum Anhaken:** Leistung (FPS, Latenz), Spielzeit (Sitzung, seit dem letzten Level-Up), Lautstärke (Mausrad ändert sie, Klick schaltet den Ton), Freunde online, Gilde online, beobachteter Ruf, Reset-Zeiten.
  - **XP pro Stunde** misst über die letzten 60 Minuten, Neustart im Kontextmenü, `/reload` misst weiter, Einloggen beginnt neu. Die XP-Einträge verschwinden auf der Höchststufe, Gilde und Ruf, wenn es nichts zu zeigen gibt.
  - **Klicks:** Karte, Charakterfenster, Ruf, Freunde, Gilde, Zeitverwaltung, nie im Kampf.
  - **Aussehen (neuer Reiter):** Stil Tooltip dunkel (neuer Standard), Tooltip, Metall, Dialog, Holz, Schlicht. Schriftart, Rand der Buchstaben, Farbe von Beschriftung und Wert, Höhe der Leiste, Abstand, Trennstriche, Rahmen um Symbole, Hervorhebung beim Überfahren. Metall, Dialog und Holz werden verkleinert, damit ihre großen Ecken auf die schmale Leiste passen.
  - **Kontextmenü eines Symbols:** Text, Anzeige, Beschriftung, Bereich und Entfernen liegen im Untermenü „Leiste“ (im Panel „Panel“). Oben stehen nur noch die Einträge des Moduls und die Optionen, damit es z. B. beim Angeln übersichtlich bleibt. Wunsch KarloDerBaer.
  - **Beschriftung je Eintrag:** Das Wort vor dem Text (z. B. „Ledger:“) lässt sich je Eintrag ein- und ausschalten, im Untermenü und im Reiter Symbole. Neues Feld `label` in `entries`. Der Haken „Beschriftung vor dem Text (alle Einträge)“ bleibt der Hauptschalter. Wunsch KarloDerBaer.
  - **Leiste und Panel getrennt:** Text, Anzeige und Beschriftung gelten je Anzeige. Neue Felder `boxText`, `boxShow`, `boxLabel` in `entries`, beim ersten Laden aus den Werten der Leiste übernommen. Im Reiter Symbole wählt „Einstellungen für“, ob Leiste oder Panel bearbeitet wird. Wunsch KarloDerBaer.
  - **Panel:** Beschriftung wie auf der Leiste (Hauptschalter `boxLabels`). Text unter dem Symbol oder rechts daneben (`boxLayout`), Zellen bis 150 bzw. 220 Punkte breit. Wunsch KarloDerBaer.
  - **Aufklappbar (Sichtbarkeit `fold`):** Das Panel zeigt zugeklappt nur den ersten Eintrag und klappt bei Maus darüber in der gewählten Richtung auf (`boxFoldDir`: unten, oben, rechts, links), der erste Eintrag bleibt dabei stehen. Die Leiste zeigt zugeklappt nur den mittleren Bereich der oberen Zeile, als Text ohne Symbole, und klappt bei Maus darüber ganz auf. Wunsch KarloDerBaer.
  - **Leiste zweizeilig:** Einstellung „Zeilen der Leiste“ (`barRows`, 1 oder 2). Die Zeile wählt man je Eintrag im Untermenü, im Reiter Symbole oder durch Ziehen (Feld `row`). Wunsch KarloDerBaer.
  - Ein Eintrag aktualisiert sich jetzt allein, ohne alle anderen neu zu lesen, und nur solange er angezeigt wird.
  - **Im Spiel prüfen:** alles aus Abschnitt 13 des Konzepts.

## 0.2.0

Kurz: Die Leiste sitzt jetzt oben in der Mitte, ist breit mit runden Ecken und hat Bereiche für links, Mitte und rechts. Auch das Panel hat runde Ecken. Mit Rechtsklick auf eine freie Stelle wählst du, welche Module angezeigt werden.

- 0.2.0 (07.11.2026, Wunsch KarloDerBaer, Vorbild Titan Panel, Konzept `Peon_Panel_Konzept.md` Abschnitt 12):
  - **Leiste nur noch oben:** mittig am oberen Rand, Breite einstellbar (30 bis 100 %, Standard 60 %), wird breiter, wenn der Inhalt nicht passt. Positionsraster und Abstandsregler entfallen, dafür der Haken „Leiste anzeigen“. Eine Leiste an einer anderen Stelle zieht beim ersten Laden nach oben, eine ausgeschaltete bleibt aus.
  - **Runde Ecken:** Leiste unten, Panel überall, dazu ein feiner Rand. Farbe und Deckkraft von Hintergrund und Rand sowie die Schriftgröße sind einstellbar. Neue Dateien `Skin.lua` und `Media\corner_*.tga`.
  - **Bereiche links, Mitte, rechts:** durch Ziehen, im Kontextmenü und auf der Optionsseite. Anfangs stehen Bags und Peon rechts.
  - **Modulname vor dem Text** auf der Leiste, abschaltbar. **Je Modul wählbar:** Symbol und Text, nur Symbol oder nur Text.
  - **Rechtsklick auf eine freie Stelle:** alle Module zum An- und Abhaken. Die Leiste bleibt auch ohne Einträge sichtbar, damit das Menü erreichbar bleibt.
  - Symbolgröße der Leiste neu 18 statt 22, wer noch den alten Standard hatte, bekommt den neuen. Ebene `LOW` statt `MEDIUM`.
  - **Im Spiel prüfen:** alles aus Abschnitt 12 des Konzepts.

## 0.1.0

Kurz: Neues Addon: Eine Leiste und ein verschiebbares Panel sammeln die Symbole deiner Peon-Addons, auf Wunsch mit kurzen Texten wie Gold oder freien Taschenplätzen. Die Minimap wird dadurch leerer.

- 0.1.0 (07.11.2026, Idee von KarloDerBaer, Konzept `Peon_Panel_Konzept.md`, Bauabschnitte P1 bis P3):
  - **Leiste:** waagerecht, an einer von 8 Stellen oder aus, Abstand vom Rand, Symbolgröße, Hintergrund, Sichtbarkeit.
  - **Panel:** frei verschiebbar, Raster mit Text unter dem Symbol, Spalten automatisch möglichst quadratisch oder fest, Sperre.
  - **Symbole:** Broker, Ledger, Fishing, Bags, Feedback und Peon. Je Modul einstellbar: Minimap, Leiste, Panel und welcher Text. Reihenfolge je Anzeige durch Ziehen, eine Markierung zeigt die Zielstelle.
  - **Kontextmenü:** Rechtsklick mit den Einträgen des Moduls, der Wahl des Textes, Entfernen und den Optionen. Es öffnet sich am Rand der Anzeige, damit es sie nicht überdeckt.
  - **Erster Start:** Alle Module auf der Leiste, ihre Minimap-Buttons aus, einmaliger Hinweis. Wird Panel abgeschaltet, kommen die Buttons zurück.
  - **Im Spiel prüfen:** alles aus Abschnitt 9 des Konzepts. Besonders: Öffnet das Menü an allen Stellen frei, Ziehen gegen Klick, Überdeckung durch Blizzards Leisten, Tooltip-Seite, Hinweisfenster.
