# Peon_Ledger: Buch mit klarem Handelsgewinn im Auktionshaus

Abgestimmt mit KarloDerBaer am 14.11.2026. Umgesetzt in Ledger 0.15.0 mit Peon 0.21.0 (Kern-API 21).

## 1. Ziel

Der Handelsgewinn zeigt nur noch, was der Handel im Auktionshaus bringt. Beute, die beim Händler oder im Auktionshaus landet, zählt nicht mehr hinein. Gebühren, Anteil und Rückzahlungen sind im Buch einzeln zu sehen.

## 2. Was bisher nicht stimmte

- Händlerverkäufe von Beute (Kosten 0) zählten voll als Handelsgewinn.
- Hergestelltes aus gekauftem und erbeutetem Material hatte nur die Kosten des gekauften Teils. Der Wert der Beute erschien beim Verkauf als Handelsgewinn.
- Die zurückgezahlte Einzahlung steckte unsichtbar im Erlös. Die Zeile „Auktionshaus: Gebühren“ zeigte nur die bezahlten Einzahlungen und Abbruchkosten zusammen.
- „Sondereinnahme“ mischte Startbestand aus Auktionshaus und Händler.

## 3. Beuteanteil je Posten

Jeder Posten trägt zusätzlich:

- `b` = Beuteanteil von 0 bis 1. Gekauft 0, Beute, Quest, Startbestand, Abweichung und alles mit Kosten 0 ist 1.
- `a` = Kosten je Stück, die aus Käufen im Auktionshaus stammen (für die Überleitung).

Herstellen: Der Beuteanteil des Ergebnisses ist der Marktwert des erbeuteten Materials geteilt durch (Marktwert des erbeuteten Materials + Kosten des gekauften Materials). Ohne Marktwert gilt der Händlerpreis. Das wirkt über mehrere Stufen. Alte Posten ohne `b` gelten bei Kosten 0 als Beute, sonst als gekauft.

Verkauf von n Stück: Beuteanteil λ = Summe der Anteile der entnommenen Stücke geteilt durch n (Stücke ohne Posten zählen als Beute).

- Erlös, zurückgezahlte Einzahlung und Gebühren teilen sich nach λ. Die Kosten der Stücke gehören ganz zum Handel.
- Handelsteil: (Erlös − Gebühren) × (1 − λ) − Kosten = Beitrag zum Handelsgewinn.
- Beuteteil: (Erlös − Gebühren) × λ = Verkauf Beute.
- Die offenen Gebühren eines Gegenstands verteilen sich auf die Stücke, die im Auktionshaus stehen (eingestellt minus zurück minus verkauft). Vorher trug der erste Verkauf alle Gebühren, auch die eines ganzen Stapels.
- Kommen mehrere Käufe desselben Gegenstands in einem Schwung aus der Post, werden ihre Beträge nach der Menge zusammengezählt. Vorher bekam der ganze Schwung nur den Preis des ersten Kaufs.

## 4. Buch „Nach Art“

```
AH: Käufe
AH: Einstellgebühren        (bezahlt als Ausgabe, zurück als Einnahme)
AH: Abbruchkosten
AH: Verkäufe                (brutto)
AH: Anteil
AH: Ware an Händler         (Handelsteil von Händlerverkäufen)

AH: Handelsgewinn
   davon ins Lager
   davon in Auktionen            (ab 0.15.1)
   davon offene Gebühren
   davon Gebühren für Beute
   davon Händler/Spieler
   davon verbraucht
──────────
Händler, AH: Verkauf Beute, Rückkauf, Reparaturen, Beute, Quests, Herstellen,
Spielerhandel, Post, Flüge, Lehrer, Sonstiges

Spielalltag
──────────
AH: Handelsgewinn
Spielalltag
Gesamtergebnis
   Goldänderung
```

- Die AH-Zeilen sind Geld, das wirklich geflossen ist. Ihr Saldo zusammen ist gleich Handelsgewinn plus der grauen davon-Zeilen. „davon ins Lager“ ist der Rest dieser Rechnung, so geht sie immer auf.
- Verkäufe von Ware an andere Spieler zählen zum Spielerhandel, nicht zum Handelsgewinn.
- Abbruchkosten ohne Gegenstand mindern den Handelsgewinn sofort, Einstellgebühren erst beim Verkauf des Gegenstands.
- „AH: Verkäufe“ und „AH: Anteil“ zeigen nur den Handelsteil. „AH: Verkauf Beute“ zeigt den Beuteteil nach Anteil als Einnahme, dazu seinen Teil an Einzahlung (Einnahme) und Gebühren (Ausgabe). Dieses Gold steht auch bei den Einstellgebühren oben, die graue Zeile „davon Einstellgebühren für Beute“ gleicht das aus.
- Spielalltag = Saldo der übrigen Zeilen. Gesamtergebnis = Handelsgewinn + Spielalltag. Goldänderung = echte Änderung des Goldes. Sie unterscheidet sich vom Gesamtergebnis um ins Lager, offene Einstellgebühren, Ware von Händlern und Spielern und selbst verbraucht.
- „Sondereinnahme“ entfällt: Startbestand ist Beute.

Links bei den Summen: AH: Handelsgewinn (groß), Spielalltag, Gesamtergebnis (groß), Goldänderung, Verbrauch. Verkäufe, Anteil, Einzahlung zurück, Gebühren, Ware an Händler und Wareneinsatz zeigt der Tooltip des Handelsgewinns. Jede Zeile „Nach Art“ erklärt sich im Tooltip.

Der Trennstrich kommt aus dem Kern: `UI.Table` mit `o.rowLine(item)` (Peon 0.21.0, Kern-API 21). Mit einem älteren Kern fehlt nur der Strich.

## 5. Post an Twinks und Ruhezeit nach dem Einloggen

- In den ersten 20 Sekunden nach dem Einloggen verbucht Ledger keine Bewegungen. Anhänge aus einem gerade genommenen Brief sind davon jetzt ausgenommen.
- Findet die Kontrollrechnung mehr Ware, als sie erwartet, und liegt diese Ware beim Charakter unter „Unterwegs“, verbucht sie den Zugang als Twink-Post mit den mitgewanderten Kosten.
- Einmalige Reparatur beim ersten Start von 0.15.0: Abweichungen, die zu „Unterwegs“ desselben Charakters passen, werden zu Twink-Post.

## 5a. Eingestellte Ware (ab 0.15.1)

- Beim Einstellen kommt die Ware gleich unter Auktionen, danach fragt Ledger die eigenen Auktionen neu ab. Vorher fehlte sie bis zum nächsten Blick auf die Seite Auktionen, und die Kontrollrechnung buchte Abweichungen, die die Kosten zerstörten.
- Alte Paare aus Minus nach dem Einstellen und späterem Plus werden bei jedem Login zu „Auktion (korrigiert)“.
- „davon in Auktionen“ zeigt die AH-Kosten der Stücke aus Käufen im Zeitraum, die gerade in laufenden Auktionen stehen.

## 6. Anzeige beim Einsammeln

Während „Alles einsammeln“ oder „Auktionshaus-Post“ läuft, zeigt das Postfenster einen Balken mit „Brief n von m“.
