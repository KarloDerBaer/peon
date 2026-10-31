-- Peon_Ledger - Overview.lua
-- Reiter "Uebersicht" (L2): alle Charaktere des Realms mit Gold und dem Stand je Ort.
-- "–" = Ort noch nicht erfasst (Bank: einmal die Bank oeffnen, Post: Postfach, Auktionen: Auktionshaus).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local O = {}
ns.Overview = O

local GREY = "|cff999999"

local function Count(v) if v == nil then return GREY .. "–|r" end return tostring(v) end

-- Taschen/Bank: belegte von allen Plaetzen (wie die Taschenanzeige im Spiel), sonst Stueck
local function SlotText(v, r, key)
    local s = r.slots[key]
    if s and s[2] then return ("%d/%d"):format(s[1], s[2]) end
    if s then return tostring(s[1]) end
    return Count(v)
end

local function SlotSort(r, key)
    local s = r.slots[key]
    if s then return s[1] end
    return r[key] or -1
end

-- Vermoegen (L6, Preise von Peon_Broker): Gold + Gold in der Post + Wert der Gegenstaende in Taschen, Bank,
-- Post und Auktionen. nil ohne Broker. Ab 0.7.3 zaehlt angelegte Ausruestung immer mit; Gebundenes (auch Angelegtes)
-- nur mit dem Haendlerpreis (ns.Worth). Die Option "Ausruestung mitzaehlen" entfaellt.
O.VALUE_PLACES = { "bags", "bank", "auctions", "transit", "equip" }   -- ab 0.7.2 ohne Post, mit "unterwegs" (Twink-Post)
function O.Worth(c, cache)
    if not ns.HasBroker() then return nil end
    local items, missing = 0, 0
    local places = O.VALUE_PLACES
    for _, place in ipairs(places) do
        local p = c.places[place]
        if type(p) == "table" and type(p.items) == "table" then
            for id, n in pairs(p.items) do
                local b = ns.Inventory.BoundIn(p, place, id, n)
                local k = id .. ":" .. n .. ":" .. b
                local v = cache[k]
                if v == nil then v = ns.Worth(id, n, b) or false; cache[k] = v end
                if v then items = items + v else missing = missing + 1 end
            end
        end
    end
    local gold = (c.money or 0) + (type(c.places.transit) == "table" and tonumber(c.places.transit.money) or 0)   -- Post nur Twink-Gold unterwegs (0.7.2)
    return gold + items, items, missing
end

function O.Rows()
    local I = ns.Inventory
    local rows, me = {}, ns.CharName()
    local cache = {}
    for name, c in pairs(I.RealmData().chars) do
        rows[#rows + 1] = {
            name = name, class = c.class, me = name == me, money = c.money,
            bags = I.PlaceCount(c, "bags"), bank = I.PlaceCount(c, "bank"), mail = I.PlaceCount(c, "mail"),
            auctions = I.PlaceCount(c, "auctions"), equip = I.PlaceCount(c, "equip"),
            seen = c.seen, mailMoney = type(c.places.mail) == "table" and c.places.mail.money or nil,
            level = c.level, faction = c.faction, slots = {},
        }
        rows[#rows].worth, rows[#rows].itemsValue, rows[#rows].missing = O.Worth(c, cache)
        for _, key in ipairs({ "bags", "bank", "mail", "auctions" }) do
            local used, all = I.PlaceSlots(c, key)
            if used then rows[#rows].slots[key] = { used, all } end
        end
    end
    return rows
end

-- Summen ueber alle Charaktere fuer die Bloecke (ab 0.8)
function O.Totals(rows)
    local t = { money = 0, chars = 0, worth = 0, items = 0, missing = 0, hasWorth = false,
                bagsFree = 0, bagsKnown = false, bankFree = 0, bankKnown = false, auctions = 0 }
    for _, r in ipairs(rows) do
        if type(r.money) == "number" then t.money = t.money + r.money; t.chars = t.chars + 1 end
        if r.worth then t.hasWorth = true; t.worth = t.worth + r.worth; t.items = t.items + (r.itemsValue or 0); t.missing = t.missing + (r.missing or 0) end
        local b, k = r.slots.bags, r.slots.bank
        if b and b[2] then t.bagsFree = t.bagsFree + (b[2] - b[1]); t.bagsKnown = true end
        if k and k[2] then t.bankFree = t.bankFree + (k[2] - k[1]); t.bankKnown = true end
        local a = r.slots.auctions
        if a then t.auctions = t.auctions + (a[1] or 0) end
    end
    return t
end

function O.Refresh()
    if not O.list then return end
    local rows = O.Rows()
    O.list:SetData(rows)
    local t = O.Totals(rows)
    local dash = GREY .. "–|r"
    -- Vermoegen
    local worth = { { L.OV_GOLD:format(t.chars), ns.Money(t.money) } }
    if ns.HasBroker() then
        worth[#worth + 1] = { L.OV_ITEMS, ns.Money(t.items) }
        worth[#worth + 1] = { "|cffffffff" .. L.OV_SUM .. "|r", "|cffffffff" .. ns.Money(t.worth) .. "|r" }
    else
        worth[#worth + 1] = { L.OV_ITEMS, dash }
        worth[#worth + 1] = { L.OV_SUM, dash }
    end
    if ns.Cost then worth[#worth + 1] = { L.OV_LAGERV, ns.Money(math.floor(ns.Cost.TotalValue() + 0.5)) } end
    if not ns.HasBroker() then worth[#worth + 1] = { GREY .. L.OV_NOBROKER .. "|r", "" }
    elseif t.missing > 0 then worth[#worth + 1] = { GREY .. L.OV_NOPRICE:format(t.missing) .. "|r", "" } end
    O.SetBlock("worth", worth)
    -- Gewinn heute / 7 / 30 Tage, alle Charaktere; dazu Handelsgewinn und Verbrauch (7 Tage)
    local profit, d7 = {}, nil
    for _, p in ipairs({ { "today", L.BK_TODAY }, { "d7", L.BK_D7 }, { "d30", L.BK_D30 } }) do
        local res = ns.Book.Collect(p[1], false)
        if p[1] == "d7" then d7 = res end
        profit[#profit + 1] = { p[2], O.Signed(res.profit) }
    end
    if d7 and ns.Cost then
        profit[#profit + 1] = { L.OV_TRADE7, O.Signed(math.floor((d7.trade or 0) + 0.5)) }
        profit[#profit + 1] = { L.OV_USE7, ns.Money(math.floor((d7.use or 0) + 0.5)) }
    end
    O.SetBlock("profit", profit)
    -- Plaetze
    O.SetBlock("slots", {
        { L.OV_BAGS_FREE, t.bagsKnown and tostring(t.bagsFree) or dash },
        { L.OV_BANK_FREE, t.bankKnown and tostring(t.bankFree) or dash },
        { L.OV_AUCTIONS, tostring(t.auctions) },
    })
end

function O.Signed(v)
    if not v or v == 0 then return GREY .. "0|r" end
    return (v > 0 and "|cff40c040+" or "|cffe05050-") .. "|r" .. ns.Money(math.abs(v))
end

-- Block mit Ueberschrift und Zeilen "Beschriftung ... Wert" (ab 0.8)
O.LINE_H = 17
O.MAX_LINES = 7
function O.NewBlock(parent, key, title, width)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(width, 24 + O.MAX_LINES * O.LINE_H)
    local h = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetText(title)
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -17)
    line:SetPoint("TOPRIGHT", 0, -17)
    b.title = h
    b.lines = {}
    for i = 1, O.MAX_LINES do
        local y = -22 - (i - 1) * O.LINE_H
        local l = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 2, y)
        l:SetJustifyH("LEFT")
        local v = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        v:SetPoint("TOPRIGHT", -2, y + 1)
        v:SetJustifyH("RIGHT")
        b.lines[i] = { label = l, value = v }
    end
    O.blocks[key] = b
    return b
end

function O.SetBlock(key, lines)
    local b = O.blocks and O.blocks[key]
    if not b then return end
    b.data = lines
    for i, fs in ipairs(b.lines) do
        local d = lines[i]
        fs.label:SetText(d and d[1] or "")
        fs.value:SetText(d and d[2] or "")
    end
end

-- Inhalt eines Blocks als Text (Tests, Fehlersuche)
function O.BlockText(key)
    local b = O.blocks and O.blocks[key]
    if not b or not b.data then return "" end
    local out = {}
    for _, d in ipairs(b.data) do out[#out + 1] = tostring(d[1]) .. " " .. tostring(d[2]) end
    return table.concat(out, "\n")
end

function O.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    local fixed = 90 + 90 + 56 + 56 + 64 + 52
    O.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_CHAR, width = total - fixed,
              format = function(v, r) return W.ClassColored(v, r.class) .. (r.me and (GREY .. " " .. L.OV_ME .. "|r") or "") end,
              sortValue = function(r) return W.Lower(r.name) end },
            { key = "money", title = L.COL_GOLD, width = 90, align = "RIGHT", format = function(v) return v and ns.Money(v, true) or (GREY .. "–|r") end },
            { key = "worth", title = L.COL_WORTH, width = 90, align = "RIGHT", format = function(v) return v and ns.Money(v, true) or (GREY .. "–|r") end,
              sortValue = function(r) return r.worth or -1 end },
            { key = "bags", title = L.PLACE_BAGS, width = 56, align = "RIGHT", format = function(v, r) return SlotText(v, r, "bags") end, sortValue = function(r) return SlotSort(r, "bags") end },
            { key = "bank", title = L.PLACE_BANK, width = 56, align = "RIGHT", format = function(v, r) return SlotText(v, r, "bank") end, sortValue = function(r) return SlotSort(r, "bank") end },
            { key = "auctions", title = L.PLACE_AUCTIONS, width = 64, align = "RIGHT", format = function(v, r) return SlotText(v, r, "auctions") end, sortValue = function(r) return SlotSort(r, "auctions") end },
            { key = "seen", title = L.COL_SEEN, width = 52, align = "RIGHT", format = function(v, r) return r.me and L.AGE_NOW or ns.Age(v) end,
              sortValue = function(r) return r.me and math.huge or (r.seen or 0) end },
        },
        rows = 5, rowHeight = 19, sortKey = "money", sortDesc = true,
        onEnter = function(list, r, row)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(W.ClassColored(r.name, r.class))
            if r.level then GameTooltip:AddLine(L.TT_LEVEL:format(r.level, r.faction or "?"), 0.8, 0.8, 0.8) end
            for _, key in ipairs({ "bags", "bank", "auctions", "equip", "transit" }) do   -- Post ab 0.7.1 nicht mehr angezeigt
                local n = r[key]
                if n then
                    local s = r.slots[key]
                    local right = L.TT_PIECES:format(n)
                    if s and s[2] then right = right .. "  ·  " .. L.TT_SLOTS:format(s[1], s[2], s[2] - s[1])
                    elseif s then right = right .. "  ·  " .. L.TT_SLOTS_ONLY:format(s[1]) end
                    GameTooltip:AddDoubleLine(L["PLACE_" .. key:upper()], right, 1, 1, 1, 0.8, 0.8, 0.8)
                end
            end
            if r.worth then
                GameTooltip:AddDoubleLine(L.TT_WORTH, ns.Money(r.worth), 1, 0.82, 0, 1, 1, 1)
                GameTooltip:AddDoubleLine(L.TT_WORTH_ITEMS, ns.Money(r.itemsValue or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
                if (r.missing or 0) > 0 then GameTooltip:AddLine(L.TT_WORTH_MISSING:format(r.missing), 0.6, 0.6, 0.6, true) end
            end
            local p7 = ns.Book.Collect("d7", true, nil, r.name).profit
            GameTooltip:AddDoubleLine(L.TT_PROFIT7, O.Signed(p7), 1, 0.82, 0, 1, 1, 1)
            GameTooltip:AddLine(L.TT_PLACES_HINT, 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.OV_EMPTY,
    })
    O.list.frame:SetPoint("TOPLEFT", 4, -4)
    -- drei Bloecke unter der Liste (ab 0.8)
    O.blocks = {}
    local gap = 28
    local bw = math.floor((total - 2 * gap) / 3)
    local y = -(4 + (O.list.height or 123) + 16)
    local defs = { { "worth", L.OV_B_WORTH }, { "profit", L.OV_B_PROFIT }, { "slots", L.OV_B_SLOTS } }
    for i, d in ipairs(defs) do
        local b = O.NewBlock(inset, d[1], d[2], bw)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * (bw + gap), y)
    end
    O.hint = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    O.hint:SetPoint("BOTTOMRIGHT", -10, 12)
    O.hint:SetText(GREY .. L.OV_HINT .. "|r")
end

W.pages.overview = { build = O.Build, refresh = O.Refresh }
