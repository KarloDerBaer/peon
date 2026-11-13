-- Peon_Broker - Calendar.lua
-- Ab 0.93 (Konzept Peon_Manager_Chancen.md 5.4, D4): Feste aus dem Kalender des Spiels fuer die Prognosen im Peon Manager.
-- Beim Anmelden liest Broker die Feste der naechsten 6 Wochen mit Name, Beginn und Ende (wie Questie den
-- Dunkelmond-Jahrmarkt: C_Calendar.GetNumDayEvents, GetDayEvent). Fuer den Jahrmarkt muss die Einstellung
-- calendarShowDarkmoon an sein: Broker schaltet sie kurz ein und danach auf den alten Wert zurueck (KarloDerBaer, 13.11.2026).
-- Der Manager liest die Feste aus PeonBrokerDB.feste = { t = Zeit, list = { { n = Name, s = Beginn, e = Ende } }, dm }.
-- Pruefung P2: /broker pruefen kalender liest einmal mit und einmal ohne die Einstellung und nennt beides.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Ca = {}
ns.Calendar = Ca

Ca.WEEKS = 6
Ca.DELAY = 8     -- Sekunden nach dem Anmelden
Ca.WAIT = 5      -- so lange auf die Daten des Kalenders warten

local function Api() return rawget(_G, "C_Calendar") end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

-- Zeit des Kalenders { year, month, monthDay, hour, minute } in Sekunden
function Ca.Time(d)
    if type(d) ~= "table" or not Num(d.year) or not Num(d.month) then return nil end
    return time({ year = d.year, month = d.month, day = d.monthDay or d.day or 1, hour = d.hour or 0, min = d.minute or 0, sec = 0 })
end

local function CVar(name)
    local c = rawget(_G, "C_CVar")
    if c and c.GetCVar then return c.GetCVar(name) end
    local g = rawget(_G, "GetCVar")
    return g and g(name) or nil
end
local function SetCVar(name, v)
    local c = rawget(_G, "C_CVar")
    if c and c.SetCVar then return pcall(c.SetCVar, name, v) end
    local s = rawget(_G, "SetCVar")
    if s then return pcall(s, name, v) end
end

-- Feste der naechsten Wochen lesen. Rueckgabe: Liste { n, s, e } oder nil, Grund
function Ca.Read(weeks)
    local C = Api()
    if not C or type(C.GetNumDayEvents) ~= "function" or type(C.GetDayEvent) ~= "function" then return nil, "api" end
    local now = time()
    local cur = date("*t", now)
    if type(C.SetAbsMonth) == "function" then pcall(C.SetAbsMonth, cur.month, cur.year) end
    local out, seen = {}, {}
    for i = 0, (weeks or Ca.WEEKS) * 7 - 1 do
        local d = date("*t", now + i * 86400)
        local offset = (d.year - cur.year) * 12 + (d.month - cur.month)
        local ok, n = pcall(C.GetNumDayEvents, offset, d.day)
        for idx = 1, (ok and Num(n)) and n or 0 do
            local ok2, ev = pcall(C.GetDayEvent, offset, d.day, idx)
            if ok2 and type(ev) == "table" and ev.calendarType == "HOLIDAY" and type(ev.title) == "string" and not Peon.IsSecret(ev.title) then
                local s, e = Ca.Time(ev.startTime), Ca.Time(ev.endTime)
                if s then
                    local k = ev.title .. "|" .. s
                    if not seen[k] then
                        seen[k] = true
                        out[#out + 1] = { n = ev.title, s = s, e = e or s }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.s < b.s end)
    return out
end

-- Mit kurz eingeschaltetem Jahrmarkt lesen und den alten Wert zurueckstellen
function Ca.ReadWithDarkmoon()
    local old = CVar("calendarShowDarkmoon")
    local switched = old ~= nil and tostring(old) ~= "1"
    if switched then SetCVar("calendarShowDarkmoon", "1") end
    local list, why = Ca.Read()
    if switched then SetCVar("calendarShowDarkmoon", old) end
    return list, why, switched
end

function Ca.Save(list, switched)
    if type(list) ~= "table" then return end
    mod.acc.feste = { t = time(), list = list, dm = switched and true or nil }
    mod:Dbg(("Kalender: %d Feste gelesen"):format(#list))
end

-- Nach dem Anmelden: Kalender oeffnen, auf die Daten warten, lesen (nie im Kampf)
function Ca.Start()
    if Ca.started or not Api() then return end
    Ca.started = true
    local C = Api()
    C_Timer.After(Ca.DELAY, function()
        if Peon.InCombat and Peon.InCombat() then Ca.started = false; return end
        if type(C.OpenCalendar) == "function" then pcall(C.OpenCalendar) end
        C_Timer.After(Ca.WAIT, function()
            mod:Call("Kalender", function()
                local list, _, switched = Ca.ReadWithDarkmoon()
                Ca.Save(list, switched)
            end)
        end)
    end)
end

-- Pruefung P2: beide Wege vergleichen
function Ca.Probe()
    local C = Api()
    if not C then mod:Print(L.CAL_NO_API); return end
    if type(C.OpenCalendar) == "function" then pcall(C.OpenCalendar) end
    C_Timer.After(2, function()
        local old = CVar("calendarShowDarkmoon")
        SetCVar("calendarShowDarkmoon", "0")
        local without = Ca.Read() or {}
        SetCVar("calendarShowDarkmoon", "1")
        local with = Ca.Read() or {}
        SetCVar("calendarShowDarkmoon", old or "0")
        mod.acc.calProbe = { t = time(), old = old, without = without, with = with }
        mod:Print(L.CAL_PROBE:format(#without, #with, tostring(old)))
        for _, f in ipairs(with) do mod:Print(("  %s: %s bis %s"):format(f.n, date("%d.%m. %H:%M", f.s), date("%d.%m. %H:%M", f.e))) end
        Ca.Save(with, tostring(old) ~= "1")
    end)
end

mod:On("LOGIN", function() mod:Call("Kalender", Ca.Start) end)
