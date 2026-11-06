-- Peon - List.lua
-- Liste mit Spalten, Sortierung per Klick auf den Spaltenkopf und Bildlauf (ab API 7).
--
--   local list = Peon.NewList(parent, {
--       columns = {
--           { key = "name",  title = "Name",  width = 160 },
--           { key = "price", title = "Preis", width = 90, align = "RIGHT",
--             format = function(value, item) return Money(value) end,   -- Anzeige (optional)
--             sortValue = function(item) return item.price end },       -- Sortierwert (optional)
--       },
--       rows      = 10,             -- sichtbare Zeilen
--       rowHeight = 18,
--       sortKey   = "name", sortDesc = false,   -- Startsortierung; nil = unsortiert
--       selectable = true,          -- Klick markiert die Zeile
--       onClick   = function(list, item, button) end,
--       onEnter   = function(list, item, row) end,   -- z. B. Tooltip
--       onLeave   = function(list, item, row) end,
--       emptyText = "Keine Einträge",
--       rowColor  = function(item) return r, g, b, a end,   -- ab API 8: Hintergrundfarbe je Zeile (nil = keine)
--   })
--   list.frame:SetPoint("TOPLEFT", 10, -40)
--   list:SetData(items)          -- Liste von Tabellen; wird nicht kopiert
--   list:Refresh()               -- nach Aenderungen an den Eintraegen
--   list:Sort(key, desc), list:Select(item), list:GetSelected(), list:Scroll(zeilen)
--   list:GetWidth(), list:GetHeight()
--   list:UpdateColors()          -- ab API 8: nur die Zeilenfarben neu (z. B. zum Pulsieren, jedes Bild)
--
-- Auf Optionsseiten: page:Add(col, page:List(opts)); der Container hat .list.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local List = {}
List.__index = List
Peon.ListPrototype = List

local HEADER_H = 20
local SCROLL_W = 16
local PAD = 4

local function Compare(a, b)
    local ta, tb = type(a), type(b)
    if a == nil then return false end        -- leere Werte ans Ende
    if b == nil then return true end
    if ta == "number" and tb == "number" then return a < b end
    if ta == "boolean" then a = a and 1 or 0; ta = "number" end
    if tb == "boolean" then b = b and 1 or 0; tb = "number" end
    if ta == "number" and tb == "number" then return a < b end
    return tostring(a):lower() < tostring(b):lower()
end

function Peon.NewList(parent, o)
    o = o or {}
    local list = setmetatable({ o = o, columns = o.columns or {}, data = {}, view = {}, offset = 0 }, List)
    list.rowsVisible = o.rows or 10
    list.rowHeight = o.rowHeight or 18
    list.sortKey, list.sortDesc = o.sortKey, o.sortDesc and true or false

    local width = PAD * 2 + SCROLL_W
    for _, col in ipairs(list.columns) do width = width + (col.width or 100) end
    list.width = width
    list.height = HEADER_H + list.rowsVisible * list.rowHeight + PAD * 2

    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(list.width, list.height)
    list.frame = f

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)

    -- Spaltenkoepfe
    list.headers = {}
    local x = PAD
    for i, col in ipairs(list.columns) do
        local h = CreateFrame("Button", nil, f)
        h:SetSize(col.width or 100, HEADER_H)
        h:SetPoint("TOPLEFT", x, -PAD)
        local fs = h:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("LEFT", 3, 0)
        fs:SetPoint("RIGHT", -3, 0)
        fs:SetJustifyH(col.align or "LEFT")
        h.label = fs
        h:SetScript("OnClick", function()
            if list.sortKey == col.key then
                list:Sort(col.key, not list.sortDesc)
            else
                list:Sort(col.key, false)
            end
        end)
        list.headers[i] = h
        x = x + (col.width or 100)
    end
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", PAD, -(PAD + HEADER_H))
    line:SetPoint("TOPRIGHT", -PAD, -(PAD + HEADER_H))

    -- Zeilen
    list.rowFrames = {}
    for r = 1, list.rowsVisible do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(list.width - PAD * 2 - SCROLL_W, list.rowHeight)
        row:SetPoint("TOPLEFT", PAD, -(PAD + HEADER_H + (r - 1) * list.rowHeight))
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local sel = row:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.55, 0.81, 0.30, 0.25)   -- Peon-Gruen
        sel:Hide()
        row.sel = sel
        -- Zeilenfarbe (ab API 8, opts.rowColor), unter der Auswahl
        local tint = row:CreateTexture(nil, "BACKGROUND", nil, -1)
        tint:SetAllPoints()
        tint:Hide()
        row.tint = tint
        row.cells = {}
        local cx = 0
        for c, col in ipairs(list.columns) do
            local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 3, 0)
            fs:SetWidth((col.width or 100) - 6)
            fs:SetJustifyH(col.align or "LEFT")
            if fs.SetWordWrap then fs:SetWordWrap(false) end
            row.cells[c] = fs
            cx = cx + (col.width or 100)
        end
        row:SetScript("OnClick", function(_, button)
            local item = row.item
            if not item then return end
            if o.selectable ~= false then list.selected = item; list:Update() end
            if o.onClick then Peon._ListCall(list, "onClick", o.onClick, list, item, button) end
        end)
        row:SetScript("OnEnter", function()
            if row.item and o.onEnter then Peon._ListCall(list, "onEnter", o.onEnter, list, row.item, row) end
        end)
        row:SetScript("OnLeave", function()
            if o.onLeave then Peon._ListCall(list, "onLeave", o.onLeave, list, row.item, row) end
        end)
        list.rowFrames[r] = row
    end

    -- Hinweis bei leerer Liste
    local empty = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    empty:SetPoint("TOP", 0, -(PAD + HEADER_H + 8))
    empty:SetText(o.emptyText or L.LIST_EMPTY)
    list.empty = empty

    -- Bildlauf: Schieberegler rechts und Mausrad
    local bar = CreateFrame("Slider", nil, f)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(SCROLL_W - 2)
    bar:SetPoint("TOPRIGHT", -PAD, -(PAD + HEADER_H + 2))
    bar:SetPoint("BOTTOMRIGHT", -PAD, PAD + 2)
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.06)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetScript("OnValueChanged", function(_, value)
        if list.updating then return end
        list:SetOffset(math.floor((tonumber(value) or 0) + 0.5))
    end)
    list.bar = bar

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) list:Scroll(-delta * 3) end)

    list:UpdateHeaders()
    list:Update()
    return list
end

-- Fehler in Rueckruf-Funktionen melden, ohne die Liste kaputtzumachen
function Peon._ListCall(list, where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local key = tostring(where) .. tostring(err)
        list.reported = list.reported or {}
        if not list.reported[key] then
            list.reported[key] = true
            Peon.ReportCoreError("List " .. tostring(where), err)
        end
    end
end

function List:GetWidth() return self.width end
function List:GetHeight() return self.height end

function List:SetData(items)
    self.data = type(items) == "table" and items or {}
    local still = false
    for _, it in ipairs(self.data) do if it == self.selected then still = true; break end end
    if not still then self.selected = nil end
    self:Refresh()
end

-- Sicht neu aufbauen (sortieren) und anzeigen
function List:Refresh()
    local view = {}
    for i, it in ipairs(self.data) do view[i] = it end
    local key = self.sortKey
    if key then
        local col
        for _, c in ipairs(self.columns) do if c.key == key then col = c end end
        local pos = {}
        for i, it in ipairs(view) do pos[it] = i end
        local get = (col and col.sortValue) or function(it) return it[key] end
        local desc = self.sortDesc
        local vals = {}
        for _, it in ipairs(view) do
            local ok, v = pcall(get, it)
            vals[it] = ok and v or nil
        end
        table.sort(view, function(a, b)
            local va, vb = vals[a], vals[b]
            if va ~= nil and vb ~= nil then
                local lt, gt = Compare(va, vb), Compare(vb, va)
                if lt or gt then
                    if desc then return gt end
                    return lt
                end
            elseif va ~= nil or vb ~= nil then
                return va ~= nil                 -- leere Werte immer ans Ende
            end
            return pos[a] < pos[b]               -- gleiche Werte: alte Reihenfolge
        end)
    end
    self.view = view
    self:SetOffset(self.offset)
end

function List:Sort(key, desc)
    self.sortKey, self.sortDesc = key, desc and true or false
    self:UpdateHeaders()
    self:Refresh()
end

function List:UpdateHeaders()
    for i, col in ipairs(self.columns) do
        local text = col.title or col.key or ""
        if self.sortKey and col.key == self.sortKey then
            text = text .. (self.sortDesc and " v" or " ^")
        end
        self.headers[i].label:SetText(text)
    end
end

function List:MaxOffset()
    return math.max(0, #self.view - self.rowsVisible)
end

function List:SetOffset(offset)
    offset = math.max(0, math.min(self:MaxOffset(), tonumber(offset) or 0))
    self.offset = offset
    self:Update()
end

function List:Scroll(rows)
    self:SetOffset(self.offset + (rows or 0))
end

function List:Select(item)
    self.selected = item
    -- sichtbar machen
    for i, it in ipairs(self.view) do
        if it == item then
            if i <= self.offset then self:SetOffset(i - 1)
            elseif i > self.offset + self.rowsVisible then self:SetOffset(i - self.rowsVisible) end
            break
        end
    end
    self:Update()
end

function List:GetSelected() return self.selected end
function List:GetItems() return self.view end

-- Zeilen fuellen
function List:Update()
    for r, row in ipairs(self.rowFrames) do
        local item = self.view[self.offset + r]
        row.item = item
        if item then
            for c, col in ipairs(self.columns) do
                local value = item[col.key]
                local text
                if col.format then
                    local ok, t = pcall(col.format, value, item)
                    text = ok and t or "?"
                else
                    text = value
                end
                if Peon.IsSecret(text) then text = L.SECRET end
                row.cells[c]:SetText(text ~= nil and tostring(text) or "")
            end
            if item == self.selected then row.sel:Show() else row.sel:Hide() end
            row:Show()
        else
            row.sel:Hide()
            row:Hide()
        end
    end
    self:UpdateColors()
    if #self.view == 0 then self.empty:Show() else self.empty:Hide() end
    local max = self:MaxOffset()
    self.updating = true
    self.bar:SetMinMaxValues(0, max)
    self.bar:SetValue(self.offset)
    self.updating = false
    if max > 0 then self.bar:Show() else self.bar:Hide() end
end

-- Zeilenfarben (ab API 8): opts.rowColor(item) -> r, g, b, a oder nil
function List:UpdateColors()
    local fn = self.o.rowColor
    for r, row in ipairs(self.rowFrames) do
        local item = row.item
        local cr, cg, cb, ca
        if fn and item then
            local ok, a1, a2, a3, a4 = pcall(fn, item)
            if ok then cr, cg, cb, ca = a1, a2, a3, a4 end
        end
        if row.tint then
            if type(cr) == "number" and (ca or 1) > 0 then
                row.tint:SetColorTexture(cr, cg or 0, cb or 0, ca or 1)
                row.tint:Show()
            else
                row.tint:Hide()
            end
        end
    end
end

-- Baustein fuer Optionsseiten (Widgets.lua): Container mit Liste
local Page = Peon.PagePrototype
if Page then
    function Page:List(o)
        local c = CreateFrame("Frame", nil, self.content)
        local list = Peon.NewList(c, o)
        c:SetSize(list:GetWidth(), list:GetHeight())
        list.frame:SetPoint("TOPLEFT", 0, 0)
        c.list = list
        return c
    end
end
