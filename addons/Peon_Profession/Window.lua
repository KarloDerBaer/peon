-- Peon_Profession - Window.lua
-- Fenster "Peon Berufe" mit Peon.UI (Konzept Abschnitt 4): links die Berufe, oben der Beruf mit Stufe und den Knoepfen
-- fuer die Einkaufsliste, rechts "Jetzt" (Rezept, Anzahl, Farbe, Ersatz), darunter das Material und die weiteren
-- Schritte bis zum Hoechstwert mit Kosten. Statuszeile: Herkunft der Preise und Kosten bis zum Hoechstwert.
-- Oeffnen: /prof, Minimap-Button, Panel, Knopf "Guide" an der Leiste im Berufsfenster. ESC schliesst.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local W = {}
ns.Window = W

local GOLD, GREY, WHITE = "|cffffd100", "|cff999999", "|cffffffff"
local function UI() return Peon.UI end
local function G() return ns.Guide end
local function P() return ns.Prices end

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

function W.Create()
    if W.frame then return W.frame end
    local U = UI()
    local f = U.Window("PeonProfessionFrame", { title = ("|c%sPeon|r %s"):format(Peon.COLOR or "ff8ccf4d", L.TITLE),
        icon = "Interface\\Icons\\INV_Misc_Note_01" })
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    W.frame = f

    -- Kopf: Beruf mit Stufe, Fortschritt, Knoepfe fuer die Einkaufsliste
    W.title = U.Text(f, "big", "")
    W.title:SetPoint("TOPLEFT", 70, -32)
    W.progress = U.Progress(f, 220)
    W.progress:SetPoint("TOPLEFT", 72, -54)
    W.btnMax = U.Button(f, "", 170, function() mod:Call("Einkaufsliste", W.ToList, "max") end)
    W.btnMax:SetPoint("TOPRIGHT", -12, -38)
    W.btnStep = U.Button(f, L.TO_LIST_STEP, 170, function() mod:Call("Einkaufsliste", W.ToList, "step") end)
    W.btnStep:SetPoint("RIGHT", W.btnMax, "LEFT", -6, 0)

    -- links: Berufe
    local left = U.Panel(f, "categories")
    left:SetPoint("TOPLEFT", U.EDGE, -U.TOP)
    left:SetPoint("BOTTOMLEFT", U.EDGE, U.BOTTOM)
    left:SetWidth(U.CAT_W)
    W.cats = U.CategoryList(left, {}, function(key)
        if key then W.key = key; mod.db.sel = key; W.pick = nil end
        W.Refresh()
    end)
    W.left = left
    local x0 = U.EDGE + U.CAT_W + U.GAP

    -- Jetzt
    local now = U.Panel(f, "right")
    now:SetPoint("TOPLEFT", x0, -U.TOP)
    now:SetPoint("TOPRIGHT", -U.EDGE - 1, -U.TOP)
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

    -- Material
    local mats = U.Panel(f, "list", true)
    mats:SetPoint("TOPLEFT", now, "BOTTOMLEFT", 0, -U.GAP)
    mats:SetPoint("TOPRIGHT", now, "BOTTOMRIGHT", 0, -U.GAP)
    mats:SetHeight(150)
    W.mats = U.Table(mats, {
        icon = true, sortKey = "sort", empty = L.NO_MATS,
        columns = {
            { key = "name", title = L.COL_MAT },
            { key = "per", title = L.COL_PER, width = 46, align = "RIGHT" },
            { key = "need", title = L.COL_TOTAL, width = 60, align = "RIGHT" },
            { key = "have", title = L.COL_HAVE, width = 60, align = "RIGHT" },
            { key = "missing", title = L.COL_MISSING, width = 60, align = "RIGHT",
              format = function(v) return (v and v > 0) and tostring(v) or (GREY .. "–|r") end },
            { key = "unit", title = L.COL_UNIT, width = 100, align = "RIGHT",
              format = function(v, item) return MoneyOrDash(v, item.src == "vendor") end },
            { key = "cost", title = L.COL_COST, width = 100, align = "RIGHT", format = function(v) return MoneyOrDash(v) end },
        },
        onEnter = function(row, item) W.ItemTip(row, item) end,
    })

    -- Weiter bis zum Hoechstwert
    local plan = U.Panel(f, "list", true)
    plan:SetPoint("TOPLEFT", mats, "BOTTOMLEFT", 0, -U.GAP)
    plan:SetPoint("RIGHT", now, "RIGHT", 0, 0)
    plan:SetPoint("BOTTOM", f, "BOTTOM", 0, U.BOTTOM)
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

    W.status = U.StatusBar(f)
    f:SetScript("OnShow", function() mod:Call("Fenster", W.Refresh) end)
    pcall(mod.RegisterEvent, mod, "GET_ITEM_INFO_RECEIVED", function() W.Later() end)
    pcall(mod.RegisterEvent, mod, "BAG_UPDATE_DELAYED", function() W.Later() end)
    return f
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

function W.Open(key)
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.MSG_COMBAT); return end
    if not Peon.UI then mod:Print(L.TOO_OLD); return end
    W.Create()
    W.Place()
    if key then W.key = key; mod.db.sel = key; W.pick = nil end
    W.frame:Show()
    W.Refresh()
end

function W.Toggle(key)
    if W.IsOpen() then W.frame:Hide() else W.Open(key) end
end

function W.IsOpen() return W.frame ~= nil and W.frame:IsShown() end

-- Gewaehlter Beruf: zuletzt gewaehlt, sonst der erste, der noch nicht fertig ist
function W.Current(profs)
    local pick
    for _, p in ipairs(profs) do if p.key == (W.key or mod.db.sel) then pick = p end end
    if not pick then for _, p in ipairs(profs) do if not pick and p.skill < p.max then pick = p end end end
    return pick or profs[1]
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
        local learn = v.learn
        local extra = ""
        if learn and learn.skill then extra = ((L.LEARN_SRC[learn.src or "t"]) or L.LEARN_AT):format(learn.skill) end
        t[#t + 1] = L.NOT_LEARNED:format(extra)
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

-- Ansicht des gewaehlten Schritts (Klick in "Weiter") oder des aktuellen
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
    local profs = ns.ReadProfessions()
    local nodes = {}
    for _, p in ipairs(profs) do nodes[#nodes + 1] = { key = p.key, text = ("%s  %d/%d"):format(p.name, p.skill, p.max) } end
    W.cats:SetNodes(nodes)
    local prof = W.Current(profs)
    W.prof, W.view = prof, nil
    if not prof then
        W.title:SetText(L.NO_PROFS)
        W.progress:Set(0, "")
        W.Empty(L.NO_PROFS)
        return
    end
    W.key = prof.key
    W.cats:Select(prof.key)
    W.title:SetText(L.SKILL:format(prof.name, prof.skill, prof.max))
    W.progress:Set(prof.skill / math.max(1, prof.max), "")
    W.btnMax:SetText(L.TO_LIST_MAX:format(prof.max))
    local craft = ns.PROFS[prof.key] and ns.PROFS[prof.key].craft
    W.btnStep:SetShown(craft and P().Broker() ~= nil)
    W.btnMax:SetShown(craft and P().Broker() ~= nil)

    if not G().Route(prof.key) then W.Empty(L.NO_ROUTE); return end
    local v = W.ViewFor(prof.key, prof)
    W.view = v
    if not v then
        W.Empty(prof.skill >= 300 and L.DONE_ALL:format(prof.name, prof.skill) or L.DONE:format(prof.name, prof.max))
        W.FillPlan(prof)
        return
    end
    W.FillNow(prof, v)
    W.FillPlan(prof)
end

function W.Empty(text)
    W.icon:Hide()
    W.name:SetText(text or "")
    W.count:SetText("")
    W.info:SetText("")
    W.mats:SetData({})
    W.plan:SetData({})
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
        local list, total, noPrice = P().Rows(mats, v.count or 1)
        for i, r in ipairs(list) do
            local n, rq = ns.ItemName(r.id)
            r.sort, r.name, r.icon, r.quality = i, n or ("#" .. r.id), ns.ItemIcon(r.id), rq
            rows[#rows + 1] = r
        end
        W.nowCost, W.nowNoPrice = total, noPrice
    end
    W.info:SetText(W.InfoText(key, v, prof))
    W.mats:SetData(rows)
end

function W.FillPlan(prof)
    local key = prof.key
    local plan = G().Plan(key, prof.skill, prof.max)
    local items = {}
    for i, e in ipairs(plan) do
        local it = { order = i, index = e.index, trainer = e.trainer, gather = e.gather }
        if e.trainer then
            it.name = GOLD .. L.TRAINER_ROW:format(e.from, e.rank) .. "|r"
            it.range = ""
            it.icon = ns.PROFS[key].icon
        else
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
                local cost, noPrice = P().NeedCost(need)
                it.cost = (noPrice == 0 or cost > 0) and cost or nil
            else
                it.name = GREY .. L.FREE_STEP .. "|r"
                it.icon = ns.PROFS[key].icon
            end
        end
        items[#items + 1] = it
    end
    W.plan:SetData(items)
    W.planRows = plan
    -- Statuszeile: Preise und Kosten bis zum Hoechstwert
    local need = G().Need(key, plan)
    local total, noPrice = P().NeedCost(need)
    local text = P().Broker() and L.PRICES_BROKER or L.PRICES_NONE
    if P().Broker() and next(need) then
        text = text .. "   " .. L.COST_ALL:format(prof.max, ns.Money(total)) .. (noPrice > 0 and L.COST_PART:format(noPrice) or "")
    end
    W.status:SetText(text)
    if W.status.money then W.status.money:SetAmount(total or 0) end
end

-- Einkaufsliste: "step" = gezeigter Schritt (aktives Rezept), "max" = alle Schritte bis zum Hoechstwert
function W.ToList(which)
    local prof = W.prof
    if not prof then return 0 end
    local need = {}
    if which == "step" then
        local v = W.view
        if not v or v.gather then return 0 end
        for _, m in ipairs(G().Active(v) or {}) do need[m.id] = (need[m.id] or 0) + m.q * (v.count or 1) end
    else
        need = G().Need(prof.key, G().Plan(prof.key, prof.skill, prof.max))
    end
    local n = P().ToList(prof.key, need)
    W.Refresh()
    return n
end
