-- Peon - Options.lua
-- Eintrag "Peon" unter Einstellungen > AddOns mit einer Uebersicht der Module.
-- Module haengen ihre eigene Seite per mod:RegisterOptions(panel) darunter.
--
-- Ablauf: Module melden ihre Seiten bei ADDON_LOADED an; der Kern registriert die Kategorie
-- erst bei PLAYER_LOGIN, wenn alle Module geladen sind. Spaeter nachgeladene Module oder Clients
-- ohne Unterkategorien bekommen einen eigenen Eintrag.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L
local Module = Peon.ModulePrototype

local panel, category
local registered = false
local pending = {}   -- Module, deren Seite auf die Registrierung wartet

local HasSettings = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
local HasSub = HasSettings and Settings.RegisterCanvasLayoutSubcategory

---------------------------------------------------------------------------
-- Uebersicht
---------------------------------------------------------------------------
-- Alle installierten Peon-Addons (auch deaktivierte), damit die Uebersicht vollstaendig ist
local function InstalledModules()
    local list = {}
    local getNum = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if getNum and getInfo then
        for i = 1, getNum() do
            local name = getInfo(i)
            if type(name) == "string" and name:match("^Peon_") then list[#list + 1] = name end
        end
    end
    table.sort(list)
    return list
end

local function ModuleLines()
    local lines = {}
    for _, name in ipairs(InstalledModules()) do
        local mod = Peon.modules[name]
        if mod then
            lines[#lines + 1] = ("|cff33ccff%s|r  v%s  |cff80ff80%s|r  (/peon %s)"):format(
                mod.title, tostring(mod.version), L.STATE_LOADED, mod.key)
        else
            local title = Peon.GetMetadata(name, "Title") or name
            local version = Peon.GetMetadata(name, "Version") or "?"
            lines[#lines + 1] = ("|cff808080%s  v%s  %s|r"):format(title, version, L.STATE_DISABLED)
        end
    end
    return lines
end
ns.ModuleLines = ModuleLines

function ns.CreateOptions()
    panel = CreateFrame("Frame")
    panel.name = "Peon"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(("|c%sPeon|r"):format(Peon.COLOR))

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    version:SetText(L.OPT_VERSION:format(tostring(Peon.version)))

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(L.OPT_DESC)

    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    header:SetText(L.OPT_MODULES)

    local list = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -8)
    list:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    list:SetJustifyH("LEFT")
    list:SetSpacing(4)

    panel:SetScript("OnShow", function()
        local lines = ModuleLines()
        list:SetText(#lines > 0 and table.concat(lines, "\n") or L.MSG_NO_MODULES)
    end)

    if HasSettings then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Peon.category = category
    end
end

local function RegisterStandalone(mod)
    if HasSettings then
        mod.category = Settings.RegisterCanvasLayoutCategory(mod.panel, mod.panel.name)
        Settings.RegisterAddOnCategory(mod.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(mod.panel)
    end
end

local function RegisterModulePanel(mod)
    if HasSub and category then
        mod.category = Settings.RegisterCanvasLayoutSubcategory(category, mod.panel, mod.panel.name)
    elseif HasSettings then
        RegisterStandalone(mod)
    elseif InterfaceOptions_AddCategory then
        mod.panel.parent = "Peon"
        InterfaceOptions_AddCategory(mod.panel)
    end
end

-- PLAYER_LOGIN: Unterseiten anhaengen, dann die Kategorie "Peon" einmalig registrieren
function ns.FinishOptions()
    if registered then return end
    if HasSettings and category then
        for _, mod in ipairs(pending) do RegisterModulePanel(mod) end
        Settings.RegisterAddOnCategory(category)
    elseif panel and InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        for _, mod in ipairs(pending) do RegisterModulePanel(mod) end
    end
    wipe(pending)
    registered = true
end

---------------------------------------------------------------------------
-- Modul-Seiten
---------------------------------------------------------------------------
-- panel: Frame des Moduls; panel.name wird auf den Modultitel gesetzt, wenn leer
function Module:RegisterOptions(modPanel)
    if not modPanel or self.panel then return end
    modPanel.name = modPanel.name or self.title
    self.panel = modPanel
    if registered then
        RegisterStandalone(self)    -- nach dem Login nachgeladen
    else
        pending[#pending + 1] = self
    end
end

local function OpenCategory(cat, frame)
    if InCombatLockdown() then
        Peon.Print(L.MSG_COMBAT_OPTIONS)
        return
    end
    if cat and Settings and Settings.OpenToCategory then
        local id = (cat.GetID and cat:GetID()) or cat.ID or (frame and frame.name)
        Settings.OpenToCategory(id)
    elseif frame and InterfaceOptionsFrame_OpenToCategory then
        -- bekannter Blizzard-Bug: beim ersten Aufruf zweimal noetig
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame)
    else
        Peon.Print(L.MSG_NO_OPTIONS)
    end
end

function Module:OpenOptions()
    if self.panel then
        OpenCategory(self.category, self.panel)
    else
        Peon:OpenOptions()
    end
end

function Peon:OpenOptions()
    OpenCategory(category, panel)
end
