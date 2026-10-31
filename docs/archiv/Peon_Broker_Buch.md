# Peon_Broker – Post einsammeln und Buch (Bauabschnitt 8)

Stand: 02.10.2026, **abgelöst durch `Peon_Ledger_Konzept.md`** (neues Modul Peon_Ledger mit Bestand und Buch, Entscheidung KarloDerBaer 02.10.2026). Bleibt als Verlauf der Abstimmung stehen. Grundlage: `Peon_Broker_Konzept.md` (Funktion 8 „Buch“, Stufe 2 „Post leeren“), Rechenmodell 1.8 (Verkaufsquote).

## 1. Ziel

Den Kreislauf schließen: Broker weiß bisher, was eingestellt, abgebrochen und gekauft wurde – aber nicht, was **wirklich verkauft** wurde oder abgelaufen ist. Das steht nur in der Post. Deshalb gehören beide Teile zusammen:

- **Post einsammeln:** ein Klick holt die ganze Auktionshaus-Post (Gold aus Verkäufen, zurückgekommene und gekaufte Gegenstände).
- **Buch:** Beim Einsammeln liest Broker die Rechnungen und schreibt mit: Verkäufe, Abläufe, Gebühren. Zusammen mit dem, was Broker schon heute merkt (eingestellt, abgebrochen, gekauft), ergibt das Einnahmen, Ausgaben und Gewinn je Tag und je Gegenstand.
- **Verkaufsquote:** Wie oft verkauft sich ein Gegenstand wirklich? Grundlage für spätere bessere Vorschläge (dritte Börsen-Methode: Preis × Verkaufschance).

## 2. Was das Spiel liefert (im Spiel zu prüfen)

Die Post-Funktionen sind in Retail und Classic seit Jahren gleich; in Forever noch nicht geprüft. Deshalb zuerst ein **Prüfbefehl** `/broker pruefen post` (nur lesend, bei offenem Postfach):

| Was | Funktion / Ereignis | Wofür |
|---|---|---|
| Anzahl Briefe | `GetInboxNumItems()` (gezeigte / insgesamt; das Postfach zeigt höchstens 50) | Fortschritt, „weitere Post später“ |
| Kopf eines Briefs | `GetInboxHeaderInfo(i)`: Absender, Betreff, Gold, Nachnahme, Tage übrig, Gegenstand ja/nein, zurückgeschickt | erkennen: Auktionshaus-Post |
| Rechnung | `GetInboxInvoiceInfo(i)`: Art (Verkäufer / Käufer / ausstehend), Gegenstand (Name), Käufer, Gebot, Sofortkauf, **Einzahlung**, **Auktionshaus-Anteil**, Menge | Verkauf ins Buch |
| Anhänge | `GetInboxItem(i, n)`, `GetInboxItemLink(i, n)` | Abgelaufen/gekauft: welcher Gegenstand, wie viele |
| Einsammeln | `TakeInboxMoney(i)`, `TakeInboxItem(i, n)` bzw. `AutoLootMailItem(i)` | Post holen |
| Ereignisse | `MAIL_SHOW`, `MAIL_INBOX_UPDATE`, `MAIL_CLOSED`, `UI_ERROR_MESSAGE` (Taschen voll) | Ablauf steuern |

Betreffzeilen (deDE, vom Prüfbefehl 0.1 bestätigt): „Auktion erfolgreich: %s“, „Ausstehender Verkauf: %s“, „Auktion abgelaufen: %s“, „Auktion abgebrochen: %s“, „Auktion gewonnen: %s“. Systemmeldung beim Verkauf, solange man online ist: „Es wurde ein Käufer für Eure Auktion gefunden: %s“.

Bekannt aus deinem Wollstoff-Verkauf (30.09.): Die Rechnung zeigt Verkaufspreis, Auktionshausgebühr (5 %) und erhaltenen Betrag; die Einzahlung kam laut Rechnung mit 1s statt der gezahlten 72c zurück – wird mit dem Prüfbefehl nochmal angesehen.

## 3. Post einsammeln

- **Knopf am Postfach:** „Broker: Post einsammeln (12 · 3g 40s)“ – Anzahl Auktionshaus-Briefe und Gold darin. Ohne solche Post grau.
- **Ein Klick startet**, danach holt Broker einen Brief nach dem anderen (jeweils warten, bis das Spiel den vorherigen bestätigt; etwa 3 Briefe pro Sekunde). Knopf zeigt den Fortschritt und dient zum Anhalten. Gekauft oder eingestellt wird dabei nichts.
- **Was eingesammelt wird:** Verkaufserlöse (Gold), abgelaufene und abgebrochene Gegenstände, gekaufte Gegenstände. **Nie:** Nachnahme-Post, Briefe ohne Auktionshaus-Absender (Vorschlag, siehe Frage 1).
- **Stopp:** Taschen voll (Meldung „Taschen voll – n Briefe übrig“), Postfach geschlossen, Kampf.
- **Mehr als 50 Briefe:** Das Spiel zeigt nur 50; der Rest erscheint, wenn Platz ist (Retail: nach etwa einer Minute). Broker zeigt „weitere Post in … Sek.“ und macht auf Klick weiter.
- **„Ausstehender Verkauf“** (Gold kommt später): wird ins Buch übernommen, sobald die Rechnung lesbar ist; das Gold kommt mit dem späteren Brief.
- Beim Einsammeln wird **vor** dem Holen gelesen (danach ist der Brief weg) – ein Brief kommt nur einmal ins Buch.

## 4. Das Buch

### 4.1 Was erfasst wird

| Art | Woher | Gespeichert (je Eintrag) |
|---|---|---|
| Verkauft | Rechnung beim Einsammeln | Zeit, Gegenstand, Menge, Verkaufspreis, Anteil des Auktionshauses, Einzahlung zurück, Charakter |
| Abgelaufen | Brief „Auktion abgelaufen“ + Anhang | Zeit, Gegenstand, Menge, verlorene Einstellgebühr (aus dem passenden Eintrag „eingestellt“, sonst Formel F18) |
| Abgebrochen | schon heute (`cancelled`) | Zeit, Gegenstand, Menge, Abbruchkosten |
| Eingestellt | schon heute (`posted`) | Zeit, Gegenstand, Menge, Preis, Laufzeit |
| Gekauft | schon heute (`bought`) | Zeit, Gegenstand, Menge, Kosten, Art (Händler-/Markt-Schnäppchen, Einkaufsliste) |
| An Händler verkauft | Knopf „Schnäppchen verkaufen“ (Merchant.lua) | Zeit, Gegenstand, Menge, Erlös |

- Rechnungen nennen nur den **Namen** des Gegenstands. Broker ordnet ihn über die Namen aus den Scans und den eigenen eingestellten Auktionen zu; ohne Treffer bleibt der Name stehen.
- **Je Markt getrennt** (wie die Preisdaten), alle Charaktere gemeinsam mit Angabe des Charakters.
- **Speichern:** Einzelne Einträge 90 Tage, danach je Gegenstand und Woche zusammengefasst (Summen), damit die Datei klein bleibt. Die bisherigen Listen (`posted`, `cancelled`, `bought`, je max. 500) gehen ins Buch über.

### 4.2 Reiter „Buch“

- **Oben:** Zeitraum (Auswahlliste: Heute, 7 Tage, 30 Tage, Alles) und Summen: **Einnahmen** (AH-Verkäufe + Händler), **Ausgaben** (Käufe), **Gebühren** (Anteil, verlorene Einstellgebühren, Abbruchkosten), **Gewinn** = Einnahmen − Ausgaben − Gebühren.
- **Liste „Je Gegenstand“:** Gegenstand, verkauft (Stück), Ø Verkaufspreis je Stück, abgelaufen, **Verkaufsquote**, Einnahmen, Ausgaben, Gewinn; sortierbar.
- **Liste „Verlauf“:** alle Einträge zeitlich (Zeit, Art, Gegenstand, Menge, Betrag, Charakter), Klick auf einen Gegenstand in „Je Gegenstand“ zeigt nur dessen Verlauf.
- Ohne Postfach und Auktionshaus nutzbar (wie „Preise“).

### 4.3 Verkaufsquote

- **VQ je Gegenstand** = verkaufte Auktionen ÷ (verkauft + abgelaufen + abgebrochen), letzte 30 Tage, ab 3 abgeschlossenen Auktionen.
- **Anzeige:** Tooltip mit Umschalt „Verkauft: 8 von 10 (30 Tage)“; Reiter Verkaufen als Hinweis („verkauft sich gut“ / „läuft oft ab – lieber Händler?“); Reiter Buch.
- **Einfluss auf Vorschlag und Empfehlung** (Rechenmodell 1.8: AH lohnt, wenn VQ × (Erlös − Händler) > (1 − VQ) × Einstellgebühr; später Preis × Verkaufschance): **erst in einem eigenen Schritt**, wenn genug eigene Daten da sind – vorher abgestimmt.

## 5. Bauabschnitte

1. **8a – Prüfbefehl Post** (`/broker pruefen post`, nur lesend): Funktionen, Betreffzeilen, Rechnungen der vorhandenen Briefe ins Debug-Protokoll. Du öffnest einmal das Postfach mit ein paar Auktionshaus-Briefen.
2. **8b – Post einsammeln und erfassen:** Knopf am Postfach, Ablauf, Einträge ins Buch (noch ohne Reiter, Prüfung über `/broker` und die Einstellungsdatei).
3. **8c – Reiter „Buch“:** Zeitraum, Summen, Je Gegenstand, Verlauf; Übernahme der bisherigen Listen.
4. **8d – Verkaufsquote** in Tooltip und Verkaufen → **Broker 1.0**.

## 6. Entschieden (KarloDerBaer, 02.10.2026)

1. Nur Auktionshaus-Post einsammeln (keine Spieler-Post, nie Nachnahme).
2. Nur per Knopf, nicht automatisch beim Öffnen des Postfachs.
3. ~~Händlerverkäufe nur über Brokers Knopf.~~ **Geändert:** Alles erfassen, was machbar ist – jeder Händlerverkauf und -einkauf, Handel mit Spielern, Post (auch an Twinks), Zerstören, Herstellen (Materialien und Ergebnis), Verbrauch (z. B. Trank), Beute; was sich nicht zuordnen lässt, als „verbraucht/sonstiges“.
4. Einzelne Einträge 90 Tage, danach Wochensummen.
5. Gewinn bei Handel: zuerst **Zeitraum** (Einnahmen − Ausgaben), später **Zuordnen** (echter Handelsgewinn mit Einstand). Dafür werden von Anfang an alle Zu- und Abgänge erfasst.
6. **Neu:** Das Buch erfasst beim Start den **Ist-Zustand** (alle Gegenstände und Gold) – auch **charakterübergreifend** (Taschen, Bank, Post, Auktionen und Gold der Twinks), wie es Taschen-Addons zeigen.

Umfang damit deutlich größer (Bestandsführung über alle Charaktere). Offene Grundsatzfrage: eigenes Modul für den Bestand oder Teil von Broker – wird mit KarloDerBaer abgestimmt, danach wird dieses Konzept überarbeitet.

## 6a. Ursprüngliche Fragen

1. **Was einsammeln?** Nur Auktionshaus-Post (Vorschlag) – oder auch Post von Spielern (Gold und Gegenstände, aber nie Nachnahme)?
2. **Automatisch beim Öffnen des Postfachs** einsammeln – oder nur per Knopf (Vorschlag: nur Knopf)?
3. **Händlerverkäufe:** nur, was über Brokers Knopf verkauft wird (Vorschlag) – oder jeden Verkauf beim Händler mitschreiben (dann auch Graues/Beute im Buch)?
4. **Aufbewahrung:** einzelne Einträge 90 Tage, danach Wochensummen – passt das?
5. **Gewinn je Gegenstand bei Handel** (billig kaufen, teurer verkaufen): einfach Einnahmen − Ausgaben im Zeitraum (Vorschlag) – oder Käufe und Verkäufe einander zuordnen (genauer, aber aufwendiger)?
