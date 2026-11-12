# Texte für die Releases

Aus diesen Dateien baut `scripts/build_release.js` den Text des Release auf GitHub (`notes.md`): oben eine Tabelle mit allen Addons und dem Peon Manager (Addon/Modul, Version alt, Version neu, Anmerkung), darunter je geändertem Teil eine kurze Liste.

„Version alt“ ist immer der Stand des letzten normalen Release, auch bei einer Vorabversion.

Dieselben Angaben stehen im Manifest (`release = { from, note, items }` je geändertem Teil). Der Peon Manager zeigt sie ab 0.27.0 im Update-Fenster und unter „Was ist neu“. Wer ein Release übersprungen hat, sieht darunter die kurzen Texte (`Kurz:`) der Versionen davor. Die Zeilen `Kurz:` im Changelog bleiben darum Pflicht.

## Aufbau

Eine Datei je Release, Name nach Datum (`2026-11-12.md`). Je geändertem Teil ein Abschnitt mit genau der neuen Version:

```
## Peon_Broker 0.81.1

Anmerkung: Neues Fenster, Aufkauf, Fokus

- Neu: ...
- Geändert: ...
- Behoben: ...
- Entfernt: ...
```

- Name wie im Ordner `addons\` (`Peon`, `Peon_Broker`), für das Programm `Peon Manager`.
- **Anmerkung:** nur wenige Worte zur wichtigsten Änderung. Keine Hinweise auf Personen, Orte oder Wünsche.
- **Punkte:** nur `Neu`, `Geändert`, `Behoben`, `Entfernt`. Zusammengefasst über alle Versionen seit dem letzten normalen Release, für Nutzer geschrieben, je Punkt ein Satz. Die Reihenfolge der Arten ordnet das Skript selbst.
- Unveränderte Teile brauchen keinen Abschnitt (Tabelle: „unverändert“). Neue Addons ohne Abschnitt bekommen die Anmerkung „Neu“.

## Prüfung beim Bau

Fehlt für einen geänderten Teil der Abschnitt, die Anmerkung oder jeder Punkt, bricht der Bau ab. Ebenso bei einer unbekannten Art (zum Beispiel `Bugfix`).

Vorabversion und normales Release desselben Stands nutzen denselben Abschnitt, weil er an der Version hängt, nicht am Namen der Datei. Kommt zwischen Vorabversion und normalem Release eine neue Version dazu, den Abschnitt auf die neue Version ändern und die Punkte ergänzen.
