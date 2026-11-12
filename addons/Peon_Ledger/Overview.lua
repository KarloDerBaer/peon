-- Peon_Ledger - Overview.lua
-- Reiter "Uebersicht": "Wie stehe ich da?" (ab 0.14 mit Peon.UI, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6.1)
--   oben vier Kacheln: Gold gesamt (Aenderung heute), Vermoegen, Handelsgewinn heute, Post wartet
--   darunter alle Charaktere des Realms: Name, Stufe, Gold, Lagerwert, Post, zuletzt gesehen
-- Vermoegen = Gold + Wert der Gegenstaende (Preise von Peon_Broker), Gebundenes zum Haendlerpreis (ns.Worth).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local O = {}
ns.Overview = O

local GREY = W.GREY

-- Vermoegen eines Charakters: Gold (+ Gold an Twinks unterwegs) + Wert der Gegenstaende. nil ohne Broker.
O.VALUE_PLACES = { "bags", "bank", "auctions", "transit", "equip" }
function O.Worth(c, cache)
    if not ns.HasBroker() then return nil end
    local items, missing = 0, 0
    for _, place in ipairs(O.VALUE_PLACES) do
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
    local gold = (c.money or 0) + (type(c.places.transit) == "table" and tonumber(c.places.transit.money) or 0)
    return gold + items, items, missing
end

function O.Rows()
    local I = ns.Inventory
    local rows, me = {}, ns.CharName()
    local cache = {}
    for name, c in pairs(I.RealmData().chars) do
        local r = {
            name = name, class = c.class, me = name == me, money = c.money, level = c.level, faction = c.faction,
            bags = I.PlaceCount(c, "bags"), bank = I.PlaceCount(c, "bank"), auctions = I.PlaceCount(c, "auctions"),
            equip = I.PlaceCount(c, "equip"), transit = I.PlaceCount(c, "transit"),
            seen = c.seen, slots = {}, mail = I.MailInfo(c),
            lager = ns.Cost and ns.Cost.TotalValue(name) or nil,
        }
        r.worth, r.itemsValue, r.missing = O.Worth(c, cache)
        r.mailSort = r.mail and (r.mail.letters * 1e9 + r.mail.money) or -1
        for _, key in ipairs({ "bags", "bank", "auctions" }) do
            local used, all = I.PlaceSlots(c, key)
            if used then r.slots[key] = { used, all } end
        end
        rows[#rows + 1] = r
    end
    return rows
end

function O.Totals(rows)
    local t = { money = 0, chars = 0, worth = 0, items = 0, missing = 0, hasWorth = false,
                letters = 0, mailMoney = 0, nextExp = nil, mailKnown = false }
    for _, r in ipairs(rows) do
        if type(r.money) == "number" then t.money = t.money + r.money; t.chars = t.chars + 1 end
        if r.worth then t.hasWorth = true; t.worth = t.worth + r.worth; t.items = t.items + (r.itemsValue or 0); t.missing = t.missing + (r.missing or 0) end
        if r.mail then
            t.mailKnown = true
            t.letters = t.letters + (r.mail.letters or 0)
            t.mailMoney = t.mailMoney + (r.mail.money or 0)
            if r.mail.next and (not t.nextExp or r.mail.next < t.nextExp) then t.nextExp = r.mail.next end
        end
    end
    return t
end

-- Ablauf als Text: "2 T.", gelb unter 3 Tagen, rot unter 1 Tag
function O.ExpText(t)
    if not t then return "" end
    local d = (t - time()) / 86400
    local txt = d >= 1 and L.AGE_DAYS:format(math.floor(d)) or L.AGE_HOURS:format(math.max(0, math.floor(d * 24)))
    if d < 1 then return W.RED .. txt .. "|r" end
    if d < 3 then return W.YELLOW .. txt .. "|r" end
    return txt
end

local function MailText(v, r)
    local m = r.mail
    if not m then return GREY .. "–|r" end
    if (m.letters or 0) == 0 then return GREY .. "0|r" end
    local txt = tostring(m.letters)
    if (m.money or 0) > 0 then txt = txt .. " · " .. ns.Money(m.money, true) end
    if m.next then txt = txt .. " · " .. O.ExpText(m.next) end
    return txt
end

-- Kachel: Ueberschrift, grosser Wert, kleiner Zusatz
local function Tile(parent, x, y, w, h, title)
    local U = Peon.UI
    local p = U.Panel(parent, "left")
    p:SetPoint("TOPLEFT", x, y)
    p:SetSize(w, h)
    p.title = p:CreateFontString(nil, "ARTWORK", U.FONT.nav)
    p.title:SetPoint("TOPLEFT", 12, -9)
    p.title:SetText(title)
    p.big = p:CreateFontString(nil, "ARTWORK", U.FONT.big)
    p.big:SetPoint("TOPLEFT", 12, -26)
    p.big:SetJustifyH("LEFT")
    p.sub = p:CreateFontString(nil, "ARTWORK", U.FONT.small)
    p.sub:SetPoint("TOPLEFT", 12, -48)
    p.sub:SetJustifyH("LEFT")
    function p:Set(big, sub) self.big:SetText(big or ""); self.sub:SetText(sub or "") end
    return p
end

function O.Refresh()
    if not O.table then return end
    local rows = O.Rows()
    O.table:SetData(rows)
    local t = O.Totals(rows)
    O.totals = t
    local today = ns.Book.Collect("today", false)
    O.tiles.gold:Set(ns.Money(t.money, true), L.OV_TODAY:format(W.Signed(today.profit)) .. "  ·  " .. L.OV_CHARS:format(t.chars))
    if ns.HasBroker() then
        local sub = L.OV_ITEMS_VALUE:format(ns.Money(t.items, true))
        if t.missing > 0 then sub = sub .. GREY .. "  ·  " .. L.OV_NOPRICE:format(t.missing) .. "|r" end
        O.tiles.worth:Set(ns.Money(t.worth, true), sub)
    else
        O.tiles.worth:Set(GREY .. "–|r", GREY .. L.OV_NOBROKER .. "|r")
    end
    local lager = ns.Cost and ns.Cost.TotalValue() or 0
    O.tiles.trade:Set(W.Signed(today.trade or 0), L.OV_TRADE_SUB:format(today.nsales or 0, ns.Money(math.floor(lager + 0.5), true)))
    if t.mailKnown then
        local sub = (t.mailMoney > 0) and L.OV_MAIL_GOLD:format(ns.Money(t.mailMoney, true)) or ""
        if t.nextExp then sub = sub .. (sub ~= "" and "  ·  " or "") .. L.OV_MAIL_NEXT:format(O.ExpText(t.nextExp)) end
        O.tiles.mail:Set(L.OV_MAIL_LETTERS:format(t.letters), sub)
    else
        O.tiles.mail:Set(GREY .. "–|r", GREY .. L.OV_MAIL_UNKNOWN .. "|r")
    end
end

-- Text fuer die Statuszeile
function O.Status()
    local t = O.totals
    return t and L.OV_STATUS:format(ns.Realm(), t.chars) or nil
end

-- Kachelinhalt als Text (Tests, Fehlersuche)
function O.TileText(key)
    local p = O.tiles and O.tiles[key]
    if not p then return "" end
    return tostring(p.big.text or "") .. " | " .. tostring(p.sub.text or "")
end

function O.RowTooltip(row, r)
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(W.ClassColored(r.name, r.class))
    if r.level then GameTooltip:AddLine(L.TT_LEVEL:format(r.level, r.faction or "?"), 0.8, 0.8, 0.8) end
    for _, key in ipairs({ "bags", "bank", "auctions", "equip", "transit" }) do
        local n = r[key]
        if n then
            local s = r.slots[key]
            local right = L.TT_PIECES:format(n)
            if s and s[2] then right = right .. "  ·  " .. L.TT_SLOTS:format(s[1], s[2], s[2] - s[1])
            elseif s then right = right .. "  ·  " .. L.TT_SLOTS_ONLY:format(s[1]) end
            GameTooltip:AddDoubleLine(L["PLACE_" .. key:upper()], right, 1, 1, 1, 0.8, 0.8, 0.8)
        end
    end
    if r.mail then
        GameTooltip:AddDoubleLine(L.PLACE_MAIL, L.TT_MAIL:format(r.mail.letters or 0, ns.Money(r.mail.money or 0), r.mail.ah or 0), 1, 1, 1, 0.8, 0.8, 0.8)
    end
    if r.worth then
        GameTooltip:AddDoubleLine(L.TT_WORTH, ns.Money(r.worth), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.TT_WORTH_ITEMS, ns.Money(r.itemsValue or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        if (r.missing or 0) > 0 then GameTooltip:AddLine(L.TT_WORTH_MISSING:format(r.missing), 0.6, 0.6, 0.6, true) end
    end
    local p7 = ns.Book.Collect("d7", true, nil, r.name)
    GameTooltip:AddDoubleLine(L.TT_TRADE7, W.Signed(p7.trade or 0), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TT_PROFIT7, W.Signed(p7.profit), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

function O.Build(c)
    local U = Peon.UI
    local a = W.Area()
    O.tiles = {}
    local gap = 4
    local tw = math.floor((a.width - 3 * gap) / 4)
    local th = 64
    local defs = { { "gold", L.OV_T_GOLD }, { "worth", L.OV_T_WORTH }, { "trade", L.OV_T_TRADE }, { "mail", L.OV_T_MAIL } }
    for i, d in ipairs(defs) do
        O.tiles[d[1]] = Tile(c, a.left + (i - 1) * (tw + gap), -a.top, tw, th, d[2])
    end
    local panel = U.Panel(c, "list", true)
    panel:SetPoint("TOPLEFT", a.left, -(a.top + th + 6))
    panel:SetPoint("BOTTOMRIGHT", -a.right, a.bottom)
    O.panel = panel
    O.table = U.Table(panel, {
        columns = {
            { key = "name", title = L.COL_CHAR,
              format = function(v, r) return W.ClassColored(v, r.class) .. (r.me and (GREY .. " " .. L.OV_ME .. "|r") or "") end,
              sort = function(r) return W.Lower(r.name) end },
            { key = "level", title = L.COL_LEVEL, width = 60, align = "RIGHT" },
            { key = "money", title = L.COL_GOLD, width = 130, align = "RIGHT", format = function(v) return v and ns.Money(v, true) or (GREY .. "–|r") end },
            { key = "lager", title = L.COL_LAGER, width = 130, align = "RIGHT", format = function(v) return v and v > 0 and ns.Money(math.floor(v + 0.5), true) or (GREY .. "–|r") end },
            { key = "mailSort", title = L.COL_MAIL, width = 170, align = "RIGHT", format = MailText },
            { key = "seen", title = L.COL_SEEN, width = 80, align = "RIGHT", format = function(v, r) return r.me and L.AGE_NOW or ns.Age(v) end,
              sort = function(r) return r.me and math.huge or (r.seen or 0) end },
        },
        sortKey = "money", sortDesc = true,
        empty = L.OV_EMPTY,
        onEnter = function(row, r) O.RowTooltip(row, r) end,
    })
end

W.pages.overview = { build = O.Build, refresh = O.Refresh, status = O.Status }
