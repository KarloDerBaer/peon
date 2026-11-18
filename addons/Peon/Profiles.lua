-- Peon - Profiles.lua
-- Ab 0.25.0 (Kern-API 25): Profile. Ein Profil merkt sich die Einstellungen aller geladenen Peon-Module unter
-- einem Namen und spielt sie spaeter wieder ein, zum Beispiel auf einem anderen Charakter.
--
-- Was in ein Profil kommt: je Modul alle Schluessel aus opts.defaults, ausser opts.keepOnReset (Positionen, Zustand,
-- eigene Daten) und debug. Charakterwerte (opts.charKeys) gehoeren dazu, deshalb lassen sie sich so auf einen
-- anderen Charakter uebertragen. Daten der Module (Preise, Buch, Faenge ...) stehen nicht in defaults und bleiben,
-- wie sie sind. Ein Modul kann mit opts.noProfile = true ganz ausgelassen werden.
-- Gespeichert in PeonDB.profiles[Name] = { t = Zeit, mods = { [Modulschluessel] = { Schluessel = Wert } } },
-- je Konto, hoechstens Profiles.MAX Profile.
--
-- Schnittstelle (API 25, nur Erweiterung):
--   Peon.Profiles.List()        -> { { name, t, mods = Anzahl Module }, ... } nach Namen sortiert
--   Peon.Profiles.Save(name)    -> true, Anzahl Module | false, Grund ("name", "db", "full", "empty")
--   Peon.Profiles.Load(name)    -> true, Anzahl Module, Anzahl Werte | false, Grund ("missing")
--   Peon.Profiles.Delete(name)  -> true | false
--   Peon.Profiles.Values(mod)   -> Werte eines Moduls fuer ein Profil (Kopie) oder nil
-- Befehl: /peon profil [liste | speichern <Name> | laden <Name> | loeschen <Name>], Optionsseite Peon > Profile.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local P = {}
ns.Profiles = P
Peon.Profiles = P

P.MAX = 20
P.NAME_MAX = 40

local function Store()
    local db = Peon.db
    if type(db) ~= "table" then return nil end
    if type(db.profiles) ~= "table" then db.profiles = {} end
    return db.profiles
end

local function Now() return (time and time()) or 0 end

-- Name pruefen: ohne Farbcodes und Zeilenumbrueche, 1 bis NAME_MAX Zeichen
function P.CleanName(name)
    if type(name) ~= "string" or Peon.IsSecret(name) then return nil end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[|\r\n]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > P.NAME_MAX then return nil end
    return name
end

-- Gross- und Kleinschreibung egal beim Suchen
local function Find(s, name)
    if s[name] then return name end
    local low = name:lower()
    for k in pairs(s) do if type(k) == "string" and k:lower() == low then return k end end
    return nil
end

function P.Values(mod)
    local o = mod and mod.opts
    if not (o and mod.db and type(o.defaults) == "table") or o.noProfile then return nil end
    local keep = o.keepOnReset or {}
    local out, n = {}, 0
    for k in pairs(o.defaults) do
        if k ~= "debug" and not keep[k] then
            local v = mod.db[k]
            if v ~= nil then out[k] = Peon.CopyTable(v); n = n + 1 end
        end
    end
    return n > 0 and out or nil
end

function P.List()
    local s = Store()
    local out = {}
    for name, p in pairs(s or {}) do
        if type(name) == "string" and type(p) == "table" then
            local n = 0
            for _ in pairs(type(p.mods) == "table" and p.mods or {}) do n = n + 1 end
            out[#out + 1] = { name = name, t = tonumber(p.t) or 0, mods = n }
        end
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

function P.Save(name)
    name = P.CleanName(name)
    if not name then return false, "name" end
    local s = Store()
    if not s then return false, "db" end
    local key = Find(s, name)
    if not key then
        local c = 0
        for _ in pairs(s) do c = c + 1 end
        if c >= P.MAX then return false, "full" end
        key = name
    end
    local mods, n = {}, 0
    for _, mod in ipairs(Peon.order or {}) do
        local v = P.Values(mod)
        if v then mods[mod.key] = v; n = n + 1 end
    end
    if n == 0 then return false, "empty" end
    s[key] = { t = Now(), mods = mods }
    return true, n
end

function P.Load(name)
    local s = Store()
    local key = s and type(name) == "string" and Find(s, name)
    local p = key and s[key]
    if type(p) ~= "table" or type(p.mods) ~= "table" then return false, "missing" end
    local mods, values = 0, 0
    for modKey, vals in pairs(p.mods) do
        local mod = type(vals) == "table" and Peon:GetModule(modKey)
        if mod and mod._ApplyProfile then
            local n = mod:_ApplyProfile(vals)
            if n > 0 then mods = mods + 1; values = values + n end
        end
    end
    return true, mods, values
end

function P.Delete(name)
    local s = Store()
    local key = s and type(name) == "string" and Find(s, name)
    if not key then return false end
    s[key] = nil
    return true
end

---------------------------------------------------------------------------
-- /peon profil [liste | speichern <Name> | laden <Name> | loeschen <Name>]
---------------------------------------------------------------------------
local function DateText(t)
    if not t or t <= 0 or not date then return "?" end
    return date("%d.%m.%Y %H:%M", t)
end

local function Why(reason)
    if reason == "name" then return L.PROFILE_BAD_NAME:format(P.NAME_MAX) end
    if reason == "full" then return L.PROFILE_FULL:format(P.MAX) end
    if reason == "empty" then return L.PROFILE_EMPTY end
    if reason == "missing" then return L.PROFILE_MISSING end
    return L.PROFILE_NO_DB
end

function P.ListText()
    local list = P.List()
    if #list == 0 then return L.PROFILE_NONE end
    local parts = {}
    for _, p in ipairs(list) do parts[#parts + 1] = L.PROFILE_ITEM:format(p.name, DateText(p.t), p.mods) end
    return table.concat(parts, "\n")
end

function P.DoSave(name)
    local ok, n = P.Save(name)
    if ok then Peon.Print(L.PROFILE_SAVED:format(P.CleanName(name), n)) else Peon.Print(Why(n)) end
    if P.option then P.option.Refresh() end
    return ok
end

function P.DoLoad(name)
    if InCombatLockdown and InCombatLockdown() then Peon.Print(L.PROFILE_COMBAT) return false end
    local ok, mods, values = P.Load(name)
    if ok then Peon.Print(L.PROFILE_LOADED:format(name, mods, values)) else Peon.Print(Why(mods)) end
    if P.option then P.option.Refresh() end
    return ok
end

function P.DoDelete(name)
    local ok = P.Delete(name)
    Peon.Print(ok and L.PROFILE_DELETED:format(name) or L.PROFILE_MISSING)
    if P.option then P.option.Refresh() end
    return ok
end

function P.Slash(rest)
    local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    arg = arg or ""
    if sub == "speichern" or sub == "save" then
        P.DoSave(arg)
    elseif sub == "laden" or sub == "load" then
        P.DoLoad(arg)
    elseif sub == "loeschen" or sub == "löschen" or sub == "delete" then
        P.DoDelete(arg)
    else
        Peon.Print(L.PROFILE_TITLE)
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
    b:SetSize(width or 110, 22)
    b:SetText(text)
    return b
end

function P.CreatePanel()
    local panel = CreateFrame("Frame")
    panel.name = L.PROFILE_PAGE
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.PROFILE_PAGE)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.PROFILE_HINT)

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    label:SetText(L.PROFILE_NAME)
    local ok, box = pcall(CreateFrame, "EditBox", nil, panel, "InputBoxTemplate")
    if not ok or not box then box = CreateFrame("EditBox", nil, panel) end
    box:SetSize(220, 22)
    box:SetAutoFocus(false)
    box:SetMaxLetters(P.NAME_MAX)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -6)
    local save = Button(panel, L.PROFILE_BTN_SAVE)
    save:SetPoint("LEFT", box, "RIGHT", 10, 0)
    local load = Button(panel, L.PROFILE_BTN_LOAD)
    load:SetPoint("LEFT", save, "RIGHT", 6, 0)
    local del = Button(panel, L.PROFILE_BTN_DELETE)
    del:SetPoint("LEFT", load, "RIGHT", 6, 0)

    local listTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -18)
    listTitle:SetText(L.PROFILE_TITLE)
    local list = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    list:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 8, -6)
    list:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    list:SetJustifyH("LEFT")
    list:SetSpacing(3)

    local function Name() return box:GetText() or "" end
    local function Refresh() list:SetText(P.ListText()) end
    save:SetScript("OnClick", function() P.DoSave(Name()) end)
    load:SetScript("OnClick", function() P.DoLoad(Name()) end)
    del:SetScript("OnClick", function() P.DoDelete(Name()) end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel:SetScript("OnShow", Refresh)
    P.option = { panel = panel, box = box, save = save, load = load, delete = del, list = list, Refresh = Refresh }
    return panel
end
