# Peon (Kern): Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.27.2

Kurz: Gleiche Fehler mit wechselnden Speicheradressen zählen jetzt als ein Fehler. So kommen sie im Peon Manager gebündelt an.

- 0.27.2 (24.11.2026, viele einzelne Fehlerberichte am 21.11.2026): **Geändert, Fehlerspeicher:** Meldungen wie „table: 000001A2B3C4“ nennen eine Adresse, die sich mit jedem Laden ändert. `Peon.RecordError` vergleicht Meldungen jetzt ohne diese Adressen (wie schon „script ran too long“ ohne Datei und Zeile) und zählt hoch. Gleiche Regeln gelten im Peon Manager 0.54.0 und im Fehler-Worker. Die Kern-API bleibt unverändert.
  - Tests: zwei Adressen ein Fehler, andere Art oder Zeile bleibt eigen (`test.lua`).

## 0.27.1

Kurz: Die Fehlermeldung „script ran too long“ zählt als ein Fehler, auch wenn sie an verschiedenen Stellen auftritt. So kommt sie im Peon Manager als ein Bericht an und nicht als viele.

- 0.27.1 (21.11.2026, 20 einzelne Fehlerberichte aus dem Peon Manager): **Geändert, Fehlerspeicher:** Die Meldung nennt die Stelle, an der das Spiel abbrach, die ist fast jedes Mal eine andere. `Peon.RecordError` vergleicht solche Meldungen ohne Datei und Zeile und zählt hoch. Der Fehler-Worker bildet seine Kennung ebenso (`worker\peon-fehler\worker.mjs`, wirkt nach dem Hochladen).
  - Tests: zwei Stellen ein Fehler, andere Meldung bleibt eigen (`test.lua`), Kennung im Worker (`reports.test.js`).

## 0.27.0

Kurz: Liefert das Spiel keinen Realm-Namen, nimmt Peon den zuletzt bekannten. Vorher zeigten Ledger und Broker in diesem Fall leere Fenster.

- 0.27.0 (20.11.2026, Fehler gemeldet von KarloDerBaer): **Neu, `Peon.RealmName()` (API 27).** Nach einem Neustart lieferte `GetRealmName()` einen leeren Text, Ledger und Broker suchten ihre Daten dann unter „?“. Der Kern merkt sich den letzten echten Namen (`PeonDB.lastRealm`), ohne ihn hilft die Liste der Profile („Name-Realm“ dieses Charakters). Die Profile nutzen ihn ebenfalls.
  - Tests: echter Name gemerkt, leerer Name mit Merker, aus der Liste der Profile, ganz ohne Hinweis (`test_profile.lua`).

## 0.26.0

Kurz: Profile laufen jetzt mit. Alle Charaktere nutzen das Profil „Standard“, für einzelne Charaktere wählst du unter Peon > Profile ein eigenes.

- 0.26.0 (18.11.2026, Wunsch KarloDerBaer):
  - **Neu, Kern-API 26: laufende Profile.** Es gibt immer „Standard“, alle Charaktere nutzen es, bis man für einen Charakter ein anderes wählt (`Peon.Profiles.Use`, `Create`, `Current`). Änderungen gelten sofort für alle Charaktere mit demselben Profil. Die bisherigen Einstellungen werden beim Update zu „Standard“.
  - Technik: Die Werte des aktiven Profils liegen wie bisher direkt in der Kontotabelle des Moduls, die anderen unter `_profiles`, der Name unter `_profile`. Beim Einloggen setzt der Kern das Profil des Charakters ein (`Module:_SwitchProfile`). So lesen und schreiben die Module ihre Einstellungen unverändert. Neu: `PeonCharDB` je Charakter mit dem gewählten Profil, `PeonDB.profileList`, `PeonDB.profileUsers`.
  - Zum Profil gehören weiter nur die Schlüssel aus `defaults` ohne `keepOnReset`, `charKeys` und `debug`. Fensterpositionen, Merker und Daten bleiben für das ganze Konto gleich.
  - **Geändert:** Die gespeicherten Stände aus 0.25.0 werden zu Profilen. `Save`, `Load`, `Delete` und `List` aus API 25 bleiben mit gleicher Bedeutung. Befehle: `/peon profil benutzen | neu | leer | kopieren | loeschen <Name>`, `/peon profil standard`. Die Seite Peon > Profile zeigt, welches Profil dieser Charakter nutzt und wie viele Charaktere jedes Profil haben.

## 0.25.0

Kurz: Neu sind Profile. Speichere die Einstellungen aller Peon-Addons unter einem Namen und lade sie auf einem anderen Charakter mit /peon profil.

- 0.25.0 (18.11.2026, Review mit KarloDerBaer):
  - **Neu, Kern-API 25:** Profile (`Profiles.lua`, `Peon.Profiles`). Ein Profil speichert je Modul alle Schlüssel aus `defaults` außer `keepOnReset` und `debug`, auch Charakterwerte. Laden prüft jeden Wert wie beim Start, begrenzt Zahlen und feuert danach `RESET`. `opts.noProfile` lässt ein Modul aus. Gespeichert in `PeonDB.profiles`, höchstens 20. `/peon profil [speichern | laden | loeschen <Name>]`, Unterseite Peon > Profile. Neu im Modul: `mod:_ApplyProfile(werte)`.
  - **Entfernt:** Beispielfenster `/peon ui` und UI-Prüfung `/peon ui pruefen` (`UIDemo.lua`, `UIProbe.lua`, rund 950 Zeilen). Sie liegen jetzt im privaten Peon_Debug (`/pdebug ui`), weil sie nur beim Entwickeln gebraucht werden. Die Bausteine `Peon.UI` bleiben unverändert. Die Daten `PeonDB.uiProbe` und `PeonDB.uiDemoTab` werden nicht mehr geschrieben.

## 0.24.1

Kurz: Peon zeigt einmal kurz, dass es Daten mit anderen Peon-Nutzern teilt und wie du das ausschaltest.

- 0.24.1 (18.11.2026, Review mit KarloDerBaer):
  - **Neu:** Einmaliger Hinweis beim ersten Login (`teilen-2026-11`): Peon teilt Daten über einen versteckten Kanal, nichts davon im Chat, keine Charakternamen gespeichert, Ausschalten unter Einstellungen oder mit `/peon teilen aus`.
  - **Geändert:** Keine Weitergabe mehr, auch nicht für Nachrichten von Peon 0.23.0. In 0.23.0 hat nur die Begrüßung Daten getauscht, die Weitergabe ließ jeden Empfänger fremde Spieler anflüstern. `RandomNames`, `RELAY`, `FANOUT` und `MAX_HOPS` bleiben als Teil der Kern-API stehen, werden aber nicht mehr genutzt. Der Status unter `/peon teilen` nennt keine weitergegebenen Nachrichten mehr.
  - **Geändert:** Text der Option „Daten teilen“ beschreibt, wofür Module den Austausch nutzen (statt „vorerst nur die Version“).

## 0.24.0

Kurz: Peon-Nutzer erreichen sich jetzt direkt über den versteckten Kanal. Das ist schneller und braucht weniger Nachrichten.

- 0.24.0 (18.11.2026): **Kern-API 24:** `info.name` gibt Diensten den Namen des Absenders („Vorname Nachname“, ohne Realm). Nur für Dienste mit erlaubter Namensanzeige, zuerst die Rezepte der Freunde in Peon_Profession 0.6.0.
- 0.24.0 (18.11.2026): **An alle über den Kanal, an einen per Flüstern** (`Comm.lua`, Regeln für Module im Konzept Abschnitt 8, KarloDerBaer). Die Prüfung mit zwei Spielern hat gezeigt, dass Addon-Nachrichten im Kanal alle Mitglieder erreichen. `Peon.Comm.Send(dienst, daten)` geht deshalb jetzt einmal in den Kanal statt per Flüstern an drei Mitglieder mit Weitergabe. `Send` mit `{ to = name }` und `info.reply` bleiben Flüstern. Beides ohne Weitergabe (Flag `d`). `SendChannel` ist jetzt dasselbe wie `Send` ohne Ziel. Nachrichten von Peon 0.23.0 werden weiter verstanden und weitergegeben.
  - Begrüßung nur noch im Kanal, höchstens alle 30 Minuten. Geantwortet wird nur auf die erste Begrüßung nach dem Einloggen (`f`) und auf direkte Begrüßungen, sonst würde jede Begrüßung eine Antwort von allen auslösen.
  - Aufgeräumt: Die Prüfung `/peon teilen pruefen` flüstert sich nur noch als „Vorname Nachname“ an (`spaceEcho` und `hyphenEcho` entfallen).
  - Tests: `test_comm.lua` mit Kanal wie in Forever, `info.name`, Rundsendung an alle, lange Daten über den Kanal, ohne Kanal nichts an alle, keine Antwort auf spätere Begrüßungen, Nachrichten von 0.23.0. `test_uiprobe.lua` Version, Release-Test API 24.
  - **Im Spiel prüfen:** Mit Peon_Debug (Kanal und Flüstern sichtbar) nach dem Einloggen: eine Begrüßung im Kanal, Antworten anderer Peon-Nutzer per Flüstern.

## 0.23.1

Kurz: Behebt die Meldung „Kein Spieler mit dem Namen ... online“, die beim Austausch mit anderen Peon-Nutzern erscheinen konnte.

- 0.23.1 (17.11.2026): **Namen ohne Realm** (`Comm.lua`). Peon ergänzte Namen aus der Mitgliederliste über die Spieler-ID. Das Spiel hängt dort bei anderen Spielern den Realm an („Vorname Nachname-Realm“), beim eigenen Charakter nicht. An diesen Namen kommt kein Flüstern an, das Spiel meldete „nicht online“. Jetzt fällt der Realm überall weg (neu `Peon.Comm.Plain`), gemerkt und angeflüstert wird nur „Vorname Nachname“. „Vorname-Nachname“ gilt nicht mehr als derselbe Spieler wie „Vorname Nachname“, das Spiel liefert diese Form nirgends.
  - Erstes Ergebnis mit zwei Spielern (17.11.2026): Die Begrüßung kam beim anderen Peon-Nutzer über beide Wege an, 2-mal über den Kanal und 4-mal per Flüstern. Kanal-Nachrichten erreichen also andere Mitglieder, und Flüstern geht zwischen Spielern.
  - Tests: `test_comm.lua` mit Absendern und Spieler-IDs mit Realm, Prüfung, dass nie an einen Namen mit Realm geflüstert wird. `test_uiprobe.lua` Version.
  - **Im Spiel prüfen:** Mit Peon_Debug und Flüstern sichtbar: keine Meldung „nicht online“ mit Realm mehr.

## 0.23.0

Kurz: Peon lernt still andere Peon-Nutzer kennen. Das ist die Grundlage, damit Module später Spieldaten wie Sammelstellen teilen können. In den Peon-Einstellungen lässt es sich unter „Daten teilen“ abschalten.

- 0.23.0 (17.11.2026): **Datenaustausch zwischen Peon-Nutzern, Kern-API 23** (`Comm.lua`, Konzept `docs/konzepte/kern/Peon_Comm_Konzept.md`). Neu: `Peon.Comm.Register`, `Send`, `IsOn`, `SetOn`, `Peers`, `Known`, `Status`. Peon tritt dem versteckten Kanal `PeonNet` bei (Ausweichnamen `PeonNet2`, `PeonNet3`), entfernt ihn aus allen Chatfenstern und liest dort die Mitglieder. Nachrichten gehen per unsichtbarem Addon-Flüstern an drei zufällige Mitglieder, die sie an je zwei weitergeben, höchstens dreimal. Takt 1,25 Sekunden, nichts im Kampf und in Instanzen, lange Daten in bis zu acht Teilen, doppelte Nachrichten 30 Minuten erkannt, Prüfwert des Urhebers statt Namen. Die Meldung „Spieler ist nicht online“ nach eigenem Flüstern blendet Peon aus. Erster Schritt (KarloDerBaer): Noch kein Modul tauscht Daten, der Kern lernt mit dem eigenen Dienst `hello` andere Peon-Nutzer kennen (Version und Kern-API). Ergebnis in `PeonDB.comm`. Schalter und Stand in den Peon-Einstellungen, Befehl `/peon teilen` mit `an`, `aus` und `pruefen`.
  - Nach der ersten Prüfung im Spiel (17.11.2026): Namen mit Vor- und Nachnamen. Peon flüsterte an den Vornamen allein, das Spiel meldete „nicht online“. Jetzt gilt der volle Name (`UnitName` liefert den Nachnamen als zweiten Wert), „Vorname Nachname“ und „Vorname-Nachname“ zählen als derselbe Spieler. Die Prüfung flüstert sich in beiden Schreibweisen an und speichert, welche ankommt, dazu die Form der Namen aus Liste, Spieler-ID und Absender (nur „a a“, „a-a“ oder „a“, keine Namen). Die Meldung „nicht online“ blendet sie aus.
  - Zum Test im Release (KarloDerBaer): Die Begrüßung geht zusätzlich höchstens alle 30 Minuten einmal als Addon-Nachricht in den Kanal, ohne Weitergabe, auch wenn sonst niemand bekannt ist. Wer sie bekommt, antwortet per Flüstern. In `PeonDB.comm.peers` steht je Nutzer, wie oft er per Flüstern (`w`) und über den Kanal (`c`) ankam, dazu die Zähler `chanSent` und `chanRecv`. Neu: `Peon.Comm.SendChannel`, `info.via` (`w` oder `c`).
  - Nach einer Trennung vom Chatserver im Test (17.11.2026): Allein im Kanal forderte Peon die Mitgliederliste an, jede Antwort des Servers löste die nächste Anfrage aus. Jetzt höchstens eine Anfrage je Minute und nie als Antwort auf eine gerade angekommene Liste. Den Kanal versteckt Peon nur in Fenstern, in denen er steht, nach Änderungen der Chatfenster höchstens alle 5 Sekunden.
  - Für ein privates Werkzeug (Peon_Debug, nicht im Repo): `Peon.Comm.Listen(fn)` meldet jede gesendete und empfangene Peon-Nachricht, `Peon.Comm.SetShow("channel", an)` lässt den Kanal im Chatfenster, `Peon.Comm.SetShow("whisper", an)` zeigt die Meldung „nicht online“.
  - Tests: neu `test_comm.lua` (mehrere Spieler mit Vor- und Nachnamen und nachgebautem Netz wie in Forever), angepasst `test_uidemo.lua`, `test_uiprobe.lua` (Reihenfolge und Version in der TOC), `test_fish.lua` (Schalter der Kern-Seite nicht mitzählen).
  - **Im Spiel prüfen:** `/peon teilen pruefen` (erste Prüfung: eigene Kanal-Nachricht kam zurück, Flüstern an den Vornamen nicht. Nach der Korrektur erneut geprüft: Flüstern an den vollen Namen kommt in beiden Schreibweisen an, Kanal-Nachricht kommt zurück, Namen überall als „Vorname Nachname“. Offen: zwei Spieler). Nach dem Release mit mehreren Peon-Nutzern: `/peon teilen` und `PeonDB.comm.peers` nach einiger Zeit. Kanal in keinem Chatfenster sichtbar, keine Meldungen im Chat.

## 0.22.0

Kurz: Module können Rückmeldungen an Peon Feedback weitergeben, zum Beispiel das Ergebnis einer Prüfung im Spiel.

- 0.22.0 (14.11.2026): **Rückmeldungen aus Modulen, Kern-API 22** (`Feedback.lua`). Neu: `Peon.SetFeedbackHandler(fn)` (meldet Peon_Feedback an), `Peon.CanAddFeedback()` und `Peon.AddFeedback({ module, kind, area, prio, text })`. Ohne Peon_Feedback liefert `AddFeedback` nil. Fehler im Handler werden abgefangen. Erste Nutzung: Peon_ClassBuddy schickt das Ergebnis seiner Prüfung so an den Peon Manager.
  - Tests: `test_feedback.lua` (Eintrag über den Kern), `test_classbuddy.lua` (ohne und mit Peon_Feedback, Fehler im Handler), Release-Test auf API 22.

## 0.21.0

Kurz: Listen können Trennstriche zwischen Zeilen zeigen (zum Beispiel im Buch von Ledger).

- 0.21.0 (14.11.2026): **Trennstrich in Tabellen, Kern-API 21** (`UIKit.lua`). `UI.Table` nimmt `o.rowLine(item)`: Gibt die Funktion `true` zurück, steht über der Zeile ein dünner goldener Strich. Ältere Module ohne die Option sehen keinen Unterschied.
  - Tests: Kern-API 21 und Strich in der Tabelle in `test_ledger.lua`, Release-Test auf API 21.
  - **Im Spiel prüfen:** Ledger, Reiter Buch, „Nach Art“: Strich vor dem Spielalltag und vor den Summen.

## 0.20.1

Kurz: Das Peon-Gegenstandsmenü (Strg+Rechtsklick) geht jetzt auch im Auktionshaus auf dem Gegenstand der Kaufansicht auf und wird nicht mehr vom Favoriten-Menü ersetzt.
Kurz: Ein Fehler bei Hinweisen über Knöpfen ist behoben.

- 0.20.1 (13.11.2026): Zwei Fehler aus den Fehlerberichten.
  - **Gegenstandsmenü nach dem Loslassen** (`ItemMenu.lua`): Beim Drücken merkt sich der Kern nur den Gegenstand, das Menü öffnet einen Bildaufbau nach dem Loslassen (`GLOBAL_MOUSE_UP`). Blizzards Knöpfe öffnen ihr eigenes Menü beim Klick, so ersetzte das Favoriten-Menü des Auktionshauses Peons Menü sofort wieder.
  - **Hinweis mit einem Text** (`UIKit.lua`): `UI.SetTooltip` und `UI.IconButton` nehmen jetzt auch einen einzelnen Text statt einer Liste. Vorher meldete BugGrabber „bad argument #1 to 'ipairs'“.
  - Tests: Gegenstandsmenü mit Drücken und Loslassen in `test_broker.lua`, Version im Prüfbefehl.
  - **Im Spiel prüfen:** Im Auktionshaus einen Gegenstand öffnen, Strg+Rechtsklick auf sein Bild oben: Peons Menü bleibt offen. Strg+Rechtsklick in den Taschen geht wie bisher.

## 0.20.0

Kurz: Module können wichtige Hinweise einmalig in einem Fenster zeigen, zum Beispiel nach einem Update. `/peon neu` zeigt sie wieder.

- 0.20.0 (12.11.2026): **Einmalige Hinweise, Kern-API 20** (neue Datei `Notice.lua`, abgestimmt mit KarloDerBaer).
  - Module melden Hinweise mit `mod:AddNotice({ id, title, text, date })`, der Kern selbst mit `Peon.AddNotice`. Die `id` bekommt den Schlüssel des Moduls vorne (`broker:umbau-2026-11`) und darf sich nie ändern.
  - Rund 5 Sekunden nach dem Einloggen zeigt der Kern alle noch nicht gesehenen Hinweise in einem Fenster (Titel, Absender mit Datum, Absätze, Trennlinie dazwischen, Knopf „Verstanden“). Im Kampf wartet er und versucht es alle 10 Sekunden.
  - Gesehen gilt je Konto, sobald das Fenster offen war (auch Schließen mit ESC oder X). Gemerkt in `PeonDB.noticesSeen`. Neue Nutzer sehen die Hinweise ebenfalls einmal.
  - `/peon neu` (auch `/peon hinweise`, `/peon news`) zeigt alle gemeldeten Hinweise wieder.
  - Tests: neuer Test `test_notice.lua`, Prüfbefehl auf die neue Version angepasst.
  - **Im Spiel prüfen:** Fenster nach dem Einloggen mit einem Hinweis, Bildlauf bei langem Text, Verstanden und ESC, nach `/reload` kein zweites Mal, `/peon neu`.

## 0.19.0

Kurz: Listen im Stil des Auktionshauses können einzelne Zeilen farbig hinterlegen (zum Beispiel die Zielstufe im Fokus von Broker).

- 0.19.0 (12.11.2026): **Kern-API 19:** `UI.Table` kennt die Option `rowBg = function(item) return r, g, b, a end`. Die Zeile bekommt diese Hintergrundfarbe (über den Streifen, unter Markierung und Auswahl), `nil` heißt keine. Ältere Module ohne die Option sehen keinen Unterschied, Module mit der Option laufen auf älteren Kernen ohne Farbe weiter.
  - Tests: Prüfbefehl auf die neue Version angepasst.

## 0.18.0

Kurz: Neues Beispielfenster `/peon ui` mit allen Bausteinen für ein einheitliches Aussehen der Peon-Fenster im Stil des Auktionshauses. Dazu der Prüfbefehl `/peon ui pruefen`, der ausliest, welche Grafiken Blizzards Fenster wirklich zeigen.

- 0.18.0 (11.11.2026): **Prüfbefehl für das UI-Design** (neue Datei `UIProbe.lua`, Kern-API unverändert 17).
  - `/peon ui pruefen`: prüft rund 130 Atlas-Namen aus Blizzards Code (Datei, Größe, Ausschnitt, fehlt), rund 40 Schrift-Objekte (Schrift, Größe, Farbe, Schatten), rund 40 Vorlagen (als eigene, versteckte Rahmen angelegt) und alle gerade offenen Blizzard-Fenster aus einer festen Liste (Auktionshaus, Berufe, Einstellungen, Charakter, Dungeonbrowser und weitere).
  - `/peon ui pruefen maus`: der Rahmen unter der Maus samt Eltern-Kette und Kindern (die letzten 10 bleiben gespeichert).
  - `/peon ui pruefen <Pfad>`: ein Rahmen, zum Beispiel `AuctionHouseFrame.CategoriesList`. `/peon ui pruefen leeren` löscht alles.
  - Je Grafik: Atlas, Datei, Ausschnitt, Farbe, Deckkraft, Ebene, Größe, Anker. Je Schrift: Schrift-Objekt, Datei, Größe, Farbe, Schatten, Ausrichtung, Text. Je Rahmen: Typ, Vorlage (`layoutType`), Hintergrund (`backgroundAtlas`), Größe, Anker, gesperrt.
  - Ergebnis in `PeonDB.uiProbe` (nach `/reload` in WTF). Nur lesen, Blizzards Rahmen werden nicht verändert.
  - Grund: In Forever („Camelot“ in Blizzards Code) liegen unter denselben Atlas-Namen teils eigene Grafiken. Broker 0.56 bis 0.58 hat deshalb dreimal falsch geraten.
  - Von KarloDerBaer im Spiel ausgeführt (Auktionshaus, Berufe). Ergebnis in `docs/konzepte/Peon_UI_Design.md` Abschnitt 2 und 3.
  - **Bausteine, Kern-API 18** (neue Datei `UIKit.lua`, `Peon.UI`, freigegeben von KarloDerBaer nach drei Tests im Spiel): Fenster mit rundem Bild, Reiter unten mit Zahl am Reiter, Reiter oben, Beschriftung über einem Bereich, Bereich mit Hintergrund in Originalgröße, Texte nach Rolle, Trennlinie, Knöpfe (normal, Gold, gesperrt, Symbol, Neu laden), Eingaben (Text, Zahl, Geld), Suchleiste, Auswahlliste, Filter, Haken, Schieberegler (zwei Arten), Formularzeile, Liste mit Kopf, Sortierung, Streifen, Auswahl, Bildlauf (Blizzards ScrollBox), leerer Liste und Ladeanzeige, Kategorieliste mit drei Stufen, Statuszeile, Gegenstand klein und groß, Tooltip, Rückfrage, Fortschritt, einklappbare Überschrift. Alle Maße und Grafiken aus der Messung.
  - **Beispielfenster** `/peon ui` (neue Datei `UIDemo.lua`): Seiten Grundlagen, Bedienelemente, Listen, Aufbau mit Testdaten und verschiedenen Zuständen. Der gewählte Reiter wird in `PeonDB.uiDemoTab` gemerkt.
  - Regeln und Maße: `docs/konzepte/Peon_UI_Design.md` (Entwurf).
  - Nach dem ersten Test von KarloDerBaer (11.11.2026): Reiter mit sauberem Abstand (Breite Text + 40, Abstand 3), Zahl am Reiter im Reiter neben dem Text (oben war sie vom Fensterrahmen verdeckt), Rückfrage als kleines Fenster (Blizzards Dialograhmen füllt seinen Elternrahmen, vorher den ganzen Bildschirm), Hintergründe passen sich dem Bereich an (abschneiden statt über den Rand, dehnen statt mitten im Bereich enden), Kategorieliste mit Innenabstand wie Blizzard, Sortierpfeil zeigt bei aufsteigender Sortierung nach oben.
  - Nach dem zweiten Test (11.11.2026): Kategorien klappen auf und zu wie im Auktionshaus (Klick öffnet, erneuter Klick schließt), nur noch der moderne Schieberegler (Wahl von KarloDerBaer), Fortschrittsbalken wie Blizzards Balken beim Herstellen mit Knopf „Abspielen“. Die Grafiken des Balkens prüft `/peon ui pruefen` jetzt mit.
  - Nach dem dritten Test (11.11.2026): Hinter der Bildlaufleiste der Kategorien liegt kein Hintergrundbild mehr, dort ist wie bei Blizzard das hellere Grau des Fensters zu sehen. Gemessen mit `/peon ui pruefen maus`: die Leiste selbst war bei beiden gleich.
  - **Im Spiel prüfen:** `/peon ui`, alle vier Seiten. Passt der Look zum Auktionshaus? Regler A oder B? Fortschritt, einklappbare Überschrift, Rückfrage und Zahl am Reiter. Sortieren, Auswahl, Bildlauf, Kontextmenü, Kategorien und Suche auf der Seite Aufbau.

## 0.17.0

Kurz: Grundlage für Listen im Aussehen des Blizzard-Auktionshauses.

- 0.17.0 (10.11.2026): **Listen wie im Auktionshaus, API 17** (für Broker 0.56).
  - `Peon.NewList` mit `style = "ah"`: Spaltenköpfe wie in Blizzards Listen, Zeilen mit Streifen, Markierung und Hervorhebung des Auktionshauses, größere Schrift (`Number14FontWhite`). Ohne die Grafiken Rückfall auf schlichte Farben.
  - `flex = Spaltenname` und `list:SetSize(breite, hoehe)`: Die Spalte wächst mit der Breite, die Zahl der Zeilen folgt der Höhe (fehlende Zeilen werden angelegt, überzählige verborgen).
  - Bestehende Listen ohne die neuen Angaben sehen aus wie bisher.

## 0.16.1

Kurz: Behebt ein Einfrieren des Spiels, wenn ein Diagramm ohne Hilfslinien gezeichnet wurde (Broker-Tooltip mit Umschalt).

- 0.16.1 (09.11.2026, gemeldet von KarloDerBaer: Spiel friert beim erweiterten Tooltip ein, BugGrabber „insecure scripts exceeded execution limit“): `Peon.NiceRange` teilte bei `steps = 0` (Diagramm mit `grid = 0`) durch 0, die Schleife `while b < hi` endete nie. Jetzt mindestens 1 Schritt, ungültige Schrittweite gibt den Bereich unverändert zurück, die Schleife hat eine Obergrenze. `grid = 0` zeichnet keine Hilfslinien.

## 0.16.0

Kurz: Strg+Rechtsklick auf einen Gegenstand öffnet jetzt ein Menü mit Einträgen der Peon-Module, zum Beispiel „Auf Einkaufsliste“. Die Taste lässt sich auf der Peon-Seite der Einstellungen ändern.

- 0.16.0 (09.11.2026): **Gegenstandsmenü, API 16** (Konzept `docs/konzepte/broker/Peon_Broker_Umbau.md`, Abschnitt 9). Neue Dateien `ItemMenu.lua` und `Bindings.xml`.
  - `Peon.AddItemMenu(addon, fn(root, item), order)`: Module hängen Einträge an (`item = { id, link, name }`), zwischen Modulen eine Trennlinie. `Peon.OpenItemMenu(item, owner)`, `Peon.ItemMenuEntries()`.
  - Erkennung wie Ledgers Alt+Klick: Mausklick (`GLOBAL_MOUSE_DOWN`) und Gegenstand im sichtbaren Tooltip, dazu `HandleModifiedItemClick` für Links. Nicht auf Aktionsleisten. Menü über `MenuUtil.CreateContextMenu`.
  - Klick einstellbar auf der Peon-Seite (`PeonDB.itemMenuClick`, Standard Strg+Rechtsklick, auch Alt+Rechts, Umschalt+Rechts, Strg+Mitte, Mitte, aus). Umschalt+Rechtsklick ist bei Blizzard belegt (Stapel teilen, mehrere Stapel kaufen), das steht dabei.
  - Tastenbelegung „Peon: Gegenstandsmenü für den Gegenstand unter der Maus“ (`PEON_ITEM_MENU`).
  - **Im Spiel prüfen:** Strg+Rechtsklick in Taschen, Bank, beim Händler, auf Questbelohnungen und Chat-Links. Löst Blizzard dabei noch etwas anderes aus? Auswahl auf der Peon-Seite der Einstellungen.

## 0.15.0

Kurz: Grundlage für die neuen Einträge von Peon_Panel.

- 0.15.0 (07.11.2026): API 15. `mod:AddLauncher` legt weitere Starter eines Moduls an, neue Felder `onWheel` (Mausrad) und `available` (gerade nicht anzeigen), dazu `Launcher:IsAvailable` und `Launcher:Wheel`. Vorhandenes bleibt unverändert.

## 0.14.0

Kurz: Grundlage für das neue Addon Peon_Panel.

- 0.14.0 (07.11.2026): API 14. Neue Datei `Launcher.lua`: Starter (`mod:NewLauncher`, `Peon.GetLaunchers`, `Peon.OnLauncherAdded`, `Peon.OnLauncherRefresh`), den `mod:NewMinimapButton` selbst anlegt, und kurze Zahlen (`Peon.ShortNumber`, `Peon.ShortGold`).
  - Der Kern merkt sich in `PeonDB.panelHid`, welche Minimap-Buttons Peon_Panel ausgeblendet hat, und schaltet sie wieder ein, wenn Panel beim Login nicht geladen ist.
  - **Im Spiel prüfen:** Peon_Panel abschalten, die Buttons sind danach wieder da. Selbst ausgeblendete bleiben aus.

## 0.13.0

Kurz: Der Manager kennt jetzt die Bereiche aller Module für Rückmeldungen.

- 0.13.0 (06.11.2026, Wunsch KarloDerBaer): API 13 – `Peon.SaveFeedbackAreas()`: Der Kern legt beim Einloggen alle gemeldeten Bereiche in `PeonDB.feedbackAreas` ab, damit der Peon Manager sie in seinem Formular anbieten kann. Bestehendes unverändert.
  - **Im Spiel prüfen:** Nach einem `/reload` bietet der Manager unter „Rückmeldungen“ die Bereiche der Module an.

## 0.12.0

- 0.12.0 (06.11.2026, Wunsch KarloDerBaer, Anlass: Fehler von Peon_Tooltip im Dungeon, der nirgends gespeichert war): API 12 – **Fehlerspeicher.** Abgefangene Fehler aller Module (`mod:ReportError`, `mod:Call`) und des Kerns stehen jetzt in `PeonDB.errors` (Addon, Bereich, Text, Version, Build, erstes und letztes Auftreten, Anzahl, höchstens 100, gleiche Fehler zählen hoch). Im Chat steht nur noch einmal pro Sitzung ein kurzer Hinweis. Neu: `Peon.RecordError`, `Peon.ClearErrors`, `Peon.ReportCoreError`, Befehl `/peon fehler` (Text zeigen) und `/peon fehler leeren`. Geheime Fehlertexte werden nicht mehr ausgewertet. Bestehendes bleibt nutzbar, nur der Chat-Text von `ReportError` ist kürzer.
  - **Im Spiel prüfen:** Löst ein Modul einen Fehler aus, zeigt `/peon fehler` den vollen Text, auch nach `/reload`.

## 0.11.1

- 0.11.1 (05.11.2026): Diagramm: Ein Wert ohne Nachbarn erscheint bei Linien und Stufenlinien als Punkt. Eine Linie braucht zwei Punkte, deshalb blieb das Diagramm am ersten Tag mit Daten leer (gesehen in Ledger). API unverändert. **Im Spiel prüfen:** Punkte im Ledger-Reiter „Gegenstand“.

## 0.11.0

- 0.11.0 (07.10.2026, Wunsch KarloDerBaer für die Tooltip-Optionen): API 11 – **Untertabs auf Optionsseiten**: `page:Tabs({ { key, Text }, … }, y)` (Reiterleiste oben, `PanelTopTabButtonTemplate`, Rückfall normale Knöpfe), `page:Column(x, y, reiter)` (Spalte gehört zu einem Reiter; ohne Reiter immer sichtbar), `page:SelectTab(key)`, `page:GetTab()`, `page.onTab(page, key)`. Bausteine einer Reiter-Spalte hängen an einem Haltefenster je Reiter (eigenes Ein-/Ausblenden eines Bausteins bleibt erhalten); der Reset-Knopf steht unter der tiefsten sichtbaren Spalte. Diagramm-Legende: bei mehreren Reihen mit demselben Schlüssel gewinnt die Reihe mit Beschriftung (vorher die letzte – Ledger zeigte „zone“ statt „Gewinnzone“). Bestehendes unverändert.

## 0.10.0

- 0.10.0 (06.10.2026, Konzept `Peon_Ledger_Gegenstand.md` G1): API 10 – **Diagramm-Baustein** `Peon.NewChart` (neue Datei Chart.lua): Linien (gestrichelt, Lücken überbrücken), Stufenlinien, Fläche zwischen zwei Linien (Band; Gewinnzone zweifarbig je Abschnitt, Trapez über `SetVertexOffset`), Balken (auch unter 0 in eigener Farbe), Punkte (Kreis/Quadrat), senkrechte Markierungen, waagerechte Linie, zwei Achsen mit schönen Grenzen (`Peon.NiceRange`) und eigener Beschriftung, Mauslinie mit `onHover(index)`, Legende mit Knöpfen an/aus (`ch:CreateLegend`), `ch:SetSize`, verknüpfte Diagramme (`Peon.LinkCharts`: gemeinsame Mauslinie, gleicher Bereich links). Linien über `CreateLine` (Rückfall ohne: kleine Kästchen). Bereich „Diagramm“ für Peon_Feedback. Bestehendes unverändert. **Im Spiel prüfen:** ob `CreateLine` und `SetVertexOffset` in Forever gehen (Linien glatt, Gewinnzone als Fläche statt Treppe).

## 0.9.0

- 0.9.0 (02.10.2026): API 9 – Bereiche für Rückmeldungen: `Peon.SetFeedbackAreas(ADDON_NAME, { … })` und `Peon.GetFeedbackAreas(ADDON_NAME)` (Kopie der Liste; doppelte, leere und falsche Einträge werden entfernt). Der Kern meldet eigene Bereiche (Einstellungsseite, Bausteine, Liste, Minimap-Button, Debug-Log, Chatbefehle). Neue Datei Feedback.lua, bestehendes unverändert.

## 0.8.0

- 0.8.0 (01.10.2026): API 8 – Liste mit Zeilenfarbe (`rowColor = function(item) return r, g, b, a end`, `list:UpdateColors()` nur für die Farben, z. B. zum Pulsieren). Bestehendes unverändert.

## 0.7.0

- 0.7.0 (29.09.2026): API 7 – Liste mit Spalten, Sortierung und Bildlauf (`Peon.NewList`, `page:List`), Minimap-Button (`mod:NewMinimapButton`). Fishing behält vorerst seinen eigenen Minimap-Button.

## 0.6.0

- 0.6.0 (29.09.2026): API 6 – Auswahlliste `page:Dropdown` (neue Menü-API, Rückfall UIDropDownMenu, dann Knopfreihe; Liste auch per Funktion; eigene get/set).

## 0.5.0

- 0.5.0 (29.09.2026): API 5 – Button, Text, Check mit Hinweis und eigenen Werten, Neuanordnung beim Refresh, `opts.keepOnReset`.
