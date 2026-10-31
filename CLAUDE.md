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
- Ideen für neue Funktionen gibt KarloDerBaer einzeln vor. Sie kommen erst nach seiner Zustimmung in `Peon_Stand.md`.
- Nichts löschen ohne KarloDerBaers Zustimmung.

## Code

- Addon-Code nur in `addons/` ändern. Der AddOns-Ordner des Spiels zeigt per Junction auf diese Ordner, Änderungen sind nach `/reload` im Spiel (neue Dateien: WoW neu starten).
- Im Addon-Ordner liegt nur Addon-Code (keine Notizen, Kopien oder Testdateien).
- Neue Module heißen `Peon_<Name>`, hängen von Peon ab und entstehen aus `vorlage/Peon_Beispiel`.
- Die Kern-API wird nur erweitert, nie geändert.

## Vor jedem Commit und nach jeder Arbeit

- Alle Tests laufen lassen (`tests\run_tests.cmd` oder `sh tests/run_tests.sh`), alle müssen OK melden.
- Version in der TOC des geänderten Moduls erhöhen.
- `docs/changelog/<Modul>.md`, `docs/projekt/Peon_Stand.md` und bei Bedarf `docs/projekt/Peon_Entscheidungen.md` aktualisieren.
- Commit-Texte auf Deutsch, kurz, mit Modul und Version vorne, z. B. `Broker 0.33.0: Kanal broker über Peon_Bridge`.
