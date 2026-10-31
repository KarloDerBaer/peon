-- Peon_Fishing - Catches.lua
-- Fangdatenbank (accountweit, PeonFishingDB.catches), Fangliste im Angelmodus und Uebersichtsfenster.
--
-- Ein "Fang" = ein Beutefenster vom Angeln (IsFishingLoot). Gezaehlt wird pro Zone/Unterzone:
--   n      = Anzahl Faenge
--   items  = in wie vielen Faengen der Gegenstand dabei war (Grundlage fuer die Prozentzahl)
--   qty    = Gesamtmenge
-- Alle Faenge zaehlen fuer die Unterzone. Ein Fang, der eindeutig aus einem Fischschwarm stammt,
-- wird dort getrennt gefuehrt (pitems/pqty). Ist ein Fischschwarm in der Unterzone entdeckt
-- (e.pools), werden alle Fische dieser Art dort zusammengefasst und als "<Fisch> (Schwarm)" angezeigt.

local ADDON_NAME, ns = ...
local L = ns.L
local IsSecret = ns.IsSecret

local MAX_LIST_LINES = 15

local function DB()
    local acc = PeonFishingDB
    if type(acc) ~= "table" then return nil end
    local c = acc.catches
    if type(c) ~= "table" then c = {}; acc.catches = c end
    c.zones = c.zones or {}
    c.info = c.info or {}
    -- Alte Schwarm-Eintraege (0.9.2-0.9.10) in die Unterzonen einsortieren
    if type(c.pools) == "table" or not c.poolMerged then
        c.poolMerged = true
        if ns.MergeOldPools then ns.MergeOldPools(c) end
    end
    c.poolFish = c.poolFish or {}
    c.poolRepair = nil
    if not c.poolMarked then          -- 0.9.12: bereits einsortierte Schwarm-Fische -> Schwarm entdeckt
        c.poolMarked = true
        for _, subs in pairs(c.zones) do
            for _, e in pairs(subs) do
                for name, fish in pairs(c.poolFish) do
                    for id in pairs(e.pitems or {}) do
                        if fish[id] then e.pools = e.pools or {}; e.pools[name] = true end
                    end
                end
            end
        end
    end
    return c
end

local function Text(v)
    if v == nil or IsSecret(v) or v == "" then return nil end
    return v
end

-- Aktueller Ort: Zone und Unterzone (ohne Unterzone = Zonenname)
function ns.CurrentPlace()
    local zone = Text(GetRealZoneText and GetRealZoneText()) or Text(GetZoneText and GetZoneText()) or UNKNOWN
    local sub = Text(GetSubZoneText and GetSubZoneText()) or zone
    return zone, sub
end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    return (c and c.hex) or "|cffffffff"
end

local function FishLabel(id, pool)
    local info = DB().info[id] or {}
    local icon = info.icon and ("|T" .. info.icon .. ":14:14|t ") or ""
    return icon .. QualityColor(info.q) .. (info.name or ("item:" .. id)) .. "|r"
        .. (pool and (" |cff66ccff" .. L.CATCH_POOL_TAG .. "|r") or "")
end

local IsKnownPoolFish        -- weiter unten definiert

-- Eintraege eines Ortes sortiert (haeufigste zuerst). Fische eines in dieser Unterzone entdeckten
-- Schwarms werden zusammengefasst und als "(Schwarm)" markiert.
local function SortedItems(entry)
    local byId = {}
    local function add(id, count, qty)
        local r = byId[id]
        if not r then r = { id = id, count = 0, qty = 0 }; byId[id] = r end
        r.count = r.count + count
        r.qty = r.qty + qty
    end
    for id, count in pairs(entry.items or {}) do add(id, count, (entry.qty and entry.qty[id]) or count) end
    for id, count in pairs(entry.pitems or {}) do add(id, count, (entry.pqty and entry.pqty[id]) or count) end
    local list = {}
    for id, r in pairs(byId) do
        r.pool = (entry.pitems and entry.pitems[id]) and true or IsKnownPoolFish(entry, id)
        list[#list + 1] = r
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    return list
end

---------------------------------------------------------------------------
-- Schwaerme sind nie Soft-Ziel, es gibt kein Ereignis, und die Beute-Quelle (GetLootSourceInfo) ist
-- auch im Schwarm der Schwimmer. Erkennbar sind sie nur ueber den Tooltip unter dem Mauszeiger.
-- Ein Schwarm ist "aktiv", wenn auf ihn gezeigt wurde, der Spieler seitdem am selben Platz steht und
-- das hoechstens POOL_WINDOW Sekunden her ist. Rechtsklick auf die Fangliste loest ihn.
-- Gezeigt heisst ausserdem: der Schwarm ist in dieser Unterzone entdeckt (e.pools, siehe unten).
---------------------------------------------------------------------------
local POOL_WORDS = { "schwarm", "school", "wrack", "wreckage", "treibgut", "flotsam", "ölteppich", "oil spill",
    "elementarem wasser", "elemental water" }
local POOL_WINDOW = 180
local POOL_MOVE = 0.004        -- Kartenanteil (grob 5-15 m)
local lastPool, lastPoolTime, lastPoolPos

local function IsPoolName(t)
    if not t then return false end
    local lt = t:lower()
    for _, w in ipairs(POOL_WORDS) do
        if lt:find(w, 1, true) then return true end
    end
    return false
end

local function PlayerPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or IsSecret(map) then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local ok, x, y = pcall(pos.GetXY, pos)
    if not ok or not x or IsSecret(x) or IsSecret(y) then return nil end
    return { map = map, x = x, y = y }
end

-- Liefert den aktiven Schwarm oder nil plus Grund (fuer das Debug-Log)
local function ActivePool()
    if not lastPool then return nil, "kein Schwarm gezeigt" end
    local age = GetTime() - lastPoolTime
    if age > POOL_WINDOW then return nil, ("zu lange her (%.0f s)"):format(age) end
    local now = PlayerPos()
    if lastPoolPos and now then
        if now.map ~= lastPoolPos.map then return nil, "andere Karte" end
        local dx, dy = now.x - lastPoolPos.x, now.y - lastPoolPos.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > POOL_MOVE then return nil, ("bewegt (%.4f)"):format(d) end
    end
    return lastPool, ("vor %.0f s gezeigt"):format(age)
end
function ns.ReleasePool()
    if lastPool then
        ns.Dbg("Schwarm geloest: " .. lastPool)
        lastPool = nil
        ns.UpdateCatchList()
    end
end
ns.ActivePool = ActivePool

---------------------------------------------------------------------------
-- Passt der Fang zum Schwarm? Ein Fischschwarm liefert (fast) nur seinen Fisch. Faengt man etwas
-- anderes, lag der Schwimmer ausserhalb des Schwarms: dann zaehlt der Fang fuer die Unterzone.
-- Erkennung: gemeinsamer Namensteil von Schwarm und Gegenstand (NameMatches), z. B.
-- "Schwarm oeliger Schwarzmaulfische" / "Oeliges Schwarzmaul" -> "schwarzmaul". Einmal erkannte
-- Fische merkt sich c.poolFish[Schwarm]. Wrackteile, Treibgut, Oelteppiche u. Ae. liefern
-- gemischte Beute: dort gilt nichts als eindeutig.
---------------------------------------------------------------------------
local FISH_POOL_WORDS = { "schwarm", "school" }
local MIN_WORD = 6        -- nur Woerter ab 6 Zeichen vergleichen
local MIN_SHARE = 0.8     -- mind. 80 % des Wortes muessen im Schwarmnamen vorkommen

local function CommonLen(a, b)
    local best = 0
    local prev = {}
    for i = 1, #a do
        local cur = {}
        local ai = a:byte(i)
        for j = 1, #b do
            if ai == b:byte(j) then
                local v = (prev[j - 1] or 0) + 1
                cur[j] = v
                if v > best then best = v end
            end
        end
        prev = cur
    end
    return best
end

local function IsFishPool(name)
    local lt = name:lower()
    for _, w in ipairs(FISH_POOL_WORDS) do
        if lt:find(w, 1, true) then return true end
    end
    return false
end

-- Passt der Gegenstandsname zum Schwarmnamen? Das laengste Wort des Gegenstands (ab 6 Zeichen)
-- muss zu mind. 80 % im Schwarmnamen stehen: "Schwarzmaul" passt zu "...Schwarzmaulfische",
-- "Schwarzer" (nur "schwarz", 78 %) nicht, "Raw Longjaw Mud Snapper" nicht zu "Firefin Snapper School".
local function NameMatches(stripped, itemName)
    local longest = ""
    for w in itemName:lower():gmatch("[^%s%-]+") do
        if #w > #longest then longest = w end
    end
    return #longest >= MIN_WORD and CommonLen(stripped, longest) >= math.ceil(#longest * MIN_SHARE)
end

-- Liefert die Gegenstaende des Fangs, die eindeutig zum Fischschwarm gehoeren (oder nil).
-- learned = gemerkte Fische dieses Schwarms (c.poolFish[Name]), wird ergaenzt.
local function PoolFishOf(poolName, learned, seen, info)
    if not IsFishPool(poolName) then return nil end
    local stripped = poolName:lower()
    for _, w in ipairs(FISH_POOL_WORDS) do stripped = stripped:gsub(w, " ") end
    local found
    for id in pairs(seen) do
        local nm = info[id] and info[id].name
        if (learned and learned[id]) or (nm and NameMatches(stripped, nm)) then
            found = found or {}
            found[id] = true
            if learned then learned[id] = true end
        end
    end
    return found
end

-- Gehoert der Fisch zu einem Schwarm, der in dieser Unterzone entdeckt wurde (e.pools)?
IsKnownPoolFish = function(e, id)
    if not e.pools then return false end
    local c = DB()
    for name in pairs(e.pools) do
        local learned = c.poolFish[name]
        if (learned and learned[id]) or PoolFishOf(name, nil, { [id] = 1 }, c.info) then return true end
    end
    return false
end

-- Schwarm in der aktuellen Unterzone als entdeckt merken
local function MarkPoolHere(name)
    if not IsFishPool(name) then return end
    local c = DB()
    if not c then return end
    local zone, sub = ns.CurrentPlace()
    c.zones[zone] = c.zones[zone] or {}
    local e = c.zones[zone][sub] or { n = 0, items = {}, qty = {} }
    c.zones[zone][sub] = e
    e.pools = e.pools or {}
    if not e.pools[name] then
        e.pools[name] = true
        ns.Dbg(("Schwarm entdeckt: %s in %s / %s"):format(name, zone, sub))
    end
end

-- Alte Schwarm-Eintraege (eigene Liste bzw. Eintrag mit pool = true) in die Unterzone einsortieren,
-- in der die Fische des Schwarms am haeufigsten gefangen wurden. Passende Fische -> "(Schwarm)".
function ns.MergeOldPools(c)
    local old = {}
    if type(c.pools) == "table" then
        for key, e in pairs(c.pools) do old[#old + 1] = { name = e.name or key, e = e } end
    end
    c.pools = nil
    for z, subs in pairs(c.zones) do
        for sname, e in pairs(subs) do
            if e.pool then old[#old + 1] = { name = sname, e = e, zone = z }; subs[sname] = nil end
        end
    end
    for _, o in ipairs(old) do
        local e = o.e
        local fish = PoolFishOf(o.name, nil, e.items, c.info) or {}
        local bestZone, bestSub, best = nil, nil, -1
        for z, subs in pairs(c.zones) do
            if z ~= UNKNOWN and (not o.zone or o.zone == UNKNOWN or o.zone == z) then
                for sname, se in pairs(subs) do
                    local cnt = 0
                    for id in pairs(fish) do cnt = cnt + (se.items[id] or 0) end
                    if cnt > best then bestZone, bestSub, best = z, sname, cnt end
                end
            end
        end
        if not bestZone then bestZone, bestSub = o.zone or UNKNOWN, o.zone or UNKNOWN end
        c.zones[bestZone] = c.zones[bestZone] or {}
        local se = c.zones[bestZone][bestSub] or { n = 0, items = {}, qty = {} }
        c.zones[bestZone][bestSub] = se
        se.pitems, se.pqty = se.pitems or {}, se.pqty or {}
        se.n = se.n + e.n
        for id, count in pairs(e.items) do
            local q = e.qty[id] or count
            if fish[id] then
                se.pitems[id] = (se.pitems[id] or 0) + count
                se.pqty[id] = (se.pqty[id] or 0) + q
            else
                se.items[id] = (se.items[id] or 0) + count
                se.qty[id] = (se.qty[id] or 0) + q
            end
        end
        if IsFishPool(o.name) then
            se.pools = se.pools or {}
            se.pools[o.name] = true
        end
        c.poolFish = c.poolFish or {}
        c.poolFish[o.name] = c.poolFish[o.name] or {}
        for id in pairs(fish) do c.poolFish[o.name][id] = true end
        ns.Dbg(("Alter Schwarm einsortiert: %s -> %s / %s"):format(o.name, bestZone, bestSub))
    end
    if c.zones[UNKNOWN] and next(c.zones[UNKNOWN]) == nil then c.zones[UNKNOWN] = nil end
end

---------------------------------------------------------------------------
-- Aufzeichnen
---------------------------------------------------------------------------
local counted = false

local function Record()
    local c = DB()
    if not c then return end
    local seen = {}
    for slot = 1, GetNumLootItems() or 0 do
        local link = GetLootSlotLink(slot)
        local id = type(link) == "string" and not IsSecret(link) and tonumber(link:match("item:(%d+)"))
        if id then
            local icon, name, qty, _, quality = GetLootSlotInfo(slot)
            local info = c.info[id] or {}
            if Text(name) then info.name = name end
            if icon and not IsSecret(icon) then info.icon = icon end
            if type(quality) == "number" and not IsSecret(quality) then info.q = quality end
            c.info[id] = info
            seen[id] = (seen[id] or 0) + ((type(qty) == "number" and not IsSecret(qty)) and qty or 1)
        end
    end
    if next(seen) == nil then return end

    local zone, sub = ns.CurrentPlace()
    c.zones[zone] = c.zones[zone] or {}
    local pool, why = ActivePool()
    local poolFish
    if pool then
        c.poolFish[pool] = c.poolFish[pool] or {}
        poolFish = PoolFishOf(pool, c.poolFish[pool], seen, c.info)
        if not poolFish then why = why .. ", nicht eindeutig aus dem Schwarm" end
    end
    ns.Dbg("Schwarm-Zuordnung: " .. tostring(poolFish and pool) .. " (" .. why .. ")")
    if pool then MarkPoolHere(pool) end
    local e = c.zones[zone][sub] or { n = 0, items = {}, qty = {} }
    c.zones[zone][sub] = e
    e.n = e.n + 1
    for id, q in pairs(seen) do
        if poolFish and poolFish[id] then
            e.pitems, e.pqty = e.pitems or {}, e.pqty or {}
            e.pitems[id] = (e.pitems[id] or 0) + 1
            e.pqty[id] = (e.pqty[id] or 0) + q
        else
            e.items[id] = (e.items[id] or 0) + 1
            e.qty[id] = (e.qty[id] or 0) + q
        end
    end
    local place = sub .. (poolFish and " (Schwarm)" or "")
    ns.Dbg(("Fang gezaehlt: %s / %s (%d Faenge)"):format(zone, place, e.n))
    if ns.UpdateCatchList then ns.UpdateCatchList() end
    if ns.RefreshOverview then ns.RefreshOverview() end
end

local function WorldTip()
    if not (C_TooltipInfo and C_TooltipInfo.GetWorldCursor) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
    if ok and type(data) == "table" and type(data.lines) == "table" and data.lines[1] then
        return Text(data.lines[1].leftText)
    end
end

---------------------------------------------------------------------------
-- Fangliste im Angelmodus
---------------------------------------------------------------------------
local list
local shownPool       -- zuletzt angezeigter Schwarm (Ticker erkennt Aenderungen)

local function CreateList()
    list = CreateFrame("Frame", "PeonFishingCatchList", UIParent, "BackdropTemplate")
    list:SetSize(240, 60)
    list:SetFrameStrata("MEDIUM")
    list:SetClampedToScreen(true)
    list:SetMovable(true)
    list:EnableMouse(true)
    list:RegisterForDrag("LeftButton")
    if list.SetBackdrop then
        list:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        list:SetBackdropColor(0, 0, 0, 0.7)
        list:SetBackdropBorderColor(0.4, 0.6, 0.8, 0.9)
    end
    list:SetScript("OnDragStart", function(self) self:StartMoving() end)
    list:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.ReleasePool() end
    end)
    list:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        PeonFishingDB.catchListPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    list.title = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    list.title:SetPoint("TOPLEFT", 8, -8)
    list.title:SetPoint("TOPRIGHT", -8, -8)
    list.title:SetJustifyH("LEFT")
    list.sub = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    list.sub:SetPoint("TOPLEFT", list.title, "BOTTOMLEFT", 0, -2)
    list.lines = {}
    for i = 1, MAX_LIST_LINES do
        local l = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 8, -34 - (i - 1) * 16)
        l:SetJustifyH("LEFT")
        l:SetWidth(170)
        l:SetWordWrap(false)
        local r = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r:SetPoint("TOPRIGHT", -8, -34 - (i - 1) * 16)
        r:SetJustifyH("RIGHT")
        list.lines[i] = { l = l, r = r }
    end

    local pos = PeonFishingDB.catchListPos
    list:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        list:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        list:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
    end
end

function ns.UpdateCatchList()
    local db = ns.GetDB()
    if not db then return end
    if db.mode ~= "fishing" or not db.showCatchList then
        if list then list:Hide() end
        return
    end
    if not list then CreateList() end
    local zone, sub = ns.CurrentPlace()
    local zt = DB().zones[zone]
    local pool = ActivePool()
    shownPool = pool
    local e = zt and zt[sub]
    list.title:SetText(sub)
    list.sub:SetText(sub ~= zone and zone or "")
    local rows = e and SortedItems(e) or {}
    local shown = 0
    for i, line in ipairs(list.lines) do
        local it = rows[i]
        if it then
            shown = i
            line.l:SetText(FishLabel(it.id, it.pool))
            line.r:SetText(("%d  |cffaaaaaa%.0f%%|r"):format(it.qty, it.count / e.n * 100))
            line.l:Show(); line.r:Show()
        else
            line.l:Hide(); line.r:Hide()
        end
    end
    local footer
    if not e or e.n == 0 then
        footer = L.CATCH_NONE
    else
        footer = L.CATCH_COUNT:format(e.n) .. (e.n < 50 and ("  |cffaaaaaa" .. L.CATCH_ROUGH .. "|r") or "")
    end
    -- Fusszeile in die naechste freie Zeile
    local fl = list.lines[math.min(shown + 1, MAX_LIST_LINES)]
    if shown < MAX_LIST_LINES then
        fl.l:SetText("|cffaaaaaa" .. footer .. "|r"); fl.r:SetText("")
        fl.l:Show(); fl.r:Show()
        shown = shown + 1
    end
    for _, line in ipairs(list.lines) do line.l:SetWidth(170) end
    if pool and shown + 1 < MAX_LIST_LINES then
        local pl, hl = list.lines[shown + 1], list.lines[shown + 2]
        pl.l:SetWidth(224); hl.l:SetWidth(224)
        pl.l:SetText("|cff66ccff" .. L.CATCH_POOL_ACTIVE:format(pool) .. "|r"); pl.r:SetText("")
        hl.l:SetText("|cff888888" .. L.CATCH_POOL_RELEASE .. "|r"); hl.r:SetText("")
        pl.l:Show(); pl.r:Show(); hl.l:Show(); hl.r:Show()
        shown = shown + 2
    end
    list:SetHeight(40 + shown * 16)
    list:Show()
end

---------------------------------------------------------------------------
-- Verteilung im Tooltip des Schwarms
---------------------------------------------------------------------------
local tooltipDone
function ns.AddPoolTooltip(name)
    if tooltipDone == name or not GameTooltip:IsShown() then return end
    local line1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    if IsSecret(line1) or line1 ~= name then return end
    tooltipDone = name
    local c = DB()
    local zone, sub = ns.CurrentPlace()
    local e = c.zones[zone] and c.zones[zone][sub]
    GameTooltip:AddLine(" ")
    if not e then
        GameTooltip:AddLine("Peon Fishing: " .. L.CATCH_NONE, 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine("Peon Fishing: " .. sub .. ", " .. L.CATCH_COUNT:format(e.n), 0.4, 0.8, 1)
        for i, it in ipairs(SortedItems(e)) do
            if i > 8 then break end
            GameTooltip:AddDoubleLine(FishLabel(it.id, it.pool), ("%.0f%%"):format(it.count / e.n * 100), 1, 1, 1, 0.8, 0.8, 0.8)
        end
    end
    GameTooltip:Show()
end
GameTooltip:HookScript("OnTooltipCleared", function() tooltipDone = nil end)
GameTooltip:HookScript("OnHide", function() tooltipDone = nil end)

---------------------------------------------------------------------------
-- Uebersichtsfenster mit Suche
---------------------------------------------------------------------------
local ov
local collapsed = {}
local ROW_H = 16

local function BuildRows(filter)
    local c = DB()
    local rows = {}
    filter = filter and filter:lower() or ""
    local function match(s) return filter == "" or (s and s:lower():find(filter, 1, true)) end

    local zones = {}
    for z in pairs(c.zones) do zones[#zones + 1] = z end
    table.sort(zones)
    for _, z in ipairs(zones) do
        local subs = {}
        for s in pairs(c.zones[z]) do subs[#subs + 1] = s end
        table.sort(subs)
        local zoneRows = {}
        for _, s in ipairs(subs) do
            local e = c.zones[z][s]
            local fishRows = {}
            local placeMatch = match(z) or match(s)
            for _, it in ipairs(SortedItems(e)) do
                local info = c.info[it.id] or {}
                if placeMatch or match(info.name) or (it.pool and match(L.CATCH_POOL_TAG)) then
                    fishRows[#fishRows + 1] = { kind = "fish", id = it.id, count = it.qty, pool = it.pool,
                        pct = it.count / e.n * 100 }
                end
            end
            if #fishRows > 0 then
                zoneRows[#zoneRows + 1] = { kind = "sub", text = s, n = e.n }
                for _, r in ipairs(fishRows) do zoneRows[#zoneRows + 1] = r end
            end
        end
        if #zoneRows > 0 then
            rows[#rows + 1] = { kind = "zone", text = z }
            if not collapsed[z] or filter ~= "" then
                for _, r in ipairs(zoneRows) do rows[#rows + 1] = r end
            end
        end
    end

    return rows
end

local function Render()
    if not ov or not ov:IsShown() then return end
    local rows = BuildRows(ov.search:GetText())
    for i, r in ipairs(rows) do
        local b = ov.rows[i]
        if not b then
            b = CreateFrame("Button", nil, ov.content)
            b:SetHeight(ROW_H)
            b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            b:SetPoint("RIGHT", ov.content, "RIGHT", 0, 0)
            b.l = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            b.l:SetPoint("LEFT", 0, 0)
            b.l:SetJustifyH("LEFT")
            b.r = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            b.r:SetPoint("RIGHT", -4, 0)
            b.r:SetJustifyH("RIGHT")
            b:SetScript("OnClick", function(self)
                if self.zone then
                    collapsed[self.zone] = not collapsed[self.zone]
                    Render()
                end
            end)
            ov.rows[i] = b
        end
        b.zone = nil
        if r.kind == "zone" then
            b.zone = r.text
            b.l:SetPoint("LEFT", 0, 0)
            b.l:SetText((collapsed[r.text] and "|cffffd100+ " or "|cffffd100- ") .. r.text .. "|r")
            b.r:SetText("")
        elseif r.kind == "sub" then
            b.l:SetPoint("LEFT", 12, 0)
            b.l:SetText(r.text)
            b.r:SetText("|cffaaaaaa" .. L.CATCH_COUNT:format(r.n) .. "|r")
        else
            b.l:SetPoint("LEFT", 24, 0)
            b.l:SetText(FishLabel(r.id, r.pool))
            b.r:SetText(("%d  |cffaaaaaa%.1f%%|r"):format(r.count, r.pct))
        end
        b:Show()
    end
    for i = #rows + 1, #ov.rows do ov.rows[i]:Hide() end
    ov.empty:SetShown(#rows == 0)
    ov.content:SetHeight(math.max(1, #rows * ROW_H))
end
ns.RefreshOverview = Render

local function CreateOverview()
    ov = CreateFrame("Frame", "PeonFishingOverview", UIParent, "BackdropTemplate")
    ov:SetSize(420, 480)
    ov:SetPoint("CENTER")
    ov:SetFrameStrata("DIALOG")
    ov:SetClampedToScreen(true)
    ov:SetMovable(true)
    ov:EnableMouse(true)
    ov:RegisterForDrag("LeftButton")
    ov:SetScript("OnDragStart", ov.StartMoving)
    ov:SetScript("OnDragStop", ov.StopMovingOrSizing)
    if ov.SetBackdrop then
        ov:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end
    local title = ov:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(L.OVERVIEW_TITLE)
    local close = CreateFrame("Button", nil, ov, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local label = ov:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 18, -44)
    label:SetText(L.OVERVIEW_SEARCH)
    ov.search = CreateFrame("EditBox", nil, ov, "InputBoxTemplate")
    ov.search:SetSize(200, 20)
    ov.search:SetPoint("LEFT", label, "RIGHT", 10, 0)
    ov.search:SetAutoFocus(false)
    ov.search:SetScript("OnTextChanged", function() Render() end)
    ov.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local scroll = CreateFrame("ScrollFrame", nil, ov, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -72)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    ov.content = CreateFrame("Frame", nil, scroll)
    ov.content:SetSize(360, 1)
    scroll:SetScrollChild(ov.content)
    ov.rows = {}
    ov.empty = ov:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    ov.empty:SetPoint("TOP", 0, -100)
    ov.empty:SetText(L.OVERVIEW_EMPTY)

    ov:SetScript("OnShow", Render)
    tinsert(UISpecialFrames, "PeonFishingOverview")   -- mit Escape schliessen
    ov:Hide()
end

function ns.ToggleOverview()
    if not ov then CreateOverview() end
    ov:SetShown(not ov:IsShown())
end

---------------------------------------------------------------------------
-- Datenbank zuruecksetzen (Optionen, mit Rueckfrage)
---------------------------------------------------------------------------
StaticPopupDialogs["PEON_FISHING_RESET_CATCHES"] = {
    text = L.POPUP_RESET_CATCHES,
    button1 = YES, button2 = NO,
    OnAccept = function()
        PeonFishingDB.catches = {}
        ns.Print(L.MSG_CATCHES_RESET)
        ns.UpdateCatchList()
        Render()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
for _, e in ipairs({ "LOOT_READY", "LOOT_CLOSED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "WORLD_CURSOR_TOOLTIP_UPDATE" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
    if event == "LOOT_READY" then
        if counted then return end
        local ok, fishing = pcall(IsFishingLoot)
        if ok and fishing then
            counted = true
            Record()
        end
    elseif event == "LOOT_CLOSED" then
        counted = false
    elseif event == "WORLD_CURSOR_TOOLTIP_UPDATE" then
        local t = WorldTip()
        if IsPoolName(t) then
            local changed = lastPool ~= t or not ActivePool()
            lastPool, lastPoolTime, lastPoolPos = t, GetTime(), PlayerPos()
            MarkPoolHere(t)
            ns.AddPoolTooltip(t)
            C_Timer.After(0, function() ns.AddPoolTooltip(t) end)
            if changed then
                ns.Dbg("Schwarm erkannt: " .. t)
                ns.UpdateCatchList()
            end
        end
    else
        ns.UpdateCatchList()
    end
end)

table.insert(ns.onModeChanged, function() ns.UpdateCatchList() end)

-- Schwarm-Zeile aktuell halten (Bewegung, Zeitfenster)
C_Timer.NewTicker(1, function()
    if list and list:IsShown() and (ActivePool()) ~= shownPool then ns.UpdateCatchList() end
end)
table.insert(ns.onLogin, function() ns.UpdateCatchList() end)
