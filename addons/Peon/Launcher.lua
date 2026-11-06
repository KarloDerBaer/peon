-- Peon - Launcher.lua
-- Starter (ab API 14): der allgemeine Eintrag eines Moduls fuer Anzeigen wie Peon_Panel.
-- Symbol, Klick, Tooltip, Menue und waehlbare Texte. Der Kern zeigt selbst nichts an.
--
--   local s = mod:NewLauncher({
--       icon = "Interface\\Icons\\INV_Misc_Bag_08",
--       title = "Bags",                               -- Standard: Titel des Moduls
--       key = "bags",                                 -- Standard: Schluessel des Moduls
--       showKey = "minimapShow",                      -- Einstellung des Minimap-Buttons, nil = keiner
--       onClick = function(mod, button, owner) end,   -- owner = geklickter Knopf
--       onTooltip = function(mod, tooltip) end,
--       hint = "Linksklick: ...",
--       update = function(mod, iconTexture) end,      -- Symbol faerben
--       menu = function(mod, root) end,               -- eigene Eintraege im Kontextmenue
--       texts = { { key = "free", label = "Freie Plaetze", get = function(mod) return "23 frei" end } },
--       defaultText = "free",                         -- nil = anfangs kein Text
--       openOptions = function() end,                 -- Standard: Optionsseite des Moduls
--   })
--   s:Refresh()                     -- Symbol und Text neu zeichnen
--   Peon.GetLaunchers()             -- Liste aller Starter
--   Peon.OnLauncherAdded(fn)        -- fn(starter), auch fuer alle schon angelegten
--   Peon.OnLauncherRefresh(fn)      -- fn(starter) bei s:Refresh()
--
-- mod:NewMinimapButton legt selbst einen Starter an.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local Module = Peon.ModulePrototype

local PANEL_ADDON = "Peon_Panel"

local launchers = {}
local addedFns, refreshFns = {}, {}

local Launcher = {}
Launcher.__index = Launcher

---------------------------------------------------------------------------
-- Minimap-Buttons, die Peon_Panel ausgeblendet hat (PeonDB.panelHid)
-- Laeuft Panel nicht mehr, kommen genau diese Buttons zurueck. Geprueft wird erst ab dem Login,
-- vorher sind noch nicht alle Addons geladen.
---------------------------------------------------------------------------
function Peon.SetPanelHid(key, hidden)
    if type(Peon.db) ~= "table" or type(key) ~= "string" then return end
    if type(Peon.db.panelHid) ~= "table" then Peon.db.panelHid = {} end
    Peon.db.panelHid[key] = hidden and true or nil
end

local function Restore(l)
    if not Peon.loggedIn or Peon.IsAddOnLoaded(PANEL_ADDON) then return end
    local hid = type(Peon.db) == "table" and Peon.db.panelHid
    if type(hid) ~= "table" or not hid[l.key] then return end
    hid[l.key] = nil
    l:SetMinimapShown(true)
end

function Peon._RestoreLaunchers()
    for _, l in ipairs(launchers) do Restore(l) end
end

---------------------------------------------------------------------------
-- Starter
---------------------------------------------------------------------------
function Module:NewLauncher(o)
    if self.launcher then return self.launcher end
    o = o or {}
    local l = setmetatable({
        mod = self, key = o.key or self.key, title = o.title or self.title, icon = o.icon,
        showKey = o.showKey, onClick = o.onClick, onTooltip = o.onTooltip, hint = o.hint,
        update = o.update, menu = o.menu, texts = o.texts or {}, defaultText = o.defaultText,
        openOptions = o.openOptions,
    }, Launcher)
    self.launcher = l
    launchers[#launchers + 1] = l
    Restore(l)
    for _, fn in ipairs(addedFns) do self:Call("Starter", fn, l) end
    return l
end

function Launcher:HasMinimap() return self.showKey ~= nil end

function Launcher:IsMinimapShown()
    local db = self.mod.db
    return self.showKey ~= nil and db ~= nil and db[self.showKey] ~= false
end

function Launcher:SetMinimapShown(on)
    local db = self.mod.db
    if self.showKey == nil or db == nil then return end
    db[self.showKey] = on and true or false
    self.mod:Fire("CHANGED", self.showKey)
end

function Launcher:Click(button, owner)
    if self.onClick then self.mod:Call("Starter", self.onClick, self.mod, button, owner) end
end

function Launcher:FillTooltip(tooltip)
    if self.onTooltip then self.mod:Call("Starter", self.onTooltip, self.mod, tooltip) end
end

function Launcher:FillMenu(root)
    if self.menu then self.mod:Call("Starter", self.menu, self.mod, root) end
end

function Launcher:ColorIcon(texture)
    if self.update then self.mod:Call("Starter", self.update, self.mod, texture) end
end

function Launcher:OpenOptions()
    if self.openOptions then
        self.mod:Call("Starter", self.openOptions)
    else
        self.mod:OpenOptions()
    end
end

-- Text zur Auswahl key, nil wenn es ihn nicht gibt oder er nichts liefert. Geheime Werte werden nicht gezeigt.
function Launcher:GetText(key)
    for _, t in ipairs(self.texts) do
        if t.key == key then
            local ok, text = pcall(t.get, self.mod)
            if not ok then
                self.mod:ReportError("Starter", text)
                return nil
            end
            if text == nil or Peon.IsSecret(text) then return nil end
            return tostring(text)
        end
    end
    return nil
end

function Launcher:Refresh()
    for _, fn in ipairs(refreshFns) do self.mod:Call("Starter", fn, self) end
end

function Peon.GetLaunchers()
    local copy = {}
    for i, l in ipairs(launchers) do copy[i] = l end
    return copy
end

function Peon.OnLauncherAdded(fn)
    addedFns[#addedFns + 1] = fn
    for _, l in ipairs(launchers) do l.mod:Call("Starter", fn, l) end
end

function Peon.OnLauncherRefresh(fn)
    refreshFns[#refreshFns + 1] = fn
end

---------------------------------------------------------------------------
-- Kurze Zahlen fuer knappe Anzeigen: 950, 12,3k, 1,2M (mit Punkt ausser in deutsch)
---------------------------------------------------------------------------
local function Short(v, unit)
    local s = ("%.1f"):format(v) .. unit
    if GetLocale() == "deDE" then s = s:gsub("%.", ",") end
    return s
end

function Peon.ShortNumber(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1000000 then return Short(n / 1000000, "M") end
    if n >= 1000 then return Short(n / 1000, "k") end
    return ("%.0f"):format(n)
end

-- Geldbetrag kurz: 45s, 950g, 12,3k g
function Peon.ShortGold(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    if gold < 1 then return ("%.0fs"):format(math.floor(copper / 100)) end
    if gold < 1000 then return ("%.0fg"):format(gold) end
    return Peon.ShortNumber(gold) .. " g"
end
