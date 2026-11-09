-- Peon - ItemMenu.lua
-- Kontextmenue auf Gegenstaenden (API 16, ab Peon 0.16; Konzept Peon_Broker_Umbau.md, Abschnitt 9).
-- Strg+Rechtsklick (einstellbar) auf einen Gegenstand oeffnet ein Menue, egal wo: Taschen, Bank, Haendler, Quest,
-- Beute, Post, Berufe, Auktionshaus, Chat-Links. Jedes Modul haengt seine Eintraege an:
--
--   Peon.AddItemMenu(addonName, function(root, item) root:CreateButton("Info", function() ... end) end, order)
--     item = { id, link, name }; order = Reihenfolge (kleiner zuerst, Standard 100). Zwischen Modulen eine Trennlinie.
--   Peon.OpenItemMenu(item [, owner])   Menue fuer einen Gegenstand oeffnen (z. B. aus eigenen Listen)
--   Peon.ItemMenuEntries()              Anzahl angemeldeter Module
--
-- Erkennung wie Ledgers Alt+Klick (Pick.lua): Mausklick (GLOBAL_MOUSE_DOWN) und der Gegenstand im sichtbaren
-- Tooltip, dazu HandleModifiedItemClick fuer Klicks auf Links. Nicht auf Aktionsleisten.
-- Umschalt+Rechtsklick ist bei Blizzard belegt (Stapel teilen, mehrere Stapel kaufen, Kisten oeffnen), darum
-- Standard Strg+Rechtsklick. Dazu die Tastenbelegung "Peon: Gegenstandsmenue" (Bindings.xml) fuer eine Taste,
-- die das Menue fuer den Gegenstand unter der Maus oeffnet.

local ADDON_NAME, ns = ...
local L = Peon.L

local M = {}
ns.ItemMenu = M

M.DEDUP = 0.4                 -- Sekunden: derselbe Klick kommt ueber zwei Wege
M.DEFAULT = "CTRL-RightButton"
-- Waehlbare Klicks: { Wert, Text }
M.CLICKS = {
    { "CTRL-RightButton",  "ITEMMENU_CTRL_RIGHT" },
    { "ALT-RightButton",   "ITEMMENU_ALT_RIGHT" },
    { "SHIFT-RightButton", "ITEMMENU_SHIFT_RIGHT" },
    { "CTRL-MiddleButton", "ITEMMENU_CTRL_MIDDLE" },
    { "MiddleButton",      "ITEMMENU_MIDDLE" },
    { "off",               "ITEMMENU_OFF" },
}
M.providers = {}

function Peon.AddItemMenu(addonName, fn, order)
    if type(addonName) ~= "string" or type(fn) ~= "function" then return false end
    for _, p in ipairs(M.providers) do
        if p.addon == addonName then p.fn, p.order = fn, tonumber(order) or p.order; return true end
    end
    M.providers[#M.providers + 1] = { addon = addonName, fn = fn, order = tonumber(order) or 100 }
    table.sort(M.providers, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.addon < b.addon end)
    return true
end

function Peon.ItemMenuEntries() return #M.providers end

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function M.IDFromLink(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

function M.ItemFromLink(link)
    local id = M.IDFromLink(link)
    if not id then return nil end
    return { id = id, link = link, name = link:match("%[(.-)%]") }
end

-- Aktionsleisten-Knopf? Dort loest ein Klick mit Taste zusaetzlich die Aktion aus, darum kein Menue
function M.IsActionButton(owner)
    if type(owner) ~= "table" then return false end
    if rawget(owner, "action") ~= nil and type(owner.action) == "number" then return true end
    local name = owner.GetName and owner:GetName()
    if type(name) ~= "string" or Peon.IsSecret(name) then return false end
    return name:find("ActionButton", 1, true) or name:find("MultiBar", 1, true) or name:find("StanceButton", 1, true)
        or name:find("PetAction", 1, true) or name:find("PossessButton", 1, true) or name:find("OverrideActionBar", 1, true)
        or false
end

-- Gegenstand im sichtbaren Tooltip (GameTooltip, sonst Chat-Link-Tooltip unter der Maus)
function M.TooltipItem()
    for _, tipName in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tip = rawget(_G, tipName)
        if type(tip) == "table" and tip.IsShown and tip:IsShown() and tip.GetItem then
            local ok, _, link = pcall(tip.GetItem, tip)
            local item = ok and M.ItemFromLink(link) or nil
            if item and tipName == "ItemRefTooltip" and not (tip.IsMouseOver and tip:IsMouseOver()) then item = nil end
            if item and tip.GetOwner and M.IsActionButton(tip:GetOwner()) then return nil end
            if item then return item end
        end
    end
    return nil
end

-- Passt der Klick zur Einstellung? button = "RightButton" usw.
function M.Matches(button)
    local want = (Peon.db and Peon.db.itemMenuClick) or M.DEFAULT
    if want == "off" or type(button) ~= "string" then return false end
    local mod, btn = want:match("^(%u+)%-(%a+)$")
    if not mod then mod, btn = nil, want end
    if button ~= btn then return false end
    local ctrl = IsControlKeyDown and IsControlKeyDown() or false
    local alt = IsAltKeyDown and IsAltKeyDown() or false
    local shift = IsShiftKeyDown and IsShiftKeyDown() or false
    return ctrl == (mod == "CTRL") and alt == (mod == "ALT") and shift == (mod == "SHIFT")
end

function Peon.OpenItemMenu(item, owner)
    if type(item) ~= "table" or not Num(item.id) or #M.providers == 0 then return false end
    local now = GetTime and GetTime() or 0
    if M.last == item.id and M.lastT and now - M.lastT < M.DEDUP then return true end
    M.last, M.lastT = item.id, now
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
    MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
        if root.CreateTitle then root:CreateTitle(item.name or ("item " .. item.id)) end
        local first = true
        for _, p in ipairs(M.providers) do
            if not first and root.CreateDivider then root:CreateDivider() end
            first = false
            local ok, err = pcall(p.fn, root, item)
            if not ok and Peon.RecordError then Peon.RecordError(p.addon, "Gegenstandsmenue", err) end
        end
    end)
    return true
end

function M.OnMouseDown(button)
    if not M.Matches(button) then return end
    local item = M.TooltipItem()
    if item then Peon.OpenItemMenu(item) end
end

function M.OnModifiedClick(link)
    local button = GetMouseButtonClicked and GetMouseButtonClicked() or nil
    if not M.Matches(button) then return end
    local item = M.ItemFromLink(link)
    if item then Peon.OpenItemMenu(item) end
end

-- Tastenbelegung (Bindings.xml): Menue fuer den Gegenstand unter der Maus
function Peon_OpenHoverItemMenu()
    local item = M.TooltipItem()
    if item then Peon.OpenItemMenu(item) end
end

function M.Init()
    if M.ready then return end
    M.ready = true
    if Peon.db and Peon.db.itemMenuClick == nil then Peon.db.itemMenuClick = M.DEFAULT end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "GLOBAL_MOUSE_DOWN")
    f:SetScript("OnEvent", function(_, _, button)
        local ok, err = pcall(M.OnMouseDown, button)
        if not ok and Peon.ReportCoreError then Peon.ReportCoreError("ItemMenu", err) end
    end)
    M.frame = f
    if hooksecurefunc and rawget(_G, "HandleModifiedItemClick") then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            local ok, err = pcall(M.OnModifiedClick, link)
            if not ok and Peon.ReportCoreError then Peon.ReportCoreError("ItemMenu", err) end
        end)
    end
end

-- Auswahlliste fuer die Kern-Optionsseite
function M.AddOption(panel, anchor)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -8, -24)
    title:SetText(L.ITEMMENU_OPT)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -36)
    hint:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.ITEMMENU_OPT_HINT)
    local function Get() return (Peon.db and Peon.db.itemMenuClick) or M.DEFAULT end
    local function Set(v) if Peon.db then Peon.db.itemMenuClick = v end end
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        dd:SetWidth(220)
        dd:SetupMenu(function(_, root)
            for _, o in ipairs(M.CLICKS) do
                root:CreateRadio(L[o[2]] or o[1], function() return Get() == o[1] end, function() Set(o[1]) end)
            end
        end)
    end
    M.option = { title = title, dropdown = dd, hint = hint, Set = Set, Get = Get }
    return title
end
