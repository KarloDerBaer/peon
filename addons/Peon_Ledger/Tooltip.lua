-- Peon_Ledger - Tooltip.lua
-- Ledger-Zeilen im Gegenstands-Tooltip (ab 0.7, Wunsch KarloDerBaer 03.10.2026):
--   ohne Umschalt:  Ledger  Kosten 2s (Ø 1s 50c)           (Kosten des naechsten Stuecks, Durchschnitt des Bestands)
--   mit Umschalt:   zusaetzlich "Bestand: 25 (Mirel 20, Borin 5)" und je Charakter die Orte ("Taschen 5, Bank 15")
--   Ohne Posten (keine Kosten bekannt) ohne Umschalt nur "Ledger (Umschalt)", wenn jemand den Gegenstand hat.
--   Ab 0.14: dahinter "zuletzt 2s 40c" (zuletzt gezahlt, nur wenn anders als die Kosten), mit Umschalt der letzte
--   Kauf und der letzte Verkauf mit Datum (Last.lua).
-- Nur der aktuelle Realm; zeigt nichts, wenn niemand den Gegenstand hat.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local T = {}
ns.Tooltip = T

local COLOR = { 0.55, 0.78, 1 }      -- dezent hellblau wie Brokers "Behalten"
local GREY = { 0.75, 0.75, 0.75 }

function T.ItemID(link)
    if type(link) ~= "string" or Peon.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Vorname (Charaktere haben in Forever Vor- und Nachnamen)
function T.Short(name) return (tostring(name):match("^(%S+)")) or tostring(name) end

-- Orte als Text: "Taschen 5, Bank 15"
function T.PlacesText(places)
    local parts = {}
    for _, place in ipairs(ns.Inventory.PLACES) do
        if places[place] then parts[#parts + 1] = L["PLACE_" .. place:upper()] .. " " .. places[place] end
    end
    return table.concat(parts, ", ")
end

function T.LastLines(tooltip, last, sale)
    if last then
        tooltip:AddDoubleLine("  " .. L.TT_LAST_BUY, L.TT_LAST_TEXT:format(ns.Money(math.floor(last.unit + 0.5)), last.n,
            ns.Stock.SourceText(last.src), date("%d.%m.", last.t)), GREY[1], GREY[2], GREY[3], COLOR[1], COLOR[2], COLOR[3])
    end
    if sale then
        tooltip:AddDoubleLine("  " .. L.TT_LAST_SALE, L.TT_LAST_TEXT:format(ns.Money(math.floor(sale.unit + 0.5)), sale.n,
            ns.Stock.SourceText(sale.src), date("%d.%m.", sale.t)), GREY[1], GREY[2], GREY[3], COLOR[1], COLOR[2], COLOR[3])
    end
end

function T.AddLines(tooltip, link)
    if not mod.db or not mod.db.tooltipShow then return false end
    local id = T.ItemID(link)
    if not id then return false end
    local c = ns.Inventory.Count(id)
    local cost = ns.Cost and ns.Cost.Text(id)
    local last = ns.Last and ns.Last.Buy(id)
    local sale = ns.Last and ns.Last.Sale(id)
    if last then
        local nx = ns.Cost and ns.Cost.Info(id)
        local lt = L.TT_LAST:format(ns.Money(math.floor(last.unit + 0.5)))
        if not nx or math.abs((nx.next or 0) - last.unit) >= 1 then cost = cost and (cost .. " · " .. lt) or lt end
    end
    if c.total <= 0 and not cost then return false end
    local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
    local title = ("|c%sLedger|r"):format(Peon.COLOR)
    if not shift and c.total > 0 then title = title .. " |cff777777" .. L.TT_SHIFT_HINT .. "|r" end
    tooltip:AddDoubleLine(title, cost or "", 1, 1, 1, COLOR[1], COLOR[2], COLOR[3])
    if not shift then return true end
    if c.total <= 0 then T.LastLines(tooltip, last, sale); return true end
    local parts = {}
    for i, ch in ipairs(c.chars) do
        if i > 3 then parts[#parts + 1] = "…"; break end
        parts[#parts + 1] = T.Short(ch.name) .. " " .. ch.total
    end
    if c.warband then parts[#parts + 1] = L.PLACE_WARBAND .. " " .. c.warband end
    tooltip:AddDoubleLine("  " .. L.TT_STOCK_LEFT, L.TT_STOCK:format(c.total, table.concat(parts, ", ")),
        GREY[1], GREY[2], GREY[3], COLOR[1], COLOR[2], COLOR[3])
    for _, ch in ipairs(c.chars) do
        local right = T.PlacesText(ch.places)
        local ct = ns.Cost and ns.Cost.Text(id, ch.name)   -- ab 0.9: Kosten je Charakter
        if ct then right = right .. " · " .. ct end
        tooltip:AddDoubleLine("    " .. ch.name, right, GREY[1], GREY[2], GREY[3], GREY[1], GREY[2], GREY[3])
    end
    T.LastLines(tooltip, last, sale)
    return true
end

function T.OnItem(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= rawget(_G, "ItemRefTooltip") then return end
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if link == nil or Peon.IsSecret(link) then return end
    if T.AddLines(tooltip, link) and tooltip.Show then tooltip:Show() end
end

function T.Init()
    if T.hooked then return end
    T.hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            mod:Call("Tooltip", T.OnItem, tooltip, data)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(self)
            mod:Call("Tooltip", T.OnItem, self)
        end)
    end
    -- Umschalt waehrend der Tooltip offen ist: neu aufbauen (macht Broker schon, wenn geladen)
    if Peon.GetModule and Peon.GetModule("broker") then return end
    mod:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key)
        if type(key) ~= "string" or not key:find("SHIFT") then return end
        local tt = GameTooltip
        if tt and tt.IsShown and tt:IsShown() and tt.GetItem and tt.RefreshData then
            local _, link = tt:GetItem()
            if link then tt:RefreshData() end
        end
    end)
end
