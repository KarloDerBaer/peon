-- Peon_Warhorn - Probe.lua
-- Ab 0.1.0: Pruefaufbau fuer die Gruppensuche (/peon warhorn pruefen oder Knopf auf der Optionsseite).
-- Klaert im Spiel, bevor die eigene Liste mit Filtern entsteht:
--   1. welche Fenster und Schnittstellen der Gruppensuche es in Forever gibt
--   2. ob C_LFGList.Search aus einem Addon geht: einmal nach Tastendruck oder Klick, einmal von selbst (Zeitgeber)
--   3. welche Daten je Eintrag lesbar sind (Rollen, Klassen, Anzahl je Rolle) und was davon geheim ist
--   4. wie oft das Spiel gefundene Eintraege von selbst aktualisiert (LFG_LIST_SEARCH_RESULT_UPDATED)
-- Das Ergebnis steht in PeonWarhornDB.probe und nach /reload in WTF (SavedVariables\Peon_Warhorn.lua).
-- Namen anderer Spieler und Texte der Eintraege werden nicht gespeichert, nur ob sie lesbar oder geheim sind.
-- Blizzards Fenster werden nur gelesen, nie veraendert.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Probe = P

P.MAX_RESULTS = 15     -- so viele Eintraege werden je Suche genau gelesen
P.MAX_MEMBERS = 10     -- so viele Mitglieder je Eintrag
P.WAIT        = 8      -- Sekunden auf die Antwort einer Suche warten
P.GAP         = 3      -- Sekunden zwischen erster und zweiter Suche
P.WATCH       = 60     -- Sekunden, in denen Aktualisierungen gezaehlt werden
P.MAX_DEPTH   = 3

P.FRAMES = { "LFGParentFrame", "LFGBrowseFrame", "LFGListingFrame", "PVEFrame", "LFDParentFrame", "LFDQueueFrame",
    "LFGListFrame", "GroupFinderFrame", "RaidFinderFrame" }
P.ADDONS = { "Blizzard_GroupFinder_VanillaStyle", "Blizzard_GroupFinder", "Blizzard_LFGUtil" }
P.FUNCS  = { "Search", "GetSearchResults", "GetFilteredSearchResults", "GetSearchResultInfo",
    "GetSearchResultPlayerInfo", "GetSearchResultLeaderInfo", "GetSearchResultMemberCounts",
    "GetAvailableCategories", "GetAvailableActivities", "GetLfgCategoryInfo", "GetActivityInfoTable",
    "ApplyToGroup", "GetActiveEntryInfo", "RequestAvailableActivities" }
-- Felder mit Namen oder freiem Text: nur Art und Laenge speichern
P.HIDE = { leaderName = true, name = true, comment = true, voiceChat = true, partyGUID = true }

local run           -- laufende Pruefung (zeigt auf PeonWarhornDB.probe)
local waiting       -- Schritt, der auf die Antwort der Suche wartet

local function Secret(v) return Peon.IsSecret(v) end

-- Wert so ablegen, dass er sicher in SavedVariables geht; geheime Werte werden nur gezaehlt
local function V(v, depth)
    if Secret(v) then
        if run then run.secrets = (run.secrets or 0) + 1 end
        return "<geheim>"
    end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then return v end
    if t ~= "table" then return "<" .. t .. ">" end
    depth = depth or 0
    if depth >= P.MAX_DEPTH then return "<Tabelle>" end
    local ok, out = pcall(function()
        local o, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 40 then o["<mehr>"] = true break end
            if Secret(k) then
                o["<geheim " .. n .. ">"] = V(x, depth + 1)
            else
                o[type(k) == "number" and k or tostring(k)] = V(x, depth + 1)
            end
        end
        return o
    end)
    return ok and out or "<nicht lesbar>"
end

-- Namen und freie Texte: nur festhalten, ob lesbar, leer oder geheim
local function Hidden(v)
    if Secret(v) then
        if run then run.secrets = (run.secrets or 0) + 1 end
        return "<geheim>"
    end
    if type(v) == "string" then return v == "" and "<leer>" or ("<Text, " .. #v .. " Zeichen>") end
    if v == nil then return nil end
    return "<" .. type(v) .. ">"
end

-- Tabelle eines Eintrags ablegen, Namen und Texte ausgeblendet
local function Record(t)
    if Secret(t) then return V(t) end
    if type(t) ~= "table" then return V(t) end
    local ok, out = pcall(function()
        local o = {}
        for k, x in pairs(t) do
            if Secret(k) then
                o["<geheim>"] = "<geheim>"
            elseif P.HIDE[k] then
                o[k] = Hidden(x)
            else
                o[k] = V(x, 1)
            end
        end
        return o
    end)
    return ok and out or "<nicht lesbar>"
end

-- Funktion geschuetzt aufrufen; liefert ok und bis zu zwei Rueckgaben
local function Try(fn, ...)
    if type(fn) ~= "function" then return false, "fehlt" end
    return pcall(fn, ...)
end

local function Now() return GetTime and GetTime() or 0 end

local function Log(text)
    if run then
        run.log = run.log or {}
        run.log[#run.log + 1] = ("%.1f %s"):format(Now() - (run.t0 or 0), text)
    end
    mod:Dbg(text)
end

---------------------------------------------------------------------------
-- Umgebung: Fenster, Blizzard-Addons, Funktionen
---------------------------------------------------------------------------
local function Env()
    local env = { frames = {}, addons = {}, funcs = {} }
    for _, name in ipairs(P.FRAMES) do
        local f = _G[name]
        if f == nil then
            env.frames[name] = "fehlt"
        else
            local ok, shown = Try(f.IsShown, f)
            env.frames[name] = ok and (shown and "sichtbar" or "versteckt") or "vorhanden"
        end
    end
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
    for _, name in ipairs(P.ADDONS) do
        local ok, loaded = Try(isLoaded, name)
        env.addons[name] = ok and (loaded and "geladen" or "nicht geladen") or "unbekannt"
    end
    local api = C_LFGList or {}
    for _, name in ipairs(P.FUNCS) do env.funcs[name] = type(api[name]) == "function" end
    env.funcs.LFGUtil_GetFilteredActivities = type(LFGUtil_GetFilteredActivities) == "function"
    env.funcs.InviteUnit = C_PartyInfo ~= nil and type(C_PartyInfo.InviteUnit) == "function"
    if C_LFGListRoles then
        local ok, roles = Try(C_LFGListRoles.GetRoles)
        env.myRoles = ok and V(roles) or "Fehler"
    end
    if GetBuildInfo then env.build = { GetBuildInfo() } end
    return env
end

-- Kategorie aus Blizzards Auswahl, sonst die erste verfuegbare
local function Category()
    local browse = _G.LFGBrowseFrame
    local dd = browse and browse.CategoryDropdown
    if dd and dd.GetValue then
        local ok, id = Try(dd.GetValue, dd)
        if ok and type(id) == "number" and not Secret(id) and id > 0 then return id, "Blizzard-Auswahl" end
    end
    local ok, cats = Try(C_LFGList.GetAvailableCategories)
    if ok and type(cats) == "table" and not Secret(cats) and type(cats[1]) == "number" then return cats[1], "erste verfuegbare" end
    return nil
end

local function Activities(categoryID)
    local browse = _G.LFGBrowseFrame
    local dd = browse and browse.ActivityDropdown
    local sel = dd and dd.selectedValues
    if type(sel) == "table" and not Secret(sel) and #sel > 0 then return sel, "Blizzard-Auswahl" end
    local ok, list = Try(LFGUtil_GetFilteredActivities, categoryID)
    if ok and type(list) == "table" then return list, "LFGUtil" end
    ok, list = Try(C_LFGList.GetAvailableActivities, categoryID)
    if ok and type(list) == "table" then return list, "GetAvailableActivities" end
    return nil, "keine"
end

local function CategoryName(id)
    local ok, info = Try(C_LFGList.GetLfgCategoryInfo, id)
    if ok and type(info) == "table" and not Secret(info.name) and type(info.name) == "string" then return info.name end
    return tostring(id)
end

---------------------------------------------------------------------------
-- Ergebnisse lesen
---------------------------------------------------------------------------
local function ReadResult(id)
    local e = { id = V(id) }
    if Secret(id) then return e end
    local api = C_LFGList
    local ok, info = Try(api.GetSearchResultInfo, id)
    e.info = ok and Record(info) or "Fehler"
    if ok and type(info) == "table" and not Secret(info) then
        local keys = {}
        for k in pairs(info) do if not Secret(k) then keys[#keys + 1] = tostring(k) end end
        table.sort(keys)
        e.fields = table.concat(keys, ",")
    end
    local okC, counts = Try(api.GetSearchResultMemberCounts, id)
    e.counts = okC and V(counts) or "Fehler"
    local okL, leader = Try(api.GetSearchResultLeaderInfo, id)
    e.leader = okL and Record(leader) or "Fehler"
    local n = ok and type(info) == "table" and not Secret(info) and info.numMembers
    if type(n) == "number" and not Secret(n) then
        e.members = {}
        for i = 1, math.min(n, P.MAX_MEMBERS) do
            local okP, p = Try(api.GetSearchResultPlayerInfo, id, i)
            e.members[i] = okP and Record(p) or "Fehler"
        end
    end
    return e
end

local function ReadResults(step)
    local api = C_LFGList
    local ok, total, ids = Try(api.GetSearchResults)
    if ok then step.total = V(total) else step.total = "Fehler" end
    local okF, ftotal = Try(api.GetFilteredSearchResults)
    step.filteredTotal = okF and V(ftotal) or "fehlt"
    step.results = {}
    if ok and type(ids) == "table" and not Secret(ids) then
        for i = 1, math.min(#ids, P.MAX_RESULTS) do step.results[i] = ReadResult(ids[i]) end
    end
end

---------------------------------------------------------------------------
-- Ablauf: Suche nach Klick/Taste, Suche von selbst, Beobachten
---------------------------------------------------------------------------
local Finish, Next

local function DoSearch(label)
    local step = { label = label, t = Now() - run.t0 }
    run.steps[#run.steps + 1] = step
    waiting = step      -- schon vor dem Aufruf: eine Blockade meldet das Spiel noch waehrend des Aufrufs
    local ok, err = pcall(C_LFGList.Search, run.category, 0, 0, nil, false, nil, run.activities)
    step.callOk = ok
    if not ok then step.error = Secret(err) and "<geheim>" or tostring(err) end
    Log("Suche " .. label .. (ok and " aufgerufen" or (" Fehler: " .. tostring(step.error))))
    if not ok then waiting = nil; step.answer = "Fehler"; Next(); return end
    C_Timer.After(P.WAIT, function()
        if waiting == step then
            step.answer = "keine Antwort"
            waiting = nil
            Log("keine Antwort auf " .. label)
            Next()
        end
    end)
end

function Next()
    if not run then return end
    if #run.steps == 1 then
        C_Timer.After(P.GAP, function() if run then DoSearch("auto") end end)
    else
        run.watch = { start = Now() - run.t0, updates = 0, received = 0, ids = {} }
        Log("beobachte " .. P.WATCH .. " Sekunden")
        C_Timer.After(P.WATCH, Finish)
    end
end

local function StepText(step)
    local name = step.label == "auto" and L.P_STEP_AUTO or (step.label == "click" and L.P_STEP_CLICK or L.P_STEP_KEY)
    local text
    if step.answer == "Ergebnisse" then
        text = (type(step.total) == "number") and L.P_RES_OK:format(name, step.total) or L.P_RES_OK:format(name, 0)
    elseif step.answer == "fehlgeschlagen" then text = L.P_RES_FAIL:format(name)
    elseif step.answer == "Fehler" then text = L.P_RES_ERR:format(name)
    else text = L.P_RES_NONE:format(name) end
    if step.blocked then text = text .. L.P_BLOCKED end
    return text
end

function Finish()
    if not run or run.done then return end
    run.done = true
    run.dauer = Now() - run.t0
    local lines = {}
    for _, step in ipairs(run.steps) do lines[#lines + 1] = StepText(step) end
    if run.watch then lines[#lines + 1] = L.P_WATCH:format(P.WATCH, run.watch.updates) end
    lines[#lines + 1] = L.P_SECRETS:format(run.secrets or 0)
    run.summary = lines
    for _, line in ipairs(lines) do mod:Print(line) end
    mod:Print(L.P_DONE)
    Log("fertig")
    run = nil
    if mod.page then mod.page:Refresh() end
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local function OnReceived()
    if not run then return end
    if waiting then
        local step = waiting
        waiting = nil
        step.answer = "Ergebnisse"
        step.dt = Now() - run.t0 - step.t
        ReadResults(step)
        Log("Ergebnisse fuer " .. step.label .. ": " .. tostring(step.total))
        Next()
    elseif run.watch then
        run.watch.received = run.watch.received + 1     -- z. B. Suche durch Blizzards Fenster
    end
end

local function OnFailed(event, reason)
    if not run then return end
    if waiting then
        local step = waiting
        waiting = nil
        step.answer = "fehlgeschlagen"
        step.reason = V(reason)
        Log("Suche fehlgeschlagen: " .. tostring(step.reason))
        Next()
    end
end

local function OnUpdated(event, id)
    if not run or not run.watch then return end
    local w = run.watch
    w.updates = w.updates + 1
    if #w.ids < 20 then w.ids[#w.ids + 1] = V(id) end
end

local function OnBlocked(event, addon, func)
    if not run then return end
    run.blocked = run.blocked or {}
    local b = { event = event, addon = V(addon), func = V(func), step = waiting and waiting.label or "-" }
    run.blocked[#run.blocked + 1] = b
    if waiting and not Secret(addon) and addon == ADDON_NAME then waiting.blocked = true end
    Log(event .. " " .. tostring(b.addon) .. " " .. tostring(b.func))
end

mod:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", OnReceived)
mod:RegisterEvent("LFG_LIST_SEARCH_FAILED", OnFailed)
mod:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", OnUpdated)
mod:RegisterEvent("ADDON_ACTION_BLOCKED", OnBlocked)
mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", OnBlocked)

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
-- source: "key" (Chatbefehl, also Tastendruck) oder "click" (Knopf auf der Optionsseite)
function P.Start(source)
    if Peon.InCombat() then mod:Print(L.P_COMBAT) return end
    if run then mod:Print(L.P_RUNNING) return end
    if not (C_LFGList and type(C_LFGList.Search) == "function") then mod:Print(L.P_NO_API) return end
    local db = mod.db
    if not db then return end
    local cat, catFrom = Category()
    if not cat then mod:Print(L.P_NO_CAT) return end
    local acts, actsFrom = Activities(cat)
    run = {
        version = mod.version, date = date("%Y-%m-%d %H:%M:%S"), t0 = Now(), source = source,
        env = Env(), category = cat, categoryFrom = catFrom, categoryName = CategoryName(cat),
        activities = acts, activitiesFrom = actsFrom, steps = {}, secrets = 0,
    }
    db.probe = run
    mod:Print(L.P_START:format(run.categoryName))
    Log("Start " .. source)
    DoSearch(source)
end

function P.LastText()
    local p = mod.db and mod.db.probe
    if type(p) ~= "table" or not p.date then return L.P_NEVER end
    local text = L.P_LAST:format(p.date)
    if type(p.summary) == "table" then text = text .. "\n" .. table.concat(p.summary, "\n") end
    return text
end

-- fuer Tests
function P._Running() return run end
