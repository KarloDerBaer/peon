-- Peon_Broker - Start.lua
-- Reiter "Start" - Was steht an? (ab 0.24, mit KarloDerBaer abgestimmt 03.10.2026)
-- Eine Zeile je Bereich mit dem, was gerade zu tun ist; Klick auf eine Zeile springt zum passenden Reiter.
-- Am Auktionshaus oeffnet das Broker-Fenster mit diesem Reiter. Nur lesend: es wird nichts gekauft, eingestellt
-- oder abgefragt ausser der Liste der eigenen Auktionen (wie im Reiter "Meine Auktionen").

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local St = {}
ns.Start = St

local GREY, ORANGE, GREEN, WHITE = "|cff999999", "|cffff9933", "|cff60e060", "|cffffffff"
local function Money(v) return ns.Tooltip.Money(v) end
local function AHOpen() return ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse") ~= nil end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
-- Verkaufen: lohnende Gegenstaende in den Taschen (ohne "Behalten"), Wert wie im Reiter Verkaufen
function St.SellLine()
    local n, value, vendor = 0, 0, 0
    for _, it in ipairs(ns.Sell.ScanBags()) do
        if not it.keep and (it.count or 0) > 0 then
            if it.worth then
                n = n + 1
                value = value + (it.value or 0)
            elseif it.hw and it.hw > 0 then
                vendor = vendor + it.hw
            end
        end
    end
    local text
    if n > 0 then text = L.START_SELL:format(n) else text = GREY .. L.START_SELL_NONE .. "|r" end
    if vendor > 0 then text = text .. GREY .. "  " .. L.START_SELL_VENDOR:format(Money(vendor)) .. "|r" end
    return { tab = "sell", area = L.TAB_SELL, text = text, value = n > 0 and Money(value) or "", prio = n > 0 and 2 or 0 }
end

-- Meine Auktionen: unterboten / verkauft / laufend (Stand der letzten Abfrage)
function St.AuctionsRows()
    local A = ns.Auctions
    if A.rows then return A.rows end
    local c = mod.acc.owned
    if type(c) == "table" and c.market == ns.MarketKey() and type(c.rows) == "table" then return c.rows end
    return nil
end

function St.AuctionsLine()
    local rows = St.AuctionsRows()
    if not rows then return { tab = "auctions", area = L.TAB_AUCTIONS, text = GREY .. L.START_AUC_UNKNOWN .. "|r", value = "", prio = 0 } end
    local under, sold, running, soldValue = 0, 0, 0, 0
    for _, r in ipairs(rows) do
        if r.sold or r.status == "sold" then
            sold = sold + 1
            if Num(r.price) then soldValue = soldValue + r.price * (r.qty or 1) end
        else
            running = running + 1
            if r.status == "under" then under = under + 1 end
        end
    end
    local parts = {}
    if under > 0 then parts[#parts + 1] = ORANGE .. L.START_AUC_UNDER:format(under) .. "|r" end
    if running > 0 then parts[#parts + 1] = L.START_AUC_RUNNING:format(running) end
    if sold > 0 then parts[#parts + 1] = GREEN .. L.START_AUC_SOLD:format(sold) .. "|r" end
    local text = #parts > 0 and table.concat(parts, "  ·  ") or (GREY .. L.START_AUC_NONE .. "|r")
    return { tab = "auctions", area = L.TAB_AUCTIONS, text = text, value = "", prio = under > 0 and 3 or (sold > 0 and 1 or 0) }
end

-- Scan: letzter Scan, wann der naechste moeglich ist
function St.ScanLine()
    local market = ns.Data.Market()
    local last = market and market.lastScan
    local wait = ns.Scan.Remaining()
    local text
    if ns.Scan.state then
        text = GREEN .. L.START_SCAN_RUNNING .. "|r"
    elseif not last then
        text = ORANGE .. L.MM_NO_SCAN .. "|r"
    else
        text = L.START_SCAN_LAST:format(ns.Scan.Age(last))
        if wait > 0 then text = text .. GREY .. "  ·  " .. L.START_SCAN_WAIT:format(ns.Scan.FormatTime(wait)) .. "|r"
        else text = text .. "  ·  " .. GREEN .. L.START_SCAN_READY .. "|r" end
    end
    local old = not last or time() - last > 3600
    return { tab = "prices", area = L.START_SCAN, text = text, value = "", prio = (old and wait == 0) and 2 or 0, scan = true }
end

-- Radar: Schnaeppchen in der Datenbank (wie beim Oeffnen des Reiters, ohne Live-Pruefung)
St.RADAR_CACHE = 30   -- Sekunden: Radar-Zeile nicht bei jeder Taschenaenderung neu rechnen

function St.RadarLine()
    local R, D = ns.Radar, ns.Data
    local market = D.Market()
    local now0 = GetTime and GetTime() or time()
    local c = St.radarCache
    if c and now0 - c.t < St.RADAR_CACHE and c.scan == (market and market.lastScan) and c.market == market then return c.line end
    local vendor, ah, best = 0, 0, 0
    if market then
        local maxAge = R.MaxAge()
        local now = time()
        local budget = R.Budget()
        for key, e in pairs(market.items) do
            if type(e) == "table" and e.lv and not e.gone and e.m and ns.Buy.KnownKey(key) then
                local seen = D.Seen(e)
                if seen and (not maxAge or now - seen <= maxAge) then
                    local hp = ns.VendorPrice(D.ItemID(key))
                    if ((hp and e.m < hp) or (e.md and e.m < e.md)) and not R.IsHidden(key) then
                        local ok, d = pcall(R.Evaluate, key, D.ParseLevels(e.lv), false, nil)
                        if ok and d and R.Visible(d, budget) and not d.cant then
                            if d.kind == "vendor" then vendor = vendor + 1 else ah = ah + 1 end
                            local g = d.showGain or (d.best and d.best.gain) or 0
                            if g > best then best = g end
                        end
                    end
                end
            end
        end
    end
    local n = vendor + ah
    local text = n > 0 and L.START_RADAR:format(n, vendor, ah) or (GREY .. L.START_RADAR_NONE .. "|r")
    local line = { tab = "radar", area = L.TAB_RADAR, text = text, value = best > 0 and (GREEN .. "+" .. Money(best) .. "|r") or "", prio = n > 0 and 2 or 0 }
    St.radarCache = { t = now0, scan = market and market.lastScan, market = market, line = line }
    return line
end

-- Einkaufsliste: Gegenstaende unter dem Hoechstpreis (Stand Scan / letzte Abfrage), noch unter der Wunschmenge
function St.BuyLine()
    if W.WIP and W.WIP.buy then return nil end   -- Einkaufsliste wird ueberarbeitet
    local B = ns.Buy
    local list = B.CurrentList()
    if not list then return { tab = "buy", area = L.TAB_BUY, text = GREY .. L.START_BUY_NOLIST .. "|r", value = "", prio = 0 } end
    local hits, open = 0, 0
    for _, r in ipairs(B.ListRows()) do
        local need = not r.wish or (r.stock or 0) < r.wish
        if need then open = open + 1 end
        if need and (r.hits or 0) > 0 then hits = hits + 1 end
    end
    local text
    if hits > 0 then text = L.START_BUY_HITS:format(list.name or "?", hits)
    elseif open > 0 then text = GREY .. L.START_BUY_OPEN:format(list.name or "?", open) .. "|r"
    else text = GREY .. L.START_BUY_DONE:format(list.name or "?") .. "|r" end
    return { tab = "buy", area = L.TAB_BUY, text = text, value = "", prio = hits > 0 and 2 or 0 }
end

function St.Lines()
    local out = {}
    for i, fn in ipairs({ St.AuctionsLine, St.SellLine, St.RadarLine, St.BuyLine, St.ScanLine }) do
        local ok, line = pcall(fn)
        if ok and line then line.order = i; out[#out + 1] = line
        elseif not ok then mod:Dbg("Start: Zeile " .. i .. " - " .. tostring(line)) end
    end
    return out
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
function St.Refresh()
    if not St.list then return end
    St.list:SetData(St.Lines())
    St.list:Refresh()
    St.hint:SetText(GREY .. (AHOpen() and L.START_HINT or L.START_HINT_NOAH) .. "|r")
end

function St.Click(line)
    if not line then return end
    if line.scan and AHOpen() and not ns.Scan.state and ns.Scan.Remaining() == 0 then
        ns.Scan.Start()
        St.Refresh()
        return
    end
    if line.tab and W.pages[line.tab] then W.Select(line.tab) end
end

function St.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    St.list = Peon.NewList(inset, {
        columns = {
            { key = "area", title = L.START_COL_AREA, width = 120,
              format = function(v, r) return (r.prio or 0) > 0 and (WHITE .. v .. "|r") or (GREY .. v .. "|r") end },
            { key = "text", title = L.START_COL_WHAT, width = total - 120 - 90 },
            { key = "value", title = "", width = 90, align = "RIGHT" },
        },
        rows = 8, rowHeight = 26, sortKey = "order",
        onClick = function(list, r) mod:Call("Start", St.Click, r) end,
        onEnter = function(list, r, row)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(r.area, 1, 1, 1)
            GameTooltip:AddLine(r.scan and L.START_TT_SCAN or L.START_TT_GO, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = "",
    })
    St.list.frame:SetPoint("TOPLEFT", 4, -4)
    St.hint = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    St.hint:SetPoint("BOTTOMLEFT", 10, 12)
    St.hint:SetPoint("RIGHT", -10, 0)
    St.hint:SetJustifyH("LEFT")
end

function St.Init()
    -- eigene Auktionen auch ohne geoeffneten Reiter "Meine Auktionen" lesen (fuer die Zeile)
    mod:RegisterEvent("OWNED_AUCTIONS_UPDATED", function()
        if W.IsOpen() and W.current == "start" then
            if not ns.Auctions.list then ns.Auctions.Read() end
            St.Refresh()
        end
    end)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function() if W.IsOpen() and W.current == "start" then St.Refresh() end end)
end

W.pages.start = {
    build = St.Build,
    refresh = St.Refresh,
    enter = function()
        if AHOpen() then ns.Auctions.Query(); W.SetAHMode("Buy") end
    end,
}
