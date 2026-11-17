# Peon_Fishing: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 1.7.0

Kurz: Deine Fänge erscheinen jetzt auch im Codex von Peon Berufe, mit den Gebieten, in denen du welchen Fisch gefangen hast.

- 1.7.0 (17.11.2026, für Peon_Profession 0.5.0): Neue Schnittstelle `mod:CatchZones()` (nur lesend) in `Catches.lua`. Liefert je Gegenstand die Gebiete mit Fängen (Fänge mit dem Gegenstand, alle Fänge im Gebiet, häufigste Unterzone), Fischschwärme mitgezählt, dazu Name, Symbol und Qualität aus der Fangdatenbank.
  - Tests: Gebiete je Gegenstand mit Unterzone, zweites Gebiet, anderer Fisch.
  - **Im Spiel prüfen:** Codex in Peon Berufe, Farming, Angeln: stehen deine Fische mit Gebiet und Anteil da?

## 1.6.0

Kurz: Mit Peon_Panel liegt das Angeln auf der Leiste, samt Köder-Menü und Anzeige von Angelmodus oder Köder.

- 1.6.0 (07.11.2026): Starter für Peon_Panel neben dem eigenen Minimap-Button: gleiche Färbung des Symbols, gleicher Tooltip, Menü mit Köder und Optionen, Texte Angelmodus (Standard) und Köder. Der eigene Button bleibt, das Menü ist in eine gemeinsame Funktion gezogen.
  - **Im Spiel prüfen:** Menü am Minimap-Button wie bisher, Symbol und Text auf der Leiste wechseln mit dem Angelmodus.

## 1.5.2

Kurz: Neue Angel-Sets nutzen nur noch Haupt- und Nebenhand und gehen beim Tausch von Rüstung nicht mehr kaputt.

- 1.5.2 (05.11.2026, Rückmeldung KarloDerBaer): Ein neu angelegtes Angel-Set nutzt nur Haupt- und Nebenhand, alle anderen Plätze sind ignoriert. So geht es nicht kaputt, wenn man Rüstung tauscht oder verkauft. Eine Meldung erklärt, wie weitere Angelausrüstung ins Set kommt. Vorhandene Sets und das Rückkehr-Set bleiben unverändert. **Im Spiel prüfen:** Set neu anlegen, im Ausrüstungsmanager sind nur Haupt- und Nebenhand aktiv.

## 1.5.1

- 1.5.1 (02.10.2026): meldet Bereiche für Peon_Feedback (Ausrüstung, Steuerung, Köder, Schwimmer-Erkennung, Kampf, Ton, Fänge, Minimap-Button, Optionen); eine Zeile am Ende von Fishing.lua, sonst unverändert.

## 1.5.0

- 1.5.0 (29.09.2026): Angel-Set, Markierung, Warnton und „nach dem Kampf“ als Auswahllisten.

## 1.4.0

- 1.4.0 (29.09.2026): Optionsseite auf Kern-Bausteine umgestellt, neue Überschrift „Schwimmer-Erkennung“, Standardwerte-Knopf.
