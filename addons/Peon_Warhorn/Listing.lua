-- Peon_Warhorn - Listing.lua
-- Seite Eintragen (ab 0.3.0, Konzept Abschnitt 13): alles auf einer Seite. Kategorie, Aktivitaeten zum Anhaken,
-- Rollen, "Neue Spieler willkommen", Knopf Eintragen. Ist man eingetragen: Aendern und Austragen.
--   * Eintragen, Aendern und Austragen gehen wie die Suche nur nach Klick (C_LFGList.CreateListing hat
--     Einschraenkungen). Die Knoepfe rufen die Schnittstelle darum direkt im Klick auf.
--   * In einer Gruppe darf nur der Anfuehrer eintragen (wie Blizzards LFGListingUtil_CanEditListing).
--   * Blizzards Kommentarfeld ist geschuetzt (SetSecurityDisableSetText), ein Addon kann keinen Text setzen.
--     Der Knopf "Kommentar bei Blizzard" zeigt fuer diesen Schritt Blizzards Seite, ab 0.3.1 gleich in der
--     Ansicht mit dem Kommentarfeld (Blizzards SetCategorySelection mit Warhorns Kategorie). Den Text liest das
--     Spiel beim Eintragen selbst aus diesem Feld, Warhorn zeigt ihn nur an, wenn er lesbar ist.
--   * Spielstil (ab 0.3.1): Pflicht bei Blizzard, Vorgabe "Entspannt" (Enum.LFGEntryGeneralPlaystyle.FunRelaxed).
-- Auswahl je Charakter: lCategory, lActivities, lNewPlayer, lPlaystyle (0 = Vorgabe).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local S = ns.Search

local Lst = {}
ns.Listing = Lst

local function Secret(v) return Peon.IsSecret(v) end
local function Try(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

---------------------------------------------------------------------------
-- Daten
---------------------------------------------------------------------------
function Lst.CanEdit()
    if not (IsInGroup and IsInGroup()) then return true end
    return (UnitIsGroupLeader and UnitIsGroupLeader("player")) and true or false
end

-- Eigener Eintrag oder nil
function Lst.Active()
    local api = C_LFGList
    if not api then return nil end
    local ok, has = Try(api.HasActiveEntryInfo)
    if not ok or has ~= true then return nil end
    local okI, info = Try(api.GetActiveEntryInfo)
    if not okI or type(info) ~= "table" or Secret(info) then return nil end
    return info
end

function Lst.Selected()
    local out = {}
    for _, id in ipairs(mod.db.lActivities or {}) do out[#out + 1] = id end
    return out
end

function Lst.IsSelected(id)
    for _, a in ipairs(mod.db.lActivities or {}) do if a == id then return true end end
    return false
end

function Lst.Toggle(id)
    local acts = mod.db.lActivities
    for i, a in ipairs(acts) do
        if a == id then table.remove(acts, i); Lst.dirty = true; return end
    end
    acts[#acts + 1] = id
    Lst.dirty = true
end

function Lst.SetCategory(id)
    if mod.db.lCategory == id then return end
    mod.db.lCategory = id
    mod.db.lActivities = {}
    Lst.dirty = true
end

-- Kategorie: gespeicherte, sonst die der Suche, sonst die erste
function Lst.EnsureCategory()
    local db = mod.db
    if type(db.lCategory) == "number" and db.lCategory > 0 and #S.Activities(db.lCategory) > 0 then return end
    local cat = db.category
    if type(cat) ~= "number" or cat <= 0 or #S.Activities(cat) == 0 then
        local cats = S.Categories()
        cat = cats[1] and cats[1][1] or 0
    end
    db.lCategory = cat
    db.lActivities = {}
end

-- Eigenen Eintrag in die Auswahl uebernehmen
function Lst.LoadActive()
    local info = Lst.Active()
    if not info then return false end
    local acts = {}
    if type(info.activityIDs) == "table" and not Secret(info.activityIDs) then
        for _, id in ipairs(info.activityIDs) do if type(id) == "number" and not Secret(id) then acts[#acts + 1] = id end end
    end
    if #acts > 0 then
        local ok, a = Try(C_LFGList.GetActivityInfoTable, acts[1])
        if ok and type(a) == "table" and not Secret(a) and type(a.categoryID) == "number" and not Secret(a.categoryID) then
            mod.db.lCategory = a.categoryID
        end
        mod.db.lActivities = acts
    end
    if not Secret(info.newPlayerFriendly) then mod.db.lNewPlayer = info.newPlayerFriendly == true end
    Lst.dirty = false
    return true
end

-- Aktivitaet fuer Fluestervorlagen aus der Wer-Liste: eigener Eintrag, sonst die Auswahl zum Eintragen
function Lst.ActivityText()
    local info = Lst.Active()
    local acts = {}
    if info and type(info.activityIDs) == "table" and not Secret(info.activityIDs) then acts = info.activityIDs
    else acts = mod.db and mod.db.lActivities or {} end
    if #acts == 0 then return "" end
    if #acts == 1 then return S.ActivityName(acts[1]) end
    return L.ACT_SOME:format(#acts)
end

-- Spielstile wie in Blizzards Auswahl
function Lst.Playstyles()
    local e = Enum and Enum.LFGEntryGeneralPlaystyle
    if type(e) ~= "table" then return {} end
    local out = {}
    for _, k in ipairs({ "Learning", "FunRelaxed", "FunSerious", "Expert" }) do
        local v = e[k]
        if type(v) == "number" then
            local name
            local fn = rawget(_G, "GetGeneralPlaystyleString")
            if type(fn) == "function" then
                local ok, n = pcall(fn, v)
                if ok and type(n) == "string" and not Secret(n) then name = n end
            end
            out[#out + 1] = { v, name or L["PLAYSTYLE_" .. k] or k }
        end
    end
    return out
end

-- Gewaehlter Spielstil, sonst "Entspannt"
function Lst.Playstyle()
    local v = mod.db and mod.db.lPlaystyle
    for _, p in ipairs(Lst.Playstyles()) do if p[1] == v then return v end end
    local e = Enum and Enum.LFGEntryGeneralPlaystyle
    return e and e.FunRelaxed or nil
end

-- Kommentar aus Blizzards Feld, nur wenn lesbar
function Lst.Comment()
    local box = rawget(_G, "LFGListingComment")
    local eb = type(box) == "table" and box.EditBox
    if type(eb) ~= "table" or type(eb.GetText) ~= "function" then return nil end
    local ok, t = pcall(eb.GetText, eb)
    if not ok or Secret(t) or type(t) ~= "string" then return nil end
    return t
end

-- Blizzards Seite fuer den Kommentar, gleich in der Ansicht mit dem Kommentarfeld
function Lst.OpenComment()
    ns.Overlay.ShowBlizzardOnce("listing")
    local lf = rawget(_G, "LFGListingFrame")
    local cat = mod.db.lCategory
    if type(lf) ~= "table" or type(cat) ~= "number" or cat <= 0 or Lst.Active() then return end
    if type(lf.SetCategorySelection) ~= "function" then return end
    local okG, cur = pcall(lf.GetCategorySelection, lf)
    if okG and cur == cat then return end
    local ok, err = pcall(lf.SetCategorySelection, lf, cat)
    if not ok then mod:Dbg("Kommentar: Blizzards Ansicht nicht gewechselt: " .. tostring(err)) end
end

-- Empfohlene Stufen einer Aktivitaet als Text ("28-38")
function Lst.LevelText(id)
    local ok, a = Try(C_LFGList and C_LFGList.GetActivityInfoTable, id)
    if not ok or type(a) ~= "table" or Secret(a) then return "" end
    local lo, hi = a.minLevelSuggestion, a.maxLevelSuggestion
    if Secret(lo) or Secret(hi) then return "" end
    lo = (type(lo) == "number" and lo > 0) and lo or (not Secret(a.minLevel) and a.minLevel) or nil
    if type(lo) ~= "number" or lo <= 0 then return "" end
    if type(hi) ~= "number" or hi <= 0 or hi == lo then return tostring(lo) end
    return lo .. "-" .. hi
end

-- Rollen: allein ueber Blizzards Rollenwahl der Gruppensuche, in der Gruppe die Gruppenrolle
function Lst.Roles()
    if IsInGroup and IsInGroup() then
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
        return { tank = role == "TANK", healer = role == "HEALER", dps = role == "DAMAGER" }
    end
    return ns.Filter.MyRoles()
end

function Lst.SetRole(key, on)
    if IsInGroup and IsInGroup() then
        local role = ({ tank = "TANK", healer = "HEALER", dps = "DAMAGER" })[key]
        if on and role and UnitSetRole then pcall(UnitSetRole, "player", role) end
        return
    end
    local r = ns.Filter.MyRoles()
    r[key] = on and true or false
    if C_LFGListRoles and C_LFGListRoles.SetRoles then
        pcall(C_LFGListRoles.SetRoles, { tank = r.tank == true, healer = r.healer == true, dps = r.dps == true })
    end
end

---------------------------------------------------------------------------
-- Eintragen, Aendern, Austragen (nur aus Klick)
---------------------------------------------------------------------------
function Lst.Post()
    if Peon.InCombat() then Lst.status = "combat" return false end
    if not Lst.CanEdit() then Lst.status = "leader" return false end
    local acts = Lst.Selected()
    if #acts == 0 then Lst.status = "noact" return false end
    local data = { activityIDs = acts, newPlayerFriendly = mod.db.lNewPlayer == true, generalPlaystyle = Lst.Playstyle() }
    local api = C_LFGList
    local fn = Lst.Active() and api.UpdateListing or api.CreateListing
    local ok, err = Try(fn, data)
    if not ok then
        mod:Dbg("Eintragen Fehler: " .. tostring(Secret(err) and "<geheim>" or err))
        Lst.status = "error"
        return false
    end
    Lst.status = "posting"
    Lst.dirty = false
    return true
end

function Lst.Remove()
    if Peon.InCombat() then Lst.status = "combat" return false end
    if not Lst.Active() then return false end
    local ok, err = Try(C_LFGList.RemoveListing)
    if not ok then
        mod:Dbg("Austragen Fehler: " .. tostring(err))
        Lst.status = "error"
        return false
    end
    Lst.status = "removing"
    return true
end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
local CHECK = "|A:common-icon-checkmark:14:14|a"

local function Columns()
    return {
        { key = "check", title = "", width = 30, align = "CENTER", nosort = true, format = function(_, a) return Lst.IsSelected(a.id) and CHECK or "" end },
        { key = "name", title = L.COL_ACTIVITY, format = function(_, a) return a.name end, sort = function(a) return a.order end },
        { key = "level", title = L.COL_LEVEL_SUGGEST, width = 110, align = "CENTER", format = function(_, a) return a.level end, sort = function(a) return a.order end },
    }
end

function Lst.Items()
    local out = {}
    for i, id in ipairs(S.Activities(mod.db.lCategory)) do
        out[#out + 1] = { id = id, name = S.ActivityName(id), level = Lst.LevelText(id), order = i }
    end
    return out
end

function Lst.Create(page)
    local UI = Peon.UI
    Lst.page = page

    local cat = UI.Dropdown(page, 160, function() return S.Categories() end, function() return mod.db.lCategory end,
        function(v) Lst.SetCategory(v); Lst.Update() end)
    cat:SetPoint("TOPLEFT", 62, -32)
    Lst.catDD = cat
    local all = UI.Button(page, L.LST_ALL, 80, function()
        mod.db.lActivities = {}
        for _, id in ipairs(S.Activities(mod.db.lCategory)) do mod.db.lActivities[#mod.db.lActivities + 1] = id end
        Lst.dirty = true
        Lst.Update()
    end)
    all:SetPoint("LEFT", cat, "RIGHT", 10, 0)
    local none = UI.Button(page, L.LST_NONE, 80, function() mod.db.lActivities = {}; Lst.dirty = true; Lst.Update() end)
    none:SetPoint("LEFT", all, "RIGHT", 4, 0)
    local psLabel = UI.Text(page, "label", L.LST_PLAYSTYLE)
    psLabel:SetPoint("LEFT", none, "RIGHT", 18, 0)
    local ps = UI.Dropdown(page, 150, function() return Lst.Playstyles() end, function() return Lst.Playstyle() end,
        function(v) mod.db.lPlaystyle = v; Lst.dirty = true; Lst.Update() end)
    ps:SetPoint("LEFT", psLabel, "RIGHT", 8, 0)
    UI.SetTooltip(ps, { L.LST_PLAYSTYLE, L.LST_PLAYSTYLE_TIP })
    Lst.playDD = ps
    local bliz = UI.Button(page, L.BTN_BLIZZARD, 90, function() ns.Overlay.SetReplace("listing", false) end)
    bliz:SetPoint("TOPRIGHT", -10, -34)
    UI.SetTooltip(bliz, { L.BTN_BLIZZARD, L.BTN_BLIZZARD_TIP_ANY })

    -- Rollen und "Neue Spieler willkommen"
    Lst.roleChecks = {}
    local prev
    for _, def in ipairs({ { "tank", L.ROLE_TANK }, { "healer", L.ROLE_HEALER }, { "dps", L.ROLE_DPS } }) do
        local key = def[1]
        local cb = UI.Check(page, def[2], false, function(on) Lst.SetRole(key, on); Lst.dirty = true; Lst.Update() end)
        if prev then cb:SetPoint("LEFT", prev, "RIGHT", 82, 0) else cb:SetPoint("TOPLEFT", 60, -64) end
        UI.SetTooltip(cb, { def[2], L.LST_ROLE_TIP })
        Lst.roleChecks[key] = cb
        prev = cb
    end
    local np = UI.Check(page, L.LST_NEWPLAYER, false, function(on) mod.db.lNewPlayer = on; Lst.dirty = true; Lst.Update() end)
    np:SetPoint("LEFT", prev, "RIGHT", 96, 0)
    UI.SetTooltip(np, { L.LST_NEWPLAYER, L.LST_NEWPLAYER_TIP })
    Lst.newPlayer = np

    -- Aktivitaeten
    ns.Window.BuildTable("listing", {
        page = page, top = -100, bottom = 70, columns = Columns, sortKey = "name", empty = L.LST_EMPTY,
        onClick = function(a, button)
            if button ~= "LeftButton" then return end
            Lst.Toggle(a.id)
            Lst.Update()
        end,
        onBuilt = function(p, t) Lst.panel, Lst.table = p, t end,
    })

    -- Kommentar und Knoepfe
    local comment = UI.Button(page, L.LST_COMMENT, 170, function() Lst.OpenComment() end)
    comment:SetPoint("BOTTOMLEFT", 12, 36)
    UI.SetTooltip(comment, { L.LST_COMMENT, L.LST_COMMENT_TIP })
    Lst.commentBtn = comment
    local ctext = UI.Text(page, "text", "")
    ctext:SetPoint("LEFT", comment, "RIGHT", 10, 0)
    ctext:SetWidth(330)
    if ctext.SetWordWrap then ctext:SetWordWrap(false) end
    Lst.commentText = ctext
    local remove = UI.Button(page, L.LST_REMOVE, 110, function() Lst.Remove(); Lst.Update() end)
    remove:SetPoint("BOTTOMRIGHT", -12, 36)
    Lst.removeBtn = remove
    local post = UI.Button(page, L.LST_POST, 130, function() Lst.Post(); Lst.Update() end, "gold")
    post:SetPoint("RIGHT", remove, "LEFT", -8, 0)
    Lst.postBtn = post

    Lst.status = nil
    Lst.statusBar = UI.StatusBar(page)
    page:HookScript("OnShow", function()
        if not Lst.dirty then Lst.LoadActive() end
        Lst.EnsureCategory()
        Lst.Update()
    end)
end

function Lst.StatusText()
    local s = Lst.status
    if s == "combat" then return "|cffff6060" .. L.STATUS_COMBAT_ANY .. "|r" end
    if s == "leader" then return "|cffff6060" .. L.LST_LEADER .. "|r" end
    if s == "noact" then return "|cffff6060" .. L.LST_NOACT .. "|r" end
    if s == "error" or s == "failed" then return "|cffff6060" .. L.LST_FAILED .. "|r" end
    if s == "posting" or s == "removing" then return L.LST_WAIT end
    local info = Lst.Active()
    if info then
        local n = type(info.activityIDs) == "table" and not Secret(info.activityIDs) and #info.activityIDs or 0
        return "|cff40ff40" .. L.LST_ACTIVE:format(n) .. "|r" .. (Lst.dirty and (", " .. L.LST_DIRTY) or "")
    end
    if not Lst.CanEdit() then return L.LST_LEADER end
    return L.LST_NOT_ACTIVE
end

function Lst.Update()
    if not (Lst.page and mod.db) then return end
    local active = Lst.Active() ~= nil
    local roles = Lst.Roles()
    for key, cb in pairs(Lst.roleChecks) do cb:SetChecked(roles[key] == true) end
    Lst.newPlayer:SetChecked(mod.db.lNewPlayer == true)
    if Lst.table then Lst.table:SetData(Lst.Items()) end
    if Lst.catDD and Lst.catDD.GenerateMenu then pcall(Lst.catDD.GenerateMenu, Lst.catDD) end
    if Lst.playDD and Lst.playDD.GenerateMenu then pcall(Lst.playDD.GenerateMenu, Lst.playDD) end
    local c = Lst.Comment()
    Lst.commentText:SetText(c and c ~= "" and L.LST_COMMENT_SHOW:format(c) or ("|cff808080" .. L.LST_COMMENT_NONE .. "|r"))
    local can = Lst.CanEdit() and not Peon.InCombat()
    Lst.postBtn:SetText(active and L.LST_UPDATE or L.LST_POST)
    if can and #(mod.db.lActivities or {}) > 0 and (not active or Lst.dirty) then Lst.postBtn:Enable() else Lst.postBtn:Disable() end
    if can and active then Lst.removeBtn:Enable() else Lst.removeBtn:Disable() end
    Lst.statusText = Lst.StatusText()
    Lst.statusBar:SetText(Lst.statusText)
end

local function Refresh()
    if Lst.page and Lst.page:IsVisible() then Lst.Update() end
end

mod:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE", function()
    Lst.status = nil
    Lst.LoadActive()
    Refresh()
end)
mod:RegisterEvent("LFG_LIST_ENTRY_CREATION_FAILED", function()
    Lst.status = "failed"
    Refresh()
end)
mod:RegisterEvent("GROUP_ROSTER_UPDATE", Refresh)
mod:RegisterEvent("PLAYER_ROLES_ASSIGNED", Refresh)
