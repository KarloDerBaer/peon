-- Peon_Broker - Trade.lua
-- Ab 0.127 (Konzept Peon_Broker_Marktvergleich.md, Abschnitt 6.2, KarloDerBaer 20.11.2026): Unterreiter "Markttausch" in
-- Chancen. Im einen Haus kaufen, im anderen verkaufen (Fraktion und Neutral).
--   Liste     vom Peon Manager (Peon_Bridge mod:Compare, sortiert nach seiner Bewertung). Ohne Manager eine einfache Liste
--             aus Brokers eigenen Preisen, nur nach Preisunterschied (Pages.lua G.CompareRows).
--   Zustand   nur fuer das Haus, an dem man steht: am Haus der Quelle "kaufbar" oder "zu teuer", am Haus des Ziels "frei"
--             oder "unterboten", dazu "im Gepaeck" fuer Ware, die hier verkauft werden soll. Grundlage ist der juengste
--             Preis im Markt dieses Hauses, "Alle pruefen" fragt alle Zeilen fuer dieses Haus einmal live ab (Radar.lua,
--             Auswahl "trade").
-- Ab 0.128 (KarloDerBaer 20.11.2026, Konzept Abschnitt 10.1): nur noch die Auswahl des Managers, ohne ihn ein Hinweis
--             (die Liste nach Preisunterschied entfaellt). Broker fuegt nie etwas hinzu, er entfernt eine Chance, wenn neuere
--             Preise als der Stand des Managers ihre Bedingungen nicht mehr erfuellen (Spanne und Gewinn je Stueck nach dem
--             Anteil des Zielhauses, Grenzen vom Manager). Entfernte bleiben weg, bis ein neuerer Stand sie wieder bringt
--             (PeonBrokerDB.tradeGone[Heimatmarkt][Schluessel] = "Stand:Zeit"). Neue Preise kommen aus der laufenden Abfrage
--             (solange die Liste offen ist, reihum die Zeilen fuer das Haus hier, T.NextKey), dem Komplettscan und dem Manager.
--   Klick     am Haus der Quelle: Fokus im Aufkauf mit Kaufen bis, am Haus des Ziels: Gegenstand. Unterwegs: Fokus fuer
--             den naechsten Besuch.
--   Gepaeck   ab 0.128.1 aus Peon_Ledger: Posten, die im anderen Haus gekauft und noch nicht verkauft sind (Ledger 0.17,
--             mod:HouseLots). Bis dahin (Konzept 6.2, M5): Was aus dem Markttausch in den Fokus ging, merkt sich Broker mit dem Zielhaus
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

local GREY, ORANGE, GREEN, GOLD, BLUE = "|cff999999", "|cffff9933", "|cff60e060", "|cffffd100", "|cff66bbff"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- ab 0.128.2 (KarloDerBaer 20.11.2026): Markttausch in Chancen und Beobachten erst, wenn er in den Einstellungen der
-- Chancen eingeschaltet ist (tradeOn, Vorgabe aus). Mehr, Neutral bleibt immer da.
function T.On() return mod.db.tradeOn == true end

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

---------------------------------------------------------------------------
-- Entfernte Chancen (ab 0.128)
---------------------------------------------------------------------------
function T.GoneStore()
    local acc = mod.acc
    if type(acc.tradeGone) ~= "table" then acc.tradeGone = {} end
    local hk = ns.HomeMarketKey()
    if type(acc.tradeGone[hk]) ~= "table" then acc.tradeGone[hk] = {} end
    return acc.tradeGone[hk]
end

local function GoneStand(v)
    if type(v) ~= "string" then return nil end
    return tonumber(v:match("^(%d+)"))
end

-- Zur Liste des Managers mit Stand t entfernt?
function T.GoneAt(key, t)
    local g = GoneStand(T.GoneStore()[key])
    return g ~= nil and Num(t) and g >= t
end

-- Eintraege aelterer Staende vergessen
function T.PruneGone(t)
    if not Num(t) then return end
    local st = T.GoneStore()
    for k, v in pairs(st) do
        local g = GoneStand(v)
        if not g or g < t then st[k] = nil end
    end
end

-- Juengster Preis eines Markts, wenn er neuer ist als der Stand t: Preis (nil = kein Angebot), true. Sonst nil, false
local function NewerPrice(market, key, t)
    local m = ns.Data.Markets()[market]
    local e = type(m) == "table" and m.items and m.items[key]
    if type(e) ~= "table" then return nil, false end
    local seen = math.max(Num(e.t) and e.t or 0, Num(e.lt) and e.lt or 0)
    if not Num(t) or seen <= t then return nil, false end
    if e.gone or not Num(e.m) or e.m <= 0 then return nil, true end
    return e.m, true
end

-- Anteil des Zielhauses einer Richtung (gemessen, sonst die Annahme des Managers)
function T.CutDst(dir, info)
    local _, dst = T.Markets(dir)
    if dir == "n" and not ns.Data.CutSure(dst) and info and Num(info.cutN) then return info.cutN / 10000 end
    return ns.Pages and ns.Pages.CutOf(dst) or ns.Data.Cut(dst)
end

-- Erfuellt die Chance mit den neueren Preisen noch die Bedingungen? Rueckgabe ok, Kaufpreis, Verkaufspreis (mit neuen Preisen)
function T.Recheck(x, t, info)
    local src, dst = T.Markets(x.dir)
    local buyNow, srcNew = NewerPrice(src, x.key, t)
    local dstNow, dstNew = NewerPrice(dst, x.key, t)
    if not srcNew and not dstNew then return true, x.buy, x.sell end
    local buy = (srcNew and buyNow) or x.buy
    local sell = x.sell
    if dstNew and dstNow then sell = math.min(sell, dstNow) end
    local net = sell * (1 - T.CutDst(x.dir, info)) - buy
    local minNet = info and Num(info.minNet) and info.minNet or 1000
    local minPct = info and Num(info.minPct) and info.minPct or 20
    local ok = net >= minNet and buy > 0 and net / buy * 100 >= minPct
    return ok, buy, sell
end

-- Alle Eintraege der Auswahl des Managers: Liste { key, dir, buy, sell, net, perDay, qty, supply, cons, score, light,
-- buyNow, sellNow }, Stand, vom Manager? Ohne Manager eine leere Liste (ab 0.128).
function T.Entries()
    local t, list, _, info = T.Manager()
    local out = {}
    T.stamp = t or "none"   -- neuer Stand des Managers: Liste neu sortieren
    if not list then return out, nil, false end
    T.PruneGone(t)
    local gone = T.GoneStore()
    for key, s in pairs(list) do
        local x = T.Parse(s)
        if x then
            local k = (type(key) == "string" and key:match("^%d+$")) and tonumber(key) or key
            x.key = k
            if not T.GoneAt(k, t) then
                local ok, buy, sell = T.Recheck(x, t, info)
                if ok then
                    x.buyNow, x.sellNow = buy, sell
                    out[#out + 1] = x
                else
                    gone[k] = ("%d:%d"):format(t, time())   -- ab 0.128: entfernt bis zum naechsten Stand
                    T.removed = (T.removed or 0) + 1
                end
            end
        end
    end
    return out, t, true
end

-- Zahl der entfernten Eintraege zum jetzigen Stand
function T.GoneCount()
    local t = T.Manager()
    local n = 0
    if not t then return 0 end
    for _, v in pairs(T.GoneStore()) do local g = GoneStand(v); if g and g >= t then n = n + 1 end end
    return n
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

-- Wie viele hat man in den Taschen? Ab 0.131 (Fehlermeldung KarloDerBaer 24.11.2026) nur verkaufbare: Das Spiel zaehlt
-- auch Angelegtes mit, der Hinweis am neutralen Haus nannte so ein getragenes, seelengebundenes Stirnband. Jetzt zaehlen
-- nur Stuecke in den Taschen, die nicht gebunden sind (T.Unbound), hoechstens so viele, wie das Spiel meldet.
function T.Unbound(id)
    local C = rawget(_G, "C_Container")
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) or id == nil then return nil end
    local n = 0
    for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
        local okn, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (okn and tonumber(slots) or 0) do
            local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.itemID == id and info.isBound ~= true then
                n = n + (Num(info.stackCount) and info.stackCount or 1)
            end
        end
    end
    return n
end

local function InBags(key)
    if not ns.Stock then return 0 end
    local id = ns.Data.ItemID(key)
    local bags = ns.Stock.Counts(id, nil)
    bags = Num(bags) and bags or 0
    local free = T.Unbound(id)
    if free then bags = math.min(bags, free) end
    return bags
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

-- Zahl am Unterreiter: alle Eintraege der Auswahl
function T.Count()
    if not T.On() then return 0 end
    return #(T.Entries())
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
        local gone = T.GoneCount()
        if gone > 0 then st = st .. "  " .. GREY .. L.TR_GONE_N:format(gone) .. "|r" end
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

---------------------------------------------------------------------------
-- Laufende Abfrage (ab 0.128): solange die Liste Markttausch (oder Beobachten, Markttausch) offen ist, fragt Broker die
-- Zeilen fuer das Haus hier reihum ab, die am laengsten nicht gefragte zuerst (Radar.lua R.NextKey, Art "trade").
---------------------------------------------------------------------------
T.sent = {}   -- Schluessel -> Zeit der letzten Abfrage (GetTime)

function T.ListShown()
    local C = ns.Chances
    return C ~= nil and C.Shown() and C.Tab() == "trade"
end

-- Schluessel der offenen Liste (Chancen oder Beobachten), nil wenn keine offen ist
function T.ActiveKeys()
    if not (ns.Scan and ns.Scan.ahOpen) then return nil end
    if T.ListShown() then return T.Keys() end
    if ns.Packages and ns.Packages.Shown() then return ns.Packages.Keys() end   -- ab 0.129: Pakete
    -- ab 0.135 (U3): Beobachten hat keinen Unterreiter Markttausch mehr, die Pruefung der Liste fragt alle ab
    return nil
end

function T.Active()
    local keys = T.ActiveKeys()
    return keys ~= nil and #keys > 0
end

function T.NextKey()
    local keys = T.ActiveKeys()
    if not keys then return nil end
    local best, bestT
    for _, k in ipairs(keys) do
        local s = T.sent[k] or -1e9
        if best == nil or s < bestT then best, bestT = k, s end
    end
    if best ~= nil then T.sent[best] = GetTime and GetTime() or time() end
    return best
end

-- Antwort einer Abfrage (Radar.lua R.Apply): Liste neu zeigen
function T.OnAnswer(key)
    if (T.ListShown() or (ns.Packages and ns.Packages.Shown())) and ns.Chances then ns.Chances.Refresh() end
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

-- ab 0.128.1: Ware aus dem anderen Haus aus Peon_Ledger (Posten mit Haus, ab Ledger 0.17). Rueckgabe { [itemID] = Stueck },
-- nil ohne Ledger. here = "n" (neutrales Haus offen) oder "f"
function T.LedgerGoods(here)
    local led = Peon.GetModule and Peon:GetModule("ledger")
    if not led or type(led.HouseLots) ~= "function" then return nil end
    local ok, lots = pcall(led.HouseLots, led)
    if not ok or type(lots) ~= "table" then return nil end
    local other = here == "n" and "f" or "n"
    local out = {}
    for id, o in pairs(lots) do
        if Num(o[other]) and o[other] > 0 then out[id] = o[other] end
    end
    return out
end

-- Gegenstaende in den Taschen, die an diesem Haus verkauft werden sollen: Liste { key, name, n }
-- ab 0.128.1 vor allem aus Peon_Ledger (im anderen Haus gekauft und noch nicht verkauft), dazu die Merker aus dem
-- Markttausch (tradeGoods) fuer Kaeufe, die Ledger noch keinem Haus zuordnen konnte
function T.GoodsHere()
    local out = {}
    if not (ns.Scan and ns.Scan.ahOpen) then return out end
    local here = ns.AHMarketKey()
    local fromLedger = T.LedgerGoods(here == ns.NeutralMarketKey() and "n" or "f")
    local seen = {}
    for id, n in pairs(fromLedger or {}) do
        local bags = InBags(id)
        if bags > 0 then
            seen[id] = true
            out[#out + 1] = { key = id, name = ns.Data.ItemName(id) or tostring(id), n = math.min(bags, n) }
        end
    end
    for key, g in pairs(T.Goods()) do
        local _, dst = T.Markets(g.dir)
        local n = InBags(key)
        if dst == here and n > 0 and not seen[ns.Data.ItemID(key) or key] and not seen[key] then
            out[#out + 1] = { key = key, name = ns.Data.ItemName(key) or tostring(key), n = n }
        end
    end
    table.sort(out, function(a, b) return W.Lower(a.name) < W.Lower(b.name) end)
    return out
end

function T.OnAHShow()
    T.Prune()
    if not T.On() or mod.db.chancesTradeNote == false then return end
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

function T.RowTooltip(row, r)   -- ab 0.131: Zusatzzeilen ueber W.ShowItemTooltip (bleiben nach Umschalt)
    W.ShowItemTooltip(row, r.key, function(GameTooltip)
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
        if r.buyNow and r.buyNow ~= r.buy then GameTooltip:AddDoubleLine(L.TR_TIP_BUY_NOW, Money(r.buyNow), 0.8, 0.8, 0.8, 1, 1, 1) end
        if r.sellNow and r.sellNow ~= r.sell then GameTooltip:AddDoubleLine(L.TR_TIP_SELL_NOW, Money(r.sellNow), 0.8, 0.8, 0.8, 1, 1, 1) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T.Where(r.dir) == "dst" and L.TR_TIP_CLICK_DST or L.TR_TIP_CLICK_SRC, 0.6, 0.6, 0.6, true)
    end)
end

function T.LightText(r)
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
