# Peon_Warhorn: Konzept Gruppensuche mit Filtern

Stand: 17.11.2026, Entwurf von Claude für Schritt 2 bis 4 des Plans in `Peon_Stand.md`, Fragen beantwortet von KarloDerBaer (Abschnitt 10). Gebaut in Warhorn 0.2.0 (alle drei Schritte aus Abschnitt 11 in einem Zug), Abweichungen beim Bau in `Peon_Entscheidungen.md`. Grundlage ist die Prüfung mit Warhorn 0.1.0 (Ergebnis in `Peon_Stand.md` und `Peon_Ueberblick.md`).

## 1. Idee

Blizzards Gruppensuche zeigt alle Einträge einer Kategorie ohne Filter. Warhorn zeigt dieselben Einträge in einer eigenen Liste mit Filtern nach Rolle, Klasse und Stufe, getrennt nach Gruppen und Einzelspielern. Blizzards Fenster bleibt unverändert.

## 2. Was die Prüfung festgelegt hat

- Suchen geht nur nach Klick oder Tastendruck des Spielers. Ein Zeitgeber wird blockiert.
- Bekannte Einträge aktualisiert das Spiel von selbst (neue Mitglieder, Rollen, aufgelöste Einträge).
- Je Eintrag sind lesbar: Mitglieder mit Klasse, Stufe, Rolle und möglichen Rollen, Anführer, freie Plätze je Rolle, Anzahl je Klasse und Rolle. Nichts davon war geheim.
- Ein Eintrag mit einem Mitglied ist ein Einzelspieler (so behandelt ihn Blizzard, Titel und Kommentar waren in der Prüfung bei allen Einträgen leer).
- Blizzards Aktionen in der Liste sind nur Anflüstern und Einladen (Einladen nur bei Einzelspielern und wenn man selbst einladen darf). Eine Anfrage an eine Gruppe gibt es in dieser Gruppensuche nicht.

## 3. Fenster

- **Wie bei Broker über Blizzards Fenster** (KarloDerBaer): Warhorn legt eine eigene Fläche mit `Peon.UI` über Blizzards Suchseite. Sie hängt an `LFGParentFrame`, wandert also mit, wenn Peon_Mover das Fenster verschiebt.
- Blizzards Reiter unten („Gruppen suchen“ und „Eintragen“) bleiben sichtbar und bedienbar. Warhorn liegt nur über der Suchseite. Auf dem Reiter zum Eintragen sieht man Blizzards Fenster wie immer.
- Breite: Blizzards Fenster ist 458 breit, für die Spalten zu schmal. Warhorn beginnt an derselben Stelle links oben und ist breiter (etwa 680), gleiche Höhe ohne die Reiter.
- **Umschalten zu Blizzard** (KarloDerBaer): Knopf „Blizzard“ oben in Warhorn blendet Warhorn aus. Ein kleiner Knopf „Warhorn“ oben an Blizzards Fenster holt Warhorn zurück. Die Wahl bleibt gemerkt. Anders als bei Broker ist kein Neuladen nötig, weil Warhorn nichts in Blizzards Tabellen schreibt (der Knopf an Blizzards Fenster ist ein eigener Rahmen, nur angehängt).
- Öffnen über Blizzards Wege (Taste, Menü) und zusätzlich über `/warhorn` und Peon_Panel. Ob `/warhorn` Blizzards Fenster ohne Taint öffnen kann, wird beim Bau geprüft, sonst zeigt der Befehl einen Hinweis auf Blizzards Taste.
- Zwei Reiter oben in Warhorn mit Zahl der Treffer: **Gruppen** und **Mitspieler**.

```
+------------------------------------------------------------+
| (Horn) Warhorn   [Gruppen 9] [Mitspieler 3]   [Blizzard] [x] |
| Dungeons v   Aktivität: 3 gewählt v            (Suchen) ⟳ |
| Rolle: [T] [H] [D]   Klassen v   Stufe 25 – 40            |
|------------------------------------------------------------|
| Aktivität        Anführer     Stufe   Rollen      Alter    |
| Kloster          Paladin      28–33   T H D D _   2 Min    |
| Höhlen d. Wehkl. Hexenmeister 35–38   _ H D D D   3 Min    |
| ...                                                        |
|------------------------------------------------------------|
| 12 von 37 Einträgen · zuletzt gesucht vor 40 s             |
+------------------------------------------------------------+
   [ Gruppen suchen ] [ Eintragen ]      (Blizzards Reiter)
```

## 4. Auswahl, was gesucht wird

- Kategorie (Dungeons, Raids, …) und Aktivitäten (einzelne Dungeons, mehrere wählbar) als eigene Auswahl in Warhorn. Grund: Warhorn sucht selbst und soll auch ohne Blizzards Fenster gehen.
- Beim ersten Öffnen und wenn sie leer ist, übernimmt Warhorn Blizzards Auswahl. Danach merkt sich Warhorn die eigene Auswahl je Charakter.
- Vorschlag „passend zur Stufe“ wie bei Blizzard (`LFGUtil_GetFilteredActivities`) als Standard.

## 5. Filter

**Reiter Gruppen** (Einträge mit mehr als einem Mitglied):

| Filter | Wirkung | Standard |
|---|---|---|
| Rolle frei | nur Gruppen mit freiem Platz für die gewählten Rollen (`TANK_REMAINING` usw.) | meine Rollen aus Blizzards Rollenwahl |
| Klassen | Klassen wählen, dann „nur mit“ oder „nur ohne“ diese Klassen | aus |
| Ohne meine Klasse | blendet Gruppen aus, in denen meine Klasse schon dabei ist | aus |
| Stufe | Stufe des Anführers oder Spanne der Mitglieder in einem Bereich | aus |
| Größe | Mitglieder von bis | aus |

**Reiter Mitspieler** (Einträge mit einem Mitglied, so behandelt auch Blizzard sie):

| Filter | Wirkung | Standard |
|---|---|---|
| Rolle | nur Spieler, die eine der gewählten Rollen spielen (`lfgRoles`) | die Rollen, die meiner Gruppe fehlen (in einer Gruppe), sonst alle |
| Klassen | nur die gewählten Klassen | alle |
| Stufe | Bereich | aus |

Filter wirken sofort und ohne neue Suche. Die Zahl am Reiter zeigt die Treffer nach Filter. Gemerkt je Charakter.

## 6. Liste

- Spalten **Gruppen:** Aktivität, Anführer (in Klassenfarbe), Stufe (Spanne), Rollen (Symbole für besetzte und freie Plätze), Klassen (kleine Symbole), Alter. Kommentar und Mitglieder im Tooltip.
- Spalten **Mitspieler:** Name (Klassenfarbe), Klasse, Stufe, Rollen, Aktivitäten (Anzahl, Liste im Tooltip), Alter.
- Sortierung per Klick auf den Kopf. Standard: Gruppen nach freiem Platz für meine Rolle, dann Alter. Mitspieler nach Alter.
- Neue Einträge seit der letzten Suche hell hinterlegt. Aufgelöste Einträge grau, bei der nächsten Suche weg.
- Eigene Gruppe oder eigener Eintrag immer oben (wie bei Blizzard).

## 7. Aktualisierung

- Änderungen, die das Spiel von selbst liefert, zeigt die Liste sofort (`LFG_LIST_SEARCH_RESULT_UPDATED`).
- Neue Suche nur durch den Spieler, **nie automatisch** (KarloDerBaer):
  - Knopf „Suchen“ und Knopf zum Neuladen
  - Tastenbelegung „Warhorn: Suchen“
  - Sucht Blizzards eigener Knopf, übernimmt Warhorn das Ergebnis ebenso.
- Die Statuszeile zeigt, wie alt die Suche ist. Ab 60 Sekunden färbt sich der Hinweis gold.
- Lehnt das Spiel ab, weil zu oft gesucht wurde (`LFG_LIST_SEARCH_FAILED`), zeigt die Statuszeile das und der nächste Versuch wartet.
- Nebenwirkung: Blizzards Liste zeigt danach ebenfalls das Ergebnis der Suche von Warhorn. Sie bleibt dabei unverändert bedienbar.

## 8. Aktionen (Schritt 4)

- Rechtsklick auf eine Zeile: Anflüstern, Einladen (nur Einzelspieler und wenn ich einladen darf), Spieler ansehen (`/who`-Ansicht nur wenn es ohne Taint geht).
- Doppelklick: Anflüstern.
- Vorher prüfen, ob `C_PartyInfo.InviteUnit` aus Warhorn ohne Blockade geht (Blizzard ruft es selbst aus seinem Menü auf, kurze Prüfung im Spiel).
- Melden von Einträgen bleibt in Blizzards Fenster.

## 9. Technik

- Neue Dateien: `Search.lua` (Suche, Ergebnisse, Ereignisse), `Filter.lua` (Filter, ohne Fenster, gut zu testen), `Window.lua` (Fläche, Reiter, Liste), `Overlay.lua` (über Blizzards Suchseite legen, Umschalten, `HookScript` auf `LFGParentFrame` und `LFGBrowseFrame` OnShow/OnHide, nur lesen).
- Braucht Peon API 18 (`Peon.UI`), in `scripts/release.json` dann `api: 18`.
- Einstellungen: `PeonWarhornDB` (Warhorn oder Blizzard anzeigen), `PeonWarhornCharDB` (Auswahl, Filter, Reiter).
- Geheime Werte: Jeder Wert wird vorher mit `Peon.IsSecret` geprüft. Geheime Einträge stehen ungefiltert unten mit Hinweis, statt einen Fehler auszulösen.
- Im Kampf: Fenster öffnet nicht neu, Suchen ist gesperrt, die Liste bleibt sichtbar.
- Der Prüfbefehl aus 0.1.0 bleibt als `/peon warhorn pruefen`.
- Tests: `test_warhorn.lua` um Filter, Sortierung, Suchen nur per Knopf und Taste, Fläche über Blizzards Fenster, Umschalten und geheime Werte erweitern.

## 10. Fragen an KarloDerBaer

Beantwortet am 17.11.2026:

1. Fenster: **wie bei Broker über Blizzards Fenster**, mit Knopf zum Umschalten auf Blizzards Original.
2. Auswahl der Dungeons: **eigene in Warhorn**, zu Beginn aus Blizzards Auswahl.
3. Klassenfilter bei Gruppen: **beides**, „nur mit“ und „nur ohne“, dazu „Ohne meine Klasse“.
4. Suchen: **nie automatisch**, nur über Knopf und Taste.

## 11. Reihenfolge

1. Warhorn 0.2.0: `Search.lua` und `Filter.lua` mit Tests, Fläche über Blizzards Suchseite mit Reiter Gruppen, Umschalten zu Blizzard, Knopf und Taste zum Suchen.
2. Warhorn 0.3.0: Reiter Mitspieler, Statuszeile, Merken je Charakter.
3. Warhorn 0.4.0: Aktionen nach kurzer Prüfung von `InviteUnit`.

## 12. Ideen für später (nichts davon ist beschlossen)

- Ton oder Hinweis, wenn nach einer Suche ein neuer Treffer für die eigenen Filter da ist.
- Merkliste für Spieler, mit denen man gut gespielt hat.
- Eigene Gruppe schnell ausschreiben mit gespeicherten Vorlagen.
