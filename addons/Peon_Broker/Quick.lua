-- Peon_Broker - Quick.lua
-- Ab 0.104 (Wunsch KarloDerBaer 19.11.2026): Modus "Schnellkauf" im Reiter Fokus. Der bisherige Fokus heisst
-- "Aufkauf". Beide teilen Gegenstand, laufende Abfrage und Preisstufen, der Umschalter steht oben rechts.
-- Schnellkauf ist fuer guenstige Angebote, die nur Sekunden stehen (Lockangebote und ihre Nachahmer):
--   links   Kaufen bis, Menge, Kaufknopf mit Alarm (Ton und Leuchten, sobald etwas unter Kaufen bis steht),
--           Block Lockangebot (Preisfeld, Einstellen, Zurueckziehen, Zustand) und die Bilanz der Sitzung
--   rechts  Preisstufen (eigene Angebote markiert, neue Stufen kurz gruen), darunter ein Diagramm mit dem
--           guenstigsten Preis, der Menge unter Kaufen bis und senkrechten Strichen fuer eigene Lockangebote
-- Lockangebot: 1 Stueck aus den Taschen, kuerzeste Laufzeit. Der Preis steht als Vorschlag im Feld: die erste
-- echte Stufe (Data.SkipBait) minus quickBaitPct Prozent. Ein eigener Betrag im Feld gilt bis zum naechsten
-- Gegenstand. Nur Massenware (PostCommodity). Eigenes Einstellen per Knopf war in Forever bisher nicht erprobt:
-- Fragt das Spiel nach (Rueckgabe von PostCommodity oder AUCTION_HOUSE_POST_WARNING), bestaetigt erst der zweite
-- Klick (ConfirmPostCommodity).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Q = {}
ns.Quick = Q

Q.DURATION = 1        -- kuerzeste Laufzeit des Spiels
Q.NEW_SEC = 6         -- Sekunden: so lange ist eine neue oder groessere Stufe gruen
Q.POST_WAIT = 10      -- Sekunden: so lange warten wir auf die Bestaetigung des Spiels
Q.bait = nil          -- { key, price, t, loc, id, state = "posting" | "confirm" | "up" | "cancelling" | "cancelled" | "gone" }
Q.manual = nil        -- { key, price }: eigener Lockpreis (bis zum naechsten Gegenstand)
Q.sessions = {}       -- [Schluessel] = { baits, deposit, bought, cost }: Bilanz dieser Sitzung
Q.marks = {}          -- [Schluessel] = { GetTime() eigener Lockangebote } fuer das Diagramm
Q.newTiers = {}       -- [Preis] = GetTime(), bis wann die Stufe als neu gilt
Q.prev = nil          -- { key, rows, levels = { [Preis] = Menge } }: letzte Antwort fuer den Vergleich
Q.alarm = {}          -- { key, rows, qty }: letzte Antwort fuer den Alarm

local GREY, GREEN, ORANGE, YELLOW = "|cff999999", "|cff60e060", "|cffff9933", "|cffffd100"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function Now() return GetTime and GetTime() or time() end
local function AHApi() return rawget(_G, "C_AuctionHouse") end
local function AHOpen() return ns.Scan.ahOpen and AHApi() ~= nil end

function Q.On() return mod.db.focusMode == "quick" end

-- quiet = true: nur umschalten (der Aufrufer zeichnet neu). Ab 0.106 laedt der Modus die Werte, die fuer den
-- Gegenstand in Beobachten gespeichert sind (Aufkauf und Schnellkauf getrennt).
function Q.SetMode(mode, quiet)
    local new = (mode == "quick") and "quick" or "buyout"
    local changed = mod.db.focusMode ~= new
    mod.db.focusMode = new
    local F = ns.Focus
    F.chartN = nil
    if F.ApplyMode then F.ApplyMode() end
    if changed and not quiet and F.key ~= nil and ns.Watch and ns.Watch.Is(F.key) then
        F.LoadWatch(F.key)
        if F.limitInput and not F.ManualLimit(F.key) then F.ClearLimitInput() end
    end
    if not quiet then F.Update() end
end

function Q.Session(key)
    local s = Q.sessions[key]
    if not s then s = { baits = 0, deposit = 0, bought = 0, cost = 0 }; Q.sessions[key] = s end
    return s
end

-- Neuer Gegenstand im Fokus: eigener Lockpreis und Vergleich vergessen (Lockangebot und Bilanz bleiben)
function Q.OnNewKey()
    Q.manual, Q.prev, Q.newTiers, Q.alarm = nil, nil, {}, {}
end

---------------------------------------------------------------------------
-- Was der Schnellkauf kauft: alles bis Kaufen bis (ohne Kaufen bis nichts)
---------------------------------------------------------------------------
function Q.Plan()
    local F = ns.Focus
    local limit = F.ManualLimit(F.key)
    if not limit then return nil end
    local d = F.OwnPlan(limit + 1, limit)
    if not d then return nil end
    d.quick = true
    d.ref = F.ManualTarget(F.key)   -- Ziel fuer einen Posten (Wiedereinstellen), sonst keins
    d.net, d.gain, d.showGain = nil, nil, nil
    d.best.gain = nil
    return F.CapPlan(d)
end

-- Urteil: Text, Farbe, Satz
function Q.Verdict(d)
    local F = ns.Focus
    if not F.ManualLimit(F.key) then return L.QUICK_V_NOLIMIT, GREY, L.QUICK_W_NOLIMIT end
    if not d or d.gone then return L.FOCUS_V_WAIT, GREY, L.FOCUS_W_WAIT end
    if (d.maxQty or d.qty or 0) < 1 then
        return L.QUICK_V_NONE, GREY, mod.db.quickAlarm ~= false and L.QUICK_W_NONE_ALARM or L.QUICK_W_NONE
    end
    if d.cant then return L.FOCUS_V_CANT, ORANGE, L.FOCUS_W_GOLD end
    local lv = ns.Data.Available(d.rows or {})
    return L.QUICK_V_BUY, GREEN, L.QUICK_W_BUY:format(d.maxQty or d.qty or 0, lv[1] and Money(lv[1].price) or "-")
end

function Q.Summary(d)
    local qty, cost
    if d and not d.gone then
        local best = d.best or {}
        qty = Num(best.qty) and best.qty > 0 and best.qty or nil
        cost = qty and Num(best.cost) and best.cost or nil
    end
    return L.QUICK_SUMMARY:format(qty and tostring(qty) or "-", cost and Money(cost) or "-")
end

---------------------------------------------------------------------------
-- Alarm und neue Stufen (bei jeder neuen Antwort einmal)
---------------------------------------------------------------------------
-- Stufen einer Antwort als Preis -> Menge (nur fremde Angebote)
local function Levels(rows)
    local m = {}
    for _, l in ipairs(ns.Data.Available(rows or {})) do m[l.price] = (m[l.price] or 0) + l.qty end
    return m
end

-- Neue oder groessere Stufen seit der letzten Antwort merken
function Q.NoteTiers(key, rows)
    if type(rows) ~= "table" then return end
    local p = Q.prev
    if p and p.rows == rows then return end
    local levels = Levels(rows)
    if p and p.key == key then
        local untilT = Now() + Q.NEW_SEC
        for price, qty in pairs(levels) do
            if qty > (p.levels[price] or 0) then Q.newTiers[price] = untilT end
        end
    end
    Q.prev = { key = key, rows = rows, levels = levels }
end

function Q.IsNew(price)
    local t = Q.newTiers[price]
    return t ~= nil and Now() < t
end

-- Ton, wenn nach einer Antwort ohne Menge unter Kaufen bis jetzt etwas da ist. Der Kaufknopf leuchtet, solange
-- etwas da ist. Gleiche Antwort (z. B. nur Kaufen bis geaendert): kein Ton.
function Q.CheckAlarm(key, rows, qty, button)
    local a = Q.alarm
    if rows ~= nil and rows ~= a.rows then
        if a.key == key and (a.qty or 0) == 0 and qty > 0 and mod.db.quickAlarm ~= false and ns.Radar.PlayAlert then
            ns.Radar.PlayAlert(mod.db.quickSound or "raid")
        end
        Q.alarm = { key = key, rows = rows, qty = qty }
    elseif a.key == key then
        a.qty = qty
    end
    if button then
        if qty > 0 and button.LockHighlight then button:LockHighlight()
        elseif button.UnlockHighlight then button:UnlockHighlight() end
    end
end

---------------------------------------------------------------------------
-- Lockangebot
---------------------------------------------------------------------------
-- Vorschlag: erste echte Stufe minus quickBaitPct Prozent (nil ohne Live-Stand)
function Q.Suggest()
    local F = ns.Focus
    local rows = F.LiveRows()
    if not rows then return nil, nil end
    local D = ns.Data
    local b = D.SkipBait(rows, mod.db)
    local lv = D.Available(rows)
    local base = (b and b.price) or (lv[1] and lv[1].price)
    if not Num(base) then return nil, nil end
    local pct = (tonumber(mod.db.quickBaitPct) or 20) / 100
    return math.max(1, math.floor(base * (1 - pct))), base
end

function Q.ManualPrice(key)
    local m = Q.manual
    if m and key ~= nil and m.key == key and Num(m.price) and m.price > 0 then return m.price end
    return nil
end

function Q.Price(key)
    return Q.ManualPrice(key) or (Q.Suggest())
end

-- Getippter Lockpreis (0 = wieder der Vorschlag)
function Q.SetPriceTyped(amount)
    local F = ns.Focus
    if F.key == nil then return end
    if Num(amount) and amount > 0 then Q.manual = { key = F.key, price = math.floor(amount) } else Q.manual = nil end
    F.Update()
end

-- Gegenstand in den Taschen finden: bag, slot
function Q.FindBag(itemID)
    local C = rawget(_G, "C_Container")
    local slots = (C and C.GetContainerNumSlots) or rawget(_G, "GetContainerNumSlots")
    local idOf = (C and C.GetContainerItemID) or rawget(_G, "GetContainerItemID")
    if not (slots and idOf) then return nil end
    for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
        local okn, n = pcall(slots, bag)
        for slot = 1, (okn and tonumber(n) or 0) do
            local ok, id = pcall(idOf, bag, slot)
            if ok and id == itemID then return bag, slot end
        end
    end
    return nil
end

-- Lockangebot fuer key: steht es (eigene Menge zum Lockpreis im Live-Stand)?
function Q.BaitFor(key)
    local b = Q.bait
    if b and b.key == key then return b end
    return nil
end

-- Zustand nach einer neuen Antwort: eigenes Angebot zum Lockpreis nicht mehr da -> weg (gekauft oder abgelaufen)
function Q.CheckBait(key, rows, t)
    local b = Q.BaitFor(key)
    if not (b and b.state == "up" and type(rows) == "table" and Num(t)) then return end
    if t <= (b.wall or 0) then return end   -- Antwort von vor dem Einstellen
    for _, r in ipairs(rows) do
        if r.price == b.price and (r.own or 0) > 0 then b.seen = true; return end
    end
    if b.seen then b.state, b.goneT = "gone", Now() end
end

-- Knopf Einstellen (zweiter Klick bestaetigt, wenn das Spiel nachfragt)
function Q.Post()
    local F = ns.Focus
    local key = F.key
    if key == nil or not AHOpen() then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local b = Q.bait
    if b and b.key == key and b.state == "confirm" then
        local ok = ah.ConfirmPostCommodity and pcall(ah.ConfirmPostCommodity, b.loc, Q.DURATION, 1, b.price)
        if not ok then Q.bait = nil; mod:Print(L.QUICK_POST_FAILED) else b.state, b.t = "posting", Now() end
        F.Update()
        return
    end
    if b and (b.state == "posting" or b.state == "cancelling") and Now() - b.t < Q.POST_WAIT then return end
    if not ns.Data.IsCommodity(key) then mod:Print(L.QUICK_ONLY_MASS); return end
    local price = Q.Price(key)
    if not Num(price) then return end
    local id = ns.Data.ItemID(key)
    local bag, slot = Q.FindBag(id)
    local IL = rawget(_G, "ItemLocation")
    if not bag then mod:Print(L.QUICK_NO_ITEM); return end
    local okl, loc = pcall(function() return IL:CreateFromBagAndSlot(bag, slot) end)
    if not (okl and loc and ah.PostCommodity) then mod:Print(L.QUICK_POST_FAILED); return end
    local ok, needs = pcall(ah.PostCommodity, loc, Q.DURATION, 1, price)
    if not ok then mod:Print(L.QUICK_POST_FAILED); return end
    local dep
    if ah.CalculateCommodityDeposit then
        local okd, v = pcall(ah.CalculateCommodityDeposit, id, Q.DURATION, 1)
        if okd and Num(v) then dep = v end
    end
    Q.bait = { key = key, price = price, t = Now(), wall = time(), loc = loc, deposit = dep, state = needs == true and "confirm" or "posting" }
    ns.Radar.lastSend = Now()   -- Einstellen zaehlt wie eine Abfrage (Bremse des Spiels)
    if needs == true then mod:Print(L.QUICK_CONFIRM_ASK) end
    F.Update()
end

-- Das Spiel fragt nach (z. B. Preis weit unter dem Markt)
function Q.OnPostWarning()
    local b = Q.bait
    if b and b.state == "posting" and Now() - b.t < Q.POST_WAIT then
        b.state = "confirm"
        mod:Print(L.QUICK_CONFIRM_ASK)
        if ns.Focus.Shown() then ns.Focus.Update() end
    end
end

-- Auktion erstellt: Lockangebot steht
function Q.OnCreated(auctionID)
    local b = Q.bait
    if not (b and b.state == "posting" and Now() - b.t < Q.POST_WAIT) then return end
    b.state, b.id, b.t, b.wall = "up", Num(auctionID) and auctionID or nil, Now(), time()
    local s = Q.Session(b.key)
    s.baits = s.baits + 1
    s.deposit = s.deposit + (b.deposit or 0)
    local m = Q.marks[b.key] or {}
    m[#m + 1] = Now()
    Q.marks[b.key] = m
    mod:Print(L.QUICK_POSTED:format(Money(b.price)))
    if ns.Focus.Shown() then ns.Focus.Update() end
end

-- Fehler des Auktionshauses, waehrend wir einstellen oder zurueckziehen
function Q.OnError()
    local b = Q.bait
    if b and (b.state == "posting" or b.state == "confirm" or b.state == "cancelling") and Now() - b.t < Q.POST_WAIT then
        if b.state == "cancelling" then b.state = "up" else Q.bait = nil end
        mod:Print(L.QUICK_POST_FAILED)
        if ns.Focus.Shown() then ns.Focus.Update() end
    end
end

-- Knopf Zurueckziehen
function Q.Cancel()
    local b = Q.bait
    if not (b and b.state == "up" and b.id) then return end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return end
    local ah = AHApi()
    local ok = ah and ah.CancelAuction and pcall(ah.CancelAuction, b.id)
    if not ok then mod:Print(L.LOTS_CANCEL_FAILED); return end
    b.state, b.t = "cancelling", Now()
    ns.Focus.Update()
end

function Q.OnCanceled(auctionID)
    local b = Q.bait
    if b and b.state == "cancelling" and (auctionID == nil or auctionID == b.id) then
        b.state = "cancelled"
        if ns.Focus.Shown() then ns.Focus.Update() end
    end
end

-- Zustand des Lockangebots als Text
function Q.StateText(key)
    local b = Q.BaitFor(key)
    if not b then return GREY .. L.QUICK_BAIT_NONE .. "|r" end
    local ago = math.max(0, math.floor(Now() - b.t))
    if b.state == "confirm" then return ORANGE .. L.QUICK_BAIT_CONFIRM .. "|r" end
    if b.state == "posting" then return GREY .. L.QUICK_BAIT_POSTING .. "|r" end
    if b.state == "cancelling" then return GREY .. L.QUICK_BAIT_CANCELLING .. "|r" end
    if b.state == "cancelled" then return GREY .. L.QUICK_BAIT_CANCELLED .. "|r" end
    if b.state == "gone" then return YELLOW .. L.QUICK_BAIT_GONE:format(Money(b.price)) .. "|r" end
    return GREEN .. L.QUICK_BAIT_UP:format(Money(b.price), ns.Radar.ShortAge(ago)) .. "|r"
end

function Q.BalanceText(key)
    local s = Q.sessions[key]
    if not s or (s.baits == 0 and s.bought == 0) then return GREY .. L.QUICK_BALANCE_NONE .. "|r" end
    local avg = s.bought > 0 and Money(math.floor(s.cost / s.bought + 0.5)) or "-"
    return GREY .. L.QUICK_BALANCE:format(s.baits, Money(s.deposit), s.bought, Money(s.cost), avg) .. "|r"
end

-- Kauf fertig (Radar.lua R.FinishJob): in die Bilanz
function Q.OnBought(job, n, cost)
    if not (job and job.quick and n and n > 0) then return end
    local s = Q.Session(job.key)
    s.bought = s.bought + n
    s.cost = s.cost + (Num(cost) and cost or 0)
end

---------------------------------------------------------------------------
-- Diagramm: guenstigster Preis, Menge unter Kaufen bis, Striche fuer eigene Lockangebote
---------------------------------------------------------------------------
function Q.Series(limit)
    local M = ns.Measure
    local c = M and M.cur
    if not c or #c.samples < 2 then return nil end
    local under, mins, marks = {}, {}, {}
    local own = Q.marks[c.key] or {}
    for i, s in ipairs(c.samples) do
        local q = 0
        if Num(limit) then
            for _, l in ipairs(s.lv or {}) do if l.price <= limit then q = q + l.qty end end
        end
        under[i], mins[i] = q, s.min
        local prevT = i > 1 and c.samples[i - 1].t or -math.huge
        for _, t in ipairs(own) do
            if t > prevT and t <= s.t then marks[i] = true end
        end
    end
    return #c.samples, under, mins, marks
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
function Q.Init()
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_POST_WARNING", function() mod:Call("Schnellkauf", Q.OnPostWarning) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function(_, id) mod:Call("Schnellkauf", Q.OnCreated, id) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_CANCELED", function(_, id) mod:Call("Schnellkauf", Q.OnCanceled, id) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_SHOW_ERROR", function() mod:Call("Schnellkauf", Q.OnError) end)
end
