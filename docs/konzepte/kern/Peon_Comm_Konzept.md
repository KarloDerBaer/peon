# Peon (Kern): Konzept Datenaustausch zwischen Peon-Nutzern (Peon.Comm)

Stand: 18.11.2026. Gebaut in Peon 0.23.0 (API 23) als erster Schritt ohne Dienste der Module, im Spiel mit zwei Spielern geprüft. Ab Peon 0.24.0 an alle über den Kanal, an einen per Flüstern. **Regeln für Module: Abschnitt 8.**

## 1. Idee

Peon-Nutzer tauschen Spieldaten untereinander aus, ohne dass jemand etwas davon sieht. Der Kern stellt dafür eine Schnittstelle bereit. Sie läuft nur, wenn mindestens ein Modul sie braucht. Erster Nutzer ist Peon_Profession mit den Sammelstellen, die Schnittstelle soll aber von Anfang an für weitere Daten taugen.

## 2. Was schon feststeht (KarloDerBaer, 17.11.2026)

- Der Austausch gehört in den Kern und wird nur genutzt, wenn ein Modul ihn braucht.
- Er ist von Anfang an an und lässt sich abschalten.
- Daten von anderen erscheinen sofort, aber als fremd erkennbar (anders gefärbt), bis zwei verschiedene Spieler sie melden oder man es selbst bestätigt.

## 3. Was auf Forever geht (Erkenntnis aus PLG)

Profession Leveling Guide (MIT, `Module\Netz.lua`, Version 2.6.8 und später) hat es auf dem Forever-Client getestet:

- **Addon-Nachrichten über einen Kanal (`CHANNEL`) kommen nicht an**, auch die eigenen nicht. Senden meldet keinen Fehler. *Widerlegt durch die eigene Prüfung mit zwei Spielern (17.11.2026, Abschnitt 7): Kanal-Nachrichten erreichen alle Mitglieder.*
- **Unsichtbares Addon-Flüstern (`WHISPER`) geht.**
- PLG nutzt deshalb einen versteckten Kanal nur als Treffpunkt: Wer im Kanal ist, hat das Addon. Die Liste der Mitglieder liefert `C_ChatInfo.GetChannelRosterInfo`. Der Kanal wird aus allen Chatfenstern entfernt (`ChatFrame_RemoveChannel`).
- Die Daten gehen per Addon-Flüstern an wenige zufällige Mitspieler aus der Liste (eigene Nachricht an 3, weitergegebene an 2), die sie höchstens dreimal weitergeben. So verbreiten sie sich auch zwischen Spielern, die nie gleichzeitig online sind.
- Takt: höchstens etwa eine Flüsternachricht je 1,25 Sekunden (Blizzard drosselt bei etwa einer je Sekunde). Nachrichten höchstens 255 Zeichen.
- Jede Nachricht trägt einen Prüfwert des Urhebers und die Zahl der Sprünge. Doppelte Nachrichten werden 30 Minuten lang erkannt.
- Ausweichnamen für den Kanal, falls einer gesperrt ist.

Im Spiel selbst noch einmal bestätigen (erster Schritt der Sitzung): Kanal-Nachricht kommt nicht an, Flüstern kommt an, Mitgliederliste lesbar.

## 4. Vorschlag für die Schnittstelle (API 23, nur Erweiterung)

```lua
-- Ein Modul meldet einen Dienst an. Erst dann tritt Peon dem Kanal bei.
Peon.Comm.Register("nodes", {
    version = 1,
    onReceive = function(daten, info) end,   -- info.melder = Prüfwert, info.spruenge
})
Peon.Comm.Send("nodes", daten)              -- Tabelle oder Text, der Kern packt und teilt auf
Peon.Comm.IsOn()                            -- Austausch eingeschaltet?
Peon.Comm.Peers()                           -- Zahl der erreichbaren Peon-Nutzer
```

- Ein Präfix `PEON` für alle Dienste, der Dienst steht in der Nachricht.
- Der Kern kümmert sich um Kanal, Mitgliederliste, Warteschlange, Takt, Weitergabe, doppelte Nachrichten und Prüfwert.
- Die Module kümmern sich um ihre Daten: was gesendet wird, wie oft, und wie fremde Daten gespeichert werden.
- Nicht im Kampf und nicht in Instanzen senden. Geheime Werte vorher mit `Peon.IsSecret` prüfen.
- Keine Charakternamen speichern oder anzeigen. Namen nur im Speicher zum Zustellen.
- Abschalten in den Kern-Optionen („Daten mit anderen Peon-Nutzern teilen“). Dann verlässt Peon den Kanal und sendet nichts.
- Abschnitt im Überblick (`Peon_Ueberblick.md`) und Tests wie bei den anderen Kern-Teilen.

## 5. Mögliche Dienste

| Dienst | Modul | Daten |
|---|---|---|
| nodes | Profession | Sammelstellen: Karte, Ort gerundet, Vorkommen, Beute (Daten ab Profession 0.5.0 in `PeonProfessionDB.nodes`) |
| colors | Profession | gemessene Rezeptfarben (`PeonProfessionDB.colors`) |
| vendors, trainers | Profession | Rezepthändler und Lehrer mit Ort und Rezepten |
| fish | Fishing | Fänge je Gebiet |

Fremde Daten speichert jedes Modul getrennt von den eigenen, mit Zahl der Melder (höchstens 5 Prüfwerte je Eintrag).

## 6. Fragen an KarloDerBaer (geklärt 17.11.2026)

1. Welche Dienste kommen im ersten Schritt dazu? **Noch keine.** Über das nächste Release erst testen, ob der Austausch funktioniert. Dafür lernen sich die Peon-Nutzer unsichtbar kennen (Dienst `hello` des Kerns), das Ergebnis lässt sich danach in `PeonDB.comm` ansehen.
2. Name des versteckten Kanals? **`PeonNet`**, Ausweichnamen `PeonNet2` und `PeonNet3`.
3. Wer zeigt an, wie viele Peon-Nutzer erreichbar sind? **Der Kern**, in den Peon-Einstellungen unter dem Schalter, dazu `/peon teilen`.
4. Wie wird im Spiel geprüft? **An sich selbst:** `/peon teilen pruefen` schickt eine Kanal-Nachricht und ein Addon-Flüstern an den eigenen Charakter und liest die Mitgliederliste.

## 7. Umsetzung in Peon 0.23.0

- Datei `addons/Peon/Comm.lua`, Tests `tests/test_comm.lua`.
- Nachricht: `1^dienst^urheber^sprünge^flags^nummer^teil^teile^daten`, höchstens 255 Zeichen. Flag `d` = direkt, nicht weitergeben. Daten in einem eigenen Format verpackt (kein Lua-Code), `^`, `|`, `~` und Nullzeichen maskiert. Bis zu acht Teile je Nachricht.
- Begrüßung 30 Sekunden nach dem Betreten der Welt an drei Mitglieder, danach alle 30 Minuten. Ist dann noch niemand im Kanal, holt der Wächter (jede Minute) sie nach. Wer eine direkte Begrüßung bekommt, antwortet einmal (höchstens alle 10 Minuten je Urheber). Neue Mitglieder im Kanal werden direkt begrüßt.
- `PeonDB.comm.peers[Prüfwert] = { first, last, n, hops, v, a }`, höchstens 200.
- Nächster Schritt nach dem Test: Dienst `nodes` in Peon_Profession, fremde Stellen getrennt von den eigenen mit höchstens 5 Prüfwerten je Stelle.

### 7.1 Prüfung im Spiel allein (17.11.2026)

Von KarloDerBaer mit `/peon teilen pruefen` ausgeführt (Build 70938), Ergebnis aus `PeonDB.comm.probe`:

| Punkt | Ergebnis |
|---|---|
| Kanal `PeonNet` betreten | ja |
| Kanal-Nachricht gesendet / zurückgekommen | ja / **ja** |
| Flüstern an sich selbst gesendet / zurückgekommen | ja / **nein** |
| Mitgliederliste | 1 Eintrag (der eigene), gemeldete Anzahl 0 |

Das Flüstern scheiterte, weil Peon nur den Vornamen nahm. Im Chat stand „nicht online“ mit dem Vornamen. Forever-Charaktere haben Vor- und Nachnamen (`UnitName` liefert den Nachnamen als zweiten Wert). Seitdem nimmt Peon den vollen Namen, und „Vorname Nachname“ und „Vorname-Nachname“ gelten als derselbe Spieler. Die Prüfung flüstert in beiden Schreibweisen und merkt sich, welche ankommt, dazu die Form der Namen aus Mitgliederliste, Spieler-ID und Absender.

**Zweite Prüfung mit vollem Namen (17.11.2026):** Kanal-Nachricht zurück: ja. Flüstern an sich selbst: ja, als „Vorname Nachname“ und als „Vorname-Nachname“. Namen aus Mitgliederliste, Spieler-ID und Absender kommen alle als „Vorname Nachname“ mit Leerzeichen. Allein ist damit alles geprüft. Offen bleibt nur, was zwischen zwei Spielern ankommt. Ebenso ist offen, ob die Kanal-Nachricht nur an den Absender zurückgeht oder alle Mitglieder erreicht. Klären lässt sich das nur mit zwei Spielern im Kanal.

### 7.2 Test über den Kanal im Release (KarloDerBaer, 17.11.2026)

- Die Begrüßung geht zusätzlich höchstens alle 30 Minuten einmal als Addon-Nachricht in den Kanal (Flag `d`, keine Weitergabe), auch wenn die Mitgliederliste sonst niemanden zeigt. Direkte Begrüßungen an neue Mitglieder bleiben Flüstern.
- Wer sie bekommt, antwortet per Flüstern. So prüft dieselbe Begrüßung beide Wege zwischen zwei Spielern.
- `PeonDB.comm.peers[Prüfwert]` zählt je Nutzer `w` (per Flüstern angekommen) und `c` (über den Kanal angekommen), dazu `chanSent` und `chanRecv`.
- Auswertung nach dem Release: Stehen bei fremden Nutzern `c`-Werte, erreicht der Kanal andere Mitglieder. Stehen `w`-Werte, geht Flüstern zwischen Spielern.
- **Erstes Ergebnis (17.11.2026):** Ein anderer Peon-Nutzer kam mit `c` = 2 und `w` = 4 an. Beide Wege gehen zwischen Spielern. Dabei fiel auf: Namen über die Spieler-ID tragen bei anderen Spielern einen Realm, Flüstern daran scheitert. Behoben in 0.23.1.

### 7.3 Peon_Debug (privat)

Privates Werkzeug von KarloDerBaer im Ordner `privat/` (steht in `.gitignore`, liegt also nicht im Repo und kommt in kein Release). Zwei Schalter, getrennt für Kanal und Flüstern: Der Kanal bleibt im Chatfenster und jede Peon-Nachricht im Kanal erscheint lesbar im Chat. Jedes Peon-Flüstern erscheint im Chat, die Meldung „nicht online“ wird nicht ausgeblendet. Dafür hat der Kern `Peon.Comm.Listen` und `Peon.Comm.SetShow`. Befehl `/pdebug kanal`, `/pdebug fluestern`, `/pdebug hallo` (Begrüßung sofort senden), `/pdebug fenster <Name>` (Zeilen in ein eigenes Chatfenster), Einstellungen unter Peon > Debug. Im Spiel bestätigt (17.11.2026): Die Kanal-Begrüßung geht raus und kommt beim Absender lesbar zurück (Dienst `hello`, Sprung 0, Flag `d`, Version und Kern-API).

## 8. Regeln für Module (KarloDerBaer, 18.11.2026, ab Peon 0.24.0)

### 8.1 Wege

- **An alle:** `Peon.Comm.Send("dienst", daten)` geht einmal als Addon-Nachricht in den Kanal `PeonNet`. Alle Peon-Nutzer, die gerade online sind, bekommen sie sofort. Es gibt keine Weitergabe.
- **An einen:** `Peon.Comm.Send("dienst", daten, { to = name })` oder `info.reply(daten)` geht per Addon-Flüstern an genau diesen Spieler. Gedacht für Antworten und Nachholen.
- Beim Empfänger sagt `info.via`, woher die Nachricht kam (`c` Kanal, `w` Flüstern), `info.origin` ist der Prüfwert des Urhebers.
- Wer offline war, bekommt Rundsendungen nicht nachgeliefert. Braucht ein Dienst das, holt er es selbst nach (8.3).
- Nachrichten von Peon 0.23.0 (Flüstern mit Weitergabe) versteht der Kern weiter und gibt sie weiter.

### 8.2 Sparsam senden

- Alle Dienste teilen sich einen Takt: höchstens eine Nachricht je 1,25 Sekunden für alles zusammen, nie im Kampf und nicht in Instanzen. Was wartet, bleibt in der Warteschlange (höchstens 150).
- Eine Nachricht hat höchstens 255 Zeichen. Größere Daten teilt der Kern in bis zu 8 Teile, mehr lehnt `Send` ab (Rückgabe 0).
- Nur Neues senden, nie den ganzen Bestand. Mehrere neue Einträge sammeln und gemeinsam schicken, etwa alle paar Minuten oder beim Verlassen eines Gebiets.
- Als Richtwert je Dienst: höchstens eine Rundsendung pro Minute.

### 8.3 Nachholen beim Einloggen

- Ein Dienst, der Bestand austauscht, schickt nach dem Einloggen einmal einen kurzen Stand an alle (z. B. Zahl der Einträge oder Zeitpunkt des neuesten).
- Wer deutlich mehr oder Neueres hat, antwortet per `info.reply` mit einem Teil davon, höchstens einmal je Urheber in 10 Minuten.
- Antworten lösen keine weitere Antwort aus. So entsteht keine Lawine, wenn viele online sind.

### 8.4 Daten

- Nur Tabellen, Texte, Zahlen und Wahrheitswerte. Der Kern packt sie ohne Lua-Code.
- Jede Nachricht trägt die Version des Dienstes (`v`). Einträge, die ein Modul nicht versteht, überspringt es ohne Fehler.
- Geheime Werte vorher mit `Peon.IsSecret` prüfen.
- Daten aus dem Netz sind fremd und ungeprüft: Grenzen und Plausibilität prüfen (Karte, Koordinaten 0 bis 1, Längen von Texten, Anzahl der Einträge).

### 8.5 Fremde Daten speichern und zeigen

- Getrennt von den eigenen Daten speichern, mit Obergrenze und Alter (alte Einträge fallen weg).
- Je Eintrag höchstens 5 Prüfwerte der Melder merken. Fremde Daten erscheinen sofort, aber als fremd erkennbar (anders gefärbt), bis zwei verschiedene Spieler sie melden oder man es selbst bestätigt.
- Charakternamen werden grundsätzlich nicht gespeichert. Ausnahmen entscheidet KarloDerBaer je Dienst. Die erste ist „Rezepte der Freunde“ (8.7).

### 8.6 Ablauf für einen neuen Dienst

1. Dienst im Konzept des Moduls beschreiben: Name (höchstens 12 Zeichen), Daten, wann gesendet wird, wie gespeichert und angezeigt wird. Mit KarloDerBaer abstimmen.
2. `Peon.Comm.Register` nur, wenn `Peon.API >= 23` und `Peon.Comm` da ist. Ohne Kern-Austausch läuft das Modul normal weiter.
3. Tests mit nachgebautem `Peon.Comm` im Modultest. Der Netzaufbau aus `tests/test_comm.lua` dient als Vorbild.
4. Im Spiel mit Peon_Debug ansehen, was gesendet wird.

### 8.7 Erster Dienst: Rezepte der Freunde (KarloDerBaer, 18.11.2026)

Der Codex von Peon_Profession zeigt, welche Rezepte andere Peon-Nutzer kennen. Anlass: Blizzards Berufslinks lassen sich in Forever derzeit nicht beim anderen öffnen (Fehler im Spiel seit 8.11.2026). Dafür braucht die Anzeige Namen, das ist die erste Ausnahme von 8.5. Geklärt mit KarloDerBaer und gebaut in Profession 0.6.0: nur Freunde und Gilde, nur der eingeloggte Charakter, 30 Tage, Anzeige in Spalte und Tooltip. Ablauf im Codex-Konzept `docs/konzepte/profession/Peon_Profession_Codex.md`, Abschnitt 8. Den Namen des Absenders liefert der Kern ab API 24 als `info.name`.
