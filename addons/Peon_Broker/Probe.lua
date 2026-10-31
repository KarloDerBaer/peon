-- Peon_Broker - Probe.lua
-- Pruefbefehl (/broker pruefen): stellt fest, welche Auktionshaus-Funktionen der Client hat,
-- wie der Markt heisst und wie die Gebuehren aussehen. Alles nur lesend; nichts wird gekauft,
-- eingestellt oder abgebrochen. Ergebnis in PeonBrokerDB.probe, Ereignis-Zaehler in
-- PeonBrokerDB.probeEvents (bleiben ueber /reload erhalten und sind im WTF-Ordner lesbar).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Probe = P
P.ahOpen = false

-- Ereignisse, die spaeter gebraucht werden koennten. Unbekannte werden abgewiesen (pcall).
P.EVENTS = {
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
    "REPLICATE_ITEM_LIST_UPDATE", "OWNED_AUCTIONS_UPDATED",
    "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED",
    "AUCTION_HOUSE_PURCHASE_COMPLETED", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
    "COMMODITY_PRICE_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED", "UI_ERROR_MESSAGE",
    "AUCTION_HOUSE_SHOW_NOTIFICATION", "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION",
    "AUCTION_HOUSE_SHOW_ERROR", "AUCTION_HOUSE_NEW_RESULTS_RECEIVED",
    "AUCTION_ITEM_LIST_UPDATE", "AUCTION_OWNED_LIST_UPDATE", "NEW_AUCTION_UPDATE",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED",
}

-- Alte Classic-Funktionen (zum Vergleich)
P.LEGACY = {
    "QueryAuctionItems", "GetAuctionItemInfo", "GetNumAuctionItems", "CanSendAuctionQuery",
    "CalculateAuctionDeposit", "GetAuctionHouseDepositRate", "PostAuction", "CancelAuction",
    "PlaceAuctionBid", "GetOwnerAuctionItems",
}

-- Texte, an denen spaeter Verkaeufe und Post erkannt werden (fuer das Buch)
P.STRINGS = {
    "ERR_AUCTION_SOLD_S", "ERR_AUCTION_EXPIRED_S", "ERR_AUCTION_WON_S", "ERR_AUCTION_OUTBID_S",
    "ERR_AUCTION_STARTED", "ERR_AUCTION_REMOVED", "ERR_AUCTION_REMOVED_S",
    "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT",
    "AUCTION_WON_MAIL_SUBJECT", "AUCTION_OUTBID_MAIL_SUBJECT", "AUCTION_INVOICE_MAIL_SUBJECT",
}

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
-- Wert sicher als Text (geheime Werte werden nicht angefasst)
local function Str(v)
    if Peon.IsSecret(v) then return "<geheim>" end
    if type(v) == "table" then return "<table>" end
    return tostring(v)
end

-- Aufruf mit allen Rueckgabewerten; Ergebnis als Textliste oder Fehlertext
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil, "fehlt" end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil, Str(r[2]) end
    local out = {}
    for i = 2, table.maxn(r) do out[#out + 1] = Str(r[i]) end
    return out, nil, r
end

local function SortedKeys(t, filter)
    local keys = {}
    if type(t) ~= "table" then return keys end
    for k, v in pairs(t) do
        if type(k) == "string" and (not filter or filter(k, v)) then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end

local function AH() return rawget(_G, "C_AuctionHouse") end

---------------------------------------------------------------------------
-- Ereignisse mitzaehlen (nur die ersten 3 Aufrufe je Ereignis mit Werten)
---------------------------------------------------------------------------
local frame
function P.Init()
    local acc = mod.acc
    acc.probeEvents = type(acc.probeEvents) == "table" and acc.probeEvents or {}
    if frame then return end
    frame = CreateFrame("Frame")
    for _, ev in ipairs(P.EVENTS) do
        local ok = pcall(frame.RegisterEvent, frame, ev)
        local e = acc.probeEvents[ev]
        if type(e) ~= "table" then e = { count = 0, samples = {} }; acc.probeEvents[ev] = e end
        e.known = ok and true or false
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        mod:Call("Ereignis " .. event, P.OnEvent, event, ...)
    end)
end

function P.OnEvent(event, ...)
    local e = mod.acc.probeEvents[event]
    if e then
        e.count = (e.count or 0) + 1
        e.last = date("%Y-%m-%d %H:%M:%S")
        e.samples = type(e.samples) == "table" and e.samples or {}
        if #e.samples < 3 then
            local args = {}
            for i = 1, select("#", ...) do args[#args + 1] = Str((select(i, ...))) end
            e.samples[#e.samples + 1] = table.concat(args, ", ")
        end
    end
    mod:Dbg(event)
    if event == "AUCTION_HOUSE_SHOW" then
        P.ahOpen = true
    elseif event == "AUCTION_HOUSE_CLOSED" then
        P.ahOpen = false
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        P.OnReplicate()
    end
end

---------------------------------------------------------------------------
-- Gebuehren-Test mit dem ersten verkaufbaren Gegenstand in den Taschen
---------------------------------------------------------------------------
function P.FeeTest()
    local ah, C = AH(), rawget(_G, "C_Container")
    local res = {}
    if not ah or not C or not ItemLocation then res.error = "API fehlt"; return res end
    for bag = 0, 4 do
        local slots = C.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and info.itemID and not Peon.IsSecret(info.itemID) then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                local valid = Try(ah.IsSellItemValid, loc, false)
                if valid and valid[1] == "true" then
                    res.itemID = info.itemID
                    res.link = Str(info.hyperlink)
                    res.stack = info.stackCount
                    res.vendor = ns.VendorPrice(info.itemID)
                    res.name = Str(ns.GetItemInfo(info.itemID) or "?")
                    local st = Try(ah.GetItemCommodityStatus, loc)
                    res.commodityStatus = st and st[1]
                    res.isCommodity = (Enum and Enum.ItemCommodityStatus and st
                        and tonumber(st[1]) == Enum.ItemCommodityStatus.Commodity) or false
                    res.deposit = {}
                    for dur = 1, 3 do
                        local r, err
                        if res.isCommodity then
                            r, err = Try(ah.CalculateCommodityDeposit, info.itemID, dur, 1)
                        else
                            r, err = Try(ah.CalculateItemDeposit, loc, dur, 1)
                        end
                        res.deposit[dur] = r and r[1] or ("Fehler: " .. tostring(err))
                    end
                    return res
                end
            end
        end
    end
    res.none = true
    return res
end

---------------------------------------------------------------------------
-- Pruefung
---------------------------------------------------------------------------
function P.Run()
    mod:Print(L.MSG_PROBE_START)
    local r = {}
    r.time = date("%Y-%m-%d %H:%M:%S")
    r.version, r.peon, r.peonAPI = mod.version, Peon.version, Peon.API
    local b = Try(GetBuildInfo) or {}
    r.build = { version = b[1], build = b[2], date = b[3], interface = b[4] }
    r.locale = GetLocale()

    -- Markt
    r.realm = Str(GetRealmName and GetRealmName())
    r.realmNormalized = GetNormalizedRealmName and Str(GetNormalizedRealmName()) or "fehlt"
    local f = Try(UnitFactionGroup, "player") or {}
    r.faction, r.factionLocal = f[1], f[2]
    r.unitName = Try(UnitName, "player")
    r.unitFullName = Try(UnitFullName, "player")
    r.market = ns.MarketKey()
    -- Hinweise auf Regelsaetze (Namen im globalen Bereich)
    r.rulesetNames = SortedKeys(_G, function(k) return k:find("[Rr]uleset") ~= nil or k:find("^C_Forever") ~= nil end)

    -- Auktionshaus-Schnittstelle
    local ah = AH()
    r.api = SortedKeys(ah, function(_, v) return type(v) == "function" end)
    r.legacy = {}
    for _, name in ipairs(P.LEGACY) do r.legacy[name] = type(rawget(_G, name)) == "function" end
    r.frames = {
        AuctionHouseFrame = rawget(_G, "AuctionHouseFrame") ~= nil,
        AuctionFrame = rawget(_G, "AuctionFrame") ~= nil,
        Blizzard_AuctionHouseUI = Peon.IsAddOnLoaded("Blizzard_AuctionHouseUI") and true or false,
        Blizzard_AuctionUI = Peon.IsAddOnLoaded("Blizzard_AuctionUI") and true or false,
    }
    r.enums = {}
    if type(Enum) == "table" then
        for _, name in ipairs(SortedKeys(Enum, function(k) return k:find("Auction") or k:find("Commodity") end)) do
            local vals = {}
            for _, k in ipairs(SortedKeys(Enum[name])) do vals[#vals + 1] = k .. "=" .. Str(Enum[name][k]) end
            r.enums[name] = table.concat(vals, ", ")
        end
    end
    r.strings = {}
    for _, name in ipairs(P.STRINGS) do
        local v = rawget(_G, name)
        if type(v) == "string" then r.strings[name] = v end
    end

    -- Nur bei geoeffnetem Auktionshaus
    r.ahOpen = P.ahOpen
    if P.ahOpen and ah then
        r.live = {}
        r.live.throttleReady = Try(ah.IsThrottledMessageSystemReady)
        r.live.numReplicate = Try(ah.GetNumReplicateItems)
        local ok, fee = pcall(P.FeeTest)
        r.live.fee = ok and fee or { error = Str(fee) }
    end

    -- vorherigen Scan-Test behalten
    local old = mod.acc.probe
    if type(old) == "table" and old.scan then r.scan = old.scan end
    mod.acc.probe = r
    P.Report(r)
    if mod.page then mod.page:Refresh() end
    return r
end

-- Kurze Zusammenfassung (Chat und Optionsseite)
function P.AHText(r)
    if #r.api > 0 then return L.AH_MODERN:format(#r.api) end
    if r.legacy and r.legacy.QueryAuctionItems then return L.AH_LEGACY end
    return L.AH_NONE
end

function P.FeeText(r)
    local fee = r.live and r.live.fee
    if not fee then return L.NOT_TESTED end
    if fee.none or fee.error then return fee.error or "-" end
    local parts = {}
    for dur = 1, 3 do parts[#parts + 1] = ns.Money(tonumber(fee.deposit[dur])) end
    return ("%s: %s"):format(fee.name or "?", table.concat(parts, " / "))
end

function P.Report(r)
    mod:Print(L.MSG_MARKET:format(r.market))
    mod:Print(L.MSG_CLIENT:format(Str(r.build.version), Str(r.build.build), Str(r.build.interface)))
    mod:Print(L.MSG_AH:format(P.AHText(r)))
    if not r.ahOpen then
        mod:Print(L.MSG_AH_CLOSED)
    elseif r.live and r.live.fee then
        local fee = r.live.fee
        if fee.none then
            mod:Print(L.MSG_FEE_NONE)
        elseif fee.error then
            mod:Print(L.MSG_FEE_ERROR:format(fee.error))
        else
            local parts = {}
            for dur = 1, 3 do parts[#parts + 1] = ns.Money(tonumber(fee.deposit[dur])) end
            mod:Print(L.MSG_FEE:format(fee.link or fee.name or "?", ns.Money(fee.vendor), table.concat(parts, " / ")))
        end
    end
    mod:Print(L.MSG_SAVED)
end

---------------------------------------------------------------------------
-- Komplettscan-Test (/broker pruefen scan): einmal anfordern, Anzahl und Dauer messen,
-- die ersten drei Eintraege roh speichern. Alle 15 Minuten moeglich.
---------------------------------------------------------------------------
P.SCAN_TIMEOUT = 90

function P.ScanTest()
    local ah = AH()
    if not P.ahOpen then mod:Print(L.MSG_SCAN_NEED_AH); return end
    if not ah or type(ah.ReplicateItems) ~= "function" then mod:Print(L.MSG_SCAN_NO_API); return end
    local probe = type(mod.acc.probe) == "table" and mod.acc.probe or {}
    mod.acc.probe = probe
    local scan = { started = date("%Y-%m-%d %H:%M:%S"), t0 = GetTime(), updates = 0 }
    probe.scan = scan
    P.scanning = scan
    local ok, err = pcall(ah.ReplicateItems)
    if not ok then
        scan.error = Str(err)
        P.scanning = nil
        mod:Print(L.MSG_SCAN_ERROR:format(scan.error))
        return
    end
    mod:Print(L.MSG_SCAN_START)
    if C_Timer and C_Timer.After then
        C_Timer.After(P.SCAN_TIMEOUT, function()
            if P.scanning == scan and scan.updates == 0 then
                P.scanning = nil
                scan.timeout = true
                mod:Print(L.MSG_SCAN_NONE:format(P.SCAN_TIMEOUT))
            end
        end)
    end
end

function P.OnReplicate()
    local scan = P.scanning
    if not scan then return end
    local ah = AH()
    scan.updates = scan.updates + 1
    local n = Try(ah.GetNumReplicateItems)
    scan.count = n and tonumber(n[1]) or nil
    scan.seconds = math.floor((GetTime() - scan.t0) + 0.5)
    scan.samples = {}
    for i = 0, 2 do
        local vals = Try(ah.GetReplicateItemInfo, i)
        -- ab 0.22.1: Restzeit je Angebot (eigene Funktion, Stufe 0-3: 30 Min., 2 Std., 12 Std., 2 Tage)
        local left = Try(ah.GetReplicateItemTimeLeft, i)
        if vals then scan.samples[#scan.samples + 1] = table.concat(vals, " | ") .. " || Restzeit " .. (left and table.concat(left, " | ") or "fehlt") end
    end
    -- Verteilung der Restzeit-Stufen ueber alle Angebote (zeigt, ob die Funktion echte Werte liefert)
    if type(ah.GetReplicateItemTimeLeft) == "function" and scan.count then
        local bands = {}
        for i = 0, scan.count - 1 do
            local ok, b = pcall(ah.GetReplicateItemTimeLeft, i)
            local k = ok and tostring(b) or "Fehler"
            bands[k] = (bands[k] or 0) + 1
        end
        scan.timeLeftBands = bands
    end
    if scan.updates == 1 then
        mod:Print(L.MSG_SCAN_DONE:format(scan.count or 0, scan.seconds))
    end
    if mod.page then mod.page:Refresh() end
end

---------------------------------------------------------------------------
-- Abfrage-Test (/broker pruefen abfrage, ab 0.14.3): In welchem Zusammenhang schickt das Spiel eine
-- Live-Abfrage (SendSearchQuery) wirklich ab? Anlass: der Radar-Scan (aus C_Timer) bekam keine Antworten,
-- "Liste durchsuchen" (Klick, danach aus dem Ergebnis-Ereignis) schon.
--   1. direkt im Befehl   2. im Ergebnis-Ereignis   3. aus C_Timer   4. aus OnUpdate
--   5. ueber die Radar-Funktion (gleicher Gegenstand)   6. ueber die Radar-Funktion (Gegenstand der Einkaufsliste) (ab 0.14.4)
-- Ergebnis im Chat und in PeonBrokerDB.queryTest.
---------------------------------------------------------------------------
P.QT_WAIT = 2.5
local qt

local function QTSend(label, radarKey)
    local ah = AH()
    local step = { label = label, t = GetTime(), sent = false, answered = false, itemID = qt.itemKey.itemID }
    step.ready = ah.IsThrottledMessageSystemReady and ah.IsThrottledMessageSystemReady() or nil
    qt.steps[#qt.steps + 1] = step
    qt.cur = step
    local ok, err
    if radarKey ~= nil then
        step.itemID = ns.Buy.ItemKeyFor(radarKey).itemID
        ok, err = pcall(ns.Radar.Send, radarKey)
        if ok and err == false then ok, err = false, "Send" end
    else
        local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
        ok, err = pcall(ah.SendSearchQuery, qt.itemKey, { { sortOrder = order, reverseSort = false } }, true)
    end
    step.ok = ok
    if not ok then step.err = tostring(err) end
    local my = step
    C_Timer.After(P.QT_WAIT, function() if qt and qt.cur == my then qt.cur = nil; P.QTNext(my) end end)
end

-- Naechster Schritt nach Antwort oder Zeitablauf
function P.QTNext(done)
    if not qt then return end
    local n = #qt.steps
    if n == 1 then
        if done.answered and qt.inEvent then QTSend("Ereignis")          -- wir sind im Ergebnis-Ereignis
        else qt.steps[#qt.steps + 1] = { label = "Ereignis", skipped = true }; P.QTNext({}) end
    elseif n == 2 then
        C_Timer.After(1, function() QTSend("Timer") end)
    elseif n == 3 then
        C_Timer.After(1, function()
            qt.frame:SetScript("OnUpdate", function(self)
                self:SetScript("OnUpdate", nil)
                QTSend("OnUpdate")
            end)
        end)
    elseif n == 4 then
        C_Timer.After(1, function() QTSend("Radar", qt.key) end)
    elseif n == 5 then
        local listKey
        for _, list in ipairs(ns.Buy.Lists()) do for k in pairs(list.items) do listKey = listKey or k end end
        if listKey ~= nil then
            C_Timer.After(1, function() QTSend("Radar " .. tostring(listKey), listKey) end)
        else
            qt.steps[#qt.steps + 1] = { label = "Radar Liste", skipped = true }; P.QTNext({})
        end
    else
        P.QTReport()
    end
end

function P.QTReport()
    local out = {}
    for _, s in ipairs(qt.steps) do
        local line
        if s.skipped then
            line = L.QTEST_SKIPPED:format(s.label)
        else
            line = L.QTEST_LINE:format(s.label, s.sent and L.YES or L.NO, s.answered and L.YES or L.NO,
                s.answerTime or 0, tostring(s.ready), s.ok and "ok" or ("Fehler " .. tostring(s.err)))
        end
        out[#out + 1] = line
        mod:Print(line)
    end
    mod.acc.queryTest = { t = date("%Y-%m-%d %H:%M:%S"), item = qt.key, lines = out }
    mod:Print(L.MSG_SAVED)
    qt.frame:UnregisterAllEvents()
    qt = nil
end

function P.QueryTest()
    local ah = AH()
    if not (ns.Scan.ahOpen and ah and ah.SendSearchQuery) then mod:Print(L.QTEST_NEED_AH); return end
    if qt then return end
    -- Massenware mit den meisten Angeboten aus dem letzten Scan
    local market = ns.Data.Market()
    local best, bestQ
    for k, e in pairs(market and market.items or {}) do
        if type(k) == "number" and type(e) == "table" and not e.gone and (e.q or 0) > (bestQ or 0) and ns.Data.IsCommodity(k) then
            best, bestQ = k, e.q
        end
    end
    if not best then mod:Print(L.QTEST_NEED_AH); return end
    qt = { steps = {}, key = best, itemKey = ns.Buy.ItemKeyFor(best) }
    qt.frame = qt.frame or CreateFrame("Frame")
    pcall(qt.frame.RegisterEvent, qt.frame, "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    pcall(qt.frame.RegisterEvent, qt.frame, "COMMODITY_SEARCH_RESULTS_UPDATED")
    pcall(qt.frame.RegisterEvent, qt.frame, "ITEM_SEARCH_RESULTS_UPDATED")
    qt.frame:SetScript("OnEvent", function(_, event, arg)
        local s = qt and qt.cur
        if not s then return end
        if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT" then
            s.sent = true
        elseif arg == s.itemID or (type(arg) == "table" and arg.itemID == s.itemID) then
            s.answered = true
            s.answerTime = GetTime() - s.t
            qt.cur = nil
            qt.inEvent = true
            mod:Call("Abfrage-Test", P.QTNext, s)
            if qt then qt.inEvent = false end
        end
    end)
    mod:Print(L.QTEST_START:format(ns.Data.ItemName(best, market.items[best]) or tostring(best)))
    QTSend("Befehl")
end

---------------------------------------------------------------------------
-- Felder der Suchergebnisse (ab 0.22, Vorbereitung Absatzquote): laeuft automatisch mit, sobald Broker
-- Ergebnisse liest (Verkaufen, Radar, Einkaufsliste). Je Art (Massenware/Einzelgegenstand) werden die
-- vorhandenen Felder gezaehlt und die ersten Beispiele gespeichert: PeonBrokerDB.fieldProbe.
-- Wichtig fuer die Absatzquote: auctionID (Auktionsnummer), timeLeftSeconds/timeLeft (Restzeit), owners.
---------------------------------------------------------------------------
P.FIELD_SAMPLES = 5
P.FIELD_MAX = 500
P.FIELD_KEYS = { "auctionID", "timeLeftSeconds", "timeLeft", "owners", "totalNumberOfOwners", "quantity",
    "unitPrice", "buyoutAmount", "bidAmount", "containsOwnerItem", "numOwnerItems", "containsAccountItem" }

local function FieldText(v)
    if Peon.IsSecret(v) then return "<geheim>" end
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do
            parts[#parts + 1] = tostring(k) .. "=" .. ((type(x) == "table") and "<table>" or (Peon.IsSecret(x) and "<geheim>" or tostring(x)))
            if #parts >= 4 then break end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return tostring(v)
end

function P.Field(kind, r)
    if type(r) ~= "table" then return end
    local acc = mod.acc
    if type(acc) ~= "table" then return end
    if type(acc.fieldProbe) ~= "table" then acc.fieldProbe = {} end
    local f = acc.fieldProbe[kind]
    if type(f) ~= "table" then f = { count = 0, keys = {}, samples = {} }; acc.fieldProbe[kind] = f end
    if (f.count or 0) >= P.FIELD_MAX then return end   -- genug gesehen: kein Aufwand mehr
    f.count = (f.count or 0) + 1
    f.last = date("%Y-%m-%d %H:%M:%S")
    for k in pairs(r) do if type(k) == "string" then f.keys[k] = (f.keys[k] or 0) + 1 end end
    if #f.samples < P.FIELD_SAMPLES then
        local parts = {}
        for _, k in ipairs(SortedKeys(r)) do parts[#parts + 1] = k .. "=" .. FieldText(r[k]) end
        f.samples[#f.samples + 1] = table.concat(parts, " | ")
    end
end

-- /broker pruefen auktionen: was ist bisher gesehen worden?
function P.FieldReport()
    local fp = mod.acc and mod.acc.fieldProbe
    local any = false
    for _, kind in ipairs({ "commodity", "item" }) do
        local f = type(fp) == "table" and fp[kind]
        if type(f) == "table" and (f.count or 0) > 0 then
            any = true
            local have, miss = {}, {}
            for _, k in ipairs(P.FIELD_KEYS) do
                if f.keys[k] then have[#have + 1] = k else miss[#miss + 1] = k end
            end
            mod:Print(L.FIELD_KIND:format(L["FIELD_" .. kind:upper()], f.count))
            mod:Print(L.FIELD_HAVE:format(#have > 0 and table.concat(have, ", ") or "–"))
            if #miss > 0 then mod:Print(L.FIELD_MISS:format(table.concat(miss, ", "))) end
        end
    end
    if not any then mod:Print(L.FIELD_NONE) end
end
