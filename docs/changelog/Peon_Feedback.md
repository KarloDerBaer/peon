# Peon_Feedback: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.3.0

- 0.3.0 (06.11.2026, Wunsch KarloDerBaer): **Zurück aus dem Archiv und ausgeliefert**, jetzt als Zusatz zum Peon Manager für Feedback im Spiel.
  - Knopf „An Manager“ lädt neu, damit das Spiel die Rückmeldungen schreibt und der Manager sie abholen kann.
  - Was der Manager eingelesen hat, löscht das Addon beim nächsten Laden (`feedbackClearBefore` in `Data.lua` von Peon_Bridge). Danach wird es im Manager bearbeitet und gesendet.
  - Der Charakter bleibt im Spiel und wird nicht übergeben.
  - **Im Spiel prüfen:** Das Fenster lief in Forever noch nie, also Aussehen und Auswahllisten ansehen (`WowStyle1DropdownTemplate`, sonst greift der Rückfall). Rückmeldung speichern, „An Manager“, Eintrag erscheint im Manager, nach einem weiteren `/reload` ist er im Spiel weg.

## 0.2.0

- 0.2.0 (03.10.2026): Knöpfe unten neu: „Löschen“ links, „Bearbeiten“ in der Mitte, „OK“ rechts. „Bearbeiten“ öffnet ein eigenes Fenster mit allen Angaben des gewählten Eintrags.

## 0.1.0

- 0.1.0 (02.10.2026): Rückmeldungen im Spiel festhalten, mit Modul, Art, Bereich und Priorität, Liste und Minimap-Button.
