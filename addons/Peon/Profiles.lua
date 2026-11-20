-- Peon - Profiles.lua
-- Profile fuer die Einstellungen aller Peon-Module.
--   Ab 0.25.0 (Kern-API 25): Profile als gespeicherte Staende (Save, Load, Delete, List, Values).
--   Ab 0.26.0 (Kern-API 26): laufende Profile. Es gibt immer "Standard", alle Charaktere nutzen es, bis man fuer
--   einen Charakter ein anderes waehlt. Was man einstellt, gilt sofort fuer alle Charaktere mit demselben Profil.
--
-- Was zu einem Profil gehoert: je Modul alle Schluessel aus opts.defaults ausser keepOnReset (Positionen, Zustand,
-- eigene Daten), charKeys (bleiben je Charakter) und debug. Ein Modul mit opts.noProfile = true hat kein Profil.
-- Die Daten der Module (Preise, Buch, Faenge ...) stehen nicht in defaults und gelten fuer das ganze Konto.
--
-- Speicher:
--   PeonDB.profileList[Name] = { t = angelegt }        Liste aller Profile (immer mit "Standard")
--   PeonDB.profileUsers["Name-Realm"] = Profil          wer welches Profil nutzt (nur zur Anzeige)
--   PeonCharDB.profile = Name                            Profil dieses Charakters (fehlt = Standard)
--   je Modul: acc._profile = aktives Profil (seine Werte liegen wie immer direkt in acc), acc._profiles[Name] = Werte
--   der anderen Profile. So lesen und schreiben die Module ihre Einstellungen wie bisher.
--   Beim Einloggen setzt der Kern je Modul das Profil des Charakters ein (Module:_SwitchProfile in Module.lua).
--
-- Schnittstelle:
--   API 25: Peon.Profiles.List(), Save(name) (aktuelle Einstellungen unter name ablegen), Load(name) (Werte von name
--           ins aktuelle Profil kopieren), Delete(name), Values(mod)
--   API 26: Peon.Profiles.Current(), Use(name) (dieser Charakter nutzt name, fehlt es, entsteht es als Kopie),
--           Create(name, leer) (neues Profil, Kopie des aktuellen oder mit leer = true aus Standardwerten), MAX
-- Befehl: /peon profil [benutzen | neu | leer | kopieren | loeschen <Name> | standard], Optionsseite Peon > Profile.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local P = {}
ns.Profiles = P
Peon.Profiles = P

P.MAX = 20
P.NAME_MAX = 40
P.DEFAULT = "Standard"

local function Now() return (time and time()) or 0 end

local function List()
    local db = Peon.db
    if type(db) ~= "table" then return nil end
    if type(db.profileList) ~= "table" then db.profileList = {} end
    if type(db.profileList[P.DEFAULT]) ~= "table" then db.profileList[P.DEFAULT] = { t = Now() } end
    return db.profileList
end

local function CharKey()
    local name = UnitName and UnitName("player")
    local realm = Peon.RealmName and Peon.RealmName() or (GetRealmName and GetRealmName())   -- ab API 27 mit Rueckfall
    if type(name) ~= "string" or Peon.IsSecret(name) then return nil end
    if type(realm) == "string" and not Peon.IsSecret(realm) and realm ~= "" then return name .. "-" .. realm end
    return name
end

-- Name pruefen: ohne Farbcodes und Zeilenumbrueche, 1 bis NAME_MAX Zeichen
function P.CleanName(name)
    if type(name) ~= "string" or Peon.IsSecret(name) then return nil end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[|\r\n]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > P.NAME_MAX then return nil end
    return name
end

-- Vorhandenes Profil suchen, Gross- und Kleinschreibung egal. Rueckgabe: Name wie gespeichert oder nil
function P.Find(name)
    local l = List()
    name = P.CleanName(name)
    if not (l and name) then return nil end
    if l[name] then return name end
    local low = name:lower()
    for k in pairs(l) do if k:lower() == low then return k end end
    return nil
end

-- Profil dieses Charakters (gibt es das gewaehlte nicht mehr, gilt Standard)
function P.Current()
    local c = rawget(_G, "PeonCharDB")
    local name = type(c) == "table" and c.profile
    return (type(name) == "string" and P.Find(name)) or P.DEFAULT
end

local function Modules()
    local out = {}
    for _, mod in ipairs(Peon.order or {}) do
        if mod.initialized and mod.acc and mod._ProfileKeys and #mod:_ProfileKeys() > 0 then out[#out + 1] = mod end
    end
    return out
end

---------------------------------------------------------------------------
-- Start: Kern (ADDON_LOADED von Peon) und je Modul (Module:_InitDB)
---------------------------------------------------------------------------
function P.Init()
    if type(rawget(_G, "PeonCharDB")) ~= "table" then PeonCharDB = {} end
    local db = Peon.db
    if type(db) ~= "table" then return end
    local l = List()
    -- Staende aus 0.25.0 (PeonDB.profiles[Name] = { t, mods }) werden zu Profilen, die Werte holen sich die Module
    if type(db.profiles) == "table" then
        db.profileSeed = type(db.profileSeed) == "table" and db.profileSeed or {}
        for name, p in pairs(db.profiles) do
            local n = P.CleanName(name)
            if n and type(p) == "table" and type(p.mods) == "table" then
                if not l[n] then l[n] = { t = tonumber(p.t) or Now() } end
                db.profileSeed[n] = p.mods
            end
        end
        db.profiles = nil
    end
    if type(db.profileUsers) ~= "table" then db.profileUsers = {} end
    local key = CharKey()
    if key then db.profileUsers[key] = P.Current() end
end

-- Je Modul beim Laden: Speicher anlegen, alte Staende uebernehmen, Geloeschtes entfernen, Profil einsetzen
function P._Attach(mod)
    local acc = mod.acc
    if not acc or #mod:_ProfileKeys() == 0 then return end
    local l = List()
    if not l then return end
    if type(acc._profiles) ~= "table" then acc._profiles = {} end
    if type(acc._profile) ~= "string" then acc._profile = P.DEFAULT end   -- bisherige Einstellungen = Standard
    local seed = Peon.db.profileSeed
    if type(seed) == "table" then
        for name, mods in pairs(seed) do
            if acc._profiles[name] == nil and name ~= acc._profile and type(mods[mod.key]) == "table" then
                acc._profiles[name] = Peon.CopyTable(mods[mod.key])
            end
        end
    end
    for name in pairs(acc._profiles) do if not l[name] then acc._profiles[name] = nil end end
    if not l[acc._profile] then
        -- Das Profil, das zuletzt aktiv war, gibt es nicht mehr: seine Werte verwerfen, Standard einsetzen
        local std = acc._profiles[P.DEFAULT]
        acc._profile = P.DEFAULT
        acc._profiles[P.DEFAULT] = nil
        if type(std) == "table" then for k, v in pairs(std) do acc[k] = v end end
    end
    mod:_SwitchProfile(P.Current(), false)
end

---------------------------------------------------------------------------
-- API 26: laufende Profile
---------------------------------------------------------------------------
function P.Create(name, empty)
    local l = List()
    if not l then return false, "db" end
    name = P.CleanName(name)
    if not name then return false, "name" end
    if P.Find(name) then return false, "exists" end
    local c = 0
    for _ in pairs(l) do c = c + 1 end
    if c >= P.MAX then return false, "full" end
    l[name] = { t = Now() }
    local cur = P.Current()
    for _, mod in ipairs(Modules()) do
        mod.acc._profiles = type(mod.acc._profiles) == "table" and mod.acc._profiles or {}
        mod.acc._profiles[name] = empty and {} or mod:_ProfileValues(cur)
    end
    return true, name
end

function P.Use(name)
    local l = List()
    if not l then return false, "db" end
    local found = P.Find(name)
    if not found then
        local ok, why = P.Create(name)
        if not ok then return false, why end
        found = why
    end
    PeonCharDB = type(rawget(_G, "PeonCharDB")) == "table" and PeonCharDB or {}
    PeonCharDB.profile = found
    local key = CharKey()
    if key and type(Peon.db.profileUsers) == "table" then Peon.db.profileUsers[key] = found end
    local n = 0
    for _, mod in ipairs(Modules()) do
        if mod:_SwitchProfile(found, true) then n = n + 1 end
    end
    return true, n, found
end

---------------------------------------------------------------------------
-- API 25 (gleiche Bedeutung wie in 0.25.0)
---------------------------------------------------------------------------
function P.Values(mod)
    if not (mod and mod._ProfileValues) then return nil end
    local v = mod:_ProfileValues(P.Current())
    return (v and next(v)) and v or nil
end

-- { { name, t, mods, users, current }, ... }: Standard zuerst, dann nach Namen
function P.List()
    local l = List()
    local out = {}
    if not l then return out end
    local users = {}
    for _, p in pairs(type(Peon.db.profileUsers) == "table" and Peon.db.profileUsers or {}) do users[p] = (users[p] or 0) + 1 end
    local cur = P.Current()
    for name, p in pairs(l) do
        out[#out + 1] = { name = name, t = tonumber(p.t) or 0, mods = #Modules(), users = users[name] or 0, current = name == cur }
    end
    table.sort(out, function(a, b)
        if (a.name == P.DEFAULT) ~= (b.name == P.DEFAULT) then return a.name == P.DEFAULT end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

-- Aktuelle Einstellungen unter name ablegen (neu oder ueberschreiben), ohne zu wechseln
function P.Save(name)
    local l = List()
    if not l then return false, "db" end
    name = P.CleanName(name)
    if not name then return false, "name" end
    local key = P.Find(name)
    if not key then
        local ok, why = P.Create(name)
        if not ok then return false, why end
        key = why
    end
    local mods = Modules()
    if #mods == 0 then return false, "empty" end
    local cur = P.Current()
    if key ~= cur then
        for _, mod in ipairs(mods) do mod.acc._profiles[key] = mod:_ProfileValues(cur) end
    end
    l[key].t = Now()
    return true, #mods
end

-- Werte des Profils name ins aktuelle Profil kopieren
function P.Load(name)
    local key = P.Find(name)
    if not key then return false, "missing" end
    local mods, values = 0, 0
    for _, mod in ipairs(Modules()) do
        local vals = mod:_ProfileValues(key)
        if vals then
            local n = mod:_ApplyProfile(vals)
            if n > 0 then mods = mods + 1; values = values + n end
        end
    end
    return true, mods, values
end

function P.Delete(name)
    local l = List()
    local key = P.Find(name)
    if not (l and key) or key == P.DEFAULT then return false end
    if P.Current() == key then P.Use(P.DEFAULT) end
    l[key] = nil
    for _, mod in ipairs(Modules()) do
        if type(mod.acc._profiles) == "table" then mod.acc._profiles[key] = nil end
    end
    if type(Peon.db.profileSeed) == "table" then Peon.db.profileSeed[key] = nil end
    for who, p in pairs(type(Peon.db.profileUsers) == "table" and Peon.db.profileUsers or {}) do
        if p == key then Peon.db.profileUsers[who] = P.DEFAULT end
    end
    return true
end

---------------------------------------------------------------------------
-- /peon profil [benutzen | neu | leer | kopieren | loeschen <Name> | standard]
---------------------------------------------------------------------------
local function Why(reason)
    if reason == "name" then return L.PROFILE_BAD_NAME:format(P.NAME_MAX) end
    if reason == "full" then return L.PROFILE_FULL:format(P.MAX) end
    if reason == "exists" then return L.PROFILE_EXISTS end
    if reason == "empty" then return L.PROFILE_EMPTY end
    if reason == "missing" then return L.PROFILE_MISSING end
    return L.PROFILE_NO_DB
end

local function Refresh() if P.option then P.option.Refresh() end end

local function Combat()
    if InCombatLockdown and InCombatLockdown() then Peon.Print(L.PROFILE_COMBAT) return true end
    return false
end

function P.ListText()
    local parts = {}
    for _, p in ipairs(P.List()) do
        local line = L.PROFILE_ITEM:format(p.name, p.users)
        if p.current then line = line .. " " .. L.PROFILE_THIS end
        parts[#parts + 1] = line
    end
    return table.concat(parts, "\n")
end

function P.DoUse(name)
    if Combat() then return false end
    local ok, n, found = P.Use(name)
    if ok then Peon.Print(L.PROFILE_USED:format(found)) else Peon.Print(Why(n)) end
    Refresh()
    return ok
end

function P.DoCreate(name, empty)
    if Combat() then return false end
    local ok, why = P.Create(name, empty)
    if not ok then Peon.Print(Why(why)); Refresh(); return false end
    return P.DoUse(why)
end

function P.DoLoad(name)
    if Combat() then return false end
    local ok, mods, values = P.Load(name)
    if ok then Peon.Print(L.PROFILE_LOADED:format(P.Find(name), P.Current(), mods, values)) else Peon.Print(Why(mods)) end
    Refresh()
    return ok
end

function P.DoDelete(name)
    if Combat() then return false end
    local key = P.Find(name)
    local ok = P.Delete(name)
    if ok then Peon.Print(L.PROFILE_DELETED:format(key))
    elseif key == P.DEFAULT then Peon.Print(L.PROFILE_KEEP_DEFAULT)
    else Peon.Print(L.PROFILE_MISSING) end
    Refresh()
    return ok
end

-- API 25: speichern (ohne Wechsel)
function P.DoSave(name)
    local ok, n = P.Save(name)
    if ok then Peon.Print(L.PROFILE_SAVED:format(P.Find(name), n)) else Peon.Print(Why(n)) end
    Refresh()
    return ok
end

function P.Slash(rest)
    local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    arg = arg or ""
    if sub == "benutzen" or sub == "use" or sub == "wechseln" then P.DoUse(arg)
    elseif sub == "neu" or sub == "new" then P.DoCreate(arg, false)
    elseif sub == "leer" or sub == "empty" then P.DoCreate(arg, true)
    elseif sub == "kopieren" or sub == "copy" or sub == "laden" or sub == "load" then P.DoLoad(arg)
    elseif sub == "speichern" or sub == "save" then P.DoSave(arg)
    elseif sub == "loeschen" or sub == "löschen" or sub == "delete" then P.DoDelete(arg)
    elseif sub == "standard" or sub == "default" then P.DoUse(P.DEFAULT)
    else
        Peon.Print(L.PROFILE_STATUS:format(P.Current()))
        for line in P.ListText():gmatch("[^\n]+") do Peon.Print("  " .. line) end
        for _, line in ipairs(L.PROFILE_HELP) do Peon.Print(line) end
    end
end

---------------------------------------------------------------------------
-- Optionsseite Peon > Profile (eigene Unterseite, damit die Seite Peon nicht zu lang wird)
---------------------------------------------------------------------------
local function Button(parent, text, width)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width or 120, 22)
    b:SetText(text)
    return b
end

local function Text(panel, font, anchor, x, y)
    local fs = panel:CreateFontString(nil, "ARTWORK", font)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)
    fs:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    fs:SetJustifyH("LEFT")
    return fs
end

function P.CreatePanel()
    local panel = CreateFrame("Frame")
    panel.name = L.PROFILE_PAGE
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.PROFILE_PAGE)
    local hint = Text(panel, "GameFontHighlight", title, 0, -8)
    hint:SetText(L.PROFILE_HINT)
    local status = Text(panel, "GameFontNormal", hint, 0, -14)

    local label = Text(panel, "GameFontNormal", status, 0, -16)
    label:SetText(L.PROFILE_NAME)
    local ok, box = pcall(CreateFrame, "EditBox", nil, panel, "InputBoxTemplate")
    if not ok or not box then box = CreateFrame("EditBox", nil, panel) end
    box:SetSize(220, 22)
    box:SetAutoFocus(false)
    box:SetMaxLetters(P.NAME_MAX)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -6)
    local use = Button(panel, L.PROFILE_BTN_USE)
    use:SetPoint("LEFT", box, "RIGHT", 10, 0)
    local new = Button(panel, L.PROFILE_BTN_EMPTY)
    new:SetPoint("LEFT", use, "RIGHT", 6, 0)
    local copy = Button(panel, L.PROFILE_BTN_COPY)
    copy:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -8)
    local del = Button(panel, L.PROFILE_BTN_DELETE)
    del:SetPoint("LEFT", copy, "RIGHT", 6, 0)
    local std = Button(panel, L.PROFILE_BTN_DEFAULT, 160)
    std:SetPoint("LEFT", del, "RIGHT", 6, 0)

    local listTitle = Text(panel, "GameFontNormal", copy, 4, -18)
    listTitle:SetText(L.PROFILE_TITLE)
    local list = Text(panel, "GameFontHighlight", listTitle, 8, -6)
    list:SetSpacing(3)
    local foot = Text(panel, "GameFontHighlightSmall", list, -8, -14)
    foot:SetText(L.PROFILE_FOOT)

    local function Name() return box:GetText() or "" end
    local function Refresh()
        status:SetText(L.PROFILE_STATUS:format(P.Current()))
        list:SetText(P.ListText())
    end
    use:SetScript("OnClick", function() P.DoUse(Name()) end)
    new:SetScript("OnClick", function() P.DoCreate(Name(), true) end)
    copy:SetScript("OnClick", function() P.DoLoad(Name()) end)
    del:SetScript("OnClick", function() P.DoDelete(Name()) end)
    std:SetScript("OnClick", function() P.DoUse(P.DEFAULT) end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel:SetScript("OnShow", Refresh)
    P.option = { panel = panel, box = box, use = use, empty = new, copy = copy, delete = del, default = std,
        status = status, list = list, Refresh = Refresh,
        save = use }   -- save: Name aus 0.25.0
    return panel
end
