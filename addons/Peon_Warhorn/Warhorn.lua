-- Peon_Warhorn - Warhorn.lua
-- Gruppen, Dungeons und Raids. Ab 0.2.0 Gruppensuche mit Filtern (Konzept docs/konzepte/warhorn/Peon_Warhorn_Konzept.md):
--   Search.lua  Suche, Ergebnisse, Ereignisse
--   Filter.lua  Filter nach Rolle, Klasse, Stufe, Groesse (ohne Fenster)
--   Window.lua  Fenster mit Seiten, Seite Suchen mit Reitern Gruppen und Mitspieler, Liste, Menue
--   Whisper.lua Fluesterfenster mit Vorlagen (ab 0.3.0), schnell anfluestern und eigene Platzhalter (ab 0.5.0)
--   Placeholders.lua Fenster zum Bearbeiten der Platzhalter (ab 0.5.0)
--   Contacts.lua Anfragen merken und markieren (ab 0.5.0)
--   Listing.lua Seite Eintragen (ab 0.3.0)
--   Who.lua     Seite Wer-Liste (ab 0.3.0)
--   Settings.lua Seite Einstellungen (ab 0.3.0)
--   Overlay.lua ueber Blizzards Gruppensuche legen, Seiten nach Blizzards Reiter, Reiter Einstellungen
--   Journal.lua Dungeon aus ForeverDungeonJournal uebernehmen (ab 0.4.0)
--   Probe.lua   Pruefaufbau aus 0.1.0 (/peon warhorn pruefen)
-- Einstellungen in PeonWarhornDB (accountweit) und PeonWarhornCharDB (je Charakter).

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "warhorn",           -- /peon warhorn ...
    title    = "Warhorn",
    db       = "PeonWarhornDB",
    charDB   = "PeonWarhornCharDB",
    charKeys = { category = true, activities = true, tab = true, gFilter = true, pFilter = true,
                 lCategory = true, lActivities = true, lNewPlayer = true, lPlaystyle = true, wFilter = true, wText = true,
                 contacts = true },
    defaults = {
        show       = true,          -- Hauptschalter: Warhorn ueber Blizzards Gruppensuche (aus = ueberall Blizzard)
        replace    = { search = true, listing = true, who = true },   -- ab 0.3.0: je Seite Warhorn oder Blizzard
        whisper    = {},            -- ab 0.3.0: Fluestervorlagen (Whisper.lua): templates, groupTpl, playerTpl
        hideCols   = {},            -- ab 0.3.0: ausgeblendete Spalten je Liste (groups, players, who)
        colors     = {},            -- ab 0.3.0: Farben new und own ({ r, g, b, a }), leer = Standard
        probe      = {},            -- Ergebnis der letzten Pruefung (/peon warhorn pruefen)
        category   = 0,             -- je Charakter: gewaehlte Kategorie (0 = noch keine, beim ersten Oeffnen aus Blizzards Auswahl)
        activities = {},            -- je Charakter: gewaehlte Aktivitaeten (leer = alle der Kategorie)
        tab        = "groups",      -- je Charakter: groups oder players
        gFilter    = {},            -- je Charakter: Filter Gruppen (Filter.lua)
        pFilter    = {},            -- je Charakter: Filter Mitspieler
        lCategory  = 0,             -- je Charakter: Kategorie beim Eintragen
        lActivities = {},           -- je Charakter: Aktivitaeten beim Eintragen
        lNewPlayer = false,         -- je Charakter: "Neue Spieler willkommen"
        lPlaystyle = 0,             -- je Charakter: Spielstil beim Eintragen (0 = Vorgabe Entspannt), ab 0.3.1
        wFilter    = {},            -- je Charakter: Filter der Wer-Liste
        wText      = "",            -- je Charakter: letzte Wer-Suche
        contacts   = {},            -- je Charakter, ab 0.5.0: angefluesterte und eingeladene Spieler (Contacts.lua)
        contactKeep = 120,          -- ab 0.5.0: so viele Minuten werden Anfragen gemerkt
    },
    choices  = { tab = { groups = true, players = true } },
    keepOnReset = { probe = true, category = true, activities = true, tab = true, whisper = true, contacts = true,
                    lCategory = true, lActivities = true, wText = true },
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
    if ns.Whisper then mod:Call("Vorlagen", ns.Whisper.InitDefaults) end
    if ns.Who then mod:Call("Wer-Liste", ns.Who.InitFilter) end
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
    if ns.Whisper then ns.Whisper.InitDefaults() end
    if ns.Who then ns.Who.InitFilter() end
    if ns.Window then
        for _, kind in ipairs({ "groups", "players", "who" }) do ns.Window.RebuildTable(kind) end
    end
    Apply()
    if ns.Window then ns.Window.Update() end
end)
