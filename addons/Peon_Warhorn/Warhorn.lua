-- Peon_Warhorn - Warhorn.lua
-- Gruppen, Dungeons und Raids. Ab 0.2.0 Gruppensuche mit Filtern (Konzept docs/konzepte/warhorn/Peon_Warhorn_Konzept.md):
--   Search.lua  Suche, Ergebnisse, Ereignisse
--   Filter.lua  Filter nach Rolle, Klasse, Stufe, Groesse (ohne Fenster)
--   Window.lua  Flaeche mit Reitern Gruppen und Mitspieler, Liste, Menue
--   Overlay.lua ueber Blizzards Suchseite legen, Umschalten, Oeffnen
--   Probe.lua   Pruefaufbau aus 0.1.0 (/peon warhorn pruefen)
-- Einstellungen in PeonWarhornDB (accountweit) und PeonWarhornCharDB (je Charakter).

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "warhorn",           -- /peon warhorn ...
    title    = "Warhorn",
    db       = "PeonWarhornDB",
    charDB   = "PeonWarhornCharDB",
    charKeys = { category = true, activities = true, tab = true, gFilter = true, pFilter = true },
    defaults = {
        show       = true,          -- Warhorn ueber Blizzards Suchseite (aus = Blizzard)
        probe      = {},            -- Ergebnis der letzten Pruefung (/peon warhorn pruefen)
        category   = 0,             -- je Charakter: gewaehlte Kategorie (0 = noch keine, beim ersten Oeffnen aus Blizzards Auswahl)
        activities = {},            -- je Charakter: gewaehlte Aktivitaeten (leer = alle der Kategorie)
        tab        = "groups",      -- je Charakter: groups oder players
        gFilter    = {},            -- je Charakter: Filter Gruppen (Filter.lua)
        pFilter    = {},            -- je Charakter: Filter Mitspieler
    },
    choices  = { tab = { groups = true, players = true } },
    keepOnReset = { probe = true, category = true, activities = true, tab = true },
    slash    = { "/warhorn" },
    onSlash  = function(m, cmd)
        if cmd == "pruefen" or cmd == "prüfen" or cmd == "probe" then
            ns.Probe.Start("key")
        elseif cmd == "optionen" or cmd == "options" then
            m:OpenOptions()
        elseif cmd == "suchen" or cmd == "search" then
            ns.Search.Search()
        elseif cmd == "" and m._fromOwnSlash then
            ns.Overlay.Toggle()
        else
            m:OpenOptions()
        end
    end,
})
ns.mod = mod

-- /warhorn ohne Zusatz oeffnet die Gruppensuche, /peon warhorn ohne Zusatz die Optionen
SlashCmdList["PEON_WARHORN"] = function(msg)
    mod._fromOwnSlash = true
    local ok, err = pcall(mod.HandleSlash, mod, msg)
    mod._fromOwnSlash = nil
    if not ok then mod:ReportError("Slash", err) end
end

-- Tastenbelegung (Bindings.xml): ein Tastendruck zaehlt fuer das Spiel wie ein Klick
function PeonWarhorn_Search()
    mod:Call("Taste", ns.Search.Search)
end

mod:On("INIT", function()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    if ns.Filter then mod:Call("Filter", ns.Filter.InitDefaults) end
end)
mod:On("LOGIN", function()
    if ns.Overlay then mod:Call("Overlay", ns.Overlay.Init) end
    if mod.NewLauncher then
        mod:Call("Starter", function()
            mod:NewLauncher({
                icon = "Interface\\Icons\\INV_Misc_Horn_01",
                onClick = function() ns.Overlay.Toggle() end,
                onTooltip = function(_, tooltip) tooltip:AddLine(L.LAUNCHER_TIP, 1, 1, 1) end,
            })
        end)
    end
end)
local function Apply()
    if ns.Overlay then ns.Overlay.Apply() end
end
mod:On("CHANGED", Apply)
mod:On("RESET", function()
    if ns.Filter then ns.Filter.InitDefaults() end
    Apply()
    if ns.Window then ns.Window.Update() end
end)
