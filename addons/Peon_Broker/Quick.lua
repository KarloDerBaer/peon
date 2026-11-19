-- Peon_Broker - Quick.lua
-- Ab 0.104 (Wunsch KarloDerBaer 19.11.2026): Modus "Schnellkauf" im Reiter Fokus. Der bisherige Fokus heisst
-- "Aufkauf". Beide teilen Gegenstand, laufende Abfrage und Preisstufen, der Umschalter steht oben rechts.
-- Schnellkauf ist fuer guenstige Angebote, die nur Sekunden stehen (Lockangebote und ihre Nachahmer):
--   links   Kaufen bis, Menge, Kaufknopf mit Alarm (Ton und Leuchten, sobald etwas unter Kaufen bis steht),
--           Block Lockangebot (Preisfeld, Einstellen, Zurueckziehen, Zustand) und die Bilanz der Sitzung
--   rechts  Preisstufen (eigene Angebote markiert, neue Stufen kurz gruen), darunter ein Diagramm mit dem
--           guenstigsten Preis, der Menge unter Kaufen bis und senkrechten Strichen fuer eigene Lockangebote
-- Lockangebot: 1 Stueck aus den Taschen, kuerzeste Laufzeit. Der Preis steht als Vorschlag im Feld: ab 0.107
-- Kaufen bis minus quickBaitPct Prozent (Vorgabe 50, vorher die erste echte Stufe minus 20). Ein eigener Betrag im
-- Feld gilt bis zum naechsten Gegenstand. Ab 0.107 uebernimmt der Schnellkauf beim ersten Oeffnen Kaufen bis vom
-- Aufkauf (Q.EnsureLimit), damit das Feld nicht leer ist. Nur Massenware (PostCommodity). Eigenes Einstellen per Knopf war in Forever bisher nicht erprobt:
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
Q.baits = {}          -- ab 0.110: [Schluessel] = { { t, price, own, lastQ, added, times }, ... } Lockangebote fortlaufend
Q.hold = nil          -- ab 0.114: { key, rows, untilT } Pause der Abfragen, solange der Kaufknopf frei ist
Q.opp = {}            -- ab 0.111: [Schluessel] = { t, won } letzte Gelegenheit zum Kauf
Q.baitPing = nil      -- ab 0.111: Schluessel, fuer den gerade ein fremdes Lockangebot erkannt wurde
Q.avg = {}            -- ab 0.112: [Schluessel] = true/false, Haken "Durchschnitt zaehlt" (sonst aus Beobachten)
Q.skip = {}           -- ab 0.109: [Schluessel] = true/false, Haken "Lockangebot ignorieren" (sonst aus Beobachten)
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

-- ab 0.110: Kaufprotokoll (Radar.lua R.Trace)
function Q.Trace(fmt, ...)
    if ns.Radar and ns.Radar.Trace then ns.Radar.Trace(fmt, ...) end
end

-- quiet = true: nur umschalten (der Aufrufer zeichnet neu). Ab 0.106 laedt der Modus die Werte, die fuer den
-- Gegenstand in Beobachten gespeichert sind (Aufkauf und Schnellkauf getrennt).
function Q.SetMode(mode, quiet)
    local new = (mode == "quick") and "quick" or "buyout"
    local changed = mod.db.focusMode ~= new
    if changed and not quiet and ns.Focus.AutoSave then ns.Focus.AutoSave() end   -- ab 0.113: Werte des bisherigen Modus
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
    Q.manual, Q.prev, Q.newTiers, Q.alarm, Q.hold = nil, nil, {}, {}, nil
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
    -- ab 0.112: Max. Gold statt Max. Menge (die feste Menge des Aufkaufs gilt hier nicht)
    local gold = F.ManualGold(F.key)
    local cap = false
    if gold then cap = Q.GoldQty(d.rows, limit, gold) end
    local c = F.CapPlan(d, cap)
    if c and not c.gone then
        c.goldCap = gold
        if Q.AvgOn(F.key) then c.avgLimit = limit end   -- ab 0.112: Kauf gilt, solange der Durchschnitt passt
    end
    -- ab 0.109: Haken "Lockangebot ignorieren": Knopf und Alarm erst ab mehr als 1 Stueck unter Kaufen bis. Das
    -- Spiel verkauft von unten, der Kauf eines groesseren Stapels nimmt das eine Stueck also mit.
    if c and not c.gone and Q.SkipOn(F.key) and (c.maxQty or 0) <= Q.SKIP_MAX and (c.maxQty or 0) > 0 then
        c.baitOnly = true
        c.maxQty, c.qty, c.cost = 0, 0, 0
        c.best = { qty = 0, cost = 0 }
        c.buyLimit = 0
    end
    return c
end

-- ab 0.109: Haken "Lockangebot ignorieren" je Gegenstand (in dieser Sitzung, sonst aus Beobachten gespeichert)
Q.SKIP_MAX = 1   -- so viele Stueck allein gelten als Lockangebot (fest, KarloDerBaer 19.11.2026)
-- ab 0.113: gespeicherter Wert des Schnellkaufs fuer key (true/false) oder nil (nichts gespeichert -> Vorgabe).
-- Bis 0.112 stand nur true (sonst nil): hat der Eintrag schon Werte des Schnellkaufs, heisst nil dort aus.
local function SavedFlag(key, field)
    local Wt = ns.Watch
    local w = Wt and Wt.Is(key) and Wt.Store()[key]
    if not w then return nil end
    if w[field] ~= nil then return w[field] and true or false end
    if w.qlim ~= nil or w.qgold ~= nil or w.mode == "quick" then return false end
    return nil
end

function Q.SkipOn(key)
    if key == nil then return false end
    local v = Q.skip[key]
    if v ~= nil then return v end
    v = SavedFlag(key, "qskip")
    if v ~= nil then return v end
    return true   -- ab 0.113 Vorgabe an
end

-- ab 0.114 (Wunsch KarloDerBaer): Solange der Kaufknopf frei ist, schickt der Fokus hoechstens quickHold Sekunden
-- keine Abfrage. Laut Kaufprotokoll wartete ein Kauf sonst bis zu 1 Sek. auf den Preis und noch einmal so lange auf
-- die Bestaetigung, weil die Bremse des Spiels von der letzten Abfrage belegt war. Danach ist der Knopf gesperrt, bis
-- die naechste Antwort da ist (sie zeigt, was jetzt noch zu haben ist). Ein laufender Kauf haelt die Abfragen ohnehin an.
function Q.HoldQueries(key)
    local h = Q.hold
    if not (h and Q.On() and key ~= nil and h.key == key) then return false end
    return Now() < h.untilT
end

-- Kaufknopf gesperrt: Pause vorbei, die Antwort von damals ist noch die neueste
function Q.Locked(key)
    local h = Q.hold
    if not (h and Q.On() and key ~= nil and h.key == key) then return false end
    if Now() < h.untilT then return false end
    local rows = ns.Focus.LiveRows()
    return rows == nil or rows == h.rows
end

-- ab 0.112: wie viele Stueck bis Kaufen bis fuer gold Kupfer zu haben sind (von unten)
function Q.GoldQty(rows, limit, gold)
    local n, cost = 0, 0
    for _, l in ipairs(ns.Data.Available(rows or {})) do
        if Num(limit) and l.price > limit then break end
        local can = math.floor((gold - cost) / l.price)
        local take = math.min(l.qty, can)
        if take < 1 then break end
        n, cost = n + take, cost + take * l.price
        if take < l.qty then break end
    end
    return n
end

-- ab 0.112: Haken "Durchschnitt zaehlt" je Gegenstand (Sitzung, sonst aus Beobachten). Ab 0.113 Vorgabe an.
function Q.AvgOn(key)
    if key == nil then return false end
    local v = Q.avg[key]
    if v ~= nil then return v end
    v = SavedFlag(key, "qavg")
    if v ~= nil then return v end
    return true
end

-- ab 0.113 (Wunsch KarloDerBaer): Limit pro Kauf ohne gespeicherten Wert = Preis fuer Q.GOLD_QTY Stueck zu Kaufen bis.
-- Folgt Kaufen bis, bis man selbst einen Betrag eintraegt. Leert man das Feld, bleibt es leer (Q.goldCleared).
Q.GOLD_QTY = 100
Q.goldCleared = {}
function Q.EnsureGold()
    local F = ns.Focus
    local key = F.key
    if key == nil or not Q.On() or Q.goldCleared[key] then return end
    local m = F.manualGold
    if m and m.key == key and not m.auto then return end
    local limit = F.ManualLimit(key)
    if not (Num(limit) and limit > 0) then return end
    F.manualGold = { key = key, gold = math.floor(limit * Q.GOLD_QTY), auto = true }
end

function Q.SetAvg(on)
    local key = ns.Focus.key
    if key == nil then return end
    Q.avg[key] = on and true or false
    ns.Focus.Update()
end

function Q.SetSkip(on)
    local key = ns.Focus.key
    if key == nil then return end
    Q.skip[key] = on and true or false
    ns.Focus.Update()
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
    -- ab 0.114: neue Antwort mit etwas Kaufbarem -> Abfragen kurz anhalten, damit die Bremse des Spiels beim Klick frei
    -- ist. Ohne Kaufbares keine Pause.
    if rows ~= nil and rows ~= a.rows then
        local sec = tonumber(mod.db.quickHold) or 1
        if qty > 0 and sec > 0 then
            Q.hold = { key = key, rows = rows, untilT = Now() + sec }
            Q.Trace("hold %s s qty=%s", sec, qty)
            if C_Timer then C_Timer.After(sec + 0.05, function() if ns.Focus.Shown() then ns.Focus.Update() end end) end
        else
            Q.hold = nil
        end
    end
    -- ab 0.111: Gelegenheit = etwas Kaufbares unter Kaufen bis taucht auf (mit Haken ohne einzelnes Lockangebot)
    if rows ~= nil and rows ~= a.rows and qty > 0 and (a.key ~= key or (a.qty or 0) == 0) then
        local s = Q.Session(key)
        s.opps = (s.opps or 0) + 1
        Q.opp[key] = { t = Now(), won = false }
    end
    -- ab 0.111: Ton fuer ein neues fremdes Lockangebot, solange der Kaufknopf noch gesperrt ist (zum Vorbereiten)
    if Q.baitPing == key then
        Q.baitPing = nil
        if qty == 0 and mod.db.quickBaitAlarm ~= false and ns.Radar.PlayAlert then ns.Radar.PlayAlert(mod.db.quickBaitSound or "ping") end
    end
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
-- Vorschlag (ab 0.107): Kaufen bis minus quickBaitPct Prozent (nil ohne Kaufen bis)
function Q.Suggest()
    local F = ns.Focus
    local base = F.ManualLimit(F.key)
    if not Num(base) then return nil, nil end
    local pct = (tonumber(mod.db.quickBaitPct) or 50) / 100
    return math.max(1, math.floor(base * (1 - pct))), base
end

-- ab 0.107: Kaufen bis des Aufkaufs fuer key: in Beobachten gespeichert, sonst was der Aufkauf gerade rechnet
function Q.BuyoutLimit(key)
    local F, Wt = ns.Focus, ns.Watch
    if Wt and Wt.Is(key) then
        local l = Wt.Limit(key)
        if Num(l) and l > 0 then return l end
    end
    local keep = mod.db.focusMode
    mod.db.focusMode = "buyout"
    local ok, d = pcall(F.Plan)
    mod.db.focusMode = keep
    if ok and type(d) == "table" and not d.gone and Num(d.limit) and d.limit > 0 then return d.limit end
    return nil
end

-- Schnellkauf ohne Kaufen bis: das des Aufkaufs uebernehmen. Ab 0.107.1 jedes Mal, wenn das Feld leer ist, nur nicht
-- nachdem man es im Schnellkauf selbst geleert hat (Q.limitCleared, bis man wieder einen Wert eintraegt). In 0.107.0
-- galt "einmal je Gegenstand": Oeffnete man den Fokus aus Beobachten, waehrend der Schnellkauf eingestellt war, war das
-- Einmal schon verbraucht, bevor der Fokus in den gespeicherten Aufkauf wechselte. Danach blieb das Feld leer.
Q.limitCleared = {}
function Q.NoteLimit(key, limit)
    if key == nil then return end
    if limit then Q.limitCleared[key] = nil elseif Q.On() then Q.limitCleared[key] = true end
end

function Q.EnsureLimit()
    local F = ns.Focus
    local key = F.key
    if key == nil or not Q.On() or Q.limitCleared[key] or F.ManualLimit(key) then return end
    local v = Q.BuyoutLimit(key)
    if Num(v) and v > 0 then
        F.manualLimit = { key = key, price = math.floor(v) }
        F.manualSrc = F.manualSrc or "own"
    end
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
    -- ab 0.114.1 auch ohne vorher gesehen, wenn die Antwort sicher nach dem Einstellen kam (2 Sek. Abstand)
    if b.seen or t > (b.wall or 0) + 2 then b.state, b.goneT = "gone", Now() end
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
    Q.AddBait(b.key, Now(), b.price, true)
    Q.Trace("bait up price=%s id=%s", b.price, b.id)
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
    -- ab 0.114.1: Das Spiel meldet ein verkauftes Angebot ebenfalls mit AUCTION_CANCELED und dessen Nummer (Kaufprotokoll
    -- 19.11.2026: Lockangebot nach 0,35 Sek. weg, bevor eine Abfrage es zeigte). Vorher hiess "weg" nur, was eine
    -- Antwort schon einmal gezeigt hatte, der Zustand blieb sonst bei "steht seit".
    elseif b and b.state == "up" and b.id ~= nil and auctionID == b.id then
        b.state, b.goneT = "gone", Now()
        Q.Trace("bait gone id=%s", b.id)
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
    s.buys = (s.buys or 0) + 1
    -- ab 0.111: die letzte Gelegenheit gilt als genutzt (einmal)
    local o = Q.opp[job.key]
    if o and not o.won then o.won = true; s.won = (s.won or 0) + 1 end
end

-- ab 0.111: Kauf aus dem Schnellkauf ohne Erfolg (fehlgeschlagen, zu teuer, Fehler)
function Q.OnFailed(job)
    if not (job and job.quick) then return end
    local s = Q.Session(job.key)
    s.fails = (s.fails or 0) + 1
end

-- ab 0.111: Zeile "Gekauft": Stueck, Quote der genutzten Gelegenheiten. Rueckgabe Text, Tooltip-Zeilen
function Q.BoughtText(key)
    local s = key ~= nil and Q.sessions[key]
    local opps, won = s and s.opps or 0, s and s.won or 0
    local bought = s and s.bought or 0
    local pct = opps > 0 and math.floor(won * 100 / opps + 0.5) or nil
    local text = pct and L.QUICK_MV_BOUGHT:format(bought, pct) or L.QUICK_MV_BOUGHT0:format(bought)
    local tip = { L.QUICK_MV_TIP_BOUGHT:format(won, opps, s and s.buys or 0, s and s.fails or 0) }
    tip[#tip + 1] = Q.SkipOn(key) and L.QUICK_MV_TIP_BOUGHT_SKIP or L.QUICK_MV_TIP_BOUGHT_ALL
    return text, tip
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
-- Marktbewegung (ab 0.108, Wunsch KarloDerBaer 19.11.2026): Lockangebote wirken nur, wenn viel eingestellt wird.
-- Ueber dem Diagramm stehen Zufluss, Abfluss und die Bewegung, dazu die Nachwirkung des letzten Lockangebots.
-- Grundlage ist die laufende Messung (Measure.lua, Fenster focusWindow). Bewegung zaehlt Ereignisse je Minute:
-- Einstellungen + Kaeufe + Preisspruenge (Stufen mit neuer bzw. weniger Menge, guenstigster Preis geaendert).
--   lebhaft  mindestens quickMoveIn Einstellungen je Minute und mindestens quickMoveAll Ereignisse je Minute
--   ruhig    weniger als quickMoveLow Ereignisse je Minute
--   maessig  sonst
---------------------------------------------------------------------------
function Q.Movement(v)
    local M = ns.Measure
    M.Sync()
    if not v or (v.n or 0) < 2 or (v.elapsed or 0) < M.FIRST then return "first" end
    local db = mod.db
    local ev = (v.newPerMin or 0) + (v.soldPerMin or 0) + (v.jumpsPerMin or 0)
    if (v.newPerMin or 0) >= (tonumber(db.quickMoveIn) or 2) and ev >= (tonumber(db.quickMoveAll) or 5) then return "high", ev end
    if ev < (tonumber(db.quickMoveLow) or 1) then return "low", ev end
    return "mid", ev
end

-- Menge fremder Angebote genau zum Preis in einer Abfrage (eigene zaehlen nicht, Data.Available)
local function QtyAt(s, price)
    for _, l in ipairs(s.lv or {}) do if l.price == price then return l.qty end end
    return 0
end

-- Lockangebote fortlaufend (ab 0.110). Bis 0.109 aus den Abfragen der Messung gerechnet: die behaelt nur die letzten
-- 240 Abfragen (bei 0,7 Sek. knapp 3 Min.) und beginnt bei neuem Kaufen bis oder Modus neu, die Anzeige verschwand.
-- Jetzt prueft jede neue Abfrage (Q.OnSample aus Measure.Add):
--   fremdes Lockangebot  neue Preisstufe mit genau 1 Stueck, mindestens quickBaitMinPct Prozent unter dem bisher
--                        guenstigsten fremden Angebot (ab 0.109) und hoechstens bei Kaufen bis (ab 0.110)
--   Folge                in den quickFollowSec Sekunden danach waechst die Menge genau zum Lockpreis. Waechst sie nur um
--                        1 Stueck, ist das selbst ein Lockangebot und zaehlt nicht (ab 0.110).
-- Eigene Lockangebote kommen ueber Q.OnCreated dazu (Q.AddBait).
Q.BAIT_KEEP = 200

function Q.AddBait(key, t, price, own, lastQ)
    if key == nil or not Num(price) then return end
    if lastQ == nil then
        local c = ns.Measure and ns.Measure.cur
        local s = c and c.key == key and c.samples[#c.samples]
        lastQ = s and QtyAt(s, price) or 0
    end
    local list = Q.baits[key] or {}
    list[#list + 1] = { t = t, price = price, own = own or nil, lastQ = lastQ, added = 0, times = 0 }
    while #list > Q.BAIT_KEEP do table.remove(list, 1) end
    Q.baits[key] = list
end

function Q.OnSample(key, prev, s)
    if key == nil or type(s) ~= "table" or not Num(s.t) then return end
    local sec = tonumber(mod.db.quickFollowSec) or 30
    local list = Q.baits[key] or {}
    for _, b in ipairs(list) do
        if s.t > b.t and s.t <= b.t + sec then
            local q = QtyAt(s, b.price)
            local inc = q - (b.lastQ or 0)
            if inc >= 2 then b.added, b.times = b.added + inc, b.times + 1 end
            b.lastQ = q
        end
    end
    if prev and Num(prev.min) then
        local pct = (tonumber(mod.db.quickBaitMinPct) or 5) / 100
        -- ab 0.110: nur unter Kaufen bis (was man ohnehin nicht kaufen wuerde, zaehlt nicht). Ohne Kaufen bis alle.
        local F = ns.Focus
        local limit = F and F.key == key and F.ManualLimit and F.ManualLimit(key) or nil
        for _, l in ipairs(s.lv or {}) do
            if l.qty == 1 and l.price <= prev.min * (1 - pct) and QtyAt(prev, l.price) == 0
               and not (Num(limit) and l.price > limit) then
                Q.AddBait(key, s.t, l.price, false, 1)
                if ns.Focus and ns.Focus.key == key then Q.baitPing = key end   -- ab 0.111: Ton in Q.CheckAlarm
                Q.Trace("bait foreign price=%s min=%s", l.price, prev.min)
            end
        end
    end
end

-- Alle Lockangebote im Zeitfenster der Messung. Rueckgabe { n, withFollow, added, last } oder nil (keins im Fenster).
-- Jedes: { t, price, own, added, times, running, left, sec }
function Q.BaitStats(key)
    if key == nil then return nil end
    local M = ns.Measure
    M.Sync()
    local now = Now()
    local sec = tonumber(mod.db.quickFollowSec) or 30
    local from = now - M.WINDOW
    local r = { n = 0, withFollow = 0, added = 0 }
    for _, b in ipairs(Q.baits[key] or {}) do
        if b.t > from then
            local f = { t = b.t, price = b.price, own = b.own, added = b.added, times = b.times, sec = sec,
                        running = now < b.t + sec, left = math.max(0, math.ceil(b.t + sec - now)) }
            r.n = r.n + 1
            if f.added > 0 then r.withFollow = r.withFollow + 1 end
            r.added = r.added + f.added
            if not r.last or f.t >= r.last.t then r.last = f end
        end
    end
    if r.n == 0 then return nil end
    return r
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
