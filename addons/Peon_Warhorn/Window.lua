-- Peon_Warhorn - Window.lua
-- Warhorn-Fenster (Overlay.lua legt es ueber Blizzards Gruppensuche) mit Seiten (ab 0.3.0): Suchen (hier),
-- Eintragen (Listing.lua), Wer-Liste (Who.lua), Einstellungen (Settings.lua).
-- Die Seite Suchen: Auswahl, Filterleiste, Reiter Gruppen und Mitspieler, Liste mit Tooltip und Menue, Statuszeile.
-- Dazu Hilfen fuer alle Seiten: Klassenfarben, Alter, Tabellen mit waehlbaren Spalten. Bausteine aus Peon.UI (API 18).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local S = ns.Search
local F = ns.Filter

local W = {}
ns.Window = W

-- ab 0.3.1 so gross wie Ledger und Peons andere Fenster (Peon.UI.WINDOW_W, WINDOW_H), vorher 680 breit
W.WIDTH, W.HEIGHT = 800, 538
W.STRATA = "HIGH"   -- ueber Blizzards Fenster samt Rahmen (dort MEDIUM)
W.LEVEL = 300       -- ueber Blizzards Teilen in der Schicht HIGH (Suchfeld und Knopf der Wer-Liste)
W.TICK = 1          -- Sekunden zwischen zwei Aktualisierungen der Statuszeile
W.AGE_REFRESH = 10  -- Sekunden zwischen zwei Aktualisierungen der Spalte Alter
W.OLD = 60          -- ab so vielen Sekunden ist die Suche "alt" (Hinweis gold)
W.DOUBLE = 0.4      -- Doppelklick
W.TITLE_H = 24      -- Hoehe der Titelleiste, dort gehen Klicks zu Blizzards Fenster

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
function W.Colored(text, c)
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
        -- ab 0.2.2 ohne "+n" (Wunsch KarloDerBaer): ist ein Platz frei, steht die Zahl gruen
        local t = A(ROLE_ATLAS[role]) .. (free > 0 and ("|cff40ff40" .. n .. "|r") or n)
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

-- Werte fuer die Platzhalter (ab 0.5.1: alle Aktivitaeten als Aufzaehlung, Rollen des Mitspielers)
function W.WhisperCtx(e)
    local acts = S.ActivityList(e.activityIDs)
    return { activity = acts ~= "" and acts or e.activityText, searchRoles = e.isSolo and e.playerRoles or nil }
end

-- ab 0.3.0: eigenes Fenster mit Vorlage (Whisper.lua)
function W.Whisper(e)
    local name = e and e.leaderName
    if not name then return end
    ns.Whisper.Open(name, W.WhisperCtx(e), e.isSolo and "player" or "group")
end

-- ab 0.5.0: Standardvorlage sofort senden (Shift+Doppelklick) oder eine Vorlage aus dem Untermenue
function W.QuickWhisper(e, tpl)
    local name = e and e.leaderName
    if not name then return false end
    return ns.Whisper.QuickSend(name, W.WhisperCtx(e), e.isSolo and "player" or "group", tpl)
end

function W.Invite(e)
    if not (e and e.isSolo and e.leaderName and W.CanInvite()) then return end
    local ok, err = false, nil
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        ok, err = pcall(C_PartyInfo.InviteUnit, e.leaderName)
        if not ok then mod:Dbg("Einladen Fehler: " .. tostring(err)) end
    elseif InviteUnit then
        ok = pcall(InviteUnit, e.leaderName)
    end
    if ok and ns.Contacts then ns.Contacts.Record(e.leaderName, "invite") end
end

function W.Menu(e)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(W.frame, function(_, root)
        root:CreateTitle(e.leaderName or "?")
        local w = root:CreateButton(L.MENU_WHISPER, function() W.Whisper(e) end)
        if w.SetEnabled then w:SetEnabled(e.leaderName ~= nil) end
        ns.Whisper.AddQuickMenu(root, e.leaderName, W.WhisperCtx(e), e.isSolo and "player" or "group", e.leaderName ~= nil)
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
            if IsShiftKeyDown and IsShiftKeyDown() then W.QuickWhisper(e) else W.Whisper(e) end
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
    if e.leaderName then GameTooltip:AddLine(L.TIP_LEADER:format(W.Colored(e.leaderName, e.leaderClass)), 1, 1, 1) end
    if ns.Contacts then ns.Contacts.AddTooltip(GameTooltip, e.leaderName) end
    if e.comment and e.comment ~= "" then GameTooltip:AddLine(e.comment, 0.8, 0.8, 0.8, true) end
    if #e.members > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TIP_MEMBERS, 1, 0.82, 0)
        for _, m in ipairs(e.members) do
            local role = m.role and ROLE_ATLAS[m.role] and A(ROLE_ATLAS[m.role]) or ""
            local cls = m.class and A(ClassAtlas(m.class)) or ""
            GameTooltip:AddLine(("%s %s %s %s"):format(role, cls, W.Colored(m.name or W.ClassName(m.class), m.class), m.level and ("(" .. m.level .. ")") or ""), 1, 1, 1)
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

-- Farben aus den Einstellungen (ab 0.3.0)
W.DEFAULT_COLORS = { new = { 0.2, 0.8, 0.2, 0.12 }, own = { 0.3, 0.6, 1, 0.15 } }
function W.Color(key)
    local c = mod.db and type(mod.db.colors) == "table" and mod.db.colors[key]
    if type(c) ~= "table" or type(c[1]) ~= "number" then c = W.DEFAULT_COLORS[key] end
    return c[1], c[2], c[3], c[4] or 1
end
local function RowBg(e)
    if e.hasSelf then return W.Color("own") end
    if e.isNew and not e.isDelisted then return W.Color("new") end
end
W.RowBg = RowBg

-- ab 0.5.0: Symbol vor dem Namen, wenn schon angefluestert oder eingeladen (Contacts.lua)
function W.Marked(name, text)
    if ns.Contacts then return ns.Contacts.Mark(name, text) end
    return text
end

function W.GroupColumns()
    return {
        { key = "activity", title = L.COL_ACTIVITY, format = function(_, e) return e.activityText end, sort = function(e) return e.activityText end, color = Gray },
        { key = "leader", title = L.COL_LEADER, width = 110, format = function(_, e) return W.Marked(e.leaderName, W.Colored(e.leaderName or "?", e.leaderClass)) end, sort = function(e) return e.leaderName end },
        { key = "level", title = L.COL_LEVEL, width = 58, align = "CENTER", format = function(_, e) return W.LevelText(e) end, sort = function(e) return e.levelMin end, color = Gray },
        { key = "roles", title = L.COL_ROLES, width = 128, format = function(_, e) return W.RolesText(e) end,
          sort = function(e) return -F.FreeFor(e, mod.db.gFilter.roles) end },
        { key = "classes", title = L.COL_CLASSES, width = 92, nosort = true, format = function(_, e) return W.ClassesText(e, 5) end },
        { key = "age", title = L.COL_AGE, width = 66, align = "RIGHT", format = function(_, e) return W.AgeText(S.Age(e)) end, sort = AgeSort, color = Gray },
    }
end

function W.PlayerColumns()
    return {
        { key = "name", title = L.COL_NAME, width = 120, format = function(_, e) return W.Marked(e.leaderName, W.Colored(e.leaderName or "?", e.leaderClass)) end, sort = function(e) return e.leaderName end },
        { key = "class", title = L.COL_CLASS, width = 92, format = function(_, e) return W.ClassName(e.leaderClass) end, sort = function(e) return W.ClassName(e.leaderClass) end, color = Gray },
        { key = "level", title = L.COL_LEVEL, width = 52, align = "CENTER", format = function(_, e) return e.leaderLevel and tostring(e.leaderLevel) or "" end, sort = function(e) return e.leaderLevel end, color = Gray },
        { key = "roles", title = L.COL_ROLES, width = 72, nosort = true, format = function(_, e) return W.PlayerRolesText(e) end },
        { key = "activity", title = L.COL_ACTIVITY, format = function(_, e) return e.activityText end, sort = function(e) return e.activityText end, color = Gray },
        { key = "age", title = L.COL_AGE, width = 66, align = "RIGHT", format = function(_, e) return W.AgeText(S.Age(e)) end, sort = AgeSort, color = Gray },
    }
end

---------------------------------------------------------------------------
-- Seiten und Tabellen mit waehlbaren Spalten (ab 0.3.0)
---------------------------------------------------------------------------
W.pages = {}
W.PAGE_TITLE = { search = "PAGE_SEARCH", listing = "PAGE_LISTING", who = "PAGE_WHO", settings = "PAGE_SETTINGS" }

function W.NewPage(key)
    local p = CreateFrame("Frame", nil, W.frame)
    p:SetAllPoints(W.frame)
    p:Hide()
    p.key = key
    W.pages[key] = p
    return p
end

function W.ShowPage(key)
    for k, p in pairs(W.pages) do p:SetShown(k == key) end
    W.page = key
    local t = W.PAGE_TITLE[key] and L[W.PAGE_TITLE[key]]
    if W.frame and W.frame.SetTitle then pcall(W.frame.SetTitle, W.frame, t and (L.TITLE .. ": " .. t) or L.TITLE) end
end

-- Spalten ohne die ausgeblendeten (die erste Spalte bleibt immer)
function W.Visible(kind, cols)
    local hc = mod.db and type(mod.db.hideCols) == "table" and mod.db.hideCols[kind]
    local hide = type(hc) == "table" and hc or {}
    local out = {}
    for i, c in ipairs(cols) do if i == 1 or not hide[c.key] then out[#out + 1] = c end end
    return out
end

-- Tabelle in eigenem Bereich. spec: page, columns (Funktion), top, bottom, sortKey, empty, rowBg, onEnter,
-- onClick, onBuilt(panel, table). Neuaufbau mit W.RebuildTable(kind), wenn sich die Spalten aendern.
W.specs = {}
function W.BuildTable(kind, spec)
    spec = spec or W.specs[kind]
    W.specs[kind] = spec
    local UI = Peon.UI
    local old = spec.table
    local p = UI.Panel(spec.page, "list", true)
    p:SetPoint("TOPLEFT", 8, spec.top)
    p:SetPoint("BOTTOMRIGHT", -8, spec.bottom or 29)
    local cols = W.Visible(kind, spec.columns())
    local sortKey = spec.sortKey
    if old then
        for _, c in ipairs(cols) do if c.key == old.sortKey then sortKey = old.sortKey end end
    end
    local t = UI.Table(p, {
        columns = cols, sortKey = sortKey, sortDesc = (old and old.sortKey == sortKey and old.sortDesc) or nil,
        empty = spec.empty, loadingText = L.SEARCHING, rowBg = spec.rowBg,
        onEnter = spec.onEnter, onClick = spec.onClick,
    })
    if spec.panel then spec.panel:Hide() end
    spec.panel, spec.table = p, t
    if old and old.items then t:SetData(old.items) end
    if spec.onBuilt then spec.onBuilt(p, t) end
    return p, t
end

function W.RebuildTable(kind)
    if W.specs[kind] then W.BuildTable(kind) end
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

-- Jede Aenderung an Auswahl oder Filter sucht gleich neu (ab 0.2.2, Wunsch KarloDerBaer). Das geht, weil jede
-- dieser Aenderungen aus einem Klick oder Tastendruck kommt. Im Kampf bleibt es beim Filtern der alten Liste.
function W.Changed()
    W.Update()
    if not Peon.InCombat() then S.Search() end
end

-- Kategorie aus der Auswahlliste (ab 0.5.3): erst suchen, dann die Anzeige neu aufbauen. Bis 0.5.2 lief vor der
-- Suche ein Neuaufbau samt Menue der Auswahlliste, danach wertete das Spiel die Suche nicht mehr als Klick
-- und blockierte sie (gemeldet bei Quest & Zonen). Der Knopf Suchen war nicht betroffen.
function W.ChangeCategory(v)
    S.SetCategory(v, true)
    if not Peon.InCombat() then S.Search() end
    S.Notify("selection")
end

local function BuildActivityMenu(root)
    local acts = S.Activities(mod.db.category)
    root:CreateButton(L.ACT_ALL, function() mod.db.activities = {}; S.Notify("selection"); W.Changed() end)
    for _, id in ipairs(acts) do
        root:CreateCheckbox(S.ActivityName(id), function() return S.IsActivitySelected(id) end, function() S.ToggleActivity(id); W.Changed() end)
    end
end

local function BuildFilterMenu(root)
    local f = Filt()
    root:CreateTitle(L.CLASSES)
    local my = F.MyClass()
    for _, c in ipairs(F.CLASSES) do
        root:CreateCheckbox(W.Colored(W.ClassName(c), c), function() return f.classes[c] == true end, function()
            f.classes[c] = not f.classes[c] or nil
            W.Changed()
        end)
    end
    if mod.db.tab == "groups" then
        if root.CreateDivider then root:CreateDivider() end
        root:CreateRadio(L.MODE_WITH, function() return f.mode == "with" end, function() f.mode = "with"; W.Changed() end)
        root:CreateRadio(L.MODE_WITHOUT, function() return f.mode == "without" end, function() f.mode = "without"; W.Changed() end)
        root:CreateCheckbox(L.NO_MY_CLASS .. (my and (" (" .. W.ClassName(my) .. ")") or ""), function() return f.noMyClass end, function() f.noMyClass = not f.noMyClass; W.Changed() end)
        if root.CreateDivider then root:CreateDivider() end
        root:CreateTitle(L.SIZE)
        for _, n in ipairs({ 0, 2, 3, 4 }) do
            root:CreateRadio(n == 0 and L.SIZE_ALL or L.SIZE_MAX:format(n), function() return f.sizeMax == n end, function() f.sizeMax = n; W.Changed() end)
        end
    end
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(L.FILTER_RESET, function() F.Reset(mod.db.tab); W.SyncControls(); W.Changed() end)
end

function W.Create(parent)
    if W.frame then return W.frame end
    local UI = Peon.UI
    local f = UI.TryFrame("Frame", "PeonWarhornFrame", parent, "PortraitFrameTemplate") or CreateFrame("Frame", "PeonWarhornFrame", parent)
    W.frame = f
    local win = f
    -- Schicht und Ebene vor allen Kindern setzen, damit sie mitwandern
    if f.SetFrameStrata then f:SetFrameStrata(W.STRATA) end
    if f.SetFrameLevel then f:SetFrameLevel(W.LEVEL) end
    W.WIDTH = Peon.UI.WINDOW_W or W.WIDTH
    W.HEIGHT = Peon.UI.WINDOW_H or W.HEIGHT
    f:SetSize(W.WIDTH, W.HEIGHT)
    if f.SetTitle then pcall(f.SetTitle, f, L.TITLE) end
    if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, "Interface\\Icons\\INV_Misc_Horn_01") end
    -- Titelleiste bleibt fuer Blizzards Fenster frei (Peon_Mover zieht dort), darunter faengt die Flaeche die Maus ab.
    -- Bis 0.2.0 lag dafuer ein eigener Rahmen auf derselben Ebene wie die Bedienelemente und konnte ihre Klicks
    -- schlucken. Ab 0.2.1 faengt das Fenster selbst die Maus ab, nur die Titelleiste ist ausgespart.
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetHitRectInsets then f:SetHitRectInsets(0, 0, W.TITLE_H, 0) end
    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function()
            if Peon.InCombat() then return end
            if HideUIPanel and LFGParentFrame then pcall(HideUIPanel, LFGParentFrame) end
        end)
    end

    -- Seite Suchen: alles Folgende liegt auf ihr
    f = W.NewPage("search")

    -- Zeile 1: Kategorie, Aktivitaeten, Suchen, Neu suchen, Blizzard
    local cat = UI.Dropdown(f, 140, CategoryItems, function() return mod.db.category end, function(v) W.ChangeCategory(v) end)
    cat:SetPoint("TOPLEFT", 62, -32)
    W.catDD = cat
    -- Text bleibt "Filter" (ab 0.2.2): Blizzards Vorlage setzt ihn beim Oeffnen ohnehin darauf zurueck
    local act = UI.FilterDropdown(f, L.FILTER, BuildActivityMenu)
    act:SetPoint("LEFT", cat, "RIGHT", 8, 0)
    if act.SetWidth then act:SetWidth(170) end
    W.actDD = act
    local search = UI.Button(f, L.BTN_SEARCH, 110, function() S.Search() end, "gold")
    search:SetPoint("LEFT", act, "RIGHT", 10, 0)
    W.searchBtn = search
    local refresh = UI.RefreshButton(f, function() S.Search() end, L.REFRESH_TIP)
    refresh:SetPoint("LEFT", search, "RIGHT", 4, 0)
    local bliz = UI.Button(f, L.BTN_BLIZZARD, 90, function() ns.Overlay.SetReplace("search", false) end)
    bliz:SetPoint("TOPRIGHT", -10, -34)
    UI.SetTooltip(bliz, { L.BTN_BLIZZARD, L.BTN_BLIZZARD_TIP })

    -- Zeile 2: Rollen, Filter, Stufe
    W.roleChecks = {}
    local prev
    for _, def in ipairs({ { "tank", L.ROLE_TANK }, { "healer", L.ROLE_HEALER }, { "dps", L.ROLE_DPS } }) do
        local key = def[1]
        local cb = UI.Check(f, A(KEY_ATLAS[key], 16) .. " " .. def[2], false, function(on)
            Filt().roles[key] = on or nil
            W.Changed()
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
        -- Stufe: beim Tippen nur filtern, mit Eingabetaste neu suchen
        e:HookScript("OnEnterPressed", function(self)
            if self.ClearFocus then self:ClearFocus() end
            W.Changed()
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
        W.BuildTable(kind, {
            page = f, top = -122,
            columns = kind == "groups" and W.GroupColumns or W.PlayerColumns,
            sortKey = "age", empty = L.EMPTY_NEVER, rowBg = RowBg,
            onEnter = W.ShowTooltip, onClick = OnRowClick,
            onBuilt = function(p, t)
                W.panels[kind], W.tables[kind] = p, t
                if W.tabs then W.Update() end
            end,
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
    f:HookScript("OnShow", function()
        S.EnsureSelection()
        W.SyncControls()
        W.Update()
    end)

    S.OnChange(function(what)
        if what == "selection" then W.SyncControls() end
        W.Update()
    end)
    W.tabs:Select(mod.db.tab or "groups")
    return win
end

-- Bedienelemente an die gespeicherten Werte angleichen (Reiter, Filter, Auswahl)
function W.SyncControls()
    if not W.frame then return end
    local f = Filt()
    for key, cb in pairs(W.roleChecks) do cb:SetChecked(f.roles[key] == true) end
    W.lvlMin:SetText(f.levelMin > 0 and tostring(f.levelMin) or "")
    W.lvlMax:SetText(f.levelMax > 0 and tostring(f.levelMax) or "")
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
    elseif S.status == "blocked" then
        text = "|cffff6060" .. L.STATUS_BLOCKED .. "|r"
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
    if W.searchBtn then
        if Peon.InCombat() then W.searchBtn:Disable() else W.searchBtn:Enable() end
    end
    W.UpdateStatus()
end
