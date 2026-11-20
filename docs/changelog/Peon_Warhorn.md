# Peon_Warhorn: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`.

## 0.5.3

Kurz: Beim Wechsel der Kategorie, zum Beispiel auf Quest & Zonen, kommt keine Fehlermeldung „blockiert“ mehr.
Kurz: Lässt das Spiel eine Suche einmal nicht zu, steht in der Statuszeile ein Hinweis, statt dass „Suche läuft“ stehen bleibt.

- 0.5.3 (20.11.2026, Fehler gemeldet von KarloDerBaer): Beim Wechsel auf Quest & Zonen in der Auswahl der Kategorie meldete das Spiel `ADDON_ACTION_BLOCKED` für Warhorn. Der Knopf Suchen ging.
  - **Ursache (vermutlich):** Bis 0.5.2 baute Warhorn beim Wechsel zuerst die Anzeige samt Menü der Auswahlliste neu auf und suchte erst danach. Zu diesem Zeitpunkt wertete das Spiel die Suche nicht mehr als Klick des Spielers.
  - **Lösung:** Beim Wechsel der Kategorie sucht Warhorn jetzt zuerst und baut die Anzeige erst danach neu auf (`Window.ChangeCategory`).
  - **Blockierte Suche:** Blockiert das Spiel eine Suche von Warhorn doch einmal, bleibt „Suche läuft“ nicht stehen. Die Statuszeile zeigt „Das Spiel hat die Suche hier nicht erlaubt, bitte auf Suchen klicken“ (`Search.lua`, Ereignis `ADDON_ACTION_BLOCKED`).

## 0.5.2

Kurz: Beim schnellen Anflüstern wählst du die gesuchte Rolle direkt im Menü. Angegebene Rollen des Spielers sind wählbar, die anderen grau.

- 0.5.2 (18.11.2026, Wunsch KarloDerBaer):
  - **Rolle im Untermenü:** Im Rechtsklick-Menü unter „Schnell anflüstern“ bekommt jede Vorlage mit `{suchrolle}` beim Anflüstern von Spielern eine weitere Ebene mit Tank, Heiler und DD (eigene Wörter aus den Platzhaltern). Ein Klick sendet sofort mit dieser Rolle. Hat der Spieler Rollen angegeben, sind nur diese wählbar, die anderen grau. Ohne Angabe (auch in der Wer-Liste) sind alle wählbar. Vorlagen ohne `{suchrolle}` und Anfragen an Gruppen bleiben wie bisher.
  - **Im Spiel prüfen:** Mitspieler mit einer, mit mehreren und ohne Rolle, dazu die Wer-Liste.

## 0.5.1

Kurz: Mehrere Dungeons stehen beim Anflüstern jetzt mit Namen in der Nachricht statt „2 Aktivitäten“.
Kurz: Neuer Platzhalter {suchrolle} für die Rolle, die du suchst. Hat der Spieler genau eine Rolle angegeben, steht sie von selbst da, sonst wählst du sie im Flüsterfenster.
Kurz: Für Schaden steht beim Platzhalter {rolle} jetzt von selbst DD.

- 0.5.1 (17.11.2026, nach dem Test von 0.5.0 durch KarloDerBaer):
  - **{aktivitaet} als Aufzählung:** Bei mehreren Aktivitäten setzt Warhorn die Namen ein („Kloster, Uldaman und Geschmolzener Kern“), ab fünf gekürzt („… und 2 weitere“). Bisher stand dort „2 Aktivitäten“ (`Search.ActivityList`, auch für die Wer-Liste über die Aktivitäten beim Eintragen).
  - **Neuer Platzhalter {suchrolle}:** die gesuchte Rolle des anderen Spielers, `{rolle}` bleibt die eigene. Hat ein Mitspieler genau eine Rolle angegeben, setzt Warhorn sie ein. Bei keiner oder mehreren Rollen (und in der Wer-Liste) steht oben rechts im Flüsterfenster eine Auswahl „Rolle“, bis dahin ist Senden gesperrt. Schnell anflüstern öffnet in diesem Fall das Fenster, statt zu senden. Die Standardvorlage für Spieler nutzt jetzt `{suchrolle}` (nur bei neuen Vorlagen, vorhandene bleiben).
  - **DD als Vorgabe:** Ohne eigenes Wort setzt `{rolle}` und `{suchrolle}` bei Schaden „DD“ ein (englisch „DPS“). Die Beschriftungen in den Listen bleiben „Schaden“.
  - **Im Spiel prüfen:** Anfrage an eine Gruppe mit mehreren Dungeons, Mitspieler mit einer und mit mehreren Rollen anflüstern (Fenster und schnell), eigene Vorlage mit `{suchrolle}`.

## 0.5.0

Kurz: Platzhalter lassen sich jetzt anpassen, zum Beispiel DD statt Schaden, und du kannst eigene anlegen.
Kurz: Schnell anflüstern schickt eine Vorlage sofort ab, über das Rechtsklick-Menü oder mit Shift und Doppelklick.
Kurz: Spieler und Gruppen, die du schon angeflüstert oder eingeladen hast, bekommen ein kleines Symbol.

- 0.5.0 (17.11.2026, Wunsch KarloDerBaer, Einzelheiten mit ihm abgestimmt):
  - **Platzhalter bearbeiten** (`Placeholders.lua`, neu): Knopf „Platzhalter“ auf der Seite Einstellungen öffnet ein kleines Fenster. Dort je Rolle ein eigenes Wort für `{rolle}` (leer = Wort des Spiels) und eigene Platzhalter mit Name und Text (anlegen, ändern, löschen). Namen nur aus Buchstaben a bis z und Ziffern, nicht wie ein fester Platzhalter. Im Text eigener Platzhalter gehen die festen. Gespeichert in `whisper.roleWords` und `whisper.vars`.
  - **Platzhalter einfügen:** Im Flüsterfenster ein Menü „Platzhalter“, das den gewählten Platzhalter an der Schreibmarke einsetzt.
  - **Schnell anflüstern:** Im Rechtsklick-Menü der Listen (Gruppen, Mitspieler, Wer-Liste) ein Untermenü „Schnell anflüstern“ mit allen Vorlagen, ein Klick schickt sofort ab. Shift und Doppelklick schickt die Standardvorlage (für Gruppen oder für Spieler) sofort ab. Ohne Standardvorlage öffnet sich das Fenster wie bisher.
  - **Anfragen merken** (`Contacts.lua`, neu): Jedes Flüstern an einen Spieler, auch aus dem normalen Chat, und jede Einladung aus Warhorn wird je Charakter gemerkt (`contacts`). In den Listen steht dann ein Sprechblasen-Symbol vor dem Namen, im Tooltip „Angeflüstert vor …“ und „Eingeladen vor …“. Gruppen zählen über ihren Anführer. Dauer in den Einstellungen unter „Anfragen merken“: 30 Minuten bis 1 Tag, Vorgabe 2 Stunden (`contactKeep`).
  - **Im Spiel prüfen:** Platzhalter-Fenster (Rollenwort DD, eigener Platzhalter in einer Vorlage), Menü „Platzhalter“ im Flüsterfenster, Untermenü „Schnell anflüstern“, Shift und Doppelklick, Symbol und Tooltip nach dem Anflüstern, auch nach `/reload`.

## 0.4.0

Kurz: Klickt man im Addon ForeverDungeonJournal auf das Auge eines Dungeons, stellt Warhorn seine Suche gleich auf diesen Dungeon und zeigt die Seite Suchen.

- 0.4.0 (17.11.2026, Wunsch KarloDerBaer):
  - **Dungeon aus dem Journal übernehmen** (`Journal.lua`, neu): Warhorn hängt sich an die Suchfunktion des Journals (`SearchDungeonDirect`), nicht an Blizzards Fenster. Nach der Suche des Journals liest Warhorn die gesuchte Aktivität aus dessen Daten (`ForeverDungeonJournalDB.lfgClick`) und stellt Kategorie und Auswahl auf genau diesen Dungeon. Die Auswahl ersetzt die gespeicherte, so abgestimmt mit KarloDerBaer.
  - **Seite Suchen:** Warhorn springt auf die Seite Suchen. Der Hinweis „Zum Gruppenbrowser wechseln“ des Journals erscheint dann nicht mehr.
  - **Keine zweite Suche:** Warhorn sucht nicht selbst, die Ergebnisse der Suche des Journals kommen ohnehin bei Warhorn an.
  - Ohne das Journal, bei fehlgeschlagener Suche oder mit ausgeschaltetem Warhorn passiert nichts. TOC: `OptionalDeps: ForeverDungeonJournal`.
  - **Im Spiel prüfen:** Auge im Journal bei geschlossener Gruppensuche und bei offener Gruppensuche, einmal von der Seite Eintragen aus. Warhorn zeigt Suchen mit dem Dungeon oben in der Auswahl und die passenden Gruppen. Keine Meldung „blockiert“ und keine Suche, die hängen bleibt.

## 0.3.4

Kurz: Öffnet man die Gruppensuche über das Dungeon-Journal, liegt Warhorn jetzt oben. Blizzards Fenster schaut nicht mehr darüber.

- 0.3.4 (17.11.2026, Fehler gemeldet von KarloDerBaer): Nach dem Klick auf das Auge im Addon ForeverDungeonJournal lag Blizzards Seite Eintragen über Warhorn, bis zum `/reload`, egal wie man die Gruppensuche danach öffnete.
  - **Ursache:** ForeverDungeonJournal setzt Blizzards Fenster nach dem Öffnen in die Schicht DIALOG über sein Journal. Warhorn hängt an diesem Fenster und rutschte mit in DIALOG. In derselben Schicht zeichnete das Spiel Blizzards Seiten über Warhorn, obwohl Warhorn die höhere Ebene hatte.
  - **Lösung** (`Overlay.lua`, `O.Raise`): Warhorn liegt immer eine Schicht über Blizzards Fenster, normal wie bisher HIGH, nach dem Journal FULLSCREEN. Geprüft beim Öffnen, kurz danach, nach 0,3 und nach 1 Sekunde, auch beim ersten Öffnen nach `/reload` (dann entsteht Warhorn erst bei schon offenem Fenster). Wechselt Warhorn bei offenem Fenster die Schicht, blendet es sich einmal kurz neu ein.
  - **Flüsterfenster** liegt immer über Warhorn, auch in der höheren Schicht.
  - **Im Spiel prüfen:** Nach `/reload` über das Auge im Dungeon-Journal öffnen, Warhorn liegt oben. Schließen und normal öffnen, Warhorn liegt oben. Flüsterfenster aus Warhorn heraus öffnen, es liegt über Warhorn.

## 0.3.3

Kurz: In den Einstellungen steht „Blizzard ersetzen:“ jetzt gut lesbar vor den Haken.

- 0.3.3 (17.11.2026, Wunsch KarloDerBaer): Die Überschrift „Warhorn statt Blizzard“ lag oben links unter dem runden Bild. Sie heißt jetzt „Blizzard ersetzen:“ und steht in derselben Zeile vor den Haken Suchen, Eintragen und Wer-Liste.

## 0.3.2

Kurz: Der Reiter Eintragen zeigt jetzt zuverlässig Warhorns Seite. Der Reiter Einstellungen sitzt unten am Rand, und beim Öffnen der Gruppensuche sucht Warhorn gleich.

- 0.3.2 (17.11.2026, nach dem Test von 0.3.1 durch KarloDerBaer):
  - **Reiter Eintragen:** Blizzard zeigt beim Wechsel die neue Seite, bevor es die alte versteckt. Warhorn fand darum noch die Suchseite offen und blieb dort oder zeigte Blizzards Seite. Jetzt zählt zuerst Blizzards gewählter Reiter (`selectedTab`).
  - **Reiter Einstellungen unten** am rechten Rand statt direkt unter Blizzards Reitern (Wunsch KarloDerBaer).
  - **Suchen beim Öffnen:** Öffnet man die Gruppensuche auf der Seite Suchen (Menüknopf, Taste, `/warhorn`), sucht Warhorn gleich. Höchstens alle 5 Sekunden. Nicht, wenn Blizzard die Gruppensuche von selbst öffnet (Antwort der Wer-Liste).
  - **Im Spiel prüfen:** Wechsel auf Eintragen, Lage des Reiters Einstellungen, Suche beim Öffnen ohne Meldung „blockiert“.

## 0.3.1

Kurz: Warhorn ist jetzt so groß wie Ledger und deckt Blizzards Fenster ganz ab. Beim Eintragen gibt es den Spielstil (Vorgabe Entspannt), und der Knopf zum Kommentar führt direkt zum Kommentarfeld.

- 0.3.1 (17.11.2026, nach dem Test von 0.3.0 durch KarloDerBaer):
  - **Blizzards Fenster schaute unten heraus:** Seit 0.3.0 kommt Warhorns Anzeige vor Blizzards eigener, Blizzards Reiter unten waren da noch nicht versteckt. Warhorn hielt den modernen Stil darum für den alten und endete zu weit oben. Jetzt zählt zuerst Blizzards Schalter `LFGVANILLA_SETTING_MODERN_STYLE`.
  - **Blizzards Suchfeld der Wer-Liste schien durch:** Es liegt bei Blizzard in der Schicht HIGH. Warhorn liegt in dieser Schicht jetzt auf Ebene 300.
  - **Größe wie Ledger:** 800 x 538 (Peons Fenstergröße) statt 680 breit. Die Listen nutzen dieselben Schriften wie Ledger (Peons Tabelle).
  - **Spielstil beim Eintragen:** Auswahl wie bei Blizzard (Lernen, Entspannt, Ernsthaft, Experte), Vorgabe Entspannt, je Charakter gemerkt (`lPlaystyle`).
  - **Kommentar:** Der Knopf „Kommentar bei Blizzard“ öffnet Blizzards Seite gleich in der Ansicht mit dem Kommentarfeld (Warhorns Kategorie). Warhorn zeigt den Kommentar unten an, wenn das Spiel ihn lesen lässt.
  - **Rückweg:** Der Knopf „Warhorn“ an Blizzards Seiten liegt jetzt in der Schicht HIGH. Auf Blizzards Seite Eintragen lag er unter Blizzards Teilen und war nicht zu sehen.
  - **Im Spiel prüfen:** Warhorn deckt Blizzards Fenster auf allen Seiten, Knopf Warhorn oben rechts auf Blizzards Seiten, Kommentar-Knopf landet beim Kommentarfeld, Eintragen mit Spielstil und Kommentar.

## 0.3.0

Kurz: Warhorn hat jetzt auch eigene Seiten zum Eintragen und für die Wer-Liste, dazu einen Reiter Einstellungen rechts am Fenster.
Kurz: Anflüstern öffnet ein kleines Fenster mit fertigen Vorlagen, abgeschickt wird erst mit Senden.

- 0.3.0 (17.11.2026, Wunsch KarloDerBaer, Konzept Abschnitt 13):
  - **Fenster für alle Seiten** (`Overlay.lua`, `Window.lua`): hängt an Blizzards ganzem Fenster (`LFGParentFrame`) statt an der Suchseite und zeigt je nach Blizzards Reiter die Seite Eintragen, Suchen oder Wer-Liste. Je Seite ein Knopf „Blizzard“, auf Blizzards Seiten ein Knopf „Warhorn“. Öffnet die Gruppensuche auf einer Seite, die Blizzard zeigt, springt sie wie bisher auf „Suchen“.
  - **Reiter Einstellungen** unter Blizzards Reitern rechts (eigener Rahmen, Zahnrad).
  - **Seite Eintragen** (`Listing.lua`): Kategorie, Aktivitäten zum Anhaken mit empfohlener Stufe, Knöpfe Alle und Keine, Rollen, „Neue Spieler willkommen“, Eintragen, Eintrag ändern, Austragen. In einer Gruppe nur für den Anführer. Statuszeile mit dem eigenen Eintrag.
  - **Kommentar:** Blizzards Kommentarfeld ist geschützt, ein Addon kann dort nichts hineinschreiben. Der Knopf „Kommentar bei Blizzard“ zeigt dafür Blizzards Seite, der Knopf Warhorn bringt zurück.
  - **Seite Wer-Liste** (`Who.lua`): Suchfeld wie bei Blizzard, Schnellsuche (meine Stufe ±3, meine Zone, beides), Filter nach Klasse, Stufe und „ohne Gilde“. Spalten Name, Stufe, Klasse, Gilde, Zone. Doppelklick flüstert an, Rechtsklick mit Anflüstern und Einladen.
  - **Flüsterfenster** (`Whisper.lua`): Empfänger, Auswahl der Vorlage, Textfeld, Zähler bis 255 Zeichen, Senden und Abbrechen. Platzhalter `{name}`, `{rolle}`, `{klasse}`, `{stufe}`, `{aktivitaet}`. Zwei Vorlagen zu Beginn: „Gruppe anfragen“ und „Mitspieler einladen“. Doppelklick und „Anflüstern“ in allen Listen öffnen es.
  - **Seite Einstellungen** (`Settings.lua`): je Seite Warhorn oder Blizzard, sichtbare Spalten je Liste (die erste Spalte bleibt), Farben für neue Einträge und den eigenen Eintrag, Flüstervorlagen anlegen, ändern, löschen, Standard für Gruppen und für Mitspieler.
  - Neu in `PeonWarhornDB`: `replace`, `whisper`, `hideCols`, `colors`. Neu je Charakter: `lCategory`, `lActivities`, `lNewPlayer`, `wFilter`, `wText`. Die Vorlagen bleiben bei „Standardwerte“.
  - Tests: Seiten nach Blizzards Reiter, Umschalten je Seite, Reiter Einstellungen, Eintragen, Ändern, Austragen, Wer-Suche mit Filtern und Schnellsuche, Flüsterfenster mit Vorlagen, Spalten, Farben, Vorlagen bearbeiten.
  - **Im Spiel prüfen:** ob Eintragen, Ändern und Austragen aus Warhorn gehen, ob die Wer-Suche aus Warhorn geht und die Antwort ankommt, Aussehen und Lage des Reiters Einstellungen, ob Senden im Flüsterfenster ankommt, Farbwahl.

## 0.2.2

Kurz: Warhorn sucht jetzt bei jeder Änderung an Auswahl und Filtern gleich neu. Die Rollen zeigen nur noch die Anzahl, eine grüne Zahl heißt: Platz frei.

- 0.2.2 (17.11.2026, Wünsche KarloDerBaer nach dem Test im Spiel):
  - **Automatisch neu suchen** bei jeder Änderung: Kategorie, Aktivitäten, Rollen-Haken, alles im Filtermenü und „Zurücksetzen“. Die Stufe filtert beim Tippen und sucht mit der Eingabetaste neu. Das geht, weil jede dieser Änderungen aus einem Klick oder Tastendruck kommt. Im Kampf filtert Warhorn nur die vorhandene Liste.
  - **Knopf der Aktivitäten heißt „Filter“:** Blizzards Vorlage setzte den Text beim Öffnen ohnehin auf „Filter“ zurück, darum zeigt er nicht mehr „Alle Aktivitäten“ oder die Anzahl.
  - **Rollen ohne „+n“:** nur Symbol und Anzahl. Ist für eine Rolle ein Platz frei, steht die Zahl grün.
  - Nicht mehr von selbst auf Leiste und Panel (Peon_Panel 0.4.1).

## 0.2.1

Kurz: Warhorn lässt sich jetzt bedienen, und die Gruppensuche öffnet gleich mit Warhorn.

- 0.2.1 (17.11.2026, nach dem ersten Blick im Spiel von KarloDerBaer):
  - **Bedienung ging nicht:** Ein eigener Rahmen zum Abfangen der Maus lag auf derselben Ebene wie die Bedienelemente und konnte ihre Klicks schlucken. Jetzt fängt das Fenster selbst die Maus ab, nur die Titelleiste bleibt für Blizzards Fenster frei.
  - **Kategorie blieb leer:** Kurz nach dem Anmelden liefert das Spiel noch keine Kategorien. Die Auswahl wird jetzt nachgeholt, sobald das Spiel sie meldet (`LFG_LIST_AVAILABILITY_UPDATE`), und beim Zeigen der Fläche.
  - **Linie quer durchs Fenster:** Blizzards Suchseite ist selbst ein Fenster mit Rahmen auf hoher Ebene, dieser Rahmen lag über Warhorn. Warhorn liegt jetzt in der Schicht HIGH.
  - **Moderner Stil der Gruppensuche** (Reiter rechts am Fenster statt unten): Die Fläche reicht bis an den unteren Rand und deckt Blizzards Knöpfe „Nachricht senden“ und „Gruppeneinladung“ ab. Die Reiter rechts wandern an Warhorns rechten Rand, solange Warhorn zu sehen ist.
  - **Öffnen auf Warhorn:** Öffnet man die Gruppensuche (Menüknopf, Taste), springt sie auf den Reiter „Suchen“, solange Warhorn eingeschaltet ist. Fragt Blizzard selbst einen Reiter an, gilt Blizzards Wahl.
  - **Im Spiel prüfen:** keine Linie mehr, Bedienung, Kategorie gefüllt, Reiter rechts am Rand, Öffnen über den Menüknopf landet in Warhorn.

## 0.2.0

Kurz: Warhorn liegt jetzt über Blizzards Gruppensuche und filtert Gruppen und Mitspieler nach Rolle, Klasse und Stufe. Mit dem Knopf Blizzard kommst du jederzeit zur Originalansicht zurück.

- 0.2.0 (17.11.2026, Konzept `docs/konzepte/warhorn/Peon_Warhorn_Konzept.md`, Schritte 2 bis 4 auf Wunsch von KarloDerBaer in einem Zug):
  - **Fläche über Blizzards Suchseite** (`Overlay.lua`, `Window.lua`): hängt an `LFGBrowseFrame`, ist also nur auf Blizzards Reiter „Suchen“ zu sehen und wandert mit, wenn Peon_Mover das Fenster verschiebt. Links oben bündig, 680 breit, unten endet sie über Blizzards Reitern (angehängt an `LFGParentFrameTab1`). Die Titelleiste lässt Klicks zu Blizzards Fenster durch (Verschieben mit Peon_Mover). Schließen schließt Blizzards Gruppensuche.
  - **Umschalten ohne Neuladen:** Knopf „Blizzard“ in Warhorn, Knopf „Warhorn“ oben an Blizzards Suchseite, Haken in den Optionen (`show`). Warhorn schreibt nichts in Blizzards Tabellen.
  - **Auswahl:** eigene Kategorie und Aktivitäten (mehrere), beim ersten Mal aus Blizzards Auswahl, je Charakter gemerkt.
  - **Suchen** (`Search.lua`) nur über den Knopf „Suchen“, den Knopf zum Neuladen, die Taste „Gruppensuche: Suchen“ (`Bindings.xml`) und `/warhorn suchen`, nie automatisch. Sucht Blizzards eigener Knopf, übernimmt Warhorn das Ergebnis. Änderungen an gefundenen Einträgen zeigt die Liste sofort. Im Kampf ist Suchen gesperrt. Lehnt das Spiel ab, steht das in der Statuszeile.
  - **Reiter Gruppen** (`Filter.lua`): freier Platz für die gewählten Rollen (Start mit Blizzards Rollenwahl), Klassen „nur mit“ oder „nur ohne“, ohne meine Klasse, Gruppengröße höchstens 2, 3 oder 4, Stufe von bis (ein Mitglied im Bereich). Spalten Aktivität, Anführer, Stufe, Rollen (Symbol, Anzahl, freie Plätze grün), Klassen, Alter.
  - **Reiter Mitspieler:** Einträge mit einem Mitglied, Filter nach Rolle, Klasse und Stufe. Spalten Name, Klasse, Stufe, Rollen, Aktivität, Alter.
  - Zahl der Treffer an den Reitern, Statuszeile mit Treffern und Alter der Suche (ab 60 Sekunden gold mit Hinweis). Neue Einträge seit der letzten Suche grün hinterlegt, der eigene Eintrag blau und oben, ausgetragene grau. Sortierung zu Beginn nach Alter.
  - **Tooltip** mit Aktivitäten, Anführer, Kommentar, Mitgliedern (Rolle, Klasse, Stufe) und Alter. **Doppelklick** flüstert an, **Rechtsklick** öffnet ein Menü mit Anflüstern und Einladen (Einladen nur bei Einzelspielern und wenn man einladen darf, wie bei Blizzard).
  - Einträge mit geheimen Werten werden nie herausgefiltert und nicht ausgewertet, der Tooltip nennt das.
  - `/warhorn` öffnet Blizzards Gruppensuche auf dem Reiter „Suchen“ (über Blizzards `LFGVanilla_ToggleFrame`), `/warhorn optionen` die Optionen. Starter für Peon_Panel.
  - Neu `PeonWarhornCharDB` (je Charakter): `category`, `activities`, `tab`, `gFilter`, `pFilter`. Braucht Peon API 18.
  - Tests: `test_warhorn.lua` neu aufgebaut (Fläche, Suche, alle Filter, Reiter, Tooltip, Aktionen, Aktualisierung, Kampf, Umschalten, Prüfaufbau).
  - **Im Spiel prüfen:** Lage und Größe der Fläche (Unterkante über Blizzards Reitern, Knopf „Warhorn“ oben rechts), Symbole für Rollen und Klassen, ob `/warhorn` die Gruppensuche ohne Fehlermeldung öffnet, ob Einladen aus Warhorn geht.

## 0.1.0

Kurz: Neues Modul für Gruppen, Dungeons und Raids. Diese erste Version prüft nur, was die Gruppensuche im Spiel erlaubt.

- 0.1.0 (17.11.2026, Schritt 1 des Plans unter „Offene Punkte“ in `Peon_Stand.md`):
  - **Prüfaufbau:** `/peon warhorn pruefen` oder der Knopf „Prüfung starten“ auf der Optionsseite. Sucht in der Gruppensuche zweimal mit `C_LFGList.Search`: einmal direkt nach Tastendruck oder Klick, drei Sekunden später von selbst über einen Zeitgeber. Danach zählt die Prüfung 60 Sekunden lang, wie oft das Spiel gefundene Einträge von selbst aktualisiert (`LFG_LIST_SEARCH_RESULT_UPDATED`).
  - **Gelesen wird:** welche Fenster es gibt (`LFGParentFrame`, `LFGBrowseFrame`, `PVEFrame` und weitere), ob Blizzards Gruppensuche im Vanilla-Stil geladen ist, welche Funktionen von `C_LFGList` vorhanden sind, je Suche Antwort, Anzahl und bis zu 15 Einträge mit Feldern, Anzahl je Rolle, Anführer und bis zu 10 Mitgliedern (Klasse, Stufe, Rolle, mögliche Rollen). Blockiert das Spiel die Suche (`ADDON_ACTION_BLOCKED` oder `ADDON_ACTION_FORBIDDEN`), wird das gemerkt.
  - **Datenschutz:** Namen anderer Spieler, Titel und Kommentare der Einträge werden nicht gespeichert, nur ob sie lesbar, leer oder geheim sind. Geheime Werte werden nicht ausgewertet, nur gezählt.
  - Kategorie und Aktivitäten kommen aus Blizzards Auswahl im Fenster, sonst die erste verfügbare Kategorie mit allen Aktivitäten. Blizzards Fenster wird nur gelesen. Im Kampf startet die Prüfung nicht.
  - Ergebnis in `PeonWarhornDB.probe`, nach `/reload` in `SavedVariables\Peon_Warhorn.lua`. Kurze Zusammenfassung im Chat und auf der Optionsseite.
  - Tests: `test_warhorn.lua`.
  - **Im Spiel geprüft (KarloDerBaer, 17.11.2026):** Beide Wege ausgeführt (Taste und Knopf). Suche nach Klick geht, Suche von selbst blockiert das Spiel, Änderungen an gefundenen Einträgen kommen von selbst, keine geheimen Werte. Einzelheiten in `Peon_Stand.md` unter „Offene Punkte“.
