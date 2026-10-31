-- Peon_Broker - Auctions.lua
-- Reiter "Meine Auktionen" (Bauabschnitt 6, mit KarloDerBaer abgestimmt 30.09.2026):
-- eigene Auktionen mit Status (guenstigster / gleichauf / unterboten / verkauft), guenstigstes Angebot
-- anderer Verkaeufer (letzter Scan oder "Live pruefen"), Restzeit; Abbrechen mit Kosten, "Naechste
-- unterbotene" (je Klick eine), "Neu einstellen" (springt zu Verkaufen). Abbruch nur per Klick.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

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

local function TimeLeftText(sec, band)
    if Num(sec) then
        if sec >= 3600 then return L.AUC_HOURS:format(math.floor(sec / 3600 + 0.5)) end
        return L.AUC_MINUTES:format(math.max(1, math.floor(sec / 60)))
    end
    return L["AUC_BAND_" .. tostring(band)] or ""
end

-- Liste aus dem Spiel lesen und im Zwischenspeicher je Markt ablegen (Anzeige auch ohne Auktionshaus)
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
        A.UpdateView()
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
    A.UpdateView()
    local p = run.pending
    if C_Timer then
        C_Timer.After(A.LIVE_WAIT, function()
            if A.liveRun == run and run.pending == p then run.pending = nil; A.NextLive() end
        end)
    end
end

-- Ergebnisse lesen; bei Einzelgegenstaenden unter dem Schluessel des Ereignisses, sonst dem der Auktion (ab 0.20.2)
local function ReadRows(commodity, itemID, arg, itemKey, key)
    if commodity then return ns.Sell.ReadCommodity(itemID) end
    local rows = ns.Sell.ReadItems(type(arg) == "table" and arg or itemKey, key)   -- ab 0.28 nach Variante gefiltert
    if #rows == 0 and type(itemKey) == "table" and itemKey ~= arg then
        local other = ns.Sell.ReadItems(itemKey, key)
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
        type(arg) == "table" and ns.Sell.KeyText(arg) or tostring(arg), #rows, rows.partial and " (Teil)" or "", tostring((ns.Data.LiveValues(rows))))
    while #l > 30 do table.remove(l, 1) end
end

-- Ergebnis uebernehmen; ohne Angebote anderer Verkaeufer im Ergebnis, aber mit Angeboten im Scan, gilt der Scan
-- (ein leeres Ergebnis kann auch "noch nicht geladen" heissen)
local function Store(key, rows)
    if key ~= nil and #rows > 0 then ns.Data.ApplyLive(key, rows, time()) end   -- ab 0.28 auch Varianten (gefiltert)
    local min = ns.Data.LiveValues(rows)
    if #rows == 0 then A.live[key] = nil else A.live[key] = { min = min, t = time() } end
end

-- Angeklickte Auktion (ab 0.20): Blizzard zeigt die aktuellen Angebote; deren Ergebnis nutzt Broker gleich mit
local function OnWatchResults(commodity, arg)
    local w = A.watch
    local id = commodity and arg or (type(arg) == "table" and arg.itemID)
    if not w or id ~= w.itemID then return end
    local rows = ReadRows(commodity, w.itemID, arg, w.itemKey, w.key)
    if #rows == 0 and (rows.partial or rows.foreign) then return end   -- Spiel laedt noch (ab 0.20.1)
    A.watch = nil
    Log("Klick", w.key, arg, rows)
    Store(w.key, rows)
    A.Evaluate()
    A.UpdateView()
end

local function OnResults(commodity, arg)
    local run = A.liveRun
    local p = run and run.pending
    if not p then OnWatchResults(commodity, arg); return end
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

---------------------------------------------------------------------------
-- Abbrechen
---------------------------------------------------------------------------
function A.CancelCost(r)
    local ah = AHApi()
    if not r or not AHOpen() or not ah.GetCancelCost then return nil end
    local ok, c = pcall(ah.GetCancelCost, r.id)
    if ok and Num(c) then return c end
    return nil
end

function A.CanCancel(r)
    if not r or r.sold or not AHOpen() or A.busy then return false end
    local ah = AHApi()
    if ah.CanCancelAuction then
        local ok, can = pcall(ah.CanCancelAuction, r.id)
        if ok and can == false then return false end
    end
    return true
end

function A.Cancel(r)
    if not A.CanCancel(r) then return false end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return false end
    local ah = AHApi()
    local cost = A.CancelCost(r)
    local ok = pcall(ah.CancelAuction, r.id)
    if not ok then mod:Print(L.AUC_CANCEL_FAILED); return false end
    A.busy = { row = r, cost = cost, t = time() }
    A.UpdateView()
    if C_Timer then
        local job = A.busy
        C_Timer.After(10, function() if A.busy == job then A.busy = nil; A.UpdateView() end end)
    end
    return true
end

function A.OnCanceled()
    local job = A.busy
    if not job then A.Query(); return end
    A.busy = nil
    local r = job.row
    mod:Print(L.AUC_CANCELED:format(r.qty, r.name, job.cost and Money(job.cost) or "?"))
    A.lastCancelled, A.lastCancelledName = r.key, r.name
    A.Query()
end

-- Mit jedem Klick die naechste unterbotene Auktion abbrechen
function A.CancelNextUnder()
    for _, r in ipairs(A.list:GetItems()) do
        if r.status == "under" then
            A.list:Select(r)
            A.selected = r
            return A.Cancel(r)
        end
    end
    mod:Print(L.AUC_NONE_UNDER)
    return false
end

-- Neu einstellen: zu "Verkaufen", Gegenstand waehlen (kommt nach dem Abbruch per Post zurueck)
function A.Repost(r)
    r = r or A.selected
    local key = r and r.key or A.lastCancelled
    if key == nil then return end
    W.Select("sell")
    for _, it in ipairs(ns.Sell.ScanBags()) do
        if it.key == key then ns.Sell.Select(it); return end
    end
    mod:Print(L.AUC_NOT_IN_BAGS:format(r and r.name or A.lastCancelledName or tostring(key)))
end

---------------------------------------------------------------------------
-- Auswahl (ab 0.20, Wunsch von KarloDerBaer): Klick zeigt die aktuellen Angebote des Gegenstands im Blizzard-Fenster
---------------------------------------------------------------------------
function A.SelectRow(r)
    A.selected = r
    if r and AHOpen() and not r.sold and r.key ~= nil then
        -- auch wenn das Zeigen erst spaeter klappt (Daten laden / Spiel nicht bereit): Ergebnis mitnehmen
        A.watch = { key = r.key, itemID = r.itemID, itemKey = r.itemKey }
        ns.Buy.ShowInAH({ key = r.key, itemKey = type(r.itemKey) == "table" and r.itemKey or nil, offer = r.other or r.price,
                          qty = r.qty, own = true })
    end
    A.UpdateView()
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function A.Refresh()
    if not A.list then return end
    if AHOpen() then
        A.Query()
    else
        -- ohne Auktionshaus: zuletzt gelesener Stand dieses Markts
        local c = mod.acc.owned
        if type(c) == "table" and c.market == ns.MarketKey() and type(c.rows) == "table" then
            A.rows, A.readAt = c.rows, c.t
            A.Evaluate()
        else
            A.rows = {}
        end
    end
    A.UpdateView()
end

function A.OnOwnedUpdated()
    if not A.list then return end
    A.Read()
    -- Reiter gerade geoeffnet (ab 0.24, Feedback #4): nach dem Neuladen gleich alle live pruefen
    if A.autoLive and AHOpen() and W.current == "auctions" then
        A.autoLive = nil
        A.StartLive()
    end
    A.UpdateView()
end

function A.UpdateView()
    if not A.list then return end
    A.list:SetData(A.rows or {})
    local sel
    if A.selected then
        for _, r in ipairs(A.rows or {}) do if r.id == A.selected.id then sel = r end end
    end
    A.selected = sel
    if sel then A.list:Select(sel) end
    -- Stand
    local st
    if A.liveRun then
        st = L.AUC_LIVE_RUN:format(A.liveRun.index, #A.liveRun.queue)
    elseif A.liveAt then
        st = L.AUC_LIVE_AGE:format(ns.Scan.Age(A.liveAt))
    else
        local market = ns.Data.Market()
        st = (market and market.lastScan) and L.AUC_SCAN_AGE:format(ns.Scan.Age(market.lastScan)) or L.MM_NO_SCAN
    end
    if not AHOpen() then st = st .. "   " .. ORANGE .. L.AUC_NEED_AH .. "|r" end
    A.status:SetText(GREY .. st .. "|r")
    if AHOpen() and not A.liveRun and #(A.rows or {}) > 0 then A.liveButton:Enable() else A.liveButton:Disable() end
    -- Auswahl
    local under = 0
    for _, r in ipairs(A.rows or {}) do if r.status == "under" then under = under + 1 end end
    if sel then
        local cost = A.CancelCost(sel)
        local text = W.Colored(sel.name, sel.quality)
        if sel.sold then text = text .. "  " .. GREY .. L.AUC_SOLD_HINT .. "|r"
        elseif cost then text = text .. "  " .. GREY .. L.AUC_COST:format(Money(cost)) .. "|r" end
        A.selText:SetText(text)
    else
        A.selText:SetText(GREY .. L.AUC_PICK .. "|r")
    end
    if sel and A.CanCancel(sel) then A.cancelButton:Enable() else A.cancelButton:Disable() end
    if (sel or A.lastCancelled) then A.repostButton:Enable() else A.repostButton:Disable() end
    if under > 0 and AHOpen() and not A.busy then A.nextButton:Enable() else A.nextButton:Disable() end
    A.nextButton:SetText(L.AUC_NEXT_UNDER:format(under))
end

local STATUS_TEXT = { under = "AUC_ST_UNDER", equal = "AUC_ST_EQUAL", best = "AUC_ST_BEST", sold = "AUC_ST_SOLD" }
local STATUS_COLOR = { under = ORANGE, equal = YELLOW, best = GREEN, sold = GREY }

function A.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    local fixed = 50 + 86 + 86 + 90 + 64
    A.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = total - fixed,
              format = function(v, r)
                  return "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(v, r.quality)
              end,
              sortValue = function(r) return W.Lower(r.name) end },
            { key = "qty", title = L.AUC_COL_QTY, width = 50, align = "RIGHT" },
            { key = "price", title = L.AUC_COL_MINE, width = 86, align = "RIGHT",
              format = function(v) return v and Money(v) or "–" end },
            { key = "other", title = L.AUC_COL_OTHER, width = 86, align = "RIGHT",
              format = function(v, r)
                  if r.sold or v == nil then return GREY .. "–|r" end
                  return (r.source == "live" and "" or GREY) .. Money(v) .. (r.source == "live" and "" or "|r")
              end },
            { key = "status", title = L.AUC_COL_STATUS, width = 90,
              format = function(v) return (STATUS_COLOR[v] or "") .. (L[STATUS_TEXT[v] or ""] or "") .. "|r" end,
              sortValue = function(r) return (r.rank or 9) * 1e7 + (Num(r.left) and r.left or 0) end },
            { key = "left", title = L.AUC_COL_LEFT, width = 64, align = "RIGHT",
              format = function(v, r) return r.sold and "–" or TimeLeftText(v, r.band) end,
              sortValue = function(r) return Num(r.left) and r.left or (r.band or 9) * 1e6 end },
        },
        rows = 17, rowHeight = 19, sortKey = "status",
        onClick = function(list, r) mod:Call("Meine Auktionen", A.SelectRow, r) end,
        onEnter = function(list, r, row) W.ShowItemTooltip(row, r.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.AUC_EMPTY,
    })
    A.list.frame:SetPoint("TOPLEFT", 4, -4)

    -- Stand und "Live pruefen"
    local y = -(A.list:GetHeight() + 10)
    A.status = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    A.status:SetPoint("TOPLEFT", 10, y - 4)
    A.liveButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    A.liveButton:SetSize(120, 22)
    A.liveButton:SetPoint("TOPRIGHT", -8, y)
    A.liveButton:SetText(L.AUC_LIVE)
    A.liveButton:SetScript("OnClick", function() mod:Call("Meine Auktionen", A.StartLive) end)

    -- Auswahl und Knoepfe
    A.selText = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    A.selText:SetPoint("BOTTOMLEFT", 10, 14)
    A.selText:SetJustifyH("LEFT")
    A.nextButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    A.nextButton:SetSize(170, 24)
    A.nextButton:SetPoint("BOTTOMRIGHT", -8, 8)
    A.nextButton:SetScript("OnClick", function() mod:Call("Meine Auktionen", A.CancelNextUnder) end)
    A.repostButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    A.repostButton:SetSize(116, 24)
    A.repostButton:SetPoint("RIGHT", A.nextButton, "LEFT", -6, 0)
    A.repostButton:SetText(L.AUC_REPOST)
    A.repostButton:SetScript("OnClick", function() mod:Call("Meine Auktionen", A.Repost) end)
    A.cancelButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    A.cancelButton:SetSize(100, 24)
    A.cancelButton:SetPoint("RIGHT", A.repostButton, "LEFT", -6, 0)
    A.cancelButton:SetText(L.AUC_CANCEL)
    A.cancelButton:SetScript("OnClick", function() if A.selected then mod:Call("Meine Auktionen", A.Cancel, A.selected) end end)
    A.selText:SetPoint("RIGHT", A.cancelButton, "LEFT", -8, 0)
end

function A.Init()
    mod:RegisterEvent("OWNED_AUCTIONS_UPDATED", function() A.OnOwnedUpdated() end)
    mod:RegisterEvent("AUCTION_CANCELED", function() A.OnCanceled() end)
    mod:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED", function()
        if W.IsOpen() and W.current == "auctions" then A.Query() end
    end)
    mod:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) OnResults(true, itemID) end)
    mod:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) OnResults(false, itemKey) end)
    pcall(mod.RegisterEvent, mod, "COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID) OnResults(true, itemID) end)
    pcall(mod.RegisterEvent, mod, "ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey) OnResults(false, itemKey) end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() A.liveRun = nil; A.busy = nil; A.watch = nil; A.autoLive = nil end)
end

W.pages.auctions = {
    build = A.Build,
    refresh = A.Refresh,
    -- Reiter gewaehlt (ab 0.20): Blizzard-Fenster auf "Auktionen", bzw. die gewaehlte Auktion zeigen
    enter = function()
        A.autoLive = AHOpen() and true or nil   -- nach dem Neuladen (Refresh fragt ab) live pruefen (ab 0.24)
        if A.selected and not A.selected.sold then A.SelectRow(A.selected) else W.SetAHMode("Auctions") end
    end,
}
