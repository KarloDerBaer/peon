-- Peon - Core.lua
-- Globales Objekt "Peon", allgemeine Hilfsfunktionen und die zentrale Ereignisverteilung.
-- Module (Peon_Fishing, Peon_Tooltip, ...) sind eigene Addons mit "## Dependencies: Peon"
-- und melden sich per Peon:NewModule() an (siehe Module.lua).

local ADDON_NAME, ns = ...
local L = ns.L

local Peon = {}
_G.Peon = Peon
ns.Peon = Peon

Peon.name      = ADDON_NAME
Peon.L         = L
Peon.NewLocale = ns.NewLocale
Peon.API       = 14         -- wird erhoeht, wenn Funktionen dazukommen (Module koennen pruefen)
Peon.COLOR     = "ff8ccf4d" -- Peon-Gruen fuer Chat-Ausgaben
Peon.modules   = {}         -- addonName -> Modul
Peon.order     = {}         -- Module in Ladereihenfolge
Peon.loggedIn  = false

local GetMeta       = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

function Peon.GetMetadata(addonName, field)
    if not GetMeta then return nil end
    local ok, value = pcall(GetMeta, addonName, field)
    if ok then return value end
    return nil
end

function Peon.IsAddOnLoaded(addonName)
    return IsAddOnLoaded ~= nil and IsAddOnLoaded(addonName) and true or false
end

Peon.version = Peon.GetMetadata(ADDON_NAME, "Version") or "?"

---------------------------------------------------------------------------
-- Allgemeine Hilfsfunktionen
---------------------------------------------------------------------------
function Peon.Print(msg)
    print(("|c%sPeon|r: %s"):format(Peon.COLOR, tostring(msg)))
end

-- Geheime Werte (Secret Values, seit 12.x): nie vergleichen, rechnen oder als Schluessel nutzen
local issecretvalue = issecretvalue
function Peon.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Wert sicher als Text; geheime Werte werden nicht ausgewertet
function Peon.S(v)
    if Peon.IsSecret(v) then return L.SECRET end
    return tostring(v)
end

function Peon.InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player") == true
end

-- Tabelle rekursiv kopieren (fuer Standardwerte)
function Peon.CopyTable(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Peon.CopyTable(v) end
    return c
end

-- Zahl auf Schrittweite runden und in [min, max] halten. range = { min, max, step }
function Peon.Clamp(value, range)
    value = tonumber(value)
    if not value or type(range) ~= "table" then return nil end
    local step = range[3] or 1
    value = math.floor(value / step + 0.5) * step
    return math.max(range[1], math.min(range[2], value))
end

---------------------------------------------------------------------------
-- Fehlerspeicher (API 12): abgefangene Fehler aller Module in PeonDB.errors.
-- Das Spiel schreibt sie bei Reload, Ausloggen oder Beenden nach WTF (Peon.lua), dort liest der Peon Manager.
-- Gleiche Fehler zaehlen hoch. Der Manager loescht ueber Data.lua der Bridge (Peon.ClearErrors).
---------------------------------------------------------------------------
local MAX_ERRORS, MAX_ERROR_TEXT = 100, 1000

local function BuildNumber()
    if not GetBuildInfo then return nil end
    local ok, _, build = pcall(GetBuildInfo)
    if ok and not Peon.IsSecret(build) then return build end
    return nil
end

function Peon.RecordError(addon, where, err, version)
    local db = Peon.db
    if type(db) ~= "table" then return end
    if type(db.errors) ~= "table" then db.errors = {} end
    addon, where = tostring(addon), Peon.S(where)
    local msg = Peon.S(err):sub(1, MAX_ERROR_TEXT)
    local now = time and time() or 0
    for _, e in ipairs(db.errors) do
        if e.addon == addon and e.where == where and e.msg == msg then
            e.n, e.last, e.version = (e.n or 1) + 1, now, version or e.version
            return
        end
    end
    db.errors[#db.errors + 1] = { addon = addon, where = where, msg = msg, version = version,
        build = BuildNumber(), first = now, last = now, n = 1 }
    while #db.errors > MAX_ERRORS do table.remove(db.errors, 1) end
end

-- Fehler bis einschliesslich Zeitpunkt `upTo` loeschen, ohne Angabe alle. Rueckgabe: Anzahl geloescht
function Peon.ClearErrors(upTo)
    local db = Peon.db
    if type(db) ~= "table" or type(db.errors) ~= "table" then return 0 end
    local keep, n = {}, 0
    for _, e in ipairs(db.errors) do
        if upTo == nil or (e.last or 0) <= upTo then n = n + 1 else keep[#keep + 1] = e end
    end
    db.errors = keep
    return n
end

-- Fehler im Kern selbst (Optionen, Bausteine): speichern und kurz im Chat nennen
function Peon.ReportCoreError(where, err)
    Peon.RecordError(ADDON_NAME, where, err, Peon.version)
    Peon.Print(L.MSG_ERROR_SAVED:format(Peon.S(where)))
end

---------------------------------------------------------------------------
-- Ereignisverteilung
-- Kern-Ereignisse fuer Module: INIT (SavedVariables bereit), LOGIN, COMBAT_START, COMBAT_END,
-- RESET (Standardwerte). Dazu beliebige WoW-Ereignisse ueber mod:RegisterEvent().
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
Peon.frame = frame
local wowHandlers = {}   -- WoW-Ereignis -> { { mod, fn }, ... }

local function FireAll(name, ...)
    for _, mod in ipairs(Peon.order) do
        if mod.initialized then mod:Fire(name, ...) end
    end
end

function Peon._RegisterWowEvent(mod, event, fn)
    local list = wowHandlers[event]
    if not list then
        list = {}
        wowHandlers[event] = list
        frame:RegisterEvent(event)
    end
    list[#list + 1] = { mod = mod, fn = fn }
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if type(PeonDB) ~= "table" then PeonDB = {} end
            Peon.db = PeonDB
            if ns.CreateOptions then
                local ok, err = pcall(ns.CreateOptions)
                if not ok then Peon.ReportCoreError("Options", err) end
            end
        elseif Peon.modules[name] then
            Peon.modules[name]:_Init()
        end
    elseif event == "PLAYER_LOGIN" then
        Peon.loggedIn = true
        if Peon.SaveFeedbackAreas then Peon.SaveFeedbackAreas() end
        if Peon._RestoreLaunchers then Peon._RestoreLaunchers() end
        if ns.FinishOptions then
            local ok, err = pcall(ns.FinishOptions)
            if not ok then Peon.ReportCoreError("Options", err) end
        end
        FireAll("LOGIN")
    elseif event == "PLAYER_REGEN_DISABLED" then
        FireAll("COMBAT_START")
    elseif event == "PLAYER_REGEN_ENABLED" then
        FireAll("COMBAT_END")
    end

    local list = wowHandlers[event]
    if list then
        for _, h in ipairs(list) do
            if h.mod.initialized then h.mod:Call(event, h.fn, event, ...) end
        end
    end
end)
