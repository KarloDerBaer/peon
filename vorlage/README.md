# Peon – Vorlage für ein neues Modul

`Peon_Beispiel` ist ein fertiges, getestetes Grundgerüst (Einstellungen mit Standardwerten, Wertebereich und erlaubten Werten, Optionsseite mit Kern-Bausteinen, Debug-Log, `/peon beispiel`). `test_beispiel.lua` ist der passende Test.

## Neues Modul anlegen (Beispiel: Peon_Gatherer)

1. `vorlage\Peon_Beispiel` nach `addons\Peon_Gatherer` kopieren und umbenennen, ebenso die TOC-Datei (`Peon_Gatherer.toc`) und `Beispiel.lua` (`Gatherer.lua`, auch in der TOC).
2. In allen Dateien ersetzen: `Beispiel` → `Gatherer`, `beispiel` → `gatherer`, `PeonBeispielDB` → `PeonGathererDB`.
3. In der TOC Titel, Notes (en/de), IconTexture und Version (0.1.0) anpassen. Pro-Charakter-Werte: `## SavedVariablesPerCharacter: PeonGathererCharDB` und in `NewModule` `charDB` + `charKeys` setzen.
4. `test_beispiel.lua` als `tests\test_gatherer.lua` ablegen, Namen ersetzen, Prüfungen erweitern.
5. Testen (`tests\run_tests.cmd`), dann mit `scripts\junctions.cmd` die Junction im AddOns-Ordner anlegen (WoW geschlossen).
6. **WoW komplett neu starten** (neuer Addon-Ordner, `/reload` reicht nicht).
7. `docs\changelog\Peon_Gatherer.md` anlegen, `docs\projekt\Peon_Stand.md` und bei Bedarf `Peon_Entscheidungen.md` ergänzen.

## Aufbau

| Datei | Inhalt |
|---|---|
| Peon_Beispiel.toc | Interface 16001, Dependencies/Group Peon, Titel in Peon-Grün, Icon, SavedVariables |
| Locales.lua | Texte enUS, darunter deDE; `Peon.NewLocale()` |
| Beispiel.lua | `Peon:NewModule(...)`, `Apply()` bei LOGIN/CHANGED/RESET, Optionsseite bei INIT |
| Options.lua | `mod:NewOptionsPage`, Header, Check, Slider, Dropdown (Auswahlliste), Reset-Knopf, Ausgrauen |

Weitere Bausteine und die ganze Kern-API: siehe `docs\projekt\Peon_Ueberblick.md`, ausführliche Vorlage in `docs\projekt\Peon_Vorlage.md`.
