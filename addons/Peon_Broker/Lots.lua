-- Peon_Broker - Lots.lua
-- Stufe 2, H3 (ab 0.67, Konzept Peon_Broker_Neuaufbau.md, Abschnitte 6.2 und 6.3): Wiederverkauf-Kette.
-- Gekauftes und Abgebrochenes kommt per Post. Broker merkt sich deshalb jeden Aufkauf aus dem Radar und jede
-- abgebrochene unterbotene Auktion als Posten (Gegenstand, Menge, Einsatz, Zielpreis) und fuehrt bis zum Einstellen.
--
-- Speicher je Charakter (die Ware liegt in seiner Post und Tasche): PeonBrokerCharDB.lots = {
--   { id, key, qty, left (noch einzustellen), cost (Einsatz gesamt, nil = unbekannt), target (Zielpreis je Stueck),
--     src ("radar" oder "cancel"), t, posted = { price, qty, t } } }
--
-- Einstellen bleibt Blizzards Weg (Rechtsklick in der Tasche, Klick auf "Auktion erstellen"). Broker legt nichts selbst
-- ins Verkaufsfenster: SetPostItem aus Addon-Code beruehrt Blizzards Wert displayMode, danach blockiert das Spiel das
-- Benutzen aus der Tasche (Fehlerberichte 10 und 11, Broker 0.64.1).
--
-- Zielpreis eintragen (Konzept 6.2, KarloDerBaer 11.11.2026): schreibt per Klick den Zielpreis in Blizzards Preisfeld
-- (PriceInput:SetAmount, wie Broker 0.10 bis 0.12, im Spiel bestaetigt). Pruefung auf Blockaden: Meldet das Spiel
-- innerhalb von LT.BLOCK_WATCH Sekunden danach eine blockierte Aktion von Broker, merkt Broker das (acc.targetBlocked)
-- und bietet den Knopf nicht mehr an. Der Zielpreis steht dann nur noch im Rat.
--
-- Unterbotene abbrechen (Konzept 6.3): Jeder Klick bricht die naechste unterbotene Auktion ab (eine je Klick, das Spiel
-- erlaubt es nur aus einem Klick). Vorher nennt der Knopf, was an Einzahlung verloren geht.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local LT = {}
ns.Lots = LT

LT.BLOCK_WATCH = 60          -- Sekunden nach "Zielpreis eintragen", in denen eine Blockade dem Knopf zugeschrieben wird
LT.POSTED_KEEP = 2 * 86400   -- eingestellte Posten bleiben so lange (Fokus bewacht sie), danach weg
LT.MAX = 100                 -- hoechstens so viele Posten

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function AHApi() return rawget(_G, "C_AuctionHouse") end

function LT.List()
    local c = mod.char
    if type(c) ~= "table" then return {} end
    if type(c.lots) ~= "table" then c.lots = {} end
    return c.lots
end

-- Neuer Posten (Radar-Kauf oder abgebrochene Auktion)
function LT.Add(key, qty, cost, target, src)
    if key == nil or not Num(qty) or qty < 1 then return nil end
    local list = LT.List()
    local c = mod.char
    c.lotSeq = (tonumber(c.lotSeq) or 0) + 1
    local lot = { id = c.lotSeq, key = key, qty = qty, left = qty, cost = Num(cost) and cost or nil,
                  target = Num(target) and math.floor(target + 0.5) or nil, src = src or "radar", t = time() }
    list[#list + 1] = lot
    while #list > LT.MAX do table.remove(list, 1) end
    mod:Dbg(("Posten: %s x%d, Ziel %s (%s)"):format(tostring(key), qty, tostring(lot.target), lot.src))
    LT.Changed()
    return lot
end

function LT.Remove(id)
    local list = LT.List()
    for i, lot in ipairs(list) do
        if lot.id == id then table.remove(list, i); LT.Changed(); return true end
    end
    return false
end

-- Posten, die noch eingestellt werden muessen
function LT.Open()
    local out = {}
    for _, lot in ipairs(LT.List()) do if (lot.left or 0) > 0 then out[#out + 1] = lot end end
    return out
end

function LT.Count() return #LT.Open() end

-- erster offener Posten zu einem Gegenstand (Variante oder Grund-ID)
function LT.ForKey(key)
    if key == nil then return nil end
    local id = ns.Data.ItemID(key)
    for _, lot in ipairs(LT.List()) do
        if (lot.left or 0) > 0 and (lot.key == key or ns.Data.ItemID(lot.key) == id) then return lot end
    end
    return nil
end

-- eingestellter Posten zu einem Gegenstand (fuer den Fokus: bewachen)
function LT.Posted(key)
    if key == nil then return nil end
    local best
    for _, lot in ipairs(LT.List()) do
        if lot.key == key and type(lot.posted) == "table" and (not best or lot.posted.t > best.posted.t) then best = lot end
    end
    return best
end

-- Stueck in den Taschen (ohne Bank)
function LT.InBags(key)
    local ci = rawget(_G, "C_Item")
    local id = ns.Data.ItemID(key)
    if not (ci and ci.GetItemCount and id) then return nil end
    local ok, n = pcall(ci.GetItemCount, id)
    return ok and Num(n) and n or nil
end

-- Einsatz je Stueck
function LT.UnitCost(lot)
    if not Num(lot.cost) or not Num(lot.qty) or lot.qty < 1 then return nil end
    return lot.cost / lot.qty
end

-- Eingestellt: offene Posten des Gegenstands um die Menge kuerzen (aelteste zuerst)
function LT.OnPosted(key, qty, price)
    if key == nil or not Num(qty) or qty < 1 then return 0 end
    local id, rest, hit = ns.Data.ItemID(key), qty, 0
    for _, lot in ipairs(LT.List()) do
        if rest <= 0 then break end
        if (lot.left or 0) > 0 and (lot.key == key or ns.Data.ItemID(lot.key) == id) then
            local take = math.min(lot.left, rest)
            lot.left, rest, hit = lot.left - take, rest - take, hit + take
            lot.posted = { price = Num(price) and price or nil, qty = (lot.posted and lot.posted.qty or 0) + take, t = time() }
        end
    end
    if hit > 0 then LT.Changed() end
    return hit
end

-- alte eingestellte Posten aufraeumen
function LT.Prune(now)
    now = now or time()
    local list = LT.List()
    for i = #list, 1, -1 do
        local lot = list[i]
        if (lot.left or 0) <= 0 and (not lot.posted or now - (lot.posted.t or 0) > LT.POSTED_KEEP) then table.remove(list, i) end
    end
end

---------------------------------------------------------------------------
-- Einstellen beobachten: sicherer Anhang an PostItem der beiden Verkaufsfenster merkt Gegenstand, Menge und Preis
-- (aus dem Rat, Advice.current), das Ereignis AUCTION_HOUSE_AUCTION_CREATED bestaetigt.
---------------------------------------------------------------------------
LT.POST_WAIT = 10
function LT.OnPostClick()
    local it = ns.Advice and ns.Advice.current
    if not it or it.key == nil then return end
    LT.pendingPost = { key = it.key, qty = Num(it.qty) and it.qty or 1, price = it.price, t = GetTime and GetTime() or 0 }
end

function LT.OnCreated()
    local p = LT.pendingPost
    LT.pendingPost = nil
    if not p or (GetTime and GetTime() or 0) - p.t > LT.POST_WAIT then return end
    LT.OnPosted(p.key, p.qty, p.price)
end

---------------------------------------------------------------------------
-- Zielpreis eintragen
---------------------------------------------------------------------------
function LT.CanFill()
    return not (type(mod.acc.targetBlocked) == "table")
end

-- Schreibt den Zielpreis des Postens in Blizzards Preisfeld. Rueckgabe true = eingetragen
function LT.FillTarget(sf, lot)
    if not LT.CanFill() or type(sf) ~= "table" or not lot or not Num(lot.target) then return false end
    local input = rawget(sf, "PriceInput")
    if type(input) ~= "table" or type(input.SetAmount) ~= "function" then return false end
    local ok = pcall(input.SetAmount, input, lot.target)
    if ok then
        LT.filledAt = GetTime and GetTime() or 0
        mod.acc.targetFills = (tonumber(mod.acc.targetFills) or 0) + 1
        mod:Dbg("Zielpreis eingetragen: " .. tostring(lot.target))
    end
    return ok
end

-- Das Spiel meldet eine blockierte Aktion von Broker: kurz nach "Zielpreis eintragen" gilt sie als Folge davon
function LT.OnBlocked(event, addon, fn)
    if addon ~= ADDON_NAME or not LT.filledAt then return end
    if (GetTime and GetTime() or 0) - LT.filledAt > LT.BLOCK_WATCH then return end
    mod.acc.targetBlocked = { t = time(), event = event, fn = type(fn) == "string" and fn or "?" }
    mod:Print(L.LOTS_FILL_BLOCKED)
end

---------------------------------------------------------------------------
-- Unterbotene abbrechen (Blizzards Reiter Auktionen)
---------------------------------------------------------------------------
-- Naechste unterbotene, nicht verkaufte Auktion (aelteste Zeile zuerst) und ihre Kosten
function LT.NextUndercut()
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do
        if r.status == "under" and not r.sold and r.id then return r, LT.CancelCost(r.id) end
    end
    return nil
end

function LT.CountUndercut()
    local n = 0
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do
        if r.status == "under" and not r.sold then n = n + 1 end
    end
    return n
end

function LT.CancelCost(id)
    local ah = AHApi()
    if not (ah and ah.GetCancelCost) then return nil end
    local ok, c = pcall(ah.GetCancelCost, id)
    return ok and Num(c) and c or nil
end

-- Ein Klick: naechste unterbotene Auktion abbrechen. Der neue Zielpreis ist das guenstigste fremde Angebot minus
-- Unterbieten (wie Verkaufen, F15).
function LT.CancelNext()
    local r = LT.NextUndercut()
    local ah = AHApi()
    if not r or not (ah and ah.CancelAuction) then return false end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return false end
    local ok = pcall(ah.CancelAuction, r.id)
    if not ok then mod:Print(L.LOTS_CANCEL_FAILED); return false end
    local unit = Num(r.price) and r.qty and r.qty > 0 and r.price or nil
    local target = Num(r.other) and ns.Data.Undercut(r.other, r.key, mod.db) or nil
    LT.cancelling = { id = r.id, key = r.key, qty = r.qty or 1, target = target, unit = unit, name = r.name }
    return true
end

-- Abbruch bestaetigt: Posten mit dem neuen Preis
function LT.OnCanceled(auctionID)
    local c = LT.cancelling
    if not c or (auctionID ~= nil and auctionID ~= c.id) then return end
    LT.cancelling = nil
    LT.Add(c.key, c.qty, nil, c.target, "cancel")
    mod:Print(L.LOTS_CANCELED:format(c.name or tostring(c.key), c.target and Money(c.target) or "?"))
    if ns.Auctions then pcall(ns.Auctions.Query) end
end

---------------------------------------------------------------------------
-- Anzeige: Zahl am Reiter Verkaufen, Statuszeile, Liste
---------------------------------------------------------------------------
-- Text von Blizzards Reiter "Verkaufen" mit Zahl (nur der Text, wie "Markt" statt "Kaufen")
function LT.UpdateSellTab()
    local f = rawget(_G, "AuctionHouseFrame")
    local tab = type(f) == "table" and rawget(f, "SellTab") or nil
    if type(tab) ~= "table" or not tab.SetText or not ns.AHTouch() then return end
    local base = L.AHTAB_SELL_BASE
    local n = LT.Count()
    tab:SetText(n > 0 and (base .. " (" .. n .. ")") or base)
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
    if ns.AHTabs and ns.AHTabs.AlignSoon then ns.AHTabs.AlignSoon() end
end

function LT.StatusPart()
    local n = LT.Count()
    if n <= 0 then return nil end
    return L.LOTS_STATUS:format(n)
end

function LT.Changed()
    LT.UpdateSellTab()
    if ns.Radar and ns.Radar.RefreshLots then ns.Radar.RefreshLots() end
    if ns.Focus and ns.Focus.Update then ns.Focus.Update() end
end

-- Zeilen fuer die Liste "Zum Einstellen"
function LT.Rows()
    local rows, D = {}, ns.Data
    for _, lot in ipairs(LT.Open()) do
        local e = D.Lookup(lot.key)
        local id = D.ItemID(lot.key)
        local bags = LT.InBags(lot.key)
        rows[#rows + 1] = {
            lot = lot, key = lot.key, link = D.LinkFromKey and D.LinkFromKey(lot.key) or nil,
            name = (type(e) == "table" and e.nm) or D.ItemName(lot.key, e) or tostring(lot.key),
            quality = type(e) == "table" and e.ql or nil, icon = ns.Buy.Icon(id),
            qty = lot.left, unit = LT.UnitCost(lot), target = lot.target,
            now = type(e) == "table" and not e.gone and e.m or nil, bags = bags,
        }
    end
    return rows
end

-- Klick auf einen Posten: am Auktionator Brokers Flaeche schliessen und sagen, wie es weitergeht
function LT.Pick(row)
    if not row then return end
    local T = ns.AHTabs
    if ns.Scan.ahOpen and T and T.current then T.Close() end
    local text = (row.bags or 0) > 0 and L.LOTS_HINT_POST or L.LOTS_HINT_MAIL
    local ef = rawget(_G, "UIErrorsFrame")
    if type(ef) == "table" and ef.AddMessage then pcall(ef.AddMessage, ef, text, 1, 0.82, 0) end
    mod:Print(text)
end

-- Rechtsklick: Posten entfernen, In den Fokus, Gegenstand
function LT.Menu(row, owner)
    if not row then return end
    local mu = rawget(_G, "MenuUtil")
    if not (mu and mu.CreateContextMenu) then return end
    mu.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(row.name or "")
        root:CreateButton(L.LOTS_REMOVE, function() LT.Remove(row.lot.id) end)
        root:CreateButton(L.MENU_FOCUS or L.NTAB_FOCUS, function() mod:Call("Sprung", ns.Go.Focus, { key = row.key }) end)
        root:CreateButton(L.NTAB_ITEM, function() mod:Call("Sprung", ns.Go.Item, { key = row.key }) end)
    end)
end

function LT.Init()
    LT.Prune()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function()
        mod:Call("Posten", function()
            LT.UpdateSellTab()
            local f = rawget(_G, "AuctionHouseFrame")
            if LT.hooked or not ns.AHTouch() or type(f) ~= "table" or not hooksecurefunc then return end
            for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
                local sf = rawget(f, name)
                if type(sf) == "table" and type(sf.PostItem) == "function" then
                    hooksecurefunc(sf, "PostItem", function() mod:Call("Posten", LT.OnPostClick) end)
                    LT.hooked = true
                end
            end
        end)
    end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function() mod:Call("Posten", LT.OnCreated) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_CANCELED", function(_, id) mod:Call("Posten", LT.OnCanceled, id) end)
    mod:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, addon, fn) mod:Call("Posten", LT.OnBlocked, "ADDON_ACTION_BLOCKED", addon, fn) end)
    mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) mod:Call("Posten", LT.OnBlocked, "ADDON_ACTION_FORBIDDEN", addon, fn) end)
    pcall(mod.RegisterEvent, mod, "BAG_UPDATE_DELAYED", function() if ns.Radar and ns.Radar.RefreshLots then mod:Call("Posten", ns.Radar.RefreshLots) end end)
end
