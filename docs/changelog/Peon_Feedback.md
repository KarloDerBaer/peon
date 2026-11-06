# Peon_Feedback: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.4.0

Kurz: Mit Peon_Panel öffnest du das Feedback-Fenster von der Leiste aus und siehst die Zahl deiner Rückmeldungen.

- 0.4.0 (07.11.2026): Text für Peon_Panel: Anzahl der Rückmeldungen, die noch nicht an den Manager übergeben sind. Beim Schreiben und Löschen aktualisiert. Der Klick auf das Symbol öffnet das Feedback-Fenster.

## 0.3.1

Kurz: Einträge verschwinden nach „An Manager“ sofort aus der Liste.

- 0.3.1 (06.11.2026, Rückmeldung von KarloDerBaer): Nach „An Manager“ verschwinden die Einträge sofort aus der Liste, statt erst nach dem nächsten Neuladen. Sie bleiben ausgeblendet in der Datei (`handed`), damit der Manager sie lesen kann, gelöscht wird wie bisher über die Marke. Das Fenster nennt die Zahl der übergebenen Einträge. Ohne Daten vom Manager wird nichts ausgeblendet, der Knopf weist darauf hin.
  - **Im Spiel prüfen:** Rückmeldung speichern, „An Manager“, nach dem Neuladen ist die Liste leer und der Hinweis steht im Fenster. Die Rückmeldung erscheint im Manager.

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
