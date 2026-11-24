# Peon_Broker: Verlauf der Versionen

Neueste Version oben. Den aktuellen Stand (Dateien, Einstellungen, Befehle) zeigt `docs/projekt/Peon_Stand.md`. Übernommen aus dem bisherigen `Peon_Stand.md` am 31.10.2026, Notizen zu Tests stehen bei der Version, zu der sie gehören.

## 0.131.0

Kurz: Kaufen bis und Limit pro Kauf im Schnellkauf bleiben gespeichert. Vorher konnte Broker sie beim Öffnen des Fokus durch die Vorgabe ersetzen.
Kurz: Im Diagramm des Schnellkaufs bestimmt der Preis die Auflösung. Kurze Angebote mit großen Mengen machen das Diagramm nicht mehr unlesbar.
Kurz: Der Markttausch schlägt keine angelegten oder seelengebundenen Gegenstände mehr vor.
Kurz: Beim Überfahren eines Gegenstands zeigt Broker überall denselben Tooltip mit Preisen, darunter die Angaben der jeweiligen Liste.

- 0.131.0 (25.11.2026, Fehlermeldungen vom 24.11.2026, KarloDerBaer):
  - **Behoben, Kaufen bis nicht zuverlässig gespeichert:** Die Werte aus Beobachten kamen nur beim Sprung aus Beobachten in den Fokus. Öffnete man den Reiter direkt (auch nach `/reload`) oder kam aus Chancen, setzte der Schnellkauf seine Vorgaben (Kaufen bis die Hälfte des günstigsten, Limit pro Kauf 5 Gold). Beim Verlassen speicherte das automatische Speichern diese Vorgaben über die eigenen Werte. Der Knopf Auto war nicht die Ursache, er ändert Kaufen bis nur per Klick. Jetzt lädt der Schnellkauf die gespeicherten Werte einmal je Gegenstand, bevor er Vorgaben setzt (`F.EnsureLoaded`), und speichert nie Werte, die er nicht geladen hat.
  - **Behoben, Diagramm im Schnellkauf:** Die Menge richtet ihre Achse nach 90 % der Werte. Einzelne große Mengen stauchen die übrigen Balken nicht mehr, sie enden am Rand mit hellem Abschluss. Kaufen bis bestimmt den Bereich der Preisachse nicht mehr mit, liegt es außerhalb, steht es gestrichelt am Rand (Kern API 28).
  - **Behoben, Markttausch:** Der Hinweis am Zielhaus und der Zustand „im Gepäck“ zählen nur ungebundene Stücke in den Taschen. Das Spiel zählt Angelegtes mit, so kam ein getragenes, seelengebundenes Stirnband in den Hinweis.
  - **Geändert, Tooltip:** Ein Weg für jeden Gegenstand (`W.ShowItemTooltip` mit Zusatzzeilen). Abweichend waren Beobachten/Schnellkauf, Chancen (Aufkauf und Spekulation sowie Schnellkauf), dort stand nur eigener Text ohne die Preise. Markttausch, Pakete und Neutral verloren ihre Zusatzzeilen beim Drücken von Umschalt, jetzt bleiben sie.
  - Tests: Werte nach direktem Öffnen und aus Chancen geladen, nichts Ungeladenes gespeichert (`test_broker.lua`), Gebundenes nie als Ware, gemeinsamer Tooltip ohne alten Zusatz (`test_broker.lua`), Achsen mit `trim` und `fit` (`test_chart.lua`).

## 0.130.3

Kurz: Kommt nach einem Klick auf Kaufen kein Preis vom Spiel, hängt der Schnellkauf nicht mehr 20 Sekunden lang. Nach höchstens 3 Sekunden fragt Broker wieder ab und du kannst erneut klicken.

- 0.130.3 (22.11.2026, Kaufprotokoll KarloDerBaer):
  - **Behoben, keine Abfragen nach einem Kaufversuch:** Im Protokoll (14:36 Uhr) war die Bremse des Spiels beim Klick belegt. Das Spiel stellte den Start des Kaufs in die Warteschlange und verwarf ihn dort (`AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED`). Ein Preis kam nie, der Kauf wartete 20 Sek. auf ihn, und so lange liefen weder Abfragen noch Klicks. Jetzt gilt ein verworfener Start sofort als fehlgeschlagen (im Protokoll `dropped quote`), der Fokus fragt gleich neu ab.
  - **Geändert, Wartezeit auf den Preis:** höchstens 3 Sek. (`R.QUOTE_WAIT`), sonst kommt er nach 0,15 bis 1,2 Sek. Mit dem Preis gelten für Bestätigung und Ergebnis wieder 20 Sek.
  - Tests: Wartezeiten, verworfener Start ohne Preis beendet den Kauf, nach dem Preis bleibt er (`test_broker.lua`).

## 0.130.2

Kurz: Nach einem fehlgeschlagenen Kauf im Schnellkauf zeigt der Fokus keine längst verkauften Angebote mehr. Der Kaufknopf wird erst wieder frei, wenn die Liste wirklich neu ist.

- 0.130.2 (21.11.2026, Kaufprotokoll KarloDerBaer):
  - **Behoben, alte Liste nach einem Fehlschlag:** Das Spiel beantwortet das „Neu laden“ direkt nach einem fehlgeschlagenen Kauf mit Code 10. Der Fokus wartete dann 1 Sek. und schaltete auf die Suche um. Die Suche lieferte die alte Liste mit den schon verkauften billigen Angeboten, der Kaufknopf wurde frei und der nächste Klick war zu teuer. Das betraf mindestens 6 von 11 „zu teuer“ im Protokoll. Jetzt beendet eine Meldung des Auktionshauses die laufende Abfrage des Fokus sofort, der Fokus bleibt bei „Neu laden“ (im Protokoll `focus retry`).
  - Auswertung des fünften Kaufprotokolls (21:05 bis 21:13 Uhr, Seidenstoff): 9 bestätigte Käufe, alle fehlgeschlagen. Vom Erscheinen des Angebots bis zum Klick 0,05 bis 0,6 Sek. Nach dem Preis des Spiels (0,15 Sek.) wartet die Bestätigung etwa 0,5 Sek. auf die Bremse des Spiels, die Absage kommt 0,2 Sek. später. In dieser Zeit waren die Angebote weg. Ob gekauft oder zurückgezogen, meldet das Spiel gleich.
  - Tests: Meldung beendet die Abfrage des Fokus, nächste Abfrage wieder mit Neu laden, Prüfung vor einem Kauf unverändert (`test_broker.lua`).

## 0.130.1

Kurz: Kein kurzes Ruckeln mehr, wenn du den Tooltip einer Kiste mit Paketliste öffnest.

- 0.130.1 (20.11.2026, Fehlermeldung KarloDerBaer, „Abgefangene Kiste: Stoffe des Experten“):
  - **Behoben, Ruckeln bei Kisten:** Der Paketvergleich baute sein Namensverzeichnis aus allen gespeicherten Gegenständen spätestens jede Minute und nach jedem Scan neu, und zwar beim Zeigen der Kiste. Mit echten Daten waren das 57.500 Einträge und etwa 190 ms (Lua 5.1 auf dem PC). Der übrige Tooltip brauchte unter 0,1 ms.
  - Jetzt nur Gegenstände mit Nummer (Varianten tragen seit 0.130.0 den vollen Namen und passen nie zu einer Paketliste), echte Daten 8.900 Einträge und 32 ms. Neu gebaut wird nur bei neuen Preisdaten (`P.Sig`: Scan oder Stand vom Manager in einem Markt), nicht mehr nach Zeit (`INDEX_AGE` entfällt).
  - Aufbau im Hintergrund nach dem Anmelden (5 Sek. danach) und nach jedem Scan, je Bild 1.000 Einträge (`P.Prepare`, `P.STEP`, gemessen etwa 3 ms je Schritt). Wird eine Kiste gezeigt, bevor er fertig ist, baut Broker das Verzeichnis sofort ganz.
  - Tests: Varianten nicht im Verzeichnis, kein Neuaufbau ohne neue Daten, Neuaufbau nach Scan, Aufbau in Schritten (`test_broker.lua`).

## 0.130.0

Kurz: Broker speichert seine Preisdaten jetzt viel kompakter. So bleibt die Datei sicher unter der Grenze, ab der das Spiel sie nicht mehr lädt. Im Spiel ändert sich nichts.
Kurz: Fehlen beim Start die Preisdaten, obwohl beim letzten Mal viele da waren, sagt Broker Bescheid und nennt die Sicherung im Peon Manager.

- 0.130.0 (20.11.2026, Auftrag KarloDerBaer nach der nicht mehr ladbaren Datei vom selben Tag):
  - **Messung** mit der echten, reparierten Datei: 230.868 verschiedene Werte (Grenze etwa 262.000). Jeder Text zählt als ein Wert, egal wie lang. Fast alles waren die Texte je Gegenstand: Tageswerte `d` 42.800, Name `nm` 40.200, Schlüssel 38.900, Link `lk` 36.300, Absatz `ab` 29.100, `ss` 18.600. Drei Viertel der Gegenstände sind Varianten (Ausrüstung mit Zusatz). Tageswerte kürzen, Wochenwerte weglassen oder runden hätte fast nichts gespart.
  - **Neu, Speicherform** (`Store.lua`): Beim Abmelden und vor `/reload` kommen alle Texte eines Gegenstands in einen Text `e.x`, beim Laden (Migration) werden sie wieder getrennt. Zahlen bleiben eigene Felder. Mit der echten Datei 108.050 Werte statt 230.868, Hin- und Rückweg ohne Abweichung, Packen etwa 0,6 Sek., Entpacken etwa 0,3 Sek. (Lua 5.1 auf dem PC).
  - **Geändert:** Varianten speichern keinen Namen mehr, er steht im Schlüssel. Nach dem Laden ist `nm` der volle Name der Variante.
  - **Geändert:** Varianten ohne Angebot seit 7 Tagen fallen beim Abmelden weg (`Store.VARIANT_DAYS`), die Langzeitwerte hat der Peon Manager.
  - **Neu, Warnungen:** Beim Packen schätzt Broker die Zahl der Werte (`svEst`), ab 180.000 kommt beim Laden ein Hinweis im Chat. Je Charakter merkt er sich die Zahl der Gegenstände (`PeonBrokerCharDB.svItems`). Startet Broker leer, obwohl dort mindestens 1.000 standen, nennt ein Hinweis die Spielsicherung im Manager.
  - Braucht Peon Manager 0.53.1, ältere Manager lesen den Verlauf aus der Datei nicht mehr (Langzeitwerte aus der Blizzard-API und eigenen Ständen bleiben).
  - Tests: Packen und Entpacken, Name aus dem Schlüssel, ungeeignete Werte bleiben ungepackt, Abmelden und Laden, alte Varianten entfernt, beide Hinweise (`test_broker.lua`).

## 0.129.0

Kurz: Neuer Unterreiter Pakete in Chancen (mit eingeschaltetem Markttausch): kleine, gestreute Angebote vom Peon Manager mit Knopf Kaufen am einen und Verkaufen am anderen Haus, beide mit Prüfung des Live-Preises.
Kurz: Liefert das Spiel keinen Realm-Namen, zeigt Broker trotzdem deine Daten. Was in dieser Zeit unter „?“ gespeichert wurde, kommt zu deinem Markt.

- 0.129.0 (20.11.2026, Wunsch und Fehlermeldung KarloDerBaer, Konzept `Peon_Broker_Pakete.md`):
  - **Neu, Unterreiter Pakete** (`Packages.lua`): Angebote beider Pakete mit Richtung, Menge, Kaufen bis, Verkaufen ab, Zustand und Spalte Aktion. Gekauft liest Broker aus Ledger (`mod:HouseLots`), eingestellt aus den eigenen Auktionen. Laufende Abfrage der Zeilen für das Haus hier, „Alle prüfen“ (Radar, Auswahl `pkgcheck`).
  - **Neu, Kaufen** (Spalte Aktion am Haus der Quelle): genau die fehlende Menge, nur Preisstufen bis Kaufen bis, ein Klick (`R.BuyStep` Art `pkg`, bestätigt selbst wie der Fokus). Grau mit Hinweis, wenn der Live-Preis darüber liegt.
  - **Neu, Verkaufen** (am Haus des Ziels): 1 Kupfer unter dem günstigsten Angebot, nie unter Verkaufen ab. Liegt die Konkurrenz darunter, warnt der erste Klick, der zweite verkauft. Massenware stellt Broker selbst ein (`PostCommodity`), Einzelstücke legt der sichere Knopf unter der Liste ins Verkaufsfenster und trägt den Preis ein.
  - **Behoben, leerer Realm-Name:** Markt mit Rückfall aus dem Kern (API 27). Märkte und Speicher je Markt unter „? / Fraktion“ wandern beim Anmelden zum echten Markt (fehlende Gegenstände dazu, vorhandene bleiben), danach fällt „?“ weg.
  - Tests: Pakete mit Kaufen, Verkaufen, Warnung und Zustand aus Ledger, Zusammenführen der Märkte (`test_broker.lua`).

## 0.128.2

Kurz: Markttausch ist ab Werk aus. Chancen und Beobachten zeigen ihn erst, wenn du ihn in den Einstellungen der Chancen einschaltest. Mehr, Neutral bleibt immer da.

- 0.128.2 (20.11.2026, Wunsch KarloDerBaer): neue Einstellung `tradeOn` (Vorgabe aus) statt `chancesShowT` (Vorgabe an). Aus: kein Unterreiter Markttausch in Chancen und Beobachten, kein Haken „Beobachten: Markttausch“ im Menü, kein Hinweis am Zielhaus, keine laufende Abfrage.
  - Tests: ab Werk aus, Beobachten fällt auf Aufkauf zurück, kein Haken im Menü (`test_broker.lua`).

## 0.128.1

Kurz: Der Hinweis am Auktionshaus auf Ware aus dem Markttausch kennt jetzt alles, was du im anderen Haus gekauft hast, auch ohne Klick in der Liste Markttausch. Dafür braucht es Peon_Ledger 0.17.

- 0.128.1 (20.11.2026): `Trade.lua` nimmt die Ware für das andere Haus aus Peon_Ledger (`mod:HouseLots`, Posten mit Haus des Kaufs). Die Merker aus dem Markttausch (`tradeGoods`) bleiben für Käufe, die Ledger noch keinem Haus zuordnen kann.

## 0.128.0

Kurz: Markttausch zeigt nur noch die Auswahl des Peon Managers und hält die Preise am Auktionshaus aktuell. Passt eine Chance mit neuen Preisen nicht mehr, verschwindet sie bis zum nächsten Stand des Managers.
Kurz: Beobachten hat einen dritten Unterreiter Markttausch, und die Werte des Schnellkaufs werden jetzt mit dem Peon Manager abgeglichen.

- 0.128.0 (20.11.2026, Wunsch KarloDerBaer, Konzept `Peon_Broker_Marktvergleich.md` Abschnitt 10):
  - **Geändert, Markttausch nur mit Auswahl des Managers** (`Trade.lua`): Ohne Daten vom Manager steht ein Hinweis da, die Liste nach Preisunterschied entfällt.
  - **Neu, Entfernen nach neuen Preisen** (`T.Recheck`, `PeonBrokerDB.tradeGone[Heimatmarkt]`): Preise, die neuer sind als der Stand des Managers (Live-Abfrage, Komplettscan, Manager), prüfen Spanne und Gewinn je Stück nach dem Anteil des Zielhauses gegen die Grenzen des Managers. Entfernte kommen erst mit einem neueren Stand wieder. Broker fügt nie etwas hinzu.
  - **Neu, laufende Abfrage** (`T.NextKey`, Radar Art `trade`): Solange die Liste offen ist, fragt Broker ihre Zeilen für das Haus hier reihum ab.
  - **Neu, Beobachten, Unterreiter Markttausch** (`WatchPage.lua`, `Watch.lua` `ton`): Richtung, beide Preise, Spanne nach Gebühr, Absatz im Ziel und Zustand am Haus hier, nur beobachten. Haken „Beobachten: Markttausch“ im Gegenstandsmenü, auch für Ausrüstung.
  - **Geändert, Abgleich mit dem Manager:** Werte des Schnellkaufs (`qlim`, `qgold`, `qskip`, `qavg`, Zeit `t.q`) und Haken der Listen (`bon`, `qon`, `ton`, Zeit `t.lists`) gehen je Gruppe mit eigener Zeit in beide Richtungen. `qmax` und `mode` bleiben im Spiel.
  - Tests: Entfernen und Wiederkommen, ohne Manager, laufende Abfrage, Liste Markttausch in Beobachten, Zeiten und Abgleich (`test_broker.lua`).

## 0.127.0

Kurz: Neuer Unterreiter Markttausch in Chancen: im eigenen Haus kaufen und im neutralen verkaufen oder umgekehrt. Die Liste kommt vom Peon Manager, ohne ihn zeigt Broker die Preisunterschiede.
Kurz: Mehr, Neutral hat jetzt eine Suche und zeigt den Absatz in beiden Häusern.

- 0.127.0 (20.11.2026, Wunsch KarloDerBaer, Konzept `Peon_Broker_Marktvergleich.md`):
  - **Neu, Suche in Mehr, Neutral** (`Pages.lua`, `G.CompareRows(minPct, onlyStock, search)`): Mit Suchtext gilt der Mindestunterschied nicht, Gegenstände aus nur einem Haus stehen mit „fehlt“ da.
  - **Neu, Absatz je Tag in beiden Häusern** (`G.SalesPerDay`, über `bridge:Sales`), Tooltip mit Preis, Anteil und Absatz je Haus und dem Satz des Managers.
  - **Geändert, Unterschied je Richtung:** im einen Haus zum Preis kaufen, im anderen nach dem Anteil verkaufen (`G.Spread`). Vorher beide Preise nach Gebühr. Spalte „Besser“ heißt jetzt „Richtung“.
  - **Neu, Anteil des neutralen Hauses angenommen 15 %**, solange Broker ihn nicht gemessen hat (`Cut.lua`, `C.Guess`, `C.NEUTRAL_GUESS`). Gilt nur für den Vergleich zwischen den Häusern.
  - **Neu, Unterreiter Markttausch** (`Trade.lua`, `chancesShowT`): Liste vom Manager (`bridge:Compare`) mit Richtung, Kaufen bis, Verkaufen für, Gewinn, Absatz, Menge, Ampel und Zustand. Der Zustand gilt für das Haus, an dem man steht: kaufbar oder zu teuer am Haus der Quelle, frei, unterboten oder im Gepäck am Haus des Ziels. „Alle prüfen“ fragt die Zeilen für dieses Haus einmal live ab (Radar, Auswahl `trade`). Ohne Manager eine Liste nur nach Preisunterschied ab 20 %.
  - **Neu, Gepäck für das andere Haus** (`PeonBrokerDB.tradeGoods`): Ein Klick am Haus der Quelle öffnet den Fokus mit Kaufen bis und merkt den Gegenstand. Am Zielhaus nennt ein Hinweis, was davon in den Taschen liegt (`chancesTradeNote`, abschaltbar). Verkauft oder nach 14 Tagen fällt der Eintrag weg.
  - Tests: Suche, Richtung nach Gebühr, Markttausch mit und ohne Manager, Zustände an beiden Häusern, Gepäck und Hinweis, vier Unterreiter (`test_broker.lua`).

## 0.126.0

Kurz: Beobachten, Unterreiter Schnellkauf, merkt sich jetzt alles über den Logout hinaus. Die Bewegung steht als Ampel da (grün lebhaft, gelb mäßig, rot ruhig, grau ungeprüft), blass, wenn der Wert älter als 6 Stunden ist.
Kurz: Neue Spalten Treffer (wie oft etwas bis zu deinem Kaufen bis auftauchte), Einbrüche (Anzahl im Zeitraum) und Tief 24 Std. Die Spalte Rat ist weg. Gekauft steht im Tooltip über den ganzen Zeitraum.

- 0.126.0 (20.11.2026, Wunsch KarloDerBaer):
  - **Neu, Bewegung gespeichert** (`QuickChances.lua`, `QC.Save`, `QC.Load`): Die letzten 3 Prüfungen je Gegenstand stehen in `PeonBrokerDB.quickMove[Markt]`. Nach Logout oder `/reload` zeigt die Liste den letzten Stand, gespeicherte Gegenstände sind sofort wieder dran. Ab 6 Std. gilt der Wert als alt (`QC.OLD`, `v.old`), der Tooltip nennt die letzte Prüfung. Gilt auch für Chancen.
  - **Geändert, Bewegung als Ampel** (`QC.Light`): farbiger Punkt statt Wort, vorläufig oder alt blass.
  - **Neu, Treffer** (`QuickStats.lua`, Feld `h`): ein fremdes Angebot taucht bis Kaufen bis des Schnellkaufs auf, vorher stand dort keins. Gezählt in allen Prüfungen und im Fokus.
  - **Neu, Tief 24 Std.** (`QS.Low24`, Feld `lo` je Stunde): niedrigster Preis aus Stufen mit mindestens 2 Stück, grün bis Kaufen bis.
  - **Geändert, Einbrüche als Anzahl** im Zeitraum statt je Stunde, sichtbar ab der ersten Beobachtung. Je Stunde steht im Tooltip. In Chancen bleibt die Spalte Einbr./Std.
  - **Neu, Gekauft gespeichert** (`QS.OnBought`, Felder `k` und `c`): Menge und Durchschnitt im Zeitraum im Tooltip statt nur für die Sitzung.
  - **Geändert, Zeitraum** (`quickStatDays`): Vorgabe 7 statt 14 Tage. Ein schon gespeicherter Wert bleibt.
  - **Entfernt, Spalte Rat** im Unterreiter Schnellkauf. Die Zahl am Reiter und das Aufleuchten zählen weiter.
  - Tests: Treffer, Tiefstpreis 24 Std., Gekauft, gespeicherte und alte Bewegung, Spalten (`test_broker.lua`).

## 0.125.1

Kurz: Der Aufkauf kauft wieder alles unter dem Ziel. Das automatische Kaufen bis des Schnellkaufs blieb beim Wechsel in den Aufkauf stehen, oft unter dem günstigsten Angebot, und dann wurde nichts gekauft.

- 0.125.1 (20.11.2026, Fehler gemeldet von KarloDerBaer):
  - **Behoben, Werte je Modus** (`Quick.SetMode`): Beim Wechsel zwischen Schnellkauf und Aufkauf werden eigenes Ziel, Kaufen bis, Menge und Limit pro Kauf geleert, danach lädt der Modus seine Werte aus Beobachten. Vorher blieb das Kaufen bis, das der Schnellkauf selbst einträgt (Hälfte des günstigsten Angebots, mindestens Händlerpreis), im Aufkauf stehen. Betroffen war vor allem der Sprung aus Chancen (Aufkauf), wenn der Fokus vorher im Schnellkauf stand: „Keine Chance“, obwohl genug unter dem Ziel stand.
  - Tests: aus Chancen ohne Kaufen bis des Schnellkaufs, Umschalten per Knopf (`test_broker.lua`).

## 0.125.0

Kurz: Der Knopf „Auto“ im Schnellkauf reagiert jetzt auch auf Einbrüche, also billige Angebote mit mehreren Stück. Statt der Zeile „Letztes“ zeigt der Fokus den tiefsten Einbruch dieser Sitzung und wie viele es waren.
Kurz: Hinter „Gekauft“ steht der Durchschnittspreis, unter dem Kaufknopf der letzte Kauf mit Menge und Durchschnittspreis.

- 0.125.0 (20.11.2026, Wunsch KarloDerBaer nach dem fünften Kaufprotokoll):
  - **Neu, Einbrüche im Fokus** (`Quick.AddDip`): `QuickStats.OnPair` gibt den Einbruch und den Tiefstpreis davor zurück, `Quick.OnSample` merkt ihn in der Bilanz der Sitzung (`dips`, `dipLow`, `lastDip`). Regel wie bei Langfristig.
  - **Geändert, Auto auch für Einbrüche** (`Quick.AutoLimit`): Es gilt das jüngere von letztem fremden Lockangebot und letztem Einbruch. Regulär ist beim Einbruch die günstigste Stufe ab 2 Stück mindestens `quickDipPct` Prozent darüber, sonst der Tiefstpreis davor. Neuer Rückgabewert `kind` („bait“ oder „dip“), der Tooltip nennt den Einbruch.
  - **Geändert, Zeile Einbruch statt Letztes** (`Quick.DipText`): tiefster Einbruch dieser Sitzung und Anzahl in Klammern, der letzte im Tooltip. Das letzte Lockangebot steht jetzt im Tooltip der Zeile Lockangebote.
  - **Neu, Durchschnitt hinter Gekauft** (`Quick.BoughtText`) und **letzter Kauf unter dem Kaufknopf** (`Quick.LastBuyText`, Menge, Durchschnittspreis, wie lange her). Der Kaufknopf steht im Schnellkauf dafür etwas höher (`F.QUICK_BUY_Y`).
  - Tests: Einbruch gemerkt, Auto über Einbruch mit Stufe knapp darüber, Leuchten auf Kaufen bis, Zeile und Tooltip, jüngeres Lockangebot geht vor, letzter Kauf und Durchschnitt. Ältere Tests auf die neue Zeile angepasst (`test_broker.lua`).

## 0.124.0

Kurz: Die Zeile „Langfristig“ im Schnellkauf zählt jetzt einfach mit, zum Beispiel „29 Einbrüche, 6 Lockangebote (3 Min.)“, statt auf eine Stunde hochzurechnen. Als Einbruch zählt nur noch ein echtes neues Tief, nicht mehr das Wiedereinstellen nach einem Auskauf.

- 0.124.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Geändert, Einbruch nur bei echtem Tief** (`QuickStats.OnPair`, `QuickStats.Dip`): Verglichen wird mit dem Tiefstpreis der letzten 60 Sekunden (`QS.LOW_SEC`), nicht mehr nur mit der vorigen Abfrage. Tiefstpreis ist die günstigste fremde Stufe ab 2 Stück (`QuickStats.Low`), einzelne Lockangebote verschieben ihn nicht. Vorher zählte in lebhaften Märkten jedes Wiedereinstellen zum alten Preis nach einem Auskauf.
  - **Geändert, einfach gezählt** (`QuickStats.Get`): ohne Gewichtung der Tage. Einbrüche liegen im neuen Feld `e`, die nach alter Regel gezählten (`d`) werden nicht mehr gelesen.
  - **Geändert, Anzeige:** Im Fokus Anzahl mit beobachteter Zeit statt Werte je Stunde, kurzer Tooltip (Regel, Nachahmer, Zeitraum). In den Tooltips von Chancen und Beobachten ebenso. Die Spalte Einbr./Std. zeigt einen Wert erst ab 30 Min. Beobachtung.
  - Tests: Wiedereinstellen nach Auskauf ist kein Einbruch, echtes Tief schon, Lockangebot senkt das Tief nicht, Tief gilt eine Minute, Zählung ohne Gewichtung, Anzeige (`test_broker.lua`).

## 0.123.0

Kurz: Der Knopf „Auto“ im Schnellkauf hebt Kaufen bis jetzt auch an, wenn die Lockangebote über deinem Kaufen bis liegen. Er leuchtet, sobald das letzte Lockangebot bei oder über deinem Kaufen bis liegt.

- 0.123.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Geändert, Lockangebote auch über Kaufen bis erkannt** (`Quick.OnSample`): Fremde Lockangebote über Kaufen bis kommen mit dem Merker `above` in `Q.baits`. Gemeldet wird weiter nur bis Kaufen bis: Zeile Lockangebote (`Q.BaitStats`), Nachahmer und Ton zählen sie nicht. Im Kaufprotokoll heißen sie `bait above`.
  - **Geändert, Auto hebt an** (`Quick.AutoLimit`): Das letzte fremde Lockangebot zählt auch über Kaufen bis. Neuer Rückgabewert `high`, wenn es bei oder über Kaufen bis liegt. Dann leuchtet der Knopf (`LockHighlight`), der Tooltip sagt es in Orange.
  - Tests: Erkennung über Kaufen bis ohne Ton und ohne Zeile, Auto hebt an, Leuchten vor und nach dem Klick, Leuchten genau auf dem Lockpreis. Test aus 0.110 angepasst (`test_broker.lua`).

## 0.122.0

Kurz: Neue langfristige Kennzahl im Schnellkauf: Broker zählt über Tage, wie oft bei einer Ware ein Angebot deutlich unter den günstigsten Preis fällt (Einbrüche je Stunde). Zu sehen im Fokus, in den Chancen und in Beobachten.

- 0.122.0 (19.11.2026, Wunsch KarloDerBaer, Abstimmung im Konzept `docs/konzepte/broker/Peon_Broker_Chancen_Schnellkauf.md` Abschnitt 7):
  - **Neu, Gelegenheiten langfristig** (`QuickStats.lua`): Einbruch heißt neues fremdes Angebot mit mindestens 2 Stück, mindestens `quickDipPct` Prozent (Vorgabe 5) unter dem bisher günstigsten. Höchstens einer je Abfrage, unabhängig von Kaufen bis. Dazu fremde Lockangebote (Regel wie im Fokus) und Lockangebote mit Nachahmern (nur im Fokus erkennbar). Gezählt wird bei jeder Beobachtung einer Massenware, im Fokus (`Quick.OnSample`) und in den Prüfungen der Chancen und von Beobachten (`QuickChances.OnAnswer`). Die beobachtete Zeit zählt je Abstand höchstens 10 Sekunden.
  - **Speicher** `PeonBrokerDB.quickStats[Markt][Schlüssel][Tag]` mit Zeit, Einbrüchen, Lockangeboten und Nachahmern. Gezählt über `quickStatDays` Tage (Vorgabe 14), ältere Tage mit weniger Gewicht. Unter 30 Minuten Beobachtung ist der Wert vorläufig (grau).
  - **Anzeige:** Im Fokus neue Zeile „Langfristig“ im Verlauf (Einbrüche und Lockangebote je Std., beobachtete Zeit, Einzelheiten im Tooltip), die Zeilen rücken dafür etwas enger. In den Chancen im Unterreiter Schnellkauf Spalte „Einbr./Std.“. Bei gleicher Bewegung stehen Vorschläge mit mehr Einbrüchen weiter oben. In Beobachten im Unterreiter Schnellkauf ersetzt die Spalte „Einbr./Std.“ die Spalte Gekauft, gekaufte Stück stehen im Tooltip. Beide Tooltips zeigen die langfristigen Werte.
  - **Einstellungen** im Fenster Einstellungen des Fokus unter „Gelegenheiten (langfristig)“: Einbruch ab (Prozent) und Zeitraum (Tage).
  - Tests: Einbruch, Lockangebot ist kein Einbruch, Zeit mit Obergrenze, Gewichtung und Aufräumen alter Tage, nur Massenware, Anzeige (`test_broker.lua`). Ältere Tests auf die neuen Spalten angepasst.

## 0.121.0

Kurz: Im Schnellkauf setzt der neue Knopf „Auto“ neben Kaufen bis den Preis auf die Mitte zwischen dem letzten fremden Lockangebot und dem nächsten regulären Angebot. So reagierst du schnell, wenn die Lockangebote zu einem neuen Preis wandern.

- 0.121.0 (19.11.2026, Wunsch KarloDerBaer nach dem vierten Kaufprotokoll):
  - **Neu, Knopf Auto hinter Kaufen bis im Schnellkauf** (`Quick.AutoLimit`): Mitte zwischen dem letzten fremden Lockangebot und dem günstigsten regulären Angebot darüber, abgerundet. Regulär ist eine fremde Stufe über dem Lockpreis mit mindestens 2 Stück in der letzten Abfrage, ohne Abfrage der günstigste Preis bei der Erkennung (neues Feld `reg` in `Q.baits`). Eigene Lockangebote zählen nicht. Grau, solange kein fremdes Lockangebot erkannt ist oder kein Abstand besteht. Der Tooltip zeigt Lockpreis, regulären Preis und den neuen Wert. Ein Klick setzt Kaufen bis einmalig, der Wert folgt danach nicht von selbst.
  - Anlass: Im Protokoll (19:50 bis 19:53 Uhr) gelang mit Kaufen bis genau auf dem Lockpreis 1 von 9 Klicks, mit Kaufen bis zwischen Lockpreis und regulärem Preis 10 von 18. Bezahlt wurde in beiden Fällen meist der Lockpreis.
  - Tests: Vorschlag, eigene Lockangebote, regulär erst ab 2 Stück, Rückfall ohne Abfrage, kein Abstand, Knopf grau und Klick (`test_broker.lua`).

## 0.120.0

Kurz: Im Unterreiter Aufkauf der Chancen stehen keine Spekulationen mehr. Die Spalte Art entfällt, die Art steht im Tooltip.
Kurz: Beim Verkaufen gilt der Schutz vor Lockangeboten nur noch für Massenware.
Kurz: Die Marktbewegung im Schnellkauf zählt nur noch, was nahe am günstigsten Preis passiert, und Preissprünge erst ab 2 %. Große Märkte sind dadurch nicht mehr automatisch lebhaft.
Kurz: Schnellkauf ohne eigene Werte: Kaufen bis ist die Hälfte des günstigsten Angebots (mindestens der Händlerpreis), Limit pro Kauf 5 Gold. Beides ist einstellbar.
Kurz: Ruhige Vorschläge im Schnellkauf werden seltener geprüft, lebhafte sofort wieder. Im Rechtsklick-Menü lässt sich „Beobachten: Aufkauf“ und „Beobachten: Schnellkauf“ einzeln anhaken.

- 0.120.0 (19.11.2026, Rückmeldung KarloDerBaer zu 0.119.0):
  - **Behoben:** Im Unterreiter Aufkauf der Chancen standen auch Spekulationen. `R.Refresh` füllte die Liste nach jeder Antwort des Radars mit allen Zeilen, jetzt nur mit denen des offenen Unterreiters (`C.TabRows`).
  - **Behoben:** Der Schutz vor Lockangeboten im Verkaufen griff auch bei Einzelgegenständen (z. B. ein Ring, 1 Stück knapp unter 2 Stück, hieß „Lockangebot nicht beachtet“). Er gilt jetzt nur bei Massenware (`Advice.Bait`), der Hinweis in den Optionen sagt das.
  - **Entfernt:** Spalte Art in den Listen der Chancen. Die Art steht im Tooltip (Chancen des Managers wie bisher, Treffer des Radars mit neuer erster Zeile in `R.TipLines`).
  - **Geändert, Kaufen bis im Schnellkauf ohne eigenen Wert** (`Quick.DefaultLimit`): `quickLimitPct` Prozent (Vorgabe 50) des günstigsten fremden Angebots, mindestens der Händlerpreis. Ein einzelnes Stück ganz unten zählt nicht, wenn es darüber weitere Angebote gibt (Lockangebot). Bis 0.119 kam der Wert aus dem Aufkauf. Gilt im Fokus (`Quick.EnsureLimit`), bei „Für Schnellkauf beobachten“ und beim Haken „Beobachten: Schnellkauf“ (bis 0.119 dort der günstigste Preis).
  - **Geändert, Limit pro Kauf ohne eigenen Wert** (`Quick.DefaultGold`): fester Betrag `quickGoldDefault` (Vorgabe 5 Gold) statt Preis für 100 Stück zu Kaufen bis. „Für Schnellkauf beobachten“ speicherte bis 0.119 „ohne Grenze“, jetzt ebenfalls 5 Gold. Beide Vorgaben stehen im Fenster Einstellungen des Fokus unter „Schnellkauf ohne eigene Werte“, das Fenster ist dafür höher.
  - **Geändert, Prüfabstand nach Bewegung** (`QuickChances.Wait`, `QC.DueIn`): Lebhafte und ungeprüfte kommen sofort wieder dran. Die anderen warten gleitend nach ihrem Anteil an der Grenze für lebhaft, höchstens `qcWaitMax` Minuten (Vorgabe 10, Einstellungen der Chancen), mindestens 30 Sekunden. Vorläufige Ergebnisse warten halb so lange. Die Zeile zeigt „vor 2 Min., wieder in 3 Min.“.
  - **Neu, Haken im Gegenstandsmenü:** Bei Massenware „Beobachten: Aufkauf“ und „Beobachten: Schnellkauf“ (`Watch.SetBuyoutOn`, `Watch.SetQuickOn`, Merker `bon` und `qon` nur im Spiel). Beide aus beendet die Beobachtung, Werte der abgewählten Liste bleiben gespeichert. Preisgrenze und Zielpreis stehen nur, wenn der Gegenstand im Aufkauf steht. Der Knopf „Für Schnellkauf beobachten“ entfällt, andere Gegenstände behalten den einen Haken „Beobachten“.
  - **Geändert, Marktbewegung nur in der Kaufzone** (`Measure.Pair`, `Measure.Zone`, `Measure.IsJump`): Einstellungen und Käufe zählen für lebhaft, mäßig und ruhig nur bis `quickZonePct` Prozent (Vorgabe 5) über dem günstigsten fremden Angebot beider Abfragen (`zNew`, `zSold`). Ein Preissprung zählt erst ab `quickJumpPct` Prozent Änderung (Vorgabe 2), Wackeln um 1 Kupfer nicht mehr. Zufluss und Abfluss im Verlauf gelten weiter für den ganzen Markt. Gilt im Fokus, in den Chancen und in Beobachten. Beide Werte stehen in den Einstellungen des Fokus unter Marktbewegung, die Vorgaben ohne eigene Werte rücken dafür in die linke Spalte.
  - Tests: Filter je Unterreiter in `R.Refresh`, Kaufzone und Preissprung, Vorgaben für Kaufen bis und Limit pro Kauf, Wartezeit, Haken im Menü (`test_broker.lua`). Ältere Tests auf die neuen Vorgaben und die Liste ohne Spalte Art angepasst.

## 0.119.0

Kurz: Neue Chancen für den Schnellkauf: Broker schlägt Massenware mit viel Menge auf dem Markt vor und prüft, wie lebhaft dort gerade gehandelt wird.
Kurz: Chancen und Beobachten haben jetzt Unterreiter (Spekulation, Aufkauf, Schnellkauf), damit die Listen übersichtlich bleiben.

- 0.119.0 (19.11.2026, Wunsch KarloDerBaer, Konzept `docs/konzepte/broker/Peon_Broker_Chancen_Schnellkauf.md`):
  - **Neu, Chancen der Art Schnellkauf** (`QuickChances.lua`): Vorschläge sind die Massenwaren mit der größten Menge im jüngsten Stand des Markts (eigener Komplettscan oder Stand des Peon Managers, den `Data.ApplyManager` schon einträgt), deren günstigster Preis mindestens beim Mindestpreis liegt. Einstellbar sind Anzahl (Vorgabe 10), Mindestpreis (Vorgabe 1 Silber) und Abfragen je Prüfung (Vorgabe 5). Die Liste bleibt bis zum nächsten Stand oder bis „Neu vorschlagen“.
  - **Neu, Prüfung der Marktbewegung:** ein Gegenstand nach dem anderen, je Gegenstand mehrere Abfragen direkt hintereinander (erste als Suche, dann „Neu laden“). Gezählt werden Einstellungen, Käufe, Preissprünge und fremde Lockangebote mit denselben Regeln wie im Fokus (`Measure.Sample`, `Measure.Pair`, `Quick.NewBaits`, `Quick.MoveClass`). Bewertet wird gleitend über die letzten 3 Prüfungen, mit nur einer Prüfung vorläufig („lebhaft?“). Reihenfolge: erste Runde nach Menge, danach lebhafte, ungeprüfte, mäßige, ruhige.
  - **Neu, Fortschritt sichtbar:** die geprüfte Zeile ist hell hinterlegt und füllt Punkte, wartende zeigen „als 3. dran“, oben „Prüft 4 von 10: Name“. Die Liste sortiert erst nach einer fertigen Prüfung neu. Knopf „Prüfung anhalten“.
  - **Neu, Gegenstandsmenü:** „Nicht für Schnellkauf vorschlagen“ (`PeonBrokerDB.quickHide` je Markt, Knopf „Zurückholen“) und „Für Schnellkauf beobachten“ (Kaufen bis = günstigster Preis).
  - **Neu, Unterreiter in Chancen:** Spekulation (Spekulation, Langzeit, Muster, Knopf „Alle prüfen“), Aufkauf (Aufkauf des Managers, Händler und Aufkauf des Radars, Scan mit Auswahl), Schnellkauf. Laufend geprüft wird nur der offene, Broker merkt ihn sich (`chancesTab`). Unterreiter ohne eingeschaltete Art verschwinden. Zahlen an den Unterreitern. Der alte Reiter Radar öffnet den Unterreiter Aufkauf.
  - **Neu, Unterreiter in Beobachten:** Aufkauf (wie bisher) und Schnellkauf mit Günstigster, Kaufen bis, Glocke, Darunter, Bewegung, Gekauft und Rat. Ein Gegenstand steht in jeder Liste, für die er Werte hat. Abgefragt wird nur die offene Liste (`watchTab`), Schnellkauf mit derselben Prüfung. Doppelklick öffnet den Fokus im Modus der Liste.
  - **Geändert:** Spalte Art in Beobachten entfällt (die Unterreiter ersetzen sie). Das Fenster Einstellungen der Chancen hat einen Abschnitt Schnellkauf und ist höher.
  - Tests: Vorschläge, Prüfung, gleitende Bewertung, Reihenfolge, Pause, Ausblenden, Unterreiter, Zeilen in Beobachten, Fokus im Modus der Liste (`test_broker.lua`). Ältere Tests auf die Unterreiter angepasst.

## 0.118.0

Kurz: Intern für die Fehlersuche: Broker kann ein Kaufprotokoll an ein separates Werkzeug weitergeben. Für dich ändert sich nichts.

- 0.118.0 (19.11.2026, Wunsch KarloDerBaer nach weiteren Fehlkäufen):
  - **Neu, Anschluss für ein Kaufprotokoll:** Die Aufrufstellen von 0.110.0 bis 0.114.1 sind zurück (Abfrage, Antwort, Klick, Kaufschritte, Pause, Lockangebote). `R.Trace` gibt die Zeilen nur weiter, wenn jemand `mod.traceHook` gesetzt hat, und kehrt sonst sofort zurück. Broker speichert nichts und hat keine Einstellung dafür. Aufzeichnen tut das private Peon_Debug (ab 0.3.0, `/pdebug kauf`, Daten in `PeonDebugDB.brokerLog`), das nicht ausgeliefert wird.
  - Tests: Zeilen nur mit Anschluss, Fehler im Abnehmer stört nicht, Broker speichert nichts (`test_broker.lua`).

## 0.117.0

Kurz: Beim ersten Öffnen nach dem Update erklärt ein kurzer Hinweis den neuen Schnellkauf im Fokus.

- 0.117.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Neu, Hinweis „Der Button ist heiß“** (`broker:schnellkauf-2026-11`, `L.NOTICE_QUICK_TITLE`, `L.NOTICE_QUICK_TEXT`): einmalig, erklärt den Schnellkauf und weist darauf hin, dass die Benutzung auf eigene Gefahr ist und man die Einstellungen prüfen soll.
  - Tests: Hinweis gemeldet, Titel und Absätze (`test_broker.lua`).

## 0.116.0

Kurz: Im Schnellkauf ändert ein Klick auf eine Preisstufe nichts mehr. So stellst du Kaufen bis nicht aus Versehen um.

- 0.116.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Geändert:** Klick auf eine Preisstufe setzt im Schnellkauf weder Kaufen bis noch den Zielpreis. Im Aufkauf bleibt es wie bisher.

## 0.115.0

Kurz: Die Einstellung „Kaufprotokoll aufzeichnen“ ist wieder weg. Sie hat geholfen, die Fehlkäufe zu finden, und wird nicht mehr gebraucht.

- 0.115.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Entfernt, Kaufprotokoll** (seit 0.110.0): Einstellung `buyTrace`, `R.Trace`, `Q.Trace` und die zusätzlichen Ereignisse. Gespeicherte Zeilen (`buyLog`) werden beim Laden gelöscht. Das Fenster Einstellungen des Fokus ist 800 hoch.

## 0.114.1

Kurz: Ein eigenes Lockangebot, das sofort gekauft wird, steht jetzt richtig als weg da, statt weiter „steht seit …“ zu zählen.

- 0.114.1 (19.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben:** Laut Kaufprotokoll war das Lockangebot nach 0,35 Sek. verkauft, bevor eine Abfrage es zeigte. Das Spiel meldet das mit `AUCTION_CANCELED` und der Nummer des Angebots, das wertet `Q.OnCanceled` jetzt aus. Außerdem gilt es als weg, wenn eine Antwort mindestens 2 Sek. nach dem Einstellen es nicht zeigt, auch ohne dass es vorher zu sehen war.
  - Auswertung des dritten Kaufprotokolls (14:50 bis 15:20 Uhr): drei Käufe Leinenstoff, alle gelungen. Preis des Spiels nach 0,14 bis 0,18 Sek., auch wenn die Bremse beim Klick belegt war. Kein Code 10.

## 0.114.0

Kurz: Steht im Schnellkauf etwas unter Kaufen bis, fragt Broker 1 Sekunde lang nicht nach. So kommt dein Kauf schneller beim Spiel an.
Kurz: Die Zeile „Sitzung“ unter dem Lockangebot ist weg, „ist weg“ steht ohne Zusatz.

- 0.114.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Neu, Pause der Abfragen** (`quickHold`, Vorgabe 1 Sek., 0 bis 5 Sek., 0 = aus): Zeigt eine Antwort etwas Kaufbares, schickt der Fokus so lange keine Abfrage (`Q.HoldQueries`). Wird nicht geklickt, ist der Knopf danach gesperrt, bis die nächste Antwort da ist (`Q.Locked`). Sie gibt ihn mit der neuen Menge wieder frei. Nach einem Kauf wird sofort wieder abgefragt. Anlass: Im Kaufprotokoll wartete ein Kauf bis zu 1 Sek. auf den Preis und noch einmal so lange auf die Bestätigung, wenn die Bremse des Spiels von einer Abfrage belegt war.
  - **Entfernt:** Zeile „Sitzung …“ unter dem Lockangebot (die Bilanz steht in der Zeile „Gekauft“) und der Zusatz „(gekauft oder abgelaufen)“.
  - Tests: Pause, gesperrter Knopf auch per Taste, neue Antwort gibt frei, ohne Kaufbares keine Pause, abschaltbar, nach dem Kauf sofort weiter (`test_broker.lua`).

## 0.113.0

Kurz: Im Schnellkauf sind „Lockangebot ignorieren“ und „Durchschnitt zählt“ jetzt vorgegeben, das Limit pro Kauf steht auf dem Preis für 100 Stück.
Kurz: Neue Einstellungen speichern Aufkauf und Schnellkauf automatisch, wenn du den Reiter verlässt oder Broker schließt.

- 0.113.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Geändert, Vorgaben im Schnellkauf:** Ohne gespeicherte Werte sind beide Haken an und das Limit pro Kauf ist der Preis für 100 Stück zu Kaufen bis (`Q.EnsureGold`, `Q.GOLD_QTY`). Das Limit folgt Kaufen bis, bis man selbst einen Betrag einträgt. Selbst geleert bleibt es leer. Gespeichert werden die Haken jetzt auch als aus und „ohne Grenze“ als 0.
  - **Neu, automatisch speichern** (`autoSaveBuyout`, `autoSaveQuick`, Vorgabe an): beim Verlassen des Reiters, Schließen von Broker oder Auktionshaus und beim Wechsel von Modus oder Gegenstand (`F.AutoSave`, `F.Save(quiet)`). Nur für Gegenstände, die schon in Beobachten stehen.
  - **Geändert:** Hinter dem Limit pro Kauf steht „≥ x Stück“ statt „mindestens x Stück“.
  - Auswertung des zweiten Kaufprotokolls (14:33 bis 14:46 Uhr): Ohne Abbrechen kam nach einem zu teuren Preis kein Code 10 mehr. Code 10 kommt noch direkt nach fehlgeschlagenen Käufen, vom Spiel selbst. Ist die Bremse des Spiels beim Klick belegt (eine Abfrage ist gerade unterwegs), wartet der Kauf bis zu 1 Sek. auf den Preis und noch einmal so lange auf die Bestätigung. Siehe `Peon_Stand.md`.
  - Tests: Vorgaben, Limit folgt Kaufen bis, eigener Betrag bleibt, automatisch speichern beim Verlassen und beim Wechsel des Modus, nicht für unbeobachtete, Einstellung aus (`test_broker.lua`).

## 0.112.1

Kurz: „Limit pro Kauf“ steht jetzt links bündig unter Kaufen bis. Der Tooltip zu „Durchschnitt zählt“ beschreibt genauer, was passiert.

- 0.112.1 (19.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben:** „Limit pro Kauf“ stand im Spiel rechtsbündig. Im Schnellkauf haben die Beschriftungen keine feste Breite mehr, die Felder hängen an fester Stelle (`F.QUICK_FIELD_X`).
  - **Geändert, Tooltip „Durchschnitt zählt“:** Broker kauft die beim Klick angezeigte Menge. Haben andere einen Teil gekauft, füllt das Spiel mit teureren Angeboten auf, und der Kauf geht durch, solange der Durchschnitt höchstens Kaufen bis ist.

## 0.112.0

Kurz: Neuer Haken „Durchschnitt zählt“ im Schnellkauf: Der Kauf geht durch, solange der Durchschnitt je Stück höchstens Kaufen bis ist.
Kurz: Statt Max. Menge gibt es jetzt „Limit pro Kauf“ in Gold, Silber und Kupfer.

- 0.112.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Neu, Haken „Durchschnitt zählt“** rechts neben „Lockangebot ignorieren“ (je Gegenstand, gespeichert in Beobachten als `qavg`): Der Preis des Spiels gilt, solange der Durchschnitt je Stück höchstens Kaufen bis ist, ohne zweiten Klick mit Warnung (`job.avg`). Bisher galt der Preis des teuersten geplanten Stücks. Einzelne Stücke können dabei über Kaufen bis liegen, das erklärt der Tooltip.
  - **Geändert, Limit pro Kauf statt Max. Menge:** Goldfeld wie bei Kaufen bis, leer heißt ohne Grenze (`F.manualGold`, `Q.GoldQty`, in Beobachten `qgold` statt `qmax`). Der Kauf nimmt nur so viel, wie in das Limit passt, und ein höherer Gesamtpreis des Spiels gilt als zu teuer (`job.goldCap`). Dahinter steht, wie viele Stück zu Kaufen bis mindestens hineinpassen.
  - **Entfernt:** Hinweis „Linksklick“ hinter Kaufen bis im Schnellkauf.
  - Tests: Durchschnitt mit und ohne Haken, Limit pro Kauf im Plan und beim Preis des Spiels, Speichern, Tests von 0.106 auf das Limit pro Kauf umgestellt (`test_broker.lua`).

## 0.111.1

Kurz: Ist ein Kauf im Fokus zu teuer geworden, bricht Broker ihn nicht mehr aktiv ab. Das soll den roten Fehler „Interner Auktionshausfehler“ vermeiden.

- 0.111.1 (19.11.2026, Versuch mit KarloDerBaer):
  - **Geändert, zu teurer Preis:** kein `CancelCommoditiesPurchase` mehr, der Preis verfällt ohne Bestätigung. Laut Kaufprotokoll folgte jedem Abbruch 0,1 Sek. später der Fehler Code 10. Im Protokoll steht dafür `toohigh nocancel`.

## 0.111.0

Kurz: Eigener Ton, wenn ein fremdes Lockangebot auftaucht und der Kaufknopf noch gesperrt ist. So bist du für den folgenden Stapel bereit.
Kurz: Mehr Töne zur Auswahl. Im Schnellkauf zeigt die Zeile „Gekauft“, wie viele Gelegenheiten du genutzt hast.

- 0.111.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Neu, Ton für Lockangebote** (`quickBaitAlarm`, `quickBaitSound`, Vorgabe Kartenmarkierung): wenn ein fremdes Lockangebot erkannt wird und der Kaufknopf gesperrt ist (Haken „Lockangebot ignorieren“ oder nichts unter Kaufen bis). Ist der Knopf frei, gilt der normale Alarm.
  - **Neu, mehr Töne:** Münzen, Stufenaufstieg, Warteschlange bereit, Kartenmarkierung, Bosswarnung, Auktionshaus (`R.SOUNDS`, `R.SoundChoices`), auch für den Ton des Radars.
  - **Neu, Zeile „Gekauft“:** gekaufte Stück in dieser Sitzung und die Quote der genutzten Gelegenheiten. Eine Gelegenheit beginnt, wenn etwas Kaufbares unter Kaufen bis auftaucht, mit Haken ohne ein einzelnes Lockangebot. Im Tooltip Käufe und Fehlschläge (`Q.BoughtText`, `Q.OnFailed`, `Q.opp`).
  - Auswertung des ersten Kaufprotokolls (13:15 bis 13:24 Uhr): Die Fehler mit Code 10 kamen jedes Mal direkt nach dem Abbruch eines zu teuren Kaufs oder nach einem fehlgeschlagenen Kauf. Fehlgeschlagen sind Käufe, bei denen jemand anderes schneller war. Siehe `Peon_Stand.md`.
  - Tests: Ton für Lockangebote mit gesperrtem und freiem Knopf, Quote, Auswahl der Töne (`test_broker.lua`).

## 0.110.0

Kurz: Im Fokus meldet sich der Preisalarm aus Beobachten nicht mehr zusätzlich für den Gegenstand, den du gerade ansiehst.
Kurz: Neue Einstellung „Kaufprotokoll aufzeichnen“, um Fehlkäufe auszuwerten.
Kurz: Der Schnellkauf ist aufgeräumt: kürzere Zeilen mit Tooltips, Linien um das Lockangebot, Lockangebote bleiben sichtbar.

- 0.110.0 (19.11.2026, Rückmeldung KarloDerBaer):
  - **Geändert, Preisalarm:** Für den Gegenstand im sichtbaren Fokus gibt Beobachten keinen Alarm, der Fokus hat seinen eigenen (`Wt.InFocus`). Der Alarm gilt als gegeben und kommt nach dem Verlassen nicht nach.
  - **Neu, Kaufprotokoll** (`buyTrace` im Fenster Einstellungen des Fokus, Standard aus): jede Abfrage, Antwort, jeder Kaufschritt und die Ereignisse des Auktionshauses (Fehler mit Code, Bremse, Kauf gelungen oder fehlgeschlagen) mit Uhrzeit in `buyLog` (höchstens 6000 Zeilen, `R.Trace`). Anlass: viele Fehler mit Code 10 („Interner Auktionshausfehler“) beim Kauf von Lockangeboten.
  - **Behoben, Lockangebote verschwanden:** Sie wurden aus den Abfragen der Messung gerechnet, die nur die letzten 240 Abfragen behält und bei neuem Kaufen bis oder Modus neu beginnt. Jetzt zählt jede neue Abfrage fortlaufend mit (`Q.OnSample`, `Q.AddBait`, `Q.baits`).
  - **Geändert, fremde Lockangebote:** zählen nur, wenn sie höchstens bei Kaufen bis liegen. Was man ohnehin nicht kaufen würde, zählt nicht. Ohne Kaufen bis zählen alle.
  - **Behoben, Folge:** Wächst die Menge zum Lockpreis nur um 1 Stück, ist das selbst ein Lockangebot und zählt nicht mehr als Folge.
  - **Behoben, Tooltip am Knopf:** Unsichtbare Mausbereiche der Zeilen des Aufkaufs lagen im Schnellkauf über dem Knopf. Sie sind jetzt mit verborgen.
  - **Geändert, Schnellkauf links:** Knopf „Lockangebot einstellen“ (vorher „1 einstellen“, breiter), Linien über und unter dem Block Lockangebot, Beschriftungen links bündig.
  - **Geändert, Zeilen über dem Diagramm:** kurz, zum Beispiel „446 je Min. (29×)“, „lebhaft (71 Sprünge)“, „26 in 10 Min., 25 mit Folge“, „+10 in 30 Sek.“. Einzelheiten und Regeln im Tooltip jeder Zeile.
  - Tests: Lockangebote fortlaufend, einzelnes Stück keine Folge, kurze Zeilen und Tooltips, Mausbereiche, stiller Preisalarm im Fokus, Protokoll (`test_broker.lua`).

## 0.109.0

Kurz: Der Schnellkauf erkennt jetzt auch fremde Lockangebote und zeigt, wie viel andere danach zum selben Preis eingestellt haben.
Kurz: Neuer Haken „Lockangebot ignorieren“: Kaufknopf und Alarm erst ab mehr als 1 Stück unter Kaufen bis.

- 0.109.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Neu, fremde Lockangebote:** Eine neue Preisstufe mit genau 1 Stück, die mindestens 5 % unter dem bisher günstigsten fremden Angebot liegt, gilt als Lockangebot (`Q.ForeignBaits`, Grenze `quickBaitMinPct` 1 bis 50 % im Fenster Einstellungen des Fokus). Knappes Unterbieten zählt so nicht.
  - **Geändert, Anzeige über dem Diagramm:** Statt einer Zeile „Nach Lockangebot“ stehen jetzt zwei. „Lockangebote“ fasst alle fremden und eigenen im Zeitfenster zusammen (Zahl, wie viele Nachfolger hatten, im Schnitt wie viel Stück danach zum selben Preis kam). „Letztes“ zeigt das jüngste wie bisher, das eigene mit „(eigenes)“ (`Q.BaitStats`, `Q.FollowOf`). Eigene Lockangebote werden dafür als Liste gemerkt.
  - **Neu, Haken „Lockangebot ignorieren“** unter Max. Menge: Steht nur 1 Stück unter Kaufen bis, bleibt der Kaufknopf gesperrt und der Alarm still (`Q.SkipOn`, `c.baitOnly`). So hängt man nicht im Kauf eines einzelnen Stücks, während ein großer Stapel kommt. Das Spiel verkauft von unten, ein späterer Kauf nimmt das eine Stück mit. Der Haken gilt je Gegenstand und wird mit Speichern in Beobachten gemerkt (`qskip`, nur im Spiel).
  - Der Block Lockangebot links rückt 16 Punkte nach unten, das Fenster Einstellungen des Fokus ist 680 hoch.
  - Tests: fremdes Lockangebot und Grenze, Zusammenfassung mit eigenem Lockangebot, fünf Zeilen, Haken mit Knopf, Alarm, Speichern und je Gegenstand (`test_broker.lua`).

## 0.108.0

Kurz: Der Schnellkauf zeigt über dem Diagramm, wie viel gerade eingestellt und gekauft wird und wie lebhaft der Markt ist.
Kurz: Nach einem eigenen Lockangebot siehst du, wie viel andere danach zum selben Preis eingestellt haben.

- 0.108.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Neu, Marktbewegung im Schnellkauf:** Über dem Diagramm stehen vier Zeilen statt der Messwerte des Aufkaufs (`F.UpdateQuickMove`, `F.QUICK_ROWS`). Zufluss und Abfluss in Stück je Minute mit der Zahl der Einstellungen bzw. Käufe je Minute, die Bewegung (lebhaft, mäßig, ruhig) mit den Preissprüngen, und die Nachwirkung des Lockangebots. Grundlage ist das Zeitfenster der Messung (`focusWindow`).
  - **Neu, Bewegung:** zählt Ereignisse je Minute, also Einstellungen, Käufe und Preissprünge (`Q.Movement`). Lebhaft ab 2 Einstellungen und 5 Ereignissen je Minute, ruhig unter 1 Ereignis je Minute, sonst mäßig. Die drei Grenzen stehen im Fenster Einstellungen des Fokus (`quickMoveIn`, `quickMoveAll`, `quickMoveLow`).
  - **Neu, Nachwirkung des Lockangebots:** Wie viel Stück andere in den 30 Sekunden nach dem eigenen Lockangebot genau zu dessen Preis eingestellt haben und in wie vielen Schritten (`Q.Follow`, einstellbar 10 bis 120 Sekunden mit `quickFollowSec`). Solange die Zeit läuft, steht dort „bisher“ mit der Restzeit.
  - **Geändert, Messung:** Der Vergleich zweier Abfragen zählt jetzt auch Einstellungen und Käufe (Massenware je Preisstufe) und Preissprünge (`nNew`, `nSold`, `jump`). `M.Values` liefert dazu `inAll`, `newPerMin`, `soldPerMin`, `jumps`, `jumpsPerMin`.
  - Das Fenster Einstellungen des Fokus ist höher (640).
  - Tests: Zähler der Messung, Stufen der Bewegung, Nachwirkung fertig und laufend, Zeilen im Schnellkauf und zurück im Aufkauf, Zahl der Regler (`test_broker.lua`).

## 0.107.1

Kurz: Der Schnellkauf übernimmt Kaufen bis jetzt auch, wenn du den Fokus aus Beobachten öffnest. Der Lockpreis liegt 50 % darunter.

- 0.107.1 (19.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben, Kaufen bis im Schnellkauf:** Öffnete man den Fokus aus Beobachten, während der Schnellkauf eingestellt war, galt die Übernahme schon als erledigt, bevor der Fokus in den gespeicherten Aufkauf wechselte. Beim Umschalten blieb das Feld leer. Jetzt füllt der Schnellkauf Kaufen bis immer nach, wenn es leer ist, außer man hat es dort selbst geleert (`Q.limitCleared`, bis man wieder einen Wert einträgt).
  - **Behoben, Lockpreis:** Gespeichert war noch die alte Vorgabe 20 %. Sie wird einmal auf 50 % gestellt (`quickBaitPct50`), ein eigener anderer Wert bleibt.
  - Tests: Sprung aus Beobachten mit anschließendem Umschalten, selbst geleert bleibt leer, Umzug des Prozentwerts (`test_broker.lua`).

## 0.107.0

Kurz: Der Schnellkauf übernimmt beim ersten Öffnen Kaufen bis vom Aufkauf. Der Lockpreis liegt dann 50 % darunter.
Kurz: Das Feld Max. Menge steht bündig unter Kaufen bis, der Text dahinter hat mehr Platz.

- 0.107.0 (19.11.2026, Rückmeldung KarloDerBaer):
  - **Geändert, Schnellkauf:** Beim ersten Öffnen für einen Gegenstand übernimmt er Kaufen bis vom Aufkauf (`Q.EnsureLimit`, `Q.BuyoutLimit`): aus Beobachten, sonst den Wert, den der Aufkauf gerade rechnet. Leert man das Feld selbst, bleibt es leer.
  - **Geändert, Lockpreis:** Vorschlag ist Kaufen bis minus 50 % (`quickBaitPct`, einstellbar 5 bis 90 %), nicht mehr die erste echte Stufe minus 20 %.
  - **Geändert, Max. Menge:** Das Feld steht im Schnellkauf bündig mit dem Goldfeld von Kaufen bis.
  - Tests: Kaufen bis übernommen, selbst geleert bleibt leer, Lockpreis aus Kaufen bis, Lage des Mengenfelds (`test_broker.lua`).

## 0.106.0

Kurz: Im Schnellkauf gibt es statt des Reglers ein Feld „Max. Menge“. Dahinter steht, was ein Kauf höchstens kostet.
Kurz: Beobachten merkt sich die Werte von Aufkauf und Schnellkauf getrennt und öffnet den Fokus im zuletzt gespeicherten Modus.

- 0.106.0 (19.11.2026, Wünsche KarloDerBaer):
  - **Geändert, Schnellkauf:** ohne große Zeile und Satz darunter, ohne Haken „Wiedereinstellen“. Käufe aus dem Schnellkauf werden nie als Posten gemerkt. Kaufen bis, Max. Menge und Lockangebot rücken nach oben.
  - **Geändert, Max. Menge:** Eingabefeld statt Regler. Leer heißt alle (grau „alle“ im Feld). Dahinter steht „Höchstens 15s (10 × 1s 50c)“, also Menge mal Kaufen bis, ohne Menge „ohne Grenze“ (`F.SyncQuickQty`).
  - **Neu, Beobachten je Modus:** Kaufen bis und Zielpreis gehören zum Aufkauf, Kaufen bis und Max. Menge des Schnellkaufs werden getrennt gespeichert (`qlim`, `qmax`), dazu der zuletzt gespeicherte Modus (`mode`). „Speichern“ ändert nur die Werte des aktiven Modus. Umschalten im Fokus lädt die Werte des Modus. Die neuen Werte bleiben im Spiel, der Abgleich mit dem Peon Manager lässt sie aus.
  - **Geändert, Liste Beobachten:** neue Spalte „Art“ (Aufkauf oder Schnellkauf). „Kaufen bis“ zeigt den Wert dieser Art, „Zielpreis“ nur beim Aufkauf. Der Preisalarm nimmt Kaufen bis der gespeicherten Art, den Zielpreis nur beim Aufkauf. Doppelklick öffnet den Fokus in dieser Art, aus Chancen öffnet er immer im Aufkauf.
  - **Geändert, Liste Beobachten:** Spalte „Stand“ entfällt. Ohne laufende Abfrage steht oben rechts „Letzter Gegenstand gescannt vor: …“, die jüngste Einzelabfrage eines beobachteten Gegenstands (auch aus Fokus oder Chancen).
  - Tests: Schnellkauf ohne Hinweise und Haken, Max. Menge mit Höchstbetrag, Speichern und Laden je Modus, Fokus aus Beobachten und Chancen, Liste mit Art, Alarm je Modus, Stand oben rechts, kein Posten aus dem Schnellkauf (`test_broker.lua`).

## 0.105.0

Kurz: Das Radar hat keinen eigenen Reiter mehr. Seine Treffer stehen mit den Chancen vom Peon Manager in einer Liste im Reiter Chancen.
Kurz: Ein Knopf startet den Scan, daneben wählst du, was geprüft wird: Manager-Chancen, Beobachten, Massenware oder Alles.

- 0.105.0 (19.11.2026, Wunsch KarloDerBaer):
  - **Geändert, Reiter Chancen:** eine Liste für beides (`C.Rows`). Chancen des Managers wie bisher. Die Live-Prüfung aktualisiert sie, auch wenn das Radar für denselben Gegenstand etwas findet, es gibt keine doppelten Zeilen. Dazu die Treffer des Radars (Händler, Aufkauf), die keine Chance des Managers sind. Spalten Gegenstand, Art, Gewinn, Kaufen bis, Risiko, Zustand. Treffer aus dem Scan zeigen im Zustand ihr Alter, neue Treffer einen Punkt. Rechtsklick auf einen Treffer öffnet das Menü wie bisher im Radar.
  - **Geändert, Weggefallene:** je Herkunft wie bisher. Treffer des Radars bleiben 30 Sekunden grau stehen, verworfene Chancen des Managers bleiben ausgeblendet, bis ein neuerer Stand sie wieder bringt.
  - **Geändert, Scan:** Knopf mit Auswahl (`C.MODES`, Einstellung `chancesScan`). „Manager-Chancen“ fragt jede Chance einmal ab (früher „Alle prüfen“), „Beobachten“, „Massenware“ und „Alles“ sind der frühere Radar-Scan. Er läuft, solange der Reiter offen ist. Das Erneuern prüft Chancen des Managers und Treffer des Radars gemeinsam, die am längsten nicht geprüfte zuerst (`R.NextRenew`).
  - **Geändert, Zahl am Reiter:** nur noch am Reiter Chancen, die Treffer des Radars zählen mit. Nach einem Komplettscan mit neuen Treffern blinkt sie bis zum Öffnen (`C.OnScanDone`). Die eigene Auswahl für das Radar entfällt, Standard für Chancen bleibt aus.
  - **Geändert, Einstellungen:** ein Fenster „Einstellungen Chancen und Radar“ mit allen Werten beider Teile, etwas höher als die anderen.
  - **Geändert:** Ein gespeicherter Reiter Radar öffnet Chancen. „Zurück zu Radar“ im Fokus heißt „Zurück zu Chancen“. Die Tasten heißen „Fokus: kaufen“ und „Fokus: nächster Treffer des Radars“.
  - **Entfernt:** Reiter Radar im Broker-Fenster und im Auktionshaus (`R.Build`, `W.pages.radar`, Auswahl `badgeRadar`).
  - Tests: eine Liste ohne Doppel, Live-Prüfung aktualisiert die Chance des Managers, verworfene Chance kommt nicht als Treffer zurück, gemeinsames Erneuern, Auswahl des Scans, Blinken nach dem Scan, alte Tests auf den Reiter Chancen umgestellt (`test_broker.lua`).

## 0.104.0

Kurz: Der Kaufknopf im Fokus hängt nicht mehr an alten Angeboten. Nach einem Kauf oder wenn das Angebot schon weg ist, prüft Broker sofort neu.
Kurz: Neu im Fokus ist der Modus Schnellkauf für günstige Angebote, die nur Sekunden stehen: Alarm, Kaufen bis und ein eigenes Lockangebot mit einem Klick.
Kurz: Beim Verkaufen erkennt Broker Lockangebote (ein paar Stück weit unter dem Markt) und schlägt den Preis vom ersten echten Angebot aus vor.

- 0.104.0 (19.11.2026, Wünsche KarloDerBaer):
  - **Behoben, Kaufknopf im Fokus:** Nach einem Kauf oder wenn das Angebot schon weg war, rechnete der Knopf bis zur nächsten Antwort mit den alten Preisstufen. Schnelles Nachklicken startete denselben veralteten Kauf, das Spiel nannte einen höheren Preis und Broker brach ab. Mit eigenem Ziel fragte der Fokus danach nicht einmal sofort neu ab. Jetzt nimmt Broker die gekaufte Menge sofort aus den Stufen (`R.TakeRows`, `R.AfterBuy`), bei „schon weg“ fällt die günstigste fremde Stufe weg. In beiden Fällen fragt der Fokus sofort neu ab. Nach „schon weg“ zeigt der Knopf „Prüft …“ bis zur frischen Antwort, höchstens 3 Sekunden (`R.IsStale`, `R.STALE_MAX`).
  - **Behoben, Taste „Kaufen“:** Sie kaufte nur Chancen aus dem Radar, mit eigenem Ziel oder fester Menge tat sie nichts. Jetzt kauft sie genau das, was der Knopf zeigt (`F.Buy`).
  - **Neu, Fokus mit zwei Modi:** Umschalter oben rechts, „Aufkauf“ (der bisherige Fokus) und „Schnellkauf“ (`Quick.lua`, Einstellung `focusMode`). Gegenstand, laufende Abfrage und Preisstufen bleiben beim Umschalten.
  - **Neu, Schnellkauf:** links Kaufen bis, Menge und der Kaufknopf. Gekauft wird alles bis Kaufen bis, ohne Zielpreis und Gewinn. Sobald nach einer Antwort ohne Menge etwas unter Kaufen bis steht, kommt ein Ton und der Knopf leuchtet (`quickAlarm`, `quickSound`). Rechts die Preisstufen mit eigenen Angeboten (lila) und neuen oder größeren Stufen (einige Sekunden grün). Darunter ein Diagramm mit dem günstigsten Preis, der Menge unter Kaufen bis und einem Strich für jedes eigene Lockangebot.
  - **Neu, Lockangebot im Schnellkauf:** „1 einstellen“ stellt 1 Stück aus den Taschen mit der kürzesten Laufzeit ein (`PostCommodity`, nur Massenware). Im Feld steht als Vorschlag die erste echte Stufe minus 20 % (`quickBaitPct`), ein eigener Betrag gilt bis zum nächsten Gegenstand. Fragt das Spiel nach, bestätigt der zweite Klick (`ConfirmPostCommodity`, auch nach `AUCTION_HOUSE_POST_WARNING`). „Zurückziehen“ bricht das Angebot ab. Der Zustand zeigt, ob es steht, weg ist (gekauft oder abgelaufen) oder zurückgezogen wurde. Bilanz der Sitzung: Lockangebote mit Einzahlung, gekaufte Menge, Kosten und Preis je Stück.
  - **Neu, Rat beim Verkaufen:** Lockangebote zählen nicht (`Data.SkipBait`). Das sind die günstigsten fremden Stufen, wenn sie zusammen höchstens 5 Stück oder unter 2 % aller Angebote haben und die nächste Stufe mehr als 10 % teurer ist. Alle drei Grenzen stehen in den Optionen beim Preisvorschlag (`baitQty`, `baitPct`, `baitGap`). „Günstige“ und „Vorschlag“ gehen dann von der ersten echten Stufe aus, der Kasten nennt das Lockangebot. Steht im Preisfeld der Preis des Lockangebots oder weniger, heißt der Rat „Lockangebot“.
  - Tests: Stufen nach Kauf und „weg“, Sperre bis zur frischen Antwort, Kauf und Bilanz, Lockangebote erkennen mit allen Grenzen, Rat und Knöpfe beim Verkaufen, Umschalter, Plan und Urteil im Schnellkauf, Alarm nur bei neuer Antwort, neue Stufen, Lockangebot einstellen, bestätigen, zurückziehen und weg, Diagramm (`test_broker.lua`).

## 0.103.3

Kurz: Der Paketvergleich erscheint jetzt auch bei der Kiste „Textilien des Experten“.

- 0.103.3 (18.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben, Paketvergleich:** Im Spieltext der Kiste steht „-: 20 schweres Leder“ mit einem Doppelpunkt zu viel. `P.ParseLine` las diese Zeile nicht, es blieb nur ein Paket übrig und der Vergleich erscheint erst ab zwei. Jetzt darf nach dem Strich ein Doppelpunkt oder Punkt stehen.
  - Tests: Zeile mit „-:“ gelesen, Textilien des Experten ergeben zwei Pakete (`test_broker.lua`).

## 0.103.2

Kurz: Broker braucht im Auktionshaus etwas weniger Leistung.

- 0.103.2 (18.11.2026, Review mit KarloDerBaer):
  - **Geändert:** Die Ereignisse des Auktionshauses zählt die Prüfung erst nach `/broker pruefen` (auch `pruefen scan`) bis zum nächsten `/reload`, vorher bei jedem Login. Ob das Auktionshaus offen ist, weiß die Prüfung auch ohne eigene Ereignisse (über den Scan).

## 0.103.1

Kurz: „Im Markt zeigen“ springt bei Ausrüstung mit Zusatz wie „des Banditen“ jetzt zur richtigen Variante.
Kurz: Beim Verkaufen trägt Broker den Preis deiner Variante selbst ein, wenn Blizzard den Preis einer anderen Variante vorschlägt.

- 0.103.1 (17.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben, Im Markt zeigen:** Der Knopf suchte in Blizzards Ergebnisliste nur nach der Nummer des Gegenstands. Alle Varianten haben dieselbe, darum ging die erste Zeile auf (zum Beispiel „der Beweglichkeit“ statt „des Banditen“). Jetzt vergleicht `Go.RowMatches` bei Varianten den Namen vom Spiel (`GetItemKeyInfo`), sonst den gelernten Zusatz. Passt keine Zeile, geht der Klick wie bisher auf den Reiter Markt mit Suche.
  - **Neu, Rat beim Verkaufen:** Steht im Preisfeld der Preis einer anderen Variante („Andere Variante“) und kennt Broker das günstigste Live-Angebot genau dieser Variante, trägt er den Vorschlag selbst ein (`A.AutoVariant`, über `Lots.FillTarget` wie der Knopf „Vorschlag“). Einmal je Gegenstand, solange das Fenster offen ist, eine eigene Änderung danach bleibt stehen. Nicht nach einer Blockade (`targetBlocked`) und nicht, wenn nur der letzte Marktpreis bekannt ist.
  - Tests: Variante findet ihre Zeile, fehlende Variante keine fremde, ohne Namen über den gelernten Zusatz, Preis selbst eintragen nur einmal, nur mit Live-Angebot, nicht nach Blockade (`test_broker.lua`).

## 0.103.0

Kurz: Steht von deiner Variante gerade nichts im Auktionshaus, rät Broker beim Verkaufen nicht mehr vorschnell zum Händler. Er schlägt den Preis vor, zu dem sie zuletzt vermutlich verkauft wurde, sonst den oberen Rand des üblichen Bereichs.
Kurz: Dazu ein Hinweis, wenn sie selten im Markt ist oder zuletzt angeboten, aber nicht verkauft wurde.

- 0.103.0 (17.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben, Rat beim Verkaufen:** Blizzard trägt bei Gegenständen mit Zusatz den billigsten Preis irgendeiner Variante ein. Stand von der eigenen Variante gerade kein Angebot im Haus, verglich der Rat nur diesen Preis mit dem Händler und sagte „Lieber zum Händler“. Der letzte Preis der Variante zählte nicht, weil er als „weg“ galt.
  - **Neu, Rat beim Verkaufen:** Ohne Angebot genau dieses Gegenstands (`A.NoOffers`) gilt als Vergleichspreis der Preis, zu dem zuletzt vermutlich verkauft wurde, wenn höchstens 7 Tage alt (`A.SOLD_DAYS`), sonst der obere Rand des üblichen Bereichs (`A.Reference`). Liegt der Preis im Feld darunter und bringt der Vergleichspreis nach Abzug mehr als der Händler, heißt der Rat „Höher ansetzen“ und der Knopf „Vorschlag“ trägt den Vergleichspreis ein (`A.CheckNoOffers`).
  - **Neu, Rat beim Verkaufen:** Hinweis zum Markt (`A.MarketHint`): bisher nie gesehen, selten (länger als 7 Tage nicht im Markt, `A.SEEN_DAYS`) oder in den letzten 7 Tagen angeboten, aber kein Verkauf erkannt (eigene Vergleiche, Verkaufspreis und Absatz vom Manager).
  - **Neu, Absatz:** Broker merkt sich den höchsten Preis, zu dem bei einem Vergleich vermutlich verkauft wurde, in `e.sp = "Preis:Zeit"` (`Sales.Compare` gibt ihn als vierten Wert zurück, `Sales.LastSold`, `Sales.RecentDays`). Werte gibt es erst ab dieser Version.
  - **Behoben, Absatz:** Verschwand ein Gegenstand beim Komplettscan ganz, wurde er nicht verglichen. Einzelstücke ohne Konkurrenz galten so nie als verkauft. Jetzt vergleicht der Scan auch diese (`Scan.lua` nach `D.MarkGone`).
  - Tests: Verkaufspreis beim Vergleich, Höher ansetzen mit Verkaufspreis und mit üblichem Bereich, Hinweise selten, nie gesehen und ohne Verkauf, Händler bleibt bei niedrigem Vergleichspreis (`test_broker.lua`).

## 0.102.0

Kurz: „Alle prüfen“ bei den Chancen erkennt jetzt auch Ausrüstung mit Zusatz wie „der Beweglichkeit“, die schon weg ist. Vorher blieb sie „ungeprüft“, bis man sie im Fokus geöffnet hat.

- 0.102.0 (17.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben, Chancen:** Chancen mit Varianten (Zusatz im Namen) konnte Broker ohne gelernten Suchschlüssel nicht gezielt abfragen, sie blieben „ungeprüft“. Jetzt sucht Broker auf der Seite Chancen zuerst über die Namenssuche des Auktionshauses nach allen Varianten (`R.LearnChance`, `C.NextLearn`). Ist die Variante dabei, ist der Schlüssel gelernt und die Chance wird normal geprüft. Fehlt sie oder gibt es gar keine Angebote, steht sie auf „weg“. Hat das Spiel die Namen der Varianten noch nicht geladen, versucht Broker es nach 30 Sekunden erneut, höchstens dreimal.
  - **Behoben, Chancen:** „Alle prüfen“ hielt auf der Seite Chancen gleich nach dem Start wieder an, weil der Radar-Scan nur auf der Seite Radar laufen durfte. Geprüft hat bis dahin nur das Erneuern nacheinander.
  - `B.FinishKey` lernt die Schlüssel auch, wenn der Markt den Gegenstand noch nicht als Gegenstand mit Varianten kennt.
  - Tests: lernen, weg bei fehlender Variante, später nochmal bei fehlenden Namen, weg ohne Angebote (`test_broker.lua`).

## 0.101.0

Kurz: Chancen, die beim Prüfen weg waren, kommen nach einem Reload nicht mehr wieder. Erst wenn der Peon Manager sie mit neuen Daten wieder findet, stehen sie erneut in der Liste.

- 0.101.0 (17.11.2026, Wunsch KarloDerBaer):
  - **Neu, Chancen:** Was beim Prüfen „weg“ ist, merkt sich Broker mit dem Stand des Managers, aus dem die Chance kam, in `PeonBrokerDB.chancesGone[Markt][Schlüssel] = "Stand:Zeit:Angebot"` (Angebot = günstigstes Angebot in Kupfer, 0 = keine Angebote). Solange der Reiter offen ist, bleibt die Zeile als „weg“ stehen. Nach dem Verlassen des Reiters, beim Öffnen des Auktionshauses und nach einem Reload ist sie ausgeblendet und wird nicht mehr geprüft (`C.Forget`, `C.Hidden`, `C.Leave`).
  - **Neu, Chancen:** Bringt der Manager einen neueren Stand, gilt die Chance wieder und der Eintrag wird entfernt (`C.Prune`). Wird sie beim Prüfen wieder bestätigt, ist der Eintrag gleich fort. Einträge ohne neuen Stand fallen nach 3 Tagen weg.
  - **Neu, Chancen:** Oben steht, wie viele Chancen bis zum nächsten Stand ausgeblendet sind („· 8 weg bis zum nächsten Stand“).
  - Aufkauf: Ist der Aufkauf im Radar aus, merkt sich Broker dazu nichts, die Prüfung sagt dann nichts über die Chance.
  - Der Manager ab 0.44.0 liest die Liste aus `Peon_Broker.lua` und blendet diese Chancen ebenfalls aus.
  - Tests: merken, ausblenden, Reload, bestätigt, neuer Stand, Aufräumen (`test_broker.lua`).

## 0.100.0

Kurz: Der mögliche Gewinn beim Verkaufen rechnet jetzt auch Einstellgebühren von Auktionen ab, die vorher nicht verkauft wurden.

- 0.100.0 (16.11.2026, Wunsch KarloDerBaer):
  - **Geändert, Verkaufen:** „Möglicher Gewinn“ zieht offene Einstellgebühren aus Peon_Ledger je Stück ab und nennt sie dahinter („offene Gebühren …“). Braucht Ledger 0.16.0, sonst wie bisher (`A.Profit`, `Item.OpenFee`).
  - Tests: Gewinn mit und ohne offene Gebühren (`test_broker.lua`).

## 0.99.1

Kurz: Beim Verkaufen steht im Rat jede Angabe in einer eigenen Zeile, ganz unten der mögliche Gewinn nach Gebühr und Einkauf. Im Fokus zeigt der Mengenregler keine zweite, veraltete Zahl mehr.

- 0.99.1 (16.11.2026, Rückmeldung KarloDerBaer):
  - **Behoben, Fokus:** Neben dem Mengenregler stand eine gelbe Zahl mit altem Stand. Das war die Wertanzeige von Blizzards Regler, die beim Nachziehen nicht neu gesetzt wurde. Sie ist jetzt aus, die Menge steht im Feld.
  - **Geändert, Verkaufen:** Der Rat links zeigt Üblich, Absatz, Verkaufsquote, Erlös und Händler je in einer eigenen Zeile mit goldener Beschriftung.
  - **Neu, Verkaufen:** Zeile „Möglicher Gewinn“ ganz unten: Erlös nach Gebühr beim Preis im Feld minus Einkauf (`A.Profit`). Der Einkauf kommt aus dem Posten, sonst aus Peon_Ledger. Ohne bekannten Einkauf zählt der Erlös ganz, mit Hinweis.
  - Tests: Zeilen Erlös und Möglicher Gewinn, Gewinn mit und ohne Einkauf (`test_broker.lua`).
  - **Im Spiel prüfen:** Keine gelbe Zahl mehr am Regler. Kasten beim Verkaufen gut lesbar, Gewinn plausibel.

## 0.99.0

Kurz: Im Fokus stellst du mit Schieberegler oder Feld ein, wie viele Stück du höchstens kaufen willst. Die Zahl bleibt, auch wenn mehr Ware unter den Preis fällt. Beim Verkaufen stehen rechts neben dem Rat Knöpfe, die mit einem Klick den günstigsten Preis, den Vorschlag, deinen zuletzt eingestellten Preis oder deinen Zielpreis eintragen.

- 0.99.0 (16.11.2026, Wunsch KarloDerBaer):
  - **Neu, Fokus: Menge.** Zeile „Menge“ unter dem Risiko mit Schieberegler, Feld und Hinweis („alle“ oder „von N“). Die eingestellte Zahl ist eine feste Höchstmenge (`F.manualQty`, nur diese Sitzung). Ändert sich die Menge im Markt, rückt der Regler, die Zahl bleibt. Regler ganz rechts oder Feld leer heißt alle. Gekauft wird von billig nach teuer. Menge, Kosten, Gewinn, Verkaufsdauer und die blaue Markierung der Preisstufen richten sich nach der Menge (`F.CapPlan`, Kopie des Plans, die Chance im Radar bleibt unberührt). „Auto“ und ein anderer Gegenstand im Fokus setzen die Menge zurück. Bei Einzelgegenständen zählt jede Auktion als ein Stück.
  - Zeilen Üblich, Verkauft in und Risiko 4 Punkte höher (`F.ROW_Y`), Platz für die neue Zeile.
  - **Neu, Verkaufen: Preisknöpfe.** Der Kasten unter „Auktion erstellen“ hat zwei Spalten. Links der Rat, rechts Knöpfe mit Preis: „Günstige“ (günstigstes Angebot anderer Verkäufer, bei Varianten genau dieser Variante, ohne Unterbieten), „Vorschlag“ (`Data.Suggest`), „Letzter“ (zuletzt eingestellter Preis) und „Ziel“ (Zielpreis des Postens, sonst aus Beobachten, nur zu sehen, wenn es einen gibt). Ohne Preis ist der Knopf grau. Eingetragen wird wie bisher über `Lots.FillTarget`, nach einer Blockade bleiben alle Knöpfe grau.
  - **Neu:** Broker merkt sich beim Einstellen den Preis je Gegenstand und Markt (`PeonBrokerDB.lastPost`, bestätigt durch `AUCTION_HOUSE_AUCTION_CREATED`). Vor diesem Update eingestellte Gegenstände haben noch keinen Wert.
  - **Entfernt:** Die Knöpfe „Zielpreis eintragen“ und „Preis eintragen“ (Variante) im Kasten. Ihre Aufgabe übernehmen „Ziel“ und „Günstige“.
  - Tests: feste Menge per Feld und Regler, Nachziehen zählt nicht als Wahl, Regler ganz rechts gleich alle, Menge über dem Angebot. Knöpfe mit Preisen, Eintragen, letzter Preis gemerkt, Ziel aus Posten und aus Beobachten, grau nach Blockade (`test_broker.lua`).
  - **Im Spiel prüfen:** Fokus mit vielen Stück unter dem Ziel: Regler und Feld, Kaufen mit kleinerer Menge, Regler bei wachsender Menge. Verkaufen: Kasten in zwei Spalten, Text nicht abgeschnitten, Knöpfe tragen ein, „Auktion erstellen“ geht danach ohne Blockade, „Letzter“ nach dem Einstellen.

## 0.98.0

Kurz: Beim Verkaufen von Gegenständen mit Zusatz zeigt Broker nur die Angebote genau dieser Variante. Ein Klick auf eine Zeile trägt ihren Preis ein. Mit „Alle Varianten zeigen“ kommt Blizzards Liste zurück.

- 0.98.0 (16.11.2026, Wunsch KarloDerBaer): Neue Datei `SellVariant.lua`.
  - **Neu:** Zeigt Blizzards Liste im Verkaufen Angebote anderer Varianten, legt Broker eine eigene Liste darüber (wie „Zum Einstellen“, Blizzards Liste bleibt darunter unberührt). Spalten Kaufpreis, Menge, Eigene. Unten steht, wie viele Angebote anderer Varianten ausgeblendet sind.
  - Klick auf eine Zeile trägt ihren Preis ins Preisfeld ein (über `Lots.FillTarget`, gleiche Sperre nach einer Blockade).
  - Knopf über der Liste links: „Alle Varianten zeigen“ bzw. „Nur diese Variante“, gemerkt in `sellVariantOnly` (Standard an).
  - Liefert das Spiel die Angebote in Teilen, fordert Broker den Rest an wie Blizzards Liste beim Blättern (höchstens `Live.MORE_MAX` mal je Gegenstand). Der Rat beim Verkaufen hört dafür auch auf `ITEM_SEARCH_RESULTS_ADDED`.
  - Die Liste „Zum Einstellen“ liegt darüber, wenn sie offen ist.
  - Tests: Liste nur bei anderen Varianten, Klick trägt den Preis ein, Umschalten, Nachladen begrenzt, anderer Gegenstand und außerhalb von Verkaufen ohne Liste (`test_broker.lua`).
  - **Im Spiel prüfen:** Variante ins Verkaufsfenster legen, Liste zeigt nur diese Variante, Klick trägt den Preis ein, „Auktion erstellen“ geht danach ohne Blockade. Umschalten auf alle Varianten und zurück.

## 0.97.1

Kurz: Mit dem Haken „Wieder einstellen“ wird jetzt auch ein Kauf aus den Chancen gemerkt. Beim Verkaufen von Gegenständen mit Zusatz sagt Broker, wenn der Preis im Feld von einer anderen Variante stammt, und trägt auf Knopfdruck einen passenden Preis ein.

- 0.97.1 (16.11.2026, Rückmeldung KarloDerBaer mit Bild):
  - **Behoben, Wieder einstellen:** Ein Kauf im Fokus aus dem Reiter Chancen wurde trotz Haken kein Posten zum Einstellen. `R.FinishJob` nahm nur Aufkauf und eigenes Ziel (`buyout`, `own`), jetzt jede Art außer Händlerware. Käufe von Einzelgegenständen tragen den Zielpreis jetzt mit (`target` im Auftrag).
  - **Behoben, Rat beim Verkaufen bei Varianten:** Blizzards Liste zeigt alle Varianten („… des Bären“, „… des Banditen“) und trägt das günstigste Angebot ein, auch von einer anderen Variante. Der Rat hieß dann „Lieber warten, jemand verkauft gerade billig“. Liegt der Preis im Feld unter dem günstigsten Angebot genau dieser Variante, heißt der Kasten jetzt „Andere Variante“ und nennt dieses Angebot. Ohne Angebot dieser Variante in der Liste nennt er ihren letzten Marktpreis. Knopf „Preis eintragen“ trägt das Angebot unterboten wie im Vorschlag ein (gleicher Weg wie „Zielpreis eintragen“, `A.CheckVariant`, `A.var`). Ein Posten mit Zielpreis geht vor.
  - Tests: Kauf aus Chancen wird Posten, Varianten-Hinweis mit und ohne Angebot, ohne andere Varianten kein Hinweis (`test_broker.lua`).
  - **Im Spiel prüfen:** Kauf aus Chancen mit Haken erscheint unter „Zum Einstellen“. Verkaufen einer Variante: Kasten „Andere Variante“, Knopf trägt den Preis ein, „Auktion erstellen“ geht danach ohne Blockade.

## 0.97.0

Kurz: Für jeden Reiter mit roter Zahl stellst du in den Optionen von Broker ein, ob und wann die Zahl kommt. Neu kann auch der Reiter Chancen eine Zahl zeigen.

- 0.97.0 (15.11.2026, Wunsch KarloDerBaer): Optionen, neuer Abschnitt „Zahl am Reiter“ mit einer Auswahl je Reiter (`AHTabs.BADGE_MODES`, Einstellungen `badgeBuy`, `badgeWatch`, `badgeRadar`, `badgeSell`, `badgeChances`).
  - **Einkaufen:** Aus, Kaufen oder Teilweise (Standard, wie bisher), Nur Kaufen.
  - **Beobachten:** Aus, Kaufen bis oder Zielpreis erreicht (Standard), Nur Kaufen bis, Nur Zielpreis.
  - **Radar:** Aus, Treffer nach dem Scan mit Blinken (Standard), ohne Blinken.
  - **Chancen (neu):** Aus (Standard), Bestätigte Chancen (bei der letzten Live-Prüfung noch da), Alle Chancen. Muster zählen nur in ihrer günstigen Zeit. Die Zahl wird nach jeder Prüfung, beim Öffnen des Auktionshauses und jede Minute neu gerechnet.
  - **Verkaufen:** Aus, Offene Posten zum Einstellen (Standard).
  - Eine Änderung wirkt sofort (`AHTabs.RefreshBadges` über das Ereignis `CHANGED`).
  - Tests: Optionen, Standard und unbekannter Wert, jeder Reiter mit seinen Möglichkeiten (`test_broker.lua`).
  - **Im Spiel prüfen:** Auswahl in den Optionen, Zahl verschwindet bei Aus sofort, Chancen mit Zahl.

## 0.96.2

Kurz: Die rote Zahl an einem Reiter sitzt jetzt auf seiner unteren rechten Ecke. Die Reiter werden dadurch nicht mehr breiter und passen wieder ins Fenster.

- 0.96.2 (15.11.2026, Rückmeldung KarloDerBaer mit Bild): Mit Zahlen an Einkaufen und Beobachten ragten die neun Reiter rechts aus dem Auktionshaus.
  - **Ursache:** Die Zahl stand neben dem Text, `Peon.UI.FitTab` machte den Reiter um ihre Breite länger.
  - **Behoben:** Neue `Window.CornerBadge`: die Zahl als roter Kreis auf der unteren rechten Ecke (`tab.corner`, oben läge sie unter dem Fensterrahmen). Im Broker-Fenster und im Auktionshaus, auch am Reiter Verkaufen. Der Kern bleibt unverändert.
  - Tests: Zahl auf der Ecke, Reiter mit und ohne Zahl gleich breit, Broker-Fenster ebenso (`test_broker.lua`).
  - **Im Spiel prüfen:** Zahl an Einkaufen und Beobachten gut sichtbar, nichts ragt aus dem Fenster.

## 0.96.1

Kurz: Der Tooltip eines Rezepts zeigt jetzt die Preise des Rezepts. Bisher standen dort die Preise des Gegenstands, den das Rezept herstellt.

- 0.96.1 (15.11.2026, Frage KarloDerBaer): Rezept „Schwerer Krokiliskeneintopf“: Gegenstandsseite üblich 2g 29s bis 3g 51s, Tooltip üblich 9s 90c bis 11s 97c.
  - **Ursache:** Bei einem Rezept enthält Blizzards Tooltip das hergestellte Produkt, `GameTooltip:GetItem()` nennt dann dessen Link. Broker hat die Zeilen für das Produkt gerechnet.
  - **Behoben:** `T.LinkFor` nimmt die Nummer aus `data.id`, die das Spiel dem Tooltip-Haken mitgibt, wenn sie vom Link abweicht (Link aus `data.hyperlink` oder `GetItemInfo`, sonst `item:Nummer`).
  - Tests: Rezept statt Produkt, gleicher Gegenstand bleibt, ohne `data` wie bisher (`test_broker.lua`).
  - **Im Spiel prüfen:** Tooltip des Rezepts zeigt Markt und üblichen Bereich wie die Gegenstandsseite.

## 0.96.0

Kurz: Neuer Reiter Chancen rechts neben dem Radar: Hier stehen die Chancen des Peon Managers mit Zustand (ungeprüft, bestätigt, weg). „Alle prüfen“ fragt sie am Auktionator einmal ab.
Kurz: Das Radar zeigt nur noch, was ein Scan im Spiel findet: Händler und Aufkauf. Der Fokus steht jetzt links neben Beobachten.
Kurz: Für Muster (günstige Tageszeit oder Wochentag) sagt Broker, wann es günstig ist, und meldet sich im Chat, wenn die günstige Zeit beginnt. Einstellbar über den Knopf Einstellungen im Reiter Chancen.

- 0.96.0 (15.11.2026): Konzept `docs/konzepte/manager/Peon_Chancen_Reiter_Muster.md` (KarloDerBaer 15.11.2026). Gehört zu Manager 0.39.
  - **Reiter Chancen:** Neue Datei `Chances.lua`. Liste aller gültigen Einträge des Managers mit Art (Spekulation, Langfristig, Aufkauf, Muster), Gewinn, Kaufen bis und Zustand, Tooltip mit Satz, Alter des Stands, Preisen und Zeitfenstern. Klick öffnet den Fokus, „Zurück“ führt zu Chancen.
  - **Live-Prüfung:** Die Arbeit macht weiter der Radar-Teil. Ist die Seite Chancen am Auktionator offen, erneuert er die Kandidaten des Managers, am längsten nicht geprüft zuerst (`R.NextRenew`). Jede Antwort setzt den Zustand (`C.Note` aus `R.Apply`). „Alle prüfen“ ist ein Radar-Scan mit der Auswahl `mgronly`, eine Runde, dann Schluss.
  - **Radar:** zeigt keine Art Spekulation mehr (`R.Visible`), die Auswahl „Vom Manager“ und die Einstellung `radarSpecOn` entfallen.
  - **Muster:** `Spec.Parse` liest die Zeitfenster (`buyWin`, `sellWin`), `Spec.Find` prüft auch die Art `m` live. Außerhalb des günstigen Fensters steht „ab 0 bis 3 Uhr“, die Zeile rutscht nach unten.
  - **Hinweise:** beim Öffnen des Auktionshauses „2 Chancen vom Peon Manager warten“ (`chancesAhNote`), bei Beginn eines günstigen Fensters eine Chatzeile mit Kaufen bis und Verkaufszeit (`chancesNotify`, Prüfung jede Minute). Arten einzeln an oder aus (`chancesShowS`, `L`, `B`, `M`), alles im neuen Fenster Einstellungen Chancen.
  - **Reihenfolge der Reiter** (KarloDerBaer): Markt, Verkaufen, Auktionen, Einkaufen, Fokus, Beobachten, Radar, Chancen, Mehr, im Fenster und im Auktionshaus.
  - Tests: Reihenfolge der Reiter, Radar-Einstellungen ohne Spekulation, Auswahl ohne „Vom Manager“, neuer Abschnitt 0.96 (Fenster lesen und als Text, Zeit im Fenster, Kandidaten und Arten, Zustand, Radar ohne Kandidaten, Hinweis beim Öffnen, Einstellungen) in `test_broker.lua`. Alle Lua-Tests grün.
  - **Im Spiel prüfen:** Reiter Chancen am Auktionator und unterwegs, „Alle prüfen“, Klick in den Fokus und zurück, Hinweis beim Öffnen des Auktionshauses, Einstellungen.

## 0.95.1

Kurz: Das Radar spielt bei neuen Treffern keinen Warnton mehr. Wer ihn möchte, schaltet ihn in den Einstellungen unter Radar wieder ein.

- 0.95.1 (14.11.2026): Fehlerbericht 29. Ab und zu kam ein Warnton (Schlachtzugswarnung) ohne Chatzeile. Ursache: der Ton bei neuen Radar-Treffern (`radarSound`) war ab Werk an und meldet sich nur mit Ton, ohne Text im Chat. Er ist jetzt ab Werk aus und wird beim ersten Laden einmal ausgeschaltet (`radarSoundOff` merkt sich das, danach bleibt die eigene Wahl). Die Warnungen der Beobachtung (mit Chatzeile) bleiben unverändert.
  - Tests: Ton nach dem Laden aus, Merker gesetzt (`test_broker.lua`).
  - **Im Spiel prüfen:** Auktionshaus mit laufendem Radar: neue Treffer pulsieren, aber kein Ton. Einstellung „Ton bei neuen Möglichkeiten“ ist aus und lässt sich wieder einschalten.

## 0.95.0

Kurz: Kosten und Gewinn im Berufsfenster zeigt jetzt das Modul Peon Berufe. Deine Einstellungen dazu werden dorthin übernommen.

- 0.95.0 (14.11.2026): Umzug des Berufsfensters nach Peon_Profession 0.2.0 (Konzept `Peon_Profession_Konzept.md` Abschnitt 8, Bauabschnitt S6, Zustimmung KarloDerBaer 14.11.2026).
  - **Entfernt aus Broker:** Block unter den Reagenzien, Gewinn in der Rezeptliste mit goldenem Strich, Zahnrad-Menü, Box neben dem Fenster, Knopf „Auf Einkaufsliste“ im Berufsfenster, Abschnitt Berufe auf der Optionsseite und die Einstellungen `craftList…`, `craftBlock`, `craftSummary`, `craftCol…`, `craftHint`. Alles steht jetzt in Peon_Profession. Die Werte bleiben in `PeonBrokerDB`, Peon_Profession übernimmt sie einmal.
  - **`Craft.lua` bleibt klein:** Kaufpreis, AH-Preis, Vorrat und Ledger für Paketvergleich, Händlerpreise und Tooltip. Die Zeile Herstellkosten im Tooltip (mit Umschalt) kommt jetzt von Peon_Profession (`profession:CraftTooltip`).
  - **Schnittstelle erweitert:** `mod:BuyPrice` liefert zusätzlich AH-Preis, Händlerpreis, Herkunft und Händler. Neu `mod:AhPrice(id)`. `mod:AddToList(name, mats, keepMax)`: mit `keepMax` wird die Wunschmenge nicht kleiner und `v` markiert Händlerware, wie bisher beim Knopf im Berufsfenster.
  - `/broker pruefen beruf` nennt den Umzug, geprüft wird mit `/prof pruefen`.
  - Tests: Preise mit Händlerpreisen (gesehen, Ledger, geschätzt), Tooltip-Zeile über Peon_Profession, `AddToList` mit `keepMax`. Die Tests des Berufsfensters stehen jetzt in `test_profession.lua`.

## 0.94.0

Kurz: Broker gibt Preise und die Einkaufsliste an das neue Modul Peon Berufe weiter.

- 0.94.0 (14.11.2026): Schnittstelle für Peon_Profession (Konzept `docs/konzepte/profession/Peon_Profession_Konzept.md` Abschnitt 5).
  - **`mod:BuyPrice(id)`:** Kaufpreis je Stück wie im Berufsfenster (Händler oder AH, das Günstigere) und Quelle.
  - **`mod:AddToList(name, mats)`:** Material auf die Einkaufsliste mit diesem Namen (`B.AddToNamed` in `Buy.lua`), wird bei Bedarf angelegt. Die Wunschmenge wird gesetzt, nicht addiert, mit Zeit je Wert für den Manager.
  - Tests: Preis ohne Daten, Liste anlegen, Menge ersetzen (`test_broker.lua`).

## 0.93.0

Kurz: Das Radar hat die neue Art Spekulation mit Kaufkandidaten aus dem Peon Manager. Erneuern prüft sie live wie jede andere Zeile.
Kurz: Der Radar-Scan kann zuerst alle Kandidaten vom Manager abfragen (Auswahl „Vom Manager“).
Kurz: Broker liest beim Anmelden die Feste der nächsten Wochen aus dem Kalender und gibt sie an den Manager.

- 0.93.0 (13.11.2026): Chancen und Prognosen, Bauabschnitte K6 und K8 (Konzept `docs/konzepte/manager/Peon_Manager_Chancen.md` 5.4 und 9.2). Braucht Bridge 0.11 und Manager 0.35.
  - **Neue Datei `Spec.lua`:** liest die Kandidaten des Managers über `bridge:Chances` (`Sp.All`, abgelaufene fallen weg). Spekulation schnell und langfristig werden im Radar zur Art **Spekulation** (`radarSpecOn`, Vorgabe an, in den Einstellungen des Radars nicht mehr grau). Aus den Preisstufen gilt: kaufen bis Kaufen bis, verkaufen zum Zielpreis (`Sp.Find`). Ohne eigene Preisstufen stehen die Werte des Managers in der Liste, bis Erneuern live prüft. Was live nicht mehr stimmt, wird „weg“ wie bisher.
  - **Radar-Scan „Vom Manager“** (`radarScanMode = "mgr"`): zuerst alle Kandidaten des Managers nach Gewinn (auch Aufkauf und Händler), danach die Massenware.
  - **Fokus:** Bei einer Chance vom Manager stehen dessen Satz und „Vom Manager, Stand vor X Std.“ unter dem Urteil, bei Spekulation dazu Risiko und Zielpreis.
  - **Einschätzungen** speichern Art (`kind`: s, l, b, v) und Satz (`say`) mit, damit der Manager sie zuordnen kann.
  - **Neue Datei `Calendar.lua`:** liest beim Anmelden die Feste der nächsten 6 Wochen (`C_Calendar.GetDayEvent`, nur Feste) und speichert sie in `PeonBrokerDB.feste`. Für den Dunkelmond-Jahrmarkt wird `calendarShowDarkmoon` kurz eingeschaltet und zurückgestellt. Prüfung P2: `/broker pruefen kalender` liest mit und ohne Jahrmarkt und nennt beides im Chat (`PeonBrokerDB.calProbe`).
  - Tests: Eintrag lesen, abgelaufene ignoriert, Spekulation aus Preisstufen, Aufkauf prüft Broker selbst, Auswahl Vom Manager, Satz im Fokus, Einschätzung mit Art und Satz, Zeit aus dem Kalender (`test_broker.lua`).
  - **Im Spiel prüfen:** Radar zeigt Spekulation mit Werten des Managers, Erneuern prüft sie live. Auswahl „Vom Manager“ im Radar-Scan. Fokus mit Satz und Alter. `/broker pruefen kalender`: kommen Feste, kommt der Jahrmarkt nur mit der Einstellung? Steht die Einstellung danach wieder wie vorher?

## 0.92.0

Kurz: In der Liste Beobachten steht hinter Kaufen bis und hinter Zielpreis je ein Lautsprecher-Symbol. Ein Klick schaltet die Warnung für diese Grenze je Gegenstand an und aus.

- 0.92.0 (13.11.2026): Symbol für die Warnung je Gegenstand (Anmerkung KarloDerBaer zur Vorabversion).
  - **Zwei neue Spalten** in der Liste Beobachten statt „Üblich“, je ein Lautsprecher hinter Kaufen bis und hinter Zielpreis (Blizzards Atlas `voicechat-icon-speaker`, aus: `voicechat-icon-speaker-mute`). Klick auf ein Symbol schaltet die Warnung (Chat und Ton) für diese Grenze des Gegenstands an oder aus, die Zeile wird dabei nicht ausgewählt. Die Tabelle meldet nur die Zeile, darum prüft `P.OverBell` die Maus über den Spaltenköpfen. Hinweis beim Darüberfahren.
  - Gespeichert im Eintrag als `muteDown` und `muteUp` (`Wt.Muted(key, dir)`, `Wt.ToggleMute(key, dir)`), bleibt im Spiel, geht nicht an den Manager. Der Haken „Warnung“ unten schaltet weiter alle Gegenstände ab.
  - Tests: Umschalten, keine Meldung im ausgeschalteten Zustand, Klick auf die Spalte.
  - **Im Spiel prüfen:** Symbole in der Liste sichtbar (kein grünes Kästchen), Klick auf jedes der beiden Symbole schaltet nur seine Grenze um, Klick daneben wählt aus, Doppelklick öffnet weiter den Fokus. Ausgeschalteter Gegenstand erreicht Kaufen bis: keine Meldung.

## 0.91.0

Kurz: Im Fokus kaufst du mit einem Klick. Nur wenn der Preis höher ist als erwartet, fragt Broker mit einem zweiten Klick nach.
Kurz: Beobachten hat ein Fenster Einstellungen: Warnton und Chatnachricht für Kaufen bis und Zielpreis, den Ton auch je Gegenstand (Rechtsklick in der Liste).
Kurz: Gekauftes wird nur noch zum Wiedereinstellen gemerkt, wenn du das willst. Der Haken „Wieder einstellen“ im Fokus gilt je Gegenstand.
Kurz: Neu im Gegenstandsmenü: „Chance einschätzen“ mit schlecht, mittel oder gut und einer Bemerkung.
Kurz: Im Diagramm des Fokus steht Kaufen bis als blaue Linie, die Menge ist grau.

- 0.91.0 (13.11.2026): Wünsche und Fehler aus den Fehlerberichten (KarloDerBaer, 13.11.2026).
  - **Kaufen mit einem Klick** (`Radar.lua`, `R.OnPriceUpdated`): Nur der Start eines Kaufs von Massenware braucht einen echten Klick (`StartCommoditiesPurchase` hat Einschränkungen), die Bestätigung nicht (nachgelesen in `AuctionHouseDocumentation.lua`, Zweig forever). Kommt der Preis vom Spiel und liegt der Gesamtpreis in der Toleranz (`focusPriceTol`), bestätigt Broker selbst. Sonst bleibt es bei „Bestätigen“ mit Warnung. Gilt für den Kaufknopf im Fokus und die Taste.
  - **Einstellungen Beobachten** (`Settings.lua`, `Watch.lua`): Neuer Knopf „Einstellungen“ unten auf der Seite Beobachten. Je Richtung (Kaufen bis erreicht, Zielpreis erreicht) ein Ton (`watchSoundDown`, `watchSoundUp`, auch „Kein Ton“) und ein Haken für die Chatnachricht (`watchChatDown`, `watchChatUp`). Das Einstellungsfenster kennt dafür die neue Zeile `choice` (Auswahlliste, spielt den Ton beim Wählen ab). Der Haken „Warnung“ schaltet weiter alles ab. Der Ton hängt nicht mehr am Ton des Radars.
  - **Ton je Gegenstand:** Rechtsklick auf einen Gegenstand unter Beobachten, Untermenüs „Ton bei Kaufen bis“ und „Ton beim Zielpreis“ mit „Wie eingestellt“, „Kein Ton“ und den Tönen. Gespeichert im Eintrag (`sDown`, `sUp`), geht nicht an den Manager.
  - **Wiedereinstellen merken** (`Lots.lua`, `LT.Wanted`): Ein Kauf wird nur noch ein Posten, wenn es für den Gegenstand eingeschaltet ist. Haken „Wieder einstellen“ im Fokus rechts neben dem Urteil, gespeichert je Gegenstand in `PeonBrokerDB.relist`. Die Vorgabe für alle Gegenstände steht in den Einstellungen des Fokus (`relistDefault`, Standard aus). Gilt für alle Käufe (auch Aufkäufe aus dem Radar), abgebrochene Auktionen werden weiter immer gemerkt.
  - **Chance einschätzen** (neue Datei `Rating.lua`): Eintrag im Gegenstandsmenü (Strg+Rechtsklick, Rechtsklick in Brokers Listen und im Radar). Ein kleines Fenster mit Auswahl schlecht, mittel, gut und einer Bemerkung. Gespeichert in `PeonBrokerDB.ratings` (höchstens 500) mit Zeit, Markt, Preisdaten des Gegenstands, den Werten des Radar-Vorschlags (falls er gerade vorgeschlagen wird oder eben weggefallen ist) und ob er im Fokus stand. Die Auswertung im Peon Manager kommt später.
  - **Diagramm im Fokus** (`Focus.lua`): Kaufen bis als blaue waagrechte Linie, die Balken der Menge unter Ziel grau. Legende angepasst.
  - **Listen umbenennen** (`Buy.lua`): Das Feld Name unter Einkaufen wurde bei jeder Antwort des Auktionators neu gefüllt, der getippte Name ging verloren. Jetzt bleiben Name und Rabatt stehen, solange man darin tippt. Enter übernimmt den Namen.
  - **Bereich Beobachten** für Rückmeldungen (Peon_Feedback und Manager).
  - Tests: Ein-Klick-Kauf und Preiswarnung, Posten nur mit Haken, Töne je Richtung und Gegenstand, Fenster Einstellungen Beobachten, Einschätzung, Bereiche.
  - **Im Spiel prüfen:** Im Fokus einmal Kaufen: Der Kauf läuft ohne zweiten Klick durch. Beobachten, Einstellungen: Töne wählen (spielen beim Wählen), OK. Rechtsklick auf einen Gegenstand unter Beobachten, Ton ändern. Fokus: Haken „Wieder einstellen“ an einem Gegenstand, kaufen, Posten erscheint. Ohne Haken kein Posten. Strg+Rechtsklick, „Chance einschätzen“, speichern. Diagramm: blaue Linie bei Kaufen bis. Einkaufen: Namen einer Liste ändern, während der Auktionator antwortet.

## 0.90.0

Kurz: Beobachtungen, die ein älterer Peon Manager ohne Kaufen bis und Zielpreis schickt, überschreiben deine Grenzen im Spiel nicht.

- 0.90.0 (13.11.2026): Gleiche Regel wie Manager 0.34.0. Kommt eine Beobachtung aus dem Manager nur als Zahl (Manager vor 0.30), bekommt ein neuer Eintrag für Kaufen bis und Zielpreis die Zeit 0 (`Wt.Merge`). So gilt jede Grenze, die später kommt.
  - Tests: Vergleich mit dem Manager (`watch_compare.lua`, 3000 Fälle) mit der neuen Regel.

## 0.89.0

Kurz: Änderst du an einer Einkaufsliste im Spiel und im Peon Manager verschiedene Werte, bleiben jetzt beide erhalten.
Kurz: Kaufen bis und Zielpreis der Beobachtung gleichen sich jetzt auch mit dem Peon Manager ab.

- 0.89.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A2 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 3.2 bis 3.4). Braucht Manager 0.30.
  - **Abgleich je Wert** (`Shop.lua`): Name und Rabatt einer Liste, Menge und Höchstpreis eines Eintrags tragen ihre eigene Zeit in `t`, die neuere gewinnt (`S.MergeFields`). Ohne `t` (Daten von vor 0.89) gilt `u` für alle Werte, das verhält sich wie bisher. Name, Qualität und Symbol werden nur ergänzt, wo sie fehlen. Eigene Änderungen vermerkt `B.Touch(obj, Wert)` über `S.Stamp`.
  - **Beobachtung je Wert** (`Watch.lua`): Kaufen bis (`lim` oder `pct`, Zeit `t.buy`) und Zielpreis (`up`, Zeit `t.up`) gehen mit dem Manager hin und zurück. Der reine Abgleich steht in `Wt.Merge`, ein neuer Wert aus dem Manager setzt den Merker des Alarms zurück. Ein Manager vor 0.30 schickt nur eine Zahl, dann zählt nur, ob beobachtet wird.
  - **Löschmarken halten ein Jahr** statt 60 Tage.
  - Tests: Jahr der Löschmarken und Abgleich je Wert in `test_broker.lua`. Im Manager vergleichen `shop_compare.lua` und `watch_compare.lua` je 3000 Zufallsfälle mit den Regeln in JavaScript.
  - **Im Spiel prüfen:** Unter Beobachten Kaufen bis und Zielpreis setzen, `/reload`: Beides steht im Manager. Im Manager eine Grenze ändern, `/reload`: Sie ist im Spiel.

## 0.88.0

Kurz: Bei Kisten mit Paketauswahl kannst du das günstigste Paket über das Peon-Menü (Strg+Rechtsklick) auf die Einkaufsliste „Handelsauftrag“ setzen.

- 0.88.0 (13.11.2026): Paket auf die Einkaufsliste (Wunsch von KarloDerBaer).
  - Im Peon-Gegenstandsmenü steht bei einer Kiste mit Paketliste ganz oben „Auf „Handelsauftrag“: 16× Kupferrohre“. Der Eintrag setzt das günstigste Paket mit seiner Menge auf die Liste „Handelsauftrag“, die bei Bedarf angelegt wird. Wie bei den Materialien aus dem Berufsfenster ist die Menge der Wunsch, was fehlt, rechnet die Liste selbst gegen den Vorrat. Zweimal ausgewählt bleibt es ein Eintrag.
  - Liegt das günstigste Paket schon ganz in den Taschen oder hat kein Paket einen Preis, gibt es keinen Eintrag.
  - Unter dem Paketvergleich im Tooltip steht ein grauer Hinweis auf das Menü.
  - Ein einfacher Rechtsklick benutzt die Kiste, darum das Menü (mit KarloDerBaer abgestimmt).
  - Neu in `Pack.lua`: `P.Remember`, `P.ForItem`, `P.Best`, `P.ToList`, `P.AddMenu`. `Menu.lua` ruft `P.AddMenu` zuerst auf.
  - Tests: Hinweis im Tooltip, Menüpunkt, Liste angelegt, zweimal ausgewählt, Paket schon vorhanden.
  - **Im Spiel prüfen:** Strg+Rechtsklick auf eine Abgefangene Kiste: oben steht das günstigste Paket. Anklicken: Meldung im Chat, unter Einkaufen gibt es die Liste „Handelsauftrag“ mit dem Teil und der Menge.

## 0.87.3

Kurz: Der Paketvergleich findet jetzt auch Teile, deren Name in deinen Preisdaten fehlte, zum Beispiel den Großen leuchtenden Splitter.

- 0.87.3 (13.11.2026): „kein Preis“ beim Großen leuchtenden Splitter, obwohl Broker einen Preis hat.
  - Im Heimatmarkt fehlte bei rund einem Fünftel der Einträge der Name (etwa bei Daten aus dem Peon Manager). Das Namensverzeichnis entsteht jetzt aus allen Märkten (`P.BuildIndex`), der Preis kommt weiter aus dem Heimatmarkt.
  - Wird ein Name trotzdem nicht gefunden, fragt Broker für Einträge ohne Namen einmal das Spiel (`P.FillHome`, je Gegenstand höchstens zweimal je Sitzung) und merkt sich gefundene Namen im Eintrag.
  - Die Paketliste selbst nennt keine Gegenstandsnummern, nur Text. Deshalb bleibt es beim Vergleich über den Namen.
  - Tests: Name nur in einem anderen Markt, Name vom Spiel nachgefragt. Mit den echten Daten geprüft: alle sieben Teile beider Kisten gefunden.
  - **Im Spiel prüfen:** `/reload`, Kiste des Gesellen: auch die großen leuchtenden Splitter haben einen Preis.

## 0.87.2

Kurz: Der Paketvergleich findet jetzt auch Teile wie „kleine leuchtende Splitter“, und das günstigste Paket hat einen grünen Haken statt eines leeren Kastens.

- 0.87.2 (13.11.2026): Zwei Fehler aus dem ersten Test im Spiel.
  - Hinter dem günstigsten Paket stand ein leerer Kasten, weil die Schrift des Spiels das Zeichen „←“ nicht kennt. Jetzt steht dort der grüne Haken der Bereitschaftsabfrage (`P.BEST_ICON`).
  - Gebeugte Namen wurden nicht gefunden: „kleine leuchtende Splitter“ in der Liste, „Kleiner leuchtender Splitter“ im Scan. `P.Norm` nimmt jetzt jedem Wort die Endung (`P.Stem`) und macht Ä, Ö, Ü am Anfang klein. Mit den echten Scan-Daten geprüft: über 23.000 Namen, keine zwei fallen zusammen.
  - Tests: gebeugte Wörter, Mehrzahl mit Adjektiv, Umlaut am Anfang, verschiedene Teile bleiben verschieden, kein Pfeilzeichen.
  - **Im Spiel prüfen:** `/reload`, Kiste des Gesellen: alle vier Pakete mit Preis, Haken hinter dem günstigsten.

## 0.87.1

Kurz: Der Paketvergleich im Tooltip erscheint jetzt auch wirklich, zum Beispiel bei der Abgefangenen Kiste.

- 0.87.1 (13.11.2026): Paketvergleich blieb im Spiel leer.
  - Die Paketliste steht im Spiel mit Zeilenumbrüchen in einer einzigen Tooltip-Zeile („Benutzen: … Liste:“ und darunter die Pakete). `Pack.lua` teilt solche Texte jetzt in Zeilen.
  - Namen werden ohne Leerzeichen, Bindestriche und Artikel verglichen (`P.Norm`): „Handvoll Kupferbolzen“ aus der Liste passt zu „Eine Hand voll Kupferbolzen“ aus dem Scan.
  - Findet Broker eine Liste, aber kein Teil, steht das in der Fehlersuche (`/broker debug`).
  - Tests: Liste in einer Zeile, Namensvergleich, Test-Kiste wie im Spiel.
  - **Im Spiel prüfen:** `/reload`, dann mit der Maus auf die Abgefangene Kiste.

## 0.87.0

Kurz: Bei Kisten, für die du eines von mehreren Paketen abgeben musst, zeigt der Tooltip jetzt, was jedes Paket kostet. Was du schon in den Taschen hast, zählt als kostenlos. Das günstigste Paket steht oben und ist grün markiert.

- 0.87.0 (13.11.2026): Paketvergleich im Tooltip (Wunsch von KarloDerBaer).
  - Neue Datei `Pack.lua`: liest Zeilen wie `- 16 Kupferrohre` aus dem Tooltip (ab zwei Paketen), sucht die Teile über den Namen in den Scan-Daten des Heimatmarkts (auch Mehrzahl wie „Kupferrohre“ zu „Kupferrohr“), sonst über das Spiel. Preis je Stück wie im Berufsfenster (günstigster Kaufpreis bei Händler oder AH). Liegt ein Teil in den Taschen, zählt nur der fehlende Rest.
  - Block „Broker · Pakete (Kosten)“ unter den Preiszeilen, günstigstes zuerst und grün mit Pfeil, Pakete ohne Preis am Ende.
  - Neuer Schalter unter Preise im Tooltip: „Pakete vergleichen“ (`tooltipPacks`, an).
  - Tests: Zeilen lesen, Namen in der Mehrzahl, Rechnung mit Taschenbestand, Tooltip und Schalter in `test_broker.lua`.
  - **Im Spiel prüfen:** Mit der Maus auf eine Abgefangene Kiste: Unter den Preiszeilen stehen die drei Pakete mit Kosten, das günstigste oben. Teile in die Taschen legen: Das Paket zeigt „vorhanden“ oder nur noch den fehlenden Rest.

## 0.85.0

Kurz: Broker merkt sich eine Kennung für dein WoW-Konto. Damit hält der Peon Manager Einkaufslisten und Beobachtung je Konto auseinander.

- 0.85.0 (13.11.2026): Angleichung des Managers, Bauabschnitt A1 (Konzept `docs/konzepte/manager/Peon_Manager_Angleichung.md` 3.1).
  - Neue Schnittstelle `mod:AcctId()`: zufällige Kennung des Kontos, angelegt beim ersten Laden und danach nie geändert (`PeonBrokerDB.acct`). Das Spiel kennt den Namen des Kontoordners nicht, der Manager ordnet über die Kennung zu.
  - Tests: Kennung bleibt gleich (`test_bridge.lua`).
  - **Im Spiel prüfen:** nichts zu sehen. Nach `/reload` steht `acct` in `Peon_Broker.lua`, und das Konto erscheint im Manager unter Datenlage, Konten.

## 0.84.0

Kurz: Auf der Seite Gegenstand steht unter „Mein Bestand“ jetzt auch, was du zuletzt bezahlt und zuletzt bekommen hast (mit Peon_Ledger).

- 0.84.0 (12.11.2026): Für den Neuaufbau von Ledger 0.14.0 (Bauabschnitt E6).
  - Neue Schnittstelle `mod:ShowItem(id)`: Seite Gegenstand mit diesem Gegenstand (über `Go.Item`). Ledger öffnet sie bei Klicks und mit `/ledger <Name>`, weil es keine eigene Gegenstandsseite mehr hat.
  - „Mein Bestand“ zeigt „Zuletzt gezahlt“ und „Zuletzt verkauft“ mit Menge und Datum (`mod:LastBuy`, `mod:LastSale` aus Ledger).
  - Händlerpreise: Der letzte Kauf laut Ledger kommt aus `mod:LastBuy` (Quelle Händler), `mod:VendorBuy` bleibt als Rückfall für ältere Ledger.

## 0.83.0

Kurz: Unter Beobachten aktualisiert Broker am Auktionator laufend alle Preise, solange der Reiter offen ist. Alarme kommen sofort, die Spalte Stand zeigt das Alter, und eine Zeile leuchtet kurz auf, wenn sie jetzt zum Kaufen oder Verkaufen rät.
Kurz: Ein Haken unter Beobachten schaltet die Warnung im Chat und den Ton ab.
Kurz: Unter Beobachten wählt ein Klick den Gegenstand aus, ein Doppelklick öffnet ihn im Fokus. Der neue Knopf „Verkaufen“ legt den gewählten Gegenstand aus der Tasche in Blizzards Verkaufsfenster.
Kurz: Im Fokus setzt jetzt ein Linksklick auf eine Preisstufe „Kaufen bis“, ein Rechtsklick den Zielpreis.
Kurz: Neue Standardwerte für Radar und Fokus, zum Beispiel 90 Abfragen pro Minute im Fokus und Aufkauf erst ab 500 Stück.

- 0.83.0 (12.11.2026): **Beobachten laufend, Klicks im Fokus, neue Standardwerte** (Rückmeldung nach der Vorabversion v2026.11.12-test).
  - **Beobachten:** Solange der Reiter am Auktionator offen ist, fragt die Abfrage-Schleife (Radar.lua) alle beobachteten Gegenstände reihum ab, so schnell es geht, der am längsten nicht abgefragte zuerst (`R.Watching`, `R.NextWatch`). Jede Antwort aktualisiert den Preis, prüft die Alarme (`Watch.Check`) und zeigt die Liste neu. Neue Spalte „Stand“ (jetzt, vor X Sek., vor X Min.), rechts oben „Aktualisiert laufend“ mit wanderndem Punkt (. .. ..., alle 0,4 Sek.), unterwegs der Hinweis, dass es nur am Auktionator geht. Eine Zeile leuchtet 1,5 Sek. auf, wenn ihr Rat neu KAUFEN (grün) oder VERKAUFEN (gold) wird, sonst keine Hintergrundfarbe (Wunsch KarloDerBaer: eine wandernde Markierung war zu unruhig).
  - **Klicks unter Beobachten** (Wunsch KarloDerBaer): Klick wählt aus (für Verkaufen, Im Markt zeigen und Entfernen), Doppelklick öffnet den Fokus, Rechtsklick weiter das Menü. Hinweis links oben „Klick: auswählen, Doppelklick: Im Fokus öffnen“. Laufende Antworten tauschen die Daten der Liste nicht mehr aus, sondern füllen die vorhandenen Zeilen neu. Vorher konnte ein Austausch zwischen Drücken und Loslassen der Maustaste den Klick verschlucken.
  - **Knopf „Verkaufen“** unten (sicherer Knopf `PeonBrokerWatchSellButton`, wie „Ins Verkaufsfenster legen“ bei den Posten): Makro `/click <Taschenplatz> RightButton`, Blizzards eigener Code wechselt auf Verkaufen und legt den Gegenstand hinein. Vorher blendet Broker seinen Reiter aus. Gesperrt ohne Auswahl, unterwegs, ohne den Gegenstand in der Tasche und ohne Taschenplatz mit Namen, der Tooltip nennt den Grund. Broker schaltet Blizzards Ansicht nicht selbst um (Fehlerberichte 10 und 11).
  - **Haken „Warnung“** unten links (`watchAlarm`, Vorgabe an): aus heißt keine Meldung im Chat und kein Ton. Treffer werden trotzdem gemerkt (Rat und Zahl am Reiter).
  - **Fokus:** Linksklick auf eine Preisstufe setzt „Kaufen bis“ (blau), Rechtsklick den Zielpreis (gelb). Bisher umgekehrt. Hinweise neben den Feldern getauscht, Farben bleiben.
  - **Standardwerte** nach KarloDerBaers Einstellungen: Händler-Mindestgewinn 1s (bisher 10c), Aufkauf ab 500 Stück (200), 4 Preisstufen (5), 270 Absatz am Tag (50), Fokus 90 Abfragen pro Minute (12), erstes Urteil nach 10 Sek. (30), sicher nach 60 Sek. (120), Kaufen ab 10 % mehr Abfluss (20 %), Radar-Scan Massenware (Beobachten). Gespeicherte Werte bleiben, wer von 0.40 kommt, bekommt die neuen Werte für alles außer dem Händler-Mindestgewinn.
  - Tests: Prüfung der neuen Standardwerte, die älteren Tests rechnen weiter mit den Werten bis 0.82. Neuer Block „Beobachten laufend“.
  - **Im Spiel prüfen:** Reiter Beobachten am Auktionator: Preise und Stand laufen, Punkte wandern, Zeile leuchtet bei neuem Rat kurz auf, Alarm kommt, Haken Warnung. Klick wählt, Doppelklick öffnet den Fokus, Verkaufen legt den Gegenstand ins Verkaufsfenster. Klicks im Fokus.

## 0.82.0

Kurz: Beobachten ist wieder ein eigener Reiter. Ein Klick auf einen Gegenstand öffnet ihn im Fokus mit seinem „Kaufen bis“ und Zielpreis.
Kurz: Im Fokus gibt es „Speichern“ (in die Beobachtung, mit Kaufen bis und Zielpreis) und „Zurück“ (zum Radar oder zu Beobachten).
Kurz: Gegenstand steht jetzt unter Mehr. Zahlen an den Reitern erscheinen als roter Kreis.

- 0.82.0 (12.11.2026): **Beobachten und Fokus** (Wunsch KarloDerBaer, 12.11.2026). Neue Datei `WatchPage.lua`.
  - **Reiter Beobachten** zwischen Einkaufen und Radar: Gegenstand, Preis (günstigstes Angebot), Kaufen bis, Zielpreis, Üblich, Rat (KAUFEN, wenn der Preis auf oder unter Kaufen bis liegt, VERKAUFEN, wenn er auf oder über dem Zielpreis liegt). Klick öffnet den Gegenstand im Fokus, Rechtsklick das Menü, unten Im Markt zeigen und Entfernen. Die Zahl am Reiter zählt KAUFEN und VERKAUFEN. In Einkaufen steht die Beobachtung nicht mehr. Der Zielpreis ist die bisherige Grenze nach oben (`up`, Meldung, wenn der Preis darüber liegt), „Verkaufen ab“ entfällt.
  - **Fokus:** „Ziel“ heißt jetzt „Zielpreis“. Aus Beobachten (und bei jedem Öffnen, das nicht aus dem Radar kommt) gelten die gespeicherten Werte als eigene Werte, die Art heißt dann „Beobachten“, nach einer Änderung „Eigenes Ziel“. Neu unten: „Zurück zu Radar“ oder „Zurück zu Beobachten“ (je nach Herkunft, ohne Radar immer Beobachten) und „Speichern“ (legt den Gegenstand unter Beobachten an oder aktualisiert ihn mit Kaufen bis als Grenze nach unten und Zielpreis). Der Zurück-Knopf in der Titelleiste entfällt für den Fokus. Üblich, Verkauft in und Risiko stehen enger.
  - **Gegenstand unter Mehr** (erster Unterpunkt). Reiter unten: Markt, Verkaufen, Auktionen, Einkaufen, Beobachten, Radar, Fokus, Mehr. Sprünge zum Gegenstand öffnen Mehr mit Gegenstand.
  - **Zahlen an den Reitern als roter Kreis** (`Peon.UI.Badge`, wie im UI-Design), am Auktionshaus auch bei Blizzards Reiter Verkaufen. Vorher „Einkaufen (1)“ im Text. Blinken lässt jetzt den Kreis pulsieren.
  - **Einkaufen:** Spalte „Günstigst“ heißt „Preis“.
  - Tests: 25 neue oder geänderte Prüfungen.
  - **Im Spiel prüfen:** Passen die acht Reiter unten in die Breite? Reiter Beobachten, Klick in den Fokus mit Werten, Speichern, Zurück. Gegenstand unter Mehr. Rote Kreise an Einkaufen, Beobachten, Radar und Verkaufen.

## 0.81.1

Kurz: Im Fokus bleibt ein eigener Wert bei „Kaufen bis“ jetzt im Feld stehen, statt zu verschwinden.

- 0.81.1 (12.11.2026): **Fehler im Fokus** (KarloDerBaer, 12.11.2026): Nach jeder Eingabe füllte der Fokus die Felder mit den geltenden Werten. Bei „Kaufen bis“ war das die teuerste gekaufte Stufe statt des eigenen Werts. Lag der eigene Wert unter dem günstigsten Angebot, wurde das Feld leer, lag er zwischen zwei Stufen, sprang es auf die Stufe darunter. Jetzt zeigen die Felder eigene Werte so, wie man sie eingetragen hat.
  - Tests: 2 neue Prüfungen.
  - **Im Spiel prüfen:** Kaufen bis von Hand eintragen, auch einen Wert zwischen zwei Stufen und einen unter dem günstigsten Angebot.

## 0.81.0

Kurz: Nach dem Update zeigt Broker einmal einen Hinweis zum Neuaufbau, zum neuen Aufkauf und zum anstehenden Umbau von Ledger. `/peon neu` zeigt ihn wieder.

- 0.81.0 (12.11.2026): **Einmaliger Hinweis zum Neuaufbau** über `mod:AddNotice` (Kern-API 20, Peon 0.20.0). id `broker:umbau-2026-11`. Texte `NOTICE_REBUILD_TITLE` und `NOTICE_REBUILD_TEXT` (deutsch und englisch). Mit älterem Kern erscheint kein Hinweis, sonst läuft alles wie bisher.
  - Nach ein paar Versionen wieder entfernen.
  - **Im Spiel prüfen:** Hinweis nach dem Einloggen, Text vollständig lesbar, nach `/reload` nicht wieder.

## 0.80.0

Kurz: Die aktuellen Preise vom Peon Manager (zum Beispiel aus der Blizzard-API) kommen jetzt auch für das neutrale Auktionshaus an, nicht nur für die eigene Fraktion.

- 0.80.0 (12.11.2026): **Stand vom Manager auch für den neutralen Markt** (Frage KarloDerBaer, 12.11.2026). Beim Anmelden übernimmt Broker den neuesten Stand des Managers für Heimatmarkt und neutralen Markt (`Data.ApplyManagerAll`). Bisher nur für den Markt, in dem man gerade stand, beim Anmelden praktisch immer die Heimat. Üblicher Bereich und Absatz kamen schon vorher für jeden Markt. Den neutralen Markt legt Broker nur an, wenn der Manager Werte für ihn hat. Voraussetzung im Manager: Dem neutralen Markt ist unter Quellen ein Blizzard-Haus zugeordnet.
  - Tests: 4 neue Prüfungen (test_bridge).
  - **Im Spiel prüfen:** Nach dem Anmelden unter Mehr, Neutral und in der Zeile „Neutral“ im Tooltip das Alter der Preise (so alt wie der Stand der Blizzard-API).

## 0.79.0

Kurz: Der Aufkauf rechnet nicht mehr gegen einzelne überteuerte Angebote. Gekauft wird nur bis zur oberen Grenze des üblichen Bereichs, das Ziel liegt höchstens 20 % darüber (einstellbar). Ohne üblichen Bereich gibt es keinen Aufkauf.

- 0.79.0 (12.11.2026): **Aufkauf nur im üblichen Bereich** (Rückmeldung KarloDerBaer, 12.11.2026, Beispiel Langzahniger Matschschnapper: Ziel 1s 8c bei üblich 7c bis 10c, 687 Stück samt der Stufen zu 40c bis 1s 5c).
  - „Kaufen bis“ einer Aufkauf-Chance liegt nie über der oberen Grenze des üblichen Bereichs.
  - Das Ziel liegt höchstens `buyoutTargetPct` über dieser Grenze (Vorgabe 20 %, 0 bis 200, Radar-Einstellungen unter Aufkauf).
  - Ohne üblichen Bereich keine Aufkauf-Chance (Grund `band`). Bisher war das nur ein Punkt beim Risiko.
  - Gilt nur für Chancen aus dem Radar. Ein eigenes Ziel oder „Kaufen bis“ im Fokus gilt ohne diese Grenzen.
  - Tests: 4 neue Prüfungen mit dem Beispiel aus dem Spiel.
  - **Im Spiel prüfen:** Radar zeigt keine Aufkäufe mehr mit Zielen weit über dem üblichen Bereich. Einstellung „Ziel höchstens über üblich“.

## 0.78.0

Kurz: Im Fokus steht „Menge, Kosten, Gewinn“ über dem Kaufknopf jetzt immer, auch wenn der Knopf grau ist.

- 0.78.0 (12.11.2026): **Zeile über dem Kaufknopf immer sichtbar** (Wunsch KarloDerBaer, 12.11.2026). Auch bei grauem Knopf (zu wenig Gold, nichts unter dem Ziel, Chance vorbei, unterwegs) stehen Menge, Kosten und Gewinn da, ohne Werte mit Strichen. Während eines Kaufs steht dort wie bisher der Stand des Kaufs. Unbenutzte Texte entfernt.
  - Tests: 2 neue Prüfungen.
  - **Im Spiel prüfen:** Zeile bleibt bei grauem Knopf, zum Beispiel mit einem Ziel, unter dem nichts angeboten wird.

## 0.77.0

Kurz: Die linke Seite im Fokus ist neu geordnet: Art mit „Auto“, Ziel und Kaufen bis als Eingabefelder, darunter Üblich, Verkauft in und Risiko. Menge, Kosten und Gewinn stehen mittig über dem Kaufknopf.
Kurz: Rechts sind die Angebote, die gekauft werden, blau hinterlegt, die Stufe des Ziels gelb.

- 0.77.0 (12.11.2026): **Fokus neu geordnet** (Wunsch KarloDerBaer, 12.11.2026).
  - Reihenfolge links: Urteil mit Satz, Leerzeile, Art mit Knopf „Auto“ dahinter (setzt Ziel und Kaufen bis und damit die Art zurück), Ziel mit Eingabefeld und „Linksklick“ (gelb), Kaufen bis mit Eingabefeld und „Rechtsklick“ (blau), Leerzeile, Üblich, Verkauft in, Risiko (mit Gründen im Tooltip), Leerzeile, „Menge: … Kosten: … Gewinn: …“ mittig über dem Kaufknopf, Kaufknopf, Im Markt zeigen und Gegenstand.
  - Aus der Liste entfallen Kaufen bis, Menge, Einsatz, Ziel und Gewinn (stehen in den Feldern oder über dem Knopf).
  - Die Eingabefelder zeigen immer die Werte, die gerade gelten, auch die einer Chance aus dem Radar. Wer ein Feld ändert, bekommt die Art „Eigenes Ziel“. Während man tippt, überschreibt Broker das Feld nicht.
  - Preisstufen rechts: gekaufte Stufen (bis Kaufen bis) blau hinterlegt, die Stufe des Ziels gelb. Der grüne Preistext entfällt. Der Hinweis neben „Markt jetzt“ entfällt (steht jetzt hinter den Feldern).
  - Tests: angepasst.
  - **Im Spiel prüfen:** Anordnung links (nichts überlagert, Felder und Hinweise in einer Zeile), Werte einer Radar-Chance in den Feldern, Feld ändern ergibt „Eigenes Ziel“, „Auto“, blaue und gelbe Zeilen rechts.

## 0.76.0

Kurz: Im Fokus gibt es das Feld „Kaufen bis“. Ein Rechtsklick auf eine Preisstufe setzt es, so kauft man nur bis dorthin und das Ziel bleibt höher.
Kurz: Über dem Kaufknopf im Fokus stehen jetzt Kosten und erwarteter Gewinn nebeneinander.

- 0.76.0 (12.11.2026): **Fokus: Kaufen bis** (Wunsch KarloDerBaer, 12.11.2026).
  - Neues Feld „Kaufen bis“ unter „Eigenes Ziel“. Rechtsklick auf eine Preisstufe setzt es, Linksklick weiter das Ziel. Gekauft werden nur die Stufen bis „Kaufen bis“, die teureren unter dem Ziel bleiben stehen. So lässt sich die Spanne zum Ziel vergrößern. In den Angaben steht „(eigenes)“ hinter Kaufen bis, grün sind nur die gekauften Stufen.
  - „Auto“ nimmt Ziel und Kaufen bis zurück. Ein neuer Gegenstand im Fokus beginnt ohne beides.
  - Über dem Kaufknopf: „Kosten: … Gewinn: …“. Während eines Kaufs steht dort wie bisher der Stand des Kaufs.
  - Hinweis neben „Markt jetzt“: Klick setzt das Ziel, Rechtsklick Kaufen bis.
  - Tests: 4 neue Prüfungen.
  - **Im Spiel prüfen:** Rechtsklick auf eine Stufe, Menge, Kosten und Gewinn passen, Kaufen kauft nur bis dorthin. Feld von Hand, „Auto“.

## 0.75.1

Kurz: Das Diagramm im Fokus zeigt wieder etwas, der Fehler beim Zeichnen ist behoben.

- 0.75.1 (12.11.2026): **Fehlerbericht 13** (`Focus.lua:491: bad argument #2 to 'max'`, 48 mal): Die neue Zahl der Plätze des Diagramms (`F.CHART_SLOTS`) stand in 0.75.0 versehentlich in einer Funktion statt oben in der Datei. Sie war erst nach einem eigenen Ziel gesetzt, davor brach das Zeichnen bei jeder Antwort ab, das Diagramm blieb leer. Jetzt fest gesetzt, das Zeichnen gilt erst nach dem Zeichnen als erledigt.
  - Tests: Diagramm mit zwei Abfragen wird gezeichnet.
  - **Im Spiel prüfen:** Fokus, Diagramm erscheint ab der zweiten Abfrage, Balken bleiben im Rahmen.

## 0.75.0

Kurz: Im Radar zeigen weggefallene Chancen weiter den möglichen Gewinn, „weg“ steht jetzt unter Art.
Kurz: Der Knopf „Angebote“ nach „Im Markt zeigen“ entfällt.

- 0.75.0 (12.11.2026): **Nachbesserungen nach dem dritten Test** (Rückmeldung KarloDerBaer, 12.11.2026).
  - **Diagramm im Fokus:** mindestens 60 Plätze, von links gefüllt (`F.CHART_SLOTS`), und nichts zeichnet über den Rand (`SetClipsChildren`). Mit nur zwei Abfragen war jeder Balken so breit wie das halbe Diagramm und ragte hinaus.
  - **Radar:** Weggefallene Chancen zeigen in der Spalte Gewinn weiter den möglichen Gewinn (grau), „weg“ steht in der Spalte Art. So lässt sich eine solche Chance noch in die Beobachtung übernehmen.
  - **Zum Einstellen:** Spalten werden erst verteilt, wenn die Liste ihre Breite hat (die Überschriften lagen übereinander). Die Fläche ist undurchsichtig, unten schienen Blizzards Zeilen durch.
  - **Knopf „Angebote: <Name>“ entfernt** (Wunsch KarloDerBaer). „Im Markt zeigen“ springt weiter auf Markt und sucht den Gegenstand, steht er schon in der Liste, gehen die Angebote direkt auf. Sonst klickt man selbst auf die Zeile.
  - Tests: angepasst.
  - **Im Spiel prüfen:** Diagramm beim Start einer Messung, ausgegraute Chancen im Radar, Spalten unter „Zum Einstellen“, „Im Markt zeigen“ ohne zusätzlichen Knopf.

## 0.74.0

Kurz: Die Liste der Auktionen deckt Blizzards Ansicht jetzt ganz ab, und keine Broker-Fläche liegt mehr über anderen Reitern wie Einkaufen.
Kurz: Die Einstellungen von Radar und Fokus öffnen in einem großen Fenster mit OK und Abbrechen.
Kurz: Im Fokus steht der übliche Bereich, die Preisstufe des Ziels ist gelb hinterlegt, „Jetzt prüfen“ entfällt.
Kurz: Der Abfluss im Fokus zählt jetzt über die Preisstufen. Vorher sprang er bei Massenware, obwohl sich nichts tat.
Kurz: Während eines Kaufs schickt Broker keine Abfragen mehr. Das soll die Meldung „Interner Auktionsfehler“ verhindern.

- 0.74.0 (12.11.2026): **Nachbesserungen nach dem zweiten Test** (Rückmeldung KarloDerBaer, 12.11.2026). Braucht für die gelbe Zeile Peon 0.19.0 (API 19), läuft ohne sie weiter.
  - **Liste der Auktionen** wie Brokers eigene Reiter: ganze Fläche ab der Titelleiste, undurchsichtig, mit Brokers Statuszeile. Vorher schienen Blizzards Reiter Auktionen/Gebote, Spalten und Knöpfe durch.
  - **Keine Überlagerung mehr:** Die Liste der Auktionen, „Zum Einstellen“ und der Knopf „Angebote“ verschwinden, sobald ein Broker-Reiter offen ist (`AHTabs.PlaceOverlays`). Sie lagen vorher über Einkaufen und den anderen Seiten.
  - **Zum Einstellen** sitzt 40 Punkte weiter links, Blizzards Knopf „Neu laden“ ist wieder frei.
  - **Angebote: <Name>** steht unten rechts in Blizzards Ergebnisliste statt über den Knöpfen Filter und Suchen und verschwindet bei jedem Wechsel der Ansicht und bei Broker-Reitern.
  - **Einstellungen** in einem Fenster so groß wie das Broker-Fenster, über dem Auktionshaus, zwei Spalten, jede Zeile mit Beschriftung links und Feld rechts. Änderungen gelten erst mit OK, Abbrechen und ESC verwerfen sie.
  - **Fokus:** „Jetzt prüfen“ entfällt (er fragt ohnehin laufend). Neue Zeile „Üblich“ mit dem üblichen Bereich aus dem Verlauf. Die Preisstufe des Ziels ist gelb hinterlegt, wenn es dort Angebote gibt (`rowBg`, Kern API 19). Angaben etwas dichter.
  - **Abfluss über Preisstufen** (Massenware): Je Stufe zählt die Menge. Weniger Stück, solange alle günstigeren Stufen auch weniger wurden, ist verkauft. Weniger über einer Stufe, die stehen blieb, ist abgebrochen. Mehr ist neu. Vorher über die Auktionsnummern: Die sind bei Massenware offenbar nicht von Abfrage zu Abfrage gleich, jede neue Nummer zählte als „weg und neu“, der Abfluss sprang. Einzelgegenstände bleiben beim Vergleich der Nummern.
  - **Pause beim Kaufen:** Vom Preis des Spiels (`COMMODITY_PRICE_UPDATED`) bis zum Abschluss (`COMMODITY_PURCHASE_SUCCEEDED/FAILED`, höchstens 15 Sek.) schicken Fokus, Radar und Einkaufen keine Abfragen. Gilt auch für Käufe in Blizzards eigenem Fenster. Vermutung: „Interner Auktionsfehler“ kommt von einer Suche zwischen Preis und Bestätigen.
  - **Meldungen des Auktionshauses merken:** `/broker pruefen fehler` zeigt die letzten 10 mit Zeit, Nummer, Sekunden seit Brokers letzter Abfrage, Gegenstand der Abfrage und ob gerade gekauft wurde (`ahErrors`). Damit lässt sich klären, ob die Meldung von Broker kommt.
  - **Einkaufen:** Haken „Twinks mitzählen“ oben neben dem runden Bild (lag unter „Entfernen“), Formularzeilen etwas eingerückt, damit die grauen Zusätze nicht über den Rand ragen.
  - Tests: 20 neue oder geänderte Prüfungen.
  - **Im Spiel prüfen:**
    1. Auktionen: nichts von Blizzard scheint durch, danach auf Einkaufen wechseln: sauber?
    2. Verkaufen: „Zum Einstellen“ links neben Blizzards Knopf Neu laden.
    3. Im Markt zeigen: Knopf „Angebote“ unten rechts in der Liste, verschwindet beim Wechsel.
    4. Einstellungen von Radar und Fokus: großes Fenster, nichts überlagert, OK und Abbrechen.
    5. Fokus: Zeile „Üblich“, gelbe Zielstufe, Abfluss bleibt ruhig, wenn sich an den Stufen nichts ändert.
    6. Kaufen: kommt „Interner Auktionsfehler“ noch? Wenn ja, danach `/broker pruefen fehler` und das Ergebnis an Claude.
    7. Einkaufen: Haken oben, nichts überlagert.

## 0.73.0

Kurz: „Im Markt zeigen“ springt am Auktionshaus jetzt selbst auf Blizzards Markt. Steht der Gegenstand schon in der Liste, gehen seine Angebote sofort auf, sonst erscheint über der Liste der Knopf „Angebote: <Name>“.

- 0.73.0 (12.11.2026): **Nachbesserungen Stufe 2, Schritt 6: Sprung zum Markt mit sicherem Knopf** (Wunsch KarloDerBaer, 12.11.2026).
  - **Sicherer Knopf** (`Go.MarketButton`, `SecureActionButtonTemplate` mit der Art „click“): Er reicht den Klick des Spielers an Blizzards eigenen Knopf weiter, Blizzard schaltet in seinem eigenen Code um. Broker selbst ruft weiter weder `SetDisplayMode` noch `SelectBrowseResult` auf (Fehlerberichte 10 und 11).
  - **Ablauf:** Steht der Gegenstand schon in Blizzards Ergebnisliste, klickt der Knopf diese Zeile an, die Angebote gehen sofort auf. Sonst klickt er Blizzards Reiter „Markt“, Broker sucht den Gegenstand (wie seit 0.64.1), und sobald die Zeile da ist, erscheint über Blizzards Liste der Gold-Knopf „Angebote: <Name>“ (ebenfalls sicher, 20 Sek. lang). Blizzards Liste liest Broker nur.
  - **Wo:** Fokus, Gegenstand, Einkaufen (Kaufzeile) und die neue Liste der Auktionen. Menüs und Doppelklick in Listen gehen weiter den bisherigen Weg (Menüeinträge können keine sicheren Knöpfe sein). Unterwegs und im Kampf bleibt es beim bisherigen Weg.
  - Sichere Knöpfe sind für Drücken und Loslassen angemeldet, Broker handelt nur bei dem Teil, bei dem das Spiel die Aktion ausführt (Einstellung `ActionButtonUseKeyDown`).
  - Tests: 8 neue Prüfungen.
  - **Im Spiel prüfen (wichtig, wie bei Fehlerbericht 10):**
    1. Fokus oder Gegenstand: „Im Markt zeigen“. Springt Blizzard auf Markt? Kommt der Knopf „Angebote: …“, öffnet er die Angebote?
    2. Dasselbe noch einmal, wenn der Gegenstand schon in der Liste steht: öffnen die Angebote direkt?
    3. Danach eine Schriftrolle oder einen anderen nicht verkaufbaren Gegenstand aus der Tasche benutzen, auch nach dem Schließen des Auktionshauses: keine Meldung „Aktion wegen AddOn blockiert“?

## 0.72.0

Kurz: Unter Auktionen zeigt Broker jetzt eine eigene Liste deiner Auktionen mit der Spalte Broker (Günstigstes, unterboten, zu teuer, verkauft) und einem Filter zum Ausblenden. Blizzards Ansicht bleibt im Hintergrund, für Gebote gibt es den Knopf „Blizzard-Ansicht“.
Kurz: In der Liste kannst du eine Auktion wählen und abbrechen oder im Markt zeigen.

- 0.72.0 (12.11.2026): **Nachbesserungen Stufe 2, Schritt 5: eigene Liste der Auktionen** (Anmerkungen KarloDerBaer, 12.11.2026). Neue Datei `AuctionsOwn.lua`.
  - **Liste über Blizzards Ansicht:** eigene Fläche (Ebene 370) über Blizzards Ansicht Auktionen, solange diese offen ist. Blizzards Ansicht bleibt darunter offen und lädt weiter, Broker schreibt nichts hinein.
  - **Spalten:** Gegenstand, Menge, Preis je Stück, Broker (Status als echte Spalte, sortierbar in der Reihenfolge Günstigstes, Gleichauf, Unterboten, Zu teuer, Verkauft), Restzeit (Stunden und Minuten, sonst Blizzards Stufe kurz bis sehr lang).
  - **Filter** (Auswahl mit Haken, mehrfach): Status ausblenden (`aucHide`). Die Zeile oben nennt, wie viele der Filter ausblendet.
  - **Knöpfe:** Prüfen (wie bisher), Blizzard-Ansicht (für Gebote, `aucOwnList` aus, zurück mit „Broker-Liste“ in Blizzards Kopfzeile), Auktion abbrechen (gewählte, wird ein Posten, Ziel ist das günstigste fremde Angebot minus Unterbieten oder ohne fremdes Angebot der bisherige Preis, `Lots.CancelRow`), Unterbotene abbrechen (n), Im Markt zeigen.
  - Daten neu nur bei Änderung (Unterschrift aus Nummer, Status, fremdem Preis), die Uhr der Kopfzeile läuft alle 0,3 Sek.
  - Tests: 9 neue Prüfungen.
  - **Im Spiel prüfen:**
    1. Auktionen: Brokers Liste deckt Blizzards Ansicht ganz ab? Spalten, Sortierung, Filter.
    2. Eine Auktion wählen und abbrechen: kommt sie als Posten unter Verkaufen „Zum Einstellen“?
    3. Blizzard-Ansicht, dort Gebote, zurück mit „Broker-Liste“.

## 0.71.0

Kurz: Aufkauf gilt nur noch für echte Massenware (Vorgabe ab 200 Stück, 5 Preisstufen und 50 Stück Absatz am Tag, einstellbar). Einzelne oder selten angebotene Gegenstände erscheinen nicht mehr als Aufkauf.
Kurz: Der Radar hat ein Fenster „Einstellungen“: welche Möglichkeiten er zeigt (Händler, Aufkauf, Spekulation kommt später) mit ihren Grenzen, und ob die gezeigten Möglichkeiten regelmäßig erneuert werden.
Kurz: Der Knopf „Radar-Scan“ sucht wieder neue Möglichkeiten, wahlweise in der Beobachtung, unter allen Massenwaren oder in allem. Die gezeigten Möglichkeiten werden dabei zuerst erneuert.
Kurz: „Zum Einstellen“ steht jetzt unter Verkaufen über Blizzards Liste. Posten wählen, „Ins Verkaufsfenster legen“ klicken, fertig.

- 0.71.0 (12.11.2026): **Nachbesserungen Stufe 2, Schritte 3 und 4: Radar und Zum Einstellen** (Anmerkungen KarloDerBaer, 12.11.2026).
  - **Aufkauf nur für Massenware:** `Buyout.Find` verlangt mindestens `buyoutMinQty` Stück im Angebot (200, aus dem Scan zählt die ganze Menge, nicht nur die 12 gespeicherten Stufen), mindestens `buyoutMinLevels` Preisstufen (5) und mindestens `buyoutMinSales` Stück Absatz am Tag (50). Grund im Code `mass`. Die Vorauswahl aus dem Scan prüft Menge und Stufen schon vorher. Beispiel aus dem Spiel: Heckenschützen-Zielfernrohr mit 16 Stück in 4 Stufen ist kein Aufkauf mehr.
  - **Arten abschaltbar:** `radarVendorOn`, `radarBuyoutOn` (beide an). Eine abgeschaltete Art wird gar nicht erst gerechnet.
  - **Fenster Einstellungen im Radar:** Händler (an/aus, Gewinn ab), Aufkauf (an/aus, Gewinn ab, wieder verkauft in, Massenware: Menge, Preisstufen, Absatz je Tag), Spekulation (grau, kommt später), Goldreserve, Ton, Erneuern (an/aus, alle, spätestens alle), Anteil des Radar-Scans. Ändern rechnet die Chancen aus der Datenbank neu.
  - **Erneuern** (`radarRenew`, an): Solange die Seite Radar am Auktionator offen ist, prüft Broker jede gezeigte Möglichkeit spätestens nach `radarRenewSec` (60 Sek.) live. Reicht das Budget von etwa 92 Abfragen je Minute nicht, wird der Abstand länger, höchstens `radarRenewMax` (120 Sek.). Die Statuszeile nennt den Abstand.
  - **Radar-Scan wieder als Suche:** Knopf „Radar-Scan“ mit Auswahl daneben (`radarScanMode`): Beobachten (immer wieder die Beobachtung), Massenware (alle bekannten Massenwaren in zufälliger Reihenfolge), Alles (alle bekannten Gegenstände in zufälliger Reihenfolge). Er bekommt, was das Erneuern übrig lässt, mindestens `radarSearchPct` (20 %). Neue Möglichkeiten erscheinen mit Ton wie früher. Die Statuszeile nennt Auswahl, Abfragen je Minute und Fortschritt der Runde.
  - **Zum Einstellen unter Verkaufen:** Der Knopf „Zum Einstellen (n)“ sitzt über Blizzards Angebotsliste rechts und legt Brokers Liste der Posten darüber. Blizzards Liste bleibt darunter unberührt. Klick wählt einen Posten, der Knopf „Ins Verkaufsfenster legen“ darunter ist ein **sicherer Knopf** (`SecureActionButtonTemplate`) mit dem Makro `/click <Taschenplatz> RightButton`. Das ist derselbe Klick wie der Rechtsklick in der Tasche, Blizzards eigener Code legt den Gegenstand hinein. Taschenplätze mit Namen: Peon_Bags (`PeonBagsItemN`), sonst Blizzards `ContainerFrameNItemM`. Ohne passenden Platz steht „Rechtsklick in der Tasche“, mit Ware in der Post „Liegt noch in der Post“, im Kampf „Nicht im Kampf“ (Attribute nur außerhalb des Kampfs). Im Radar gibt es den Knopf nicht mehr.
  - Tests: 30 neue oder geänderte Prüfungen.
  - **Im Spiel prüfen:**
    1. Radar: Zielfernrohr und andere seltene Gegenstände kein Aufkauf mehr. Einstellungen öffnen und Werte ändern.
    2. Radar offen lassen: „erneuert alle … Sek.“ in der Statuszeile, die Spalte Stand springt zurück.
    3. Radar-Scan mit Massenware: neue Möglichkeiten erscheinen, Abfragen je Minute in der Statuszeile.
    4. **Sicherer Knopf (wichtig):** Ware eines Postens in der Tasche, Verkaufen, „Zum Einstellen“, Posten wählen, „Ins Verkaufsfenster legen“. Liegt der Gegenstand danach im Verkaufsfenster? Danach einen nicht verkaufbaren Gegenstand in der Tasche per Rechtsklick benutzen (wie bei Fehlerbericht 10): keine Meldung „Aktion wegen AddOn blockiert“?

## 0.70.0

Kurz: Der Fokus arbeitet nur noch am Auktionshaus und zeigt nur Live-Angebote. Unterwegs merkt er sich den Gegenstand für den nächsten Besuch.
Kurz: Im Fokus kannst du jetzt immer kaufen: Ein Klick auf eine Preisstufe oder ein eigenes Ziel kauft alles darunter, mit Menge, Einsatz, Gewinn und Verkaufsdauer.
Kurz: Der Fokus fragt so oft ab, wie du willst (2 bis 90 Abfragen pro Minute), und hat ein Fenster „Einstellungen“ mit allen Grenzen für das Urteil.

- 0.70.0 (12.11.2026): **Nachbesserungen Stufe 2, Schritt 2: Fokus nur live** (Anmerkungen KarloDerBaer, 12.11.2026). Neue Datei `Settings.lua`.
  - **Nur am Auktionshaus:** Der Reiter Fokus ist unterwegs grau wie Verkaufen (`W.AH_ONLY`). „In den Fokus“ unterwegs (Menü, Klick im Radar) merkt den Gegenstand und sagt, dass der Fokus am Auktionshaus startet.
  - **Nur Live-Daten:** Die Preisstufen rechts kommen aus der letzten Live-Abfrage dieses Besuchs (`Buy.live`, nicht älter als der neue Gegenstand und das Öffnen des Auktionshauses, `Scan.ahShownAt`), nie aus dem Komplettscan. Vor der ersten Antwort steht „Warte auf die erste Live-Antwort“. Die gemerkte Messung für unterwegs wird nicht mehr gezeigt.
  - **Eigenes Ziel und Kaufen ohne Chance:** Feld „Eigenes Ziel“ (Geld eingeben) und Klick auf eine Preisstufe setzen das Ziel, „Auto“ nimmt es zurück. Gekauft wird alles unter dem Ziel (Art „Eigenes Ziel“), mit Kaufen bis, Menge, Einsatz, Gewinn, Verkaufsdauer und Risiko wie beim Aufkauf. Ohne Chance gilt die zweite Preisstufe als Ziel. Kaufen geht auch ohne Gewinn („KEIN GEWINN“ in Orange), nur nicht ohne Menge oder Gold. Der Kauf wird wie ein Aufkauf ein Posten zum Einstellen. Ein neues Ziel beginnt die Messung neu, weil „Menge unter Ziel“ für ein Ziel gilt. Eine eben weggefallene Chance zeigt „VORBEI“, bis man ein eigenes Ziel wählt.
  - **Abfragen pro Minute:** neue Einstellung `focusRate` (2 bis 90, Vorgabe 12 = alle 5 Sek.) ersetzt `focusEvery`. Ein geänderter alter Wert wird umgerechnet. Der Kopf der Messung zeigt den Abstand mit Komma.
  - **Fenster Einstellungen** (Knopf neben „Jetzt prüfen“): Abfragen pro Minute, Messwerte aus den letzten n Minuten (`focusWindow`), erstes Urteil nach (`focusFirst`), sicheres Urteil nach (`focusSure`), Vorsprung des Abflusses (`focusMore`), Menge wächst ab (`focusGrow`), Warnung beim Kauf ab (`focusPriceTol`). Die Werte waren bisher feste Startwerte in `Measure.lua`.
  - **Diagramm** zeichnet nur noch neu, wenn eine neue Abfrage dazukam.
  - Tests: 21 neue oder geänderte Prüfungen.
  - **Im Spiel prüfen:**
    1. Unterwegs: Reiter Fokus grau, „In den Fokus“ meldet sich im Chat.
    2. Am Auktionshaus: Fokus zeigt erst „Warte“, dann live die Preisstufen.
    3. Klick auf eine Preisstufe: Ziel, Menge, Gewinn, Kaufen. Ziel von Hand, „Auto“.
    4. Einstellungen: Abfragen pro Minute auf 30, 60 und 90 stellen und „tatsächlich … Sek.“ im Kopf der Messung ansehen. Ab wann meldet das Spiel Fehler oder bleiben Antworten aus?

## 0.69.0

Kurz: Der Fokus misst jetzt auch Gegenstände, die nicht aus dem Radar kommen (vorher blieb er bei „beginnt mit der nächsten Abfrage“ stehen).
Kurz: „Unterbotene abbrechen“ sitzt unter Auktionen jetzt unten neben Blizzards „Auktionsabbruch“. Die verlorene Einzahlung steht im Tooltip.

- 0.69.0 (12.11.2026): **Nachbesserungen nach dem ersten Test von Stufe 2, Schritt 1** (Anmerkungen von KarloDerBaer, 12.11.2026).
  - **Fokus ohne Messung behoben:** Der Fokus fragte immer mit „Neu laden“ (`RefreshCommoditySearchResults`). Das schickt das Spiel nur ab, wenn es für den Gegenstand schon eine Suche hatte. Bei einem Gegenstand aus dem Menü (Flitzdistel) kam deshalb nie eine Antwort, auch nicht mit „Jetzt prüfen“. Jetzt ist die erste Abfrage eine normale Suche, danach reicht „Neu laden“. Bleibt eine Antwort aus, wechselt Broker den Weg.
  - **Weniger Rechnen je Antwort** (Bildrate im Fokus): Absatz und Trend eines Gegenstands (`Sales.Stats`, `D.Band`) merkt Broker 5 Minuten (`Buyout.CTX_TIME`), statt sie bei jeder Antwort aus dem ganzen Verlauf neu zu rechnen. Die Radar-Liste wird nur gefüllt, wenn sie zu sehen ist, die Seite Fokus nur, wenn sie zu sehen ist.
  - **Zeitmessung:** `/broker pruefen zeit` nennt je Teil (Daten, Rechnen, Liste, Fokus, Diagramm), wie lange er je Antwort im Schnitt und höchstens gebraucht hat, und leert die Messung. Damit lässt sich klären, ob das Diagramm die Bildrate drückt.
  - **Unterbotene abbrechen** steht unten links neben Blizzards „Auktionsabbruch“ statt oben über Blizzards Reitern „Auktionen/Gebote“. Text „Unterbotene abbrechen (n)“, die Einzahlung steht im Tooltip.
  - Tests: 9 neue Prüfungen.
  - **Im Spiel prüfen:**
    1. Flitzdistel (oder einen anderen Gegenstand) über das Menü in den Fokus nehmen: Messung beginnt, Werte erscheinen.
    2. Zielfernrohr aus dem Radar in den Fokus: Bildrate besser? Danach `/broker pruefen zeit` und das Ergebnis an Claude geben.
    3. Auktionen: Knopf unten neben „Auktionsabbruch“, Tooltip mit Einzahlung.

## 0.68.0

Kurz: Hat ein Händler eine Massenware günstiger, warnt Broker in Blizzards Kaufansicht, und Einkaufen zeigt den Rat „HÄNDLER“.
Kurz: Im Berufsfenster setzt „Auf Einkaufsliste“ das fehlende Material für 1, 5, 10 oder 20 Herstellungen auf die Liste „Material“.
Kurz: Die Beobachtung kennt eine Grenze nach oben: Broker meldet, wenn der Preis darüber liegt, und Einkaufen zeigt dann „VERKAUFEN“.

- 0.68.0 (12.11.2026): **Stufe 2, H4 kleine Hilfen** (Konzept Abschnitte 6.4, 6.5, 6.6).
  - **Händler-Warnung beim Kauf** (6.4): In Blizzards Kaufansicht einer Massenware steht unter dem Weiterverkauf „Achtung: Ein Händler verkauft das für … je Stück (Name)“, wenn der Händler günstiger ist als der Stückpreis im Auktionshaus. Preise aus `ns.Merchant.Price`: besuchte Händler, letzter Kauf laut Ledger, sonst die Schätzung für bekannte Reagenzien (markiert „geschätzt“).
  - **Rat „HÄNDLER“ in Einkaufen** (6.4): wenn ein Händler günstiger ist als das günstigste Angebot oder es nur beim Händler gibt. Zählt nicht für die Zahl am Reiter.
  - **Material aus dem Berufsfenster** (6.5): Knopf „Auf Einkaufsliste“ neben „Broker“ im Block unter den Reagenzien, Menü „für 1, 5, 10, 20 Herstellungen“. Fehlendes Material kommt auf die Liste „Material“ (wird bei Bedarf angelegt), Ziel = Menge je Herstellung × Anzahl, „Fehlt“ rechnet die Liste gegen den Vorrat. Was der Händler günstiger hat, ist als Händlerware markiert. Ein vorhandenes Ziel wird nicht kleiner.
  - **Beobachtung für den Verkauf** (6.6): Grenze nach oben (`watch[…].up`): im Menü eines beobachteten Gegenstands „Grenze nach oben (verkaufen)“ mit „jetzt“ und 10, 20, 30 % darüber, in Einkaufen bei der Beobachtung das Feld „Verkaufen ab“. Liegt das günstigste Angebot darauf oder darüber, meldet Broker das einmal im Chat mit Ton (wieder scharf, sobald der Preis darunter fällt), Rat „VERKAUFEN“.
  - Tests: 20 neue Prüfungen.
  - **Im Spiel prüfen:**
    1. Bei einem Händler gewesen (z. B. Faden), dann im Auktionshaus dieselbe Massenware öffnen: Warnung unter dem Weiterverkauf?
    2. Einkaufen mit so einem Gegenstand: Rat „HÄNDLER“.
    3. Berufsfenster: Knopf „Auf Einkaufsliste“ sichtbar, ohne die Twinks-Haken zu verdecken? Menü, Liste „Material“ mit sinnvollen Zielen.
    4. Beobachtung: Grenze nach oben setzen (Menü und Feld), Meldung, wenn der Preis darüber liegt.

## 0.67.0

Kurz: Jeder Aufkauf aus dem Radar wird ein Posten. Im Radar zeigt „Zum Einstellen“ alle Posten mit Einsatz, Ziel, Marktpreis und ob die Ware schon in der Tasche ist. Die Statuszeile und der Reiter Verkaufen nennen die Zahl.
Kurz: Liegt ein Posten im Verkaufsfenster, nennt der Rat Einsatz und Ziel, warnt, wenn der Markt darunter liegt, und schreibt mit „Zielpreis eintragen“ den Zielpreis ins Preisfeld.
Kurz: Unter Auktionen bricht „Unterbotene abbrechen“ mit jedem Klick die nächste unterbotene Auktion ab und nennt vorher die verlorene Einzahlung. Abgebrochenes wird ein Posten mit dem neuen Preis.

- 0.67.0 (12.11.2026): **Stufe 2, H3 Wiederverkauf-Kette** (Konzept Abschnitte 6.2 und 6.3). Neue Datei `Lots.lua`.
  - **Posten** je Charakter (`PeonBrokerCharDB.lots`): Gegenstand, Menge, noch einzustellen, Einsatz, Zielpreis je Stück, Herkunft (Radar oder Abbruch), eingestellt zu welchem Preis. Ein gekaufter Aufkauf wird automatisch ein Posten. Händler-Käufe nicht, die gehen an den Händler.
  - **Zum Einstellen:** Knopf „Zum Einstellen (n)“ oben im Radar schaltet die Liste um: Gegenstand, Menge, Einsatz je Stück, Ziel, Markt jetzt (rot, wenn unter dem Ziel), In der Tasche (oder „Post“). Klick sagt, wie es weitergeht, Rechtsklick: Posten entfernen, In den Fokus, Gegenstand. Die Statuszeile nennt „n Posten zum Einstellen“, Blizzards Reiter heißt dann „Verkaufen (n)“ (nur der Text).
  - **Abweichung vom Konzept:** Ein Klick legt den Gegenstand **nicht** selbst ins Verkaufsfenster. Das ginge nur mit Blizzards `SetPostItem` aus Broker heraus, und das berührt wie in 0.64.1 Blizzards Wert `displayMode` (danach blockiert das Spiel das Benutzen aus der Tasche). Hineinlegen bleibt der gewohnte Rechtsklick in der Tasche. Mit KarloDerBaer abzustimmen.
  - **Rat beim Verkaufen:** Liegt ein Posten im Fenster, steht oben „Posten: gekauft für … je Stück, Ziel …“, bei Bedarf „Der Markt liegt inzwischen unter dem Ziel“. Knopf **„Zielpreis eintragen“** schreibt den Zielpreis in Blizzards Preisfeld (`PriceInput:SetAmount`, so wie Broker 0.10 bis 0.12 im Spiel). Nachgelesen im Zweig forever: Das Feld setzt nur die Zahlen der Eingabefelder und ruft Blizzards `UpdatePostState`. Eingestellt wird weiter mit Blizzards „Auktion erstellen“.
  - **Prüfung auf Blockaden:** Meldet das Spiel innerhalb von 60 Sekunden nach „Zielpreis eintragen“ eine blockierte Aktion von Broker, merkt Broker das (`targetBlocked`), bietet den Knopf nicht mehr an und sagt im Rat „Bitte den Zielpreis selbst eintippen“.
  - **Einstellen erkannt:** sicherer Anhang an `PostItem` der beiden Verkaufsfenster, bestätigt durch `AUCTION_HOUSE_AUCTION_CREATED`. Der Posten wird um die eingestellte Menge gekürzt und merkt den Preis. Eingestellte Posten bleiben 2 Tage.
  - **Fokus:** Nach dem Kauf zeigt er „GEKAUFT, kommt per Post, danach zu … einstellen“. Ist der Posten eingestellt, bewacht der Fokus ihn: Die Messung zählt die Menge unter dem eigenen Preis („VORN“, „UNTERBOTEN“, „ACHTUNG“, wenn sie wächst).
  - **Unterbotene abbrechen** (Blizzards Reiter Auktionen, neben „Prüfen“): „Unterbotene abbrechen (n), Einzahlung weg …“. Jeder Klick bricht die nächste unterbotene Auktion ab (`C_AuctionHouse.CancelAuction`, Kosten aus `GetCancelCost`). Nach `AUCTION_CANCELED` wird sie ein Posten, Ziel ist das günstigste fremde Angebot minus Unterbieten.
  - Tests: 30 neue Prüfungen (Posten aus dem Kauf, Liste, Rat, Eintragen, Einstellen, Blockade, Fokus, Abbrechen, Menü, Aufräumen).
  - **Im Spiel prüfen:**
    1. Einen Aufkauf kaufen: „Zum Einstellen (1)“ im Radar, Statuszeile, Reiter „Verkaufen (1)“.
    2. Post abholen: Spalte „In der Tasche“ zeigt die Menge.
    3. Rechtsklick in der Tasche: Rat mit Posten-Zeile und Knopf. **„Zielpreis eintragen“**: Steht der Preis im Feld? Danach „Auktion erstellen“ ohne Meldung „Aktion blockiert“? Danach einen Trank aus der Tasche benutzen, ohne Blockade?
    4. Nach dem Einstellen: Posten weg aus der Liste, Fokus zeigt „VORN“ oder „UNTERBOTEN“.
    5. Unter Auktionen mit einer unterbotenen Auktion: Text mit Einzahlung, ein Klick bricht genau eine ab, sie erscheint unter „Zum Einstellen“.

## 0.66.0

Kurz: Der Fokus misst den Gegenstand jetzt laufend (Vorgabe alle 5 Sekunden): Abfluss, Zufluss unter dem Ziel, Menge unter dem Ziel und günstigster Preis, dazu ein Diagramm.
Kurz: Beim Aufkauf sagt der Fokus nach 30 Sekunden „Kaufen“, „Abwarten“ oder „Finger weg“, ab 2 Minuten ohne „vorläufig“. Ist der Gesamtpreis beim Kauf höher als erwartet, warnt Broker vor dem zweiten Klick.

- 0.66.0 (12.11.2026): **Stufe 2, H2 Fokus mit Messung** (Konzept Abschnitt 6.1, Reiter Fokus). Neue Datei `Measure.lua`.
  - **Abfragen:** Am Auktionator wird der Gegenstand im Fokus alle `focusEvery` Sekunden abgefragt (neu, Vorgabe 5, einstellbar 3 bis 30, bisher fest 15). Nimmt das Spiel gerade keine Abfrage an, wartet Broker. Der Kopf der Messung nennt den eingestellten und den tatsächlichen Abstand.
  - **Messwerte** aus je zwei Abfragen nacheinander mit den Auktionsnummern (gleiche Regeln wie der Absatz in `Sales.lua`): verkauft (Menge kleiner, oder Angebot vorzeitig weg, ohne dass ein günstigeres stehen blieb), abgebrochen (vorzeitig weg, ein günstigeres blieb), abgelaufen zählt nicht, neu eingestellt. Daraus Abfluss (verkaufte Stück je Minute), Zufluss unter Ziel (neu eingestellte Stück unter dem Zielpreis je Minute), Menge unter Ziel (wächst, bleibt, schrumpft) und günstigster Preis (fällt, bleibt, steigt), jeweils über die letzten 10 Minuten.
  - **Ziel:** Zielpreis der Chance (Aufkauf: nächste Stufe, Händler: Händlerpreis). Ohne Chance die zweite Preisstufe beim Beginn der Messung.
  - **Urteil** beim Aufkauf (Startwerte, Entscheidungen 12.11.2026): nach 30 Sekunden vorläufig, ab 2 Minuten ohne Zusatz. „Finger weg“, wenn die Menge unter dem Ziel um mindestens 10 % wächst oder der günstigste Preis fällt. „Kaufen“, wenn der Abfluss mehr als 20 % über dem Zufluss unter dem Ziel liegt. Sonst „Abwarten“ (kaum Bewegung oder etwa gleich). Händler-Chancen behalten ihr Urteil aus der Chance, dort zählt die Messung kaum.
  - **Verkauft in:** ab 2 Minuten Messung mit dem gemessenen Abfluss („gemessen“), vorher mit dem Absatz der letzten Stunden.
  - **Diagramm** unter den Messwerten: Menge unter Ziel (Balken), günstigster Preis (Linie), Ziel (waagrechte Linie). Die Preisstufen stehen darüber in kürzerer Liste.
  - **Warnung beim Kauf:** Liegt der Gesamtpreis vom Spiel mehr als 1 % über dem erwarteten, steht vor dem zweiten Klick „Achtung: gesamt … statt erwartet …“.
  - **Unterwegs:** Die letzte Messung bleibt gemerkt (`focusMeasure`) und erscheint als „nicht live“, ohne neue Abfragen.
  - Tests: 18 neue Prüfungen (Vergleich, abgebrochen, abgelaufen, jedes Urteil, Ziel ohne Chance, Seite, Warnung, unterwegs).
  - **Im Spiel prüfen:**
    1. Fokus mit einem Aufkauf: Kommen die Abfragen wirklich alle 5 Sekunden? Was zeigt „tatsächlich“? Gibt es Meldungen oder Ruckeln?
    2. Abstand auf 3 Sekunden stellen: Hält das Spiel mit? Ab wann bremst es?
    3. Passen Abfluss und Zufluss zu dem, was man in Blizzards Liste sieht? Wird ein eigener Kauf als Abfluss gezählt (soll so sein)?
    4. Urteil nach 30 Sekunden und nach 2 Minuten: plausibel?
    5. Diagramm unter den Messwerten: lesbar, passt es in den Bereich?
    6. Kauf mit absichtlich veraltetem Stand: erscheint die Warnung vor dem zweiten Klick?

## 0.65.0

Kurz: Das Radar findet jetzt Aufkäufe: Massenware, die man bis zu einer Preisstufe kauft und zum Preis der nächsten Stufe wieder einstellt. Es zählt der Gewinn in Gold, und die Menge muss sich schnell wieder verkaufen.
Kurz: Jede Chance hat eine Ampel für das Risiko. Im Fokus stehen Kaufen bis, Menge, Einsatz, Ziel, Gewinn und „Verkauft in“, die Gründe für das Risiko zeigt der Tooltip.

- 0.65.0 (12.11.2026): **Stufe 2, H1 Aufkauf** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitt 6.1). Neue Datei `Buyout.lua`.
  - **Rechnung:** Für jede Stelle zwischen zwei Preisstufen einer Massenware: alle Stück darunter kaufen (Menge, Einsatz), Zielpreis ist der Preis der nächsten Stufe, Gewinn = Menge × Ziel × 0,95 − Einsatz. Je Gegenstand zählt die Stelle mit dem höchsten Gewinn, die alle Bedingungen erfüllt.
  - **Bedingungen:** aufkaufbar (Einsatz höchstens Gold minus Goldreserve), Gewinn mindestens „Mindestgewinn Aufkauf“ (bisher „Markt-Schnäppchen“, Vorgabe 50s), wieder verkauft in höchstens `buyoutHours` Stunden (neu, Vorgabe 2, einstellbar 1 bis 24) beim jetzigen Absatz, kein Trend nach unten (Brokers Regel: aktueller und vorheriger Median unter dem üblichen Bereich). Ohne Absatzdaten gibt es keinen Aufkauf, weil sich die Verkaufsdauer nicht schätzen lässt. Kein Mindestsprung in Prozent, der übliche Bereich filtert nicht.
  - **Risiko als Ampel** (Startwerte, Entscheidungen 12.11.2026): je ein Punkt für Verkaufsdauer über 75 % der Grenze, viel Ware bis 5 % über dem Ziel (mehr als der Absatz in der Höchstdauer), dünne nächste Stufe (unter 5 Stück oder unter 10 % der eigenen Menge), Einsatz über der Hälfte des verfügbaren Golds, Stand älter als 30 Min. (älter als 2 Std. zwei Punkte), wenig Absatzdaten oder kein üblicher Bereich. 0 grün, 1 bis 2 gelb, ab 3 rot. Händler-Chancen behalten die einfache Regel aus 0.64.
  - **Radar:** Arten Aufkauf und Händler. Sortierung nach Gewinn, rotes Risiko unten. Ändert sich das Gold, wird der Aufkauf neu gerechnet und fällt weg, wenn er nicht mehr bezahlbar ist. Tooltip mit Kaufen bis, Ziel, Verkaufsdauer und den Gründen für das Risiko.
  - **Fokus:** zusätzliche Zeilen „Verkauft in“ und „Risiko“ (Tooltip mit den Gründen). Gekauft wird die ganze Stelle mit dem Gold-Knopf wie bisher (Preis vom Spiel, dann bestätigen).
  - **Optionen:** Die Regler der früheren Art „unter dem üblichen Preis“ (Marge, Tiefe, Halten, Scans, Tage) sind von der Seite verschwunden, die Werte bleiben gespeichert. Neu „Aufkauf: wieder verkauft in höchstens“.
  - Tests: 18 neue Prüfungen (Rechnung, jede Bedingung, Risiko, Radar, Sortierung, Gold, Fokus).
  - **Im Spiel prüfen:**
    1. Nach einem Komplettscan: Stehen Aufkäufe im Radar? Sind sie plausibel (Kaufen bis, Ziel = nächste Stufe)? Wie viele sind es?
    2. Ampel: Passen grün, gelb und rot zum Gefühl? Tooltip mit den Gründen.
    3. Radar-Scan: Wird ein Aufkauf live neu gerechnet, verschwindet er, wenn die Stufe weg ist?
    4. Fokus: Zeilen passen in die linke Spalte (jetzt bis zu 8 Zeilen)?
    5. Kaufen einer ganzen Stelle: erster Klick Preis, zweiter bestätigt, keine Blockade.

## 0.64.1

Kurz: Der Favoriten-Stern aus Blizzards Kaufansicht scheint nicht mehr durch Brokers Reiter.
Kurz: „Im Markt zeigen“ sucht den Gegenstand jetzt in Blizzards Markt, ein Klick auf die Zeile zeigt die Angebote. Damit lässt sich danach jeder Gegenstand aus der Tasche wieder benutzen, ohne dass das Spiel eine Aktion von Broker blockiert.

- 0.64.1 (12.11.2026): **Zwei Fehler im Auktionshaus.**
  - **Favoriten-Stern:** Blizzards Stern in der Kaufansicht eines Gegenstands (`AuctionHouseFavoriteButtonBaseTemplate`) hat eine eigene, höhere Schicht (`frameStrata="HIGH"`, nachgelesen in `Blizzard_AuctionHouseSharedTemplates.xml`, Zweig forever). Er liegt damit über jeder Ebene der Schicht des Auktionshauses, auch über Brokers Fläche (370). Solange Brokers Fläche offen ist, macht Broker die beiden Sterne (Massenware und Einzelgegenstand) unsichtbar und für die Maus taub, danach wieder wie vorher (`T.HideHighStrata`). Nur Methoden des Rahmens, nichts in Blizzards Tabellen.
  - **Blockierte Aktion beim Benutzen aus der Tasche (Fehlerberichte 10 und 11 in peon-fehler):** Bis 0.64.0 rief Broker beim Sprung „Im Markt zeigen“ Blizzards `SelectBrowseResult` auf (darin `SetDisplayMode`) und leerte Blizzards Liste. Danach galt Blizzards Wert `displayMode` als von Broker berührt. Ein Rechtsklick auf einen nicht verkaufbaren Gegenstand in der Tasche liest diesen Wert (`IsListingAuctions`) und ruft danach `UseContainerItem` auf, das Spiel blockierte das (`ADDON_ACTION_FORBIDDEN`, nachgelesen in `ContainerFrame.lua`, Zweig forever). Jetzt ruft Broker keine von Blizzards Funktionen mehr auf, die Blizzards Werte schreiben: Der Name kommt als Text in Blizzards Suchfeld, die Suche geht über die Spiel-API (`C_AuctionHouse.SendBrowseQuery`), Blizzards Liste füllt sich selbst. Ein Klick auf die Zeile zeigt die Angebote. Steht Blizzard gerade nicht auf „Markt“, sagt ein Hinweis, dass man unten auf „Markt“ klicken soll. `W.SetAHMode`, das Nachsehen und Neuladen nach dem Zeigen (`StartGuard`, `ReloadBlizzardList`) entfallen.
  - Die Tests prüfen, dass weder `SetDisplayMode` noch `SelectBrowseResult` aufgerufen wird, und den Stern.
  - **Im Spiel prüfen:**
    1. Einen Gegenstand in Blizzards Kaufansicht öffnen, dann Radar oder Fokus wählen: Der Stern oben rechts am Gegenstand darf nicht mehr durchscheinen. Zurück auf Markt: Stern wieder da und anklickbar.
    2. „Im Markt zeigen“ (Doppelklick, Menü, Knopf): Suchfeld enthält den Namen, die Liste zeigt den Gegenstand. Klick auf die Zeile zeigt die Angebote.
    3. Danach einen Trank oder einen gebundenen Gegenstand in der Tasche per Rechtsklick benutzen: keine Meldung „Aktion blockiert“.
    4. Aus Verkaufen oder Auktionen heraus „Im Markt zeigen“: Hinweis oben am Bildschirm, nach Klick auf „Markt“ stehen die Treffer da.

## 0.64.0

Kurz: Das Radar ist jetzt eine schlanke Liste: Gegenstand, Gewinn, Art, Risiko und Stand. Ein Klick auf eine Chance öffnet sie im neuen Reiter „Fokus“.
Kurz: Der Fokus zeigt genau einen Gegenstand: Urteil, alle Angaben zur Chance, die Preisstufen und den Kaufknopf. Am Auktionator wird nur dieser eine Gegenstand regelmäßig neu abgefragt. Über „In den Fokus“ im Menü kommt jeder Gegenstand hinein.
Kurz: Das Radar zeigt vorerst nur Angebote unter dem Händlerpreis. Der Radar-Scan prüft nur noch die gezeigten Chancen, von selbst wird nichts mehr live geprüft. Ausblenden, Schnellkauf, „Nur Warnton“ und die Wahl von Art und Reihenfolge entfallen.

- 0.64.0 (11.11.2026): **Neuaufbau N6, Radar und Fokus in der Grundform** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitte 4.4 und 6.1). Damit ist Stufe 1 (N1 bis N6) gebaut. Neue Datei `Focus.lua`, `Look.lua` entfällt, `Radar.lua` von rund 1.830 auf 1.170 Zeilen.
  - **Radar schlank** (`Peon.UI`): eine Liste über die ganze Breite mit Gegenstand, Gewinn, Art, Risiko, Stand. Oben der Stand der Daten und der Knopf „Radar-Scan starten“. Die linke Spalte mit Einstellungen und die Kaufzeile entfallen. Mindestgewinn, Goldreserve und Ton stehen weiter auf der Optionsseite.
  - **Nur die Art Händler** (Angebote unter dem Händlerpreis). Die Art „unter dem üblichen Preis“ erscheint nicht mehr (`R.KIND_ON`). Der Aufkauf kommt mit H1.
  - **Keine Live-Prüfung von selbst:** Beim Öffnen kommen die Chancen aus der Datenbank, jede Zeile zeigt das Alter ihres Stands. Risiko vorerst einfach: gering bei frischem Stand, mittel bei einem Stand älter als 30 Minuten, der nie live geprüft wurde.
  - **Radar-Scan** prüft reihum nur die gezeigten Chancen, jede frühestens nach 15 Sekunden wieder, und nur solange die Seite Radar offen ist. Er sucht keine neuen Gegenstände mehr. Was weg ist, wird grau mit Grund und verschwindet nach 30 Sekunden.
  - **Klick auf eine Zeile** öffnet den Fokus mit diesem Gegenstand, Rechtsklick das Gegenstandsmenü.
  - **Fokus** (immer genau ein Gegenstand, gemerkt in `focusKey`): links Symbol und Name, das Urteil (KAUFEN, LOHNT NICHT, VORBEI, KEINE CHANCE) mit einem Satz, darunter Art, Kaufen bis, Menge, Einsatz, Ziel und Gewinn. Gold-Knopf „Kaufen N“, darunter „Im Markt zeigen“ und „Gegenstand“. Rechts der Stand und die Preisstufen, grün markiert ist, was der Kauf nimmt. „Jetzt prüfen“ fragt sofort neu ab.
  - **Abfragen im Fokus:** Am Auktionator wird der Gegenstand im Fokus alle 15 Sekunden neu abgefragt (`R.SetFocus`, wie Blizzards „Neu laden“), solange die Seite offen ist. Kürzere Abstände und die Messung von Abfluss und Zufluss kommen mit H2. Unterwegs zeigt die Seite den letzten Stand ohne Abfragen.
  - **Kaufen** wie bisher in zwei Schritten: erster Klick holt den Preis vom Spiel, zweiter bestätigt. Einzelgegenstände je Klick eine Auktion.
  - **„In den Fokus“** im Gegenstandsmenü (Strg+Rechtsklick) für jeden Gegenstand, auch ohne Chance.
  - **Tasten:** „Radar: gewählten Treffer kaufen“ kauft die Chance im Fokus, „Radar: nächster Treffer“ nimmt die nächste Chance in den Fokus.
  - **Entfernt** (Streichliste des Konzepts): Ausblenden von Treffern, Schnellkauf, „Nur Warnton“ während des Scans, Wahl von Art und Reihenfolge, die drei Kaufknöpfe (1 Stück, Stapel, alle), die Pause des Scans bei gewähltem Treffer. Die gespeicherte Liste ausgeblendeter Treffer (`radarHidden`) wird nicht mehr gelesen, gelöscht wird sie nicht. 50 Texte ohne Verwendung entfernt.
  - Die Tests des alten Radars (rund 580 Zeilen) sind durch 39 neue Prüfungen ersetzt. Die Prüfungen des Kerns (Teil-Ergebnisse, Schlüssel für Gegenstände mit Zusatz, weggefallene Treffer) bleiben.
  - **Im Spiel prüfen:**
    1. Nach einem Komplettscan Reiter Radar: Liste, Spalten, Zahl am Reiter. Wird wirklich nichts von selbst abgefragt?
    2. Radar-Scan starten und stoppen. Springt der Stand der Zeilen zurück, verschwindet Gekauftes?
    3. Klick auf eine Chance: Fokus mit den Angaben, „Zurück zu Radar“. Passt alles in die linke Spalte?
    4. Kaufen im Fokus: erster Klick, „Bestätigen“, danach „VORBEI“. Keine Meldung „Aktion blockiert“.
    5. Strg+Rechtsklick auf einen beliebigen Gegenstand, „In den Fokus“.
    6. Stört die Abfrage alle 15 Sekunden im Fokus (Ruckeln, Meldungen)?

## 0.63.0

Kurz: Unterwegs zeigt der Reiter „Auktionen“ jetzt den letzten bekannten Stand deiner Auktionen und sagt, welche nach den heutigen Preisen unterboten sind.
Kurz: Händler, Neutral und Datenlage unter „Mehr“ sind im neuen Look. Die Beobachtung steht nur noch als Liste unter Einkaufen.

- 0.63.0 (11.11.2026): **Neuaufbau N5, Mehr und Auktionen** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitte 4.5 und 4.7).
  - **Auktionen unterwegs** (`Pages.lua`): Liste aus dem zuletzt gelesenen Stand (`owned`) mit Gegenstand, Menge, deinem Preis, günstigstem Angebot und Status (unterboten, in Ordnung, verkauft). Bewertet wird mit den heutigen Preisdaten, unterbotene stehen oben. Die Kopfzeile nennt Anzahl, Unterbotene, Alter und „nicht live“. Am Auktionator bleibt „Auktionen“ Blizzards Seite mit Brokers Spalte.
  - **Mehr > Händler, Neutral, Datenlage** mit `Peon.UI`: Suchfeld, Haken und Listen im Look des Auktionshauses, Symbole in den Listen. Klick zeigt den Gegenstand, Rechtsklick öffnet das Menü.
  - **Beobachtung** ist kein Unterpunkt von Mehr mehr. Sie steht als besondere Liste in Einkaufen (seit 0.62).
  - **Ein Händler-Speicher:** Die Händlerpreise für das Berufsfenster kommen jetzt aus demselben Speicher wie die Seite Händler (`vendors`). Der frühere eigene Speicher (`merchant`) wird nicht mehr beschrieben und nur noch gelesen, bis der Händler wieder besucht wurde. Gelöscht wird er nicht.
  - Aufgeräumt: alte Seite Beobachtung, eigener Händler-Scan in `Merchant.lua`, `W.Inset`.
  - **Im Spiel prüfen:** unterwegs Reiter Auktionen (vorher am Auktionshaus einmal Auktionen öffnen). Mehr mit allen drei Unterpunkten. Einen Händler besuchen, danach im Berufsfenster ein Rezept mit Händlerware: Stimmt der Händlerpreis?

## 0.62.0

Kurz: Die Seite „Einkaufen“ ist neu gebaut: links die Listen mit der Beobachtung immer oben, rechts die Gegenstände mit Ziel, Fehlt, Höchstpreis, günstigstem Angebot und Rat, darunter die Kaufzeile mit goldenem Knopf.
Kurz: In der Liste gilt jetzt wie überall: Linksklick wählt, Doppelklick zeigt den Gegenstand im Markt, Rechtsklick öffnet das Menü. Das Löschen einer Liste fragt nach.

- 0.62.0 (11.11.2026): **Neuaufbau N4, Einkaufen** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitt 4.3). Der Aufbau der Seite in `Buy.lua` nutzt jetzt `Peon.UI`, die Rechnung dahinter ist unverändert.
  - **Oben:** Suchfeld zum Hinzufügen (Name oder Link, Eingabetaste) und „Liste durchsuchen“.
  - **Links oben die Listen,** die Beobachtung als besondere Liste immer oben. Darunter Neu und Löschen (mit Rückfrage), Name, Rabatt der Liste in Prozent unter dem üblichen Preis. Für den gewählten Gegenstand „Max. Gold“ und „Ziel“ (einschließlich Vorrat) sowie Entfernen. Unten der Haken „Twinks mitzählen“ (nur mit Peon_Ledger).
  - **Rechts:** Gegenstand mit Symbol, Ziel, Fehlt, Höchstpreis, Günstigst, Rat. Die Spalten Vorrat und Treffer entfallen, sie stecken in Fehlt und Rat.
  - **Kaufzeile** unter der Liste: was der Klick kauft, „Im Markt zeigen“ und der Gold-Knopf „Kaufen“.
  - **Klicks wie überall** (`Go.Click`): Linksklick wählt, Doppelklick zeigt im Markt, Rechtsklick öffnet das Gegenstandsmenü.
  - Noch offen aus dem Konzept: der Rat „HÄNDLER“ (kommt mit den kleinen Hilfen in H4) und die Grenze nach oben für die Beobachtung (H4).
  - **Im Spiel prüfen:** Liste anlegen, umbenennen, Rabatt setzen, Gegenstand per Name hinzufügen, Max. Gold und Ziel ändern, entfernen, Liste löschen. Passt die linke Spalte, schneidet nichts ab? Am Auktionator: Liste durchsuchen, Kaufen, Doppelklick und Rechtsklick auf eine Zeile.

## 0.61.0

Kurz: Unterwegs gibt es jetzt die Seite „Markt“ aus deinen Scandaten: Suche, Kategorien wie im Auktionshaus und eine Liste mit Preis, Menge, Trend und Stand. Ohne Suche zeigt sie die Gegenstände deiner Einkaufslisten und der Beobachtung.
Kurz: „Im Markt zeigen“ funktioniert damit auch unterwegs und führt zur Marktseite mit genau diesem Gegenstand.

- 0.61.0 (11.11.2026): **Neuaufbau N3, Markt aus Scandaten** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitt 4.1). Neue Datei `Market.lua` mit `Peon.UI`. Am Auktionator bleibt „Markt“ Blizzards Kaufen.
  - **Oben:** Suchfeld (ab zwei Buchstaben), Zähler, rechts der Stand der Daten und die Auswahl des Markts. Die Auswahl erscheint nur, wenn es Daten für mehr als einen Markt gibt.
  - **Links die Kategorien** wie im Auktionshaus, auf- und zuklappbar. Die Namen kommen vom Spiel (`GetItemClassInfo`, `GetItemSubClassInfo`), die Zuordnung über `GetItemInfoInstant`. Es erscheinen nur Kategorien, zu denen es Angebote gibt.
  - **Rechts die Liste:** Gegenstand mit Symbol in Qualitätsfarbe, Preis ab, Menge, Trend, Stand. Sortieren per Klick auf den Kopf. Höchstens 500 Zeilen, der Zähler sagt, wenn es mehr gibt. Suche und Kategorie wirken zusammen.
  - **Ohne Suche und Kategorie:** die Gegenstände aus Einkaufslisten und Beobachtung, sonst ein Hinweis.
  - **Klick auf eine Zeile** zeigt den Gegenstand auf der Seite Gegenstand, „Zurück zu Markt“ führt zurück. Rechtsklick öffnet das Gegenstandsmenü.
  - **„Im Markt zeigen“ unterwegs** (`Go.Market`): öffnet die Marktseite und sucht nach genau diesem Gegenstand. Der Knopf auf der Seite Gegenstand ist nicht mehr grau.
  - **Im Spiel prüfen:** unterwegs `/broker`, Reiter Markt. Kategorien auf- und zuklappen, Namen der Kategorien, Suche, Sortieren. Dauert das erste Öffnen spürbar (rund 20.000 Gegenstände werden einmal einsortiert)? Klick auf eine Zeile und zurück. Mit Daten vom neutralen Haus: Auswahl des Markts.

## 0.60.1

Kurz: In Brokers Reitern scheinen keine Teile von Blizzards Verkaufsfenster oder vom Reiter Auktionen mehr durch.

- 0.60.1 (11.11.2026, gemeldet von KarloDerBaer mit zwei Bildern): Nach dem Wechsel von Verkaufen oder Auktionen auf einen Broker-Reiter blieben der Gegenstand, „Auktion erstellen“, „Sofortkaufmodus“ und der Reiter „Auktionen“ über Brokers Fläche sichtbar. Blizzard setzt diese Teile selbst hoch (nachgelesen in `Blizzard_AuctionHouseUI`, Zweig forever: Reiter über der Auktionsliste Ebene 300, Gegenstand, Knopf und Haken im Verkaufsfenster 350). Brokers Fläche lag seit 0.59.1 auf 300. Sie liegt jetzt fest auf 370, also über Blizzards Inhalt und unter dem runden Bild (400).
  - **Im Spiel prüfen:** von Verkaufen (mit einem Gegenstand im Verkaufsfenster) und von Auktionen auf alle fünf Broker-Reiter wechseln. Von Markt kommend: Bleibt der Favoriten-Stern neben Blizzards Suchfeld verborgen? Er hat bei Blizzard eine eigene, höhere Schicht.

## 0.60.0

Kurz: Die Seite „Gegenstand“ ist neu: links Symbol, Name und alle Werte wie im Tooltip, rechts ein Preisdiagramm für 7, 14, 30 oder 90 Tage und darunter die günstigsten Preisstufen mit Menge und Kosten bis zu jeder Stufe.
Kurz: Oben suchst du einen Gegenstand, ab zwei Buchstaben erscheinen die Treffer. Ein Klick zeigt ihn, mit Knöpfen für „Im Markt zeigen“, „Beobachten“ und „Auf Einkaufsliste“.

- 0.60.0 (11.11.2026): **Neuaufbau N2, Seite Gegenstand** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitt 4.6). Neue Datei `Item.lua` mit `Peon.UI`, `Prices.lua` entfällt.
  - **Eine Seite, ein Gegenstand:** Sie zeigt immer den zuletzt gewählten Gegenstand und merkt ihn sich (`itemKey`).
  - **Links:** Kopf mit Symbol und Namen in Qualitätsfarbe (Maus darüber zeigt den Tooltip). Darunter die Werte aus denselben Bausteinen wie der Tooltip: Markt (ab, Median, Menge, Alter), Üblich, Absatz am Tag, Händler, Beim Händler, Neutral, Herstellen, Art. Ohne üblichen Bereich steht „noch zu wenig Daten“, bei mehr als 40 % Schwankung „(schwankt stark)“. Der wichtigste Hinweis in Orange. Mit Peon_Ledger der Abschnitt „Mein Bestand“ (Vorrat, Kosten je Stück, deine Verkäufe).
  - **Knöpfe:** Im Markt zeigen (am Auktionator, unterwegs grau bis zur Marktseite aus Scandaten in N3), Beobachten an und aus, Auf Einkaufsliste mit Auswahl der Liste.
  - **Rechts oben das Diagramm:** günstigstes Angebot (gold), Median (grau gestrichelt), üblicher Bereich (grüne Fläche), Menge (Balken, rechte Achse), mit Ledger die eigenen Kosten als Linie. Zeitraum 7, 14, 30 oder 90 Tage (`itemDays`). Ältere Tage liegen als Wochenwerte vor und gelten für alle sieben Tage der Woche. Unter zwei Tagen mit Werten steht „Noch kein Verlauf“.
  - **Rechts unten die Preisstufen** des letzten Stands: Preis, Menge, Stück bis hier, Kosten bis hier. Das zeigt Preissprünge auf einen Blick (Grundlage für den Aufkauf in H1).
  - **Suche oben:** ab zwei Buchstaben die Treffer als Liste über die ganze Breite (Gegenstand, Preis ab, Median, Menge, Absatz, Gesehen), höchstens 200, der Zähler sagt, wenn es mehr gibt. Linksklick zeigt den Gegenstand, Rechtsklick öffnet das Gegenstandsmenü (`Go.Menu`).
  - Der Knopf „Mehr… (Ledger)“ entfällt, weil Ledgers eigener Reiter Gegenstand bei dessen Überarbeitung wegfällt (Entscheidung vom 09.11.2026).
  - 24 weitere Texte ohne Verwendung entfernt (alte Seite Preise).
  - **Im Spiel prüfen:**
    1. Gegenstand über die Suche wählen, unterwegs und am Auktionator. Passt alles in die Seite, schneidet nichts ab?
    2. Diagramm: Linien, Fläche und Balken sichtbar, Achsen lesbar, Wechsel des Zeitraums.
    3. Preisstufen bei einer Massenware mit vielen Angeboten.
    4. Strg+Rechtsklick auf einen Gegenstand, „Gegenstand (Broker)“, danach „Zurück zu …“.
    5. Die drei Knöpfe, am Auktionator auch „Im Markt zeigen“.
    6. Rechtsklick auf einen Treffer: Menü.

## 0.59.1

Kurz: Der Scan-Knopf sitzt jetzt mit seinem Text oben in der Titelleiste des Auktionshauses, wo ihn die Reiter nicht mehr verdecken. Der Knopf „Blizzard pur“ ist dort weg, die Einstellung findest du in den Optionen.
Kurz: In Brokers Reitern scheint links oben am runden Bild nichts mehr von Blizzards Fenster durch. „Zurück zu …“ steht in Blizzards Kaufansicht direkt rechts neben „Zurück“.
Kurz: Aufgeräumt: nicht mehr gebrauchter Code und Texte sind entfernt, ebenso vier Einstellungen des früheren Reiters Verkaufen.

- 0.59.1 (11.11.2026, Rückmeldung von KarloDerBaer nach dem Test von N1: „schaut alles gut aus“, vier Anmerkungen):
  - **Knopf „Blizzard pur“ im Auktionshaus entfernt.** Die Einstellung bleibt auf der Optionsseite und als `/broker pur`.
  - **Scan-Knopf in der Titelleiste** links neben dem Schließen-Knopf, der Text zum Scan steht links davon. Unter dem Fenster verdeckten ihn die acht Reiter.
  - **Ecke am runden Bild:** Brokers Fläche begann erst unter Blizzards Suchleiste und sparte die Ecke am Bild aus, dort schien Blizzards Inhalt durch. Jetzt deckt sie alles ab der Titelleiste ab und liegt unter dem Bild statt daneben. Nachgelesen in Blizzards Fenstervorlage (Zweig forever): rundes Bild auf Ebene 400, Metallrahmen 500, Titel 510. Brokers Fläche liegt auf 300, Knöpfe in der Titelleiste auf 520.
  - **„Zurück zu …“** steht in Blizzards Kaufansicht rechts neben Blizzards „Zurück“ (`T.PlaceBack`, nur der Anker des eigenen Knopfs). Auf Brokers eigenen Seiten und im Broker-Fenster steht der Knopf links in der Titelleiste neben dem Bild.
  - **Aufgeräumt** (Auftrag von KarloDerBaer):
    - 178 Texte ohne Verwendung in beiden Sprachen entfernt (alte Reiter Start, Verkaufen, Behalten, Meine Auktionen, alte Tooltip-Schalter, Prüffläche aus U0).
    - Funktionen ohne Aufruf entfernt: Preisvorschlag, Eintragspreis, Laufzeit und Mindestpreis des früheren Reiters Verkaufen (`D.SuggestSell`, `D.EntryPrice`, `D.SellDuration`, `D.IsLowPrice`, `D.MinPrice`), `S.Speed`, `T.SellRateLine`, `R.Affordable`, `R.OfferCost`, `R.DiagText`, dazu ihre Tests.
    - Einstellungen entfernt, die nur diese Funktionen nutzten: „Massenware mit vielen Angeboten 2 Std.“ mit Mindestzahl (`shortMass`, `shortMassMin`), „Verkauft sich schnell“ und „Markt ist voll“ (`salesGreenHours`, `salesRedDays`), `sellOnlyProfitable`.
    - Kopf von `Broker.lua` gekürzt, der Verlauf steht hier im Changelog.
    - Noch nicht aufgeräumt: der abgeschaltete Schnellkauf im Radar. Das Radar wird mit N6 neu gebaut, dabei fällt er weg.
  - **Im Spiel prüfen:** Scan-Knopf und Text in der Titelleiste, Ecke am Bild in allen fünf Broker-Reitern, „Zurück zu …“ neben Blizzards „Zurück“ bei Massenware und bei einem Einzelgegenstand. Mit Peon_Bridge 0.9.1: Knopf „An Manager“ nach einem Scan oben rechts über dem Fenster.

## 0.59.0

Kurz: Broker ist jetzt ein Fenster: Am Auktionator stehen seine Seiten als Reiter im Auktionshaus, unterwegs zeigt das Broker-Fenster dieselben Reiter in gleicher Größe und gleichem Look. Die Reiter heißen Markt, Verkaufen, Auktionen, Einkaufen, Radar, Fokus, Gegenstand und Mehr.
Kurz: Neu ist „Im Markt zeigen“: Aus Einkaufen, Radar und dem Menü jedes Gegenstands springst du mit einem Klick zu genau diesem Gegenstand in Blizzards Kaufansicht. Ein Knopf „Zurück zu …“ bringt dich wieder zurück.
Kurz: Markt (unterwegs), Auktionen (unterwegs) und Fokus sind noch in Arbeit. Broker braucht ab jetzt Peon 0.18.

- 0.59.0 (11.11.2026): **Neuaufbau N1, Gerüst** (Konzept `docs/konzepte/broker/Peon_Broker_Neuaufbau.md`, Abschnitte 3 und 5). Braucht Peon 0.18.0 (Kern-API 18).
  - **Ein Fenster in zwei Zuständen** (`Window.lua` neu): Das Broker-Fenster nutzt `Peon.UI` (800 × 538 wie das Auktionshaus, rundes Bild, Reiter unten, Statuszeile). Am Auktionator öffnet es nicht mehr: `/broker`, Minimap-Button und Panel wählen dort den zuletzt genutzten Broker-Reiter im Auktionshaus. Ist das Fenster offen und das Auktionshaus geht auf, schließt es, und sein Reiter öffnet im Auktionshaus. Unterwegs öffnet das Fenster dort, wo das Auktionshaus zuletzt stand, solange man es nicht selbst verschoben hat. Bei „Blizzard pur“ bleibt es ein eigenes Fenster.
  - **Reiter:** Markt, Verkaufen, Auktionen, Einkaufen, Radar, Fokus, Gegenstand, Mehr. Im Auktionshaus bleiben Blizzards Markt, Verkaufen und Auktionen an ihrem Platz, Brokers fünf Reiter stehen dahinter (`AHTabs.lua`). Unterwegs ist Verkaufen grau, Markt, Auktionen und Fokus zeigen noch den Hinweis „in Arbeit“ (kommen mit N3, N5, N6).
  - **Seiten einmal gebaut:** Jede Seite hängt je nach Zustand im Fenster oder im Auktionshaus (`W.Content`), mit denselben Abständen. Einkaufen gab es bisher doppelt (Fenster und Auktionshaus), jetzt ist es dieselbe Seite.
  - **Gegenstand** zeigt wieder die bisherige Gegenstandsansicht (Suche, Preise, Verlauf, Mein Bestand) statt des WIP-Hinweises, bis N2 sie neu baut.
  - **Mehr** mit den Unterpunkten Händler, Neutral (bisher Marktvergleich), Datenlage (bisher Quellen) und vorerst Beobachtung (wandert mit N4 in Einkaufen). Die eigenen Reiter dafür entfallen.
  - **Statuszeile** in beiden Zuständen: Markt, Alter von Scan und Stand vom Manager, unterwegs „letzter Stand, nicht live“, rechts das Gold. Klick öffnet Mehr mit der Datenlage.
  - **Sprünge** (neue Datei `Go.lua`): „Im Markt zeigen“ schließt Brokers Fläche und zeigt den Gegenstand in Blizzards Kaufansicht. Bis 0.58 war das gesperrt, solange Einkaufen oder Radar offen war. Unterwegs führt der Sprung zur Seite Gegenstand, bis die Marktseite aus Scandaten da ist (N3). Knöpfe „Im Markt zeigen“ in Einkaufen (neben Kaufen) und im Radar (oben neben dem Scan-Knopf), Einträge „Im Markt zeigen“ und „Gegenstand (Broker)“ im Gegenstandsmenü.
  - **Zurück:** Nach einem Sprung steht in der Titelleiste links neben dem Schließen-Knopf „Zurück zu Radar“ (oder der jeweiligen Seite), auch über Blizzards Kaufansicht. Ein Schritt zurück. Wählt man selbst einen Broker-Reiter, verschwindet der Knopf. (Das Konzept nennt „oben links“, dort sitzt das runde Bild.)
  - **Zahl am Reiter** (Radar, Einkaufen) steht jetzt auch im Broker-Fenster.
  - Die Prüffläche aus U0 (Text und Zustand von Blizzards Werten auf der leeren Fläche) entfällt, `/broker pruefen ah` bleibt.
  - Noch nicht in N1: Doppelklick und Rechtsklick-Menü in Brokers Listen (kommen mit den neuen Listen ab N2), „In den Fokus“ (N6).
  - **Im Spiel prüfen** (Peon und Peon_Broker auf Entwicklung, `/reload`):
    1. Unterwegs `/broker`: Fenster in der Größe des Auktionshauses, acht Reiter passen in die Breite, Verkaufen grau, Statuszeile unten.
    2. Einkaufen, Radar, Gegenstand, Mehr mit allen vier Unterpunkten: Passt der alte Inhalt in den neuen Rahmen, überdeckt nichts das runde Bild?
    3. Am Auktionator: acht Reiter mit gleichen Abständen, alle fünf Broker-Reiter öffnen, Statuszeile unten, Wechsel zu Blizzards Reitern und zurück.
    4. Fenster unterwegs offen lassen und das Auktionshaus öffnen: Fenster zu, Reiter im Auktionshaus offen. `/broker` am Auktionator schaltet den Reiter ein und aus.
    5. In Einkaufen und Radar einen Gegenstand wählen, „Im Markt zeigen“: Blizzards Kaufansicht mit genau diesem Gegenstand, „Zurück zu …“ in der Titelleiste.
    6. Strg+Rechtsklick auf einen Gegenstand: „Im Markt zeigen“ und „Gegenstand (Broker)“.
    7. Danach etwas kaufen, einstellen und abbrechen, dann `/broker pruefen ah`: alles „sauber“, keine Meldung „Aktion blockiert“.

## 0.58.0

Kurz: Einkaufen und Radar sehen jetzt aus wie Blizzards Reiter Verkaufen (hellgrau statt schwarzem Marmor). Im Verkaufsfenster stehen Dauer, Einzahlen, Gesamtpreis und „Auktion erstellen“ dichter, damit Brokers Rat auch neben dem Haken „Sofortkaufmodus“ Platz hat.

- 0.58.0 (10.11.2026, abgestimmt mit KarloDerBaer):
  - **Look wie Verkaufen:** `Look.lua` nimmt die Hintergründe von Blizzards Reiter Verkaufen (links das Verkaufsfenster, rechts dessen Angebotsliste), zuerst die Grafik, die Blizzard dort gerade zeigt, sonst `auctionhouse-background-sell-left` und `-sell-right`. 0.57 hatte von Kategorien und Auktionsliste kopiert, die in WoW Forever den schwarzen Marmor zeigen.
  - **Dichtere Zeilen im Verkaufsfenster** (`A.Compact`, Einzelgegenstand und Massenware): Nach Blizzards Anordnung (sicherer Anhang an `Layout`) rücken Dauer, Einzahlen, Gesamtpreis und „Auktion erstellen“ je 18 Punkte näher. Broker setzt nur deren Anker neu und schreibt keine Werte in Blizzards Fenster.
  - **Prüfung:** `/broker pruefen ah` zeigt jetzt auch, ob `spacing`, `Layout`, `UpdatePostState` und `PostItem` der beiden Verkaufsfenster sauber sind.
  - **Im Spiel prüfen:** Farben von Einkaufen und Radar. Verkaufsfenster mit und ohne Sofortkaufmodus, Rat vollständig lesbar. Einige Auktionen einstellen (Einzelgegenstand, Massenware, Dauer geändert), keine Meldung „Aktion blockiert“, danach `/broker pruefen ah`.

## 0.57.0

Kurz: Im Radar zeigt der Tooltip jetzt den normalen Gegenstand mit Brokers Preisen (Umschalt für mehr), die Radar-Angaben stehen ganz unten. Namen statt Nummern, kein Neuladen mehr ohne neuen Scan, Einkaufen und Radar im hellen Grau des Auktionshauses und eine eigene Spalte „Broker“ unter Auktionen.

- 0.57.0 (10.11.2026, Rückmeldung von KarloDerBaer nach dem Test von 0.56):
  - **Radar-Tooltip:** Blizzards normaler Tooltip mit Brokers Zeilen, Umschalt zeigt wie überall die erweiterte Ansicht. Die Radar-Angaben (Datenlage, Wiederverkauf, Absatz, ganzes Schnäppchen) hängt `Tooltip.lua` bei jedem Neuaufbau ganz unten an (`T.SetExtra`). Vorher verschwanden sie beim Drücken von Umschalt.
  - **Namen statt Nummern im Radar:** Kennt das Spiel einen Gegenstand noch nicht, fordert Broker die Daten an und setzt den Namen ein, sobald `GET_ITEM_INFO_RECEIVED` kommt.
  - **Radar lädt nur nach einem Scan neu** (oder bei anderem Markt oder anderer Altersgrenze), nicht mehr alle 2 Minuten.
  - **Helles Grau:** Einkaufen und Radar übernehmen die Hintergründe direkt von Blizzards Rahmen (links wie die Kategorien, rechts wie die Liste unter Auktionen), die Fläche den Hintergrund des Auktionshauses. Ohne geöffnetes Auktionshaus Blizzards Grafiken nach Namen, sonst Marmor.
  - **Auktionen:** Status in einer eigenen Spalte „Broker“ mit Kopf am rechten Ende der Gegenstandsspalte (Blizzards Tabelle bleibt unverändert). Ein Status erscheint nur, wenn der Gegenstand der Zeile zur Auktion passt (ein „unterboten“ von Golderz stand bei Wildblumen). Fehlt eine sichtbare Auktion in Brokers Liste, liest Broker die eigenen Auktionen neu (höchstens einmal je Sekunde), dadurch fehlt „Günstigstes“ nicht mehr.
  - **Weiterverkauf:** „nach 5 % Anteil des Hauses“ in eigener Zeile.
  - **Im Spiel prüfen:** Radar-Tooltip mit und ohne Umschalt, Namen im Radar, Farben von Einkaufen und Radar, Spalte Broker unter Auktionen.

## 0.56.0

Kurz: Das Auktionshaus ist aufgeräumt: Reiter mit gleichen Abständen wie bei Blizzard, Einkaufen und Radar im Aufbau von Blizzards Fenstern (links Einstellungen, rechts die Liste), der Rat beim Verkaufen ist ganz lesbar, und beim Kauf von Massenware steht, was ein Weiterverkauf zum nächsten Preis bringen würde.

- 0.56.0 (10.11.2026, Rückmeldung von KarloDerBaer nach dem Test im Spiel, braucht Peon 0.17 für die Listen-Optik):
  - **Reiter im Auktionshaus:** Broker misst den sichtbaren Abstand zwischen Blizzards Markt und Verkaufen und setzt Einkaufen, Radar und Auktionen genauso (`T.AlignTabs`, nach dem Öffnen und wenn sich eine Zahl am Reiter ändert). Grundabstand jetzt wie bei Blizzard (-15).
  - **Einkaufen und Radar im Blizzard-Aufbau** (neue Datei `Look.lua`): oben eine Leiste wie Blizzards Suchleiste (Einkaufen: Hinzufügen und „Liste durchsuchen“, Radar: Stand und „Radar-Scan starten“), links eine Spalte mit allen Einstellungen, rechts die Liste in Blizzards Optik, die den Platz ausfüllt. Radar: Anzeige, Reihenfolge, Mindestgewinn Händler und Auktionshaus, Nur Warnton, Ausblenden und Schnellkauf links, Kaufzeile unter der Liste. Einkaufen: Listen, Name, Höchstpreis der Liste, gewählter Gegenstand (Höchstpreis, Menge, Entfernen) und Vorrat aller Charaktere links, Kaufen unter der Liste.
  - **Radar ohne Hänger beim Wechsel:** Die Treffer werden nur neu aus der Datenbank geladen, wenn es einen neuen Scan gibt, die Altersgrenze geändert wurde oder der letzte Stand älter als 2 Minuten ist (`R.LoadIfStale`). Vorher ging jeder Wechsel auf den Reiter alle Gegenstände des Marktes durch.
  - **Rat beim Verkaufen** ohne Rahmen und ohne Überschrift „Broker“, dichter unter „Auktion erstellen“, damit der Text nicht mehr abgeschnitten wird.
  - **Weiterverkauf beim Kauf von Massenware** (neue Datei `Resale.lua`): Unter „Kaufen“ steht, was man verdient oder verliert, wenn man die gewählte Menge kauft und zum günstigsten verbleibenden Angebot wieder einstellt, nach dem Anteil des Hauses. Sicherer Anhang an `SetPrice` der Kaufanzeige, Broker liest nur.
  - **Im Spiel prüfen:** Abstände der fünf Reiter (auch mit Zahl am Radar), Einkaufen und Radar bei verschiedener Fenstergröße, Wechsel auf Radar ohne Hänger, Weiterverkauf bei Leinenstoff und Co., Rat beim Verkaufen vollständig lesbar.

## 0.55.0

Kurz: Aufgeräumt: Die alten Reiter Verkaufen, Behalten und Meine Auktionen sind ganz entfernt, ebenso deine Behalten-Liste. Verkaufen und Auktionen laufen über Blizzards Fenster mit Brokers Rat.

- 0.55.0 (09.11.2026): **Umbau U12, Aufräumen Teil 2** (mit Zustimmung von KarloDerBaer).
  - `Sell.lua` und `Keep.lua` entfernt. Ihre Bausteine liegen in `Live.lua` (Live-Ergebnisse lesen: `ReadCommodity`, `ReadItems`, `IsFull`, `RequestMore`, `Foreign`, `KeyText`) und `Stock.lua` (Vorrat zählen mit Taschen, Bank und auf Wunsch Twinks aus Ledger). Rat beim Verkaufen, Einkaufen, Radar, Auktionen, Info, Marktvergleich und Berufsfenster nutzen sie weiter.
  - `Auctions.lua` behält nur Lesen, Bewerten und Live-Prüfung der eigenen Auktionen (für Blizzards Reiter Auktionen). Abbrechen, „Nächste unterbotene“ und „Neu einstellen“ der alten Oberfläche entfallen, dafür gibt es Blizzards Knöpfe.
  - **Gelöscht beim Anmelden:** die Behalten-Liste je Charakter (`PeonBrokerCharDB.keep`) und das Gedächtnis des alten Reiters Verkaufen (`PeonBrokerDB.sellMem`).
  - Option „Nur lohnende im Reiter Verkaufen“ entfernt.
  - Tests der alten Oberflächen entfernt, die Bausteine sind weiter geprüft.

## 0.54.0

Kurz: Im Auktionshaus liegen Radar und Einkaufen nicht mehr übereinander. Die Reiter heißen und stehen jetzt: Markt (bisher Kaufen), Verkaufen, Einkaufen, Radar, Auktionen.
Kurz: Das Broker-Fenster hat die Reiter Markt, Marktvergleich, Händler, Einkaufsliste, Beobachten, Info und Quellen. Markt und Info sind noch in Arbeit.

- 0.54.0 (09.11.2026, nach dem Test von KarloDerBaer):
  - **Auktionshaus:** Beim Wechsel zwischen Radar und Einkaufen blieb die vorige Fläche sichtbar, daher überlagerten sich Texte und Knöpfe. Jetzt wird die andere umgehängte Fläche versteckt. Fläche mit undurchsichtigem Grund (Blizzards Hintergrund ließ etwas durchscheinen).
  - **Reihenfolge im Auktionshaus:** Markt, Verkaufen, Einkaufen, Radar, Auktionen. Blizzards „Auktionen“ wird nur neu verankert, „Kaufen“ bekommt den Text „Markt“ (keine Einträge in Blizzards Tabellen).
  - **Broker-Fenster:** Reiter Markt (neu, WIP: soll wie Blizzards Kaufen mit Kategorien auf Basis der Scandaten werden), Marktvergleich (bisher Markt), Händler, Einkaufsliste, Beobachten, Info (bisher Gegenstände, WIP, wird neu gestaltet), Quellen. Ein gemerkter Reiter ohne Knopf öffnet Markt.
  - **Im Spiel prüfen:** Reiter im Auktionshaus, Wechsel Radar und Einkaufen, Reiter im Broker-Fenster.

## 0.53.1

Kurz: Behebt das Einfrieren des Spiels beim erweiterten Tooltip (mit Umschalt).

- 0.53.1 (09.11.2026, gemeldet von KarloDerBaer): Das Preisdiagramm im Tooltip (0.47.0) nutzte `grid = 0`, damit hing der Diagramm-Baustein des Kerns bis Peon 0.16.0 in einer Endlosschleife. Broker nutzt jetzt `grid = 1`, der Kern ist mit Peon 0.16.1 ebenfalls abgesichert.

## 0.53.0

Kurz: Aufgeräumt: Die Startseite, die Zeile „Behalten“ im Tooltip und das Andocken des Broker-Fensters am Auktionshaus sind weg. Das Fenster bleibt dort, wo du es hingeschoben hast, und öffnet und schließt sich nicht mehr mit dem Auktionshaus.

- 0.53.0 (09.11.2026): **Umbau U12, Aufräumen Teil 1** (Konzept Abschnitt 13).
  - `Start.lua` entfernt (Startseite, seit 0.51 ohne Reiter).
  - Andocken ans Auktionshaus und Einstellung „Broker-Fenster mit dem Auktionshaus öffnen“ (`windowWithAH`) entfernt.
  - Zeile „Behalten“ im Tooltip entfernt. Die gespeicherte Behalten-Liste (`PeonBrokerCharDB.keep`) bleibt vorerst unangetastet.
  - Bereiche für Rückmeldungen nach dem neuen Aufbau (Verkaufen (Rat), Auktionen, Radar, Einkaufen, Einkaufslisten, Beobachtung, Markt, Händler, Gegenstände, Quellen, Berufe, Scan, Tooltip, Gegenstandsmenü, Optionen).
  - Noch da: die Oberflächen der früheren Reiter Verkaufen, Behalten und Meine Auktionen (ohne Reiter). Ihre Bausteine (Live-Ergebnisse lesen, Vorrat zählen, eigene Auktionen lesen) brauchen Rat, Einkaufen, Radar und Auktionen weiter.

## 0.52.0

Kurz: Broker merkt sich jetzt alles, was du bei Händlern siehst: Ware, Preis (auch in Abzeichen oder Marken), begrenzte Menge, Voraussetzungen wie Ruf und den Ort. Der neue Reiter „Händler“ zeigt die Liste mit dem Preis im Auktionshaus, der Tooltip auf Wunsch den günstigsten Händler.

- 0.52.0 (09.11.2026): **Umbau U11, Händler** (Konzept Abschnitt 8.4). Neue Datei `Vendors.lua`.
  - Beim Öffnen eines Händlers (und bei Änderungen, höchstens alle 2 Sek.) liest Broker alle Angebote: Preis je Stück in Gold, Stück je Kauf, andere Währung oder Gegenstände (`GetMerchantItemCostInfo/Item`), begrenzte Menge, Voraussetzungen (rote Zeilen im Tooltip des Angebots), dazu Name, NPC-Nummer (aus der GUID), Zone und Koordinaten. Gespeichert in `PeonBrokerDB.vendors[npcID]`. Der Kaufpreis für das Berufsfenster (`merchant`) bleibt wie bisher.
  - **Reiter „Händler“** im Broker-Fenster: Suche, „Nur mit AH-Gewinn“, Spalten Preis, Händler, Zone, Braucht, AH (grün mit „+“, wenn das Auktionshaus nach Anteil mehr bringt). Klick zeigt den Gegenstand.
  - **Tooltip-Baustein „Beim Händler“:** günstigster Händler mit Preis, Name und Zone (Standard mit Umschalt).
  - Quellen nennen Zahl der Händler, Angebote und den ältesten Besuch.
  - Der Peon Manager liest die Händler aus `Peon_Broker.lua` (Manager 0.25.0), die Bridge braucht dafür nichts.
  - **Im Spiel prüfen:** einige Händler öffnen (auch einen Rüstmeister mit Ruf und Marken), dann Reiter Händler und Tooltip mit Umschalt.

## 0.51.0

Kurz: Das Broker-Fenster enthält jetzt nur noch, was ohne Auktionshaus geht: Einkaufslisten, Markt, Gegenstände, Beobachtung und Quellen. Verkaufen, Auktionen und Radar findest du im Auktionshaus selbst.
Kurz: Neu sind der Vergleich deiner Fraktion mit dem neutralen Auktionshaus (Reiter Markt) und bei jedem Gegenstand dein Bestand mit Kosten aus Ledger.

- 0.51.0 (09.11.2026): **Umbau U10, Broker-Fenster neu** (Konzept Abschnitt 8). Neue Datei `Pages.lua`.
  - **Reiter:** Einkaufslisten, Markt, Gegenstände (bisher Preise), Beobachtung, Quellen. Start, Verkaufen, Behalten, Meine Auktionen und Radar haben keinen Reiter mehr. Ihre Seiten bleiben bis U12 angemeldet (das Radar hängt im Auktionshaus). Ein alter gemerkter Reiter öffnet Gegenstände.
  - **Markt:** Datenstand je Markt (Fraktion und Neutral, grün bis 1 Tag, orange älter) und Vergleich Fraktion gegen Neutral nach Gebühr beider Häuser, Filter „Nur Bestand“ und Mindestabstand in %, Klick zeigt den Gegenstand.
  - **Beobachtung:** günstigstes Angebot, Grenze, üblicher Bereich, Alarm, Grenze in Gold änderbar, Info, Entfernen.
  - **Quellen:** Märkte mit Stand, Werte vom Manager (Quelle und Alter), woher üblicher Bereich und Absatz kommen, Anteil der Häuser, Listen, Knopf „An Manager übergeben“ (lädt neu).
  - **Gegenstände:** Abschnitt „Mein Bestand“ mit Peon_Ledger (Vorrat gesamt, Taschen, Bank, Twinks, Kosten je Stück, eigene Verkäufe).
  - Noch nicht: einheitlicher Listen-Stil wie Blizzards Kaufliste und Diagramm in der Gegenstandsansicht (das Diagramm gibt es im Tooltip).
  - **Im Spiel prüfen:** alle fünf Reiter, Vergleich nach einem Scan in Beutebucht, Mein Bestand bei einem Gegenstand mit Vorrat.

## 0.50.0

Kurz: Blizzards Reiter „Auktionen“ zeigt jetzt bei jeder deiner Auktionen, ob sie das günstigste Angebot ist, unterboten wurde oder zu teuer ist. Darüber stehen Anzahl, Unterbotene und Gesamtwert, mit „Prüfen“ fragt Broker alle live ab.

- 0.50.0 (09.11.2026): **Umbau U9, Auktionen** (Konzept Abschnitt 7.3). Neue Datei `AuctionsAH.lua`.
  - **Kopfzeile** über Blizzards Liste (links neben „Neu laden“): laufende Auktionen, davon unterboten, Wert zum Sofortkaufpreis. Knopf **„Prüfen“** startet die Live-Prüfung aller eigenen Gegenstände (`A.StartLive` aus dem bisherigen Reiter Meine Auktionen).
  - **Status je Zeile** rechts in der Gegenstandsspalte: Günstigstes (grün), gleichauf (gelb), unterboten: Preis (orange), zu teuer: üblich (rot, Preis über dem üblichen Bereich), verkauft (grau).
  - Broker schreibt nichts in Blizzards Liste: eine eigene Uhr liest alle 0,3 Sek. die sichtbaren Zeilen (`ScrollBox:ForEachFrame`, `rowData.auctionID`) und setzt eigene Texte. Die eigenen Auktionen liest Broker nach Blizzards Abfrage (`OWNED_AUCTIONS_UPDATED`) mit.
  - Abbrechen und neu einstellen bleiben Blizzards Knöpfe. Bei „Blizzard pur“ nichts davon.
  - **Im Spiel prüfen:** Reiter Auktionen: Sitzt der Status in der Gegenstandsspalte, ohne Namen zu überdecken? Kopfzeile neben „Neu laden“? „Prüfen“ aktualisiert die Angaben?

## 0.49.0

Kurz: Die Einkaufsliste ist zurück und steht auch als Reiter „Einkaufen“ im Auktionshaus. Jede Zeile sagt, ob sich Kaufen lohnt, und die Zahl am Reiter zeigt, wie viel gerade kaufbar ist.
Kurz: Neu ist die Beobachtung mit Preisalarm: Strg+Rechtsklick auf einen Gegenstand, „Beobachten“, Preisgrenze wählen. Fällt der Preis darunter, meldet Broker sich. Im Manager heißen die Favoriten jetzt ebenfalls Beobachtung und werden abgeglichen.

- 0.49.0 (09.11.2026): **Umbau U8, Einkaufslisten und Beobachtung** (Konzept Abschnitte 7.5, 8.2, 8.7). Neue Datei `Watch.lua`.
  - **Einkaufsliste nicht mehr in Arbeit** (WIP aus 0.37 entfernt). Die Menge wirkte schon als Ziel inklusive Vorrat (`B.Plan` kauft höchstens Wunsch minus Vorrat aller Charaktere), neu sind die Spalten **Fehlt** (Ziel minus Vorrat) und **Rat** (KAUFEN, TEILWEISE, ZU TEUER, PRÜFEN, erledigt), sortierbar.
  - **Reiter „Einkaufen“ im Auktionshaus:** dieselbe Fläche, umgehängt wie das Radar. Zahl am Reiter: alle Zeilen aus allen Einkaufslisten und der Beobachtung mit Rat Kaufen oder Teilweise, ohne Blinken, neu nach Scan, Stand vom Manager und Live-Prüfung.
  - **Beobachtung** (`PeonBrokerDB.watch`, Löschmarken `watchGone`): im Gegenstandsmenü „Beobachten“ (Haken) und „Preisgrenze“ (10/20/30 % unter dem Vergleichspreis, jetziger Preis, keine Grenze). In der Einkaufsliste als eigene Liste „Beobachtung“ (nicht löschbar, Grenze über „Max.“ änderbar). Zeichen in Zeile 1 des Tooltips wie bei Einkaufslisten.
  - **Preisalarm:** liegt das günstigste Angebot auf oder unter der Grenze, einmal Meldung im Chat und Ton (Einstellung des Radars), wieder erst nach einem Preis darüber. Geprüft nach Komplettscan, Stand vom Manager und jeder Live-Abfrage.
  - **Abgleich mit dem Manager** (`mod:MergeWatch`, über Bridge 0.9.0): je Gegenstand gewinnt die neuere Änderung, Löschmarken halten. Preisgrenzen bleiben im Spiel.
  - Noch nicht: Liste im Look von Blizzards Kaufliste (U10), „Alles Lohnende kaufen“ als Ablauf, „Material auf Einkaufsliste“ aus dem Berufsfenster.
  - **Im Spiel prüfen:** Reiter Einkaufen im Auktionshaus, Spalten Fehlt und Rat, Kaufen. Beobachten über das Menü, Preisgrenze setzen, Alarm nach einem Scan. Abgleich mit dem Manager (Stern dort, Haken im Spiel).

## 0.48.0

Kurz: Das Radar steht jetzt als eigener Reiter im Auktionshaus. Findet ein Komplettscan Schnäppchen, steht am Reiter die Zahl der Treffer und er blinkt. Mit zwei neuen Tasten kaufst du den gewählten Treffer oder springst zum nächsten.

- 0.48.0 (09.11.2026): **Umbau U7, Radar im Auktionshaus** (Konzept Abschnitt 7.4).
  - Der Reiter „Radar“ im Auktionshaus zeigt das vorhandene Radar mit allen Funktionen. Die Fläche wird zwischen Broker-Fenster und Auktionshaus umgehängt (`AHTabs.Attach`/`Release`), nichts wird doppelt gebaut. Öffnet man das Radar im Broker-Fenster, holt das Fenster es zurück.
  - `R.Shown()` ersetzt die Prüfung „Broker-Fenster offen und Reiter Radar“: Radar-Scan, Gold-Anzeige und Auffrischen nach dem Scan laufen an beiden Orten.
  - Im Reiter schaltet Broker Blizzards Kaufansicht nicht mehr um (`ShowInAH` gesperrt, solange ein Broker-Reiter offen ist), sonst würde sich der Reiter schließen. Gekauft wird über Brokers Knöpfe wie bisher.
  - **Zahl am Reiter:** Nach jedem Komplettscan zählt Broker die Treffer, „Radar (3)“ blinkt, bis der Reiter geöffnet wird.
  - **Tastenbelegungen** (Tastenbelegung > AddOns > Peon Broker): „Radar: gewählten Treffer kaufen“ (wie der mittlere Kaufknopf) und „Radar: nächster Treffer“ (überspringt weggefallene, am Ende wieder von vorn). Neue Datei `Bindings.xml`.
  - Noch nicht: Aussehen der Liste wie Blizzards Kaufliste (kommt mit dem gemeinsamen Listen-Stil in U10), Auswahl springt nach einem Kauf von selbst weiter.
  - **Im Spiel prüfen:** Reiter Radar im Auktionshaus: Passt die Fläche, läuft der Radar-Scan, klappt Kaufen? Komplettscan mit Treffern: Zahl und Blinken? Tasten belegen und ausprobieren.

## 0.47.0

Kurz: Mit Umschalt zeigt der Tooltip jetzt ein kleines Preisdiagramm: das günstigste Angebot der letzten 14 Tage und den üblichen Bereich als grüne Fläche. Zeitraum (7, 14 oder 30 Tage) und Anzeige stellst du auf der Optionsseite ein.

- 0.47.0 (09.11.2026): **Umbau U6, Diagramm im Tooltip** (Konzept Abschnitt 6.4). Neuer Baustein „Diagramm“ (Formate 14, 7, 30 Tage, Standard mit Umschalt).
  - Linie: günstigstes Angebot je Tag aus Brokers Tageswerten (Lücken bleiben leer), Fläche: üblicher Bereich. Kern-Baustein `Peon.NewChart`, 210 × 54 Punkte.
  - Wie Blizzards `GameTooltip_InsertFrame`, aber ohne in den Tooltip zu schreiben: Überschrift und Leerzeilen anfügen, eigenen Rahmen an der ersten Leerzeile ausrichten, Mindestbreite setzen. Beim Leeren oder Schließen des Tooltips (sicherer Anhang an `OnTooltipCleared` und `OnHide`) verschwindet der Rahmen und die Mindestbreite wird zurückgesetzt.
  - Neu gezeichnet wird nur, wenn sich Gegenstand, Zeitraum oder Werte ändern (Blizzard baut Tooltips im Auktionshaus alle 0,2 Sek. neu auf).
  - Erst ab zwei Tagen mit Werten. Nur im Gegenstands-Tooltip, nicht in der Vorschau (dort ein Platzhalter).
  - **Im Spiel prüfen:** Tooltip mit Umschalt bei einem Gegenstand mit mehreren Tagen Daten. Sitzt das Diagramm sauber? Verträgt es sich mit Peon_Tooltip und Vergleichs-Tooltips? Flackert etwas im Auktionshaus?

## 0.46.0

Kurz: Den Broker-Tooltip stellst du jetzt selbst zusammen: welche Zeilen, ob immer oder nur mit Umschalt, in welchem Format und in welcher Reihenfolge. Dazu gibt es die Vorlagen Schlank, Standard und Ausführlich und eine Vorschau auf der Optionsseite.

- 0.46.0 (09.11.2026): **Umbau U5, Tooltip neu** (Konzept Abschnitt 6). Neue Datei `TooltipOptions.lua`, `Tooltip.lua` umgebaut in Daten sammeln (`T.Context`), ausgeben (`T.Render`) und Einstellung (`T.Layout`).
  - **Zeile 1:** Erlös für den Stapel und dahinter Stück × Preis (`18g 40s (20 × 95s)`), Farbe der Marktlage, ein Wort bei „fällt“, „Dumping“, „keine Angebote“, höchstens ein Pfeil. Ohne „AH:“ davor. Zeichen für Gegenstände auf einer Einkaufsliste (Taschen-Symbol). Formate: Stapel und je Stück, nur Stapel, nur je Stück.
  - **Bausteine:** Markt (ab, Menge, Alter), Üblich, Absatz (am Tag), Einstellen (Vorschlag und Erlös), Händler, Neutral, Herstellen, Deine Verkäufe, Hinweis (nur der wichtigste). Je Baustein Wann (immer, mit Umschalt, aus), Format und Reihenfolge.
  - **Entfällt:** Zeilen „Angebote“, „AH Min/Median“ und „7 Tage“ (gehen in Markt und Üblich auf), Einstellgebühr als eigene Zeile (Format „Mit Gebühr“), Pfeile an jedem Wert, der Hinweis „(Umschalt)“ (als Schalter weiter da, Standard aus).
  - **Optionsseite:** Vorlagen Schlank (nur Zeile 1), Standard, Ausführlich (alles ohne Umschalt), Zeile 1, Liste der Bausteine mit Auswahllisten und Pfeilen, Vorschau mit Beispielwerten (mit und ohne Umschalt umschaltbar). Ersetzt die Schalter „7 Tage“, „Händler“, „Hinweise“ und „Zeile Neutral“. Deren Werte werden beim ersten Start übernommen.
  - Gespeichert in `PeonBrokerDB.tooltipLayout`. Kaputte oder alte Einstellungen werden repariert, neue Bausteine späterer Versionen hängen sich aus an.
  - **Im Spiel prüfen:** Tooltip ohne und mit Umschalt. Optionsseite: Auswahllisten, Pfeile, Vorlagen, Vorschau. Passt alles nebeneinander auf die Seite?

## 0.45.0

Kurz: Strg+Rechtsklick auf einen Gegenstand bietet jetzt „Info (Broker)“ und „Auf Einkaufsliste“ mit allen deinen Listen an.

- 0.45.0 (09.11.2026): **Umbau U4, Einträge im Gegenstandsmenü** (Konzept Abschnitt 9, braucht Peon 0.16.0 mit API 16, sonst kein Menü). Neue Datei `Menu.lua`.
  - „Info (Broker)“ öffnet das Broker-Fenster beim Reiter Preise mit dem Gegenstand (bis zum neuen Fenster in U10).
  - „Auf Einkaufsliste“: Untermenü mit allen Listen und „Neue Liste …“.
  - „Beobachten“ kommt mit U8.
  - **Im Spiel prüfen:** Strg+Rechtsklick auf einen Gegenstand in der Tasche, „Auf Einkaufsliste“ und „Info (Broker)“ ausprobieren.

## 0.44.0

Kurz: Legst du im Auktionshaus etwas ins Verkaufsfenster, sagt Broker darunter, ob du zu diesem Preis verkaufen solltest: Verkaufen, Lieber warten, Verkaufen (Preis fällt) oder Lieber zum Händler, jeweils mit kurzem Grund.

- 0.44.0 (09.11.2026): **Umbau U3, Rat im Verkaufsfenster** (Konzept Abschnitt 7.2). Neue Datei `Advice.lua`.
  - Kasten unter Blizzards Knopf „Auktion erstellen“: oben das Urteil groß und farbig, darunter ein Satz, warum, dann Üblich, Absatz und Erlös für die Menge (mit Händlerwert). Am neutralen Haus steht oben rechts „Neutral“.
  - Broker trägt nichts in Blizzards Felder ein. Das Urteil gilt für den Preis, der gerade im Feld steht, und wird bei jeder Änderung neu gerechnet (sicherer Anhang an `UpdatePostState` beider Verkaufsfenster).
  - Urteile: Verkaufen (im Bereich, knapp darunter oder darüber), Lieber warten (mehr als 15 % unter dem unteren Rand, `A.WAIT_PCT`), Verkaufen, Preis fällt (Bereich schon länger nach unten verschoben), Lieber zum Händler (Erlös nach Anteil unter dem Händlerpreis), Keine Einschätzung (kein üblicher Bereich). Zusatz „Viel Ware im Markt“, wenn die Angebote länger als 3 Tage Absatz reichen (`A.FULL_DAYS`). Die Grenzwerte sind ein erster Vorschlag.
  - Blizzards Angebote für das Verkaufsfenster liest Broker mit und übernimmt sie als Live-Stand. Eine eigene Suche schickt er nicht ab.
  - Bei „Blizzard pur“ kein Kasten und kein Anhang.
  - **Im Spiel prüfen:** Gegenstand aus der Tasche ins Verkaufsfenster legen: Erscheint der Kasten unter „Auktion erstellen“, passt er über „Sofortkaufmodus“? Preis von Hand ändern: Wechselt das Urteil? Sind die Grenzwerte sinnvoll?

## 0.43.0

Kurz: Broker liest aus deinen Verkaufsrechnungen in der Post, wie viel jedes Auktionshaus einbehält. Der Vergleich mit dem neutralen Auktionshaus im Tooltip rechnet damit, ein „?“ heißt: noch nicht gemessen.

- 0.43.0 (09.11.2026): **Umbau U2, Anteil je Markt** (Konzept Abschnitt 5.3). Neue Datei `Cut.lua`.
  - Beim Öffnen des Briefkastens (`MAIL_INBOX_UPDATE`) liest Broker alle Verkaufsrechnungen (`GetInboxInvoiceInfo`, Art „seller“) und rechnet Anteil ÷ Verkaufspreis. Das Haus erkennt er am Absender („Auktionshaus der Allianz“ im Spiel gesehen): Allianz, Horde, jedes andere Auktionshaus gilt als neutral. Verkäufe unter 20 Silber zählen nicht (Rundung), jede Rechnung nur einmal je Sitzung. Gespeichert in `PeonBrokerDB.cut[Fraktion]` (Median der letzten 10).
  - `D.Cut(markt)` ersetzt den festen Anteil `D.CUT` überall (Erlös, kleinster lohnender Preis, Radar, Verkaufen). Ohne Messung bleibt es bei 5 %. `D.CutSure(markt)`: Fraktionshäuser gelten als bestätigt, das neutrale erst nach einer Messung.
  - Zeile „Neutral“ im Tooltip: Abstand jetzt nach Gebühr beider Häuser, graues „?“ solange der neutrale Anteil nicht gemessen ist.
  - `/broker pruefen ah` nennt die gemessenen Anteile.
  - **Im Spiel prüfen:** Nach einem Verkauf in Beutebucht den Briefkasten öffnen, dann `/broker pruefen ah`: Steht dort ein Anteil für Neutral? Verschwindet das „?“ im Tooltip?

## 0.42.0

Kurz: Der Tooltip zeigt jetzt immer die Preise des Auktionshauses deiner Fraktion, auch wenn du am neutralen Auktionshaus stehst. Die Preise des neutralen Hauses stehen in einer eigenen Zeile „Neutral“ mit dem Unterschied in Prozent.

- 0.42.0 (09.11.2026): **Umbau U1, Heimatmarkt** (Konzept Abschnitt 5). Bisher galt bei offenem neutralen Auktionshaus überall der neutrale Markt (Regel aus 0.40.0), Tooltips zeigten dort die meist höheren neutralen Preise.
  - **Zwei Märkte:** `ns.HomeMarketKey()` (immer eigene Fraktion) und `ns.AHMarketKey()` (Markt am offenen Haus). `ns.MarketKey()` ist der Markt am offenen Haus, außer innerhalb von `ns.WithHome(fn, …)`. Die Klammer wirkt bis in verschachtelte Abfragen (Lookup, Bereich und Absatz vom Manager) und setzt den Markt auch nach einem Fehler zurück.
  - **Immer Heimatmarkt:** Tooltip, Wert für Ledger (`ItemValue`, `MarketInfo`, `History`, `MarketItems`), Materialpreise im Berufsfenster. Scan, Live-Abfragen, Verkaufen, Kaufen, Radar und Auktionen bleiben beim Markt am offenen Haus.
  - **Zeile „Neutral“:** günstigstes Angebot im neutralen Haus je Stück, dahinter der Abstand zum Heimatmarkt in Prozent (grün höher, orange niedriger), bei Daten älter als ein Tag das Alter. Nur wenn es neutrale Daten mit Angeboten gibt. Einstellung `tooltipNeutral`: immer, nur mit Umschalt (Standard), aus. Die Gebühren beider Häuser stecken noch nicht im Vergleich (kommt mit U2).
  - **Im Spiel prüfen:** In Beutebucht mit offenem Auktionshaus den Tooltip ansehen: Preis wie in Sturmwind? Mit Umschalt Zeile „Neutral“ mit Prozent? Einstellung „Zeile Neutral“ auf der Optionsseite.

## 0.41.2

Kurz: Die Reiter Radar und Einkaufen sind jetzt hervorgehoben, wenn du sie anklickst, und haben den gleichen Abstand wie Blizzards Reiter.

- 0.41.2 (09.11.2026, nach dem zweiten Test von KarloDerBaer): **Ursache gefunden.** Blizzards Reiter-Vorlage (`PanelTabButtonTemplate`, `parentArray="Tabs"`) trägt jeden Reiter in die Liste `Tabs` seines Elternrahmens ein. Radar und Einkaufen hingen am Auktionshaus und standen deshalb in Blizzards Liste `AuctionHouseFrame.Tabs`. Folgen: Brokers „Blizzard-Reiter abwählen“ wählte auch Radar gleich wieder ab, und Blizzards Liste war verändert, ohne dass `issecurevariable` es meldet (es prüft nur den Eintrag, nicht den Inhalt).
  - Die Reiter hängen jetzt an einem eigenen Rahmen `PeonBrokerAHTabHolder`. Blizzards Liste bleibt bei drei Reitern.
  - Die Prüfung (`/broker pruefen ah`, Fläche) zeigt zusätzlich „Tabs (Inhalt)“: steht ein Broker-Reiter in Blizzards Liste?
  - Abstand zum Reiter davor -7 statt -15 (`T.TAB_GAP`), auf den Bildern lagen Brokers Reiter enger als Blizzards.
  - Der Test baut die Vorlage jetzt mit Eintrag in die Liste und Seitenteilen nach, so wäre der Fehler aufgefallen.
  - **Im Spiel prüfen:** Radar anklicken: hervorgehoben wie Blizzards gewählter Reiter? Abstände gleichmäßig? `/broker pruefen ah`: auch „Tabs (Inhalt)“ sauber?

## 0.41.1

Kurz: Die neuen Reiter Radar und Einkaufen decken das Auktionshaus jetzt ganz ab, der gewählte Reiter ist hervorgehoben, und der Knopf „Blizzard pur“ ist oben rechts in der Titelleiste zu sehen. Der Knopf „Broker“ unter dem Auktionshaus entfällt.

- 0.41.1 (09.11.2026, nach dem ersten Test von KarloDerBaer): Die Prüfung war sauber (alle Werte „sauber“, keine Blockade), die Oberfläche hatte drei Fehler.
  - **Fläche über alle Blizzard-Elemente:** Gegenstandsfeld, „Auktion erstellen“ und „Sofortkaufmodus“ aus dem Verkaufsfenster lagen über Brokers Fläche. Die Fläche liegt jetzt 500 Ebenen über dem Auktionshaus statt 20 (`T.PAGE_LEVEL`).
  - **Gewählter Reiter hervorgehoben:** Radar und Einkaufen sahen nie gewählt aus. Broker stellt die Seitenteile der Reiter (`Left/Middle/Right` und `…Active`) jetzt selbst um, zusätzlich zu `PanelTemplates_SelectTab`. Fehler dort landen im Debug-Log.
  - **Knopf „Blizzard pur“ sichtbar:** lag unter Blizzards Rahmen. Jetzt in der Titelleiste links neben dem Schließen-Knopf, über dem Rahmen, kleinere Schrift.
  - **Knopf „Broker“ unter dem Auktionshaus entfällt** (laut Konzept ohnehin geplant): Er lag halb hinter Blizzards Reitern (roter Rest links neben „Kaufen“). Das Fenster öffnen Minimap-Button, Peon_Panel und `/broker`.
  - **Im Spiel prüfen:** Verkaufen wählen, dann Radar: Ist nichts vom Verkaufsfenster mehr zu sehen? Ist Radar hervorgehoben wie Blizzards gewählter Reiter? Ist „Blizzard pur“ oben rechts zu sehen, und klappt an und aus (alternativ `/broker pur`)?

## 0.41.0

Kurz: Im Auktionshaus gibt es zwei neue, noch leere Reiter „Radar“ und „Einkaufen“ zum Ausprobieren. Oben rechts schaltet der Knopf „Blizzard pur“ Broker im Auktionshaus ganz ab, falls einmal etwas blockiert.

- 0.41.0 (09.11.2026): **Umbau U0, Prüfaufbau** (Konzept `docs/konzepte/broker/Peon_Broker_Umbau.md`, Abschnitte 7.1 und 7.7). Neue Datei `AHTabs.lua`.
  - **Eigene Reiter im Auktionshaus:** „Radar“ und „Einkaufen“ rechts neben Blizzards „Auktionen“ (Vorlage `AuctionHouseFrameTabTemplate`). Broker fügt nichts zu `AuctionHouseFrameDisplayMode` oder `AuctionHouseFrame.Tabs` hinzu und ruft `SetDisplayMode` dafür nie auf. Ein Klick legt eine eigene Fläche über Blizzards Inhalt und stellt nur das Aussehen der Reiter um. Wechselt Blizzard die Ansicht (Reiter, Gegenstand aus der Tasche), blendet ein sicherer Anhang an `SetDisplayMode` die Fläche wieder aus. Die Fläche zeigt live, ob Blizzards Werte noch sauber sind (`issecurevariable`).
  - **`/broker pruefen ah`:** gleiche Prüfung im Chat, Ergebnis in `PeonBrokerDB.ahProbe`.
  - **Notausgang „Blizzard pur“** (`ahPlain`, bleibt bei „Standardwerte“): Knopf oben rechts im Auktionshaus, `/broker pur` oder Knopf auf der Optionsseite, jeweils mit Rückfrage und Neuladen. Danach legt Broker keine Reiter und Knöpfe am Auktionshaus an und legt nichts in Blizzards Fenster (Verkaufen, Kaufansicht, Ansicht umschalten). Tooltip, Broker-Fenster und `/broker scan` gehen weiter. Der Starter-Tooltip erinnert daran.
  - **Blockierte Aktionen:** Meldet das Spiel `ADDON_ACTION_BLOCKED` oder `ADDON_ACTION_FORBIDDEN` für Peon_Broker, merkt Broker das (`PeonBrokerDB.ahBlocked`, Fehlerspeicher) und bietet bei offenem Auktionshaus einmal je Sitzung „Blizzard pur“ an.
  - **Im Spiel prüfen:** Nach `/reload` ohne vorher das Broker-Fenster zu benutzen: Auktionshaus öffnen, Reiter Radar und Einkaufen anklicken, zurück zu Kaufen, Verkaufen und Auktionen. Dann etwas kaufen (Massenware und Einzelgegenstand), etwas einstellen und eine Auktion abbrechen. Kommt „Aktion wegen AddOn blockiert“? Danach `/broker pruefen ah`: Stehen alle Werte auf „sauber“? Sitzt die Fläche richtig (Suchleiste und Listen verdeckt, Porträt frei)? „Blizzard pur“ an und wieder aus.

## 0.40.0

Kurz: Am neutralen Auktionshaus (zum Beispiel in Beutebucht) speichert Broker die Preise in einem eigenen Markt „Neutral“. Deine Preise aus dem Auktionshaus deiner Fraktion bleiben davon unberührt.

- 0.40.0 (09.11.2026, KarloDerBaer in Beutebucht): **Neutraler Markt.** Bisher bestand der Markt immer aus Realm-Name und Fraktion des Charakters, ein Scan am neutralen Haus wäre im Markt der eigenen Fraktion gelandet. Jetzt prüft `ns.MarketKey()` bei offenem Auktionshaus die Fraktion des Auktionators (`UnitFactionGroup("npc")`). Hat er keine, heißt der Markt `<Realm> / Neutral`. Geprüft im Spiel: „Auktionator O'reely“ in Beutebucht hat keine Fraktion. Ob das Auktionshaus offen ist, fragt `ns.AtNeutralAH()` beim Spiel nach (`C_PlayerInteractionManager`), damit es nicht von der Reihenfolge der Ereignisse abhängt. Nach dem Schließen gilt wieder der eigene Markt, Tooltips zeigen dann wieder die Preise der eigenen Fraktion.
  - **Im Spiel prüfen:** Am neutralen Haus zeigt der Tooltip des Scan-Knopfs „… / Neutral“, am Haus der eigenen Fraktion weiter „… / Alliance“.

## 0.39.0

Kurz: Im Berufsfenster stehen Kosten, Vorrat und Gewinn jetzt direkt unter den Reagenzien. In der Rezeptliste siehst du den Gewinn jedes Rezepts, das beste ist golden markiert. Alles lässt sich über das Zahnrad einstellen.
Kurz: Eine Tabelle zeigt je Material, ob es aus deinem Vorrat kommt oder beim Händler oder im AH gekauft wird, was es kostet und was dein Material im AH bringen würde.
Kurz: Bringt der Verkauf deines Materials mehr als das Herstellen, sagt Broker es dir und färbt den Gewinn in der Rezeptliste orange.

- 0.39.0 (08.11.2026, Wunsch KarloDerBaer): **Block unter den Reagenzien** statt der Box neben dem Fenster. Oben die Ergebniszeile mit Kosten, Ertrag und Gewinn, darunter eine Tabelle je Material, darunter ein Hinweis. Haken „Twinks mitzählen“ (gleiche Einstellung wie im Reiter Behalten, nur mit Ledger) und Zahnrad mit allen Einstellungen.
  - **Tabelle** (nach zwei Tests im Spiel mit KarloDerBaer abgestimmt): Spalten Material, Quelle, Kosten, Erlös, darunter Gesamt. Je Material eine Zeile. Reicht der Vorrat nicht, hat das Material zwei Zeilen: Vorrat und Kauf. Quelle ist „Vorrat“, „Händler“ oder „AH“ (wo es günstiger ist), „?“ ohne Preis. Kosten: Vorrat laut Ledger (nächstes Stück), ohne Wert im Ledger der AH-Preis mit „~“. Kauf: Menge × günstigster Preis. Erlös: was das Material aus dem Vorrat im AH nach Gebühr bringen würde (`ns.ItemValue`), bei Kauf „-“.
  - **Rechnung** (`C.CalcFull`): Gewinn = Ertrag minus Kosten, nur diese eine Zahl, auch in der Rezeptliste. Herstellen bringt Ertrag minus Kaufkosten (der Vorrat ist schon da). Bringt der Erlös des Vorrats mehr (`sellBetter`), steht der Gewinn in der Rezeptliste orange und das Rezept bekommt keinen goldenen Strich. Die Einstellung mit drei Rechnungen (`craftProfitMode`) aus den Zwischenständen entfällt.
  - **Hinweis:** „Dein Vorrat reicht für N×“, wenn nichts zu kaufen ist. Mit Material aus dem Vorrat beide Beträge: „Material verkaufen bringt mehr: 18c statt -1s 53c beim Herstellen“ (orange) oder „Herstellen bringt mehr: 20c statt 18c beim Verkauf des Materials“. Vorher stand nur der Abstand („bringt 1s 71c mehr“), das las sich wie ein Gewinn. „Lieber verkaufen“ allein war unklar, weil nicht dastand, dass das Material gemeint ist (KarloDerBaer).
  - **Händlerpreise** (neue Datei `Merchant.lua`, `ns.Merchant`): Das Spiel nennt den Kaufpreis beim Händler nur bei offenem Händlerfenster. Drei Quellen, die beste zuerst: beim Händlerbesuch gemerkt (`MERCHANT_SHOW`, `MERCHANT_UPDATE`, accountweit in `PeonBrokerDB.merchant[itemID] = { p, t, w }`, Preis je Stück, nur gegen Gold), letzter Kauf beim Händler laut Peon_Ledger (`mod:VendorBuy`, ab Ledger 0.13.1), geschätzt für bekannte Händler-Reagenzien (`V.LIST`: Fäden, Farbstoffe, Gewürze, Phiolen, Flussmittel und Ähnliches) als Ankaufspreis des Händlers × 4, grau und mit „~“.
  - **Tooltips:** Über Quelle, Kosten und Erlös einer Zeile: beim Vorrat wo es liegt, deine Kosten, AH-Preis und Erlös. Beim Kauf AH-Preis, Händlerpreis mit Herkunft und Vorrat. Über den Kästen: wie sich Kosten, Ertrag und Gewinn ergeben, beim Gewinn dazu der Vergleich Herstellen gegen Verkaufen und „Alles gekauft“.
  - **Rezeptliste sofort beschriftet** (nach dem ersten Test: Gewinne kamen erst nach etwa einer Minute, beim Wechsel des Berufs mal sofort, mal später): Das Ereignis `TRADE_SKILL_LIST_UPDATE` kam oft mehrmals hintereinander, Broker las höchstens alle 2 Sek. und verschluckte dabei das letzte, vollständige. Jetzt merkt sich Broker, dass neu gelesen werden muss, und liest beim nächsten Takt (höchstens alle 0,5 Sek., `C.READ_GAP`). Zeigt die Liste ein Rezept, das Broker noch nicht gelesen hat (anderer Beruf, Liste kam später), liest er ebenfalls nach.
  - **Rezeptliste:** Gewinn rechts in jeder Rezeptzeile, goldener Strich am besten Rezept. Die Zeilen baut das Spiel beim Scrollen neu, Broker beschriftet sie alle 0,1 Sek. und beim Belegen einer Zeile neu. Eigene Schriften und Striche hängen an den Zeilen, in Blizzards Tabellen schreibt Broker nichts.
  - **Einstellungen** (im Zahnrad-Menü und auf der Optionsseite unter „Berufe“): `craftList`, `craftListWhich` (alle, nur mit Gewinn, nur die besten 3, 5 oder 10), `craftListMode` (Betrag oder Prozent vom Material), `craftListBest`, `craftListLoss`, `craftListUnknown`, `craftBlock`, `craftSummary`, `craftColSrc`, `craftColCost`, `craftColSell`, `craftHint`, `keepAllChars`.
  - Rezepte merken die Reihenfolge der Materialien (`o`). Die Box daneben bleibt als Rückfall, wenn das Fenster keinen Reagenzien-Bereich hat (altes Berufsfenster).
  - Neuer Prüfbefehl `/broker pruefen beruf`: zeigt den Aufbau des Berufsfensters (Teile des Rezeptformulars, Anker, Zeilen der Rezeptliste) und speichert ihn in `PeonBrokerDB.craftProbe`.
  - **Im Spiel prüfen:** Sitzt der Block unter den Reagenzien und überdeckt nichts (auch bei Rezepten mit vielen Reagenzien)? Stehen die Gewinne in der Rezeptliste an der richtigen Zeile, auch nach Scrollen und Suchen? Überdecken sie lange Rezeptnamen? Öffnet das Zahnrad das Menü? Passen Spalten und Namen in die Tabelle? Stimmen die geschätzten Händlerpreise mit dem überein, was ein Händler mit Reagenzien wirklich verlangt? Keine Meldung „Aktion wegen AddOn fehlgeschlagen“ beim Herstellen? Falls etwas nicht passt: `/broker pruefen beruf` und die Ausgabe schicken.

## 0.38.0

Kurz: Fällt ein Preis stark, folgt der übliche Bereich jetzt schneller. Bisher hat Broker einen echten Preissturz in den ersten Tagen teils als Ausreißer abgeschnitten.

- 0.38.0 (08.11.2026, Wunsch KarloDerBaer, Beispiel Magicusmantel): **Kürzung nach unten (F37a):** Beim gleitenden Mittelwert werden Tageswerte nach unten erst ab 75 % unter der Mitte gekürzt (`D.BAND_CLIP_LOW_SCHW` = 25 %). Bisher galt auch nach unten das Dreifache der Schwankung. Bei wenigen, gleichen Tagen liegt die Schwankung bei 5 %, ein Sturz von 4g auf 1g 50s wurde so auf 3g 40s hochgesetzt. Nach oben bleibt die Kürzung, Mondpreise zählen weiter nicht. Gleiche Regel im Peon Manager 0.21.0, der Bereich ist also gleich, egal wer ihn rechnet.
  - Den Abstand zum nächsten Angebot prüft das Radar schon seit 0.26 (Verkauf höchstens zum nächsten Angebot), bei fallendem Markt gibt es seit 0.21 kein Markt-Schnäppchen.

## 0.37.0

Kurz: Die Einkaufsliste wird überarbeitet. Bis dahin zeigt der Reiter nur einen Hinweis.

- 0.37.0 (07.11.2026, Wunsch KarloDerBaer): Reiter Einkaufsliste zeigt nur „WIP: Update kommt bald“ (`W.WIP`, `L.TAB_WIP`), die Zeile zur Einkaufsliste unter Start entfällt. Der Code der Liste bleibt und wird für die Überarbeitung weiter getestet.

## 0.36.0

Kurz: Broker nutzt jetzt auch die neueren Preise aus dem Peon Manager, zum Beispiel aus der Blizzard-API. Auf der Leiste steht das Alter der neuesten Daten.

- 0.36.0 (07.11.2026, Wunsch KarloDerBaer): **Stand vom Manager:** Beim Anmelden und nach `/reload` holt Broker über Peon_Bridge 0.7.0 den neuesten Stand des Managers (`D.ApplyManager`). Ist er für einen Gegenstand neuer als Scan und Live-Abfrage, gilt er wie eine Live-Abfrage: aktueller Preis, Median, Menge und Angebote, Zeit in `e.lt`. Verlauf, Trend und Zahl der Scans bleiben reine Scan-Werte. Gegenstände, die im Stand fehlen, gelten als weg. Die günstigsten Stufen (`lv`) kennt der Manager nicht, sie fallen für diese Gegenstände weg, Schnäppchen kommen also weiter nur aus eigenen Scans und Live-Abfragen. Neue Felder im Markt: `mgrAt`, `mgrSrc`, `mgrItems`.
  - **Peon_Panel:** Der Text „Alter der neuesten Daten“ (Schlüssel `age`, Standard) nimmt den neueren Wert aus Scan und Manager. Das reine Scan-Alter gibt es als „Alter des letzten Scans“ (`scanAge`). Der Tooltip zeigt zusätzlich „Blizzard-API: vor … (… Gegenstände)“.
  - Das Spiel liest `Data.lua` nur beim Anmelden und nach `/reload`. Neuere Stände des Managers kommen also erst danach an.
  - **Im Spiel prüfen:** Stimmen Tooltip-Preise und Vorschläge nach `/reload` mit dem API-Stand, bleibt das Laden flüssig?

## 0.35.0

Kurz: Mit Peon_Panel zeigt Broker auf der Leiste das Alter des letzten Scans oder die Zahl der Angebote.

- 0.35.0 (07.11.2026): Texte für Peon_Panel: Alter des letzten Scans (Standard), Angebote im letzten Scan. Nach einem Scan aktualisiert. Ohne Peon_Panel ändert sich nichts.

## 0.34.0

Kurz: Einkaufslisten gelten jetzt für alle Charaktere und gleichen sich mit dem Peon Manager ab.
Kurz: Neu: eigener Höchstpreis je Gegenstand auf der Einkaufsliste.

- 0.34.0 (06.11.2026, Wunsch KarloDerBaer): **Einkaufslisten accountweit, Abgleich mit dem Manager.** Neue Datei `Shop.lua` (Regeln des Abgleichs, gleich wie `manager/src/core/shopping.js`). Listen liegen in `PeonBrokerDB.lists` mit Nummer und Änderungszeit, Löschmarken in `listsGone`, die gewählte Liste bleibt je Charakter. Listen eines Charakters werden beim ersten Laden übernommen, bei gleichem Namen in die vorhandene Liste. `mod:MergeShop(data)` mischt die Listen aus dem Manager ein. Eigener Höchstpreis in Gold je Gegenstand (`max` in Kupfer) geht vor dem Wert der Liste. **Im Spiel prüfen (WoW neu starten, neue Datei):** Listen werden übernommen, Feld „Max. Gold“ passt neben den Text im Reiter Einkaufsliste, Abgleich in beide Richtungen.

## 0.33.1

Kurz: Fehlermeldung nach dem Scan im Radar behoben.
Kurz: Der Schnellkauf für Massenware braucht jetzt zwei Klicks.

- 0.33.1 (05.11.2026): **Radar: Fehlermeldung nach dem Scan behoben** (`ADDON_ACTION_BLOCKED`, `UNKNOWN()`). Der Preis vorab für den Schnellkauf (`StartCommoditiesPurchase` ab 0.24) lief ohne Klick, das Spiel erlaubt die Funktion aber nur direkt aus einem Klick (`HasRestrictions` in Blizzards Doku, `pcall` fängt die Meldung nicht ab). Preis vorab ist aus (`R.preOff`), der Schnellkauf für Massenware braucht zwei Klicks: 1. Klick Preis, 2. Klick bestätigen. Hinweis am Knopf angepasst. **Im Spiel prüfen:** Scan im Reiter Radar ohne Meldung, Kauf von Massenware mit zwei Klicks.

## 0.33.0

- 0.33.0 (31.10.2026): Werte und Momentaufnahmen über **Peon_Bridge** (Modul `bridge`, bisher Peon_Client `client`) an zwei Stellen (`Data.lua` `D.ClientBand`, `Sales.lua` `S.ClientStats`). Die Bridge liefert nur Werte, wenn der Peon Manager den Kanal broker freischaltet, sonst rechnet Broker wie bisher selbst. Texte wie „Üblich (Client, n Tage)“ bleiben (gemeint ist der Manager mit dem Broker Client).

## 0.32.0

- 0.32.0 (23.10.2026, Peon Client C6, Rechenmodell F49): **Absatz vom Peon Client als Rückfall.** `Sales.Stats(e, now, key)`: hat Broker in den letzten 6 Std. weniger als 60 Min. selbst beobachtet (rot oder nichts), nimmt er Absatz je Std. (14-Tage-Wert ÷ 24), Quote und Sicherheit (nach beobachteter Zeit) vom Client, `src = "client"`. Gilt im Tooltip („Absatz (Client, 14 Tage)“), Reiter Preise, Verkaufen und beim Radar (Begrenzung nach Absatz). Neu für Peon_Client: `mod:IsCommodity(key)`, `mod:VendorPrice(id)`. Ohne Client oder bei Fehler wie bisher. Im Beta-Ordner blieb Broker bei 0.31.0 mit neuer Sales.lua (Dateien schreibgeschützt). In `_forever_` vollständig 0.32.0 (25.10.).

## 0.31.0

- 0.31.0 (23.10.2026, Peon Client C4, Rechenmodell Kapitel 8): **Langzeit-Teil des üblichen Bereichs vom Peon Client.** `D.ClientBand(key)` fragt Peon_Client (`LongTerm`) nach MITTE, SCHW, LANG und Tagen für den Gegenstand im eigenen Markt. Sind die Werte da und frisch (F43), nimmt `D.Band` sie statt der eigenen F35 bis F37 (SCHW mindestens 5 %, reicht auch bei weniger als 3 eigenen Tagen); HEUTE, Richtwert, Bereich, Trend und Schnäppchen rechnet Broker weiter selbst (F44). Ohne Peon_Client, ohne Werte, bei alten Werten oder bei einem Fehler im Client (abgefangen) rechnet Broker wie bisher. `D.Band` und `D.Deal` bekommen den Schlüssel als neuen letzten Wert (Verkaufen, Tooltip, Einkaufen, Radar). Anzeige „Üblich (Client, n Tage)“ im Tooltip, im Reiter Preise und beim Verkaufen. Nur mit dem Nachbau geprüft (Beta offline).

## 0.30.2

- 0.30.2 (22.10.2026, **Ursache gefunden** über `lastScanError`): „integer overflow attempting to store 49999996000“. Ein Angebot zum Höchstpreis (fast 5 Mio. Gold) brach den Scan ab, weil Broker Preise mit `%d` in seine kompakten Texte schrieb (Tageswerte in Data.lua, Absatz-Daten in Sales.lua samt Auktionsnummern). `%d` geht im Forever-Lua nur bis 2^31 (etwa 214.748 Gold). Jetzt `%.0f`. Hatte mit Peon_Client nichts zu tun. `test_client.lua` baut die Grenze von Forever nach (`string.format` mit `%d` über 2^31 = Fehler) und prüft Scan, Tageswert, Live-Abfrage und Absatz-Daten mit Höchstpreis und großer Auktionsnummer.

## 0.30.1

- 0.30.1 (22.10.2026, Fehler beim ersten Scan mit Peon_Client, Meldung im Chat nicht erhalten): Scheitert ein Arbeitsschritt des Komplettscans, bricht Broker den Scan sauber ab (Hinweis im Chat) und merkt die Meldung in `PeonBrokerDB.lastScanError` (Zeit, Text, Version, Phase, Stand), auch ohne Debug. Bisher lief der Scan dann bei jedem Bild erneut in den Fehler und wurde nie fertig. Abfrage `Peon.IsSecret` nur noch für vorhandene Links. Nachstellen mit KarloDerBaers echten Broker-Daten im Test lief fehlerfrei, die Ursache ist noch offen.

## 0.30.0

- 0.30.0 (22.10.2026, Peon Client C1): **Zuhörer für Momentaufnahmen** `mod:AddSnapshotListener(fn)` für Peon_Client. Komplettscan meldet `scan_start` (Markt, Zeit, Anzahl, Varianten), jedes Angebot als `scan_row` (auch reine Gebote, mit Mindestgebot, Gebot, Restzeit-Stufe, Link ab Qualität 2), `scan_end` bzw. `scan_abort`; jede Live-Abfrage meldet `live` (aus `Data.ApplyLive`, nicht bei Ergebnissen eines anderen Gegenstands). Ohne Zuhörer unverändert; ein Zuhörer mit Fehler wird entfernt und einmal gemeldet. Rechnung und Daten von Broker unverändert.

## 0.29.0

- 0.29.0 (07.10.2026, für Ledger 0.10): Schnittstelle `mod:MarketItems()` → alle Gegenstände des aktuellen Markts mit Nummer (Varianten ausgenommen): `{ [itemID] = { min, median, qty, t, gone, name, quality } }`.

## 0.28.1

- 0.28.1 (07.10.2026, **Absturz** beim Öffnen des Berufsfensters, Absturzbericht von KarloDerBaer): WoW brach mit „Assertion failure! L->top < L->ci->top (lapi.c)“ ab. Ursache: Die Box „Broker Herstellen“ sucht Leisten am Fensterrand (`C.SideOffset`, 0.25.2) und rief dafür `pcall(UIParent.GetChildren, UIParent)` auf – `pcall` mit mehreren Hundert Rückgabewerten überläuft im Forever-Lua den Platz des Aufrufs. Jetzt direkt `parent:GetChildren()`. Alle Peon-Module nach dem Muster durchsucht (sonst keine `pcall` mit vielen Rückgabewerten). Test mit 400 Kindern ergänzt.

## 0.28.0

- 0.28.0 (07.10.2026, Durchsicht des Moduls, alle Punkte mit KarloDerBaer abgestimmt):
  - **Ausrüstung mit Zusatz getrennt** (wichtigster Punkt): `keyLog` zeigte, dass Forever den Zusatz im Suchschlüssel (`itemSuffix` 14299–14340) und im Link als Bonus-Nummer ablegt, nicht im Link-Feld 7; die Preise der Varianten liegen weit auseinander (Gleißendes Claymore 17s–25g). Scan, Taschen und Links liefern den vollen Namen. Jetzt: Hat ein Gegenstand Varianten (`markets[…].variants[itemID]`), ist der Schlüssel `"itemID:voller Name"`. Der Scan erkennt Varianten (mehrere Namen, Link mit Bonus-Nummern oder Name ≠ Grundname aus `C_Item.GetItemInfo`; Grundname noch nicht geladen → vorerst unter der Nummer, nächster Scan entscheidet) und löscht dann den alten gemischten Eintrag und den gemerkten Schlüssel. Link je Variante in `e.lk` (Tooltip in den Listen).
  - **Suchschlüssel je Variante** werden nebenbei gelernt (`itemKeys["itemID:Name"] = "Stufe:Zusatz"`): beim Verkaufen (Taschen), aus eigenen Auktionen, aus jedem Suchergebnis (auch beim Stöbern im Blizzard-Fenster) und aus der Browse-Suche (`GetItemKeyInfo` – ob dort der volle Name kommt, im Spiel prüfen). Ergebnisse werden nach Variante gefiltert (Verkaufen, Einkaufen, Radar, Meine Auktionen) und gehen je Variante in die Datenbank. Radar, Einkaufsliste-Runde und Startseite lassen Varianten ohne gelernten Schlüssel aus (statt „weg“).
  - **Ledger:** `mod:ItemValue(itemID)` liefert bei Varianten den Wert der günstigsten Variante mit Angeboten (vorsichtig, KarloDerBaer). `MarketInfo`/`History` liefern für Gegenstände mit Varianten nichts (Ledger kennt nur Nummern).
  - **Kleine Fehler:** Reiter „Start“ wird als letzter Reiter gemerkt (`windowTab`, „book“ entfernt); Beschreibung (Optionen, TOC) und Meldung „braucht Peon 0.8“ aktualisiert; Warenart am Auktionshaus auch aus der Reagenzientasche; Kostenwarnung mit `D.CUT`.
  - **Schnellkauf abgesichert:** kein Preis vorab, solange ein Treffer gewählt oder Blizzards Kaufansicht für Massenware offen ist; Preisantworten in dieser Zeit gelten nicht als eigene, Broker bricht dann nie einen Kauf ab (`R.BlizzardBuying`).
  - **Datenmenge:** Absatz-Momentaufnahmen und Einzelvergleiche älter als 24 Std. werden beim täglichen Verdichten gelöscht (`Sales.Prune`); Vergleiche derselben Stunde werden zusammengefasst (höchstens 24 je Gegenstand); Fehlersuch-Protokolle (`radarLog`, `keyLog`, `showLog`, `aucLog`, `radarStats`) nur noch mit `/broker debug`, ohne Debug beim Start gelöscht; `posted`, `cancelled`, `bought`, `buyMode`, `dealMaxAge` und `depositCheck` entfallen (Abgleich der Einstellgebühr abgeschaltet, Formel bestätigt; Warenart wird nur noch einmal je Gegenstand gefragt).
  - **Kleinigkeiten:** Verkaufen lädt bei Teil-Ergebnissen den Rest nach (`RequestMore…SearchResults`, bis 5×; kommt nichts, gilt der Teil); Taschenliste bewertet jeden Gegenstand nur einmal, beim Einstellen ohne Bewertung (`ScanBags(true)`); rund 60 unbenutzte Texte entfernt.
  - Tests: test_broker um Schnellkauf, Aufräumen, Teil-Ergebnisse und Varianten ergänzt; alle Tests OK. **Im Spiel prüfen:** nach dem ersten Scan Ausrüstung mit Zusatz im Tooltip und im Reiter Preise (je Variante eigene Zeile?), Verkaufen einer Variante, ob der Radar nach Stöbern im Auktionshaus Varianten prüft, `/broker debug` für Protokolle.

## 0.27.1

- 0.27.1 (06.10.2026, KarloDerBaer): **Alt+Klick entfernt** (gehört jetzt Peon_Ledger): kein Auswählen im Reiter Verkaufen/Behalten und kein Hinzufügen zur Einkaufsliste per Alt+Klick mehr – Auswahl über das Broker-Fenster, Hinzufügen über Suchfeld und „Zur Einkaufsliste“ im Reiter Preise. `S.SelectLink(link)` bleibt als Funktion. Hinweistexte angepasst.

## 0.27.0

- 0.27.0 (06.10.2026, Konzept `Peon_Ledger_Gegenstand.md` G2):
  - **Absatz so lange wie die Preise:** Tageswerte `e.ab` bleiben `dataDays` (mind. 14) Tage, ältere als Wochensummen `e.abw` (26 Wochen). Der 14-Tage-Wert (`Stats14`) zählt weiter nur 14 Tage. Bestehende Daten bleiben.
  - **Schnittstellen für Ledger:** `mod:History(itemID)` → je Tag/Woche Min, Median, Menge, Scans, Absatz je Tag (ab 1 Std. Beobachtung), üblicher Bereich an diesem Tag (aus den Tagen bis dahin); `mod:MarketInfo(itemID)` → aktueller Stand (Min, Median, Menge, Bereich, Trend, Vorschlag, Händler, Warenart, Absatz je Std. mit Stufe); `mod:DayOf(t)` (Tage wie Broker).
  - **Reiter Preise:** Knopf „Mehr… (Ledger)“ neben „Zur Einkaufsliste“ (nur mit Ledger) öffnet den Gegenstand im Ledger-Reiter „Gegenstand“.

## 0.26.0

- 0.26.0 (03.10.2026, Befund KarloDerBaer „Abgefangene Kiste“: 55 Stück als Schnäppchen bei 323 Angeboten, Absatz 0,0/Std., Preis im freien Fall; mit KarloDerBaer abgestimmt):
  - **Wiederverkauf höchstens zur Untergrenze des üblichen Bereichs** (der Preis, den Verkaufen bei Dumping vorschlägt); ohne Bereich (unter 3 Tagen) höchstens Mitte zwischen Dumping-Grenze und Vergleichspreis (85 % bei DG 30 %). Gilt auch für den Gewinn bei Teilkauf (F33b). Kiste: Wiederverkauf 1s 59c statt 4s 50c → nur noch 7 Stück zu 1s lohnen (≈ 3s 50c) → unter dem Mindestgewinn, kein Schnäppchen.
  - **Menge höchstens Absatz je Std. × `dealHold`** (Standard 48 Std., Optionen „Markt: verkaufen innerhalb“). Erst ab gelbem ≈ (mind. 60 Min. beobachtet); Absatz 0/Std. = kein Markt-Schnäppchen. Rotes ≈ oder kein Absatz: Menge nicht begrenzt, Hinweis im Zeilen-Tooltip.
  - Zeilen-Tooltip im Radar: „Wiederverkauf: X je Stück (vor 5 % Anteil, höchstens Untergrenze des üblichen Bereichs)“, „Absatz ≈ x/Std. – höchstens n St. in 48 Std.“ bzw. „Absatz unbekannt oder unsicher – Menge nicht begrenzt“ (orange).
  - Händler-Schnäppchen unverändert.

## 0.25.2

- 0.25.2 (03.10.2026, Wunsch KarloDerBaer): Box „Broker Herstellen“ verdeckte die Leiste mit Berufs-Symbolen rechts am Berufsfenster. Die Box rückt jetzt hinter alles, was rechts an der Fensterkante klebt (sichtbare Rahmen am Fenster oder an UIParent, die an der rechten Kante beginnen, höchstens 140 breit, innerhalb der Fensterhöhe; `C.SideOffset`), sonst 4 Punkte Abstand. Im Spiel prüfen, ob die Leiste erkannt wird.

## 0.25.1

- 0.25.1 (03.10.2026, Wunsch KarloDerBaer): Zeile „Post“ auf der Startseite entfernt – ohne Besuch am Briefkasten liefert das Spiel keinen Inhalt, und beim Öffnen wird die Post ohnehin geleert. Startseite: Meine Auktionen, Verkaufen, Radar, Einkaufsliste, Scan.

## 0.25.0

- 0.25.0 (03.10.2026, Ledger Z3): Verkaufen zeigt „Unter deinen Kosten (X je Stück, Ledger)“ (orange), wenn der Erlös je Stück nach 5 % Anteil unter den Kosten des nächsten Stücks aus Ledger liegt (`ledger:Cost`).

## 0.24.0

- 0.24.0 (03.10.2026, Feedback-Liste und offene Punkte, mit KarloDerBaer abgestimmt), neue Dateien Start.lua und Craft.lua (**WoW komplett neu starten**):
  - **Reiter „Start“ – Was steht an?** (ganz links, am Auktionshaus öffnet das Fenster damit): je Zeile Meine Auktionen (unterboten / laufen / verkauft), Post (Gold in der Post aus Ledger `mod:MailInfo`, verkaufte Auktionen), Verkaufen (lohnende Gegenstände in den Taschen mit Wert, Händlerwert der übrigen), Radar (Schnäppchen in den letzten Daten, Händler/AH, bester Gewinn; höchstens alle 30 Sek. neu gerechnet), Einkaufsliste (Gegenstände unter dem Höchstpreis), Scan (letzter, nächster möglich; Klick startet den Scan, wenn möglich). Klick auf eine Zeile öffnet den Reiter. Beim Öffnen werden die eigenen Auktionen abgefragt.
  - **Berufe** (Craft.lua): beim Öffnen eines Berufs werden die erlernten Rezepte gelesen (`GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeSchematic`, nur Pflicht-Material) und je Charakter gemerkt. Box rechts am Berufsfenster (`ProfessionsFrame` oder `TradeSkillFrame`): gewähltes Rezept mit Material einzeln, Materialkosten (günstigstes Angebot), Wert (Zeile 1 des Tooltips), Gewinn, „Lohnt sich / Lohnt sich nicht“, darunter die 5 besten Rezepte. Tooltip mit Umschalt: „Herstellen: Material X · Gewinn Y“. Im Spiel prüfen: welches Berufsfenster Forever nutzt und ob das gewählte Rezept erkannt wird (sonst zeigt die Box nur die besten Rezepte).
  - **Meine Auktionen** (Feedback #4): beim Öffnen des Reiters neu laden und danach automatisch live prüfen.
  - **Radar „weg“, obwohl noch da** (Feedback #5, hoch): Im Radar-Protokoll waren es fast nur Gegenstände mit Zusatz („… des Wolfs“, „… der Heilung“) – die Suche mit dem Schlüssel aus `MakeItemKey(itemID)` lieferte vollständig 0 Angebote. Forever-Links haben den Zusatz nicht im Link-Feld 7, deshalb liegen alle Varianten unter der itemID. Jetzt: bleibt die Suche nach der zweiten Prüfung leer, sucht Broker den Gegenstand über die Browse-Suche (Grundname, wie das Suchfeld des Auktionshauses), nimmt den Schlüssel des Spiels mit dem günstigsten Angebot, merkt ihn (`itemKeys`) und prüft gleich nochmal; erst wenn auch das nichts findet, „weg“. Gilt auch für Einkaufsliste und Anzeige im Blizzard-Fenster. Protokoll `keyLog` (Standard-Schlüssel und gefundene Schlüssel) – zeigt beim nächsten Test, wie Forever Zusätze im Schlüssel ablegt.
  - **Schnellkauf mit einem Klick** (Feedback #6): Für das beste Händler-Schnäppchen (Massenware) holt Broker den Preis schon vorher (`StartCommoditiesPurchase`, alle 15 Sek. erneuert); der Knopf heißt dann „Händler: jetzt kaufen“ und bestätigt sofort (alles, was das Gold hergibt). Preis zu hoch: verworfen, Treffer wird neu geprüft. Antwortet das Spiel zweimal nicht, bleibt es für die Sitzung bei zwei Klicks. Einzelgegenstände: weiter ein Klick je Auktion (verlangt das Spiel).
  - **Graue Zeilen („weg“)** (Feedback #7): Klick zeigt den Gegenstand trotzdem im Blizzard-Fenster; Radar pausiert solange, die Zeile bleibt, solange sie gewählt ist.
  - **Händler-Knopf „Schnäppchen verkaufen“ entfernt** (Feedback #8): Merchant.lua gelöscht, `vendorFlip` wird gelöscht.
  - **Einkaufsliste**: neue Spalte „Vorrat“ (grau, wenn die Wunschmenge erreicht ist) und derselbe Umschalter „Vorrat aller Charaktere (Ledger)“ wie im Reiter Behalten.
  - **Verkaufen**: Hinweis mit der eigenen Verkaufsquote aus Ledger („Deine Verkäufe (30 T.): 3 von 4 verkauft (75 %)“, orange unter 50 %).
  - Bereiche für Peon_Feedback: Start, Verkaufen, Behalten, Meine Auktionen, Einkaufsliste, Radar, Preise, Berufe, Scan, Tooltip, Fenster, Optionen („Händler“ entfällt).
  - Erledigt und aus den offenen Punkten genommen (KarloDerBaer): „Abverkauf“ (= Absatz je Stunde seit 0.23) und „Vorschlag bei stark schwankenden Preisen“ (= Richtwert/üblicher Bereich seit 0.21).

## 0.23.1

- 0.23.1 (03.10.2026, mit KarloDerBaer abgestimmt):
  - **Aktueller Absatz je Stunde** aus den Vergleichen der letzten 6 Std. (einstellbar 1–24; einzelne Vergleiche in `e.ar`, 24 Std.). 14-Tage-Wert nur noch intern (Preise-Einzelheiten, `/broker absatz`, später Verbindung mit der Verkaufsquote).
  - **Sicherheit nach beobachteter Zeit** statt Zahl der Vergleiche, **Zeichen „≈“ immer da**: rot unter 60 Min., gelb ab 60, grün ab 180 Min. (einstellbar). Zahl weiß.
  - **Live-Vergleiche schon ab 1 Min. Abstand** (Neuladen beim Verkaufen, Radar liefern schnell Daten).
  - **Tooltip ohne Reichweite**: „Absatz (6 Std.): ≈ 30/Std. · 70 % verkauft“. Verkaufen mit Reichweite in Std./Tagen („reicht 15 Std.“ = bei diesem Absatz ist alles im Auktionshaus nach 15 Std. verkauft). Hinweise „Verkauft sich schnell“ (reicht unter 24 Std.) / „Markt ist voll“ (über 7 Tage) / „Läuft oft ab“ erst ab gelbem ≈. Preise: Spalte „Absatz/Std.“.
  - **Restzeit-Stufen 1–4** (Bedeutung aus `Enum.AuctionHouseTimeLeftBand`, wenn das Spiel sie mit 1–4 liefert, sonst fest 1–4).
  - Absatz-Daten aus 0.23.0 werden einmal verworfen (`salesVer` = 2), Preise bleiben.

## 0.23.0

- 0.23.0 (03.10.2026, **Absatzquote A1**, Konzept `Peon_Broker_Absatz.md`, mit KarloDerBaer abgestimmt), neue Datei Sales.lua:
  - **Vergleich zweier Beobachtungen** je Gegenstand (mind. 10 Min., höchstens 24 Std. Abstand): Live-Abfragen mit Auktionsnummer und Restzeit (`e.as`, 30 günstigste Angebote), Komplettscan ohne Nummer mit Restzeit-Stufe aus `GetReplicateItemTimeLeft` (`e.ss`, 15 günstigste). Gleicher Zeitraum wird nur einmal gezählt (`e.acov`; Live vor Scan).
  - **Regeln:** Menge kleiner = verkauft; weg und Ende vorbei = abgelaufen; weg vor dem Ende: Massenware – stand ein günstigeres Angebot in beiden Beobachtungen (auch teilweise gekauft) oder wurde dieselbe Menge billiger neu eingestellt = abgebrochen, sonst verkauft; Einzelgegenstand = verkauft abzüglich Schätzwert Abbrüche (Standard 10 %). Ende unklar = nicht gezählt. Nur bis zum höchsten in beiden sicher gesehenen Preis. Scan ohne Restzeit: nur bis 2 Std. Abstand.
  - **Werte (14 Tage, `e.ab` Tageswerte):** Absatz je Tag = verkauft ÷ beobachtete Zeit; Absatzquote = verkauft ÷ (verkauft + abgelaufen); Reichweite = Menge im Auktionshaus ÷ Absatz je Tag.
  - **Anzeige ab dem ersten Vergleich:** Sicherheit als Zeichen „≈“ (grau bis 4 Vergleiche, gelb ab 5, ohne Zeichen ab 15); Farbe der Zahl nach Reichweite (grün unter 1 Tag, rot über 7 Tage, sonst weiß). Tooltip mit Umschalt „Absatz (14 T.): ≈ 120/Tag · reicht 2 T. · 70 % verkauft“; Verkaufen: Zeile „Absatz“, Hinweise „Verkauft sich schnell“ / „Markt ist voll“ / „Läuft oft unverkauft ab – lieber Händler?“ (Quote unter 50 %, ab gelb); Preise: Spalte „Absatz/Tag“ und Zeile in den Einzelheiten.
  - **Optionen „Absatz (Markt)“:** Schwellen gelb/sicher, Anteil Abbrüche bei Einzelgegenständen, Reichweite grün/rot.
  - Chat: `/broker absatz <Name, Nummer oder Link>` – Zähler (verkauft, abgelaufen, abgebrochen, beobachtete Stunden, Vergleiche).
- Test 0.23.0 (KarloDerBaer, 03.10.2026): Tooltip zeigte „≈ 0,0/Tag · reicht > 99 T.“ rot und „Markt ist voll“, obwohl die Mengen bei Erdwurzel sichtbar sanken. Ursache: nur ein Vergleich (zwei Scans 15 Min. auseinander, dabei nichts verändert), Live-Vergleiche erst ab 10 Min. Abstand; der 14-Tage-Wert ist für „jetzt verkaufen“ nutzlos. Außerdem: **Restzeit-Stufen im Komplettscan sind in Forever 1–4** (gesehen: 1: 3.926, 2: 13.714, 3: 58.287, 4: 16.690 Angebote), nicht 0–3 wie in Retail.

## 0.22.1

- 0.22.1 (03.10.2026): `/broker pruefen scan` liest zusätzlich die Restzeit je Angebot (Beispiele „|| Restzeit …“) und zählt die Stufen über alle Angebote (`probe.scan.timeLeftBands`) – zeigt, ob Forever echte Werte liefert.

## 0.22.0

- 0.22.0 (03.10.2026, **Ledger L6 – Zusammenspiel**, abgestimmt mit KarloDerBaer):
  - **Reiter „Buch“ entfällt** (Buch in Peon_Ledger); sechs Reiter. Bereich „Buch“ für Peon_Feedback entfernt.
  - **Behalten:** neuer Umschalter unten links „Vorrat aller Charaktere (Ledger)“ (`keepAllChars`, Standard aus, nur sichtbar mit Ledger). An: Vorrat = Taschen + Bank dieses Charakters + Taschen, Bank und Post der Twinks + Accountbank (Ledger `mod:StockOthers`). Gilt auch für „zu verkaufen“ (Reiter Verkaufen, Tooltip „Behalten“). Neue Spalte „Twinks“.
  - **Tooltip (mit Umschalt):** Zeile „Deine Verkäufe (30 T.): 3 von 4 verkauft (75 %)“ aus Ledger (`mod:SellRate`), nur wenn es eigene Auktionen gab; Prozent ab 3 Stück.
  - **Schnittstelle für Ledger:** `mod:ItemValue(itemID, Stück)` = Wert wie Zeile 1 des Tooltips (günstigstes Angebot bzw. Händlerpreis).
  - **Prüfung für die Absatzquote** (nur lesend, läuft automatisch mit): Beim Lesen von Suchergebnissen (Verkaufen, Radar, Einkaufsliste) werden je Art (Massenware/Einzelgegenstand) die vorhandenen Felder gezählt (bis 500 Ergebnisse) und 5 Beispiele gespeichert: `PeonBrokerDB.fieldProbe`. Auswertung im Chat: `/broker pruefen auktionen` (wichtig: auctionID, timeLeftSeconds/timeLeft, owners).
  - **Komplettscan** (`/broker pruefen scan`, Ergebnis in `PeonBrokerDB.probe.scan`): `GetReplicateItemInfo` liefert wie in Retail 18 Werte je Angebot – **keine Auktionsnummer, Verkäufer leer (nil)**. Bestätigt mit warcraft.wiki.gg (03.10.2026): Besitzer ist seit Patch 9.0.2 immer nil außer bei eigenen Auktionen. **Restzeit gibt es aber über eine eigene Funktion** `C_AuctionHouse.GetReplicateItemTimeLeft(index)` (in Forever vorhanden) als Stufe 0–3 (`Enum.AuctionHouseTimeLeftBand`: bis 30 Min., 2 Std., 12 Std., 2 Tage). Laut Wiki haben auch die Einzelabfragen `auctionID` und `owners`; Massenware `timeLeftSeconds` (kann fehlen), Einzelgegenstände `timeLeft` (Stufe) und `timeLeftSeconds`.

## 0.21.3

- 0.21.3 (02.10.2026): Meine Auktionen erkennt die Qualität (Namensfarbe) auch aus Links im Forever-Format `|cnIQ3:` (gefunden mit der Ledger-Prüfung).

## 0.21.2

- 0.21.2 (02.10.2026, Feedback Nr. 3 von KarloDerBaer, Fehler/Verkaufen/hoch): Beim Einstellen kam manchmal „Der Gegenstand ist nicht mehr in den Taschen“, obwohl er da war. Ursache: Die Taschenliste überspringt gesperrte Plätze, und ein Platz ist gesperrt, solange der Gegenstand im Verkaufsfenster des Auktionshauses liegt (oder gerade eingestellt wird) – lag nur ein Stapel in den Taschen, fand Broker keinen. Jetzt eigene Suche beim Einstellen: freie Plätze zuerst, sonst auch gesperrte; über das Blizzard-Fenster wird ohnehin der Gegenstand eingestellt, der dort liegt. Test gegen das alte Verhalten geprüft.
- Test 0.21.x (KarloDerBaer, 02.10.2026): „bis jetzt schaut alles gut aus“.
- Post einsammeln und Buch kommen ins **neue Modul Peon_Ledger** (Konzept `Peon_Ledger_Konzept.md`, abgestimmt 02.10.2026); Broker nutzt es später nur lesend (Vorrat aller Charaktere, Verkaufsquote).

## 0.21.1

- 0.21.1 (02.10.2026):
  - Nach jedem Umschalten lädt Broker Blizzards Liste einmal neu wie der Knopf „Neu laden“ (Liste leeren mit `ItemList:Reset()`, dann `Refresh…SearchResults`), sobald das Spiel bereit ist und keine eigene Abfrage läuft. Danach Prüfung, ob die Ergebnisse zum Gegenstand gehören; sonst bis zu 3 Versuche (neu laden, eigene Suche, nochmal zeigen). Protokoll in `PeonBrokerDB.showLog` (40 Zeilen).
  - Umschalten wartet, bis keine eigene Broker-Abfrage mehr unterwegs ist (sonst überholen sich die Suchen).
  - Ergebnisse eines anderen Gegenstands (Link/Schlüssel passt nicht) werden nicht mehr gelesen (`rows.foreign`) und zählen wie „lädt noch“.
  - Radar: gewählter Treffer wird nicht mehr alle 5 Sek. neu abgefragt (Blizzard-Fenster lud dadurch ständig neu); geprüft wird beim Anklicken, nach einem Kauf und vor dem Kauf.

## 0.21.0

- 0.21.0 (02.10.2026): **Richtwert und üblicher Bereich** (Rechenmodell Kapitel 7, F35–F41, mit KarloDerBaer abgestimmt): aus den Tagesmedianen der letzten 14 Tage robuste Mitte und Schwankung (mind. 5 %), gleitender Mittelwert (Halbwertszeit 3 Tage, Ausreißer gekappt); Richtwert = mittlerer Wert aus jetzt, heute und gleitendem Mittel; zwei Messungen außerhalb des Bereichs = „Preis fällt/steigt“, dann folgt der Richtwert dem Markt. Ab 3 Tageswerten, sonst bisheriges Verfahren (`D.Band`, `D.Suggest(min, median, key, db, e, vor)`).
  - Vorschlag: Dumping nur noch unter dem üblichen Bereich und wenn der Markt nicht fällt; dann Untergrenze minus Unterbieten.
  - **Zeile 1 im Tooltip** und Wert im Reiter Verkaufen: günstigstes Angebot minus Unterbieten (statt Vorschlag), Farbe grün (gut), orange (Markt fällt), rot (Dumping); Händler weiter, wenn er mehr zahlt. Mit Umschalt neue Zeile „Üblich (n Tage) X – Y“ (+ fällt/steigt), Hinweise „Preis fällt“ / „Dumping … unter dem üblichen Bereich“.
  - Verkaufen: Hinweise „Üblich: X – Y (n Tage)“, „Preis fällt/steigt“, „Über dem üblichen Bereich – guter Zeitpunkt“. Preise-Reiter: Bereich und Richtwert.
  - Radar: Markt-Schnäppchen gegen den Richtwert; fällt der Markt, keine Markt-Schnäppchen. Vorauswahl beim Öffnen weiter gefasst (unter Händlerpreis oder unter Median).

## 0.20.2

- 0.20.2 (02.10.2026): Vermutung: Das Spiel schickt eine Suche nicht ab, wenn es für den Gegenstand schon (alte) Ergebnisse hat, oder nimmt gerade keine Abfrage an. Jetzt: Broker schaltet das Blizzard-Fenster erst um, wenn das Spiel bereit ist; kommt danach 0,8 Sek. kein Ergebnis für den Gegenstand, lädt Broker die Liste wie Blizzards Knopf neu (`RefreshItemSearchResults` / `RefreshCommoditySearchResults`, im Spiel vorhanden laut Prüfbefehl). Der gewählte Radar-Treffer wird ebenfalls so neu geladen. Meine Auktionen: leeres Ergebnis zählt nicht als „günstigster“ (dann gilt der Scan), Ergebnisse auch unter dem Schlüssel der Auktion gesucht; Protokoll der letzten 30 Ergebnisse in `PeonBrokerDB.aucLog`.
- Test 0.20.2 (KarloDerBaer, 02.10.2026): Umschalten bei Meine Auktionen weiter unzuverlässig (Titel richtig, Liste vom vorherigen Gegenstand), im Radar langsam und lädt immer wieder neu. `aucLog` zeigte: die Ergebnisse für den angeklickten Gegenstand kamen jeweils an – Blizzards Liste wurde trotzdem nicht aufgefrischt.

## 0.20.1

- 0.20.1 (02.10.2026): Vermutete Ursache: Bei Einzelgegenständen meldet das Spiel das Such-Ergebnis zuerst leer und noch unvollständig (lädt noch); Broker las „0 Angebote“ als „weg“. Jetzt: leeres und unvollständiges Ergebnis = weiter warten (auch auf `ITEM_SEARCH_RESULTS_ADDED` / `COMMODITY_SEARCH_RESULTS_ADDED`), in Radar, Verkaufen, Einkaufsliste und Meine Auktionen; kommt in die Datenbank nicht als „weg“. Zusätzlich glaubt der Radar „keine Angebote mehr“ erst nach einer zweiten Prüfung 3 Sek. später (`R.CONFIRM_AFTER`). Radar-Protokoll mit Anzahl Stufen und Schlüssel des Ereignisses; Zähler `radarStats.loading` und `emptyOnce`.
- Test (KarloDerBaer, 02.10.2026): Meine Auktionen – Klick auf „Bauplan: Arkaner Wiederverwerter“ schaltete Blizzard auf den richtigen Gegenstand, die Liste darunter zeigte aber noch die Angebote von „Pläne: Jadeschlangenklinge“; erst Blizzards „Neu laden“ half. Spalte „Günstigster“ zeigte „–“ und Status „günstigster“, obwohl es billigere Angebote gab.

## 0.20.0

- 0.20.0 (02.10.2026, Fehler und Wünsche von KarloDerBaer):
  - **Teil-Ergebnisse** (wichtigster Fehler): Das Auktionshaus liefert große Ergebnislisten in Teilen (`HasFullCommoditySearchResults` / `HasFullItemSearchResults`, wie Blizzards eigene Liste). Broker las bis 0.19 nur den ersten Teil und schrieb daraus Median und Menge in die Datenbank – der Median fiel, Markt-Schnäppchen verschwanden nach der nächsten Prüfung, und der Vorschlag beim Verkaufen wurde falsch. Jetzt: `rows.partial`; bei Teil-Ergebnissen werden nur Minimum und günstigste Stufen übernommen, Median und Menge bleiben; der Vorschlag nimmt dann den Median aus der Datenbank. Zähler `radarStats.partial`.
  - **Radar – weggefallene Treffer**: verschwinden nicht mehr stillschweigend, sondern bleiben 30 Sek. grau in der Liste mit „weg“ und Grund (keine Angebote mehr; günstige Angebote weg – günstigstes jetzt X; Wiederverkauf lohnt nicht mehr; unter Mindestgewinn / mit deinem Gold nicht; Preis beim Kauf gestiegen; gekauft; neue Daten). Grund im Tooltip und unter der Liste; Rechtsklick nimmt die graue Zeile weg. Protokoll der letzten 200 in `PeonBrokerDB.radarLog` (Zeit, Gegenstand, Grund, vorher/jetzt).
  - Radar: Ergebnisse, die das Spiel schon hatte (ohne Antwort auf die Abfrage), entfernen keinen Treffer mehr und kommen nicht in die Datenbank (können alt sein). Live geprüfte Treffer bleiben beim Neuladen des Reiters so lange wie `radarMaxAge` (vorher 5 Min.).
  - **Radar pausiert, solange ein Treffer gewählt ist** (jede fremde Abfrage verändert sonst die Anzeige im Blizzard-Fenster); gewählte Zeile nochmal anklicken = Auswahl aufheben, Radar läuft weiter. Statuszeile sagt es.
  - **Blizzard-Fenster**: `SelectBrowseResult` tut nichts, solange das Spiel die Daten zum Gegenstand nicht hat (`GetItemKeyInfo` = nil) – das Fenster zeigte dann weiter den alten Gegenstand. Broker wartet jetzt darauf (`ITEM_KEY_ITEM_INFO_RECEIVED`, sonst alle 0,3 Sek., bis 10×) und prüft, ob umgeschaltet wurde. Reiterwechsel schaltet Blizzard passend um (`W.SetAHMode`, neue Seiten-Funktion `enter`): Meine Auktionen → „Auktionen“, Radar/Einkaufsliste ohne Auswahl → „Kaufen“, Verkaufen → gewählter Gegenstand wieder ins Verkaufsfenster.
  - **Meine Auktionen**: Klick auf eine Auktion zeigt die aktuellen Angebote des Gegenstands im Blizzard-Fenster; deren Ergebnis aktualisiert gleich „Günstigster“ und Status.
  - **Verkaufen**: eingetragen wird immer das günstigste Angebot minus Unterbieten (auch bei Dumping), Untergrenze Mindestpreis (Händler). Der Vorschlag bleibt Richtwert: Hinweis „Unter dem Vorschlag X (n % weniger)“, rot bei starkem Abstand, mit Dumping-Grund. Rückfrage nur noch, wenn im Blizzard-Fenster von Hand noch tiefer eingetragen wird. Beschriftung „Preis je Stück“. Wird auf den Mindestpreis angehoben: Hinweis „Lieber beim Händler verkaufen“ und Erlös orange (Rechenmodell F23a).
- Test 0.20.0 (KarloDerBaer, 02.10.2026): Änderungen gefallen. Aber: Ausrüstung/Einzelgegenstände (z. B. 15-pfündiger Matschschnapper, mehrere „des Champions“/„der Ausdauer“) standen im Radar als „weg – keine Angebote mehr“, obwohl das Angebot im Blizzard-Fenster noch da war.

## 0.19.1

- 0.19.1 (02.10.2026): meldet Bereiche für Peon_Feedback (Verkaufen, Behalten, Meine Auktionen, Einkaufsliste, Radar, Preise, Buch, Scan, Tooltip, Händler, Fenster, Optionen); eine Zeile am Ende von Broker.lua, sonst unverändert.
- Vergleich mit Auctionator, TSM, Journalator, Auctioneer, aux (02.10.2026, im Chat): Broker hat die meisten Werkzeuge, es fehlt ein roter Faden. KarloDerBaer hat daraus die Punkte unter „Offene Punkte“ beschlossen; Tastenbelegungen, Preisgrenzen je Gegenstand und ein Verkaufs-Durchlauf werden vorerst nicht gebraucht.

## 0.19.0

- 0.19.0 (01.10.2026, Wünsche von KarloDerBaer, Fragen abgestimmt):
  - **Eine Spalte „Gewinn“**: höchster Gewinn mit meinem Gold (Gold minus Goldreserve; Kandidaten 1 Stück, jedes Stufenende, was das Gold hergibt). Sortierung, Mindestgewinn und Schnellkauf richten sich danach. Spalte „Menge“ zeigt „mit meinem Gold / ganzes Schnäppchen“ (z. B. 51/60). Spalten Gewinn je Stück / je Stapel entfallen. Tooltip der Zeile: „Mit meinem Gold: …“ und „Ganzes Schnäppchen: …“.
  - **Mindestgewinn** für Händler (H) und AH direkt im Reiter (Geldbeträge wie „50s“, „1g 20s“, „10c“; Zahl ohne Einheit = Silber) und in den Optionen; Händler jetzt bis 1000g. Neue **Goldreserve** (Optionen): gibt der Radar nie aus.
  - **Schnellkauf „Händler: Bestes kaufen“** (unten links): bestes Händler-Schnäppchen, alles was ich mir leisten kann. Massenware: Preis vom Spiel, dann Bestätigen; Einzelgegenstände: ein Klick je Auktion.
  - **Mehrere Einzelgegenstände kaufen**: Knöpfe auch bei Nicht-Massenware (1 Stück / ab Gewinn n Stück / Alle), ein Klick je Auktion, Knopf zählt mit („Weiter (2 übrig)“). Mittlerer Knopf = Menge ab Gewinn, wenn erst ab n Stück Gewinn; sonst bei Massenware bis ein Stapel.
  - **Gewählter Treffer** wird gleich im Auktionshaus gezeigt (Broker wartet, bis keine eigene Abfrage unterwegs ist, und nimmt die Antwort auf die Anzeige des Auktionshauses als Prüfung) und danach alle 5 Sek. neu abgefragt (aktualisiert auch das Blizzard-Fenster), auch ohne Radar-Scan, bis Auswahl/Reiter wechselt.
  - **Neue Treffer**: ganze Zeile pulsiert grün (Optionen: 0–30 Sek., Standard 5), grüner Punkt als eigenes Bild (das Zeichen ● fehlte in der Spielschrift → Viereck), Warnton wählbar (Schlachtzugswarnung, Bereitschaftscheck, Wecker, Flüstern; Kanal „Master“) mit Hörprobe. Vorher `SOUNDKIT.MAP_PING`.
  - **Händler-Schnäppchen** farbig: Zeile dezent gold, „H“ und Gewinn gold.
  - **Ausblenden**: keine Chatmeldung mehr; Knopf „Alle ausblenden“ (alle sichtbaren), in der Ausgeblendet-Liste „Alle wieder zeigen“.
  - **Broker-Scan beendet den Radar-Scan**; während des Scans keine Radar-Abfragen und kein Start („Broker-Scan läuft – Radar pausiert“).
  - **Händlerware am Händler verkaufen** (Merchant.lua): was der Radar als Händler-Schnäppchen kauft, wird je Charakter gemerkt; am Händler Knopf „Broker: Schnäppchen verkaufen (n · Wert)“ über dem Händlerfenster, verkauft ganze Stapel, nie mehr als gemerkt.
  - Tooltip: Händlerpreis in den Details **immer und je Stück** („Händler 5c je Stück“).
  - Unten drei Reihen: Schnellkauf | Mindestgewinn H/AH; Stand | Anzeige | Reihenfolge | Scan; gerade geprüft | Alle ausblenden | Ausgeblendet (n) | Nur Warnton.
- Nächster Schritt: KarloDerBaer testet 0.19.0 (**WoW komplett neu starten** – neue Dateien Merchant.lua und dot_new.tga, Kern 0.8.0). Danach Bauabschnitt „Buch“.

## 0.18.0

- 0.18.0 (30.09.2026, Wünsche von KarloDerBaer, Ausblenden abgestimmt):
  - **Kaufzeile direkt unter der Liste** für den gewählten Treffer: Name, Menge des Schnäppchens, Hinweis „Gewinn erst ab n Stück“ bzw. „Bei keiner Menge Gewinn“; Knöpfe „1 Stück“, „n Stück“ (bis ein Stapel, nur wenn weniger als alle) und „Alle (n)“ mit Kosten und Gewinn (grün/rot) darunter; grau mit „Nicht genug Gold“, wenn es nicht reicht. Einzelgegenstände nur „1 Stück“. Gewinn für jede Menge nach F33b (Rechenmodell).
  - Schnellkauf-Knöpfe unten entfernt. Scan-Einstellungen ganz unten: Stand | Anzeige | Reihenfolge | Scan; darunter gerade geprüfter Gegenstand | „Ausgeblendet (n)“ | Nur Warnton. Liste 14 Zeilen.
  - **Rechtsklick blendet aus** (alle Charaktere, je Markt, `PeonBrokerDB.radarHidden`): bleibt weg, solange Prüfungen (live oder voller Scan) es als Schnäppchen sehen; ist es einmal keins, wird es wieder frei und erscheint, wenn es wieder eins wird. Wird weiter abgefragt; kein Ton. Knopf „Ausgeblendet (n)“ öffnet eine Liste, Klick zeigt wieder.

## 0.17.0

- 0.17.0 (30.09.2026, mit KarloDerBaer abgestimmt):
  - **Markt-Schnäppchen neu (F33):** Wiederverkauf gegen das nächste Angebot nach dem Kauf (höchstens Median), Mindestmarge je Stück (`dealMargin`, 20 %), höchstens 20 % aller Angebote (`dealDepth`); beste Kaufmenge wird gesucht. 12 statt 5 Preisstufen gespeichert.
  - Spalten: Gewinn je Stück, Gewinn je Stapel (nur Massenware, Stapelgröße des Spiels, höchstens Schnäppchen-Menge), „Wiederverk.“ statt „Vergleich“, „Art“ als H/AH, Spalte „Daten“ in den Tooltip (dort auch Wiederverkauf/Händlerpreis und ganzes Schnäppchen). Sortierung und „bestes“ nach Gewinn je Stück.
  - Kaufen je Stück oder Stapel: unten vier Knöpfe (Händler 1×, Händler Stapel, AH 1×, AH Stapel) mit dem Preis genau dieses Kaufs; für die gewählte Zeile ebenso zwei Knöpfe. Nach einem Teilkauf bleibt der Treffer und wird neu geprüft.
  - Auswahl „Händler + AH / Nur Händler / Nur AH“ (`radarKind`) für Anzeige und Scan.
  - Gold: Schnäppchen, von denen ich mir kein Stück leisten kann, werden nicht angezeigt (Einstellung „auch Schnäppchen zeigen, die ich mir nicht leisten kann“ zeigt sie grau, nicht kaufbar); Stapel nur so groß, wie das Gold reicht.
  - Datenlade-Prüfung auch bei Schnellprüfung und Nachprüfen der Treffer.

## 0.16.0

- 0.16.0 (30.09.2026, Wünsche von KarloDerBaer):
  - Text „Wähle ein Schnäppchen“ und die Zähler-Zeile entfernt (Zähler weiter in `radarStats`).
  - Zweite Statuszeile: welcher Gegenstand gerade abgefragt wird („Prüfe: [Symbol] Name“).
  - Auswahl der Reihenfolge im Reiter (Dropdown, `radarOrder`): smart (bisher, beste 400 nach Wert × Menge), zufällig, Massenware zuerst, höchster Preis zuerst, niedrigster Preis zuerst (Preis = Median); Einkaufslisten und Nachprüfen der Treffer immer zuerst. Nach jeder Runde wird die Liste mit frischen Daten neu gebaut.
  - „Nur Warnton“ (Haken im Reiter, Standard an, `radarMute`): während des Radar-Scans Effekte, Musik, Umgebung, Dialog auf 0, „Gesamt“ bleibt (dort spielt der Warnton), Ton auch im Hintergrund und Ton allgemein an. Zurück beim Stoppen, Verlassen des Reiters, Schließen des Auktionshauses, Ausloggen/Reload; alte Werte solange in `PeonBrokerDB.radarMuteSaved` (beim nächsten Start zurückgesetzt, falls das Spiel abstürzt).
  - Vermutung zu den Abfragen ohne Antwort: Gegenstandsdaten nicht geladen. Radar prüft jetzt vorher `C_Item.IsItemDataCachedByID`, fordert fehlende Daten an und fragt den Gegenstand später ab; `timeoutLog` vermerkt „ungeladen“.
- Ergebnis 0.16.0 (30.09.2026): ~560 Abfragen, 549 Antworten, 11 ohne Antwort – **alle bei ungeladenen Gegenstandsdaten** (Vermutung bestätigt); sie kamen über Schnellprüfung/Nachprüfen, wo die Prüfung noch fehlte. ~83/Min.
- Befund KarloDerBaer: viele Markt-Treffer sind keine Schnäppchen (z. B. Abgefangene Kiste: 103 Stück zwischen 50s und 70s, Median durch 120 Stück zu 1g 26s hochgetrieben; Deviatschuppe 1172 Stück).

## 0.15.0

- 0.15.0 (30.09.2026): **Live-Ergebnisse im aktuellen Stand** (Rechenmodell Kapitel 6, mit KarloDerBaer abgestimmt): jede Live-Abfrage (Radar, Einkaufsliste, Verkaufen, Meine Auktionen) schreibt Min, Median, Menge, Preisstufen bzw. „weg“ in die Datenbank (`e.lt` = Zeit); Verlauf, Scan-Zahl und Trend bleiben reine Scan-Werte. Nächster Scan markiert auch nur live gesehene Gegenstände als weg, wenn sie fehlen. Tooltip/Preise nutzen „zuletzt gesehen“ (Scan oder live).
  - Radar beim Öffnen: alle Schnäppchen aus der Datenbank bis `radarMaxAge` (Standard 60 Min., 0 = unbegrenzt), jeder einmal live geprüft; weggefallene kommen nicht wieder. Spalte „Gesehen“ zeigt das Alter der Daten (z. B. „40 Min.“), nach der Prüfung Sekunden.
  - Radar-Tempo: prüft alle 0,1 s, ob die nächste Abfrage raus darf (Abstand weiter mind. 0,65 s), statt fest alle 0,65 s – weniger Leerlauf nach „Spiel nicht bereit“. Gegenstände, die zweimal in Folge ohne Antwort bleiben, werden für die Sitzung ausgelassen. `AUCTION_HOUSE_NEW_RESULTS_RECEIVED` für den abgefragten Gegenstand zählt als Antwort; vorhandene Ergebnisse werden unter beiden Warenarten gesucht. Zweite Statuszeile: gesendet, Antworten, ohne Antwort, Warten aufs Spiel (Sek.), ausgelassen, Ø. Fehlersuche: `radarStats.timeoutLog` mit den Ereignissen während einer Abfrage ohne Antwort.
- Ergebnis 0.15.0 (langer Lauf 22:01–22:12, 30.09.2026): ~940 Abfragen in ~11½ Min. (≈ 82/Min.), 871 vom Spiel gesendet = 871 Antworten (Ø 0,2 s), 71 ohne Antwort (7,5 %), Warten aufs Spiel nur 5 s. Bei allen Abfragen ohne Antwort kam **kein einziges** Ereignis (auch kein „gesendet“) – das Spiel schickt sie gar nicht ab. Es sind immer wieder dieselben Gegenstände.

## 0.14.5

- 0.14.5 (30.09.2026): Radar wartet nur noch 1 Sek. auf eine Antwort (statt 2). Ohne Antwort liest er die Ergebnisse, die das Spiel schon hat, und wertet sie aus (Zähler `cached`, in „Antworten“ enthalten); nur ohne vorhandene Ergebnisse zählt „ohne Antwort“. Vor einem Kauf (Einzelgegenstand) gilt weiter nur eine echte Antwort.
- Ergebnis 0.14.5 (langer Lauf, 30.09.2026): 343 Abfragen, 266 Antworten (Ø 0,2 s), 77 ohne Antwort (22 %), vorhandene Ergebnisse gab es dafür keine (0). 275 Takte „Spiel nicht bereit“ (je 0,65 s ≈ 3 Min. verloren). Dieselben Gegenstände bleiben immer wieder ohne Antwort (z. B. Flitzdistel, Großer gleißender Splitter, Himmelblauer Farbstoff).

## 0.14.4

- 0.14.4 (30.09.2026): Abfrage-Test um zwei Schritte über die Radar-Funktion selbst ergänzt (gleicher Gegenstand, Gegenstand der Einkaufsliste). Radar zählt „vom Spiel gesendet“ (Ereignis `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`) und protokolliert die ersten 30 Abfragen in `radarStats.log` (Gegenstand, Zeit, Spiel bereit, Anzeige des Auktionshauses, gesendet, Antwort).
- Ergebnis 0.14.4 (30.09.2026): Abfrage-Test alle sechs Wege ok (auch über die Radar-Funktion, auch Flitzdistel). Radar-Scan lief diesmal: 117 Abfragen, 98 vom Spiel gesendet, 98 Antworten (Ø 0,2 s), 19 ohne Antwort, 22× Spiel nicht bereit, nichts abgewiesen; etwa 60/Min. Warum der Lauf davor gar nichts abschickte, bleibt ungeklärt (beobachten). Im Protokoll: Abfragen ohne Antwort waren solche, nach denen das Spiel sofort wieder „bereit“ meldete – die Abfrage ging offenbar nicht wirklich raus; vermutlich hatte das Spiel für den Gegenstand schon Ergebnisse.

## 0.14.3

- 0.14.3 (30.09.2026): Abfrage-Test `/broker pruefen abfrage` – schickt nacheinander eine Abfrage 1. direkt aus dem Befehl, 2. aus dem Ergebnis-Ereignis, 3. aus `C_Timer`, 4. aus `OnUpdate` und meldet je Schritt „gesendet / Antwort“ (Chat und `PeonBrokerDB.queryTest`). Danach wird der Radar-Scan entsprechend umgebaut.
- Ergebnis Abfrage-Test (30.09.2026, Kupfer-/Massenware 8067): alle vier Wege funktionieren (Befehl 0,2 s, Ereignis 0,6 s, Timer 0,2 s, OnUpdate 0,2 s). Timer sind also **nicht** die Ursache. Auffällig: die erste Radar-Abfrage (Flitzdistel aus der Einkaufsliste, 1216 Angebote) wurde auch nicht abgeschickt. Ursache weiter offen.

## 0.14.2

- 0.14.2 (30.09.2026): Fehlersuche Radar-Tempo. Zweite Statuszeile beim Radar-Scan: Antworten, ohne Antwort, Spiel nicht bereit, abgewiesen, Ø Antwortzeit. Zähler auch in `PeonBrokerDB.radarStats` (mit den letzten 20 Gegenständen ohne Antwort). Ereignisse `AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED/QUEUED` werden gezählt; die Ereignis-Liste (Probe) nimmt zusätzlich diese beiden und `UI_ERROR_MESSAGE` (rote Fehlermeldungen wie „zu schnell“) auf.
- Befund 0.14.2 (KarloDerBaer, 30.09.2026): Radar-Scan „Antworten 0, ohne Antwort 11“. In der Ereignis-Liste kam während des Radar-Scans kein einziges `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT` – die Abfragen werden gar nicht abgeschickt (kein Fehler, nicht abgewiesen). Unterschied zu „Liste durchsuchen“ (funktioniert): dort kommt die erste Abfrage direkt aus dem Klick, die weiteren aus dem Ergebnis-Ereignis; der Radar schickt alle aus `C_Timer`. Vermutung: Forever nimmt Suchabfragen aus Timern nicht an.

## 0.14.1

- 0.14.1 (30.09.2026): Knöpfe „alle kaufen“ heißen jetzt **„Händler: Bestes kaufen“ / „AH: Bestes kaufen“** und zeigen nur den Preis des nächsten Kaufs (Massenware: alle Stück bis zur Grenze, Einzelgegenstand: eine Auktion); ohne Treffer „nichts zu kaufen“ (Hinweis von KarloDerBaer: je Klick wird nur ein Angebot gekauft).
- Abfragegrenze: laut Wowpedia und TSM-Blog 100 Suchen pro 60 Sek. (Retail seit 8.3); für Forever nicht bestätigt, Broker nutzt ~92/Min. und wartet zusätzlich auf die Freigabe des Spiels (`IsThrottledMessageSystemReady`). KarloDerBaer testet den Radar-Scan im Dauerlauf.
- KarloDerBaer im Spiel (0.14.0): Radar-Scan läuft nur mit ca. 24 Abfragen/Min. statt ~92. Vermutung: viele Abfragen bekommen keine passende Antwort, Broker wartet dann jeweils 2 Sek. (2,65 Sek. je Abfrage ≈ 23/Min.). Ursache noch offen.

## 0.14.0

- 0.14.0 (30.09.2026): Reiter „Einkaufsliste“ (Buy.lua) und neuer Reiter **„Radar“** (Radar.lua), Fenster 680 breit, sieben Reiter unten.
  - Einkaufsliste: wie bisher, ohne Umschalter.
  - Radar: Schnäppchen (Händler und Markt, Spalte „Gesehen“). Beim Öffnen Treffer aus einem höchstens 5 Min. alten Scan, die sofort einmal live geprüft werden (auch ohne Radar-Scan, je Treffer höchstens 2 Versuche); weg = gleich entfernt.
  - Knopf „Radar-Scan starten/stoppen“: laufend Einzelabfragen alle 0,65 Sek. (~92/Min.), nur solange der Reiter offen ist und das Auktionshaus offen; Reihenfolge ungeprüfte Treffer, jeder dritte Schritt der am längsten nicht geprüfte Treffer (spätestens alle 15 Sek.), Einkaufslisten, bis zu 400 Gegenstände mit den besten Chancen (Median × Menge, Händlerpreis oder gute Datenlage). Anzeige Abfragen je Minute.
  - Neue Treffer: Ton (abschaltbar, Einstellung „Ton bei neuen Radar-Treffern“) und grün mit ● für 60 Sek.
  - Knöpfe „Händler: alle kaufen“ und „AH: alle kaufen“ mit Anzahl und Gesamtkosten; je Klick ein Kauf, höchster Gewinn zuerst. Massenware: Kauf starten → Preis vom Spiel (teurer als die Grenze = Abbruch mit Meldung) → zweiter Klick „Bestätigen“. Einzelgegenstand: nur mit höchstens 10 Sek. alter Prüfung, sonst erst prüfen, dann `PlaceBid`. Zusätzlich Knopf „Kaufen“ für die gewählte Zeile.
  - Einstellung `buyMode` entfällt.

## 0.13.0

- 0.13.0 (30.09.2026, **Bauabschnitt 7**): Reiter „Einkaufen“ (Buy.lua), abgestimmt in `Peon_Broker_Einkaufen.md`, Formeln Rechenmodell Kapitel 5 (F28–F34).
  - Einkaufslisten je Charakter: Listen anlegen/umbenennen/löschen, Rabatt x % unter dem Median je Liste (Median = 7-Tage-Median, bei zu wenig Daten der aktuelle), Wunschmenge je Gegenstand (Kauf bis Wunschmenge minus Vorrat). Hinzufügen per Alt+Klick (im Reiter Einkaufen), Suchfeld (Namen aus den Scans) und Knopf „Zur Einkaufsliste“ im Reiter Preise. „Liste durchsuchen“ fragt nacheinander live ab.
  - Schnäppchen: Händler (Angebot < Händlerpreis, ab 10c Gewinn) und Markt/Dump (Angebot < üblicher Preis × (1 − DG), üblicher Preis = kleinerer Wert aus 7-Tage- und aktuellem Median, Gewinn beim Wiederverkauf nach 5 %, ab 50s, nur bei mind. 10 Scans in 7 Tagen). Nur bis 5 Min. nach dem Scan (einstellbar). Spalte „Daten“ (Scans / Tage). Grundlage: günstigste 5 Preisstufen je Gegenstand aus dem letzten Scan (neu im Scan: `lv`), live nachgeprüft beim Anklicken.
  - Kaufen: Anklicken öffnet den Gegenstand in Blizzards Kaufen-Ansicht (`SelectBrowseResult`); Knopf „Kaufen“ in Broker: Massenware über `StartCommoditiesPurchase` → Preis vom Spiel → Rückfrage (rot, wenn teurer als die Grenze) → `ConfirmCommoditiesPurchase`; Einzelgegenstand: Rückfrage → `PlaceBid` (günstigstes passendes Angebot). Käufe fürs Buch vermerkt.
  - Neue Einstellungen: Mindestgewinn Händler/Markt, Markt-Datenlage (Scans, Tage), Schnäppchen nur bis X Min. nach dem Scan.
- 0.13.0 von KarloDerBaer im Spiel bestätigt: Einkaufen funktioniert, drei Händler-Schnäppchen gekauft.

## 0.12.1

- 0.12.1 (30.09.2026): Broker-Knöpfe folgen Blizzards Knopf (gesperrt mit Hinweis „zu schnell – kurz warten“, frei sobald das Auktionshaus wieder annimmt; kein Warten auf eine Bestätigung, wenn nichts eingestellt wurde; Wartezeit 20 Sek.). Gesperrte Taschenplätze zählen nicht; der Rest desselben Gegenstands kommt erst nach dem Taschen-Update wieder ins Verkaufsfenster; verschwindet der Gegenstand, wird das Verkaufsfenster geleert.

## 0.12.0

- 0.12.0 (30.09.2026, **Bauabschnitt 6**): Reiter „Meine Auktionen“ (Auctions.lua), mit KarloDerBaer abgestimmt.
  - Liste der eigenen Auktionen (`QueryOwnedAuctions`, `OWNED_AUCTIONS_UPDATED`): Gegenstand mit Symbol, Menge, Mein Preis, Günstigster (anderer Verkäufer), Status, Restzeit. Status: günstigster (grün), gleichauf (gelb, nur live erkennbar), unterboten (orange), verkauft (grau). Sortierung: unterbotene zuerst, dann Restzeit.
  - Günstigster zuerst aus dem letzten Scan; „Live prüfen“ (nur auf Knopfdruck) fragt die Gegenstände nacheinander ab, eigene Angebote zählen nicht.
  - Abbrechen mit Anzeige der Kosten (`GetCancelCost`), „Nächste unterbotene (n)“ bricht je Klick eine ab, „Neu einstellen“ springt zu „Verkaufen“ und wählt den Gegenstand (kommt nach dem Abbruch per Post zurück, sonst Hinweis). Abbrüche fürs Buch vermerkt.
  - Ohne Auktionshaus: letzter Stand des Markts, Abbrechen gesperrt. Abgelaufene Auktionen (nur als Post) vorerst nicht angezeigt, kommen ins Buch.
- Test 0.10–0.12 (KarloDerBaer, 30.09.2026): funktioniert bisher gut. Zwei Fehler gefunden:
  - Nach zu schnellem Einstellen sperrt das Auktionshaus seinen Knopf („Ihr macht das zu schnell“); Brokers Knöpfe blieben danach grau, bis über das Auktionshaus selbst eingestellt wurde (Broker wartete auf eine Bestätigung, die nie kam).
  - Lua-Fehler in Blizzards `ItemSellFrame:UpdateNoneAvailableEntry` (`GetCurrentItemLevel`, ungültiger Platz): Broker legte nach dem Einstellen denselben, gerade verschwindenden Gegenstand wieder ins Verkaufsfenster.

## 0.11.0

- 0.11.0 (30.09.2026): **Reiter „Behalten“** (Keep.lua), mit KarloDerBaer abgestimmt.
  - Optionale Behalten-Menge je Gegenstand (leer = alle). Vorrat = Taschen + Bank (`C_Item.GetItemCount` mit Bank, geht auch bei geschlossener Bank; so macht es auch BagBrother). Zu verkaufen = Vorrat − Menge, höchstens die Menge in den Taschen.
  - Reiter „Behalten“ (hinter „Verkaufen“): Gegenstand mit Symbol, Menge (alle/Zahl), Vorrat (hervorgehoben: größere, hellweiße Schrift – WoW hat keinen Fettdruck), Taschen, Bank, Wert des Vorrats, Seit. Zeile anklicken → unten „Behalten: [Zahl] [Alle] [Wieder verkaufen]“; Rechtsklick = wieder verkaufen. Auch Gegenstände, die gerade nicht da sind.
  - Verkaufen: zeigt nur den Rest, trägt ihn im Auktionshaus als Menge ein; Hinweis „Du wolltest X behalten“, wenn dort mehr steht (Einstellen bleibt möglich). Rechtsklick/Knopf markiert weiter mit „alle“.
  - Tooltip: Zeile „Behalten: alle“ bzw. „Behalten: 20 (1 zu verkaufen)“ in Hellblau direkt unter Zeile 1, auch ohne Umschalt (nur aktueller Charakter).
  - Markierungen aus 0.10 werden zu „alle behalten“.

## 0.10.0

- 0.10.0 (30.09.2026, Wünsche von KarloDerBaer):
  - Gewählter Gegenstand wird ins Verkaufsfenster des Auktionshauses gelegt (`AuctionHouseFrame:SetPostItem`, Rückfall `SetDisplayMode` + `SellFrame:SetItem`), Brokers Werte dort eingetragen: Preis (`PriceInput:SetAmount`), Menge (`QuantityInput:SetQuantity`, Standard alles), Dauer (`Duration:SetDuration`). Nach 0,3 und 1 Sek. nochmal, weil das Auktionshaus nach seiner Suche selbst einen Preis setzt.
  - Eingestellt wird mit den Werten, die im Auktionshaus stehen (Broker klickt dessen Knopf „Auktion erstellen“); ohne Verkaufsfenster Rückfall auf Brokers eigene Werte mit Hinweis. Im Auktionshaus geänderte Dauer wird je Gegenstand gemerkt.
  - Linke Spalte schmal: Symbol, Name, Anzahl, Live-Stand, Vorschlag je Stück mit Stichwort, Erlös (für Menge und Dauer aus dem Auktionshaus), Hinweise; Knöpfe übereinander: „Nicht verkaufen“, „Auktion erstellen“, „Erstellen & weiter“. Eingabefelder entfernt.
  - Rechte Spalte breiter mit Spalte Trend (wie Zeile 1 im Tooltip). Rechtsklick auf eine Zeile = nicht verkaufen.
  - „Nicht verkaufen“ je Charakter (`PeonBrokerCharDB.keep`): verschwindet aus der Liste und aus „Erstellen & weiter“; per Alt+Klick auswählbar und mit „Wieder verkaufen“ freizugeben. Reiter zum Verwalten folgt.

## 0.9.3

- 0.9.3 (30.09.2026): Live-Abfrage über die normale Suche `SendSearchQuery` mit dem Schlüssel des Gegenstands (wie beim Anklicken im Auktionshaus); Nachsehen unter mehreren Schlüsseln (Gegenstand, Stufe 0, Schlüssel aus „neue Ergebnisse“), Protokoll inkl. Browse-Ergebnissen.
- 0.9.3 im Spiel bestätigt (30.09.2026): Live-Abfrage funktioniert für Massenware und Ausrüstung, Antwort nach etwa 0,3 Sek. über `COMMODITY_SEARCH_RESULTS_UPDATED` bzw. `ITEM_SEARCH_RESULTS_UPDATED`.

## 0.9.2

- 0.9.2 (30.09.2026): Live-Abfrage repariert. Debug-Log zeigte: Bei Massenware wurde die Abfrage gar nicht abgeschickt, bei Ausrüstung lagen die Ergebnisse unter einem anderen Schlüssel. Ursache: `SendSellSearchQuery` braucht einen Schlüssel mit Stufe/Zusatz/Haustierart = 0 (`MakeItemKey(itemID)`), Broker nahm den aus `GetItemKeyFromItem` (mit Gegenstandsstufe).
- 0.9.2 hat nicht geholfen: `MakeItemKey(itemID)` füllt in Forever die Stufe selbst aus (Log: 273085/25/0). Massenware wurde weiter nicht abgeschickt; bei Ausrüstung kam „neue Ergebnisse“, aber keine lesbaren Einträge.

## 0.9.1

- 0.9.1: genaueres Debug-Protokoll der Live-Abfrage (itemKey, Bereitschaft, jedes Ereignis, jedes Nachsehen).

## 0.9.0

- 0.9.0 (30.09.2026): **Neues Layout** nach KarloDerBaers Wunsch, angelehnt an das Blizzard-Fenster „Auktionen einstellen“.
  - Fenster im Stil des Auktionshauses (`ButtonFrameTemplate` mit Symbol und Titel, dunkle Innenfelder), Reiter unten wie im Auktionshaus; Rückfall auf den alten Rahmen, falls die Vorlagen fehlen.
  - Verkaufen zweispaltig: links Einstellen (großes Symbol, Name, Anzahl und Live-Stand, Kaufpreis pro Stück, Stichwort zum Vorschlag mit ausführlichem Text beim Überfahren, Menge mit „Max“, Dauer, Einzahlen, Gesamtpreis, Erlös, Hinweise, Knöpfe „Auktion erstellen“ und „Erstellen & weiter“), rechts die Taschen mit kleinem Symbol vor dem Namen.
  - Live-Angebote werden nur noch im Hintergrund für den Vorschlag abgefragt (Anzeige im Blizzard-Fenster); Knopf zum erneuten Abfragen neben dem Live-Stand.
  - Händlerpreis keine eigene Zeile mehr, nur als Hinweis „Lieber beim Händler verkaufen (zahlt …)“; Erlös orange, wenn der Händler mehr zahlt.
- **Ergebnis der Prüfung im Spiel (29.09.2026, Mirel Dorna, Build 70058):**
  - Markt: „Classic Beta PvE / Alliance“ – Realm-Name und Fraktion funktionieren als Markt-Schlüssel. Es gibt keine eigene Regelsatz-Funktion.
  - `UnitName("player")` liefert als zweiten Wert den **Nachnamen** („Mirel“, „Dorna“), nicht den Realm. Charaktere daher immer über Vor- und Nachname kennzeichnen.
  - Modernes Auktionshaus: `AuctionHouseFrame` / Blizzard_AuctionHouseUI, 85 Funktionen in `C_AuctionHouse` (u. a. ReplicateItems, SendSearchQuery, PostItem/PostCommodity, CancelAuction, StartCommoditiesPurchase, PlaceBid, CalculateItemDeposit/CalculateCommodityDeposit, GetOwnedAuctions, GetCancelCost). Keine alten Classic-Funktionen.
  - Komplettscan: 70.388 Angebote in 10 Sekunden. `GetReplicateItemInfo` liefert wie in Retail: Name, Symbol, Menge, Qualität, benutzbar, Stufe, Stufenart, Mindestgebot, Erhöhung, Sofortkaufpreis (für den ganzen Stapel), Gebot, Höchstbieter, …, Verkäufer (leer), …, itemID, hasAllInfo.
  - Gebühren-Test mit Nachtkriecher (Massenware): Einstellgebühr 1c / 4c / 12c für 12 / 24 / 48 Stunden. Händlerpreis kam leer zurück (Gegenstand noch nicht im Zwischenspeicher) – Händlerpreise später mit Nachladen abfragen. Die Formel der Einstellgebühr und der Verkaufsanteil sind noch offen; es gibt keine Funktion für den Anteil, er wird über die Rechnungs-Post ermittelt.
  - Verkaufs- und Posttexte (deDE) sind vorhanden, z. B. „Es wurde ein Käufer für Eure Auktion gefunden: %1$s“, „Auktion erfolgreich: %s“.
  - Ereignisse: alle modernen Auktionshaus-Ereignisse bekannt; `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` mit Typ 21 = Auktionshaus. Alte Ereignisse (`AUCTION_ITEM_LIST_UPDATE`, `NEW_AUCTION_UPDATE`, `AUCTION_OWNED_LIST_UPDATE`) gibt es nicht.
- Offen: Verkaufsanteil (5 % angenommen) und Formel der Einstellgebühr; Stapelpreis im Tooltip hängt davon ab, ob das Spiel die Stapelgröße liefert (`C_Item.GetItemLocation`/`GetStackCount`).
- Rechenmodell `Peon_Broker_Rechenmodell.md` abgestimmt (30.09.2026); Broker 0.6.0 setzt es um.
- Wollstoff-Test im Spiel (30.09.2026): Erlös (Gesamtpreis − 5 %), Händlerwert und Vorschlag stimmen; Min wich ab, weil das günstigste Angebot nach dem Scan gekauft wurde (normal). Einstellgebühr rundete falsch → 0.6.1.
- Rechnung Wollstoff (30.09.2026): Anteil 5 % bestätigt (1s 29c von 25s 85c), erhalten 25s 56c = Broker-Erlös 24s 56c + zurückgezahlte Einzahlung. Auffällig: Einzahlung laut Rechnung 1s 0c zurück, gezahlt 72c – bei weiteren Verkäufen beobachten; 2 und 24 Std. im Abgleich noch ungeprüft.
- Begleitprogramm beschlossen (30.09.2026): Konzept `Peon_Broker_Programm.md` als Entwurf, wird mit KarloDerBaer abgestimmt. Danach neue Reihenfolge der Bauabschnitte (Vorschlag im Konzept, Abschnitt 8).
- Test 0.9.0 (KarloDerBaer, 30.09.2026): Stil passt, Inhalt vorerst passend (wird später weiter angepasst). Live-Abfrage endet mit „keine Antwort“, obwohl das Spiel Ergebnis-Ereignisse meldet (COMMODITY_SEARCH_RESULTS_UPDATED 24×).

## 0.8.1

- 0.8.1 (30.09.2026, nach KarloDerBaers Test): Einzelgegenstände zeigten live den Preis geteilt durch die Anzahl gleicher Angebote (20s bei 6 Angeboten → 3s 33c) – `buyoutAmount` ist schon der Preis je Stück. Live-Abfrage blieb bei „wird geladen“: jetzt zusätzlich Nachsehen nach 0,5/1,5/3 Sek. und Zeitgrenze 6 Sek. („keine Antwort“, Rückfall auf den Scan); Ereignis des Spiels gilt auch, wenn die Warenart falsch vermutet war; Protokoll im Debug-Log (`/broker debug`). „(kommt zurück)“ hinter der Einstellgebühr entfernt.

## 0.8.0

- 0.8.0 (30.09.2026, **Bauabschnitt 5**): Reiter „Verkaufen“ (Sell.lua), Rechenmodell Kapitel 4 (F21–F27).
  - Links die Taschen: verkaufbare Gegenstände (keine gebundenen), gleiche zusammengefasst, Wert wie Zeile 1 im Tooltip, sortiert nach Erlös; „nur lohnende“ (Standard an).
  - Rechts: Live-Angebote (Verkaufs-Suche des Auktionshauses, eigene markiert, Klick übernimmt den Preis), Vorschlag je Stück in Gold/Silber/Kupfer mit Grund, Menge (Standard alles, „Alle“), Laufzeit (Auswahlliste; Massenware ab 20 Angeboten 2 Std.), Gesamtpreis, Einstellgebühr vom Spiel, Erlös nach 5 %, Händlerwert, Hinweise.
  - „Einstellen“ und „Einstellen & weiter“ (nächster lohnender Gegenstand); wartet auf die Bestätigung des Spiels (10 Sek.), Rückfragen bei Preis weit unter dem Vorschlag und wenn das Spiel nachfragt. Nie im Kampf.
  - Alt+Klick auf einen Gegenstand in den Taschen wählt ihn im Reiter aus (über `HandleModifiedItemClick`).
  - Am Auktionshaus öffnet das Fenster mit „Verkaufen“.
- Test 0.8.0 (KarloDerBaer, 30.09.2026): Bedienung und Einstellen funktionieren. Layout gefällt noch nicht: soll übersichtlicher werden und sich am Blizzard-Fenster „Auktionen einstellen“ orientieren.

## 0.7.0

- 0.7.0 (30.09.2026, **Bauabschnitt 4**): Broker-Fenster mit Reiter „Preise“.
  - Fenster (Window.lua): Reiter Verkaufen, Meine Auktionen, Einkaufen, Preise, Buch; bisher nur „Preise“ offen, die anderen gesperrt („folgt“). Bei offenem Auktionshaus rechts angedockt, schließt mit ihm; sonst frei verschiebbar (Position gemerkt). Escape schließt. Fußzeile: Markt und letzter Scan.
  - Öffnen: `/broker`, Minimap-Button (links Fenster, rechts Einstellungen), Knopf „Broker“ links unter dem Auktionshausfenster, Knopf auf der Optionsseite; optional automatisch mit dem Auktionshaus.
  - Reiter „Preise“ (Prices.lua): Suche nach Namensteil (Groß/klein und Umlaute egal), Liste aller Gegenstände des Markts (Name in Qualitätsfarbe, Min, Median, Angebote, gesehen; sortierbar), Maus über Zeile zeigt den Gegenstand im Tooltip mit Broker-Zeilen. Klick zeigt Einzelheiten (AH Min/Median, Angebote, 7 Tage, Vorschlag und Händler je Stück, Warenart, Dumping-Hinweis) und den Verlauf (Tage, ältere als Wochen).
  - Scan merkt Name und Qualität (`nm`, `ql`) je Gegenstand.
- 0.7.0 im Spiel getestet (30.09.2026): Fenster passt, Namen werden gespeichert; Abgleich der Einstellgebühr mit 0.6.2-Formel: 24 gleich, 0 abweichend (Formel bestätigt).
- KarloDerBaer möchte zuerst im Spiel weitermachen (Broker muss ohne Programm funktionieren); das Programm-Konzept bleibt als Entwurf liegen.

## 0.6.2

- 0.6.2 (30.09.2026): **Einstellgebühr wie im Spiel**: Grundgebühr 5 % vom Händlerwert des Stapels, abgerundet, dann × 1/4/12 für 2/8/24 Std. Gefunden über den automatischen Abgleich (`depositCheck`: vorher 32 gleich, 67 abweichend; die neue Formel trifft alle 17 gespeicherten Beispiele). Der Abgleich beginnt bei neuer Formel von vorn.

## 0.6.1

- 0.6.1 (30.09.2026): Einstellgebühr wird jetzt wie im Spiel **abgerundet** (von KarloDerBaer gefunden, Wollstoff: Broker 73c, Spiel 72c). Rechnung in ganzen Prozent, Test mit dem Wollstoff-Beispiel ergänzt.

## 0.6.0

- 0.6.0 (30.09.2026): **Rechenmodell umgesetzt** (`Peon_Broker_Rechenmodell.md`, Formeln F1–F20, Tooltip nach Kapitel 3). Neues Speicherformat (`dataVersion` 2): alte Preisdaten beim ersten Start einmalig gelöscht, Hinweis im Chat.
  - Je Gegenstand: AHmin, AHmedian (Median über alle Stück), AHmenge, AHanz, Zeit, Vorwerte; Tageswerte als Summen und Anzahl aller Scans des Tages (Tag = Mitternacht nach PC-Uhr); 7-Tage-Werte gleitend inkl. heute, Trend gegenüber Vortag.
  - Preisvorschlag: AHmin minus Unterbieten (Massenware/Einzelgegenstand getrennt); bei Dumping (AHmin mehr als DG unter dem Median) Mitte zwischen Grenze und Median. Erlös = VP × Stapel × 0,95 (Einstellgebühr wird nicht abgezogen, sie kommt bei Verkauf zurück). Einstellgebühr = Händlerwert × 5/20/60 % (Laufzeit einstellbar). Empfehlung AH nur bei Erlös > Händlerwert.
  - Tooltip: Z1 bester Wert (Stapel); mit Umschalt Angebote (Anzahl), AH Min/Median je Stück, 7 Tage (n) ab 2 Tagen, Vorschlag je Stück, Einstellgebühr, Händler, Hinweise (Dumping, wenig Angebote < 3, keine Angebote, alte Daten).
  - Entfallen: Abverkauf, gemerkte Einstellgebühren (`deposits`), „~“, „Ø“.
  - Bei geöffnetem Auktionshaus: Warenart der Taschen-Gegenstände vom Spiel gemerkt; Einstellgebühr des Spiels mit der Formel verglichen (`depositCheck`, bis zu 20 Abweichungen als Beispiel).

## 0.5.1

- 0.5.1: Fehler behoben (von KarloDerBaer gefunden, Schwerer Leinenverband): Lag der Markt auf Händlerniveau (20c), wurde der Vorschlag auf den Mindestpreis 26c angehoben; durch Aufrunden kamen 21c Erlös heraus und Zeile 1 zeigte „AH“. Jetzt gilt: Muss der Vorschlag auf den Mindestpreis angehoben werden, zeigt Zeile 1 immer den Händlerpreis.

## 0.5.0

- 0.5.0 (Wünsche von KarloDerBaer nach dem Test):
  - Zeile 1 zeigt nur den besseren Wert: „AH: …“ (Erlös, grün, mit Trend) oder „Händler: …“. Ohne Umschalt nur diese Zeile mit dezentem Hinweis „(Umschalt)“; mit Umschalt die Details. Umschalt während der Tooltip offen ist baut ihn neu auf (`MODIFIER_STATE_CHANGED` → `GameTooltip:RefreshData`).
  - Werte immer für den ganzen Stapel unter der Maus (ohne bekannte Stapelgröße 1 Stück); der Zusatz „Stapel x…“ entfällt.
  - Händlerpreis in den Details nur, wenn Zeile 1 den AH-Wert zeigt; der Hinweis „Lieber beim Händler verkaufen“ entfällt (steckt in Zeile 1).
  - Neue Trend-Symbole (abgestimmt): stark gestiegen dunkelgrün, gestiegen hellgrün, gleich dezent blauer Balken (statt gelbem Punkt, sah wie eine Münze aus), gefallen orange, stark gefallen rot.
  - Fehler behoben: Händlerpreis kam leer zurück, weil es im Forever-Client kein globales `GetItemInfo` mehr gibt – jetzt `ns.GetItemInfo`/`ns.VendorPrice` über `C_Item.GetItemInfo` (auch im Prüfbefehl). Dadurch war der Erlös grün, obwohl der Händler mehr zahlte.

## 0.4.1

- 0.4.1: Fehler behoben – ESC (Spielmenü) meldete ADDON_ACTION_FORBIDDEN „SpellStopCasting()“, weil Options.lua `StaticPopupDialogs = StaticPopupDialogs or {}` neu zugewiesen hatte. Jetzt wird nur ein Eintrag hinzugefügt; der Test prüft das.

## 0.4.0

- 0.4.0: Tooltip neu nach KarloDerBaers Aufbau (Erlös, Angebote mit Abverkauf je Stunde, AH Min/Ø, 7 Tage Min/Ø, Hinweise, Händlerpreis), Münzsymbole, Trend in fünf Stufen mit eigenen Symbolen, Umschalt zeigt alle Werte für den Stapel.
  - Je Gegenstand zusätzlich: Werte des vorherigen Scans (`pm`, `pa`, `pq`, `pt`), günstigste 20 Preisstufen (`l`), geschätzter Abverkauf (`s`, `si`); Gegenstände, die beim neuen Scan fehlen, bekommen 0 Angebote (`gone`) und behalten ihre letzten Preise.
  - Preisvorschlag (`Data.Suggest`): günstigstes Angebot minus Unterbieten; bei mehr als `dumpPct` unter dem 7-Tage-Durchschnitt der Durchschnitt minus Unterbieten; nie unter dem Mindestpreis (Erlös = Händlerpreis). Wird im Reiter „Verkaufen“ wiederverwendet.
  - Einstellgebühren werden beim Öffnen des Auktionshauses und bei Taschenänderungen (während es offen ist) für alle verkaufbaren Taschen-Gegenstände abgefragt und gemerkt.

## 0.3.0

- 0.3.0 (Bauabschnitt 3): Komplettscan, Preisdatenbank je Markt, Preise im Tooltip.
  - Scan: Knopf „Broker-Scan“ unter dem Auktionshausfenster (mit Status: Wartezeit, letzter Scan, Fortschritt) und `/broker scan`. 15-Minuten-Sperre wird selbst mitgezählt. Auswertung in Portionen (1500 Angebote bzw. 300 Gegenstände je Bild); Schließen des Auktionshauses während des Lesens bricht ab.
  - Je Gegenstand: niedrigster Stückpreis, typischer Preis (Durchschnitt der günstigsten 25 % der Menge), Menge, Anzahl Angebote, Zeitpunkt. Ausrüstung mit Zusatz („… des Bären“) getrennt über `itemID:suffixID`. Reine Gebote (ohne Sofortkauf) zählen nicht.
  - Verlauf: ein Tageswert je Tag (späterer Scan gewinnt), nach `dataDays` zu Wochenwerten verdichtet (26 Wochen), dann gelöscht. Verdichten einmal am Tag.
  - Tooltip (nur aktueller Markt): AH-Preis mit Alter, Ø 7 Tage, Händlerpreis, mit Umschalt Stapelpreis, Hinweis „Lieber beim Händler verkaufen“ (AH-Preis nach 5 % Anteil ≤ Händlerpreis). Ohne Scan im Markt ein Hinweis bei verkaufbaren Gegenständen.
  - Minimap-Tooltip zeigt letzten Scan und Anzahl Gegenstände. Der Chat-Hinweis beim Öffnen des Auktionshauses ist entfallen.

## 0.2.0

- 0.2.0 (Bauabschnitt 2): Minimap-Button (Klick öffnet vorerst die Einstellungen, Tooltip mit Markt und letzter Prüfung), Ereignis-Liste auf der Optionsseite als erster Einsatz der neuen Kern-Liste.

## 0.1.0

- Funktionen 0.1.0 (Bauabschnitt 1 – Prüfbefehl, nur lesend): Markt-Schlüssel (Realm-Name / Fraktion), Client-Version, Liste aller `C_AuctionHouse`-Funktionen, alte Classic-Funktionen, Auktionshaus-Fenster, Enums, Texte für Verkaufs-/Postmeldungen, Mitzählen der Auktionshaus- und Post-Ereignisse. Bei geöffnetem Auktionshaus zusätzlich Gebühren-Test (erster verkaufbarer Gegenstand, Einstellgebühr für alle drei Laufzeiten) und Komplettscan-Test (Anzahl, Dauer, drei Beispiel-Einträge).
