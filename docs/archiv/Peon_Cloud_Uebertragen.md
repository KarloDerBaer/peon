# Peon: Übertragen aus der Cloud (Archiv, bis 31.10.2026)

Ausgelagert am 18.11.2026 aus `docs/projekt/Peon_Ueberblick.md`.

Bis zum Umzug ins Git-Repo hat Claude in der Cloud gearbeitet und Lieferungen auf den PC übertragen. Diese Regeln gelten nur noch zum Verständnis des Archivs (`<Archiv>\eingang\`).

- **Testen vor dem Übertragen:** lua5.1 mit einem kleinen WoW-Stub (nachgebaute API), zuerst an der Arbeitskopie in der Cloud; bei Datenänderungen mit einer Kopie der echten SavedVariables. Nach dem Übertragen die Tests zusätzlich lokal auf den echten Dateien laufen lassen (`run_tests.sh`, Lua liegt in `tools\`).
- **Nach jedem Übertragen die Prüfsumme auf dem PC kontrollieren.** Einmal meldete die Übertragung „geschrieben“, obwohl die alte Datei blieb. Jede Lieferung in einem neuen Staging-Ordner.
- **Entpacken in freigegebene Ordner:** `tar` überschreibt vorhandene Dateien nur mit `--overwrite` (sonst müsste es löschen, und Löschen ist ohne Freigabe gesperrt). Programmordner des Peon Client nicht überschreiben, sondern neu entpacken und tauschen (`mv`).
- **Neue Programmversion klein übertragen:** Ändert sich nur der Programmcode, unterscheiden sich nur `resources\app.asar` und wenige Bytes der exe (Prüfsumme der asar). Dann reicht ein Paket mit app.asar und einer Liste der geänderten Bytes; auf dem PC `Runtime` nach `_neu` kopieren, beides einspielen, Prüfsummen aller Dateien mit dem Bau vergleichen, tauschen (Programm 0.3.0). Eine Datei gleichen Namens erneut zu übertragen kann die alte liefern: neuen Namen nehmen und die Prüfsumme kontrollieren.
- **Dateien über 20 MB** lehnt die Übertragung ab (28 MB scheiterte, 20 MB ging): große Pakete in Stücke zu 15 MB teilen, auf dem PC mit `cat` zusammensetzen und Prüfsummen von Stücken, Ganzem und jeder Datei kontrollieren (Peon Client 0.1.0).
- **Übertragen größerer Lieferungen:** Paket (`.tgz` mit `PRUEFSUMMEN.md5`) nach `eingang\` legen, auf dem PC in einen Zwischenordner entpacken, Prüfsummen prüfen, dann übernehmen und erneut prüfen; vorher kontrollieren, dass die zu ersetzenden Dateien noch dem Ausgangsstand entsprechen. Dateien vom PC in die Cloud holen: `device_stage_files`.
