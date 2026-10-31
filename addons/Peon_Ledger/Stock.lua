-- Peon_Ledger - Stock.lua
-- Reiter "Bestand" (L2): alle Gegenstaende aller Charaktere des Realms, Suche nach Namensteil.
-- Spalten: Gegenstand, Gesamt, Wo (Charakter und Orte). Maus ueber eine Zeile zeigt den Gegenstand im Tooltip.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local S = {}
ns.Stock = S

local GREY = "|cff999999"

-- "Mirel: Taschen 5, Bank 15 · Borin: Post 3"
function S.WhereText(e)
    local parts, me = {}, ns.CharName()
    local names = {}
    for name in pairs(e.where) do names[#names + 1] = name end
    table.sort(names, function(a, b) if (a == me) ~= (b == me) then return a == me end return a < b end)
    for _, name in ipairs(names) do
        parts[#parts + 1] = ns.Tooltip.Short(name) .. ": " .. ns.Tooltip.PlacesText(e.where[name])
    end
    if e.warband then parts[#parts + 1] = L.PLACE_WARBAND .. " " .. e.warband end
    return table.concat(parts, " · ")
end

function S.Rows()
    local filter = S.search and W.Lower(S.search) or ""
    local rows = {}
    for id, e in pairs(ns.Inventory.AllItems()) do
        local name, quality, icon = ns.Inventory.ItemInfo(id)
        name = name or ("#" .. id)
        if filter == "" or W.Lower(name):find(filter, 1, true) then
            rows[#rows + 1] = { id = id, name = name, quality = quality, icon = icon, total = e.total, where = S.WhereText(e),
                value = ns.Worth(id, e.total, e.bound),   -- Wert (ab 0.6, Brokers Zeile 1; ab 0.7.3 Gebundenes Haendlerpreis)
                lager = (ns.Cost and ns.Cost.Info(id, "*")) and ns.Cost.Info(id, "*").value or nil }   -- Lagerwert = Kosten (ab 0.7)
        end
    end
    return rows
end

function S.Refresh()
    if not S.list then return end
    local rows = S.Rows()
    S.list:SetData(rows)
    local sum, lager = 0, 0
    for _, r in ipairs(rows) do sum = sum + (r.value or 0); lager = lager + (r.lager or 0) end
    S.count:SetText(GREY .. L.STOCK_COUNT:format(#rows) .. (ns.HasBroker() and ("  ·  " .. L.STOCK_VALUE:format(ns.Money(sum))) or "")
        .. "  ·  " .. L.STOCK_LAGER:format(ns.Money(math.floor(lager + 0.5))) .. "|r")
end

function S.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    S.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = 220,
              format = function(v, r) return "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(v, r.quality) end,
              sortValue = function(r) return W.Lower(r.name) end },
            { key = "total", title = L.COL_TOTAL, width = 60, align = "RIGHT" },
            { key = "value", title = L.COL_VALUE, width = 80, align = "RIGHT",
              format = function(v) return v and ns.Money(v) or (GREY .. "–|r") end, sortValue = function(r) return r.value or -1 end },
            { key = "lager", title = L.COL_LAGER, width = 80, align = "RIGHT",
              format = function(v) return v and ns.Money(math.floor(v + 0.5)) or (GREY .. "–|r") end, sortValue = function(r) return r.lager or -1 end },
            { key = "where", title = L.COL_WHERE, width = total - 440, sortValue = function(r) return W.Lower(r.where) end },
        },
        rows = 16, rowHeight = 19, sortKey = "name",
        onEnter = function(list, r, row) W.ShowItemTooltip(row, r.id) end,
        onClick = function(list, r, button) if button == "LeftButton" and r.id then mod:ShowItem(r.id) end end,   -- ab 0.9
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.STOCK_EMPTY,
    })
    S.list.frame:SetPoint("TOPLEFT", 4, -34)
    local box = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    box:SetSize(200, 20)
    box:SetPoint("TOPLEFT", 14, -8)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) S.search = self:GetText(); mod:Call("Bestand", S.Refresh) end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    S.searchBox = box
    local label = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetText(GREY .. L.STOCK_SEARCH .. "|r")
    S.count = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    S.count:SetPoint("BOTTOMLEFT", 10, 12)
end

W.pages.stock = { build = S.Build, refresh = S.Refresh }
