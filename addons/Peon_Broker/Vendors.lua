-- Peon_Broker - Vendors.lua
-- Umbau U11 (ab 0.52, Konzept Peon_Broker_Umbau.md, Abschnitt 8.4): alles, was Broker bei Haendlern sieht.
--   PeonBrokerDB.vendors[npcID] = { n = Name, z = Zone, x, y (0..100), t = zuletzt gesehen,
--     items = { [itemID] = { p = Gold je Stueck (Kupfer, nil = nur andere Waehrung), q = Stueck je Kauf,
--       c = { { n = Menge, name = Waehrung oder Gegenstand, id = itemID oder nil }, ... }, lim = vorraetig, req = "Voraussetzung" } } }
-- Merchant.lua (Kaufpreis fuer das Berufsfenster) bleibt und nutzt weiter PeonBrokerDB.merchant.
-- Gelesen wird beim Oeffnen des Haendlerfensters und bei Aenderungen, hoechstens alle 2 Sek.
-- Voraussetzungen (Ruf, Rang, Beruf, Stufe) stehen nur im Tooltip des Angebots: rote Zeilen werden als Text gemerkt.
-- Die Liste zeigt der Reiter "Haendler" im Broker-Fenster, der Manager liest sie aus Peon_Broker.lua.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local V = {}
ns.Vendors = V

V.MIN_GAP = 2   -- Sekunden zwischen zwei Lesungen

local GREY, GREEN = "|cff999999", "|cff60e060"
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Str(v) return type(v) == "string" and not Peon.IsSecret(v) and v ~= "" end
local function Money(v) return ns.Tooltip.Money(v) end

function V.Store()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.vendors) ~= "table" then acc.vendors = {} end
    return acc.vendors
end

-- NPC-Nummer aus der GUID ("Creature-0-1-2-3-NPCID-...")
function V.NpcID(guid)
    if not Str(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

local function Where()
    local CM = rawget(_G, "C_Map")
    if not CM or not CM.GetBestMapForUnit then return nil end
    local ok, map = pcall(CM.GetBestMapForUnit, "player")
    if not ok or not Num(map) then return nil end
    local zone
    local okI, info = pcall(CM.GetMapInfo, map)
    if okI and type(info) == "table" and Str(info.name) then zone = info.name end
    local x, y
    local okP, pos = pcall(CM.GetPlayerMapPosition, map, "player")
    if okP and pos and pos.GetXY then
        local okX, px, py = pcall(pos.GetXY, pos)
        if okX and Num(px) and Num(py) then x, y = math.floor(px * 1000 + 0.5) / 10, math.floor(py * 1000 + 0.5) / 10 end
    end
    return zone, x, y
end

-- Rote Zeilen im Tooltip des Angebots i (Voraussetzungen)
function V.Requirements(i)
    local TI = rawget(_G, "C_TooltipInfo")
    if not TI or not TI.GetMerchantItem then return nil end
    local ok, data = pcall(TI.GetMerchantItem, i)
    if not ok or type(data) ~= "table" or Peon.IsSecret(data) or type(data.lines) ~= "table" then return nil end
    local out = {}
    for k, line in ipairs(data.lines) do
        if k > 1 and type(line) == "table" and Str(line.leftText) then
            local c = line.leftColor
            local r, g, b
            if type(c) == "table" then
                if c.GetRGB then r, g, b = c:GetRGB() else r, g, b = c.r, c.g, c.b end
            end
            if Num(r) and Num(g) and Num(b) and r > 0.9 and g < 0.2 and b < 0.2 then out[#out + 1] = line.leftText end
        end
    end
    if #out == 0 then return nil end
    return table.concat(out, ", ")
end

-- Kosten in anderer Waehrung oder Gegenstaenden
function V.Costs(i)
    local n = rawget(_G, "GetMerchantItemCostInfo")
    local item = rawget(_G, "GetMerchantItemCostItem")
    if type(n) ~= "function" or type(item) ~= "function" then return nil end
    local ok, count = pcall(n, i)
    if not ok or not Num(count) or count < 1 then return nil end
    local out = {}
    for j = 1, count do
        local okc, _, value, link, currency = pcall(item, i, j)
        if okc and Num(value) then
            local name = Str(currency) and currency or (Str(link) and link:match("%[(.-)%]")) or nil
            local id = Str(link) and tonumber(link:match("item:(%d+)")) or nil
            out[#out + 1] = { n = value, name = name, id = id }
        end
    end
    return #out > 0 and out or nil
end

-- Ein Angebot lesen: itemID, Eintrag
function V.Offer(i)
    local id
    local fid = rawget(_G, "GetMerchantItemID")
    if type(fid) == "function" then
        local ok, x = pcall(fid, i)
        if ok and Num(x) then id = x end
    end
    if not id then
        local flink = rawget(_G, "GetMerchantItemLink")
        if type(flink) == "function" then
            local ok, link = pcall(flink, i)
            if ok and Str(link) then id = tonumber(link:match("item:(%d+)")) end
        end
    end
    if not id then return nil end
    local CM = rawget(_G, "C_MerchantFrame")
    local info
    if CM and CM.GetItemInfo then
        local ok, x = pcall(CM.GetItemInfo, i)
        if ok and type(x) == "table" then info = x end
    end
    if not info then return id, { } end
    local q = Num(info.stackCount) and info.stackCount > 0 and info.stackCount or 1
    local e = { q = q }
    if Num(info.price) and info.price > 0 then e.p = info.price / q end
    if Num(info.numAvailable) and info.numAvailable >= 0 then e.lim = info.numAvailable end
    if info.hasExtendedCost then e.c = V.Costs(i) end
    e.req = V.Requirements(i)
    return id, e
end

-- Alle Angebote des offenen Haendlers. Rueckgabe: Zahl der Angebote
function V.Scan(force)
    local now = GetTime and GetTime() or 0
    if not force and V.lastAt and now - V.lastAt < V.MIN_GAP then return 0 end
    V.lastAt = now
    local num = rawget(_G, "GetMerchantNumItems")
    if type(num) ~= "function" then return 0 end
    local ok, n = pcall(num)
    if not ok or not Num(n) or n < 1 then return 0 end
    local guid = UnitGUID and UnitGUID("npc")
    local npc = V.NpcID(guid)
    if not npc then return 0 end
    local name = UnitName and UnitName("npc")
    local zone, x, y = Where()
    local v = { n = Str(name) and name or nil, z = zone, x = x, y = y, t = time and time() or 0, items = {} }
    local got = 0
    for i = 1, n do
        local id, e = V.Offer(i)
        if id and e then v.items[id] = e; got = got + 1 end
    end
    if got > 0 then V.Store()[npc] = v end
    mod:Dbg(("Haendler %s: %d Angebote"):format(tostring(v.n), got))
    return got
end

-- Alle Haendler, die einen Gegenstand fuehren: { { npc, v, e }, ... }, guenstigster zuerst
function V.For(id)
    local out = {}
    for npc, v in pairs(V.Store()) do
        local e = type(v) == "table" and type(v.items) == "table" and v.items[id]
        if e then out[#out + 1] = { npc = npc, v = v, e = e } end
    end
    table.sort(out, function(a, b) return (a.e.p or math.huge) < (b.e.p or math.huge) end)
    return out
end

-- Preistext eines Angebots: Gold je Stueck oder andere Waehrung
function V.PriceText(e)
    if type(e) ~= "table" then return "?" end
    local parts = {}
    if e.p then parts[#parts + 1] = Money(e.p) end
    for _, c in ipairs(e.c or {}) do parts[#parts + 1] = c.n .. " " .. (c.name or "?") end
    if #parts == 0 then return GREY .. "?" .. "|r" end
    return table.concat(parts, " + ")
end

-- Tooltip-Baustein: "1s (Gretta, Eisenschmiede)"
function V.TooltipText(id)
    local list = V.For(id)
    local best = list[1]
    if not best then return nil end
    local where = best.v.n or "?"
    if best.v.z then where = where .. ", " .. best.v.z end
    return V.PriceText(best.e) .. " |cff999999(" .. where .. ")|r"
end

function V.Summary()
    local nv, ni = 0, 0
    local oldest
    for _, v in pairs(V.Store()) do
        nv = nv + 1
        for _ in pairs(type(v.items) == "table" and v.items or {}) do ni = ni + 1 end
        if v.t and (not oldest or v.t < oldest) then oldest = v.t end
    end
    if nv == 0 then return L.VEN_NONE end
    return L.VEN_SUMMARY:format(nv, ni, oldest and ns.Scan.Age(oldest) or "?")
end

---------------------------------------------------------------------------
-- Reiter "Haendler" im Broker-Fenster
---------------------------------------------------------------------------
V.search = ""
V.onlyProfit = false

-- Zeilen: je Haendler und Gegenstand. AH = guenstigstes Angebot im Heimatmarkt, profit = AH nach Anteil > Haendlerpreis
function V.Rows(search, onlyProfit)
    local rows = {}
    search = W.Lower(search or "")
    local D = ns.Data
    for npc, v in pairs(V.Store()) do
        for id, e in pairs(type(v.items) == "table" and v.items or {}) do
            local he = ns.WithHome(D.Lookup, id)
            local name = (type(he) == "table" and he.nm) or D.ItemName(id, he) or ("item " .. id)
            local ah = type(he) == "table" and not he.gone and he.m or nil
            local profit = ah and e.p and ah * (1 - D.Cut(ns.HomeMarketKey())) > e.p and true or false
            local hay = W.Lower(name .. " " .. (v.n or "") .. " " .. (v.z or ""))
            if (search == "" or hay:find(search, 1, true)) and (not onlyProfit or profit) then
                rows[#rows + 1] = { key = id, npc = npc, name = name, quality = type(he) == "table" and he.ql or nil,
                    price = e.p, priceText = V.PriceText(e), vendor = v.n or "?", zone = v.z or "", req = e.req,
                    ah = ah, profit = profit, lim = e.lim }
            end
        end
    end
    return rows
end

function V.Build(c)
    local total = W.WIDTH - 24
    local inset = W.Inset(c)
    inset:SetPoint("TOPLEFT", 0, 0)
    inset:SetPoint("BOTTOMRIGHT", 0, 0)
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(180, 20)
    box:SetAutoFocus(false)
    box:SetPoint("TOPLEFT", 70, -6)
    box:SetScript("OnTextChanged", function(self) V.search = self:GetText() or ""; V.Refresh() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local bl = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bl:SetPoint("RIGHT", box, "LEFT", -8, 0)
    bl:SetText(L.VEN_SEARCH)
    V.searchBox = box
    local cb = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("LEFT", box, "RIGHT", 16, 0)
    local cbl = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cbl:SetText(L.VEN_ONLY_PROFIT)
    cb:SetScript("OnClick", function(self) V.onlyProfit = self:GetChecked() and true or false; V.Refresh() end)
    V.profitCheck = cb
    local fixed = 110 + 120 + 100 + 90 + 80
    V.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = total - 16 - 24 - fixed, format = function(v, r) return W.Colored(v, r.quality) end },
            { key = "priceText", title = L.VEN_COL_PRICE, width = 110, align = "RIGHT", sortValue = function(r) return r.price or math.huge end },
            { key = "vendor", title = L.VEN_COL_VENDOR, width = 120 },
            { key = "zone", title = L.VEN_COL_ZONE, width = 100 },
            { key = "req", title = L.VEN_COL_REQ, width = 90, format = function(v) return v and ("|cffff6060" .. v .. "|r") or "" end },
            { key = "ah", title = L.VEN_COL_AH, width = 80, align = "RIGHT",
              format = function(v, r) if not v then return "–" end return (r.profit and GREEN or "") .. Money(v) .. (r.profit and " +|r" or "") end },
        },
        rows = 18, rowHeight = 18, sortKey = "name",
        onClick = function(_, r) if ns.Menu then ns.Menu.Info({ id = r.key, name = r.name }) end end,
        onEnter = function(_, r, row) W.ShowItemTooltip(row, r.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.VEN_EMPTY,
    })
    V.list.frame:SetPoint("TOPLEFT", 4, -32)
    V.count = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    V.count:SetPoint("BOTTOMLEFT", 10, 10)
    V.Refresh()
end

function V.Refresh()
    if not V.list then return end
    local rows = V.Rows(V.search, V.onlyProfit)
    V.list:SetData(rows)
    V.count:SetText(V.Summary())
end

W.pages.vendors = { build = V.Build, refresh = V.Refresh }

function V.Init()
    local function OnMerchant() mod:Call("Haendler", V.Scan) end
    pcall(mod.RegisterEvent, mod, "MERCHANT_SHOW", function() V.lastAt = nil; OnMerchant() end)
    pcall(mod.RegisterEvent, mod, "MERCHANT_UPDATE", OnMerchant)
end
