-- Peon_Ledger - History.lua
-- Reiter "Verlauf" (L3): alle Bewegungen von Gegenstaenden und Gold, neueste zuerst.
-- Suche (Gegenstand, Art, Charakter, Zusatz), Auswahl "nur dieser Charakter", Umbuchungen ein/aus.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local H = {}
ns.History = H

local GREY = "|cff999999"
local GREEN = "|cff40c040"
local RED = "|cffe05050"
H.COLOR = { ["in"] = GREEN, out = RED, move = GREY }
H.MAX_ROWS = 2000

local function Short(name) return ns.Tooltip and ns.Tooltip.Short and ns.Tooltip.Short(name) or name end

-- Zusammenfassen im Verlauf (ab 0.8 Herstellen, ab 0.8.1 weitere Vorgaenge): Eintraege, die zu einem Vorgang
-- gehoeren, werden eine Zeile. Nur Anzeige - gespeichert bleibt alles einzeln (Kosten, Buch unveraendert).
--   Feste Paare (ein Klick, mehrere Eintraege): Herstellen (Rezept), Auktion eingestellt + Einstellgebuehr (gleicher
--   Gegenstand), Handel (Partner), Quest, Post an/von Twink (Empfaenger).
--   Serien gleicher Art kurz hintereinander: Auktion zurueck/verkauft/gekauft ("Alle oeffnen"), Haendler,
--   Rueckkauf, Post (gleicher Absender), Korrekturen.
-- Bedingung: gleicher Charakter, gleiche Familie (siehe H.Family), hoechstens gap Sekunden zwischen zwei Eintraegen,
-- dazwischen kein anderer (angezeigter) Eintrag.
H.CRAFT_GAP = 30
H.GAP = 5
H.SERIES = { ahreturn = true, ahsold = true, ahbuy = true, vendor = true, buyback = true, mail = true, fix = true }

local function Info(id)
    local name, quality, icon = ns.Inventory.ItemInfo(id)
    return name or ("#" .. id), quality, icon
end

-- Familie eines Eintrags: Schluessel, Abstand (Sek.) oder nil (nie zusammenfassen)
function H.Family(e)
    local k = e.k
    if e.d then return nil end                                  -- Tagessummen (Beute, Benutzt) bleiben, wie sie sind
    if k == "craft" then return "craft|" .. tostring(e.x), H.CRAFT_GAP end
    if k == "posted" or (k == "ahfee" and e.x ~= L.MV_X_CANCEL) then return "post|" .. tostring(e.id), H.GAP end
    if k == "trade" or k == "twink" then return k .. "|" .. tostring(e.x), H.GAP end
    if k == "quest" then return "quest", H.GAP end
    if H.SERIES[k] then
        local side = ns.Moves.Side(e)
        if k == "vendor" or k == "buyback" then side = (e.n and e.n ~= 0) and (e.n > 0 and "in" or "out") or ((e.m or 0) > 0 and "out" or "in") end
        return k .. "|" .. side .. "|" .. (k == "mail" and tostring(e.x) or ""), H.GAP
    end
    return nil
end

-- Zeile aus einer Gruppe (nil = nur ein Eintrag)
function H.GroupRow(g)
    if #g.list == 1 then return nil end
    local ins, outs, po, mo = {}, {}, {}, {}
    local m = 0
    for _, e in ipairs(g.list) do
        if e.id and e.n and e.n ~= 0 then
            local t, o = e.n > 0 and ins or outs, e.n > 0 and po or mo
            if not t[e.id] then t[e.id] = 0; o[#o + 1] = e.id end
            t[e.id] = t[e.id] + e.n
        end
        m = m + (e.m or 0)
    end
    local craft = g.key:sub(1, 6) == "craft|"
    local post = g.key:sub(1, 5) == "post|"
    -- Hauptgegenstand: Zugang mit der groessten Menge, sonst Abgang, sonst der erste Eintrag mit Gegenstand
    local main, mainIn = nil, true
    for _, id in ipairs(po) do if not main or ins[id] > ins[main] then main = id end end
    if not main then
        mainIn = false
        for _, id in ipairs(mo) do if not main or outs[id] < outs[main] then main = id end end
    end
    -- Eintrag fuer Art und Farbe: Auktion eingestellt statt Gebuehr; sonst der des Hauptgegenstands
    local e0
    for _, e in ipairs(g.list) do
        if post and e.k == "posted" then e0 = e; break end
        if not post and main and e.id == main and e.n and e.n ~= 0 then e0 = e; break end
    end
    e0 = e0 or g.list[1]
    if not main and e0.id then main = e0.id end
    local name, quality, icon
    if main then name, quality, icon = Info(main) end
    -- Text hinter dem Hauptgegenstand: gleiche Richtung "+ ...", Gegenrichtung "aus ..." (Herstellen) bzw. "gegen ..."
    local same, other = {}, {}
    for _, id in ipairs(po) do if id ~= main then (mainIn and same or other)[#(mainIn and same or other) + 1] = ins[id] .. " " .. (Info(id)) end end
    for _, id in ipairs(mo) do if id ~= main then (mainIn and other or same)[#(mainIn and other or same) + 1] = math.abs(outs[id]) .. " " .. (Info(id)) end end
    local function Join(t)
        if #t <= 2 then return table.concat(t, ", ") end
        return t[1] .. ", " .. L.HIST_MORE:format(#t - 1)
    end
    local parts = {}
    if #same > 0 then parts[#parts + 1] = "+ " .. Join(same) end
    if #other > 0 then parts[#parts + 1] = (craft and L.HIST_CRAFT_MATS or L.HIST_AGAINST) .. " " .. (craft and table.concat(other, ", ") or Join(other)) end
    local n = main and (mainIn and ins[main] or outs[main]) or nil
    -- Auktion eingestellt: Menge mit Vorzeichen des Eintrags (Umbuchung)
    local allNames = {}
    for _, id in ipairs(po) do allNames[#allNames + 1] = (Info(id)) end
    for _, id in ipairs(mo) do allNames[#allNames + 1] = (Info(id)) end
    return { e = e0, t = g.list[1].t or 0, c = e0.c, side = ns.Moves.Side(e0), label = ns.Moves.Label(e0), id = main, name = name,
        quality = quality, icon = icon, n = n, m = m ~= 0 and m or nil, x = e0.x,
        grp = { key = g.key, craft = craft, list = g.list, prods = ins, mats = outs, po = po, mo = mo,
                matText = table.concat(parts, "  "), names = table.concat(allNames, " ") } }
end
H.CraftRow = H.GroupRow   -- Name bis 0.8.0

function H.Rows()
    local M = ns.Moves
    local filter = H.search and W.Lower(H.search) or ""
    local me = ns.CharName()
    local showMoves = mod.db.historyMoves ~= false
    local onlyMe = mod.db.historyOnlyMe == true
    local kind = mod.db.historyKind or "all"
    local rows = {}
    local list = M.List()
    local function Single(e, side)
        local name, quality, icon
        if e.id then name, quality, icon = ns.Inventory.ItemInfo(e.id); name = name or ("#" .. e.id) end
        return { e = e, t = e.t or 0, c = e.c, side = side, label = M.Label(e), id = e.id, name = name,
            quality = quality, icon = icon, n = e.n, m = e.m, x = e.x, cnt = e.cnt, d = e.d }
    end
    local function Push(r)
        local text = W.Lower((r.name or "") .. " " .. r.label .. " " .. tostring(r.c) .. " " .. tostring(r.x or "")
            .. " " .. (r.grp and r.grp.names or ""))
        if filter == "" or text:find(filter, 1, true) then rows[#rows + 1] = r end
    end
    local grp
    local function Close()
        if not grp then return end
        local g = grp
        grp = nil
        local r = H.GroupRow(g)
        if r then Push(r) else Push(Single(g.list[1], M.Side(g.list[1]))) end
    end
    for i = #list, 1, -1 do
        local e = list[i]
        local side = M.Side(e)
        if (showMoves or side ~= "move" or (kind ~= "all" and kind ~= "ah")) and (not onlyMe or e.c == me) and M.InGroup(e.k, kind) then
            local key, gap = H.Family(e)
            if key and grp and grp.key == key and grp.c == e.c and math.abs((grp.last or 0) - (e.t or 0)) <= gap then
                grp.list[#grp.list + 1] = e
                grp.last = e.t or 0
            else
                Close()
                if key then grp = { key = key, c = e.c, last = e.t or 0, list = { e } }
                else Push(Single(e, side)) end
            end
            if #rows >= H.MAX_ROWS then break end
        end
    end
    Close()
    return rows
end

function H.Refresh()
    if not H.list then return end
    if H.kind and H.kind.Update then H.kind.Update() end
    local rows = H.Rows()
    H.list:SetData(rows)
    H.count:SetText(GREY .. L.HIST_COUNT:format(#rows) .. "|r")
end

local function ItemText(v, r)
    if not r.id then return r.x and (GREY .. r.x .. "|r") or "" end
    local n = r.n or r.e.q or 0
    local txt = "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(r.name, r.quality)
    if math.abs(n) > 1 then txt = txt .. " ×" .. math.abs(n) end
    if r.grp and r.grp.matText ~= "" then txt = txt .. GREY .. "  " .. r.grp.matText .. "|r" end
    return txt
end

local function MoneyText(v, r)
    if not r.m or r.m == 0 then return "" end
    return (r.m > 0 and GREEN .. "+" or RED .. "-") .. "|r" .. ns.Money(math.abs(r.m))
end

function H.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    H.list = Peon.NewList(inset, {
        columns = {
            { key = "t", title = L.COL_TIME, width = 80,
              format = function(v, r) return r.d and (date("%d.%m.", v) .. GREY .. " " .. L.HIST_DAY .. "|r") or date("%d.%m. %H:%M", v) end },
            { key = "c", title = L.COL_CHAR, width = 70, format = function(v) return Short(v) end },
            { key = "label", title = L.COL_KIND, width = 130,
              format = function(v, r) return (H.COLOR[r.side] or "") .. v .. "|r" end },
            { key = "name", title = L.COL_ITEM, width = total - 80 - 70 - 130 - 100, format = ItemText,
              sortValue = function(r) return W.Lower(r.name or r.x or "") end },
            { key = "m", title = L.COL_GOLD, width = 100, align = "RIGHT", format = MoneyText,
              sortValue = function(r) return r.m or 0 end },
        },
        rows = 15, rowHeight = 19, sortKey = "t", sortDesc = true,
        onClick = function(list, r, button) if button == "LeftButton" and r.id then mod:ShowItem(r.id) end end,   -- ab 0.9
        onEnter = function(list, r, row)
            if not GameTooltip then return end
            if r.id then W.ShowItemTooltip(row, r.id) else GameTooltip:SetOwner(row, "ANCHOR_RIGHT") end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine((H.COLOR[r.side] or "") .. r.label .. "|r · " .. tostring(r.c))
            if r.x then GameTooltip:AddLine(r.x, 0.8, 0.8, 0.8) end
            if r.grp then H.CraftTooltip(r) GameTooltip:Show() return end
            -- Zuordnen (ab 0.7): Wareneinsatz und Gewinn, Verbrauch, Kosten je Stueck
            local z = ns.Cost and ns.Cost.Result(r.e)
            if z and z.sale then
                GameTooltip:AddLine(L.HIST_TT_SALE:format(ns.Money(math.floor((z.cost or 0) + 0.5)), ns.Money(math.floor((z.fee or 0) + 0.5)),
                    ((z.profit or 0) >= 0 and "|cff40c040+" or "|cffe05050-") .. "|r" .. ns.Money(math.floor(math.abs(z.profit or 0) + 0.5))), 1, 0.82, 0)
                if (z.miss or 0) > 0 then GameTooltip:AddLine(L.HIST_TT_MISS:format(z.miss), 0.6, 0.6, 0.6, true) end
            elseif z and z.use and not z.traded then
                GameTooltip:AddLine(L.HIST_TT_USE:format(ns.Money(math.floor(z.use + 0.5))), 0.8, 0.8, 0.8)
            elseif z and z.unit then
                GameTooltip:AddLine(L.HIST_TT_UNIT:format(ns.Money(math.floor(z.unit + 0.5))), 0.8, 0.8, 0.8)
            end
            if r.d then GameTooltip:AddLine(L.HIST_DAILY:format(r.cnt or 1), 0.6, 0.6, 0.6, true) end
            if r.side == "move" then GameTooltip:AddLine(L.HIST_MOVE_HINT, 0.6, 0.6, 0.6, true) end
            GameTooltip:Show()
        end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.HIST_EMPTY,
    })
    H.list.frame:SetPoint("TOPLEFT", 4, -34)
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(180, 20)
    box:SetPoint("TOPLEFT", 14, -8)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) H.search = self:GetText(); mod:Call("Verlauf", H.Refresh) end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    H.searchBox = box
    H.onlyMe = H.Check(inset, L.HIST_ONLY_ME, "historyOnlyMe", false)
    H.onlyMe:SetPoint("LEFT", box, "RIGHT", 12, 0)
    H.moves = H.Check(inset, L.HIST_MOVES, "historyMoves", true)
    H.moves:SetPoint("LEFT", H.onlyMe.label, "RIGHT", 12, 0)
    -- Filter nach Art (ab 0.6)
    local items = {}
    for _, g in ipairs(ns.Moves.GROUPS) do items[#items + 1] = { g.key, L["HIST_KIND_" .. g.key:upper()] or g.key } end
    H.kind = W.Dropdown(inset, 150, items, function() return mod.db.historyKind or "all" end,
        function(v) mod.db.historyKind = v; mod:Call("Verlauf", H.Refresh) end)
    H.kind:SetPoint("TOPRIGHT", -10, -7)
    H.count = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    H.count:SetPoint("BOTTOMLEFT", 10, 12)
    H.hint = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    H.hint:SetPoint("BOTTOMRIGHT", -10, 12)
    H.hint:SetText(GREY .. L.HIST_HINT .. "|r")
end

-- Tooltip einer zusammengefassten Zeile: Herstellen mit Ergebnis/Material/Kosten je Stueck,
-- sonst jeder Eintrag einzeln (Art, Gegenstand, Gold) und Summe aus Wareneinsatz/Gebuehren/Gewinn
H.TT_MAX = 15
local function Signed(v)
    return ((v or 0) >= 0 and "|cff40c040+" or "|cffe05050-") .. "|r" .. ns.Money(math.floor(math.abs(v or 0) + 0.5))
end

function H.CraftTooltip(r)
    local g = r.grp
    if g.craft then
        for _, id in ipairs(g.po) do
            GameTooltip:AddLine(GREEN .. L.HIST_TT_CRAFT:format((Info(id)) .. " ×" .. g.prods[id]) .. "|r")
        end
        if #g.mo > 0 then
            GameTooltip:AddLine(L.HIST_TT_MATS, 1, 0.82, 0)
            for _, id in ipairs(g.mo) do GameTooltip:AddLine(RED .. "  " .. g.mats[id] .. "|r " .. (Info(id)), 0.9, 0.9, 0.9) end
        end
        if ns.Cost then
            local sum, n = 0, 0
            for _, e in ipairs(g.list) do
                local z = (e.n or 0) > 0 and e.id == r.id and ns.Cost.Result(e)
                if z and z.unit then sum = sum + z.unit * e.n; n = n + e.n end
            end
            if n > 0 then GameTooltip:AddLine(L.HIST_TT_UNIT:format(ns.Money(math.floor(sum / n + 0.5))), 0.8, 0.8, 0.8) end
        end
        GameTooltip:AddLine(L.HIST_TT_CRAFTN:format(#g.list), 0.6, 0.6, 0.6, true)
        return
    end
    local cost, fee, profit, sale = 0, 0, 0, false
    for i, e in ipairs(g.list) do
        if i <= H.TT_MAX then
            local side = ns.Moves.Side(e)
            local left = (H.COLOR[side] or "") .. ns.Moves.Label(e) .. "|r"
            if e.id then
                local n = e.n or e.q
                left = left .. "  " .. ((n and n ~= 0) and (math.abs(n) .. " ") or "") .. (Info(e.id))
            end
            GameTooltip:AddDoubleLine(left, (e.m and e.m ~= 0) and Signed(e.m) or "", 0.9, 0.9, 0.9, 1, 1, 1)
        end
        local z = ns.Cost and ns.Cost.Result(e)
        if z and z.sale then sale = true; cost = cost + (z.cost or 0); fee = fee + (z.fee or 0); profit = profit + (z.profit or 0) end
    end
    if #g.list > H.TT_MAX then GameTooltip:AddLine(L.HIST_TT_MORE:format(#g.list - H.TT_MAX), 0.6, 0.6, 0.6) end
    if r.m and r.m ~= 0 then GameTooltip:AddDoubleLine(L.HIST_TT_SUM, Signed(r.m), 1, 0.82, 0, 1, 1, 1) end
    if sale then GameTooltip:AddLine(L.HIST_TT_SALE:format(ns.Money(math.floor(cost + 0.5)), ns.Money(math.floor(fee + 0.5)), Signed(profit)), 1, 0.82, 0) end
    GameTooltip:AddLine(L.HIST_TT_GROUPN:format(#g.list), 0.6, 0.6, 0.6, true)
end

-- kleines Haekchen mit Text, Wert in mod.db[key] (Standard def)
function H.Check(parent, text, key, def)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(22, 22)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", b, "RIGHT", 2, 0)
    label:SetText(text)
    b.label = label
    local v = mod.db[key]
    if v == nil then v = def end
    b:SetChecked(v and true or false)
    b:SetScript("OnClick", function(self)
        mod.db[key] = self:GetChecked() and true or false
        mod:Call("Verlauf", H.Refresh)
    end)
    return b
end

W.pages.history = { build = H.Build, refresh = H.Refresh }
