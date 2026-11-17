-- Peon_Warhorn - Window.lua
-- Flaeche ueber Blizzards Suchseite (Overlay.lua legt sie dorthin): Auswahl, Filterleiste, Reiter Gruppen und
-- Mitspieler, Liste mit Tooltip und Menue, Statuszeile. Bausteine aus Peon.UI (API 18).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local S = ns.Search
local F = ns.Filter

local W = {}
ns.Window = W

W.WIDTH = 680
W.TICK = 1          -- Sekunden zwischen zwei Aktualisierungen der Statuszeile
W.AGE_REFRESH = 10  -- Sekunden zwischen zwei Aktualisierungen der Spalte Alter
W.OLD = 60          -- ab so vielen Sekunden ist die Suche "alt" (Hinweis gold)
W.DOUBLE = 0.4      -- Doppelklick

local ICON = 14
local function A(atlas, size) size = size or ICON return ("|A:%s:%d:%d|a"):format(atlas, size, size) end
local ROLE_ATLAS = { TANK = "groupfinder-icon-role-large-tank", HEALER = "groupfinder-icon-role-large-heal", DAMAGER = "groupfinder-icon-role-large-dps" }
local KEY_ATLAS = { tank = ROLE_ATLAS.TANK, healer = ROLE_ATLAS.HEALER, dps = ROLE_ATLAS.DAMAGER }
local function ClassAtlas(c) return "groupfinder-icon-class-" .. tostring(c):lower() end

local function Now() return GetTime and GetTime() or 0 end

function W.ClassColor(c)
    local cc = c and rawget(_G, "RAID_CLASS_COLORS") and RAID_CLASS_COLORS[c]
    if cc then return cc.r, cc.g, cc.b end
    return 1, 1, 1
end
function W.ClassName(c)
    local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
    return (names and c and names[c]) or c or "?"
end
local function Colored(text, c)
    local r, g, b = W.ClassColor(c)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text or "?")
end

function W.AgeText(sec)
    sec = math.floor(sec or 0)
    if sec < 60 then return L.AGE_SEC:format(sec) end
    if sec < 3600 then return L.AGE_MIN:format(math.floor(sec / 60)) end
    return L.AGE_HOUR:format(math.floor(sec / 3600))
end

-- Rollen einer Gruppe: Symbol, Anzahl, freie Plaetze in Gruen
function W.RolesText(e)
    local parts = {}
    for _, role in ipairs(S.ROLES) do
        local n, free = e.count[role] or 0, e.free[role] or 0
        local t = A(ROLE_ATLAS[role]) .. n
        if free > 0 then t = t .. "|cff40ff40+" .. free .. "|r" end
        parts[#parts + 1] = t
    end
    return table.concat(parts, " ")
end

function W.PlayerRolesText(e)
    local parts = {}
    for _, key in ipairs({ "tank", "healer", "dps" }) do
        if e.playerRoles and e.playerRoles[key] then parts[#parts + 1] = A(KEY_ATLAS[key]) end
    end
    return table.concat(parts, " ")
end

function W.ClassesText(e, max)
    max = max or 8
    local parts = {}
    for i, m in ipairs(e.members) do
        if i > max then parts[#parts + 1] = "+" .. (#e.members - max) break end
        if m.class then parts[#parts + 1] = A(ClassAtlas(m.class)) end
    end
    return table.concat(parts, "")
end

function W.LevelText(e)
    if not e.levelMin then return "" end
    if e.levelMin == e.levelMax then return tostring(e.levelMin) end
    return e.levelMin .. "-" .. e.levelMax
end

---------------------------------------------------------------------------
-- Aktionen
---------------------------------------------------------------------------
function W.CanInvite()
    if not IsInGroup or not IsInGroup() then return true end
    return (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) or false
end

function W.Whisper(e)
    local name = e and e.leaderName
    if not name then return end
    if ChatFrameUtil and ChatFrameUtil.SendTell then pcall(ChatFrameUtil.SendTell, name)
    elseif ChatFrame_SendTell then pcall(ChatFrame_SendTell, name) end
end

function W.Invite(e)
    if not (e and e.isSolo and e.leaderName and W.CanInvite()) then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        local ok, err = pcall(C_PartyInfo.InviteUnit, e.leaderName)
        if not ok then mod:Dbg("Einladen Fehler: " .. tostring(err)) end
    elseif InviteUnit then
        pcall(InviteUnit, e.leaderName)
    end
end

function W.Menu(e)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(W.frame, function(_, root)
        root:CreateTitle(e.leaderName or "?")
        local w = root:CreateButton(L.MENU_WHISPER, function() W.Whisper(e) end)
        if w.SetEnabled then w:SetEnabled(e.leaderName ~= nil) end
        local i = root:CreateButton(L.MENU_INVITE, function() W.Invite(e) end)
        if i.SetEnabled then i:SetEnabled(e.isSolo and e.leaderName ~= nil and W.CanInvite()) end
    end)
end

local lastClick = { e = nil, t = 0 }
local function OnRowClick(e, button)
    if button == "RightButton" then
        W.Menu(e)
    elseif button == "LeftButton" then
        if lastClick.e == e and Now() - lastClick.t <= W.DOUBLE then
            lastClick.e = nil
            W.Whisper(e)
        else
            lastClick.e, lastClick.t = e, Now()
        end
    end
end
W.OnRowClick = OnRowClick

function W.ShowTooltip(row, e)
    if not (GameTooltip and e) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if #e.activityIDs > 1 then
        GameTooltip:SetText(L.ACT_SOME:format(#e.activityIDs), 1, 0.82, 0)
        for _, id in ipairs(e.activityIDs) do GameTooltip:AddLine(S.ActivityName(id), 1, 1, 1) end
    else
        GameTooltip:SetText(e.activityText or "?", 1, 0.82, 0)
    end
    if e.leaderName then GameTooltip:AddLine(L.TIP_LEADER:format(Colored(e.leaderName, e.leaderClass)), 1, 1, 1) end
    if e.comment and e.comment ~= "" then GameTooltip:AddLine(e.comment, 0.8, 0.8, 0.8, true) end
    if #e.members > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TIP_MEMBERS, 1, 0.82, 0)
        for _, m in ipairs(e.members) do
            local role = m.role and ROLE_ATLAS[m.role] and A(ROLE_ATLAS[m.role]) or ""
            local cls = m.class and A(ClassAtlas(m.class)) or ""
            GameTooltip:AddLine(("%s %s %s %s"):format(role, cls, Colored(m.name or W.ClassName(m.class), m.class), m.level and ("(" .. m.level .. ")") or ""), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TIP_AGE:format(W.AgeText(S.Age(e))), 0.7, 0.7, 0.7)
    if e.isDelisted then GameTooltip:AddLine(L.TIP_DELISTED, 1, 0.3, 0.3) end
    if e.secret then GameTooltip:AddLine(L.TIP_SECRET, 1, 0.3, 0.3, true) end
    GameTooltip:AddLine(L.TIP_ACTIONS, 0.5, 0.8, 1, true)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Spalten
---------------------------------------------------------------------------
local function Gray(e) if e.isDelisted then return 0.5, 0.5, 0.5 end return 1, 1, 1 end
-- eigener Eintrag immer oben (Alter aufsteigend), geheime Eintraege unten (nil)
local function AgeSort(e) if e.hasSelf then return -1 end return S.Age(e) end

local function RowBg(e)
    if e.hasSelf then return 0.3, 0.6, 1, 0.15 end
    if e.isNew and not e.isDelisted then return 0.2, 0.8, 0.2, 0.12 end
end

function W.GroupColumns()
    return {
        { key = "activity", title = L.COL_ACTIVITY, format = function(_, e) return e.activityText end, sort = function(e) return e.activityText end, color = Gray },
        { key = "leader", title = L.COL_LEADER, width = 110, format = function(_, e) return Colored(e.leaderName or "?", e.leaderClass) end, sort = function(e) return e.leaderName end },
        { key = "level", title = L.COL_LEVEL, width = 58, align = "CENTER", format = function(_, e) return W.LevelText(e) end, sort = function(e) return e.levelMin end, color = Gray },
        { key = "roles", title = L.COL_ROLES, width = 128, format = function(_, e) return W.RolesText(e) end,
          sort = function(e) return -F.FreeFor(e, mod.db.gFilter.roles) end },
        { key = "classes", title = L.COL_CLASSES, width = 92, nosort = true, format = function(_, e) return W.ClassesText(e, 5) end },
        { key = "age", title = L.COL_AGE, width = 66, align = "RIGHT", format = function(_, e) return W.AgeText(S.Age(e)) end, sort = AgeSort, color = Gray },
    }
end

function W.PlayerColumns()
    return {
        { key = "name", title = L.COL_NAME, width = 120, format = function(_, e) return Colored(e.leaderName or "?", e.leaderClass) end, sort = function(e) return e.leaderName end },
        { key = "class", title = L.COL_CLASS, width = 92, format = function(_, e) return W.ClassName(e.leaderClass) end, sort = function(e) return W.ClassName(e.leaderClass) end, color = Gray },
        { key = "level", title = L.COL_LEVEL, width = 52, align = "CENTER", format = function(_, e) return e.leaderLevel and tostring(e.leaderLevel) or "" end, sort = function(e) return e.leaderLevel end, color = Gray },
        { key = "roles", title = L.COL_ROLES, width = 72, nosort = true, format = function(_, e) return W.PlayerRolesText(e) end },
        { key = "activity", title = L.COL_ACTIVITY, format = function(_, e) return e.activityText end, sort = function(e) return e.activityText end, color = Gray },
        { key = "age", title = L.COL_AGE, width = 66, align = "RIGHT", format = function(_, e) return W.AgeText(S.Age(e)) end, sort = AgeSort, color = Gray },
    }
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function Filt() return mod.db.tab == "groups" and mod.db.gFilter or mod.db.pFilter end

local function CategoryItems()
    local out = {}
    for _, c in ipairs(S.Categories()) do out[#out + 1] = c end
    return out
end

local function ActivityLabel()
    local n = #(mod.db.activities or {})
    if n == 0 then return L.ACT_ALL end
    if n == 1 then return S.ActivityName(mod.db.activities[1]) end
    return L.ACT_SOME:format(n)
end

local function BuildActivityMenu(root)
    local acts = S.Activities(mod.db.category)
    root:CreateButton(L.ACT_ALL, function() mod.db.activities = {}; S.Notify("selection") end)
    for _, id in ipairs(acts) do
        root:CreateCheckbox(S.ActivityName(id), function() return S.IsActivitySelected(id) end, function() S.ToggleActivity(id) end)
    end
end

local function BuildFilterMenu(root)
    local f = Filt()
    root:CreateTitle(L.CLASSES)
    local my = F.MyClass()
    for _, c in ipairs(F.CLASSES) do
        root:CreateCheckbox(Colored(W.ClassName(c), c), function() return f.classes[c] == true end, function()
            f.classes[c] = not f.classes[c] or nil
            W.Update()
        end)
    end
    if mod.db.tab == "groups" then
        if root.CreateDivider then root:CreateDivider() end
        root:CreateRadio(L.MODE_WITH, function() return f.mode == "with" end, function() f.mode = "with"; W.Update() end)
        root:CreateRadio(L.MODE_WITHOUT, function() return f.mode == "without" end, function() f.mode = "without"; W.Update() end)
        root:CreateCheckbox(L.NO_MY_CLASS .. (my and (" (" .. W.ClassName(my) .. ")") or ""), function() return f.noMyClass end, function() f.noMyClass = not f.noMyClass; W.Update() end)
        if root.CreateDivider then root:CreateDivider() end
        root:CreateTitle(L.SIZE)
        for _, n in ipairs({ 0, 2, 3, 4 }) do
            root:CreateRadio(n == 0 and L.SIZE_ALL or L.SIZE_MAX:format(n), function() return f.sizeMax == n end, function() f.sizeMax = n; W.Update() end)
        end
    end
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(L.FILTER_RESET, function() F.Reset(mod.db.tab); W.SyncControls(); W.Update() end)
end

function W.Create(parent)
    if W.frame then return W.frame end
    local UI = Peon.UI
    local f = UI.TryFrame("Frame", "PeonWarhornFrame", parent, "PortraitFrameTemplate") or CreateFrame("Frame", "PeonWarhornFrame", parent)
    W.frame = f
    f:SetWidth(W.WIDTH)
    if f.SetTitle then pcall(f.SetTitle, f, L.TITLE) end
    if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, "Interface\\Icons\\INV_Misc_Horn_01") end
    -- Titelleiste bleibt fuer Blizzards Fenster frei (Peon_Mover zieht dort), darunter faengt die Flaeche die Maus ab
    local block = CreateFrame("Frame", nil, f)
    block:SetPoint("TOPLEFT", 0, -24)
    block:SetPoint("BOTTOMRIGHT", 0, 0)
    if block.EnableMouse then block:EnableMouse(true) end
    if f.EnableMouse then f:EnableMouse(false) end
    W.block = block
    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function()
            if Peon.InCombat() then return end
            if HideUIPanel and LFGParentFrame then pcall(HideUIPanel, LFGParentFrame) end
        end)
    end

    -- Zeile 1: Kategorie, Aktivitaeten, Suchen, Neu suchen, Blizzard
    local cat = UI.Dropdown(f, 140, CategoryItems, function() return mod.db.category end, function(v) S.SetCategory(v) end)
    cat:SetPoint("TOPLEFT", 62, -32)
    W.catDD = cat
    local act = UI.FilterDropdown(f, ActivityLabel(), BuildActivityMenu)
    act:SetPoint("LEFT", cat, "RIGHT", 8, 0)
    if act.SetWidth then act:SetWidth(170) end
    W.actDD = act
    local search = UI.Button(f, L.BTN_SEARCH, 110, function() S.Search() end, "gold")
    search:SetPoint("LEFT", act, "RIGHT", 10, 0)
    W.searchBtn = search
    local refresh = UI.RefreshButton(f, function() S.Search() end, L.REFRESH_TIP)
    refresh:SetPoint("LEFT", search, "RIGHT", 4, 0)
    local bliz = UI.Button(f, L.BTN_BLIZZARD, 90, function() ns.Overlay.SetShow(false) end)
    bliz:SetPoint("TOPRIGHT", -10, -34)
    UI.SetTooltip(bliz, { L.BTN_BLIZZARD, L.BTN_BLIZZARD_TIP })

    -- Zeile 2: Rollen, Filter, Stufe
    W.roleChecks = {}
    local prev
    for _, def in ipairs({ { "tank", L.ROLE_TANK }, { "healer", L.ROLE_HEALER }, { "dps", L.ROLE_DPS } }) do
        local key = def[1]
        local cb = UI.Check(f, A(KEY_ATLAS[key], 16) .. " " .. def[2], false, function(on)
            Filt().roles[key] = on or nil
            W.Update()
        end)
        if prev then cb:SetPoint("LEFT", prev, "RIGHT", 82, 0) else cb:SetPoint("TOPLEFT", 60, -64) end
        UI.SetTooltip(cb, function() return { def[2], mod.db.tab == "groups" and L.ROLES_GROUP_TIP or L.ROLES_PLAYER_TIP } end)
        W.roleChecks[key] = cb
        prev = cb
    end
    local filter = UI.FilterDropdown(f, L.FILTER, BuildFilterMenu)
    filter:SetPoint("LEFT", prev, "RIGHT", 96, 0)
    W.filterDD = filter
    local lvlLabel = UI.Text(f, "label", L.LEVEL)
    lvlLabel:SetPoint("LEFT", filter, "RIGHT", 14, 0)
    local function LevelInput(key)
        local e = UI.Input(f, 36, { numeric = true, maxLetters = 2 })
        e:HookScript("OnTextChanged", function(self, user)
            if not user then return end
            Filt()[key] = tonumber(self:GetText()) or 0
            W.Update()
        end)
        UI.SetTooltip(e, { L.LEVEL, L.LEVEL_TIP })
        return e
    end
    W.lvlMin = LevelInput("levelMin")
    W.lvlMin:SetPoint("LEFT", lvlLabel, "RIGHT", 10, 0)
    local to = UI.Text(f, "label", L.LEVEL_TO)
    to:SetPoint("LEFT", W.lvlMin, "RIGHT", 4, 0)
    W.lvlMax = LevelInput("levelMax")
    W.lvlMax:SetPoint("LEFT", to, "RIGHT", 8, 0)

    -- Reiter und Listen
    W.panels, W.tables = {}, {}
    for _, kind in ipairs({ "groups", "players" }) do
        local p = UI.Panel(f, "list", true)
        p:SetPoint("TOPLEFT", 8, -122)
        p:SetPoint("BOTTOMRIGHT", -8, 29)
        W.panels[kind] = p
        W.tables[kind] = UI.Table(p, {
            columns = kind == "groups" and W.GroupColumns() or W.PlayerColumns(),
            sortKey = "age",
            empty = L.EMPTY_NEVER,
            loadingText = L.SEARCHING,
            rowBg = RowBg,
            onEnter = W.ShowTooltip,
            onClick = OnRowClick,
        })
    end
    W.tabs = UI.TopTabs(f, { { "groups", L.TAB_GROUPS }, { "players", L.TAB_PLAYERS } }, function(key)
        mod.db.tab = key
        W.SyncControls()
        W.Update()
    end)
    if W.tabs[1] then W.tabs[1]:SetPoint("BOTTOMLEFT", W.panels.groups, "TOPLEFT", 6, -2) end

    W.status = UI.StatusBar(f)

    -- Statuszeile und Alter regelmaessig neu (nur solange sichtbar)
    local acc, accAge = 0, 0
    f:SetScript("OnUpdate", function(_, dt)
        acc, accAge = acc + (dt or 0), accAge + (dt or 0)
        if acc >= W.TICK then acc = 0; W.UpdateStatus() end
        if accAge >= W.AGE_REFRESH then
            accAge = 0
            local t = W.tables[mod.db.tab]
            if t then t.list:Refresh() end
        end
    end)
    f:HookScript("OnShow", function() W.Update() end)

    S.OnChange(function(what)
        if what == "selection" then W.SyncControls() end
        W.Update()
    end)
    W.tabs:Select(mod.db.tab or "groups")
    return f
end

-- Bedienelemente an die gespeicherten Werte angleichen (Reiter, Filter, Auswahl)
function W.SyncControls()
    if not W.frame then return end
    local f = Filt()
    for key, cb in pairs(W.roleChecks) do cb:SetChecked(f.roles[key] == true) end
    W.lvlMin:SetText(f.levelMin > 0 and tostring(f.levelMin) or "")
    W.lvlMax:SetText(f.levelMax > 0 and tostring(f.levelMax) or "")
    if W.actDD and W.actDD.Text then W.actDD.Text:SetText(ActivityLabel()) end
    if W.catDD and W.catDD.GenerateMenu then pcall(W.catDD.GenerateMenu, W.catDD) end
end

function W.UpdateStatus()
    if not W.status then return end
    local text
    if S.searching then
        text = L.STATUS_SEARCHING
    elseif S.status == "failed" then
        text = "|cffff6060" .. L.STATUS_FAILED .. "|r"
    elseif S.status == "combat" then
        text = "|cffff6060" .. L.STATUS_COMBAT .. "|r"
    elseif S.status == "error" then
        text = "|cffff6060" .. L.STATUS_ERROR .. "|r"
    elseif not S.lastSearch then
        text = L.STATUS_NEVER
    else
        local age = Now() - S.lastSearch
        local shown = W.shown or 0
        local base = L.STATUS:format(shown, W.total or 0)
        if age >= W.OLD then
            text = base .. ", |cffffd100" .. L.STATUS_OLD:format(W.AgeText(age)) .. "|r"
        else
            text = base .. ", " .. L.STATUS_AGE:format(W.AgeText(age))
        end
    end
    W.status:SetText(text)
    W.statusText = text
end

-- Listen und Zahlen an den Reitern neu
function W.Update()
    if not (W.frame and mod.db) then return end
    local tab = mod.db.tab or "groups"
    local counts = {}
    for kind, t in pairs(W.tables) do
        local list, total = F.Apply(S.list, kind)
        counts[kind] = #list
        if kind == tab then W.shown, W.total = #list, total end
        t.empty:SetText(not S.lastSearch and L.EMPTY_NEVER or (kind == "groups" and L.EMPTY_GROUPS or L.EMPTY_PLAYERS))
        t:SetData(list)
        t:SetLoading(S.searching and #S.list == 0, L.SEARCHING)
        W.panels[kind]:SetShown(kind == tab)
    end
    for _, tb in ipairs(W.tabs) do
        if tb.SetBadge then tb:SetBadge(counts[tb.key] or 0) end
    end
    W.counts = counts
    if W.actDD and W.actDD.Text then W.actDD.Text:SetText(ActivityLabel()) end
    if W.searchBtn then
        if Peon.InCombat() then W.searchBtn:Disable() else W.searchBtn:Enable() end
    end
    W.UpdateStatus()
end
