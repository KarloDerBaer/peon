-- Peon_Warhorn - Search.lua
-- Suche in Blizzards Gruppensuche (C_LFGList) und Lesen der Ergebnisse.
-- Gepruefte Regeln (Warhorn 0.1.0, 17.11.2026):
--   * C_LFGList.Search geht nur nach Klick oder Tastendruck des Spielers. S.Search wird darum nur aus
--     Knopf, Taste oder Chatbefehl aufgerufen, nie aus einem Zeitgeber.
--   * Aenderungen an gefundenen Eintraegen liefert das Spiel von selbst (LFG_LIST_SEARCH_RESULT_UPDATED).
--   * Sucht Blizzards eigenes Fenster, kommt das Ergebnis ebenso hier an.
-- Jeder Wert wird vor dem Benutzen mit Peon.IsSecret geprueft. Eintraege mit geheimen Werten bekommen secret = true.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local S = {
    entries   = {},      -- [resultID] = Eintrag
    list      = {},      -- Eintraege in der Reihenfolge des Spiels
    seen      = {},      -- resultIDs der vorigen Suche (fuer "neu")
    lastSearch = nil,    -- Zeit der letzten Antwort
    searching = false,
    status    = nil,     -- nil, "failed", "combat", "error"
    listeners = {},
}
ns.Search = S

S.MAX_MEMBERS = 40
S.ROLES = { "TANK", "HEALER", "DAMAGER" }
S.ROLE_KEY = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local function Secret(v) return Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or 0 end

function S.OnChange(fn) S.listeners[#S.listeners + 1] = fn end
local function Notify(what)
    for _, fn in ipairs(S.listeners) do mod:Call("Liste", fn, what) end
end
S.Notify = Notify

local function Try(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

---------------------------------------------------------------------------
-- Kategorien und Aktivitaeten
---------------------------------------------------------------------------
function S.Activities(categoryID)
    if type(categoryID) ~= "number" or categoryID <= 0 then return {} end
    local ok, list = Try(LFGUtil_GetFilteredActivities, categoryID)
    if ok and type(list) == "table" and not Secret(list) then return list end
    ok, list = Try(C_LFGList and C_LFGList.GetAvailableActivities, categoryID)
    if ok and type(list) == "table" and not Secret(list) then return list end
    return {}
end

-- { { id, name }, ... } nur Kategorien mit Aktivitaeten (wie Blizzards Auswahl)
function S.Categories()
    local out = {}
    local ok, cats = Try(C_LFGList and C_LFGList.GetAvailableCategories)
    if not ok or type(cats) ~= "table" or Secret(cats) then return out end
    for _, id in ipairs(cats) do
        if type(id) == "number" and not Secret(id) and #S.Activities(id) > 0 then
            local okI, info = Try(C_LFGList.GetLfgCategoryInfo, id)
            local name = okI and type(info) == "table" and not Secret(info.name) and info.name or tostring(id)
            out[#out + 1] = { id, name }
        end
    end
    return out
end

local actNames = {}
function S.ActivityName(id)
    if type(id) ~= "number" or Secret(id) then return "?" end
    if actNames[id] then return actNames[id] end
    local ok, info = Try(C_LFGList and C_LFGList.GetActivityInfoTable, id)
    local name
    if ok and type(info) == "table" and not Secret(info) then
        local okN, n = Try(LFGUtil_GetActivityInfoName, info)
        if okN and type(n) == "string" and not Secret(n) then name = n end
        name = name or (not Secret(info.fullName) and info.fullName) or (not Secret(info.shortName) and info.shortName)
    end
    name = type(name) == "string" and name or tostring(id)
    actNames[id] = name
    return name
end

-- ab 0.5.1: Namen mehrerer Aktivitaeten als Aufzaehlung ("A, B und C"), ab S.LIST_MAX Namen "und n weitere"
S.LIST_MAX = 4
function S.ActivityList(ids)
    if type(ids) ~= "table" or Secret(ids) then return "" end
    local names = {}
    for _, id in ipairs(ids) do
        if type(id) == "number" and not Secret(id) then names[#names + 1] = S.ActivityName(id) end
    end
    local n = #names
    if n == 0 then return "" end
    if n == 1 then return names[1] end
    if n > S.LIST_MAX then
        local first = {}
        for i = 1, S.LIST_MAX - 1 do first[i] = names[i] end
        return table.concat(first, ", ") .. L.LIST_AND .. L.LIST_MORE:format(n - (S.LIST_MAX - 1))
    end
    return table.concat(names, ", ", 1, n - 1) .. L.LIST_AND .. names[n]
end

-- Gewaehlte Kategorie und Aktivitaeten; beim ersten Mal aus Blizzards Auswahl, sonst die erste Kategorie
function S.EnsureSelection()
    local db = mod.db
    if not db then return end
    if type(db.category) ~= "number" or db.category <= 0 or #S.Activities(db.category) == 0 then
        local cat
        local dd = _G.LFGBrowseFrame and LFGBrowseFrame.CategoryDropdown
        if dd and dd.GetValue then
            local ok, v = Try(dd.GetValue, dd)
            if ok and type(v) == "number" and not Secret(v) and v > 0 then cat = v end
        end
        if not cat then
            local cats = S.Categories()
            cat = cats[1] and cats[1][1]
        end
        db.category = cat or 0
        db.activities = {}
        local add = _G.LFGBrowseFrame and LFGBrowseFrame.ActivityDropdown
        local sel = add and add.selectedValues
        if cat and type(sel) == "table" and not Secret(sel) then
            for _, id in ipairs(sel) do if type(id) == "number" and not Secret(id) then db.activities[#db.activities + 1] = id end end
        end
    end
end

function S.SetCategory(id)
    local db = mod.db
    if not db or db.category == id then return end
    db.category = id
    db.activities = {}
    Notify("selection")
end

function S.IsActivitySelected(id)
    for _, a in ipairs(mod.db.activities or {}) do if a == id then return true end end
    return false
end

function S.ToggleActivity(id)
    local acts = mod.db.activities
    for i, a in ipairs(acts) do
        if a == id then table.remove(acts, i); Notify("selection"); return end
    end
    acts[#acts + 1] = id
    Notify("selection")
end

---------------------------------------------------------------------------
-- Suchen (nur aus Klick, Taste oder Chatbefehl)
---------------------------------------------------------------------------
function S.Search()
    if Peon.InCombat() then
        S.status = "combat"
        Notify("status")
        return false
    end
    if not (C_LFGList and type(C_LFGList.Search) == "function") then
        S.status = "error"
        Notify("status")
        return false
    end
    S.EnsureSelection()
    local db = mod.db
    local cat = db and db.category or 0
    if cat <= 0 then
        S.status = "error"
        Notify("status")
        return false
    end
    local acts = (#db.activities > 0) and db.activities or S.Activities(cat)
    local ok, err = pcall(C_LFGList.Search, cat, 0, 0, nil, false, nil, acts)
    if not ok then
        mod:Dbg("Suche Fehler: " .. tostring(Secret(err) and "<geheim>" or err))
        S.status = "error"
        Notify("status")
        return false
    end
    S.searching = true
    S.status = nil
    mod:Dbg("Suche Kategorie " .. cat .. ", " .. #acts .. " Aktivitaeten")
    Notify("status")
    return true
end

---------------------------------------------------------------------------
-- Ergebnisse lesen
---------------------------------------------------------------------------
local function Num(e, v)
    if Secret(v) then e.secret = true return nil end
    return type(v) == "number" and v or nil
end
local function Str(e, v)
    if Secret(v) then e.secret = true return nil end
    return type(v) == "string" and v or nil
end
local function Bool(e, v)
    if Secret(v) then e.secret = true return nil end
    return v == true
end

local function ReadMember(e, p)
    if Secret(p) or type(p) ~= "table" then e.secret = true return nil end
    local m = {
        name = Str(e, p.name), class = Str(e, p.classFilename), className = Str(e, p.className),
        level = Num(e, p.level), role = Str(e, p.assignedRole), isLeader = Bool(e, p.isLeader), roles = {},
    }
    local r = p.lfgRoles
    if Secret(r) then
        e.secret = true
    elseif type(r) == "table" then
        m.roles.tank, m.roles.healer, m.roles.dps = Bool(e, r.tank), Bool(e, r.healer), Bool(e, r.dps)
    end
    return m
end

function S.Read(id)
    if Secret(id) or type(id) ~= "number" then return nil end
    local api = C_LFGList
    local ok, info = Try(api.GetSearchResultInfo, id)
    if not ok or type(info) ~= "table" or Secret(info) then return nil end
    local e = {
        id = id, members = {}, classes = {}, count = { TANK = 0, HEALER = 0, DAMAGER = 0 },
        free = { TANK = 0, HEALER = 0, DAMAGER = 0 }, activityIDs = {}, readAt = Now(), secret = false,
    }
    e.numMembers = Num(e, info.numMembers) or 0
    e.isSolo = e.numMembers == 1
    e.age = Num(e, info.age) or 0
    e.isDelisted = Bool(e, info.isDelisted)
    e.hasSelf = Bool(e, info.hasSelf)
    e.leaderName = Str(e, info.leaderName)
    e.comment = Str(e, info.comment)
    local acts = info.activityIDs
    if Secret(acts) then e.secret = true
    elseif type(acts) == "table" then
        for _, a in ipairs(acts) do
            local n = Num(e, a)
            if n then e.activityIDs[#e.activityIDs + 1] = n end
        end
    end
    local okC, c = Try(api.GetSearchResultMemberCounts, id)
    if okC and type(c) == "table" and not Secret(c) then
        for _, role in ipairs(S.ROLES) do
            e.count[role] = Num(e, c[role]) or 0
            e.free[role] = Num(e, c[role .. "_REMAINING"]) or 0
        end
    elseif okC then
        e.secret = true
    end
    for i = 1, math.min(e.numMembers, S.MAX_MEMBERS) do
        local okP, p = Try(api.GetSearchResultPlayerInfo, id, i)
        local m = okP and ReadMember(e, p) or nil
        if m then
            e.members[#e.members + 1] = m
            if m.class then e.classes[m.class] = (e.classes[m.class] or 0) + 1 end
            if m.level then
                e.levelMin = math.min(e.levelMin or m.level, m.level)
                e.levelMax = math.max(e.levelMax or m.level, m.level)
            end
            if m.isLeader then e.leader = m end
        end
    end
    e.leader = e.leader or e.members[1]
    if e.leader then
        e.leaderClass, e.leaderLevel = e.leader.class, e.leader.level
        e.leaderName = e.leaderName or e.leader.name
    end
    -- Rollen eines Einzelspielers: was er spielen moechte, sonst die zugewiesene Rolle
    if e.isSolo and e.members[1] then
        local m = e.members[1]
        e.playerRoles = { tank = m.roles.tank, healer = m.roles.healer, dps = m.roles.dps }
        if not (m.roles.tank or m.roles.healer or m.roles.dps) and m.role and S.ROLE_KEY[m.role] then
            e.playerRoles[S.ROLE_KEY[m.role]] = true
        end
    end
    -- Text der Aktivitaet: eine mit Namen, mehrere als Anzahl (Namen im Tooltip)
    if #e.activityIDs == 1 then
        e.activityText = S.ActivityName(e.activityIDs[1])
    elseif #e.activityIDs > 1 then
        e.activityText = L.ACT_SOME:format(#e.activityIDs)
    else
        e.activityText = "?"
    end
    return e
end

-- Alter jetzt (Alter beim Lesen plus die Zeit seitdem)
function S.Age(e)
    return (e.age or 0) + math.max(0, Now() - (e.readAt or Now()))
end

function S.ReadAll()
    local ok, total, ids = Try(C_LFGList and C_LFGList.GetSearchResults)
    local old = S.entries
    S.entries, S.list = {}, {}
    local first = S.lastSearch == nil
    if ok and type(ids) == "table" and not Secret(ids) then
        for _, id in ipairs(ids) do
            local e = S.Read(id)
            if e then
                e.isNew = not first and not old[id] and not S.seen[id]
                S.entries[id] = e
                S.list[#S.list + 1] = e
            end
        end
    end
    S.seen = {}
    for id in pairs(S.entries) do S.seen[id] = true end
    S.total = #S.list
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
mod:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", function()
    S.ReadAll()
    S.searching = false
    S.status = nil
    S.lastSearch = Now()
    mod:Dbg("Ergebnisse: " .. tostring(S.total))
    Notify("results")
end)

-- Kategorien kommen vom Server, kurz nach dem Anmelden kann die Liste noch leer sein (in 0.2.0 blieb die
-- Auswahl dann leer). Sobald das Spiel sie meldet, wird eine fehlende Auswahl nachgeholt.
mod:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE", function()
    local before = mod.db and mod.db.category
    S.EnsureSelection()
    if mod.db and mod.db.category ~= before then Notify("selection") end
end)

mod:RegisterEvent("LFG_LIST_SEARCH_FAILED", function(event, reason)
    S.searching = false
    S.status = "failed"
    mod:Dbg("Suche abgelehnt: " .. tostring(Secret(reason) and "<geheim>" or reason))
    Notify("status")
end)

mod:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", function(event, id)
    if Secret(id) or not S.entries[id] then return end
    local old = S.entries[id]
    local e = S.Read(id)
    if not e then
        old.isDelisted = true
    else
        e.isNew = old.isNew
        S.entries[id] = e
        for i, x in ipairs(S.list) do if x == old then S.list[i] = e end end
    end
    Notify("update")
end)
