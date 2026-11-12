# Peon: Arbeitsregeln für Claude Code

Peon ist eine Addon-Sammlung von KarloDerBaer für WoW Forever, dazu das Windows-Programm Peon Manager. Dieses Repo ist die maßgebliche Quelle für Code und Doku.

## Zu Beginn jeder Sitzung lesen

- `docs/projekt/Peon_Ueberblick.md`: Wissen zu WoW Forever und zur Kern-API
- `docs/projekt/Peon_Stand.md`: Stand je Modul und offene Punkte
- `docs/projekt/Peon_Entscheidungen.md`: Entscheidungsprotokoll

## Sprache und Texte

- Antworten und alle Texte auf Deutsch, verständlich und ohne unnötigen Fachjargon.
- In allen Texten möglichst keine Gedankenstriche und Semikolons.

## Abstimmung mit KarloDerBaer

- Vor größeren Entscheidungen kurz mit KarloDerBaer abstimmen.
- Ideen für neue Funktionen gibt KarloDerBaer einzeln vor. Sie kommen erst nach Zustimmung von KarloDerBaer in `Peon_Stand.md`.
- Nichts löschen ohne Zustimmung von KarloDerBaer.

## Öffentliches Repo: keine privaten Daten

- Das Repo ist öffentlich. Wenn es um den Besitzer geht, steht dort nur **KarloDerBaer**. Keine echten Namen, Mailadressen, Konto- oder Charakternamen.
- Keine Pfade des eigenen Rechners. In Doku und Code stehen Platzhalter: `<WoW-Ordner>`, `<Programmordner>`, `<alter Programmordner>`, `<Repo>`, `<Archiv>`, `<WoW-Beta-Ordner>`.
- Die echten Pfade stehen nur in `CLAUDE.local.md` (wird von Claude Code automatisch gelesen, liegt nicht im Repo). Das Junction-Skript liest den AddOns-Ordner aus `scripts\local.json` (ebenfalls nicht im Repo).
- Vor jedem Commit neue Texte darauf prüfen.

## Code

- Addon-Code nur in `addons/` ändern. Der AddOns-Ordner des Spiels steht auf einer von zwei Arten, `scripts\junctions.cmd` zeigt und wechselt sie: **Manager** (echte Ordner, Normalzustand, Änderungen kommen erst über ein Release im Kanal Test ins Spiel) oder **Entwicklung** (Junction auf diese Ordner, Änderungen sind nach `/reload` im Spiel, auch neue Dateien und neue Addons). Umschalten geht auch bei laufendem WoW, danach `/reload`.
- Releases zuerst als Vorabversion (`vJJJJ.MM.TT-test`), nach der Prüfung durch KarloDerBaer derselbe Stand als normales Release. Veröffentlicht wird nur nach Rücksprache.
- Vor jedem Release `docs/releases/<Datum>.md` schreiben: je geändertem Teil eine kurze Anmerkung und Punkte `Neu`, `Geändert`, `Behoben`, `Entfernt`, zusammengefasst seit dem letzten normalen Release, ohne Personen, Orte oder Wünsche. Regeln in `docs/releases/README.md`. Der Bau bricht ohne sie ab. KarloDerBaer liest den Text vor dem Release gegen.
- Im Addon-Ordner liegt nur Addon-Code (keine Notizen, Kopien oder Testdateien).
- Neue Module heißen `Peon_<Name>`, hängen von Peon ab und entstehen aus `vorlage/Peon_Beispiel`.
- Die Kern-API wird nur erweitert, nie geändert.

## Vor jedem Commit und nach jeder Arbeit

- Alle Tests laufen lassen (`tests\run_tests.cmd` oder `sh tests/run_tests.sh`), alle müssen OK melden.
- Version in der TOC des geänderten Moduls erhöhen.
- Im Changelog beginnt jede neue Version mit mindestens einer Zeile `Kurz: ...` in einfacher Sprache für Nutzer (Update-Fenster und „Was ist neu“ im Manager). Der Bau des Release bricht ohne sie ab.
- `docs/changelog/<Modul>.md`, `docs/projekt/Peon_Stand.md` und bei Bedarf `docs/projekt/Peon_Entscheidungen.md` aktualisieren.
- Commit-Texte auf Deutsch, kurz, mit Modul und Version vorne, z. B. `Broker 0.33.0: Kanal broker über Peon_Bridge`.
