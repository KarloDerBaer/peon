-- Peon - Module.lua
-- Modul-Objekt: Anmeldung, SavedVariables (accountweit + pro Charakter), Standardwerte,
-- Chat-Ausgaben, Fehlerbehandlung, Debug-Log und Ereignisse.
--
-- Beispiel (in Peon_Fishing):
--   local ADDON_NAME, ns = ...
--   local mod = Peon:NewModule(ADDON_NAME, {
--       key      = "fishing",                 -- fuer /peon fishing ...
--       title    = "Fishing",                 -- Anzeige in Chat und Optionen
--       db       = "PeonFishingDB",           -- SavedVariables (accountweit)
--       charDB   = "PeonFishingCharDB",       -- SavedVariablesPerCharacter (optional)
--       oldDB    = "AlterNameDB",             -- alter Variablenname: Inhalt wird einmalig uebernommen
--       oldCharDB = "AlterNameCharDB",
--       charKeys = { mode = true, pending = true },
--       defaults = { ... },
--       ranges   = { offsetX = { -200, 200, 1 } },            -- Zahl: min, max, Schritt
--       choices  = { corner = { TOPLEFT = true, ... } },       -- erlaubte Werte
--       validate = { lure = function(v) ... return true end }, -- eigene Pruefung statt Typvergleich
--       migrate  = function(mod, acc, char) ... end,           -- vor dem Anwenden der Standardwerte
--       keepOnReset = { mode = true },                         -- bleibt bei "Standardwerte" erhalten (API 5)
--       slash    = { "/fp", "/fishingplus" },
--       onSlash  = function(mod, cmd, rest) ... end,
--   })
--   mod:On("INIT", function() local db = mod.db ... end)

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local MAX_LOG_DEFAULT = 2000

local Module = {}
Module.__index = Module
Peon.ModulePrototype = Module

---------------------------------------------------------------------------
-- Anmeldung
---------------------------------------------------------------------------
function Peon:NewModule(addonName, opts)
    assert(type(addonName) == "string", "Peon:NewModule: addonName fehlt")
    if Peon.modules[addonName] then return Peon.modules[addonName] end
    opts = opts or {}

    local mod = setmetatable({}, Module)
    mod.addonName = addonName
    mod.opts      = opts
    mod.key       = (opts.key or addonName:gsub("^Peon_", "")):lower()
    mod.title     = opts.title or Peon.GetMetadata(addonName, "Title") or addonName
    mod.version   = Peon.GetMetadata(addonName, "Version") or "?"
    mod.callbacks = {}
    mod.reported  = {}

    Peon.modules[addonName] = mod
    Peon.order[#Peon.order + 1] = mod

    if opts.slash then mod:_RegisterSlash(opts.slash) end
    return mod
end

function Peon:GetModule(keyOrName)
    if type(keyOrName) ~= "string" then return nil end
    if Peon.modules[keyOrName] then return Peon.modules[keyOrName] end
    local k = keyOrName:lower()
    for _, mod in ipairs(Peon.order) do
        if mod.key == k or mod.addonName:lower() == k then return mod end
    end
    return nil
end

---------------------------------------------------------------------------
-- Chat und Fehler
---------------------------------------------------------------------------
function Module:Print(msg)
    print(("|c%sPeon|r |cff33ccff%s|r: %s"):format(Peon.COLOR, self.title, tostring(msg)))
end

function Module:Error(msg)
    print(("|c%sPeon|r |cff33ccff%s|r: |cffff4040%s|r"):format(Peon.COLOR, self.title, tostring(msg)))
    if UIErrorsFrame then UIErrorsFrame:AddMessage(self.title .. ": " .. tostring(msg), 1, 0.25, 0.25) end
end

-- Fehler immer speichern (Peon.RecordError), im Chat nur einmal pro Sitzung kurz nennen, damit er nicht vollaeuft.
-- Den vollen Text zeigen /peon fehler und der Peon Manager.
function Module:ReportError(where, err)
    local text = Peon.S(err)
    Peon.RecordError(self.addonName, where, text, self.version)
    local key = tostring(where) .. text
    if self.reported[key] then return end
    self.reported[key] = true
    self:Print(L.MSG_ERROR_SAVED:format(tostring(where)))
    self:Dbg("FEHLER " .. tostring(where) .. ": " .. text)
end

-- Funktion geschuetzt aufrufen; Fehler werden einmalig gemeldet
function Module:Call(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then self:ReportError(where, err) end
    return ok, err
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
-- name: INIT, LOGIN, COMBAT_START, COMBAT_END, RESET oder eigene Namen (mod:Fire)
function Module:On(name, fn)
    local list = self.callbacks[name]
    if not list then list = {}; self.callbacks[name] = list end
    list[#list + 1] = fn
    -- zu spaet angemeldet? Dann sofort nachholen
    if self.initialized then
        if name == "INIT" then self:Call(name, fn) end
        if name == "LOGIN" and Peon.loggedIn then self:Call(name, fn) end
    end
end

function Module:Fire(name, ...)
    local list = self.callbacks[name]
    if not list then return end
    for _, fn in ipairs(list) do self:Call(name, fn, ...) end
end

-- Beliebiges WoW-Ereignis; fn(event, ...)
function Module:RegisterEvent(event, fn)
    Peon._RegisterWowEvent(self, event, fn)
end

---------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------
local function IsValid(o, k, v, default)
    if o.validate and o.validate[k] then return o.validate[k](v) == true end
    if type(v) ~= type(default) then return false end
    if o.choices and o.choices[k] and not o.choices[k][v] then return false end
    return true
end

function Module:_InitDB()
    local o = self.opts
    if not o.db then return end

    -- Tabelle holen; gibt es sie noch nicht, aber unter dem alten Namen (opts.oldDB / oldCharDB),
    -- wird die alte Tabelle uebernommen. Der alte Name wird geleert, damit WoW ihn nicht mehr speichert.
    -- Dafuer muss der alte Name fuer eine Version zusaetzlich in der TOC stehen.
    local function Adopt(name, oldName)
        local t = _G[name]
        if type(t) ~= "table" and oldName and type(_G[oldName]) == "table" then
            t = _G[oldName]
            self.adoptedFrom = oldName
        end
        if oldName then _G[oldName] = nil end
        if type(t) ~= "table" then t = {} end
        _G[name] = t
        return t
    end

    local acc = Adopt(o.db, o.oldDB)
    local char
    if o.charDB then char = Adopt(o.charDB, o.oldCharDB) end
    self.acc, self.char = acc, char

    if o.migrate then self:Call("Migration", o.migrate, self, acc, char) end

    -- Charakterwerte liegen nur in char; mod.db ist eine Sicht auf beide Tabellen
    local charKeys = char and o.charKeys
    local view
    if charKeys then
        for k in pairs(charKeys) do acc[k] = nil end
        view = setmetatable({}, {
            __index    = function(_, k) if charKeys[k] then return char[k] end return acc[k] end,
            __newindex = function(_, k, v) if charKeys[k] then char[k] = v else acc[k] = v end end,
        })
    else
        view = acc
    end
    self.db = view

    local defaults = o.defaults or {}
    if defaults.debug == nil then defaults.debug = false end
    o.defaults = defaults
    for k, v in pairs(defaults) do
        local cur = view[k]
        if not IsValid(o, k, cur, v) then
            view[k] = Peon.CopyTable(v)
        elseif o.ranges and o.ranges[k] then
            view[k] = Peon.Clamp(cur, o.ranges[k]) or v
        end
    end
end

-- Alle Einstellungen auf Standard; except = { key = true } bleibt erhalten.
-- Ohne except gilt opts.keepOnReset des Moduls (ab API 5), z. B. fuer Zustand oder gewaehlte Sets.
function Module:ResetDefaults(except)
    if not self.db then return end
    except = except or self.opts.keepOnReset
    for k, v in pairs(self.opts.defaults or {}) do
        if not (except and except[k]) then self.db[k] = Peon.CopyTable(v) end
    end
    self:Fire("RESET")
end

function Module:_Init()
    if self.initialized then return end
    self:Call("DB", self._InitDB, self)
    self.initialized = true
    self:Fire("INIT")
    self:_StartDebugSession()
    if Peon.loggedIn then self:Fire("LOGIN") end
end

---------------------------------------------------------------------------
-- Debug-Log: nur wenn db.debug an ist; landet zusaetzlich in acc.debugLog (max. opts.maxLog
-- Zeilen), damit es nach /reload in den SavedVariables auswertbar ist. Aus = nichts gespeichert.
---------------------------------------------------------------------------
function Module:_Log(line)
    local acc = self.acc
    if type(acc) ~= "table" then return end
    local log = acc.debugLog
    if type(log) ~= "table" then log = {}; acc.debugLog = log end
    log[#log + 1] = line
    local max = self.opts.maxLog or MAX_LOG_DEFAULT
    if #log > max then
        local keep = {}
        for i = #log - max + math.floor(max / 4), #log do keep[#keep + 1] = log[i] end
        acc.debugLog = keep
    end
end

function Module:IsDebug()
    return self.db ~= nil and self.db.debug == true
end

function Module:Dbg(msg)
    if not self:IsDebug() then return end
    local text = tostring(msg)
    print(("|c%sPeon|r |cff33ccff%s|r |cff999999[debug]|r %s"):format(Peon.COLOR, self.title, text))
    self:_Log(("%s %.3f %s"):format(date("%H:%M:%S"), GetTime(), text))
end

function Module:ToggleDebug()
    if not self.db then return end
    self.db.debug = not self.db.debug
    if self.db.debug then
        self.acc.debugLog = {}
        self:_Log(("%s ---- Debug an (%s v%s, Peon v%s) ----"):format(
            date("%Y-%m-%d %H:%M:%S"), self.addonName, tostring(self.version), tostring(Peon.version)))
    end
    self:Print(self.db.debug and L.MSG_DEBUG_ON or L.MSG_DEBUG_OFF)
end

function Module:_StartDebugSession()
    local acc = self.acc
    if type(acc) ~= "table" then return end
    if self:IsDebug() then
        self:_Log(("%s ---- Sitzung (%s v%s, Peon v%s) ----"):format(
            date("%Y-%m-%d %H:%M:%S"), self.addonName, tostring(self.version), tostring(Peon.version)))
    else
        acc.debugLog = nil
    end
end

---------------------------------------------------------------------------
-- Eigene Slash-Befehle eines Moduls (zusaetzlich zu /peon <key>)
---------------------------------------------------------------------------
function Module:HandleSlash(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if not self.initialized then return end
    if cmd == "debug" and not self.opts.ownDebug then
        self:ToggleDebug()
    elseif self.opts.onSlash then
        self:Call("Slash", self.opts.onSlash, self, cmd, rest or "")
    else
        self:OpenOptions()
    end
end

function Module:_RegisterSlash(commands)
    local id = "PEON_" .. self.key:upper():gsub("[^%w]", "_")
    for i, command in ipairs(commands) do _G["SLASH_" .. id .. i] = command end
    SlashCmdList[id] = function(msg) self:HandleSlash(msg) end
end
