-- Peon_Broker - Trade.lua
-- Ab 0.127 (Konzept Peon_Broker_Marktvergleich.md, Abschnitt 6.2, KarloDerBaer 20.11.2026): Unterreiter "Markttausch" in
-- Chancen. Im einen Haus kaufen, im anderen verkaufen (Fraktion und Neutral).
--   Liste     vom Peon Manager (Peon_Bridge mod:Compare, sortiert nach seiner Bewertung). Ohne Manager eine einfache Liste
--             aus Brokers eigenen Preisen, nur nach Preisunterschied (Pages.lua G.CompareRows).
--   Zustand   nur fuer das Haus, an dem man steht: am Haus der Quelle "kaufbar" oder "zu teuer", am Haus des Ziels "frei"
--             oder "unterboten", dazu "im Gepaeck" fuer Ware, die hier verkauft werden soll. Grundlage ist der juengste
--             Preis im Markt dieses Hauses, "Alle pruefen" fragt alle Zeilen fuer dieses Haus einmal live ab (Radar.lua,
--             Auswahl "trade").
--   Klick     am Haus der Quelle: Fokus im Aufkauf mit Kaufen bis, am Haus des Ziels: Gegenstand. Unterwegs: Fokus fuer
--             den naechsten Besuch.
--   Gepaeck   (Konzept 6.2, M5) Was aus dem Markttausch in den Fokus ging, merkt sich Broker mit dem Zielhaus
--             (PeonBrokerDB.tradeGoods[Schluessel] = { dir, t, sell }). Am Zielhaus nennt ein Hinweis die Gegenstaende in
--             den Taschen (abschaltbar, chancesTradeNote). Verkauft oder nach 14 Tagen faellt der Eintrag weg.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local T = {}
ns.Trade = T

T.GOODS_KEEP = 14 * 86400
T.FRESH = 15 * 60          -- so lange gilt ein Live-Preis als "geprueft"
T.FALLBACK_MIN = 20        -- ohne Manager: mindestens 20 % Unterschied nach Gebuehr

local GREY, ORANGE, GREEN, GOLD, BLUE = "|cff999999", "|cffff9933", "|cff60e060", "|cffffd100", "|cff66bbff"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function T.On() return mod.db.chancesShowT ~= false end

-- Liste des Managers: t, list, say, info oder nil
function T.Manager()
    local b = Peon.GetModule and Peon:GetModule("bridge")
    if not b or type(b.Compare) ~= "function" then return nil end
    local ok, t, list, say, info = pcall(b.Compare, b, ns.HomeMarketKey())
    if ok and type(list) == "table" then return t, list, say or {}, info or {} end
    return nil
end

-- "n:80:200:90:120:2:15:86:900:g" -> Tabelle
function T.Parse(s)
    if type(s) ~= "string" then return nil end
    local dir, buy, sell, net, pd, qty, sup, cons, score, light = s:match("^([nh]):(%d+):(%d+):(%-?%d+):(%d+):(%d+):(%d+):(%d+):(%-?%d+):(%a)$")
    if not dir then return nil end
    return { dir = dir, buy = tonumber(buy), sell = tonumber(sell), net = tonumber(net), perDay = tonumber(pd) / 10, qty = tonumber(qty),
        supply = tonumber(sup) < 9999 and tonumber(sup) / 10 or nil, cons = tonumber(cons) / 100, score = tonumber(score),
        light = light == "g" and "green" or "yellow" }
end

-- Satz des Managers zu einem Gegenstand (Tooltip in Mehr, Neutral)
function T.Say(key)
    local _, list, say = T.Manager()
    if not list then return nil end
    return say[key] or (type(key) == "number" and say[tostring(key)]) or (type(key) == "string" and tonumber(key) and say[tonumber(key)]) or nil
end

-- Markt der Quelle und des Ziels einer Richtung
function T.Markets(dir)
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    if dir == "n" then return hk, nk end
    return nk, hk
end

-- Alle Eintraege: Liste { key, dir, buy, sell, net, perDay, qty, supply, cons, score, light, fallback }, Stand, vom Manager?
function T.Entries()
    local t, list = T.Manager()
    local out = {}
    T.stamp = t or "own"   -- neuer Stand des Managers: Liste neu sortieren
    if list then
        for key, s in pairs(list) do
            local x = T.Parse(s)
            if x then
                local k = (type(key) == "string" and key:match("^%d+$")) and tonumber(key) or key
                x.key = k
                out[#out + 1] = x
            end
        end
        return out, t, true
    end
    -- ohne Manager: einfache Liste nach Preisunterschied (Entscheidung KarloDerBaer 20.11.2026)
    local G = ns.Pages
    if not G then return out, nil, false end
    local hk, nk = ns.HomeMarketKey(), ns.NeutralMarketKey()
    local cutH, cutN = G.CutOf(hk), G.CutOf(nk)
    for _, r in ipairs(G.CompareRows(T.FALLBACK_MIN, false)) do
        if r.better and r.home and r.neutral then
            local x = { key = r.key, fallback = true, light = "yellow", score = r.pct }
            if r.better == "neutral" then
                x.dir, x.buy, x.sell = "n", r.home, r.neutral
                x.net = math.floor(r.neutral * (1 - cutN) - r.home)
            else
                x.dir, x.buy, x.sell = "h", r.neutral, r.home
                x.net = math.floor(r.home * (1 - cutH) - r.neutral)
            end
            out[#out + 1] = x
        end
    end
    return out, nil, false
end

-- Wo steht man? "src", "dst" oder nil (unterwegs oder anderes Haus)
function T.Where(dir)
    if not (ns.Scan and ns.Scan.ahOpen) then return nil end
    local here = ns.AHMarketKey()
    local src, dst = T.Markets(dir)
    if here == src then return "src" end
    if here == dst then return "dst" end
    return nil
end

-- Juengster Preis im Markt des Hauses: Preis, Zeit des Live-Preises (oder nil), weg?
local function PriceIn(market, key)
    local m = ns.Data.Markets()[market]
    local e = type(m) == "table" and m.items and m.items[key]
    if type(e) ~= "table" then return nil end
    return Num(e.m) and e.m or nil, e.lt, e.gone ~= nil
end

-- Wie viele hat man in den Taschen?
local function InBags(key)
    if not ns.Stock then return 0 end
    local bags = ns.Stock.Counts(ns.Data.ItemID(key), nil)
    return Num(bags) and bags or 0
end

-- Zustand einer Zeile: Code, Text
function T.State(x)
    local where = T.Where(x.dir)
    if not where then
        local src = T.Markets(x.dir)
        return "away", GREY .. (src == ns.NeutralMarketKey() and L.TR_ST_BUY_NEUTRAL or L.TR_ST_BUY_HOME) .. "|r"
    end
    local market = ns.AHMarketKey()
    local price, lt, gone = PriceIn(market, x.key)
    local fresh = lt and time() - lt <= T.FRESH
    if where == "dst" then
        local have = InBags(x.key)
        if have > 0 then return "bags", GOLD .. L.TR_ST_BAGS:format(have) .. "|r" end
        if not fresh then return "open", GREY .. L.TR_ST_SELL_HERE .. "|r" end
        if gone or not price or price >= x.sell then return "free", GREEN .. L.TR_ST_FREE .. "|r" end
        return "under", ORANGE .. L.TR_ST_UNDER:format(Money(price)) .. "|r"
    end
    if not fresh then return "open", GREY .. L.TR_ST_UNCHECKED .. "|r" end
    if gone or not price then return "none", GREY .. L.TR_ST_NONE .. "|r" end
    if price <= x.buy then return "buy", GREEN .. L.TR_ST_BUY .. "|r" end
    return "dear", ORANGE .. L.TR_ST_DEAR:format(Money(price)) .. "|r"
end

T.STATE_RANK = { buy = 1, bags = 1, free = 2, open = 3, under = 4, dear = 5, none = 6, away = 7 }

-- Zeilen fuer die Liste
function T.Rows()
    local D = ns.Data
    local rows = {}
    local entries = T.Entries()
    for _, x in ipairs(entries) do
        local src, dst = T.Markets(x.dir)
        local e = (D.Markets()[src] and D.Markets()[src].items[x.key]) or (D.Markets()[dst] and D.Markets()[dst].items[x.key])
        local state, text = T.State(x)
        x.name = D.ItemName(x.key, e) or tostring(x.key)
        x.quality = type(e) == "table" and e.ql or nil
        x.icon = ns.Buy and ns.Buy.Icon(D.ItemID(x.key)) or nil
        x.state, x.stateText, x.rank = state, text, T.STATE_RANK[state] or 9
        rows[#rows + 1] = x
    end
    return rows
end

-- Zahl am Unterreiter: gruene Eintraege (ohne Manager alle)
function T.Count()
    if not T.On() then return 0 end
    local n = 0
    local entries, _, mgr = T.Entries()
    for _, x in ipairs(entries) do if not mgr or x.light == "green" then n = n + 1 end end
    return n
end

-- Schluessel fuer "Alle pruefen": alle Zeilen, deren Quelle oder Ziel das Haus ist, an dem man steht
function T.Keys()
    local keys = {}
    for _, x in ipairs(T.Entries()) do
        if T.Where(x.dir) and ns.Buy.KnownKey(x.key) then keys[#keys + 1] = x.key end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function T.DirText(dir)
    return dir == "n" and L.TR_DIR_N or L.TR_DIR_H
end

function T.StatusText()
    local t, _, _, info = T.Manager()
    local st
    if t then
        local age = math.max(0, time() - t)
        st = GREY .. L.CH_STAND:format(age < 3600 and L.SPEC_MIN:format(math.max(1, math.floor(age / 60))) or L.SPEC_HOURS:format(math.floor(age / 3600))) .. "|r"
        if info and info.cutSure == false then st = st .. "  " .. GREY .. L.TR_CUT_GUESS:format(math.floor((info.cutN or 1500) / 100 + 0.5)) .. "|r" end
    else
        st = ORANGE .. L.TR_NO_MANAGER .. "|r"
    end
    local R = ns.Radar
    if R and R.running and R.forceMode == "trade" then
        local sc = R.search
        st = GREEN .. L.CH_CHECKING:format(sc and sc.done or 0, sc and #sc.keys or 0) .. "|r"
    end
    if not (ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse")) then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
    return st
end

-- Knopf "Alle pruefen": eine Runde fuer das Haus, an dem man steht
function T.CheckAll()
    local R = ns.Radar
    if not R then return end
    if R.running then R.Stop(); return end
    R.forceMode = "trade"
    R.search = nil
    R.Start()
end

---------------------------------------------------------------------------
-- Gepaeck (M5)
---------------------------------------------------------------------------
function T.Goods()
    local acc = mod.acc
    if type(acc.tradeGoods) ~= "table" then acc.tradeGoods = {} end
    return acc.tradeGoods
end

function T.Remember(x)
    if type(x) ~= "table" or x.key == nil then return end
    T.Goods()[x.key] = { dir = x.dir, t = time(), sell = x.sell }
end

-- Alte und verkaufte Eintraege entfernen (verkauft: nichts mehr in den Taschen und aelter als 1 Std.)
function T.Prune()
    local now = time()
    for key, g in pairs(T.Goods()) do
        if type(g) ~= "table" or not Num(g.t) or now - g.t > T.GOODS_KEEP or (now - g.t > 3600 and InBags(key) == 0) then
            T.Goods()[key] = nil
        end
    end
end

-- Gegenstaende in den Taschen, die an diesem Haus verkauft werden sollen: Liste { key, name, n }
function T.GoodsHere()
    local out = {}
    if not (ns.Scan and ns.Scan.ahOpen) then return out end
    local here = ns.AHMarketKey()
    for key, g in pairs(T.Goods()) do
        local _, dst = T.Markets(g.dir)
        local n = InBags(key)
        if dst == here and n > 0 then out[#out + 1] = { key = key, name = ns.Data.ItemName(key) or tostring(key), n = n } end
    end
    table.sort(out, function(a, b) return W.Lower(a.name) < W.Lower(b.name) end)
    return out
end

function T.OnAHShow()
    T.Prune()
    if mod.db.chancesTradeNote == false then return end
    local list = T.GoodsHere()
    if #list == 0 then return end
    local names = {}
    for i = 1, math.min(5, #list) do names[#names + 1] = list[i].name .. " x" .. list[i].n end
    if #list > 5 then names[#names + 1] = "..." end
    mod:Print(L.TR_GOODS_NOTE:format(#list, table.concat(names, ", ")))
end

---------------------------------------------------------------------------
-- Klick und Tooltip
---------------------------------------------------------------------------
function T.Click(r, button, owner)
    if button == "RightButton" then ns.Go.Menu(r, owner); return end
    local where = T.Where(r.dir)
    if where == "dst" then
        mod:Call("Sprung", ns.Go.Item, { key = r.key, name = r.name })
        return
    end
    T.Remember(r)
    mod:Call("Sprung", ns.Go.Focus, { key = r.key, name = r.name, from = "chances", mode = "buyout" })
    local F = ns.Focus
    if where == "src" and F and F.key == r.key and F.SetLimit then F.SetLimit(r.buy) end
end

function T.RowTooltip(row, r)
    if not GameTooltip then return end
    W.ShowItemTooltip(row, r.key)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.CH_TAB_TRADE .. ": " .. T.DirText(r.dir), 1, 0.82, 0)
    GameTooltip:AddDoubleLine(L.TR_COL_BUY, Money(r.buy), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TR_COL_SELL, Money(r.sell), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TR_COL_NET, Money(math.max(0, r.net or 0)), 0.8, 0.8, 0.8, 0.4, 0.9, 0.4)
    if r.perDay then GameTooltip:AddDoubleLine(L.TR_COL_SALES, ns.Pages.FmtSales(r.perDay), 0.8, 0.8, 0.8, 1, 1, 1) end
    if r.qty then GameTooltip:AddDoubleLine(L.TR_COL_QTY, tostring(r.qty), 0.8, 0.8, 0.8, 1, 1, 1) end
    if r.cons then GameTooltip:AddDoubleLine(L.TR_TIP_CONS, math.floor(r.cons * 100 + 0.5) .. " %", 0.8, 0.8, 0.8, 1, 1, 1) end
    if r.supply then GameTooltip:AddDoubleLine(L.TR_TIP_SUPPLY, ns.Pages.FmtSales(r.supply), 0.8, 0.8, 0.8, 1, 1, 1) end
    local say = T.Say(r.key)
    if say then GameTooltip:AddLine(" "); GameTooltip:AddLine(say, 0.6, 0.9, 1, true) end
    if r.fallback then GameTooltip:AddLine(" "); GameTooltip:AddLine(L.TR_TIP_FALLBACK, 0.6, 0.6, 0.6, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T.Where(r.dir) == "dst" and L.TR_TIP_CLICK_DST or L.TR_TIP_CLICK_SRC, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

function T.LightText(r)
    if r.fallback then return GREY .. L.TR_LIGHT_PRICE .. "|r" end
    return r.light == "green" and (GREEN .. L.TR_LIGHT_GREEN .. "|r") or (GOLD .. L.TR_LIGHT_YELLOW .. "|r")
end

function T.BuildList(c, top)
    local UI = Peon.UI
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, top)
    p:SetPoint("BOTTOMRIGHT", 0, 0)
    T.panel = p
    T.list = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return W.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "dir", title = L.TR_COL_DIR, width = 92, align = "RIGHT", format = function(v) return BLUE .. T.DirText(v) .. "|r" end },
            { key = "buy", title = L.TR_COL_BUY, width = 84, align = "RIGHT", format = function(v) return v and Money(v) or "" end },
            { key = "sell", title = L.TR_COL_SELL, width = 84, align = "RIGHT", format = function(v) return v and Money(v) or "" end },
            { key = "net", title = L.TR_COL_NET, width = 84, align = "RIGHT", format = function(v) return GREEN .. Money(math.max(0, v or 0)) .. "|r" end },
            { key = "perDay", title = L.TR_COL_SALES, width = 58, align = "RIGHT", format = function(v) return ns.Pages.FmtSales(v) end },
            { key = "qty", title = L.TR_COL_QTY, width = 50, align = "RIGHT", format = function(v) return v and tostring(v) or "" end },
            { key = "score", title = L.TR_COL_LIGHT, width = 58, align = "RIGHT", format = function(_, r) return T.LightText(r) end },
            { key = "state", title = L.CH_COL_STATE, width = 120, align = "RIGHT", format = function(_, r) return r.stateText or "" end,
              sort = function(r) return r.rank * 1e12 - (r.score or 0) end },
        },
        sortKey = "score", sortDesc = true, icon = true, empty = L.TR_EMPTY,
        onClick = function(r, button) T.Click(r, button, T.panel) end,
        onEnter = function(row, r) if r then T.RowTooltip(row, r) end end,
    })
    return p
end

function T.Refresh(resort)
    if T.list then W.FillTable(T.list, T.Rows(), resort) end
end

function T.Init()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function()
        if C_Timer and C_Timer.After then C_Timer.After(1, function() mod:Call("Markttausch", T.OnAHShow) end)
        else mod:Call("Markttausch", T.OnAHShow) end
    end)
end
