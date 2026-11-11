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
    defaults = {
        minimapShow  = true,
        minimapAngle = 225,
        tooltipShow  = true,    -- Preiszeilen im Tooltip
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
        dealMinVendor = 10,     -- GEW_H: Mindestgewinn Haendler-Schnaeppchen (Kupfer)
        dealMinMarket = 50,     -- GEW_M: Mindestgewinn Markt-Schnaeppchen (Silber)
        dealScans    = 10,      -- SCANS_MIN: Datenlage Markt
        dealDays     = 7,       -- TAGE
        radarMaxAge  = 60,      -- Radar: Treffer aus der Datenbank bis so viele Minuten alt (0 = unbegrenzt; ab 0.15, ersetzt dealMaxAge)
        radarSound   = true,    -- Ton bei neuen Radar-Treffern
        radarKind    = "both",  -- Radar: Haendler, AH oder beides (ab 0.17)
        radarShowExpensive = false, -- Radar: auch unbezahlbare Schnaeppchen zeigen (ab 0.17)
        dealMargin   = 20,      -- MARGE: Markt-Schnaeppchen mindestens so viel % ueber dem Kaufpreis (ab 0.17)
        dealDepth    = 20,      -- TIEFE: hoechstens so viel % aller Angebote (ab 0.17)
        dealHold     = 48,      -- Markt-Schnaeppchen: hoechstens Absatz je Std. x so viele Stunden (ab 0.26)
        radarSoundKey = "raid", -- Warnton bei neuen Treffern (ab 0.19): raid, ready, alarm, tell
        radarFlash   = 5,       -- neue Treffer: Zeile pulsiert so viele Sekunden (ab 0.19)
        radarReserve = 0,       -- Goldreserve in Gold: so viel gibt der Radar nie aus (ab 0.19)
        keepAllChars = false,   -- Reiter Behalten: Vorrat aller Charaktere aus Peon_Ledger (ab 0.22)
        salesWindow  = 6,       -- Absatz (ab 0.23.1): aktueller Absatz aus den Vergleichen der letzten Stunden
        salesMidMin  = 60,      -- Sicherheit: ab so vielen beobachteten Minuten gelbes statt rotes Zeichen
        salesSureMin = 180,     -- ab so vielen beobachteten Minuten gruenes Zeichen
        salesCancelPct = 10,    -- Einzelgegenstaende: so viel % der vorzeitig verschwundenen Angebote gelten als abgebrochen
        -- Berufsfenster (ab 0.39, KarloDerBaer 08.11.2026): Gewinn in der Rezeptliste, Block unter den Reagenzien
        craftList    = true,    -- Gewinn rechts in der Rezeptliste
        craftListWhich = "all", -- welche Rezepte: all, profit, top3, top5, top10
        craftListMode = "money",-- Betrag oder Prozent vom Material (pct)
        craftListBest = true,   -- bestes Rezept mit goldenem Strich
        craftListLoss = true,   -- Verluste zeigen (nur bei "all")
        craftListUnknown = true,-- Rezepte ohne Preis mit "?" (nur bei "all")
        craftBlock   = true,    -- Block unter den Reagenzien
        craftSummary = true,    -- Ergebniszeile Kosten, Ertrag, Gewinn
        craftColSrc  = true,    -- Spalte Quelle (Vorrat, Haendler, AH)
        craftColCost = true,    -- Spalte Kosten (Ledger oder Kaufpreis)
        craftColSell = true,    -- Spalte Erloes (Vorrat im AH verkauft, nach Gebuehr)
        craftHint    = true,    -- Hinweis: verkaufen oder herstellen
    },
    ranges   = { minimapAngle = { 0, 359, 1 }, dataDays = { 14, 90, 1 }, trendNeutral = { 1, 20, 1 },
                 trendStrong = { 10, 100, 5 }, undercutValue = { 0, 100, 1 }, undercutMassValue = { 0, 100, 1 },
                 dumpPct = { 10, 90, 5 }, dealMinVendor = { 0, 10000000, 1 },
                 dealMinMarket = { 0, 100000, 1 }, dealScans = { 1, 50, 1 }, dealDays = { 1, 14, 1 }, radarMaxAge = { 0, 240, 5 },
                 dealMargin = { 0, 100, 5 }, dealDepth = { 5, 100, 5 }, dealHold = { 6, 168, 6 }, radarFlash = { 0, 30, 1 }, radarReserve = { 0, 1000000, 1 },
                 salesWindow = { 1, 24, 1 }, salesMidMin = { 10, 600, 10 }, salesSureMin = { 20, 1440, 10 },
                 salesCancelPct = { 0, 50, 5 } },
    choices  = { undercutMode = { copper = true, percent = true }, undercutMassMode = { copper = true, percent = true },
                 duration = { [2] = true, [8] = true, [24] = true },
                 radarKind = { both = true, vendor = true, market = true },
                 craftListWhich = { all = true, profit = true, top3 = true, top5 = true, top10 = true },
                 craftListMode = { money = true, pct = true },
                 radarSoundKey = { raid = true, ready = true, alarm = true, tell = true },
                 tooltipNeutral = { always = true, shift = true, off = true },
                 windowTab = { start = true, sell = true, keep = true, auctions = true, buy = true, radar = true, prices = true,
                              market = true, watch = true, sources = true, vendors = true,
                              browse = true, focus = true, more = true } },   -- ab 0.59 (Neuaufbau N1)   -- ab 0.51 neue Reiter   -- ab 0.28 mit "start", ohne "book"
    keepOnReset = { windowPos = true, windowTab = true, keepAllChars = true, ahPlain = true },
    migrate  = function(m, acc)
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
    local realm = GetRealmName and GetRealmName() or nil
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

-- Neuerer Stand vom Peon Manager (ab 0.36): Data.lua liest das Spiel nur beim Laden, also einmal je Login oder /reload
mod:On("LOGIN", function()
    if (Peon.API or 0) < 18 then return end
    local n = ns.Data.ApplyManager()
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
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    if ns.Probe then mod:Call("Probe", ns.Probe.Init) end
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
    mod:Call("Berufe", ns.Craft.Init)
    mod.char.vendorFlip = nil   -- Haendler-Knopf entfaellt (0.24, Feedback #8)
    -- ab 0.55 (Umbau U12, mit Zustimmung von KarloDerBaer): Behalten entfaellt, die Liste je Charakter wird geloescht,
    -- ebenso das Gedaechtnis des frueheren Reiters Verkaufen (Laufzeit und Menge je Gegenstand)
    mod.char.keep = nil
    mod.acc.sellMem = nil
    mod:Call("Minimap", CreateMinimapButton)
end)

-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9; mit älterem Kern wird nichts gemeldet)
-- ab 0.53 (Umbau U12): Bereiche nach dem neuen Aufbau
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Markt", "Verkaufen (Rat)", "Auktionen", "Einkaufen", "Radar", "Fokus", "Gegenstand", "Händler", "Neutral", "Datenlage", "Berufe", "Scan", "Tooltip", "Gegenstandsmenü", "Optionen" }) end
