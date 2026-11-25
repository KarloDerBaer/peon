-- Peon_Broker - Packages.lua
-- Ab 0.129 (Konzept Peon_Broker_Pakete.md, KarloDerBaer 20.11.2026): Unterreiter "Pakete" in Chancen, nur mit
-- eingeschaltetem Markttausch. Der Peon Manager stellt je Richtung ein Paket aus mehreren kleinen Angeboten zusammen
-- (Peon_Bridge mod:Packages). Hier stehen alle Angebote beider Pakete mit Zustand und einer Spalte Aktion:
--   Haus der Quelle  "Kaufen": genau die fehlende Menge bis Kaufen bis (Kaufweg des Radars, R.BuyStep, Art "pkg").
--                    Grau, wenn der Live-Preis darueber liegt oder noch keine frische Abfrage da ist.
--   Haus des Ziels   "Verkaufen": 1 Kupfer unter dem guenstigsten Angebot, nie unter Verkaufen ab. Liegt die Konkurrenz
--                    darunter, ist die Aktion gelb ("nicht mehr lukrativ"), ein zweiter Klick verkauft trotzdem.
--                    Massenware stellt Broker selbst ein (PostCommodity, wie das Lockangebot). Einzelstuecke legt der
--                    sichere Knopf unten ins Verkaufsfenster und traegt den Preis ein, "Auktion erstellen" klickt man dort.
-- Gekauft und im Gepaeck liest Broker aus Peon_Ledger (Posten mit Haus des Kaufs, mod:HouseLots), eingestellt aus den
-- eigenen Auktionen. Das klappt auch auf einem Twink, der die Ware per Post bekommen hat (Ledger nimmt das Haus mit).
-- Solange die Liste offen ist, fragt Broker die Zeilen fuer das Haus hier reihum ab (Trade.lua T.ActiveKeys).
-- Ab 0.138 (U6, Konzept Peon_Broker_Schlank.md 8): eine Zeile je Paket mit Richtung, Zahl der Angebote, Einsatz,
-- Gewinn und Stand ("2 von 6 gekauft"). Ein Klick klappt das Paket auf, darunter stehen seine Angebote mit Kaufen und
-- Verkaufen wie bisher (K.open, nur in der Sitzung, Vorgabe zu). Die Tabelle des Kerns bleibt unveraendert: die
-- Reihenfolge haelt eine feste Sortierung (order).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local K = {}
ns.Packages = K

K.WARN_WINDOW = 6   -- Sekunden: so lange gilt der erste Klick auf eine gelbe Aktion als Rueckfrage

local GREY, ORANGE, GREEN, GOLD, BLUE = "|cff999999", "|cffff9933", "|cff60e060", "|cffffd100", "|cff66bbff"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or time() end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end

function K.On() return ns.Trade ~= nil and ns.Trade.On() end

-- Pakete vom Manager: t, pkg oder nil
function K.Manager()
    local b = Peon.GetModule and Peon:GetModule("bridge")
    if not b or type(b.Packages) ~= "function" then return nil end
    local ok, t, p = pcall(b.Packages, b, ns.HomeMarketKey())
    if ok and type(p) == "table" then return t, p end
    return nil
end

-- "Schluessel:Menge:KaufenBis:VerkaufenAb:Erwartet" -> Tabelle
function K.Parse(s)
    if type(s) ~= "string" then return nil end
    local key, qty, buy, minSell, sell = s:match("^(.-):(%d+):(%d+):(%d+):(%d+)$")
    if not key or key == "" then return nil end
    return { key = key:match("^%d+$") and tonumber(key) or key, qty = tonumber(qty), buy = tonumber(buy), minSell = tonumber(minSell),
        sell = tonumber(sell) }
end

-- Haus-Kuerzel wie in Ledger: Quelle der Richtung n ist das eigene Haus ("f"), der Richtung h das neutrale ("n")
local function SrcHouse(dir) return dir == "n" and "f" or "n" end

-- Ledger: Posten nach Haus des Kaufs fuer diesen Charakter (oder leer)
function K.LedgerLots()
    local led = Peon.GetModule and Peon:GetModule("ledger")
    if not led or type(led.HouseLots) ~= "function" then return {} end
    local ok, lots = pcall(led.HouseLots, led)
    return ok and type(lots) == "table" and lots or {}
end

local function InBags(key)
    if not ns.Stock then return 0 end
    local bags = ns.Stock.Counts(ns.Data.ItemID(key), nil)
    return Num(bags) and bags or 0
end

-- Eingestellt im Zielhaus (letzter Stand der eigenen Auktionen, wenn er zum Markt passt)
local function Posted(key, market)
    local o = mod.acc and mod.acc.owned
    if type(o) ~= "table" or o.market ~= market or type(o.rows) ~= "table" then return 0 end
    local n = 0
    for _, r in ipairs(o.rows) do
        if type(r) == "table" and r.key == key and not r.sold then n = n + (Num(r.qty) and r.qty or 1) end
    end
    return n
end

-- Juengster Live-Preis im Markt des Hauses hier: Preis (nil = kein Angebot), frisch?
local function LivePrice(key)
    local m = ns.Data.Market(ns.AHMarketKey())
    local e = m and m.items and m.items[key]
    if type(e) ~= "table" then return nil, false end
    local fresh = Num(e.lt) and time() - e.lt <= ns.Trade.FRESH
    if e.gone or not Num(e.m) then return nil, fresh end
    return e.m, fresh
end

-- Verkaufspreis am Zielhaus: 1 Kupfer unter dem guenstigsten, nie unter Verkaufen ab. Rueckgabe Preis, lukrativ?
function K.SellPrice(x, lowest)
    if not Num(lowest) then return math.max(x.minSell, x.sell), true end
    local p = lowest - 1
    if p < x.minSell then return x.minSell, false end
    return p, true
end

-- Zeile mit Zustand und Aktion
function K.Row(x, lots, here)
    local D, T = ns.Data, ns.Trade
    local src, dst = T.Markets(x.dir)
    local id = D.ItemID(x.key)
    local e = (D.Markets()[src] and D.Markets()[src].items[x.key]) or (D.Markets()[dst] and D.Markets()[dst].items[x.key])
    x.name = D.ItemName(x.key, e) or tostring(x.key)
    x.quality = type(e) == "table" and e.ql or nil
    x.icon = ns.Buy and ns.Buy.Icon(id) or nil
    x.commodity = D.IsCommodity(x.key)
    local lot = lots[id]
    x.have = lot and Num(lot[SrcHouse(x.dir)]) and lot[SrcHouse(x.dir)] or 0
    x.bags = InBags(x.key)
    x.posted = Posted(x.key, dst)
    x.need = math.max(0, x.qty - x.have - x.posted)
    x.where = here == src and "src" or here == dst and "dst" or nil
    x.act, x.actText, x.actColor = nil, nil, GREY
    local price, fresh = nil, false
    if x.where then price, fresh = LivePrice(x.key) end
    x.live = price
    if x.where == "src" then
        if x.need <= 0 then
            x.state = GREEN .. L.PK_ST_BOUGHT:format(x.have) .. "|r"
        elseif not fresh then
            x.state = GREY .. L.TR_ST_UNCHECKED .. "|r"
            x.act, x.actText = "wait", L.PK_ACT_CHECKING
        elseif not price then
            x.state = GREY .. L.TR_ST_NONE .. "|r"
        elseif price <= x.buy then
            x.state = GREEN .. L.TR_ST_BUY .. "|r"
            x.act, x.actText, x.actColor = "buy", L.PK_ACT_BUY:format(x.need), GREEN
        else
            x.state = ORANGE .. L.TR_ST_DEAR:format(Money(price)) .. "|r"
            x.act, x.actText = "dear", L.PK_ACT_BUY:format(x.need)
        end
    elseif x.where == "dst" then
        local sellable = math.min(x.bags, math.max(0, x.qty - x.posted))
        if x.posted > 0 and sellable <= 0 then
            x.state = GREEN .. L.PK_ST_POSTED:format(x.posted) .. "|r"
        elseif sellable <= 0 then
            x.state = GREY .. (x.have > 0 and L.PK_ST_NOT_HERE or L.PK_ST_NOT_BOUGHT) .. "|r"
        elseif not fresh then
            x.state = GREY .. L.TR_ST_UNCHECKED .. "|r"
            x.act, x.actText = "wait", L.PK_ACT_CHECKING
        else
            local p, good = K.SellPrice(x, price)
            x.sellAt, x.sellQty = p, sellable
            x.state = (good and GREEN .. L.TR_ST_FREE or ORANGE .. L.TR_ST_UNDER:format(Money(price))) .. "|r"
            x.act, x.actText, x.actColor = good and "sell" or "sellwarn", L.PK_ACT_SELL:format(sellable), good and GREEN or ORANGE
        end
    else
        if x.posted > 0 then x.state = GREEN .. L.PK_ST_POSTED:format(x.posted) .. "|r"
        elseif x.have > 0 then x.state = GOLD .. L.PK_ST_BOUGHT:format(x.have) .. "|r"
        else x.state = GREY .. (src == ns.NeutralMarketKey() and L.TR_ST_BUY_NEUTRAL or L.TR_ST_BUY_HOME) .. "|r" end
    end
    return x
end

-- Alle Zeilen beider Pakete, dazu Zusammenfassung je Richtung { [dir] = { n, stake, gain, gainSafe, bought, posted } }
function K.Rows()
    local rows, sum = {}, {}
    local t, p = K.Manager()
    K.stamp = t or "none"
    if not p then return rows, sum, nil end
    local lots = K.LedgerLots()
    local here = (ns.Scan and ns.Scan.ahOpen) and ns.AHMarketKey() or nil
    for _, dir in ipairs({ "n", "h" }) do
        local pk = p[dir]
        if type(pk) == "table" and type(pk.list) == "table" then
            local s = { n = 0, stake = tonumber(pk.stake), gain = tonumber(pk.gain), gainSafe = tonumber(pk.gainSafe), bought = 0, posted = 0 }
            for _, line in ipairs(pk.list) do
                local x = K.Parse(line)
                if x then
                    x.dir = dir
                    K.Row(x, lots, here)
                    rows[#rows + 1] = x
                    s.n = s.n + 1
                    if x.have + x.posted >= x.qty then s.bought = s.bought + 1 end
                    if x.posted > 0 then s.posted = s.posted + 1 end
                end
            end
            sum[dir] = s
        end
    end
    return rows, sum, p
end

-- Schluessel fuer die laufende Abfrage: Zeilen, deren Quelle oder Ziel das Haus hier ist
function K.Keys()
    local keys = {}
    if not (ns.Scan and ns.Scan.ahOpen) then return keys end
    for _, x in ipairs((K.Rows())) do
        if x.where and (x.act ~= nil or x.need > 0) and ns.Buy.KnownKey(x.key) then keys[#keys + 1] = x.key end
    end
    return keys
end

function K.Shown()
    local C = ns.Chances
    return C ~= nil and C.Shown() and C.Tab() == "pkg"
end

function K.Count()
    if not K.On() then return 0 end
    local rows = K.Rows()
    local n = 0
    for _, x in ipairs(rows) do if x.act == "buy" or x.act == "sell" then n = n + 1 end end
    return n
end

function K.StatusText()
    local t, p = K.Manager()
    if not p then return ORANGE .. L.PK_NO_MANAGER .. "|r" end
    local _, sum = K.Rows()
    local parts = {}
    for _, dir in ipairs({ "n", "h" }) do
        local s = sum[dir]
        if s then parts[#parts + 1] = L.PK_SUM:format(ns.Trade.DirText(dir), s.bought, s.n, s.posted, Money(math.max(0, s.gainSafe or 0))) end
    end
    local st = #parts > 0 and table.concat(parts, "   ") or GREY .. L.PK_EMPTY_SHORT .. "|r"
    if not (ns.Scan.ahOpen and rawget(_G, "C_AuctionHouse")) then st = st .. "  " .. ORANGE .. L.ST_NOT_LIVE .. "|r" end
    return st
end

---------------------------------------------------------------------------
-- Aktionen (nur aus einem Klick)
---------------------------------------------------------------------------
-- Kaufen: genau die fehlende Menge, hoechstens bis Kaufen bis (Kaufweg des Radars)
function K.Buy(x)
    local R, B = ns.Radar, ns.Buy
    if not (R and B) or x.need <= 0 then return end
    local lv = B.live and B.live[x.key]
    if type(lv) ~= "table" or type(lv.rows) ~= "table" then return end
    local rows = {}
    for _, r in ipairs(lv.rows) do
        if Num(r.price) and r.price <= x.buy then rows[#rows + 1] = r end
    end
    local age = Num(lv.t) and math.max(0, time() - lv.t) or 999
    local d = { key = x.key, name = x.name, commodity = x.commodity, rows = rows, live = true, checked = Now() - age,
        qty = x.need, kind = "pkg", ref = x.sell }
    R.BuyStep(d, "pkg")
end

-- Massenware selbst einstellen (wie Quick.Post). K.post = { key, loc, price, qty, state, t }
function K.PostCommodity(x)
    local ah = AHApi()
    local b = K.post
    if b and b.key == x.key and b.state == "confirm" then
        local ok = ah.ConfirmPostCommodity and pcall(ah.ConfirmPostCommodity, b.loc, b.dur, b.qty, b.price)
        if not ok then K.post = nil; mod:Print(L.QUICK_POST_FAILED) else b.state, b.t = "posting", Now() end
        return
    end
    local bag, slot = ns.Quick and ns.Quick.FindBag(ns.Data.ItemID(x.key))
    local IL = rawget(_G, "ItemLocation")
    if not bag or not IL then mod:Print(L.QUICK_NO_ITEM); return end
    local okl, loc = pcall(function() return IL:CreateFromBagAndSlot(bag, slot) end)
    if not (okl and loc and ah.PostCommodity) then mod:Print(L.QUICK_POST_FAILED); return end
    local dur = ns.Data.DUR_INDEX[ns.Data.Duration(mod.db)] or 2
    local ok, needs = pcall(ah.PostCommodity, loc, dur, x.sellQty, x.sellAt)
    if not ok then mod:Print(L.QUICK_POST_FAILED); return end
    K.post = { key = x.key, loc = loc, price = x.sellAt, qty = x.sellQty, dur = dur, t = Now(), state = needs == true and "confirm" or "posting" }
    if ns.Radar then ns.Radar.lastSend = Now() end
    if needs == true then mod:Print(L.QUICK_CONFIRM_ASK) end
end

function K.OnPostWarning()
    local b = K.post
    if b and b.state == "posting" and Now() - b.t < 10 then b.state = "confirm"; mod:Print(L.QUICK_CONFIRM_ASK) end
end

function K.OnCreated()
    local b = K.post
    if not (b and b.state == "posting" and Now() - b.t < 10) then return end
    K.post = nil
    mod:Print(L.PK_POSTED:format(b.qty, ns.Data.ItemName(b.key) or tostring(b.key), Money(b.price)))
    if K.Shown() then K.Refresh(true) end
end

-- Klick auf die Spalte Aktion
function K.Act(x)
    if not x or not x.act or not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    if x.act == "dear" then mod:Print(L.PK_TOO_DEAR:format(x.name, Money(x.live or 0), Money(x.buy))); return end
    if x.act == "wait" then return end
    if x.act == "buy" then K.Buy(x); return end
    if x.act == "sellwarn" then
        local w = K.warned
        if not (w and w.key == x.key and Now() - w.t <= K.WARN_WINDOW) then
            K.warned = { key = x.key, t = Now() }
            mod:Print(L.PK_WARN:format(x.name, Money(x.live or 0), Money(x.minSell)))
            return
        end
        K.warned = nil
    end
    if x.act == "sell" or x.act == "sellwarn" then
        if x.commodity then K.PostCommodity(x)
        else
            K.selected = x
            K.UpdateSell()
            mod:Print(L.PK_ITEM_HINT:format(x.name))
        end
    end
end

-- Spalte unter der Maus (die Tabelle meldet nur die Zeile)
function K.OverAction()
    if not GetCursorPosition or not K.list then return false end
    local h = K.list.heads and K.list.heads[#K.list.o.columns]
    local left, right = h and h.GetLeft and h:GetLeft(), h and h.GetRight and h:GetRight()
    local scale = h and h.GetEffectiveScale and h:GetEffectiveScale() or 1
    local x = GetCursorPosition()
    return left ~= nil and right ~= nil and x ~= nil and scale > 0 and x / scale >= left and x / scale <= right
end

---------------------------------------------------------------------------
-- Einzelstuecke: sicherer Knopf legt das Stueck ins Verkaufsfenster, danach Preis eintragen (wie Beobachten, Lots.lua)
---------------------------------------------------------------------------
local function InCombat() return InCombatLockdown and InCombatLockdown() or false end

function K.UpdateSell()
    local b = K.sellButton
    if not b or InCombat() then return end
    local LT, x = ns.Lots, K.selected
    local name
    if x and not x.commodity and x.where == "dst" and LT and ns.Window.AtAH and ns.Window.AtAH() then
        local bag, slot = LT.FindBagSlot(x.key)
        if bag then name = LT.FindButton(bag, slot) end
    end
    if name then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/click " .. name .. " RightButton")
        b:SetText(L.PK_TO_SELL:format(x.name))
        b:Enable()
        b:Show()
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("macrotext", nil)
        b:Hide()
    end
end

-- Nach dem Klick: Preis ins Verkaufsfenster eintragen, sobald das Stueck dort liegt
function K.FillPrice()
    local x = K.selected
    if not x or not Num(x.sellAt) then return end
    local AHF = rawget(_G, "AuctionHouseFrame")
    local sf = AHF and rawget(AHF, "ItemSellFrame")
    if ns.Lots and ns.Lots.FillTarget then ns.Lots.FillTarget(sf, { target = x.sellAt }) end
end

---------------------------------------------------------------------------
-- Liste
---------------------------------------------------------------------------
function K.RowTooltip(row, x)
    if not GameTooltip then return end
    if K.OverAction() and x.act then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(x.actText or "", 1, 0.82, 0)
        if x.act == "buy" then GameTooltip:AddLine(L.PK_TIP_BUY:format(x.need, Money(x.buy)), 1, 1, 1, true)
        elseif x.act == "dear" then GameTooltip:AddLine(L.PK_TIP_DEAR:format(Money(x.live or 0), Money(x.buy)), 1, 0.6, 0.2, true)
        elseif x.act == "sell" or x.act == "sellwarn" then
            GameTooltip:AddLine(L.PK_TIP_SELL:format(x.sellQty or 0, Money(x.sellAt or 0), Money(x.minSell)), 1, 1, 1, true)
            if x.act == "sellwarn" then GameTooltip:AddLine(L.PK_TIP_WARN, 1, 0.6, 0.2, true) end
            if not x.commodity then GameTooltip:AddLine(L.PK_TIP_ITEM, 0.7, 0.7, 0.7, true) end
        end
        GameTooltip:Show()
        return
    end
    W.ShowItemTooltip(row, x.key, function(GameTooltip)   -- ab 0.131 Zusatzzeilen bleiben nach Umschalt
        GameTooltip:AddLine(L.CH_TAB_PKG .. ": " .. ns.Trade.DirText(x.dir), 1, 0.82, 0)
        GameTooltip:AddDoubleLine(L.TR_COL_BUY, Money(x.buy), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.PK_COL_MIN, Money(x.minSell), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.PK_TIP_EXPECT, Money(x.sell), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.PK_TIP_PROGRESS, L.PK_PROGRESS:format(x.have, x.posted, x.qty), 0.8, 0.8, 0.8, 1, 1, 1)
    end)
end

-- ab 0.138: Zeilen fuer die Tabelle: je Paket eine Kopfzeile, aufgeklappt darunter seine Angebote
K.open = {}   -- [Richtung] = true: aufgeklappt
function K.ViewRows(rows, sum)
    local out = {}
    for i, dir in ipairs({ "n", "h" }) do
        local s = sum and sum[dir]
        if s then
            local state = L.PK_ROW_STATE:format(s.bought, s.n) .. (s.posted > 0 and L.PK_ROW_POSTED:format(s.posted) or "")
            out[#out + 1] = { pkg = true, key = "pkg:" .. dir, dir = dir, order = i * 10000,
                name = L.PK_ROW:format(ns.Trade.DirText(dir)), qty = s.n, buy = s.stake, minSell = s.gainSafe or s.gain,
                gain = s.gain, gainSafe = s.gainSafe, stake = s.stake, bought = s.bought, posted = s.posted,
                state = (s.bought >= s.n and GREEN or GREY) .. state .. "|r", open = K.open[dir] == true,
                icon = "Interface\\Icons\\INV_Crate_01" }
            if K.open[dir] then
                local j = 0
                for _, x in ipairs(rows) do
                    if x.dir == dir then
                        j = j + 1
                        x.order, x.sub = i * 10000 + j, true
                        out[#out + 1] = x
                    end
                end
            end
        end
    end
    return out
end

function K.Toggle(dir)
    K.open[dir] = not K.open[dir] or nil
    K.Refresh(true)
end

function K.BuildList(c, top)
    local UI = Peon.UI
    local p = UI.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", 0, top)
    p:SetPoint("BOTTOMRIGHT", 0, 30)
    K.panel = p
    -- ab 0.138: feste Reihenfolge (Paket, darunter seine Angebote), Kopfzeilen mit Einsatz und Gewinn
    local function Order(r) return r.order or 0 end
    K.list = UI.Table(p, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = Order, nosort = true,
              format = function(v, r)
                  if r.pkg then return (r.open and "|cffffd100- |r" or "|cffffd100+ |r") .. tostring(v) end
                  return "   " .. tostring(v)
              end,
              color = function(r)
                  if r.pkg then return 1, 0.82, 0 end
                  return UI.QualityColor(r.quality or 1)
              end },
            { key = "dir", title = L.TR_COL_DIR, width = 92, align = "RIGHT", nosort = true,
              format = function(v, r) if r.sub then return "" end return BLUE .. ns.Trade.DirText(v) .. "|r" end },
            { key = "qty", title = L.TR_COL_QTY, width = 50, align = "RIGHT", nosort = true },
            { key = "buy", title = L.TR_COL_BUY, width = 84, align = "RIGHT", nosort = true,
              format = function(v) return Num(v) and Money(v) or "" end },
            { key = "minSell", title = L.PK_COL_MIN, width = 84, align = "RIGHT", nosort = true,
              format = function(v, r)
                  if not Num(v) then return "" end
                  return r.pkg and (GREEN .. Money(math.max(0, v)) .. "|r") or Money(v)
              end },
            { key = "state", title = L.CH_COL_STATE, width = 120, align = "RIGHT", nosort = true, format = function(v) return v or "" end },
            { key = "actText", title = L.PK_COL_ACT, width = 110, align = "CENTER", nosort = true,
              format = function(v, r) if not v then return "" end return (r.actColor or GREY) .. "[" .. v .. "]|r" end },
        },
        sortKey = "name", icon = true, empty = L.PK_EMPTY,
        rowLine = function(r) return r and r.pkg and (r.order or 0) > 10000 end,
        onClick = function(r, button)
            if r and r.pkg then
                if button ~= "RightButton" then mod:Call("Pakete", K.Toggle, r.dir) end
                return
            end
            if button == "RightButton" then ns.Go.Menu(r, K.panel); return end
            if K.OverAction() then mod:Call("Pakete", K.Act, r); return end
            K.selected = r
            K.UpdateSell()
        end,
        onEnter = function(row, r)
            if not r then return end
            if r.pkg then K.PkgTooltip(row, r); return end
            K.RowTooltip(row, r)
        end,
    })
    -- sicherer Knopf fuer Einzelstuecke (wie Beobachten, WatchPage.lua)
    local sb = CreateFrame("Button", "PeonBrokerPackageSellButton", c, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    sb:SetSize(260, 22)
    sb:SetPoint("BOTTOMRIGHT", -2, 4)
    if sb.RegisterForClicks then sb:RegisterForClicks("AnyUp", "AnyDown") end
    sb:HookScript("PreClick", function()
        local T = ns.AHTabs
        if T and T.current and T.Close then mod:Call("Verkaufen", T.Close) end
    end)
    sb:HookScript("PostClick", function()
        if C_Timer and C_Timer.After then C_Timer.After(0.3, function() mod:Call("Pakete", K.FillPrice) end) end
    end)
    UI.SetTooltip(sb, { L.PK_TO_SELL_TITLE, L.PK_TO_SELL_TIP })
    sb:Hide()
    K.sellButton = sb
    return p
end

-- ab 0.138: Tooltip einer Kopfzeile
function K.PkgTooltip(row, r)
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.name, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(L.PK_ROW_OFFERS:format(r.qty or 0), L.PK_ROW_STATE:format(r.bought or 0, r.qty or 0), 0.8, 0.8, 0.8, 1, 1, 1)
    if Num(r.stake) then GameTooltip:AddDoubleLine(L.PK_ROW_STAKE, Money(r.stake), 0.8, 0.8, 0.8, 1, 1, 1) end
    if Num(r.gainSafe) or Num(r.gain) then GameTooltip:AddDoubleLine(L.PK_ROW_GAIN, Money(math.max(0, r.gainSafe or r.gain)), 0.8, 0.8, 0.8, 0.38, 0.88, 0.38) end
    GameTooltip:AddLine(L.PK_ROW_TIP, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

function K.Refresh(resort)
    if not K.list then return end
    local all, sum = K.Rows()
    local rows = K.ViewRows(all, sum)   -- ab 0.138 je Paket eine Zeile
    W.FillTable(K.list, rows, resort or K.lastStamp ~= K.stamp)
    K.lastStamp = K.stamp
    if K.selected then
        local keep
        for _, r in ipairs(rows) do if r.key == K.selected.key and r.dir == K.selected.dir then keep = r end end
        K.selected = keep
    end
    K.UpdateSell()
end

function K.Init()
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_POST_WARNING", function() mod:Call("Pakete", K.OnPostWarning) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function() mod:Call("Pakete", K.OnCreated) end)
end
