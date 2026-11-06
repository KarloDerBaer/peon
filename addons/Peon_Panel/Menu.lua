-- Peon_Panel - Menu.lua
-- Kontextmenue eines Symbols: Eintraege des Moduls, Wahl des Textes, Entfernen, Optionen.
-- Verankert am Rand der Anzeige, damit es sie nicht ueberdeckt. Blizzard klappt es um, wenn der Platz
-- nicht reicht (Blizzard_Menu\Menu.lua im Forever-Zweig von Gethe/wow-ui-source).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

-- Inhalt des Menues. root = Menue-Beschreibung von Blizzard
function ns.FillMenu(root, s, l)
    root:CreateTitle(l.title)
    if l.menu then
        l:FillMenu(root)
        root:CreateDivider()
    end
    if #l.texts > 0 then
        root:CreateTitle(L.MENU_TEXT)
        local function isSel(v)
            local e = ns.Entry(l.key)
            return e ~= nil and e.text == v
        end
        local function setSel(v) ns.SetText(l, v) end
        root:CreateRadio(L.MENU_NO_TEXT, isSel, setSel, ns.TEXT_NONE)
        for _, t in ipairs(l.texts) do
            root:CreateRadio(t.label, isSel, setSel, t.key)
        end
        root:CreateDivider()
    end
    root:CreateButton(s.key == "bar" and L.MENU_REMOVE_BAR or L.MENU_REMOVE_BOX, function()
        ns.SetOnSurface(l, s.key, false)
    end)
    root:CreateButton(L.MENU_OPTIONS:format(l.title), function() l:OpenOptions() end)
end

-- Anker: Obere Bildschirmhaelfte = Menue unter der Anzeige, sonst darueber. Waagerecht am Symbol ausgerichtet.
function ns.MenuAnchor(s, b)
    local x = 0
    for _, c in ipairs(s.cells) do
        if c.key == b.starter.key then x = c.x end
    end
    if ns.InUpperHalf(s) then
        return "TOPLEFT", s.frame, "BOTTOMLEFT", x, -2
    end
    return "BOTTOMLEFT", s.frame, "TOPLEFT", x, 2
end

local function OpenAnchored(b, generator, ...)
    local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
    Menu.PopulateDescription(generator, b, desc)
    return Menu.GetManager():OpenMenu(b, desc, AnchorUtil.CreateAnchor(...))
end

function ns.OpenMenu(s, b)
    local l = b.starter
    local function generator(_, root)
        mod:Call("Menue", ns.FillMenu, root, s, l)
    end
    local M, MU, MV, AU = rawget(_G, "Menu"), rawget(_G, "MenuUtil"), rawget(_G, "MenuVariants"), rawget(_G, "AnchorUtil")
    if M and MU and MV and AU then
        local ok, menu = pcall(OpenAnchored, b, generator, ns.MenuAnchor(s, b))
        if ok and menu then return end
        if not ok then mod:Dbg("Menue verankert nicht geoeffnet: " .. Peon.S(menu)) end
    end
    -- Rueckfall: am Mauszeiger, Blizzard haelt es im Bild
    if MU and MU.CreateContextMenu then
        MU.CreateContextMenu(b, generator)
    else
        l:OpenOptions()
    end
end
