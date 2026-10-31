-- Peon_Broker - Keep.lua
-- "Behalten" (je Charakter): Gegenstaende, die nicht oder nur teilweise verkauft werden sollen.
-- Speicher: PeonBrokerCharDB.keep[Schluessel] = { n = Menge oder nil (= alle), t = Zeit, name, q, icon }
-- Vorrat = Taschen + Bank (C_Item.GetItemCount mit Bank, geht auch bei geschlossener Bank).
-- Ab 0.22 (Ledger L6): Umschalter "Vorrat aller Charaktere" (mod.db.keepAllChars) - dann zaehlen auch
-- Taschen, Bank und Post der anderen Charaktere und die Accountbank aus Peon_Ledger (nur wenn geladen).
-- Zu verkaufen = Vorrat - Menge, hoechstens so viel wie in den Taschen.
-- Reiter "Behalten": Liste mit Menge, Vorrat, Taschen, Bank, Wert, Seit; Menge aendern, wieder verkaufen.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local W = ns.Window

local K = {}
ns.Keep = K

local GREY, GREEN = "|cff999999", "|cff60e060"
local function Money(v) return ns.Tooltip.Money(v) end
local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Speicher
---------------------------------------------------------------------------
function K.List()
    local c = mod.char
    if type(c) ~= "table" then return {} end
    if type(c.keep) ~= "table" then c.keep = {} end
    -- aus 0.10: true = alles behalten
    for key, v in pairs(c.keep) do
        if type(v) ~= "table" then c.keep[key] = { t = 0 } end
    end
    return c.keep
end

function K.Get(key)
    if key == nil then return nil end
    return K.List()[key]
end

-- Markieren (Menge nil = alle); info = { name, quality, icon } fuer die Anzeige ohne Gegenstand in den Taschen
function K.Set(key, n, info)
    if key == nil then return end
    local e = K.List()[key] or { t = time() }
    e.n = (type(n) == "number" and n > 0) and math.floor(n) or nil
    if type(info) == "table" then
        e.name = info.name or e.name
        e.q = info.quality or e.q
        e.icon = info.icon or e.icon
    end
    K.List()[key] = e
    return e
end

function K.Remove(key)
    K.List()[key] = nil
end

---------------------------------------------------------------------------
-- Zaehlen
---------------------------------------------------------------------------
local function ItemCount(id, bank)
    local fn = (C_Item and C_Item.GetItemCount) or rawget(_G, "GetItemCount")
    if not fn or not id then return nil end
    local ok, n
    if bank then ok, n = pcall(fn, id, true, false, true) else ok, n = pcall(fn, id) end
    if ok and Num(n) then return n end
    return nil
end

-- Peon_Ledger (wenn geladen, nur lesend)
function K.Ledger()
    if not Peon.GetModule then return nil end
    local ok, l = pcall(Peon.GetModule, Peon, "ledger")
    if ok and type(l) == "table" and type(l.StockOthers) == "function" then return l end
    return nil
end

function K.AllChars() return mod.db.keepAllChars == true and K.Ledger() ~= nil end

-- Vorrat der anderen Charaktere (Taschen, Bank, Post) und der Accountbank; 0 ohne Ledger oder Umschalter aus
function K.Others(id)
    if not id or not K.AllChars() then return 0 end
    local l = K.Ledger()
    local ok, n = pcall(l.StockOthers, l, id)
    if ok and Num(n) then return n end
    return 0
end

-- Taschen, Bank, Vorrat, andere Charaktere; bags = bereits gezaehlte Menge in den Taschen (sonst vom Spiel)
function K.Counts(id, bags)
    local carrying = ItemCount(id, false)
    bags = bags or carrying or 0
    local withBank = ItemCount(id, true)
    local bank = 0
    if withBank and carrying then bank = math.max(0, withBank - carrying) end
    local others = K.Others(id)
    return bags, bank, bags + bank + others, others
end

-- Wie viel darf verkauft werden? (nil-Eintrag = alles aus den Taschen)
function K.Sellable(key, id, bags)
    local e = K.Get(key)
    if not e then return bags end
    if not e.n then return 0 end
    local b, _, total = K.Counts(id, bags)
    return math.max(0, math.min(b, total - e.n))
end

-- Tooltip-Zeile "Behalten: alle" / "Behalten: 20 (1 zu verkaufen)"
function K.TooltipText(key, id)
    local e = K.Get(key)
    if not e then return nil end
    if not e.n then return L.KEEP_TT_ALL end
    return L.KEEP_TT_N:format(e.n, K.Sellable(key, id, nil))
end

---------------------------------------------------------------------------
-- Reiter "Behalten"
---------------------------------------------------------------------------
local function ItemID(key) return ns.Data.ItemID(key) end

function K.Rows()
    local rows = {}
    local D = ns.Data
    local inBags
    for key, e in pairs(K.List()) do
        local id = ItemID(key)
        local bags, bank, total, others = K.Counts(id, nil)
        -- Ausruestung mit Zusatz: die Taschen-Menge genau dieses Zusatzes zaehlen
        if type(key) == "string" and ns.Sell then
            if not inBags then
                inBags = {}
                for _, it in ipairs(ns.Sell.ScanBags()) do inBags[it.key] = it.count end
            end
            bags = inBags[key] or 0
            total = bags + bank + others
        end
        local name = e.name or D.ItemName(key, D.Lookup(key)) or L.ITEM_UNKNOWN:format(id or 0)
        local icon = e.icon
        if not icon and C_Item and C_Item.GetItemIconByID then
            local ok, i = pcall(C_Item.GetItemIconByID, id)
            if ok then icon = i end
        end
        -- Wert des Vorrats: bester Wert wie Zeile 1 im Tooltip
        local hp = ns.VendorPrice(id)
        local entry = D.Lookup(key)
        local value, ah
        if total > 0 then
            if type(entry) == "table" and entry.m then
                local v = D.Evaluate(entry, key, total, hp, mod.db)
                ah = v.ah
                value = v.ah and v.erl or v.hw
            elseif hp then
                value = hp * total
            end
        end
        rows[#rows + 1] = { key = key, e = e, name = name, lname = W.Lower(name), quality = e.q, icon = icon,
            amount = e.n, total = total, bags = bags, bank = bank, others = others, value = value, ah = ah, t = e.t }
    end
    return rows
end

function K.Refresh()
    if not K.list then return end
    local rows = K.Rows()
    K.list:SetData(rows)
    local sel
    if K.selectedKey ~= nil then
        for _, r in ipairs(rows) do if r.key == K.selectedKey then sel = r end end
    end
    if sel then K.list:Select(sel) else K.selectedKey = nil end
    K.count:SetText(GREY .. L.KEEP_COUNT:format(#rows) .. "|r")
    if K.allChars then
        if K.Ledger() then
            K.allChars:Show(); K.allChars.label:Show()
            K.allChars:SetChecked(mod.db.keepAllChars == true)
        else
            K.allChars:Hide(); K.allChars.label:Hide()
        end
    end
    K.UpdateBar()
end

function K.UpdateBar()
    local sel = K.selectedKey ~= nil and K.Get(K.selectedKey)
    if sel then
        K.bar:Show()
        K.filling = true
        K.amount:SetText(sel.n and tostring(sel.n) or "")
        K.filling = false
        K.amountHint:SetText(GREY .. (sel.n and "" or L.KEEP_ALL_HINT) .. "|r")
    else
        K.bar:Hide()
    end
end

function K.Select(row)
    K.selectedKey = row and row.key or nil
    K.UpdateBar()
end

function K.Unkeep(row)
    if not row then return end
    K.Remove(row.key)
    mod:Print(L.SELL_UNKEPT_MSG:format(row.name))
    if K.selectedKey == row.key then K.selectedKey = nil end
    K.Refresh()
end

function K.SetAmountFromBox()
    if K.filling or K.selectedKey == nil then return end
    local n = tonumber(K.amount:GetText() or "")
    K.Set(K.selectedKey, n)
    K.Refresh()
end

function K.Build(c)
    local inset = W.Inset(c)
    inset:SetAllPoints()
    local total = W.WIDTH - 24 - 8 - 24
    local fixed = 60 + 56 + 56 + 50 + 56 + 90 + 58
    K.list = Peon.NewList(inset, {
        columns = {
            { key = "name", title = L.COL_ITEM, width = total - fixed,
              format = function(v, r)
                  return "|T" .. tostring(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0|t " .. W.Colored(v, r.quality)
              end,
              sortValue = function(r) return r.lname end },
            { key = "amount", title = L.KEEP_COL_AMOUNT, width = 60, align = "RIGHT",
              format = function(v) return v and tostring(v) or L.KEEP_ALL end,
              sortValue = function(r) return r.amount or math.huge end },
            { key = "total", title = L.KEEP_COL_TOTAL, width = 56, align = "RIGHT" },
            { key = "bags", title = L.KEEP_COL_BAGS, width = 56, align = "RIGHT" },
            { key = "bank", title = L.KEEP_COL_BANK, width = 50, align = "RIGHT" },
            { key = "others", title = L.KEEP_COL_OTHERS, width = 56, align = "RIGHT",
              format = function(v) if not K.AllChars() then return GREY .. "–|r" end return tostring(v or 0) end },
            { key = "value", title = L.COL_VALUE, width = 90, align = "RIGHT",
              format = function(v, r)
                  if v == nil then return GREY .. "–|r" end
                  return (r.ah and GREEN or GREY) .. Money(v) .. "|r"
              end },
            { key = "t", title = L.KEEP_COL_SINCE, width = 58, align = "RIGHT",
              format = function(v) return (type(v) == "number" and v > 0) and date("%d.%m.", v) or "" end },
        },
        rows = 18, rowHeight = 19, sortKey = "name",
        onClick = function(list, r, button)
            if button == "RightButton" then K.Unkeep(r) else K.Select(r) end
        end,
        onEnter = function(list, r, row) W.ShowItemTooltip(row, r.key) end,
        onLeave = function() if GameTooltip then GameTooltip:Hide() end end,
        emptyText = L.KEEP_EMPTY,
    })
    K.list.frame:SetPoint("TOPLEFT", 4, -4)
    -- Vorrat hervorheben (die WoW-Schriften haben keinen Fettdruck: groesser und hellweiss)
    for _, row in ipairs(K.list.rowFrames) do
        local cell = row.cells[3]
        if cell and cell.SetFontObject then cell:SetFontObject("GameFontHighlight") end
    end
    if K.list.headers[3] and K.list.headers[3].label and K.list.headers[3].label.SetFontObject then
        K.list.headers[3].label:SetFontObject("GameFontHighlightSmall")
    end

    -- unten: Anzahl, Menge fuer die gewaehlte Zeile, wieder verkaufen
    K.count = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    K.count:SetPoint("BOTTOMLEFT", 10, 12)

    -- Umschalter: Vorrat nur dieser Charakter / alle Charaktere (Peon_Ledger)
    local cb = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("BOTTOMLEFT", 6, 28)
    local cbl = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cbl:SetText(L.KEEP_ALL_CHARS)
    cb.label = cbl
    cb:SetScript("OnClick", function(self)
        mod.db.keepAllChars = self:GetChecked() and true or false
        mod:Call("Behalten", K.Refresh)
    end)
    cb:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.KEEP_ALL_CHARS, 1, 1, 1)
        GameTooltip:AddLine(L.KEEP_ALL_CHARS_HINT, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    K.allChars = cb

    local bar = CreateFrame("Frame", nil, inset)
    bar:SetSize(420, 26)
    bar:SetPoint("BOTTOMRIGHT", -6, 6)
    K.bar = bar
    local unkeep = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    unkeep:SetSize(140, 24)
    unkeep:SetPoint("RIGHT", 0, 0)
    unkeep:SetText(L.SELL_UNKEEP)
    unkeep:SetScript("OnClick", function()
        for _, r in ipairs(K.list:GetItems()) do if r.key == K.selectedKey then mod:Call("Behalten", K.Unkeep, r) end end
    end)
    K.unkeepButton = unkeep
    local all = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    all:SetSize(56, 24)
    all:SetPoint("RIGHT", unkeep, "LEFT", -12, 0)
    all:SetText(L.SELL_ALL)
    all:SetScript("OnClick", function()
        if K.selectedKey == nil then return end
        K.Set(K.selectedKey, nil)
        K.Refresh()
    end)
    K.allButton = all
    local box = CreateFrame("EditBox", nil, bar, "InputBoxTemplate")
    box:SetSize(50, 20)
    box:SetPoint("RIGHT", all, "LEFT", -8, 0)
    box:SetAutoFocus(false)
    if box.SetNumeric then box:SetNumeric(true) end
    if box.SetMaxLetters then box:SetMaxLetters(5) end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); mod:Call("Behalten", K.SetAmountFromBox) end)
    box:SetScript("OnEditFocusLost", function() mod:Call("Behalten", K.SetAmountFromBox) end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    K.amount = box
    local lbl = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("RIGHT", box, "LEFT", -8, 0)
    lbl:SetText(L.KEEP_AMOUNT_LABEL)
    K.amountHint = bar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    K.amountHint:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 2)
    bar:Hide()
end

function K.Init()
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if W.IsOpen() and W.current == "keep" then K.Refresh() end
    end)
end

W.pages.keep = {
    build = K.Build,
    refresh = K.Refresh,
}
