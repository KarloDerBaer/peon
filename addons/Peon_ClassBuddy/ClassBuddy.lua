-- Peon_ClassBuddy - ClassBuddy.lua
-- Klassenbuddy: kleine Helfer je Klasse (Konzept docs/konzepte/classbuddy/Peon_ClassBuddy_Konzept.md).
--   Schurke:      Combo-Punkte ueber dem Nameplate (Rogue_ComboPoints.lua, frueher Peon_ComboPoints)
--   Hexenmeister: ueberzaehlige Seelensplitter vernichten (Warlock_Shards.lua)
-- Jeder Teil startet nur fuer seine Klasse. Einstellungen in PeonClassBuddyDB, flach mit den Namen der Teile,
-- damit die Bausteine der Optionsseite sie direkt nutzen koennen (Combo-Punkte mit den Namen aus Peon_ComboPoints).

local ADDON_NAME, ns = ...
local L = ns.L

local function IsColor(n)
    return function(v)
        if type(v) ~= "table" then return false end
        for i = 1, n do
            if type(v[i]) ~= "number" or v[i] < 0 or v[i] > 1 then return false end
        end
        return true
    end
end
ns.IsColor = IsColor

-- Combo-Punkte: dieselben Namen und Standardwerte wie Peon_ComboPoints 3.5.1
ns.CP_KEYS = { "size", "gap", "yOffset", "ringPad", "showSockets", "fillColor", "socketColor", "ringColor" }

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "classbuddy",        -- /peon classbuddy ...
    title    = L.TITLE,
    db       = "PeonClassBuddyDB",
    defaults = {
        -- Schurke
        size        = 15,                          -- Durchmesser eines Punktes
        gap         = 4,                           -- Abstand zwischen den Punkten
        yOffset     = 8,                           -- Hoehe ueber dem HP-Balken
        ringPad     = 1,                           -- Dicke des Randes
        showSockets = true,                        -- leere Fassungen am Ziel zeigen
        fillColor   = { 1.00, 0.24, 0.20 },        -- gefuellter Punkt
        socketColor = { 0.00, 0.00, 0.00, 0.70 },  -- leere Fassung
        ringColor   = { 0.85, 0.70, 0.32, 1.00 },  -- goldener Rand
        cpImported  = false,                       -- Einstellungen aus Peon_ComboPoints uebernommen
        -- Hexenmeister
        shardOn     = true,                        -- ueberzaehlige Seelensplitter vernichten
        shardRule   = "bag",                       -- bag = Seelentasche voll, max = Hoechstzahl
        shardMax    = 20,                          -- Hoechstzahl (Regel max und ohne Seelentasche)
        shardAction = true,                        -- mit jedem Zauber von der Aktionsleiste einen vernichten
        shardMsg    = true,                        -- Meldung im Chat
    },
    ranges   = {
        size     = { 8, 32, 1 },
        gap      = { 0, 16, 1 },
        yOffset  = { -30, 60, 1 },
        ringPad  = { 0, 4, 1 },
        shardMax = { 1, 60, 1 },
    },
    choices  = { shardRule = { bag = true, max = true } },
    validate = {
        fillColor   = IsColor(3),
        socketColor = IsColor(4),
        ringColor   = IsColor(4),
    },
    keepOnReset = { cpImported = true },
    migrate  = function(m, acc)
        -- ab 0.2.0: Pruefung und Testfenster aus 0.1.0 sind weg
        acc.probe, acc.hideGuide = nil, nil
    end,
    onSlash  = function(m, cmd, rest)
        if cmd == "splitter" or cmd == "shard" or cmd == "shards" then
            if ns.Shards then ns.Shards.Report() end
        else
            m:OpenOptions()
        end
    end,
})
ns.mod = mod

-- Klasse des Charakters als englischer Schluessel (ROGUE, WARLOCK, ...)
function ns.PlayerClass()
    local _, class = UnitClass("player")
    if Peon.IsSecret(class) then return nil end
    return class
end

-- Einstellungen aus Peon_ComboPoints einmalig uebernehmen. Erst beim Einloggen, weil Peon_ComboPoints
-- (alphabetisch nach Peon_ClassBuddy) seine Einstellungen erst danach geladen hat.
function ns.ImportComboPoints()
    local db = mod.db
    local old = rawget(_G, "PeonComboPointsDB")
    if not db or db.cpImported or type(old) ~= "table" then return false end
    local o = mod.opts
    for _, k in ipairs(ns.CP_KEYS) do
        local v, def = old[k], o.defaults[k]
        local ok
        if o.validate[k] then ok = o.validate[k](v)
        else ok = type(v) == type(def) end
        if ok then
            if o.ranges[k] then v = Peon.Clamp(v, o.ranges[k]) or def end
            db[k] = Peon.CopyTable(v)
        end
    end
    db.cpImported = true
    mod:Dbg("Einstellungen aus Peon_ComboPoints uebernommen")
    mod:Fire("CHANGED")
    return true
end

mod:On("INIT", function()
    if ns.CreateOptions then mod:Call("Optionen", ns.CreateOptions) end
end)
mod:On("LOGIN", function()
    ns.ImportComboPoints()
end)

-- Bereiche fuer Rueckmeldungen in Peon_Feedback
if Peon.SetFeedbackAreas then
    Peon.SetFeedbackAreas(ADDON_NAME, (GetLocale() == "deDE")
        and { "Combo-Punkte", "Seelensplitter", "Optionen" }
        or  { "Combo points", "Soul shards", "Options" })
end
