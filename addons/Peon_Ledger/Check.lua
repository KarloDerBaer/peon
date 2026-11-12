-- Peon_Ledger - Check.lua
-- Kontrollrechnung (ab 0.14, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 3.4, Bauabschnitt E1).
-- Ledger rechnet selbst nach, ob Gold und Bestand eines Charakters zu Anfangsbestand und Bewegungen passen:
--   Gold:      Anfangsgold + alle Goldbewegungen des Charakters  ->  verglichen mit dem gelesenen Gold
--   Bestand:   Anfangsbestand + alle Zu- und Abgaenge je Gegenstand  ->  verglichen mit Taschen, Bank, Auktionen
--              und Ausruestung (Post und "unterwegs" zaehlen nicht, dort liegt nichts, das schon verbucht waere)
-- Umbuchungen zwischen Taschen und Auktionen (eingestellt, zurueck) aendern den Bestand nicht.
-- Beim Einloggen (nach der Ruhezeit) wird eine Abweichung als eigene Zeile "Abweichung" verbucht (Art "diff",
-- zaehlt nicht als Gewinn). So stimmt die Rechnung danach wieder, und jede Luecke ist im Verlauf zu sehen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local K = {}
ns.Check = K

K.PLACES = { "bags", "bank", "auctions", "equip" }
K.SKIP = { posted = true, ahback = true, ahreturn = true }   -- nur Umbuchung zwischen Taschen und Auktionen
K.DELAY = 25        -- Sekunden nach dem Einloggen (Inventory.LOGIN_QUIET ist 20)
K.DAYS = 7          -- Abweichungen der letzten Tage in der Anzeige

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Erwarteter Stand eines Charakters: gold, items[id]
function K.Expected(name)
    local r = ns.Inventory.RealmData()
    local c = r.chars[name]
    if type(c) ~= "table" then return nil end
    local start = type(c.start) == "table" and c.start or { places = {} }
    local gold = Num(start.money) and start.money or nil
    local items = {}
    for _, place in ipairs(K.PLACES) do
        local p = type(start.places) == "table" and start.places[place]
        if type(p) == "table" and type(p.items) == "table" then
            for id, n in pairs(p.items) do items[id] = (items[id] or 0) + n end
        end
    end
    local function Use(k, id, n, m)
        if Num(m) and gold then gold = gold + m end
        if id and Num(n) and n ~= 0 and not K.SKIP[k] then items[id] = (items[id] or 0) + n end
    end
    if type(r.weeks) == "table" then
        for _, w in pairs(r.weeks) do
            for key, sum in pairs(w) do
                local cc, k, id = key:match("^(.-)|(.-)|(.-)$")
                if cc == name then
                    id = tonumber(id)
                    Use(k, (id and id > 0) and id or nil, sum.n, sum.m)
                end
            end
        end
    end
    for _, e in ipairs(ns.Moves.List()) do
        if e.c == name then Use(e.k, e.id, e.n, e.m) end
    end
    return gold, items
end

-- Gelesener Stand: gold, items[id]
function K.Actual(name)
    local c = ns.Inventory.RealmData().chars[name]
    if type(c) ~= "table" then return nil, {} end
    local items = {}
    for _, place in ipairs(K.PLACES) do
        local p = c.places and c.places[place]
        if type(p) == "table" and type(p.items) == "table" then
            for id, n in pairs(p.items) do items[id] = (items[id] or 0) + n end
        end
    end
    return Num(c.money) and c.money or nil, items
end

-- Abweichungen: { gold = Kupfer (gelesen - erwartet), items = { [id] = Stueck }, n = Anzahl }
function K.Run(name)
    name = name or ns.CharName()
    local eg, ei = K.Expected(name)
    local ag, ai = K.Actual(name)
    local res = { gold = 0, items = {}, n = 0, name = name }
    if eg and ag and ag ~= eg then res.gold = ag - eg; res.n = res.n + 1 end
    local seen = {}
    for id, n in pairs(ai) do
        seen[id] = true
        local d = n - (ei and ei[id] or 0)
        if d ~= 0 then res.items[id] = d; res.n = res.n + 1 end
    end
    for id, n in pairs(ei or {}) do
        if not seen[id] and n ~= 0 then res.items[id] = -n; res.n = res.n + 1 end
    end
    return res
end

-- Abweichungen als Zeilen "Abweichung" verbuchen (nur eingeloggter Charakter). Rueckgabe: Anzahl Zeilen
function K.Book(name)
    name = name or ns.CharName()
    local M = ns.Moves
    if M.pending or next(M.draft or {}) then return 0 end
    local res = K.Run(name)
    if res.n == 0 then K.last = res; return 0 end
    local n = 0
    if res.gold ~= 0 then M.Add("diff", nil, nil, res.gold, L.MV_X_DIFF, name); n = n + 1 end
    for id, d in pairs(res.items) do
        local e = M.Add("diff", id, d, nil, L.MV_X_DIFF, name)
        if e and d > 0 and ns.Cost then e.v = ns.Cost.MarketValue(id) or 0 end
        n = n + 1
    end
    mod:Dbg(("Kontrollrechnung %s: %d Abweichungen verbucht"):format(name, n))
    K.last = K.Run(name)
    return n
end

-- Zeilen "Abweichung" der letzten Tage (alle Charaktere des Realms)
function K.Recent(days, now)
    now = now or time()
    local from = now - (days or K.DAYS) * 86400
    local n = 0
    for _, e in ipairs(ns.Moves.List()) do
        if e.k == "diff" and (e.t or 0) >= from then n = n + 1 end
    end
    return n
end

-- Text fuer die Statuszeile
function K.StatusText()
    local open = K.Run().n
    local recent = K.Recent()
    if open == 0 and recent == 0 then return L.CHECK_OK end
    if open > 0 then return L.CHECK_OPEN:format(open) end
    return L.CHECK_RECENT:format(recent, K.DAYS)
end

function K.OnLogin()
    local CT = rawget(_G, "C_Timer")
    local function Go() mod:Call("Kontrollrechnung", K.Book) end
    if CT and CT.After then CT.After(K.DELAY, Go) else Go() end
end
