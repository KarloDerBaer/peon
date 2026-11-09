-- Peon_Broker - Auctions.lua
-- Eigene Auktionen lesen und bewerten (guenstigster / gleichauf / unterboten / verkauft) und live pruefen.
-- Bis 0.54 auch der Reiter "Meine Auktionen". Ab 0.55 (Umbau U12) nur noch die Bausteine: die Anzeige steht in
-- Blizzards Reiter "Auktionen" (AuctionsAH.lua), Abbrechen und neu einstellen bleiben Blizzards Knoepfe.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local A = {}
ns.Auctions = A

A.LIVE_WAIT = 4          -- Sekunden je Live-Abfrage, dann naechster Gegenstand
A.RANK = { under = 1, equal = 2, best = 3, sold = 4 }

local GREY, ORANGE, GREEN, YELLOW = "|cff999999", "|cffff9933", "|cff60e060", "|cffffd100"
local function Money(v) return ns.Tooltip.Money(v) end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Eigene Auktionen lesen
---------------------------------------------------------------------------
function A.Query()
    local ah = AHApi()
    if not AHOpen() or not ah.QueryOwnedAuctions then return false end
    local ok = pcall(ah.QueryOwnedAuctions, {})
    mod:Dbg("Eigene Auktionen abgefragt: " .. tostring(ok))
    return ok
end

function A.Read()
    local ah = AHApi()
    local rows = {}
    local ok, n = pcall(ah.GetNumOwnedAuctions)
    for i = 1, (ok and tonumber(n) or 0) do
        local okr, r = pcall(ah.GetOwnedAuctionInfo, i)
        if okr and type(r) == "table" and r.auctionID then
            local link = r.itemLink
            local key = ns.Data.KeyFromLink(link)
            if key == nil and type(r.itemKey) == "table" then key = r.itemKey.itemID end
            local id = ns.Data.ItemID(key)
            if ns.Buy and ns.Buy.LearnKey then ns.Buy.LearnKey(key, r.itemKey) end   -- ab 0.28: Schluessel je Variante
            local name = type(link) == "string" and link:match("%[(.-)%]") or ns.Data.ItemName(key, ns.Data.Lookup(key)) or tostring(key)
            rows[#rows + 1] = {
                id = r.auctionID, key = key, itemID = id, itemKey = r.itemKey, link = link, name = name,
                qty = Num(r.quantity) and r.quantity or 1,
                price = Num(r.buyoutAmount) and r.buyoutAmount or nil,
                sold = r.status == 1,
                left = r.timeLeftSeconds, band = r.timeLeft,
            }
        end
    end
    A.rows = rows
    A.readAt = time()
    mod.acc.owned = { market = ns.MarketKey(), t = A.readAt, rows = rows }
    A.Evaluate()
    return rows
end

-- Qualitaet aus der Farbe des Links (fuer die Namensfarbe)
local QUALITY_BY_COLOR = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5 }
local function QualityFromLink(link)
    if type(link) ~= "string" then return nil end
    -- Forever (Pruefung Ledger 02.10.2026): Links beginnen mit "|cnIQ<Qualitaet>:" statt einer Farbe
    local q = link:match("|cnIQ(%d+):")
    if q then return tonumber(q) end
    local c = link:match("|c%x%x(%x%x%x%x%x%x)")
    return c and QUALITY_BY_COLOR[c:lower()] or nil
end

---------------------------------------------------------------------------
-- Status: Vergleich mit dem guenstigsten Angebot anderer Verkaeufer
---------------------------------------------------------------------------
-- live[key] = { min = guenstigstes anderer Verkaeufer oder nil, t = Zeit }
A.live = {}

function A.Evaluate()
    for _, r in ipairs(A.rows or {}) do
        r.quality = r.quality or QualityFromLink(r.link)
        r.icon = r.icon or A.Icon(r.itemID)
        local lv = A.live[r.key]
        local other, source
        if lv then
            other, source = lv.min, "live"
        else
            local e = ns.Data.Lookup(r.key)
            if type(e) == "table" and e.m and not e.gone then other, source = e.m, "scan" end
        end
        r.other, r.source = other, source
        if r.sold then
            r.status = "sold"
        elseif not r.price or not other then
            r.status = "best"
        elseif other < r.price then
            r.status = "under"
        elseif other == r.price then
            -- live: ein anderer Verkaeufer hat denselben Preis; Scan: der Preis kann auch der eigene sein
            r.status = source == "live" and "equal" or "best"
        else
            r.status = "best"
        end
        r.rank = A.RANK[r.status]
    end
end

function A.Icon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local ok, i = pcall(C_Item.GetItemIconByID, itemID)
        if ok and i then return i end
    end
    return nil
end

---------------------------------------------------------------------------
-- Live pruefen: je Gegenstand eine Suche, nacheinander
---------------------------------------------------------------------------
function A.StartLive()
    if not AHOpen() or A.liveRun then return end
    local seen, queue = {}, {}
    for _, r in ipairs(A.rows or {}) do
        if not r.sold and r.key ~= nil and not seen[r.key] then
            seen[r.key] = true
            queue[#queue + 1] = r
        end
    end
    if #queue == 0 then return end
    A.liveRun = { queue = queue, index = 0, done = 0 }
    A.NextLive()
end

function A.NextLive()
    local run = A.liveRun
    if not run then return end
    run.index = run.index + 1
    local r = run.queue[run.index]
    if not r or not AHOpen() then
        A.liveRun = nil
        A.liveAt = time()
        A.Evaluate()
        A.Changed()
        return
    end
    local ah = AHApi()
    if ah.IsThrottledMessageSystemReady and not ah.IsThrottledMessageSystemReady() then
        run.index = run.index - 1
        if C_Timer then C_Timer.After(0.5, A.NextLive) end
        return
    end
    -- Schluessel wie beim Verkaufen: der des Gegenstands (itemKey aus der Auktion)
    local itemKey = type(r.itemKey) == "table" and r.itemKey or { itemID = r.itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    local send = ah.SendSearchQuery or ah.SendSellSearchQuery
    run.pending = { key = r.key, itemID = r.itemID, itemKey = itemKey }
    local ok = send and pcall(send, itemKey, { { sortOrder = order, reverseSort = false } }, true)
    mod:Dbg(("Meine Auktionen: Live %s gesendet %s"):format(tostring(r.key), tostring(ok)))
    A.Changed()
    local p = run.pending
    if C_Timer then
        C_Timer.After(A.LIVE_WAIT, function()
            if A.liveRun == run and run.pending == p then run.pending = nil; A.NextLive() end
        end)
    end
end

-- Ergebnisse lesen; bei Einzelgegenstaenden unter dem Schluessel des Ereignisses, sonst dem der Auktion (ab 0.20.2)
local function ReadRows(commodity, itemID, arg, itemKey, key)
    if commodity then return ns.Live.ReadCommodity(itemID) end
    local rows = ns.Live.ReadItems(type(arg) == "table" and arg or itemKey, key)   -- ab 0.28 nach Variante gefiltert
    if #rows == 0 and type(itemKey) == "table" and itemKey ~= arg then
        local other = ns.Live.ReadItems(itemKey, key)
        if #other > 0 then rows = other end
    end
    return rows
end

-- Protokoll zur Fehlersuche (ab 0.20.2): PeonBrokerDB.aucLog, die letzten 30 Ergebnisse
local function Log(kind, key, arg, rows)
    if not mod:IsDebug() then return end   -- ab 0.28 nur mit /broker debug
    local acc = mod.acc
    if type(acc.aucLog) ~= "table" then acc.aucLog = {} end
    local l = acc.aucLog
    l[#l + 1] = ("%s %s %s Schluessel %s: %d Stufen%s, guenstigster anderer %s"):format(date and date("%H:%M:%S") or "", kind, tostring(key),
        type(arg) == "table" and ns.Live.KeyText(arg) or tostring(arg), #rows, rows.partial and " (Teil)" or "", tostring((ns.Data.LiveValues(rows))))
    while #l > 30 do table.remove(l, 1) end
end

-- Ergebnis uebernehmen; ohne Angebote anderer Verkaeufer im Ergebnis, aber mit Angeboten im Scan, gilt der Scan
-- (ein leeres Ergebnis kann auch "noch nicht geladen" heissen)
local function Store(key, rows)
    if key ~= nil and #rows > 0 then ns.Data.ApplyLive(key, rows, time()) end   -- ab 0.28 auch Varianten (gefiltert)
    local min = ns.Data.LiveValues(rows)
    if #rows == 0 then A.live[key] = nil else A.live[key] = { min = min, t = time() } end
end

local function OnResults(commodity, arg)
    local run = A.liveRun
    local p = run and run.pending
    if not p then return end
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    if id ~= p.itemID then return end
    local rows = ReadRows(commodity, p.itemID, arg, p.itemKey, p.key)
    if #rows == 0 and (rows.partial or rows.foreign) then return end   -- Spiel laedt noch (ab 0.20.1)
    run.pending = nil
    Log("Live", p.key, arg, rows)
    Store(p.key, rows)   -- ab 0.15 in die Datenbank
    run.done = run.done + 1
    A.Evaluate()
    A.NextLive()
end


-- Anzeige auffrischen (Blizzards Reiter Auktionen, AuctionsAH.lua)
function A.Changed()
    if ns.AuctionsAH and ns.AuctionsAH.Update then mod:Call("Auktionen", ns.AuctionsAH.Update) end
end

function A.Init()
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) OnResults(true, itemID) end)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) OnResults(false, itemKey) end)
    pcall(mod.RegisterEvent, mod, "COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID) OnResults(true, itemID) end)
    pcall(mod.RegisterEvent, mod, "ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey) OnResults(false, itemKey) end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() A.liveRun = nil end)
end
