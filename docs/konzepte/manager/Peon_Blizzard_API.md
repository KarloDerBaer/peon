# Blizzard-API für WoW Forever

Was wir über die Schnittstelle wissen. Blizzard hat diese Bereiche weder dokumentiert noch angekündigt, alles hier ist durch eigene Abrufe ermittelt (05.11.2026, KarloDerBaer, echte Abfragen für EU und US). Der Baustein dazu ist `manager\src\core\blizzard.js`.

## Zugang und Bereiche

- Anmeldung: `https://oauth.battle.net/token` mit Client-Credentials. Abfragen: `https://{eu|us}.api.blizzard.com`, Token im Header `Authorization: Bearer …`, Parameter `namespace=…&locale=de_DE`.
- `dynamic-forever-{eu|us}`: Live-Daten für Forever, mit Auktionen.
- `static-forever-{eu|us}` (und `static-1.60.1_70399-forever-{eu|us}`): Spieldaten mit deutschen Namen, zum Beispiel `/data/wow/item/2589` (Leinenstoff).
- `profile-forever-{region}`: nur mit einem erfundenen Charakter probiert (404), sagt also nichts aus.
- **Forever hat keine Realms:** `connected-realm/index` und `realm/index` liefern unter `dynamic-forever` 404. Der Prüfabruf von Manager 0.10.0 fragte genau diese Wege ab und meldete deshalb fälschlich keine Daten.
- Zum Vergleich: Classic Era (`dynamic-classic1x`) listet die Auktionshäuser, liefert die Angebote aber weiterhin mit 404.

## Aufbau unter `dynamic-forever`

- `/data/wow/region/index`: eine Region, EU = 93 („CAMWOW Europa“), US = 91 („CAMWOW Nordamerika“).
- `/data/wow/ruleset/index`: 4 Regelsätze, 1 PvP, 2 Normal, 3 Rollenspiel, 15 Rollenspiel (PvP).
- `/data/wow/ruleset/{rs}/auctions/index`: 15 Auktionshäuser, bei allen Regelsätzen dieselbe Liste (110 bis 121, 123 bis 125, die 122 gibt es nicht).
- **Einzelgegenstände:** `/data/wow/ruleset/{rs}/auctions/{haus}` mit `auctions[]` (`id`, `item`, `buyout`, `quantity` immer 1, `time_left`, teilweise `bid`). Hat ein Haus keine, kommt nur eine Beschreibung (`id`, `name`, Links).
- **Massenware:** `/data/wow/ruleset/{rs}/auctions/{haus}/commodities` mit `auctions[]` (`unit_price`, `quantity` usw.).
- **Der Regelsatz im Abrufweg spielt keine Rolle.** Haus 113 lieferte unter allen 4 Regelsätzen dieselben Angebote. Die Hausnummer bestimmt den Markt.
- Nicht vorhanden (404): `/data/wow/auctions/commodities`, `/data/wow/ruleset/{rs}/auctions` ohne Haus, `/data/wow/region/{id}/auctions…`, `connected-realm/{rs}/…`.

## Häuser

Das neutrale Haus heißt laut API „Auktionshaus der Schwarzmeerräuber“ und führt echte Angebote, aber wenige (Haus 117 am 05.11.2026: 356 Einzelgegenstände und 752 Massenware, Haus 111: über 59.000). Wo es im Spiel steht, ist nicht geprüft. Andere Seiten nennen die Goblinstädte wie früher, offiziell bestätigt ist das nicht. Ein Schwarzmarkt-Auktionshaus erscheint in der Liste der Häuser nicht.

Vermutung: 5 Märkte mit je einem Allianz-, Horde- und Neutral-Haus. Angebote gesamt am 05.11.2026, Stand 07:47 UTC. Die Zuordnung zum Regelsatz ist **nicht bestätigt**, die API nennt sie nicht.

| Gruppe | Allianz / Horde / Neutral | EU | US | Vermutung |
|---|---|---|---|---|
| 1 | 110 / 113 / 116 | ca. 82.000 | ca. 129.000 | großer Markt (Normal oder PvP) |
| 2 | 111 / 114 / 117 | ca. 72.000 | ca. 132.000 | großer Markt (Normal oder PvP) |
| 3 | 112 / 115 / 118 | leer | leer | unbenutzt |
| 4 | 119 / 120 / 121 | ca. 6.300 | ca. 25.000 | kleiner Markt (Rollenspiel oder RP-PvP) |
| 5 | 123 / 124 / 125 | ca. 6.000 | ca. 26.000 | kleiner Markt (Rollenspiel oder RP-PvP) |

## Geklärt am 05.11.2026 (Beobachter, Stand 08:47 UTC, EU)

- **Haus eines Markts:** Ein Komplettscan von „… PvE / Alliance“ (08:50 UTC, 42.330 Angebote) stimmt mit **Haus 111** zu 98,7 % überein (Gegenstand, Menge, Preis), mit Restzeit zu 97,9 %. Das nächstbeste Haus kommt auf 41 %. Der Vergleich trennt also klar und eignet sich zur automatischen Erkennung. **Bestätigt:** Ein Testangebot (Leinenstoff, 12345 Kupfer) erschien im nächsten Stand in Haus 111 und in keinem anderen. Gruppe 2 ist damit vermutlich der Regelsatz Normal (PvE). Für die übrigen Gruppen fehlt noch ein Beleg.
- **Takt:** stündlich. Gesehen wurden 07:47, 08:47 und 09:47 UTC. Blizzard antwortet auf `If-Modified-Since` mit 304, eine Rückfrage kostet also fast nichts.
- **Angebotsnummern bleiben gleich.** Vom Stand 08:47 zu 09:47 UTC blieben 170.567 von 191.519 Angeboten unter ihrer Nummer, ohne anderen Gegenstand oder Preis. Eine Nummer kommt nie in zwei Häusern vor.
- **Teilkäufe sind sichtbar:** Bei Massenware sank die `quantity` von 202 Angeboten (2.383 Stück), sie stieg nie. Das erkennt ein Vergleich ohne Nummern nicht.
- **Was verschwindet:** Alle `SHORT` der Vorstunde waren weg, sie können also einfach abgelaufen sein. Von `MEDIUM` kann ein Teil ebenfalls abgelaufen sein. Weg trotz `LONG` oder `VERY_LONG` heißt gekauft oder abgebrochen, das unterscheidet die API nicht. Gebote und Sofortpreis blieben unverändert, Gebote also im Vergleich noch ungesehen.
- **Preise:** Bei Massenware ist `unit_price` × `quantity` gleich dem `buyout` im Scan. Bei Einzelgegenständen ist `quantity` immer 1. Reine Gebote haben `bid` und kein `buyout`, das ist selten (30 Gebote in Haus 111, wie im Scan).
- **Felder in `item`:** `id`, dazu teilweise `bonus_lists` (immer eine Nummer), `modifiers` (bisher nur Art 28) und `context`.
- **Zusätze:** Die Nummern in `bonus_lists` sind dieselben wie im Scan (824 von 843 Paaren aus Gegenstand und Bonus gemeinsam, der Rest sind einzelne Angebote). Im Scan steht jede der 47 Nummern für genau einen Zusatz, zum Beispiel 12726 „des Wolfs“. Mehrere Nummern können denselben Zusatz haben (12735, 12919 und 12920 „der Heilung“). Eine Tabelle Nummer zu Zusatz kann aus Scans gelernt werden, die API nennt den Namen nicht.
- **`time_left`:** `SHORT`, `MEDIUM`, `LONG`, `VERY_LONG`, passt zu den Stufen 1 bis 4 im Scan.
- **Angebotsnummern:** Zahlen, innerhalb eines Hauses ohne Doppelte. Ob sie über mehrere Stände gleich bleiben, ist noch offen.
- **Größe:** Ein Stand aller EU-Häuser sind 30 Abfragen, 191.519 bis 216.794 Angebote und 15 bis 17 MB, gepackt 1,4 bis 1,6 MB. Das Haus 111 allein etwa 3,5 bis 3,9 MB, gepackt etwa 0,35 MB, also rund 8 MB am Tag. `Last-Modified` unterscheidet sich zwischen den Häusern eines Stands um bis zu eine Sekunde.
- **Regionen:** US antwortet mit 4 Regelsätzen, Taiwan mit 2. Angebote sind für Taiwan noch nicht geprüft.
- **Spieldaten:** `/data/wow/item/{id}` unter `static-forever` liefert Name, Qualität, Stufe, `sell_price` (Händlerpreis), `purchase_price`, `is_stackable`, Klasse und Unterklasse. `/data/wow/media/item/{id}` liefert das Symbol als Adresse unter `render.worldofwarcraft.com`. **Viele Gegenstände mit Zusatz fehlen dort** (404, zum Beispiel 14097), `static-classic1x-{region}` kennt sie aber.
- **Volle Namen:** Grundname plus Zusatz aus der Bonus-Nummer ergibt in allen 905 prüfbaren Paaren genau den Namen aus den Scans.
- **Zugang anlegen:** Laut Blizzard braucht das Konto einen Battle.net Authenticator, der Client-Name ist über alle Entwickler einmalig. `develop.battle.net` leitet auf `community.developer.battle.net` um.

## Gegenstandsdaten (Prüfabruf 05.11.2026, EU, Manager 0.12.0 `manager\src\core\item-info.js`)

- **`preview_item` in `/data/wow/item/{id}` liefert fertige deutsche Tooltip-Zeilen:** `level`, `binding`, `unique_equipped`, `inventory_type`, `item_subclass`, `weapon` (Schaden, Tempo, Schaden je Sekunde), `armor`, `stats` (mit `display_string` und Farbe), `spells` (Beschreibung des Effekts), `requirements` (Stufe, Klassen, Beruf), `durability`, `charges`, `container_slots`, `set` (Name und Boni), `recipe` (Material), `description`, `crafting_reagent`, `sell_price`.
- **`static-forever` kennt viele Gegenstände nicht**, auch ohne Zusatz (404 zum Beispiel bei 14097, 16802, 9449, 11996). `static-classic1x` kennt die meisten und hat denselben Aufbau, die Werte stammen aber aus Classic (zum Beispiel `static-1.15.9_68185-classic1x-eu`) und können in Forever abweichen. Bei ersten Einlesungen kam etwa die Hälfte aus den Classic-Daten. Einige fehlen in beiden (7779).
- **Zusätze:** Die Abfrage kennt nur die Gegenstandsnummer. Die Werte eines Zusatzes wie „des Wolfs“ fehlen deshalb, die Antwort zeigt nur die Grundwerte. Geprüft am 06.11.2026 mit `bonus`, `bonus_lists`, `bonusList`, `bonusLists`, `bonus_list`, `bl` und `context`: die Antwort bleibt Zeichen für Zeichen gleich. `item-bonus`, `item-suffix` und ähnliche Wege liefern 404. Peon_Bridge liest die Werte deshalb ab 0.6.0 im Spiel aus dem Tooltip. Im Spiel bestätigt (06.11.2026): `C_TooltipInfo.GetHyperlink("item:3192::::::::20:1488:::1:12723")` liefert nach `C_Item.RequestLoadItemDataByID` den vollen Namen und die Werte des Zusatzes. Davor kommt nur eine Zeile „Frage Gegenstandsinformationen ab“. Ein Link aus Gegenstand und `bonus_lists` der API reicht also, ein echter Gegenstand ist nicht nötig. Ob die Werte von der Stufe im Link abhängen (hier 20), ist noch offen.

## Offene Fragen

1. Welche Regelsätze gehören zu den anderen Gruppen? Klärt sich mit Scans von Freunden auf anderen Regelsätzen.
2. Bleibt der Takt auch über Tage stündlich? Bisher sind es nur drei Stände.
3. Liefert auch Taiwan Angebote?

## Einleser (ab Manager 0.11.0, `manager\src\core\blizzard-import.js`)

- **Auswahl unter Quellen:** Alle Häuser sind zunächst abgewählt. „Vorschlag“ nimmt die Märkte, die der Manager aus Scans, Broker und Ledger kennt, in der Region des Zugangs. Liegt ein eigener Scan vor, entscheidet der Vergleich mit den Häusern der Fraktion (mindestens 50 % gleich und 1,5-mal so viel wie das zweitbeste Haus). Sonst entscheidet der Regelsatz aus dem Realm-Namen: Normal ist belegt, PvP nur vermutet, Rollenspiel geht nur über einen Scan.
- **Markt:** Der Stand landet im Markt `<Realm> / <Fraktion>`, damit Scans und Broker denselben Schlüssel nutzen. Von Hand gewählte Häuser ohne bekannten Markt heißen vorerst `Blizzard EU Haus 111 / Alliance`. Ein späterer Vorschlag benennt den Platzhalter um, solange es den echten Markt noch nicht gibt. Sonst bleiben seine Daten unter dem alten Namen.
- **Zeitplan:** Jede Minute prüft der Manager, ob ein Haus dran ist. Erst 62 Minuten nach dem letzten Stand fragt er nach (eine Abfrage mit `If-Modified-Since`), danach alle 5 Minuten bis zum neuen Stand. Nach einem Fehler ebenfalls alle 5 Minuten.
- **Speichern:** Ein Stand wird eine Momentaufnahme mit `source = 'scan'` und `art = 'api'`. So rechnen Verlauf, Chancen und die Werte für Broker ohne Sonderweg mit. In den Zählern erscheinen API-Stände getrennt von den eigenen Scans.
- **Absatz:** API-Stände werden nur untereinander über die Nummern verglichen. Eigene Scans zählen nur für Zeiten ohne API-Paar, Live-Abfragen nur für Zeiten ohne beides.
- **Namen:** Paare aus Gegenstand und Bonus-Nummer werden aus Scans gelernt und haben Vorrang vor der festen Tabelle deutscher Zusätze. Abgefragt wird auf Deutsch, Spieler mit anderem Client bekommen deshalb für Gegenstände mit Zusatz noch getrennte Schlüssel, bis ein eigener Scan das Paar liefert.

## Beobachter (Testfassung)

Für die offenen Fragen gibt es ab Manager 0.11.0 einen Beobachter (`manager\src\core\blizzard-watch.js`). Er läuft nur mit der Umgebungsvariable `PEON_MANAGER_BLIZZARD_WATCH` und bleibt für Nutzer unsichtbar.

- Alle 10 Minuten fragt er das kleinste Haus mit `If-Modified-Since`, ob es einen neuen Stand gibt.
- Bei einem neuen Stand holt er alle Häuser und legt die Antworten gepackt in `blizzard-beobachter\stand-<Zeit>\` im Datenordner ab, die letzten 4 Stände bleiben.
- Die Auswertung steht in `blizzard-beobachter\bericht.json`: Zeiten der Stände, Größen, vorkommende Felder und Werte, Vergleich der Angebotsnummern, einmalig andere Regionen und Spieldaten.
