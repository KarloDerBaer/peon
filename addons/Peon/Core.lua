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
Peon.API       = 11         -- wird erhoeht, wenn Funktionen dazukommen (Module koennen pruefen)
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
                if not ok then Peon.Print(L.MSG_ERROR:format("Options", tostring(err))) end
            end
        elseif Peon.modules[name] then
            Peon.modules[name]:_Init()
        end
    elseif event == "PLAYER_LOGIN" then
        Peon.loggedIn = true
        if ns.FinishOptions then
            local ok, err = pcall(ns.FinishOptions)
            if not ok then Peon.Print(L.MSG_ERROR:format("Options", tostring(err))) end
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
