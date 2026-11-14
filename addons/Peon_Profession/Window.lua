-- Peon_Profession - Window.lua
-- Fenster "Peon Berufe" mit Peon.UI (Konzept Abschnitt 4, ab 0.2.0 mit Wuenschen von KarloDerBaer vom 14.11.2026):
--   links die Berufe (Haken "Alle Berufe" zeigt auch nicht gelernte), oben Beruf mit Stufe, Zielstufe und Knoepfe
--   fuer die Einkaufsliste. Drei Reiter unten:
--     Guide     "Jetzt" (Rezept, Anzahl, Farbe, Ersatz), Material des Schritts, weitere Schritte bis zum Ziel
--     Route     alle Schritte 1-300 mit Stand (erlernt, Farbe, Lernstufe), der aktuelle hervorgehoben
--     Material  alles Material von der Stufe bis zum Ziel mit Vorrat, Fehlt, Preis und Kosten
--   Statuszeile: Herkunft der Preise und Kosten bis zum Ziel.
-- Oeffnen: /prof, Minimap-Button, Panel, Knopf im Berufsfenster. ESC schliesst.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local W = {}
ns.Window = W

local GOLD, GREY = "|cffffd100", "|cff999999"
local function UI() return Peon.UI end
local function G() return ns.Guide end
local function P() return ns.Prices end

W.TABS = { { "guide", "TAB_GUIDE" }, { "route", "TAB_ROUTE" }, { "mats", "TAB_MATS" } }
W.contents = {}

local function SavePosition(f)
    if not f.GetPoint then return end
    local point, _, rel, x, y = f:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    mod.db.windowPos = { point = point, rel = rel, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

local function MoneyOrDash(v, vendor)
    if type(v) ~= "number" then return GREY .. "–|r" end
    return ns.Money(v) .. (vendor and (GREY .. " H|r") or "")
end

-- Spalten der Material-Tabellen (Guide und Material)
local function MatColumns()
    return {
        { key = "name", title = L.COL_MAT },
        { key = "per", title = L.COL_PER, width = 46, align = "RIGHT" },
        { key = "need", title = L.COL_TOTAL, width = 60, align = "RIGHT" },
        { key = "have", title = L.COL_HAVE, width = 60, align = "RIGHT" },
        { key = "missing", title = L.COL_MISSING, width = 60, align = "RIGHT",
          format = function(v) return (v and v > 0) and tostring(v) or (GREY .. "–|r") end },
        { key = "unit", title = L.COL_UNIT, width = 100, align = "RIGHT",
          format = function(v, item) return MoneyOrDash(v, item.src == "vendor") end },
        { key = "cost", title = L.COL_COST, width = 100, align = "RIGHT", format = function(v) return MoneyOrDash(v) end },
    }
end

function W.Create()
    if W.frame then return W.frame end
    local U = UI()
    local f = U.Window("PeonProfessionFrame", { title = ("|c%sPeon|r %s"):format(Peon.COLOR or "ff8ccf4d", L.TITLE),
        icon = ns.ICON })
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    W.frame = f

    -- Kopf: Beruf mit Stufe, Fortschritt, Ziel, Knoepfe fuer die Einkaufsliste
    W.title = U.Text(f, "big", "")
    W.title:SetPoint("TOPLEFT", 70, -32)
    W.progress = U.Progress(f, 220)
    W.progress:SetPoint("TOPLEFT", 72, -54)
    W.btnTarget = U.Button(f, "", 170, function() mod:Call("Einkaufsliste", W.ToList, "target") end)
    W.btnTarget:SetPoint("TOPRIGHT", -12, -38)
    W.btnStep = U.Button(f, L.TO_LIST_STEP, 170, function() mod:Call("Einkaufsliste", W.ToList, "step") end)
    W.btnStep:SetPoint("RIGHT", W.btnTarget, "LEFT", -6, 0)
    W.target = U.Input(f, 46, { numeric = true, maxLetters = 3 })
    W.target:SetPoint("RIGHT", W.btnStep, "LEFT", -12, 0)
    W.target:SetScript("OnEnterPressed", function(self) self:ClearFocus(); W.ApplyTarget() end)
    W.target:HookScript("OnEditFocusLost", function() W.ApplyTarget() end)
    if U.SetTooltip then U.SetTooltip(W.target, { L.TARGET_HINT }) end
    W.targetLabel = U.Text(f, "label", L.TARGET)
    W.targetLabel:SetPoint("RIGHT", W.target, "LEFT", -8, 0)

    -- links: Berufe, darunter der Haken "Alle Berufe"
    local left = U.Panel(f, "categories")
    left:SetPoint("TOPLEFT", U.EDGE, -U.TOP)
    left:SetPoint("BOTTOMLEFT", U.EDGE, U.BOTTOM)
    left:SetWidth(U.CAT_W)
    W.cats = U.CategoryList(left, {}, function(key)
        if key then W.key = key; mod.db.sel = key; W.pick = nil end
        W.Refresh()
    end)
    if W.cats.list and W.cats.list.box then W.cats.list.box:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -25, 30) end
    W.showAll = U.Check(left, L.SHOW_ALL, mod.db.showAll == true, function(on)
        mod.db.showAll = on and true or false
        W.Refresh()
    end, L.SHOW_ALL_HINT)
    W.showAll:SetPoint("BOTTOMLEFT", 6, 6)
    W.left = left
    W.x0 = U.EDGE + U.CAT_W + U.GAP

    local defs = {}
    for _, t in ipairs(W.TABS) do defs[#defs + 1] = { t[1], L[t[2]] } end
    W.tabs = U.BottomTabs(f, defs, function(key) if not W.selecting then W.Select(key) end end)
    W.status = U.StatusBar(f)
    f:SetScript("OnShow", function() mod:Call("Fenster", W.Refresh) end)
    pcall(mod.RegisterEvent, mod, "GET_ITEM_INFO_RECEIVED", function() W.Later() end)
    pcall(mod.RegisterEvent, mod, "BAG_UPDATE_DELAYED", function() W.Later() end)
    return f
end

-- Inhalt eines Reiters (einmal gebaut)
function W.Content(key)
    local c = W.contents[key]
    if c then return c end
    local U = UI()
    c = CreateFrame("Frame", nil, W.frame)
    c:SetAllPoints()
    W.contents[key] = c
    if key == "guide" then W.BuildGuide(c) elseif key == "route" then W.BuildRoute(c) else W.BuildMats(c) end
    return c
end

function W.BuildGuide(c)
    local U = UI()
    local now = U.Panel(c, "right")
    now:SetPoint("TOPLEFT", c, "TOPLEFT", W.x0, -U.TOP)
    now:SetPoint("TOPRIGHT", c, "TOPRIGHT", -U.EDGE - 1, -U.TOP)
    now:SetHeight(82)
    W.nowLabel = U.Text(now, "nav", L.NOW)
    W.nowLabel:SetPoint("TOPLEFT", 12, -8)
    W.icon = U.ItemIcon(now, nil, 1, 32)
    W.icon:SetPoint("TOPLEFT", 12, -24)
    W.name = U.Text(now, "heading", "")
    W.name:SetPoint("TOPLEFT", W.icon, "TOPRIGHT", 8, 0)
    W.count = U.Text(now, "text", "")
    W.count:SetPoint("TOPRIGHT", -12, -26)
    W.info = U.Text(now, "small", "", 560)
    W.info:SetPoint("TOPLEFT", W.icon, "TOPRIGHT", 8, -18)
    W.now = now

    local mats = U.Panel(c, "list", true)
    mats:SetPoint("TOPLEFT", now, "BOTTOMLEFT", 0, -U.GAP)
    mats:SetPoint("TOPRIGHT", now, "BOTTOMRIGHT", 0, -U.GAP)
    mats:SetHeight(150)
    W.mats = U.Table(mats, { icon = true, sortKey = "sort", empty = L.NO_MATS, columns = MatColumns(),
        onEnter = function(row, item) W.ItemTip(row, item) end })

    local plan = U.Panel(c, "list", true)
    plan:SetPoint("TOPLEFT", mats, "BOTTOMLEFT", 0, -U.GAP)
    plan:SetPoint("RIGHT", now, "RIGHT", 0, 0)
    plan:SetPoint("BOTTOM", c, "BOTTOM", 0, U.BOTTOM)
    W.plan = U.Table(plan, {
        icon = true, sortKey = "order",
        columns = {
            { key = "name", title = L.COL_RECIPE },
            { key = "range", title = L.COL_RANGE, width = 90, align = "RIGHT", sort = function(item) return item.order end },
            { key = "count", title = L.COL_COUNT, width = 70, align = "RIGHT",
              format = function(v) return v and ("ca. " .. v) or "" end },
            { key = "cost", title = L.COL_COST, width = 110, align = "RIGHT",
              format = function(v, item) if item.trainer or item.gather then return "" end return MoneyOrDash(v) end },
        },
        onClick = function(item, button)
            if button == "LeftButton" and item and not item.trainer then W.pick = item.index; W.Refresh() end
        end,
    })
end

function W.BuildRoute(c)
    local U = UI()
    local p = U.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", c, "TOPLEFT", W.x0, -U.TOP)
    p:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -U.EDGE - 1, U.BOTTOM)
    W.route = U.Table(p, {
        icon = true, sortKey = "order",
        columns = {
            { key = "name", title = L.COL_RECIPE },
            { key = "range", title = L.COL_RANGE, width = 80, align = "RIGHT", sort = function(item) return item.order end },
            { key = "count", title = L.COL_COUNT, width = 70, align = "RIGHT",
              format = function(v) return v and ("ca. " .. v) or "" end },
            { key = "status", title = L.COL_STATUS, width = 130 },
            { key = "cost", title = L.COL_COST, width = 100, align = "RIGHT",
              format = function(v, item) if item.gather then return "" end return MoneyOrDash(v) end },
        },
        rowBg = function(item) if item.current then return 0.55, 0.81, 0.3, 0.18 end end,
        onClick = function(item, button)
            if button == "LeftButton" and item then W.pick = item.index; W.Select("guide") end
        end,
    })
end

function W.BuildMats(c)
    local U = UI()
    local p = U.Panel(c, "list", true)
    p:SetPoint("TOPLEFT", c, "TOPLEFT", W.x0, -U.TOP)
    p:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -U.EDGE - 1, U.BOTTOM + 22)
    W.allMats = U.Table(p, { icon = true, sortKey = "name", empty = L.LIST_NOTHING, columns = MatColumns(),
        onEnter = function(row, item) W.ItemTip(row, item) end })
    W.matsNote = U.Text(c, "small", "")
    W.matsNote:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", W.x0 + 8, U.BOTTOM + 6)
end

-- Namen kommen vom Spiel oft verzoegert: gesammelt einmal neu zeichnen
function W.Later()
    if not W.IsOpen() or W.pending then return end
    W.pending = true
    local function Run() W.pending = nil; mod:Call("Fenster", W.Refresh) end
    if C_Timer and C_Timer.After then C_Timer.After(0.3, Run) else Run() end
end

function W.ItemTip(row, item)
    if not (GameTooltip and item and item.id) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, item.id) end
    if item.own then GameTooltip:AddLine(L.HAVE_TIP:format(item.own, item.others or 0), 1, 1, 1) end
    GameTooltip:Show()
end

function W.Place()
    local f = W.frame
    f:ClearAllPoints()
    local p = mod.db.windowPos
    if type(p) == "table" and type(p.point) == "string" and type(p.x) == "number" and type(p.y) == "number" then
        f:SetPoint(p.point, UIParent, type(p.rel) == "string" and p.rel or p.point, p.x, p.y)
    else
        f:SetPoint("CENTER")
    end
end

function W.Open(key, tab)
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.MSG_COMBAT); return end
    if not Peon.UI then mod:Print(L.TOO_OLD); return end
    W.Create()
    W.Place()
    if key then W.key = key; mod.db.sel = key; W.pick = nil end
    W.frame:Show()
    W.Select(tab or W.current or mod.db.windowTab)
end

function W.Toggle(key)
    if W.IsOpen() then W.frame:Hide() else W.Open(key) end
end

function W.IsOpen() return W.frame ~= nil and W.frame:IsShown() end

function W.Select(key)
    W.Create()
    if key ~= "route" and key ~= "mats" then key = "guide" end
    W.current = key
    mod.db.windowTab = key
    W.selecting = true
    if W.tabs and W.tabs.Select then W.tabs:Select(key) end
    W.selecting = nil
    for k, c in pairs(W.contents) do if k ~= key then c:Hide() end end
    W.Content(key):Show()
    if W.frame:IsShown() then W.Refresh() end
end

-- Berufe fuer die Liste: gelernte, mit "Alle Berufe" auch die uebrigen (Stufe 0, nicht gelernt)
function W.ProfList()
    local list = ns.ReadProfessions()
    for _, p in ipairs(list) do p.learned = true end
    if mod.db.showAll then
        local have = {}
        for _, p in ipairs(list) do have[p.key] = true end
        for _, key in ipairs(ns.ORDER) do
            if not have[key] then
                list[#list + 1] = { key = key, name = ns.ProfName(key), icon = ns.PROFS[key].icon, skill = 0, max = 0, learned = false }
            end
        end
    end
    return list
end

-- Gewaehlter Beruf: zuletzt gewaehlt, sonst der erste, der noch nicht fertig ist
function W.Current(profs)
    local pick
    for _, p in ipairs(profs) do if p.key == (W.key or mod.db.sel) then pick = p end end
    if not pick then for _, p in ipairs(profs) do if not pick and p.learned and p.skill < p.max then pick = p end end end
    return pick or profs[1]
end

-- Zielstufe aus dem Eingabefeld uebernehmen
function W.ApplyTarget()
    local prof = W.prof
    if not prof or not W.target then return end
    local v = tonumber(W.target:GetText() or "")
    G().SetTarget(prof.key, v)
    W.Refresh()
end

local function Zones(step)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local ids = (faction == "Horde") and step.H or step.A
    if type(ids) ~= "table" or #ids == 0 then return L.NO_ZONES end
    local names = {}
    for _, id in ipairs(ids) do
        local name
        if C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, id)
            if ok and type(info) == "table" then name = info.name end
        end
        names[#names + 1] = name or ("#" .. id)
    end
    return L.ZONES:format(table.concat(names, ", "))
end
W.Zones = Zones

local function LearnText(learn)
    if not (learn and learn.skill) then return "" end
    return ((L.LEARN_SRC[learn.src or "t"]) or L.LEARN_AT):format(learn.skill)
end

-- Text unter dem Namen: Farbe, erlernt, Ersatz, Lehrer
function W.InfoText(key, v, prof)
    local t = {}
    if v.gather then
        t[#t + 1] = Zones(v.step)
    elseif not (v.step.item or v.step.spell) then
        t[#t + 1] = L.FREE_STEP
    elseif v.learned then
        if v.color then t[#t + 1] = L.COLOR_LINE:format(L.COLOR[v.color] or "?") end
    else
        t[#t + 1] = L.NOT_LEARNED:format(LearnText(v.learn))
    end
    if v.alt then
        local altColor = L.COLOR[v.alt.color] or ""
        if v.color and v.color >= 2 then
            t[#t + 1] = L.ALT:format(v.alt.name, altColor, v.name or "?", L.COLOR[v.color] or "")
        else
            t[#t + 1] = L.ALT_FREE:format(v.alt.name, altColor)
        end
    end
    local hint = prof and G().TrainerHint(key, prof.skill, prof.max)
    if hint then t[#t + 1] = GOLD .. hint .. "|r" end
    return table.concat(t, "\n")
end

-- Ansicht des gewaehlten Schritts (Klick in "Weiter" oder "Route") oder des aktuellen
function W.ViewFor(key, prof)
    local route = G().Route(key)
    if type(route) ~= "table" then return nil end
    if W.pick and route[W.pick] then
        local s = route[W.pick]
        return G().View(key, s, math.max(s.from, prof.skill), W.pick)
    end
    local step, i = G().StepAt(key, prof.skill)
    if not step then return nil end
    return G().View(key, step, prof.skill, i)
end

function W.Refresh()
    if not W.frame then return end
    W.current = W.current or mod.db.windowTab or "guide"
    if W.current ~= "route" and W.current ~= "mats" then W.current = "guide" end
    W.Content(W.current)   -- OnShow kann vor dem ersten Select kommen
    local profs = W.ProfList()
    local nodes = {}
    for _, p in ipairs(profs) do
        local text = p.learned and ("%s  %d/%d"):format(p.name, p.skill, p.max) or (GREY .. p.name .. "  –|r")
        nodes[#nodes + 1] = { key = p.key, text = text }
    end
    W.cats:SetNodes(nodes)
    local prof = W.Current(profs)
    W.prof, W.view = prof, nil
    local craft = prof and ns.PROFS[prof.key] and ns.PROFS[prof.key].craft
    local hasBroker = P().Broker() ~= nil
    W.btnStep:SetShown(craft and hasBroker and W.current == "guide")
    W.btnTarget:SetShown(craft and hasBroker)
    W.target:SetShown(prof ~= nil)
    W.targetLabel:SetShown(prof ~= nil)
    if not prof then
        W.title:SetText(L.NO_PROFS)
        W.progress:Set(0, "")
        W.Empty(L.NO_PROFS)
        return
    end
    W.key = prof.key
    -- ab 0.2.2: der gezeigte Beruf ist der verfolgte, die Leiste von Peon_Panel zeigt ihn
    if mod.db.sel ~= prof.key then mod.db.sel = prof.key; ns.RefreshLauncher() end
    W.cats:Select(prof.key)
    if prof.learned then
        W.title:SetText(L.SKILL:format(prof.name, prof.skill, prof.max))
        W.progress:Set(prof.skill / math.max(1, prof.max), "")
    else
        W.title:SetText(prof.name .. "  " .. GREY .. L.NOT_LEARNED_P .. "|r")
        W.progress:Set(0, "")
    end
    W.goal = G().Target(prof.key, prof.skill, prof.max)
    if not (W.target.HasFocus and W.target:HasFocus()) then W.target:SetText(tostring(W.goal)) end
    W.btnTarget:SetText(L.TO_LIST_TARGET:format(W.goal))

    if not G().Route(prof.key) then W.Empty(L.NO_ROUTE); return end
    W.planRows = G().Plan(prof.key, prof.skill, prof.max, W.goal)
    if W.current == "route" then W.FillRoute(prof)
    elseif W.current == "mats" then W.FillMats(prof)
    else
        local v = W.ViewFor(prof.key, prof)
        W.view = v
        if v then W.FillNow(prof, v)
        else W.EmptyNow(prof.skill >= 300 and L.DONE_ALL:format(prof.name, prof.skill) or L.DONE:format(prof.name, prof.max)) end
        W.FillPlan(prof)
    end
    W.UpdateStatus(prof)
end

function W.EmptyNow(text)
    if not W.icon then return end
    W.icon:Hide()
    W.name:SetText(text or "")
    W.count:SetText("")
    W.info:SetText("")
    W.mats:SetData({})
end

function W.Empty(text)
    if W.current == "guide" or not W.current then
        W.EmptyNow(text)
        if W.plan then W.plan:SetData({}) end
    elseif W.current == "route" and W.route then W.route:SetData({})
    elseif W.allMats then W.allMats:SetData({}); W.matsNote:SetText(text or "") end
    W.status:SetText(P().Broker() and L.PRICES_BROKER or L.PRICES_NONE)
    if W.status.money then W.status.money:SetAmount(0) end
end

function W.FillNow(prof, v)
    local key = prof.key
    W.icon:Show()
    local rows = {}
    if v.gather then
        local names = {}
        for _, id in ipairs(v.gather) do names[#names + 1] = ns.ItemName(id) or ("#" .. id) end
        W.icon:Set(v.gather[1] and ns.ItemIcon(v.gather[1]) or ns.PROFS[key].icon, 1)
        W.name:SetText(L.GATHER:format(table.concat(names, ", ")))
        W.count:SetText(L.CRAFT_RANGE:format(v.from, v.to))
        for i, id in ipairs(v.gather) do
            local have, own, others = P().Stock(id)
            rows[#rows + 1] = { id = id, sort = i, name = ns.ItemName(id) or ("#" .. id), icon = ns.ItemIcon(id), have = have,
                own = own, others = others }
        end
    else
        local item = v.alt and v.alt.item or v.item
        local spell = v.alt and v.alt.id or v.spell
        local name, q = G().RecipeName(item, spell, v.alt and v.alt.rec or v.rec)
        if not (v.item or v.spell or v.alt) then name = L.FREE_STEP end
        W.icon:Set(G().RecipeIcon(item, spell), q)
        W.name:SetText(name)
        W.count:SetText(v.count and L.CRAFT_N:format(v.count, v.to) or L.CRAFT_RANGE:format(v.from, v.to))
        local mats = G().Active(v) or {}
        local list = P().Rows(mats, v.count or 1)
        for i, r in ipairs(list) do
            local n, rq = ns.ItemName(r.id)
            r.sort, r.name, r.icon, r.quality = i, n or ("#" .. r.id), ns.ItemIcon(r.id), rq
            rows[#rows + 1] = r
        end
    end
    W.info:SetText(W.InfoText(key, v, prof))
    W.mats:SetData(rows)
end

-- Zeile fuer einen Plan- oder Routenschritt
local function StepItem(key, e, order)
    local it = { order = order, index = e.index, trainer = e.trainer, gather = e.gather }
    if e.trainer then
        it.name = GOLD .. (e.from > 0 and L.TRAINER_ROW:format(e.from, e.rank) or L.LEARN_FIRST:format(e.rank)) .. "|r"
        it.range = ""
        it.icon = ns.PROFS[key].icon
        return it
    end
    it.range = L.CRAFT_RANGE:format(e.from, e.to)
    it.count = e.count
    if e.gather then
        local names = {}
        for _, id in ipairs(e.gather) do names[#names + 1] = ns.ItemName(id) or ("#" .. id) end
        it.name = table.concat(names, ", ")
        it.icon = e.gather[1] and ns.ItemIcon(e.gather[1]) or ns.PROFS[key].icon
    elseif e.item or e.spell then
        local _, rec = G().KnownFor(key, e.step)
        local n, q = G().RecipeName(e.item, e.spell, rec)
        it.name, it.quality, it.icon = n, q, G().RecipeIcon(e.item, e.spell)
        local need = G().Need(key, { e })
        if next(need) then
            local cost, noPrice = P().NeedCost(need)
            it.cost = (noPrice == 0 or cost > 0) and cost or nil
        end
        it.rec = rec
    else
        it.name = GREY .. L.FREE_STEP .. "|r"
        it.icon = ns.PROFS[key].icon
    end
    return it
end

function W.FillPlan(prof)
    local items = {}
    for i, e in ipairs(W.planRows or {}) do items[#items + 1] = StepItem(prof.key, e, i) end
    W.plan:SetData(items)
end

-- Reiter Route: alle Schritte 1-300 mit Stand
function W.FillRoute(prof)
    local key = prof.key
    local items = {}
    local _, cur = G().StepAt(key, prof.skill)
    for i, s in ipairs(G().Route(key)) do
        local e = { from = s.from, to = s.to, step = s, index = i, item = s.item, spell = s.spell, gather = s.gather, count = s.n }
        local it = StepItem(key, e, i)
        it.current = prof.learned and i == cur
        if s.to <= prof.skill then it.name = GREY .. (it.name or "") .. "|r" end
        if s.gather then
            it.status = ""
        elseif it.rec then
            it.status = L.COLOR[it.rec.c] or ""
        elseif s.item or s.spell then
            local learn = s.spell and ns.Learn and ns.Learn[s.spell]
            it.status = GREY .. ((learn and learn.skill) and L.STATUS_LEARN:format(learn.skill) or L.STATUS_UNKNOWN) .. "|r"
        else
            it.status = ""
        end
        items[#items + 1] = it
    end
    W.route:SetData(items)
end

-- Reiter Material: alles von der Stufe bis zum Ziel
function W.FillMats(prof)
    local need = G().Need(prof.key, W.planRows or {})
    local rows = {}
    for id, n in pairs(need) do
        local have, own, others = P().Stock(id)
        local missing = math.max(0, n - have)
        local unit, src = P().Unit(id)
        local name, q = ns.ItemName(id)
        rows[#rows + 1] = { id = id, name = name or ("#" .. id), quality = q, icon = ns.ItemIcon(id), need = n, have = have,
            own = own, others = others, missing = missing, unit = unit, src = src,
            cost = (missing > 0 and unit) and unit * missing or nil }
    end
    W.allMats:SetData(rows)
    local noMats = 0
    for _, e in ipairs(W.planRows or {}) do
        if e.step and not e.trainer and not e.gather then
            local _, rec = G().KnownFor(prof.key, e.step)
            if #G().MatsOf(rec, e.step) == 0 then noMats = noMats + 1 end
        end
    end
    local from = math.max(1, prof.skill)
    local text = GOLD .. L.MATS_HDR:format(from, W.goal) .. "|r"
    if noMats > 0 then text = text .. "   " .. GREY .. L.MATS_NONE:format(noMats) .. "|r" end
    W.matsNote:SetText(text)
end

-- Statuszeile: Preise und Kosten bis zum Ziel
function W.UpdateStatus(prof)
    local need = G().Need(prof.key, W.planRows or {})
    local total, noPrice = P().NeedCost(need)
    local text = P().Broker() and L.PRICES_BROKER or L.PRICES_NONE
    if P().Broker() and next(need) then
        text = text .. "   " .. L.COST_ALL:format(W.goal or prof.max, ns.Money(total)) .. (noPrice > 0 and L.COST_PART:format(noPrice) or "")
    end
    W.status:SetText(text)
    if W.status.money then W.status.money:SetAmount(total or 0) end
end

-- Einkaufsliste: "step" = gezeigter Schritt (aktives Rezept), "target" = alle Schritte bis zum Ziel
function W.ToList(which)
    local prof = W.prof
    if not prof then return 0 end
    local need = {}
    if which == "step" then
        local v = W.view
        if not v or v.gather then return 0 end
        for _, m in ipairs(G().Active(v) or {}) do need[m.id] = (need[m.id] or 0) + m.q * (v.count or 1) end
    else
        need = G().Need(prof.key, G().Plan(prof.key, prof.skill, prof.max, G().Target(prof.key, prof.skill, prof.max)))
    end
    local n = P().ToList(prof.key, need)
    W.Refresh()
    return n
end
