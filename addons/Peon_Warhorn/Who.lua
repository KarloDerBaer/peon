-- Peon_Warhorn - Who.lua
-- Seite Wer-Liste (ab 0.3.0, Konzept Abschnitt 13): Suchfeld wie bei Blizzard, vorgefertigte Suchen (meine
-- Stufe +-3, meine Zone, beides), Filter nach Klasse, Stufe und "ohne Gilde". Spalten Name, Stufe, Klasse,
-- Gilde, Zone. Doppelklick fluestert an, Rechtsklick mit Anfluestern und Einladen.
--   * C_FriendList.SendWho geht nur nach Klick oder Tastendruck. Gesucht wird nur aus Knopf, Eingabetaste
--     und den vorgefertigten Suchen im Menue.
--   * Die Antwort kommt mit WHO_LIST_UPDATE, solange Blizzards Wer-Liste offen ist (SetWhoToUi). Warhorn liegt
--     auf Blizzards Reiter Wer-Liste, darunter ist Blizzards Seite offen.
-- Filter je Charakter: wFilter (classes, levelMin, levelMax, noGuild), letzter Suchtext wText.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Who = { list = {}, total = 0 }
ns.Who = Who

Who.SERVER_MAX = 50   -- mehr liefert der Server nicht (MAX_WHOS_FROM_SERVER)

local function Secret(v) return Peon.IsSecret(v) end
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Filter
---------------------------------------------------------------------------
function Who.InitFilter()
    local db = mod.db
    if not db then return end
    local f = type(db.wFilter) == "table" and db.wFilter or {}
    f.classes = type(f.classes) == "table" and f.classes or {}
    f.levelMin = tonumber(f.levelMin) or 0
    f.levelMax = tonumber(f.levelMax) or 0
    f.noGuild = f.noGuild == true
    db.wFilter = f
end

function Who.Pass(e, f)
    if ns.Filter.AnyClass(f.classes) and not (e.class and f.classes[e.class]) then return false end
    if e.level then
        if f.levelMin > 0 and e.level < f.levelMin then return false end
        if f.levelMax > 0 and e.level > f.levelMax then return false end
    end
    if f.noGuild and e.guild and e.guild ~= "" then return false end
    return true
end

function Who.Apply()
    Who.InitFilter()
    local f = mod.db.wFilter
    local out = {}
    for _, e in ipairs(Who.list) do if Who.Pass(e, f) then out[#out + 1] = e end end
    return out
end

---------------------------------------------------------------------------
-- Suchen (nur aus Klick oder Taste)
---------------------------------------------------------------------------
function Who.Query(kind)
    local lvl = UnitLevel and UnitLevel("player") or 1
    local lo, hi = math.max(1, lvl - 3), lvl + 3
    local zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText()) or ""
    if kind == "level" then return ("%d-%d"):format(lo, hi) end
    if kind == "zone" then return ('z-"%s"'):format(zone) end
    if kind == "both" then return ('%d-%d z-"%s"'):format(lo, hi, zone) end
    return ""
end

function Who.Send(text)
    text = text or ""
    if Peon.InCombat() then Who.status = "combat" return false end
    local api = C_FriendList
    if not (api and type(api.SendWho) == "function") then Who.status = "error" return false end
    local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social
    local ok, err = pcall(api.SendWho, text, origin, { classIDs = {}, raceIDs = {}, uiMapIDs = {} })
    if not ok then
        mod:Dbg("Wer-Suche Fehler: " .. tostring(err))
        Who.status = "error"
        return false
    end
    mod.db.wText = text
    Who.searching = true
    Who.status = nil
    return true
end

function Who.Read()
    local api = C_FriendList
    local out = {}
    local ok, num, total = pcall(api.GetNumWhoResults)
    if not ok or Secret(num) or type(num) ~= "number" then num, total = 0, 0 end
    for i = 1, num do
        local okI, info = pcall(api.GetWhoInfo, i)
        if okI and type(info) == "table" and not Secret(info) then
            local function S(v) if Secret(v) then return nil end return v end
            out[#out + 1] = {
                name = S(info.fullName), guild = S(info.fullGuildName) or "", level = S(info.level),
                className = S(info.classStr), class = S(info.filename), race = S(info.raceStr), area = S(info.area) or "",
            }
        end
    end
    Who.list = out
    Who.total = (type(total) == "number" and not Secret(total)) and total or #out
    Who.searching = false
    Who.lastSearch = Now()
end

---------------------------------------------------------------------------
-- Aktionen
---------------------------------------------------------------------------
local function IsMe(e)
    local me = UnitName and UnitName("player")
    return e.name and me and (e.name == me or e.name:match("^([^%-]+)") == me)
end

function Who.Invite(e)
    if not (e and e.name) or IsMe(e) or not ns.Window.CanInvite() then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        local ok, err = pcall(C_PartyInfo.InviteUnit, e.name)
        if not ok then mod:Dbg("Einladen Fehler: " .. tostring(err)) end
    end
end

function Who.Whisper(e)
    if not (e and e.name) then return end
    ns.Whisper.Open(e.name, { activity = ns.Listing.ActivityText() }, "player")
end

function Who.Menu(e)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(ns.Window.frame, function(_, root)
        root:CreateTitle(e.name or "?")
        local w = root:CreateButton(L.MENU_WHISPER, function() Who.Whisper(e) end)
        if w.SetEnabled then w:SetEnabled(e.name ~= nil and not IsMe(e)) end
        local i = root:CreateButton(L.MENU_INVITE, function() Who.Invite(e) end)
        if i.SetEnabled then i:SetEnabled(e.name ~= nil and not IsMe(e) and ns.Window.CanInvite()) end
    end)
end

local last = { e = nil, t = 0 }
function Who.OnRowClick(e, button)
    if button == "RightButton" then
        Who.Menu(e)
    elseif button == "LeftButton" then
        if last.e == e and Now() - last.t <= ns.Window.DOUBLE then
            last.e = nil
            if not IsMe(e) then Who.Whisper(e) end
        else
            last.e, last.t = e, Now()
        end
    end
end

function Who.ShowTooltip(row, e)
    if not (GameTooltip and e) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.Window.Colored(e.name or "?", e.class), 1, 1, 1)
    GameTooltip:AddLine(L.WHO_TIP_LINE:format(e.level or "?", e.race or "", e.className or ""), 1, 1, 1)
    if e.guild ~= "" then GameTooltip:AddLine("<" .. e.guild .. ">", 0.25, 1, 0.25) end
    if e.area ~= "" then GameTooltip:AddLine(e.area, 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(L.TIP_ACTIONS, 0.5, 0.8, 1, true)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Seite
---------------------------------------------------------------------------
function Who.Columns()
    local W = ns.Window
    return {
        { key = "name", title = L.COL_NAME, width = 150, format = function(_, e) return W.Colored(e.name or "?", e.class) end, sort = function(e) return e.name end },
        { key = "level", title = L.COL_LEVEL, width = 56, align = "CENTER", format = function(_, e) return e.level and tostring(e.level) or "" end, sort = function(e) return e.level end },
        { key = "class", title = L.COL_CLASS, width = 104, format = function(_, e) return e.className or W.ClassName(e.class) end, sort = function(e) return e.className end },
        { key = "guild", title = L.COL_GUILD, width = 150, format = function(_, e) return e.guild end, sort = function(e) return e.guild end },
        { key = "zone", title = L.COL_ZONE, format = function(_, e) return e.area end, sort = function(e) return e.area end },
    }
end

local function BuildPresetMenu(root)
    root:CreateButton(L.WHO_P_LEVEL, function() Who.SearchFor(Who.Query("level")) end)
    root:CreateButton(L.WHO_P_ZONE, function() Who.SearchFor(Who.Query("zone")) end)
    root:CreateButton(L.WHO_P_BOTH, function() Who.SearchFor(Who.Query("both")) end)
end

local function BuildFilterMenu(root)
    Who.InitFilter()
    local f = mod.db.wFilter
    root:CreateTitle(L.CLASSES)
    for _, c in ipairs(ns.Filter.CLASSES) do
        root:CreateCheckbox(ns.Window.Colored(ns.Window.ClassName(c), c), function() return f.classes[c] == true end, function()
            f.classes[c] = not f.classes[c] or nil
            Who.Update()
        end)
    end
    if root.CreateDivider then root:CreateDivider() end
    root:CreateCheckbox(L.WHO_NO_GUILD, function() return f.noGuild end, function() f.noGuild = not f.noGuild; Who.Update() end)
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(L.FILTER_RESET, function() mod.db.wFilter = {}; Who.InitFilter(); Who.SyncControls(); Who.Update() end)
end

-- Suchtext ins Feld und gleich suchen (aus Klick im Menue)
function Who.SearchFor(text)
    if Who.box then Who.box:SetText(text) end
    Who.Send(text)
    Who.Update()
end

function Who.Create(page)
    local UI = Peon.UI
    Who.page = page
    Who.InitFilter()

    local box = UI.SearchBox(page, 250)
    box:SetPoint("TOPLEFT", 66, -32)
    box:SetText(mod.db.wText or "")
    box:SetScript("OnEnterPressed", function(self)
        if self.ClearFocus then self:ClearFocus() end
        Who.Send(self:GetText() or "")
        Who.Update()
    end)
    UI.SetTooltip(box, { L.WHO_BOX, L.WHO_BOX_TIP })
    Who.box = box
    local search = UI.Button(page, L.BTN_SEARCH, 100, function() Who.Send(box:GetText() or ""); Who.Update() end, "gold")
    search:SetPoint("LEFT", box, "RIGHT", 10, 0)
    Who.searchBtn = search
    local presets = UI.FilterDropdown(page, L.WHO_PRESETS, BuildPresetMenu)
    presets:SetPoint("LEFT", search, "RIGHT", 8, 0)
    Who.presetDD = presets
    local bliz = UI.Button(page, L.BTN_BLIZZARD, 90, function() ns.Overlay.SetReplace("who", false) end)
    bliz:SetPoint("TOPRIGHT", -10, -34)
    UI.SetTooltip(bliz, { L.BTN_BLIZZARD, L.BTN_BLIZZARD_TIP_ANY })

    local filter = UI.FilterDropdown(page, L.FILTER, BuildFilterMenu)
    filter:SetPoint("TOPLEFT", 62, -66)
    Who.filterDD = filter
    local lvlLabel = UI.Text(page, "label", L.LEVEL)
    lvlLabel:SetPoint("LEFT", filter, "RIGHT", 14, 0)
    local function LevelInput(key)
        local e = UI.Input(page, 36, { numeric = true, maxLetters = 2 })
        e:HookScript("OnTextChanged", function(self, user)
            if not user then return end
            mod.db.wFilter[key] = tonumber(self:GetText()) or 0
            Who.Update()
        end)
        UI.SetTooltip(e, { L.LEVEL, L.WHO_LEVEL_TIP })
        return e
    end
    Who.lvlMin = LevelInput("levelMin")
    Who.lvlMin:SetPoint("LEFT", lvlLabel, "RIGHT", 10, 0)
    local to = UI.Text(page, "label", L.LEVEL_TO)
    to:SetPoint("LEFT", Who.lvlMin, "RIGHT", 4, 0)
    Who.lvlMax = LevelInput("levelMax")
    Who.lvlMax:SetPoint("LEFT", to, "RIGHT", 8, 0)

    ns.Window.BuildTable("who", {
        page = page, top = -100, columns = Who.Columns, sortKey = "level", empty = L.WHO_EMPTY_NEVER,
        onEnter = Who.ShowTooltip, onClick = Who.OnRowClick,
        onBuilt = function(p, t) Who.panel, Who.table = p, t; Who.Update() end,
    })
    Who.statusBar = UI.StatusBar(page)
    page:HookScript("OnShow", function() Who.SyncControls(); Who.Update() end)
    Who.SyncControls()
end

function Who.SyncControls()
    if not Who.page then return end
    Who.InitFilter()
    local f = mod.db.wFilter
    Who.lvlMin:SetText(f.levelMin > 0 and tostring(f.levelMin) or "")
    Who.lvlMax:SetText(f.levelMax > 0 and tostring(f.levelMax) or "")
end

function Who.Update()
    if not (Who.page and Who.table and mod.db) then return end
    local list = Who.Apply()
    if Who.table.empty then Who.table.empty:SetText(Who.lastSearch and L.WHO_EMPTY or L.WHO_EMPTY_NEVER) end
    Who.table:SetData(list)
    if Who.searchBtn then if Peon.InCombat() then Who.searchBtn:Disable() else Who.searchBtn:Enable() end end
    local text
    if Who.status == "combat" then text = "|cffff6060" .. L.STATUS_COMBAT_ANY .. "|r"
    elseif Who.status == "error" then text = "|cffff6060" .. L.WHO_ERROR .. "|r"
    elseif Who.searching then text = L.STATUS_SEARCHING
    elseif not Who.lastSearch then text = L.WHO_NEVER
    else
        text = L.WHO_STATUS:format(#list, #Who.list)
        if Who.total > Who.SERVER_MAX then text = text .. ", |cffffd100" .. L.WHO_MORE:format(Who.total) .. "|r" end
    end
    Who.statusText = text
    if Who.statusBar then Who.statusBar:SetText(text) end
end

mod:RegisterEvent("WHO_LIST_UPDATE", function()
    Who.Read()
    Who.status = nil
    if Who.page then Who.Update() end
end)
