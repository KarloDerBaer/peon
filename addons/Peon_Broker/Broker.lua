-- Peon_Broker - Broker.lua
-- Anmeldung beim Peon-Kern, Markt-Schluessel, Geldanzeige, Befehle.
-- Einstellungen in PeonBrokerDB (accountweit). Ergebnis der Pruefung in PeonBrokerDB.probe.
--
-- Werte und Zuhoerer fuer den Peon Manager laufen ueber Peon_Bridge (Kanal broker).
-- Konzepte: docs/konzepte/broker/ (Neuaufbau, Rechenmodell). Verlauf der Versionen: docs/changelog/Peon_Broker.md.

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "broker",             -- /peon broker ...
    title    = "Broker",
    db       = "PeonBrokerDB",
    charDB   = "PeonBrokerCharDB",   -- je Charakter: listSel, recipes (keep bis 0.54, Behalten)
    -- ab 0.83 (KarloDerBaer, 12.11.2026): Radar- und Fokus-Werte nach seinen Einstellungen (gilt fuer neue Werte)
    defaults = {
        minimapShow  = true,
        minimapAngle = 225,
        tooltipShow  = true,    -- Preiszeilen im Tooltip
        tooltipPacks = true,    -- ab 0.87: Kosten je Paket bei Kisten mit Paketliste
        tooltipAvg   = true,    -- Zeile "7 Tage"
        tooltipVendor = true,   -- Zeile "Haendler"
        tooltipHint  = true,    -- Hinweise
        tooltipNeutral = "shift", -- ab 0.42: Zeile "Neutral" immer, nur mit Umschalt oder aus
        trendNeutral = 5,       -- TG_gleich: bis +-5 % gleich geblieben
        trendStrong  = 20,      -- TG_stark: ab +-20 % stark gestiegen/gefallen
        undercutMode = "copper",-- UB (Einzelgegenstaende): fester Betrag (Kupfer) oder Prozent
        undercutValue = 1,
        undercutMassMode = "copper", -- UBmass (Massenware)
        undercutMassValue = 0,
        dumpPct      = 30,      -- DG: Dumping-Grenze in % unter dem Median
        duration     = 8,       -- LZ: Laufzeit in Stunden (2, 8, 24)
        dataDays     = 30,      -- AUFB: Tageswerte so lange aufbewahren, danach Wochenwerte
        ahPlain      = false,   -- ab 0.41: "Blizzard pur", Broker laesst das Auktionshaus in Ruhe (AHTabs.lua)
        windowTab    = "prices",-- zuletzt gewaehlter Reiter
        windowPos    = {},      -- Position des Fensters, wenn es nicht am Auktionshaus angedockt ist
        dealMinVendor = 100,    -- GEW_H: Mindestgewinn Haendler-Schnaeppchen (Kupfer; bis 0.82 10)
        dealMinMarket = 50,     -- GEW_M: Mindestgewinn Markt-Schnaeppchen (Silber)
        dealScans    = 10,      -- SCANS_MIN: Datenlage Markt
        dealDays     = 7,       -- TAGE
        radarMaxAge  = 60,      -- Radar: Treffer aus der Datenbank bis so viele Minuten alt (0 = unbegrenzt; ab 0.15, ersetzt dealMaxAge)
        radarSound   = false,   -- Ton bei neuen Radar-Treffern (ab 0.95.1 aus, Fehlerbericht 29: Warnton ohne Chatzeile)
        watchAlarm   = true,    -- ab 0.83: Warnung der Beobachtung (Chat und Ton), Haken unter Beobachten
        radarKind    = "both",  -- Radar: Haendler, AH oder beides (ab 0.17)
        radarShowExpensive = false, -- Radar: auch unbezahlbare Schnaeppchen zeigen (ab 0.17)
        dealMargin   = 20,      -- MARGE: Markt-Schnaeppchen mindestens so viel % ueber dem Kaufpreis (ab 0.17)
        dealDepth    = 20,      -- TIEFE: hoechstens so viel % aller Angebote (ab 0.17)
        dealHold     = 48,      -- Markt-Schnaeppchen: hoechstens Absatz je Std. x so viele Stunden (ab 0.26)
        radarSoundKey = "raid", -- Warnton bei neuen Treffern (ab 0.19): raid, ready, alarm, tell
        radarFlash   = 5,       -- neue Treffer: Zeile pulsiert so viele Sekunden (ab 0.19)
        radarReserve = 0,       -- Goldreserve in Gold: so viel gibt der Radar nie aus (ab 0.19)
        buyoutHours  = 2,       -- Aufkauf (ab 0.65): Menge muss sich in so vielen Stunden wieder verkaufen
        focusEvery   = 5,       -- Fokus (0.66 bis 0.69): Abstand der Abfragen in Sekunden, ab 0.70 focusRate
        focusRate    = 90,      -- Fokus (ab 0.70): Abfragen je Minute, bis 90 (Grenze des Spiels; bis 0.82 12)
        focusWindow  = 10,      -- Fokus (ab 0.70): Messwerte aus den letzten so vielen Minuten
        focusFirst   = 10,      -- Fokus (ab 0.70): erstes, vorlaeufiges Urteil nach so vielen Sekunden (bis 0.82 30)
        focusSure    = 60,      -- Fokus (ab 0.70): Urteil ohne "vorlaeufig" ab so vielen Sekunden (bis 0.82 120)
        focusMore    = 10,      -- Fokus (ab 0.70): "Kaufen" erst, wenn der Abfluss so viel % ueber dem Zufluss liegt (bis 0.82 20)
        focusGrow    = 10,      -- Fokus (ab 0.70): Menge unter Ziel waechst/schrumpft ab so viel %
        sellVariantOnly = true, -- ab 0.98: im Verkaufen nur die Angebote dieser Variante zeigen (SellVariant.lua)
        relistDefault = false,  -- ab 0.91: Gekauftes zum Wiedereinstellen merken (je Gegenstand in relist, sonst dieser Wert)
        watchSoundDown = "raid", -- ab 0.91: Warnton der Beobachtung bei Kaufen bis (off = kein Ton)
        watchSoundUp = "raid",  -- ab 0.91: Warnton der Beobachtung beim Zielpreis
        watchChatDown = true,   -- ab 0.91: Chatnachricht bei Kaufen bis
        watchChatUp  = true,    -- ab 0.91: Chatnachricht beim Zielpreis
        focusPriceTol = 1,      -- Fokus (ab 0.70): Warnung, wenn der Gesamtpreis so viel % ueber dem erwarteten liegt
        focusMode    = "buyout", -- Fokus (ab 0.104): Modus Aufkauf (buyout) oder Schnellkauf (quick)
        focusBuyout  = false,   -- ab 0.133 (U1): Modus Aufkauf im Einkaufen (Einstellungen, Erweitert), sonst nur Schnellkauf
        foldBait     = false,   -- ab 0.133: Bereich Lockangebot im Einkaufen aufgeklappt
        chartRange   = 5,       -- ab 0.134 (U2): Zeitraum des Diagramms im Einkaufen in Minuten (5, 15, 60)
        chartMin     = true,    -- ab 0.134: Linien im Diagramm des Einkaufens (fuer alle Gegenstaende): Guenstigster,
        chartLimit   = true,    --   Kaufen bis,
        chartUnder   = true,    --   Menge darunter,
        chartDips    = true,    --   Einbrueche,
        chartBaits   = true,    --   Lockangebote
        foldMore     = false,   -- ab 0.133: Bereich Mehr Einstellungen im Einkaufen aufgeklappt
        quickAlarm   = true,    -- Schnellkauf (ab 0.104): Ton, sobald etwas unter Kaufen bis steht
        quickSound   = "raid",  -- Schnellkauf (ab 0.104): welcher Ton
        quickHold = 1,          -- ab 0.114: so viele Sekunden keine Abfrage, solange der Kaufknopf frei ist (0 = aus)
        quickBaitAlarm = true,  -- ab 0.111: Ton, wenn ein fremdes Lockangebot auftaucht und der Kaufknopf noch gesperrt ist
        quickBaitSound = "ping",
        quickMoveIn  = 2,       -- Schnellkauf (ab 0.108): lebhaft ab so vielen Einstellungen je Minute ...
        quickMoveAll = 5,       -- ... und so vielen Ereignissen je Minute (Einstellungen, Kaeufe, Preisspruenge)
        quickMoveLow = 1,       -- ruhig unter so vielen Ereignissen je Minute
        quickZonePct = 5,       -- ab 0.120: Einstellungen und Kaeufe zaehlen nur bis so viel % ueber dem guenstigsten (Kaufzone)
        quickJumpPct = 2,       -- ab 0.120: Preissprung erst ab so viel % Aenderung des guenstigsten Preises
        quickDipPct  = 5,       -- ab 0.122: Einbruch = neues Angebot so viel % unter dem bisher guenstigsten (QuickStats.lua)
        quickStatDays = 7,      -- ab 0.122: Gelegenheiten ueber so viele Tage (ab 0.126 Vorgabe 7 statt 14)
        quickFollowSec = 30,
        quickBaitMinPct = 5,
        autoSaveBuyout = true,  -- ab 0.113: Werte des Aufkaufs beim Verlassen automatisch speichern (nur beobachtete)
        autoSaveQuick = true,   -- ab 0.113: dasselbe fuer den Schnellkauf       -- ab 0.110: Kaufprotokoll im Fokus (Auswertung der Fehlkaeufe)    -- ab 0.109: fremdes Lockangebot (1 Stueck) erst so viel % unter dem bisher guenstigsten    -- Nachwirkung eines Lockangebots: so viele Sekunden danach zaehlen
        quickBaitPct = 50,      -- Schnellkauf (ab 0.104): Lockpreis so viel % unter Kaufen bis (bis 0.106: 20 % unter der ersten echten Stufe)
        baitQty      = 5,       -- Verkaufen (ab 0.104): Lockangebot hoechstens so viele Stueck ...
        baitPct      = 2,       -- ... oder unter so viel % aller Angebote ...
        baitGap      = 10,      -- ... und die naechste Stufe mehr als so viel % teurer
        radarVendorOn = true,   -- Radar (ab 0.71): Art Haendler zeigen
        radarBuyoutOn = true,   -- Radar (ab 0.71): Art Aufkauf zeigen
        -- ab 0.96: Reiter Chancen (Chances.lua) statt Art Spekulation im Radar (radarSpecOn entfaellt)
        chancesShowS = true, chancesShowL = true, chancesShowB = true, chancesShowM = true,
        chancesAhNote = true,   -- beim Oeffnen des Auktionshauses sagen, wie viele Chancen warten
        chancesNotify = true,   -- Meldung, wenn ein guenstiges Zeitfenster beginnt (Muster)
        chancesScan  = "mgr",   -- ab 0.105: Auswahl des Scans im Reiter Chancen (mgr, watch, mass, all)
        chancesTab   = "spec",  -- ab 0.119: zuletzt offener Unterreiter in Chancen (spec, buyout, quick)
        watchTab     = "buyout", -- ab 0.119: zuletzt offener Unterreiter in Beobachten (buyout, quick)
        chancesShowQ = true,    -- ab 0.119: Chancen der Art Schnellkauf (QuickChances.lua)
        tradeOn = false,        -- ab 0.128.2: Markttausch in Chancen und Beobachten (Trade.lua), erst nach Einschalten (KarloDerBaer)
        chancesTradeNote = true,   -- ab 0.127: Hinweis am Zielhaus auf Ware aus dem Markttausch
        qcCount      = 10,      -- ab 0.119: so viele Vorschlaege fuer den Schnellkauf
        qcMinPrice   = 100,     -- ab 0.119: guenstigster Preis je Stueck mindestens (Kupfer, 1 Silber)
        qcProbes     = 5,       -- ab 0.119: Abfragen je Pruefung eines Gegenstands
        qcWaitMax    = 10,      -- ab 0.120: ruhige Vorschlaege hoechstens alle so viele Minuten pruefen (maessige gleitend oefter)
        quickLimitPct = 50,     -- ab 0.120: Kaufen bis im Schnellkauf ohne eigenen Wert: so viel % des guenstigsten Angebots
        quickGoldDefault = 50000, -- ab 0.120: Limit pro Kauf im Schnellkauf ohne eigenen Wert (Kupfer, 5 Gold)
        -- ab 0.97 (Wunsch KarloDerBaer 15.11.2026): ob und wann die rote Zahl am Reiter kommt (AHTabs.BADGE_MODES)
        badgeBuy = "buypart", badgeWatch = "both", badgeRadar = "blink", badgeSell = "on", badgeChances = "off",
        buyoutMinQty = 500,     -- Aufkauf (ab 0.71): Massenware erst ab so vielen Stueck im Angebot (bis 0.82 200)
        buyoutMinLevels = 4,    -- Aufkauf (ab 0.71): und so vielen Preisstufen (bis 0.82 5)
        buyoutMinSales = 270,   -- (bis 0.82 50)
        buyoutTargetPct = 20,   -- Aufkauf (ab 0.79): Ziel hoechstens so viel % ueber der oberen Grenze des ueblichen Bereichs    -- Aufkauf (ab 0.71): und so viel Absatz je Tag
        radarRenew   = true,    -- Radar (ab 0.71): gezeigte Moeglichkeiten regelmaessig erneuern
        radarRenewSec = 60,     -- Radar (ab 0.71): jede Moeglichkeit so oft live pruefen (Sekunden)
        radarRenewMax = 120,    -- Radar (ab 0.71): reicht das Budget nicht, hoechstens so selten (Sekunden)
        radarSearchPct = 20,    -- Radar (ab 0.71): so viel % der Abfragen bleiben immer fuer den Such-Scan
        radarScanMode = "mass", -- (bis 0.82 "watch")
        aucOwnList   = true,    -- Auktionen (ab 0.72): Brokers Liste ueber Blizzards Ansicht
        aucHide      = {},      -- Auktionen (ab 0.72): ausgeblendete Status (best, equal, under, high, sold)-- Radar (ab 0.71): Such-Scan ueber Beobachten, Massenware oder alles
        keepAllChars = false,   -- Reiter Behalten: Vorrat aller Charaktere aus Peon_Ledger (ab 0.22)
        salesWindow  = 6,       -- Absatz (ab 0.23.1): aktueller Absatz aus den Vergleichen der letzten Stunden
        salesMidMin  = 60,      -- Sicherheit: ab so vielen beobachteten Minuten gelbes statt rotes Zeichen
        salesSureMin = 180,     -- ab so vielen beobachteten Minuten gruenes Zeichen
        salesCancelPct = 10,    -- Einzelgegenstaende: so viel % der vorzeitig verschwundenen Angebote gelten als abgebrochen
    },
    ranges   = { minimapAngle = { 0, 359, 1 }, dataDays = { 14, 90, 1 }, trendNeutral = { 1, 20, 1 },
                 trendStrong = { 10, 100, 5 }, undercutValue = { 0, 100, 1 }, undercutMassValue = { 0, 100, 1 },
                 dumpPct = { 10, 90, 5 }, dealMinVendor = { 0, 10000000, 1 },
                 dealMinMarket = { 0, 100000, 1 }, dealScans = { 1, 50, 1 }, dealDays = { 1, 14, 1 }, radarMaxAge = { 0, 240, 5 },
                 dealMargin = { 0, 100, 5 }, dealDepth = { 5, 100, 5 }, dealHold = { 6, 168, 6 }, radarFlash = { 0, 30, 1 }, radarReserve = { 0, 1000000, 1 },
                 buyoutHours = { 1, 24, 1 }, focusEvery = { 3, 30, 1 },
                 focusRate = { 2, 90, 1 }, focusWindow = { 2, 30, 1 }, focusFirst = { 10, 120, 5 }, focusSure = { 30, 600, 10 },
                 focusMore = { 0, 100, 5 }, focusGrow = { 1, 50, 1 }, focusPriceTol = { 0, 10, 1 },
                 quickBaitPct = { 5, 90, 5 }, quickMoveIn = { 1, 20, 1 }, quickMoveAll = { 1, 30, 1 },
                 quickMoveLow = { 1, 10, 1 }, quickFollowSec = { 10, 120, 5 }, quickHold = { 0, 5, 0.5 }, quickBaitMinPct = { 1, 50, 1 }, baitQty = { 1, 50, 1 }, baitPct = { 0, 10, 1 }, baitGap = { 5, 50, 5 },
                 buyoutMinQty = { 0, 100000, 10 }, buyoutMinLevels = { 2, 12, 1 }, buyoutMinSales = { 0, 100000, 5 }, buyoutTargetPct = { 0, 200, 5 },
                 radarRenewSec = { 15, 600, 15 }, radarRenewMax = { 30, 1200, 30 }, radarSearchPct = { 0, 80, 5 },
                 salesWindow = { 1, 24, 1 }, salesMidMin = { 10, 600, 10 }, salesSureMin = { 20, 1440, 10 },
                 salesCancelPct = { 0, 50, 5 },
                 qcCount = { 3, 30, 1 }, qcMinPrice = { 0, 1000000, 1 }, qcProbes = { 3, 20, 1 },   -- ab 0.119
                 qcWaitMax = { 1, 60, 1 }, quickZonePct = { 1, 50, 1 }, quickJumpPct = { 0, 20, 1 }, quickDipPct = { 1, 30, 1 }, quickStatDays = { 1, 60, 1 }, quickLimitPct = { 10, 100, 5 }, quickGoldDefault = { 0, 100000000, 1 } },   -- ab 0.120
    choices  = { undercutMode = { copper = true, percent = true }, undercutMassMode = { copper = true, percent = true },
                 duration = { [2] = true, [8] = true, [24] = true },
                 chartRange = { [5] = true, [15] = true, [60] = true },   -- ab 0.134
                 radarKind = { both = true, vendor = true, market = true },
                 radarScanMode = { watch = true, mass = true, all = true },
                 radarSoundKey = { raid = true, ready = true, alarm = true, tell = true, coin = true, levelup = true, queue = true, ping = true, boss = true, auction = true },
                 watchSoundDown = { off = true, raid = true, ready = true, alarm = true, tell = true },   -- ab 0.91
                 watchSoundUp = { off = true, raid = true, ready = true, alarm = true, tell = true },
                 tooltipNeutral = { always = true, shift = true, off = true },
                 badgeBuy = { off = true, buypart = true, buy = true },   -- ab 0.97
                 badgeWatch = { off = true, both = true, buy = true, sell = true },
                 badgeRadar = { off = true, blink = true, still = true },
                 badgeSell = { off = true, on = true },
                 badgeChances = { off = true, ok = true, all = true },
                 focusMode = { buyout = true, quick = true },   -- ab 0.104
                 chancesScan = { mgr = true, watch = true, mass = true, all = true },   -- ab 0.105
                 chancesTab = { spec = true, buyout = true, quick = true },   -- ab 0.119
                 watchTab = { buyout = true, quick = true },
                 quickSound = { raid = true, ready = true, alarm = true, tell = true, coin = true, levelup = true, queue = true, ping = true, boss = true, auction = true },
                 quickBaitSound = { raid = true, ready = true, alarm = true, tell = true, coin = true, levelup = true, queue = true, ping = true, boss = true, auction = true },
                 windowTab = { start = true, sell = true, keep = true, auctions = true, buy = true, radar = true, prices = true,
                              market = true, watch = true, sources = true, vendors = true,
                              browse = true, focus = true, more = true } },   -- ab 0.59 (Neuaufbau N1)   -- ab 0.51 neue Reiter   -- ab 0.28 mit "start", ohne "book"
    keepOnReset = { windowPos = true, windowTab = true, keepAllChars = true, ahPlain = true },
    migrate  = function(m, acc)
        -- ab 0.115: Kaufprotokoll (0.110 bis 0.114.1) entfernt, gespeicherte Zeilen weg
        acc.buyLog, acc.buyTrace = nil, nil
        -- ab 0.70: Abstand im Fokus als Abfragen je Minute
        if acc.focusRate == nil and type(acc.focusEvery) == "number" and acc.focusEvery > 0 and acc.focusEvery ~= 5 then
            acc.focusRate = math.max(2, math.min(90, math.floor(60 / acc.focusEvery + 0.5)))
        end
        -- ab 0.95.1 (Fehlerbericht 29): Ton bei neuen Radar-Treffern einmal ausschalten, er kam ohne Chatzeile
        if not acc.radarSoundOff then acc.radarSound = false; acc.radarSoundOff = true end
        -- ab 0.107.1: Lockpreis jetzt unter Kaufen bis, die alte Vorgabe 20 % (unter dem Markt) einmal auf 50 % stellen
        if not acc.quickBaitPct50 then
            if acc.quickBaitPct == nil or acc.quickBaitPct == 20 then acc.quickBaitPct = 50 end
            acc.quickBaitPct50 = true
        end
        if ns.Data then ns.Data.Migrate(acc) end
        if ns.Sales then ns.Sales.Migrate(acc) end
    end,
    slash    = { "/broker" },
    onSlash  = function(m, cmd, rest)
        if cmd == "pruefen" or cmd == "prüfen" or cmd == "check" or cmd == "probe" then
            local r = rest:lower()
            if r == "scan" then ns.Probe.ScanTest()
            elseif r == "abfrage" or r == "query" then ns.Probe.QueryTest()
            elseif r == "auktionen" or r == "auctions" or r == "felder" or r == "fields" then ns.Probe.FieldReport()
            elseif r == "beruf" or r == "craft" then ns.Craft.Probe()
            elseif r == "ah" then ns.AHTabs.Probe()
            elseif r == "zeit" or r == "time" then ns.Radar.PerfReport()   -- ab 0.69
            elseif r == "fehler" or r == "errors" then ns.Radar.ErrorReport()   -- ab 0.74
            elseif r == "kalender" or r == "calendar" then ns.Calendar.Probe()   -- ab 0.93, Pruefung P2
            else ns.Probe.Run() end
        elseif cmd == "pur" or cmd == "blizzard" then
            -- ab 0.41: "Blizzard pur" an oder aus (laedt neu, darum mit Rueckfrage)
            ns.AHTabs.AskPlain(not ns.AHPlain())
        elseif cmd == "absatz" or cmd == "sales" then
            ns.Sales.Report(rest)
        elseif cmd == "scan" then
            ns.Scan.Start()
        elseif cmd == "optionen" or cmd == "options" or cmd == "config" then
            m:OpenOptions()
        else
            ns.Window.Toggle()
        end
    end,
})
ns.mod = mod

-- Schnittstelle fuer andere Module (nur lesend): Wert eines Gegenstands (Zeile 1 des Tooltips) fuer count Stueck
function mod:ItemValue(id, count) return ns.ItemValue(id, count) end
-- Ab 0.84 (fuer Peon_Ledger 0.14): Seite Gegenstand mit diesem Gegenstand zeigen (Ledger hat keine eigene mehr)
function mod:ShowItem(id)
    if type(id) ~= "number" or not ns.Go then return false end
    return ns.Go.Item({ id = id })
end

-- Ab 0.85 (Manager-Angleichung A1, Peon_Manager_Angleichung.md 3.1): Kennung dieses WoW-Kontos fuer den Peon Manager.
-- Das Spiel kennt den Namen des Kontoordners nicht, der Manager ordnet ueber die Kennung Einkaufslisten und
-- Beobachtung dem richtigen Konto zu. Einmal angelegt, nie geaendert (PeonBrokerDB.acct).
function mod:AcctId()
    local acc = mod.acc
    if type(acc) ~= "table" then return nil end
    if type(acc.acct) ~= "string" or acc.acct == "" then
        acc.acct = ("k%.0f_%d"):format(time(), math.random(1, 1000000))
    end
    return acc.acct
end

-- Ab 0.27 (fuer den Ledger-Reiter "Gegenstand", Konzept Peon_Ledger_Gegenstand.md): Verlauf eines Gegenstands im
-- aktuellen Markt, aelteste zuerst. Je Eintrag { day, week (nur Wochenwerte), min, median, qty, scans,
-- sales (Absatz je Tag, nil unter 1 Std. Beobachtung), low, high (ueblicher Bereich an diesem Tag) }.
function mod:History(id) return ns.ItemHistory(id) end
-- Tagesnummer wie in Brokers Daten (Mitternacht nach PC-Uhr)
function mod:DayOf(t) return ns.Data.Day(t) end
-- Aktueller Stand eines Gegenstands: { min, median, qty, offers, t, gone, low, high, trend, suggest, vendor, commodity,
-- perHour, level (1 rot, 2 gelb, 3 gruen), name, quality } oder nil ohne Daten
function mod:MarketInfo(id) return ns.MarketInfo(id) end
-- ab 0.32 (fuer Peon_Client): Warenart (true = Massenware) und Haendlerpreis je Stueck
function mod:IsCommodity(key) return ns.Data and ns.Data.IsCommodity(key) or false end
function mod:VendorPrice(id) return ns.VendorPrice(id) end
-- Ab 0.94 (fuer Peon_Profession): Kaufpreis je Stueck wie im Berufsfenster (Haendler oder AH, das Guenstigere).
-- Rueckgabe: Preis (nil = unbekannt), Quelle ("vendor", "ah", "none"). Ab 0.95 dahinter wie im Berufsfenster:
-- AH-Preis, Haendlerpreis, Herkunft des Haendlerpreises ("seen", "ledger", "est"), Haendler
function mod:BuyPrice(id)
    if type(id) ~= "number" or not (ns.Craft and ns.Craft.BuyPrice) then return nil, "none" end
    return ns.Craft.BuyPrice(id)
end
-- Ab 0.95 (fuer Peon_Profession): guenstigstes Angebot je Stueck im Heimatmarkt, nil = unbekannt
function mod:AhPrice(id)
    if type(id) ~= "number" or not (ns.Craft and ns.Craft.UnitCost) then return nil end
    return ns.Craft.UnitCost(id)
end
-- Ab 0.94 (fuer Peon_Profession): Material auf die Einkaufsliste mit diesem Namen (wird bei Bedarf angelegt).
-- mats = { { id = itemID, n = Stueck, v = Haendlerware } }. Die Wunschmenge wird auf n gesetzt, "Fehlt" rechnet die
-- Liste selbst. Ab 0.95: keepMax = true laesst die Wunschmenge nicht kleiner werden und setzt die Markierung
-- Haendlerware (wie bisher "Auf Einkaufsliste" im Berufsfenster). Rueckgabe: Zahl der Eintraege, Liste
function mod:AddToList(name, mats, keepMax)
    if type(name) ~= "string" or name == "" or type(mats) ~= "table" or not (ns.Buy and ns.Buy.AddToNamed) then return 0 end
    return ns.Buy.AddToNamed(name, mats, keepMax)
end
-- Ab 0.29 (Ledger-Reiter "Gegenstaende"): alle Gegenstaende des aktuellen Markts mit Nummer (Varianten mit
-- Zusatz ausgenommen). { [itemID] = { min, median, qty, t, gone, name, quality } }
function mod:MarketItems() return ns.MarketItems() end

function ns.MarketItems()
    local out = {}
    local D = ns.Data
    if not D or not D.Market then return out end
    local m = D.Market()
    if type(m) ~= "table" or type(m.items) ~= "table" then return out end
    for k, e in pairs(m.items) do
        if type(k) == "number" and type(e) == "table" then
            local t = e.t
            if e.lt and (not t or e.lt > t) then t = e.lt end
            out[k] = { min = e.m, median = e.md, qty = e.q, t = t, gone = e.gone, name = e.nm, quality = e.ql }
        end
    end
    return out
end

-- Zuhoerer fuer Momentaufnahmen (ab 0.30, fuer Peon_Client). fn(art, ...):
--   "scan_start", { market, t, total, variants }       Komplettscan: Daten da, Lesen beginnt
--   "scan_row", itemID, name, count, quality, buyout, minBid, bid, band, link   je Angebot (auch reine Gebote)
--   "scan_end", { market, t, listings, skipped, items } "scan_abort", { market, t }
--   "live", key, rows, t, { market, commodity, partial } jede Live-Abfrage (ausser Ergebnissen eines anderen Gegenstands)
-- Ohne Zuhoerer aendert sich nichts. Ein Zuhoerer mit Fehler wird entfernt (einmal gemeldet).
ns.listeners = {}
function mod:AddSnapshotListener(fn)
    if type(fn) ~= "function" then return false end
    for _, f in ipairs(ns.listeners) do if f == fn then return true end end
    ns.listeners[#ns.listeners + 1] = fn
    return true
end

function ns.HasListeners() return #ns.listeners > 0 end

function ns.Notify(kind, ...)
    local list = ns.listeners
    for i = #list, 1, -1 do
        local ok, err = pcall(list[i], kind, ...)
        if not ok then
            table.remove(list, i)
            mod:ReportError("Zuhoerer", err)
        end
    end
end

-- Ist das Auktionshaus gerade offen? Ohne Abhaengigkeit von der Reihenfolge der Ereignisse (ab 0.40)
local function AHOpenNow()
    local pim = rawget(_G, "C_PlayerInteractionManager")
    local pt = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Auctioneer
    if pim and type(pim.IsInteractingWithNpcOfType) == "function" and pt then
        local ok, v = pcall(pim.IsInteractingWithNpcOfType, pt)
        if ok and v == true then return true end
    end
    if ns.Scan and ns.Scan.ahOpen then return true end
    local f = rawget(_G, "AuctionHouseFrame")
    return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() == true
end

-- Neutrales Auktionshaus (ab 0.40, KarloDerBaer 09.11.2026): Der Auktionator hat keine Fraktion.
-- Geprueft in Beutebucht: UnitFactionGroup gibt fuer "Auktionator O'reely" nil.
function ns.AtNeutralAH()
    if not AHOpenNow() then return false end
    if not (UnitExists and UnitExists("npc")) then return false end
    local f = UnitFactionGroup and UnitFactionGroup("npc")
    if Peon.IsSecret(f) then return false end
    return f == nil or f == "" or f == "Neutral"
end

-- Markt = Regelsatz (Realm-Name) + Fraktion. Der Nachname des Charakters gehoert nicht dazu.
-- Ab 0.42 (Umbau U1, Konzept Abschnitt 5.1) zwei Fragen:
--   ns.HomeMarketKey(): Heimatmarkt, immer die eigene Fraktion. Fuer Tooltip, Wert fuer Ledger, Berufsfenster.
--   ns.AHMarketKey():   Markt am offenen Haus, am neutralen Auktionshaus "Neutral" (ab 0.40), sonst Heimat.
--                       Fuer Scan, Live-Abfragen und alles, was im Auktionshaus passiert.
-- ns.MarketKey() ist der Markt, in dem gerade gerechnet wird: ns.AHMarketKey(), ausser innerhalb von
-- ns.WithHome(...) (dann der Heimatmarkt). So greifen auch verschachtelte Abfragen (Lookup, Bereich vom Manager,
-- Absatz) auf denselben Markt zu.
local function RealmFaction()
    -- ab 0.129.0: mit Rueckfall des Kerns (API 27), das Spiel lieferte zeitweise einen leeren Namen
    local realm = (Peon.RealmName and Peon.RealmName()) or (GetRealmName and GetRealmName()) or nil
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if Peon.IsSecret(realm) or type(realm) ~= "string" or realm == "" then realm = "?" end
    if Peon.IsSecret(faction) or type(faction) ~= "string" or faction == "" then faction = "?" end
    return realm, faction
end

function ns.HomeMarketKey()
    local realm, faction = RealmFaction()
    return realm .. " / " .. faction
end

function ns.AHMarketKey()
    local realm, faction = RealmFaction()
    if ns.AtNeutralAH() then faction = "Neutral" end
    return realm .. " / " .. faction
end

-- Neutraler Markt (fuer die Zeile "Neutral" im Tooltip), unabhaengig vom Ort
function ns.NeutralMarketKey()
    local realm = RealmFaction()
    return realm .. " / Neutral"
end

function ns.MarketKey()
    return ns.marketOverride or ns.AHMarketKey()
end

-- fn im Markt key ausfuehren (verschachtelt erlaubt). Hoechstens vier Rueckgabewerte, Fehler werden weitergereicht.
function ns.WithMarket(key, fn, ...)
    local old = ns.marketOverride
    ns.marketOverride = key
    local ok, a, b, c, d = pcall(fn, ...)
    ns.marketOverride = old
    if not ok then error(a, 0) end
    return a, b, c, d
end

function ns.WithHome(fn, ...)
    return ns.WithMarket(ns.HomeMarketKey(), fn, ...)
end

-- Gegenstandsinfos: im Forever-Client gibt es nur noch C_Item.GetItemInfo (globales GetItemInfo fehlt)
function ns.GetItemInfo(item)
    local fn = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
    if not fn or item == nil then return nil end
    local r = { pcall(fn, item) }
    if not r[1] then return nil end
    return select(2, unpack(r, 1, table.maxn(r)))
end

-- Schnittstelle fuer Peon_Ledger (ab 0.22, nur lesend): Wert eines Gegenstands wie Zeile 1 im Tooltip -
-- guenstigstes Angebot bzw. Haendlerpreis, was man in diesem Moment hoechstens bekaeme (Stand letzter Scan).
-- Rueckgabe: Kupfer fuer count Stueck oder nil (kein Wert bekannt)
function ns.ItemValue(id, count)
    if type(id) ~= "number" then return nil end
    count = (type(count) == "number" and count > 0) and count or 1
    local hp = ns.VendorPrice(id)
    local D = ns.Data
    if D and D.Lookup and D.Evaluate then
        local function Value(key, e)
            if type(e) ~= "table" or not e.m then return nil end
            local ok, v = pcall(D.Evaluate, e, key, count, hp, mod.db)
            if ok and type(v) == "table" then
                local val = v.ah and v.erl or v.hw
                if type(val) == "number" then return val end
            end
            return nil
        end
        local val = Value(id, (D.Lookup(id)))
        if val then return val end
        -- ab 0.28: Ausruestung mit Varianten - Ledger kennt nur die Nummer, also der Wert der guenstigsten Variante
        -- (vorsichtig, mit KarloDerBaer abgestimmt 06.10.2026); Varianten ohne Angebote zaehlen nicht
        if D.HasVariants and D.HasVariants(id) then
            local low
            for _, key in ipairs(D.VariantKeys(id)) do
                local e = D.Lookup(key)
                local v = type(e) == "table" and not e.gone and Value(key, e) or nil
                if v and (not low or v < low) then low = v end
            end
            if low then return low end
        end
    end
    if hp and hp > 0 then return hp * count end
    return nil
end

function ns.MarketInfo(id)
    local D = ns.Data
    if id == nil or not D or not D.Lookup then return nil end
    local e = D.Lookup(id)
    if type(e) ~= "table" or not e.m then return nil end
    local hp = ns.VendorPrice(D.ItemID(id) or id)
    local r = { min = e.m, median = e.md, qty = e.q, offers = e.n, t = e.lt and e.t and math.max(e.lt, e.t) or e.t, gone = e.gone,
        vendor = hp, commodity = D.IsCommodity(id), name = D.ItemName(id, e), quality = e.ql }
    local ok, v = pcall(D.Evaluate, e, id, 1, hp, mod.db)
    if ok and type(v) == "table" then
        r.suggest = v.vp
        if v.band then r.low, r.high, r.trend = v.band.low, v.band.high, v.band.trend end
    end
    local sr = ns.Sales and ns.Sales.Stats(e, nil, id)
    if sr then r.perHour, r.level = sr.perHour, sr.level end
    return r
end

function ns.ItemHistory(id)
    local D, S = ns.Data, ns.Sales
    local rows = {}
    if id == nil or not D or not D.Lookup then return rows end
    local e = D.Lookup(id)
    if type(e) ~= "table" then return rows end
    local byDay, byWeek = {}, {}
    local function Row(day, week)
        local map, k = week and byWeek or byDay, week or day
        local r = map[k]
        if not r then r = { day = day, week = week }; map[k] = r; rows[#rows + 1] = r end
        return r
    end
    local prev
    for _, x in ipairs(D.ParseDays(e.d)) do
        if x[5] > 0 then
            local r = Row(x[1])
            r.min, r.median, r.qty, r.scans = x[2] / x[5], x[3] / x[5], x[4] / x[5], x[5]
            local ok, b = pcall(D.Band, e, r.median, prev, x[1])
            if ok and type(b) == "table" then r.low, r.high = b.low, b.high end
            prev = r.median
        end
    end
    for _, y in ipairs(D.ParseDays(e.w)) do
        local r = Row(y[1] * 7 + 3, y[1])
        r.min, r.median, r.qty, r.days = y[2], y[3], y[4], y[5]
    end
    if S and S.ParseDays then
        for _, x in ipairs(S.ParseDays(e.ab)) do
            if x[5] >= 3600 then Row(x[1]).sales = x[2] * 86400 / x[5] end
        end
        for _, y in ipairs(S.ParseDays(e.abw)) do
            if y[5] >= 3600 then Row(y[1] * 7 + 3, y[1]).sales = y[2] * 86400 / y[5] end
        end
    end
    table.sort(rows, function(a, b) return a.day < b.day end)
    return rows
end

-- Haendlerpreis je Stueck (nil, wenn unbekannt)
function ns.VendorPrice(item)
    local price = select(11, ns.GetItemInfo(item))
    if type(price) == "number" and not Peon.IsSecret(price) then return price end
    return nil
end

-- Kupfer -> "1g 2s 3c"
function ns.Money(c)
    if type(c) ~= "number" then return "?" end
    c = math.floor(c + 0.5)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, k) end
    if s > 0 then return ("%ds %dc"):format(s, k) end
    return ("%dc"):format(k)
end

-- Geldbetrag aus Text (ab 0.19): "1g 20s 5c", "50s", "10c"; Zahl ohne Einheit = unit Kupfer (z. B. 100 = Silber)
function ns.ParseMoney(text, unit)
    if type(text) ~= "string" then return nil end
    local t = text:lower():gsub("%s+", ""):gsub(",", ".")
    if t == "" then return nil end
    local plain = tonumber(t)
    if plain then return math.max(0, math.floor(plain * (unit or 1) + 0.5)) end
    local total, found = 0, false
    for num, u in t:gmatch("(%d+%.?%d*)([gsck])") do
        local mult = (u == "g" and 10000) or (u == "s" and 100) or 1
        total = total + tonumber(num) * mult
        found = true
    end
    local rest = t:gsub("%d+%.?%d*[gsck]", "")
    if not found or rest ~= "" then return nil end
    return math.floor(total + 0.5)
end

-- Geldbetrag als Eingabetext: "1g 20s", "50s", "0c"
function ns.MoneyText(c)
    c = math.max(0, math.floor((tonumber(c) or 0) + 0.5))
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if k > 0 or #parts == 0 then parts[#parts + 1] = k .. "c" end
    return table.concat(parts, " ")
end

-- Eingabefeld fuer einen Geldbetrag (ab 0.19): get() / set(kupfer); Enter oder Verlassen uebernimmt, Escape verwirft
function ns.MoneyBox(parent, width, get, set, unit)
    local b = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    b:SetSize(width, 20)
    b:SetAutoFocus(false)
    if b.SetFontObject then b:SetFontObject("GameFontHighlightSmall") end
    b.Reset = function() b:SetText(ns.MoneyText(get())) end
    local function Apply()
        local c = ns.ParseMoney(b:GetText(), unit)
        if c then mod:Call("Geldbetrag", set, c) end
        b.Reset()
    end
    b:SetScript("OnEnterPressed", function(self) Apply(); self:ClearFocus() end)
    b:SetScript("OnEditFocusLost", function() Apply() end)
    b:SetScript("OnEscapePressed", function(self) b.Reset(); self:ClearFocus() end)
    b.Reset()
    return b
end

-- Ab 0.42 (Umbau U1): Werte fuer Ledger und Berufsfenster immer aus dem Heimatmarkt, auch am neutralen Auktionshaus
do
    local function Home(fn) return function(...) return ns.WithHome(fn, ...) end end
    ns.ItemValue = Home(ns.ItemValue)
    ns.MarketInfo = Home(ns.MarketInfo)
    ns.ItemHistory = Home(ns.ItemHistory)
    ns.MarketItems = Home(ns.MarketItems)
end

-- Minimap-Button (Kern-Baustein ab API 7): Linksklick Broker-Fenster, Rechtsklick Einstellungen
local function CreateMinimapButton()
    mod:NewMinimapButton({
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        name = "PeonBrokerMinimapButton",
        hint = L.MM_HINT,
        onClick = function(m, button)
            if button == "RightButton" then m:OpenOptions() else ns.Window.Toggle() end
        end,
        onTooltip = function(m, tt)
            tt:AddLine(L.MM_MARKET:format(ns.MarketKey()), 1, 1, 1)
            local r = m.acc and m.acc.probe
            local when = type(r) == "table" and r.time or L.MM_NEVER
            local market = ns.Data.Market()
            if market and market.lastScan then
                tt:AddLine(L.MM_SCAN:format(ns.Scan.Age(market.lastScan), market.lastItems or 0), 0.8, 0.8, 0.8)
            else
                tt:AddLine(L.MM_NO_SCAN, 0.8, 0.8, 0.8)
            end
            -- Neuerer Stand vom Peon Manager (ab 0.36)
            if market and market.mgrAt then
                local fmt = market.mgrSrc == "api" and L.MM_API or L.MM_MANAGER
                local newer = not market.lastScan or market.mgrAt > market.lastScan
                tt:AddLine(fmt:format(ns.Scan.Age(market.mgrAt), market.mgrItems or 0), newer and 0.8 or 0.6, newer and 0.8 or 0.6, newer and 0.8 or 0.6)
            end
            tt:AddLine(L.MM_PROBE:format(when), 0.6, 0.6, 0.6)
            if ns.AHPlain() then tt:AddLine(L.AH_PLAIN_TT, 1, 0.6, 0.3, true) end
        end,
        -- Texte fuer Peon_Panel
        texts = {
            -- ab 0.36: "age" = neueste Daten (Scan oder Manager), der reine Scan steht unter "scanAge"
            { key = "age", label = L.TEXT_DATA_AGE, get = function()
                local at = ns.Data.DataAt(ns.Data.Market())
                return at and ns.Scan.Age(at) or L.TEXT_NO_SCAN
            end },
            { key = "scanAge", label = L.TEXT_SCAN_AGE, get = function()
                local market = ns.Data.Market()
                return market and market.lastScan and ns.Scan.Age(market.lastScan) or L.TEXT_NO_SCAN
            end },
            { key = "offers", label = L.TEXT_SCAN_OFFERS, get = function()
                local market = ns.Data.Market()
                return market and market.lastListings and L.TEXT_OFFERS:format(Peon.ShortNumber(market.lastListings)) or L.TEXT_NO_SCAN
            end },
        },
        defaultText = "age",
    })
    mod:On("SCAN_DONE", function() if mod.launcher then mod.launcher:Refresh() end end)
end

-- ab 0.129.0: Lieferte das Spiel einen leeren Realm-Namen (gesehen 20.11.2026), lagen Daten unter "? / Fraktion".
-- Sobald der echte Name bekannt ist (Kern API 27), wandern sie zum echten Markt: Gegenstaende, die dort fehlen, kommen
-- dazu, vorhandene bleiben (sie haben den Verlauf). Dasselbe fuer die Speicher je Markt. Danach fallen die "?"-Maerkte weg.
function ns.MergeUnknownRealm()
    local acc = mod.acc
    local realm = Peon.RealmName and Peon.RealmName()
    if type(acc) ~= "table" or type(realm) ~= "string" or realm == "" then return 0 end
    local n = 0
    local function MoveTable(t, deep)
        if type(t) ~= "table" then return end
        local olds = {}
        for k in pairs(t) do if type(k) == "string" and k:match("^%? / ") then olds[#olds + 1] = k end end
        for _, k in ipairs(olds) do
            local target = realm .. " / " .. k:match("^%? / (.+)$")
            if t[target] == nil then
                t[target] = t[k]
            elseif deep and type(t[k]) == "table" and type(t[k].items) == "table" and type(t[target].items) == "table" then
                for key, e in pairs(t[k].items) do
                    if t[target].items[key] == nil then t[target].items[key] = e; n = n + 1 end
                end
            end
            t[k] = nil
            n = n + 1
        end
    end
    MoveTable(acc.markets, true)
    for _, name in ipairs({ "chancesGone", "quickMove", "quickStats", "tradeGone", "quickHide" }) do MoveTable(acc[name]) end
    if type(acc.owned) == "table" and type(acc.owned.market) == "string" and acc.owned.market:match("^%? / ") then
        acc.owned.market = realm .. " / " .. acc.owned.market:match("^%? / (.+)$")
    end
    if n > 0 then mod:Print(L.MSG_REALM_MERGED:format(realm)) end
    return n
end

-- Neuerer Stand vom Peon Manager (ab 0.36): Data.lua liest das Spiel nur beim Laden, also einmal je Login oder /reload
mod:On("LOGIN", function()
    mod:Call("Realm", ns.MergeUnknownRealm)   -- ab 0.129.0, vor allem anderen
    if (Peon.API or 0) < 18 then return end
    local n = ns.Data.ApplyManagerAll()   -- ab 0.80: Heimat und Neutral
    if n > 0 then mod:Dbg(("Stand vom Manager: %d Gegenstaende neu"):format(n)) end
    if ns.Watch then mod:Call("Beobachtung", ns.Watch.Check) end   -- ab 0.49: Preisalarm nach dem Stand vom Manager
    if mod.launcher then mod.launcher:Refresh() end
end)

mod:On("INIT", function()
    if (Peon.API or 0) < 18 then   -- ab 0.59: Fenster mit Peon.UI (Kern-API 18)
        mod:Error(L.MSG_OLD_CORE)
        return
    end
    if mod.acc.migrated then
        mod.acc.migrated = nil
        mod:Print(L.MSG_MIGRATED)
    end
    mod:AcctId()   -- ab 0.85: Kennung des Kontos fuer den Manager, gleich beim ersten Laden
    if ns.Store then mod:Call("Speicher", ns.Store.Check) end   -- ab 0.130: Groesse der Datei, verlorene Daten
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    mod:Call("Scan", ns.Scan.Init)
    mod:Call("Tooltip", ns.Tooltip.Init)
    mod:Call("Fenster", ns.Window.Init)
    mod:Call("Auktionshaus-Reiter", ns.AHTabs.Init)
    mod:Call("Anteil", ns.Cut.Init)
    mod:Call("Rat beim Verkaufen", ns.Advice.Init)
    mod:Call("Weiterverkauf", ns.Resale.Init)   -- ab 0.56
    mod:Call("Menue", ns.Menu.Init)
    mod:Call("Beobachtung", ns.Watch.Init)
    mod:Call("Auktionen", ns.AuctionsAH.Init)
    mod:Call("Haendler", ns.Vendors.Init)
    mod:Call("Meine Auktionen", ns.Auctions.Init)
    mod:Call("Einkaufsliste", ns.Buy.Init)
    mod:Call("Radar", ns.Radar.Init)
    mod:Call("Chancen", ns.Chances.Init)   -- ab 0.96
    if ns.Trade then mod:Call("Markttausch", ns.Trade.Init) end   -- ab 0.127
    if ns.Packages then mod:Call("Pakete", ns.Packages.Init) end   -- ab 0.129
    if ns.Lots then mod:Call("Posten", ns.Lots.Init) end   -- ab 0.67 (H3)
    if ns.Quick then mod:Call("Schnellkauf", ns.Quick.Init) end   -- ab 0.104
    if ns.QuickStats then mod:Call("Beobachten", ns.QuickStats.Init) end   -- ab 0.135 (U3): Sitzung am Auktionshaus
    if ns.SellVariant then mod:Call("Varianten", ns.SellVariant.Init) end   -- ab 0.98
    mod:Call("Sprung", ns.Go.InitMarket)   -- ab 0.73: sicherer Knopf Im Markt zeigen
    -- ab 0.95: Berufsfenster in Peon_Profession (Craft.lua dort)
    mod.char.vendorFlip = nil   -- Haendler-Knopf entfaellt (0.24, Feedback #8)
    -- ab 0.55 (Umbau U12, mit Zustimmung von KarloDerBaer): Behalten entfaellt, die Liste je Charakter wird geloescht,
    -- ebenso das Gedaechtnis des frueheren Reiters Verkaufen (Laufzeit und Menge je Gegenstand)
    mod.char.keep = nil
    mod.acc.sellMem = nil
    mod:Call("Minimap", CreateMinimapButton)
end)

-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9; mit älterem Kern wird nichts gemeldet)
-- ab 0.53 (Umbau U12): Bereiche nach dem neuen Aufbau
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Markt", "Verkaufen (Rat)", "Auktionen", "Einkaufen", "Radar", "Fokus", "Beobachten", "Gegenstand", "Händler", "Neutral", "Datenlage", "Berufe", "Scan", "Tooltip", "Gegenstandsmenü", "Optionen" }) end
