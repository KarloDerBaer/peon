-- Peon_Warhorn - Journal.lua
-- Ab 0.4.0 (Wunsch KarloDerBaer): Dungeon aus dem Addon ForeverDungeonJournal uebernehmen.
--   * Klickt man dort auf das Auge eines Dungeons, sucht das Journal selbst nach diesem Dungeon
--     (ForeverDungeonJournal_NS.SearchDungeonDirect) und legt die Nummer der Aktivitaet in
--     ForeverDungeonJournalDB.lfgClick ab.
--   * Warhorn haengt sich an diese Funktion des Journals, nicht an Blizzards Fenster. Danach stellt es seine
--     Auswahl (Kategorie und Dungeons) auf genau diesen Dungeon und springt auf die Seite Suchen.
--   * Warhorn sucht nicht selbst: Die Ergebnisse der Suche des Journals kommen ohnehin bei Warhorn an.
--   * Ohne das Journal passiert nichts.

local ADDON_NAME, ns = ...
local mod = ns.mod

local J = {}
ns.Journal = J

J.ADDON = "ForeverDungeonJournal"
J.NS = "ForeverDungeonJournal_NS"
J.DB = "ForeverDungeonJournalDB"

local function Secret(v) return Peon.IsSecret(v) end

-- Nummer der Aktivitaet, nach der das Journal gerade gesucht hat (nur wenn die Suche geklappt hat)
function J.Activity(dungeonName)
    local db = rawget(_G, J.DB)
    local log = type(db) == "table" and db.lfgClick
    if type(log) ~= "table" or log.ok ~= true then return nil end
    if dungeonName ~= nil and log.dungeon ~= dungeonName then return nil end
    local id = log.activity
    if type(id) ~= "number" or Secret(id) then return nil end
    return id
end

-- Kategorie der Aktivitaet (Dungeons, Raids, ...). Ohne Antwort des Spiels keine Uebernahme.
function J.Category(id)
    local get = C_LFGList and C_LFGList.GetActivityInfoTable
    if type(get) ~= "function" then return nil end
    local ok, info = pcall(get, id)
    if not ok or type(info) ~= "table" or Secret(info) then return nil end
    local cat = info.categoryID
    if type(cat) ~= "number" or Secret(cat) or cat <= 0 then return nil end
    return cat
end

function J.Adopt(dungeonName)
    if not (mod.db and mod.db.show ~= false) then return false end
    local id = J.Activity(dungeonName)
    if not id then return false end
    local cat = J.Category(id)
    if not cat then return false end
    local S = ns.Search
    mod.db.category = cat
    mod.db.activities = { id }
    -- die Suche des Journals laeuft schon, ihre Ergebnisse kommen ueber LFG_LIST_SEARCH_RESULTS_RECEIVED
    S.searching = true
    S.status = nil
    S.Notify("selection")
    S.Notify("status")
    J.adopted = id
    mod:Dbg("Dungeon-Journal: Aktivitaet " .. id .. ", Kategorie " .. cat)
    if ns.Overlay and ns.Overlay.ShowSearchTab then ns.Overlay.ShowSearchTab() end
    return true
end

function J.Hook()
    if J.hooked then return true end
    local fdj = rawget(_G, J.NS)
    if type(fdj) ~= "table" or type(fdj.SearchDungeonDirect) ~= "function" then return false end
    hooksecurefunc(fdj, "SearchDungeonDirect", function(dungeonName)
        mod:Call("Dungeon-Journal", J.Adopt, dungeonName)
    end)
    J.hooked = true
    return true
end

J.Hook()
mod:RegisterEvent("ADDON_LOADED", function(event, name)
    if name == J.ADDON then mod:Call("Dungeon-Journal", J.Hook) end
end)
