-- Peon_Panel - Menu.lua
-- Kontextmenues: je Symbol (Eintraege des Moduls, Untermenue mit Text, Anzeige, Beschriftung, Bereich, Entfernen,
-- dann Optionen) und auf einer
-- freien Stelle (alle Module zum An- und Abhaken).
-- Verankert am Rand der Anzeige, damit sie nicht ueberdeckt wird. Blizzard klappt das Menue um, wenn der Platz
-- nicht reicht (Blizzard_Menu\Menu.lua im Forever-Zweig von Gethe/wow-ui-source).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local SIDE_LABEL = { left = L.SIDE_LEFT, center = L.SIDE_CENTER, right = L.SIDE_RIGHT }
local SHOW_LABEL = { both = L.SHOW_BOTH, icon = L.SHOW_ICON, text = L.SHOW_TEXT }
local ROW_LABEL = { [1] = L.ROW_1, [2] = L.ROW_2 }
ns.SIDE_LABEL, ns.SHOW_LABEL, ns.ROW_LABEL = SIDE_LABEL, SHOW_LABEL, ROW_LABEL

-- Inhalt des Menues. root = Menue-Beschreibung von Blizzard
-- Oben die Eintraege des Moduls, die Einstellungen von Leiste und Panel liegen in einem Untermenue (ab 0.3.0),
-- damit sie z. B. beim Angeln nicht die Eintraege des Moduls verdraengen.
function ns.FillMenu(root, s, l)
    root:CreateTitle(l.title)
    if l.menu then
        l:FillMenu(root)
        root:CreateDivider()
    end
    local sub = root:CreateButton(s.key == "bar" and L.MENU_SUB_BAR or L.MENU_SUB_BOX)
    ns.FillDisplayMenu(sub, s, l)
    root:CreateButton(L.MENU_OPTIONS:format(l.title), function() l:OpenOptions() end)
end

-- Untermenue: Text, Anzeige, Beschriftung, Bereich, Zeile, Entfernen. Text, Anzeige und Beschriftung gelten
-- nur fuer diese Anzeige (ab 0.3.0), Leiste und Panel sind getrennt einstellbar.
function ns.FillDisplayMenu(root, s, l)
    local sk = s.key
    if #l.texts > 0 then
        root:CreateTitle(L.MENU_TEXT)
        local function isSel(v) return ns.TextOf(l.key, sk) == v end
        local function setSel(v) ns.SetText(l, v, sk) end
        root:CreateRadio(L.MENU_NO_TEXT, isSel, setSel, ns.TEXT_NONE)
        for _, t in ipairs(l.texts) do
            root:CreateRadio(t.label, isSel, setSel, t.key)
        end
        root:CreateDivider()
        root:CreateTitle(L.MENU_SHOW)
        local function isShow(v) return ns.ShowOf(l.key, sk) == v end
        local function setShow(v) ns.SetShow(l, v, sk) end
        for _, v in ipairs(ns.SHOWS) do
            root:CreateRadio(SHOW_LABEL[v], isShow, setShow, v)
        end
        root:CreateCheckbox(L.MENU_LABEL:format(ns.LabelName(l)), function() return ns.LabelOf(l.key, sk) end,
            function() ns.SetLabel(l, not ns.LabelOf(l.key, sk), sk) end)
        root:CreateDivider()
    end
    if sk == "bar" then
        root:CreateTitle(L.MENU_SIDE)
        local function isSide(v) return ns.SideOf(l.key) == v end
        local function setSide(v) ns.SetSide(l, v) end
        for _, v in ipairs(ns.SIDES) do
            root:CreateRadio(SIDE_LABEL[v], isSide, setSide, v)
        end
        if (ns.mod.db.barRows or 1) >= 2 then
            root:CreateTitle(L.MENU_ROW)
            local function isRow(v) return ns.RowOf(l.key) == v end
            local function setRow(v) ns.SetRow(l, v) end
            for _, v in ipairs(ns.ROWS) do
                root:CreateRadio(ROW_LABEL[v], isRow, setRow, v)
            end
        end
        root:CreateDivider()
    end
    root:CreateButton(sk == "bar" and L.MENU_REMOVE_BAR or L.MENU_REMOVE_BOX, function()
        ns.SetOnSurface(l, sk, false)
    end)
end

-- Menue auf einer freien Stelle: alle Module, nach Name
function ns.FillSurfaceMenu(root, s)
    root:CreateTitle(s.key == "bar" and L.HDR_BAR or L.HDR_BOX)
    local list = {}
    for _, l in pairs(ns.starters) do list[#list + 1] = l end
    table.sort(list, function(a, b) return a.title < b.title end)
    for _, l in ipairs(list) do
        local function isOn()
            local e = ns.Entry(l.key)
            return e ~= nil and e[s.key] == true
        end
        root:CreateCheckbox(l.title, isOn, function() ns.SetOnSurface(l, s.key, not isOn()) end)
    end
    root:CreateDivider()
    root:CreateButton(L.MENU_PANEL, function() mod:OpenOptions() end)
end

-- Anker: Obere Bildschirmhaelfte = Menue unter der Anzeige, sonst darueber.
local function AnchorAt(s, x)
    if ns.InUpperHalf(s) then
        return "TOPLEFT", s.frame, "BOTTOMLEFT", x, -2
    end
    return "BOTTOMLEFT", s.frame, "TOPLEFT", x, 2
end

-- Waagerecht am Symbol ausgerichtet
function ns.MenuAnchor(s, b)
    local x = 0
    for _, c in ipairs(s.cells) do
        if c.key == b.starter.key then x = c.x end
    end
    return AnchorAt(s, x)
end

local function OpenAnchored(owner, generator, ...)
    local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
    Menu.PopulateDescription(generator, owner, desc)
    return Menu.GetManager():OpenMenu(owner, desc, AnchorUtil.CreateAnchor(...))
end

-- Rueckgabe: ob ein Menue offen ist
local function Open(owner, generator, ...)
    local M, MU, MV, AU = rawget(_G, "Menu"), rawget(_G, "MenuUtil"), rawget(_G, "MenuVariants"), rawget(_G, "AnchorUtil")
    if M and MU and MV and AU then
        local ok, menu = pcall(OpenAnchored, owner, generator, ...)
        if ok and menu then return true end
        if not ok then mod:Dbg("Menue verankert nicht geoeffnet: " .. Peon.S(menu)) end
    end
    -- Rueckfall: am Mauszeiger, Blizzard haelt es im Bild
    if MU and MU.CreateContextMenu then
        MU.CreateContextMenu(owner, generator)
        return true
    end
    return false
end

function ns.OpenMenu(s, b)
    local l = b.starter
    local function generator(_, root)
        mod:Call("Menue", ns.FillMenu, root, s, l)
    end
    if not Open(b, generator, ns.MenuAnchor(s, b)) then l:OpenOptions() end
end

function ns.OpenSurfaceMenu(s)
    local function generator(_, root)
        mod:Call("Menue", ns.FillSurfaceMenu, root, s)
    end
    local x = ns.CursorInFrame(s.frame) or 0
    if not Open(s.frame, generator, AnchorAt(s, x)) then mod:OpenOptions() end
end
