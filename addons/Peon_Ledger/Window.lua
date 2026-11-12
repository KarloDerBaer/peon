-- Peon_Ledger - Window.lua
-- Ledger-Fenster. Ab 0.14 (Neuaufbau E4, Konzept Peon_Ledger_Neuaufbau.md Abschnitt 6) mit Peon.UI wie Broker:
-- Fenster 800 x 538 im Look des Auktionshauses, vier Reiter unten, Statuszeile mit Kontrollrechnung und Gold.
--   Uebersicht (Overview.lua)  "Wie stehe ich da?"
--   Bestand (Stock.lua)        "Was habe ich wo?"
--   Buch (Book.lua)            "Was habe ich verdient, und wofuer ging Gold weg?"
--   Verlauf (History.lua)      "Was ist passiert?"
-- Jeder Reiter meldet sich mit W.pages[key] = { build = fn(content), refresh = fn() } an.
-- Oeffnen: /ledger, Minimap-Button, Panel. ESC schliesst.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local W = {}
ns.Window = W

W.TABS = {
    { key = "overview", label = "TAB_OVERVIEW" },
    { key = "stock",    label = "TAB_STOCK" },
    { key = "book",     label = "TAB_BOOK" },
    { key = "history",  label = "TAB_HISTORY" },
    { key = "info",     label = "TAB_INFO" },      -- ab 0.14.5: Begriffe und Abweichungen
}
W.pages = {}
W.contents = {}
W.QUALITY = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }
W.GREY, W.GREEN, W.RED, W.YELLOW = "|cff999999", "|cff40c040", "|cffe05050", "|cffffd100"

local function UI() return Peon.UI end

-- Masse der Bereiche (Peon_UI_Design.md Abschnitt 3)
function W.Area()
    local U = UI()
    return { top = U.TOP, bottom = U.BOTTOM, left = U.EDGE, right = U.EDGE + 1, width = U.WINDOW_W - 2 * U.EDGE - 1 }
end

local function SavePosition(f)
    if not f.GetPoint then return end
    local point, _, rel, x, y = f:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    mod.db.windowPos = { point = point, rel = rel, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

function W.Create()
    if W.frame then return W.frame end
    local U = UI()
    local f = U.Window("PeonLedgerFrame", { title = ("|c%sPeon|r Ledger"):format(Peon.COLOR), icon = "Interface\\Icons\\INV_Scroll_03" })
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    local defs = {}
    for _, t in ipairs(W.TABS) do defs[#defs + 1] = { t.key, L[t.label] } end
    W.tabs = U.BottomTabs(f, defs, function(key) if not W.selecting then W.Select(key) end end)
    W.tabButtons = {}
    for i, t in ipairs(W.tabs) do t.text = defs[i][2]; W.tabButtons[i] = t end
    W.status = U.StatusBar(f)
    f:SetScript("OnShow", function() mod:Call("Fenster", W.Refresh) end)
    W.frame = f
    return f
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

function W.Open(tab)
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.MSG_COMBAT); return end
    W.Create()
    W.Place()
    W.Select(tab or W.current or mod.db.windowTab)
    W.frame:Show()
    W.Refresh()
end

function W.Toggle(tab)
    if W.frame and W.frame:IsShown() then W.frame:Hide() else W.Open(tab) end
end

function W.IsOpen() return W.frame ~= nil and W.frame:IsShown() end

function W.Select(key)
    W.Create()
    if not W.pages[key] then key = "overview" end
    W.current = key
    mod.db.windowTab = key
    W.selecting = true
    if W.tabs and W.tabs.Select then W.tabs:Select(key) end
    W.selecting = nil
    for k, c in pairs(W.contents) do if k ~= key then c:Hide() end end
    local c = W.contents[key]
    if not c then
        c = CreateFrame("Frame", nil, W.frame)
        c:SetAllPoints()
        W.contents[key] = c
        W.pages[key].build(c)
    end
    c:Show()
    if W.frame:IsShown() then W.Refresh() end
end

function W.Refresh()
    if not W.frame then return end
    local page = W.current and W.pages[W.current]
    if page and page.refresh then page.refresh() end
    W.UpdateStatus()
end

-- Statuszeile: links Kontrollrechnung (bzw. Text der Seite), rechts Gold aller Charaktere
function W.UpdateStatus()
    if not W.status then return end
    local total = ns.Inventory.TotalMoney()
    if W.status.money then W.status.money:SetAmount(math.max(0, total or 0)) end
    local page = W.current and W.pages[W.current]
    local text = page and page.status and page.status() or nil
    local check = ns.Check and ns.Check.StatusText() or ""
    W.statusText = text and (text .. "   ·   " .. check) or check
    W.status:SetText(W.statusText)
end

-- Neue Daten (Bestand geaendert): offenes Fenster einmal je Bild auffrischen
function W.OnData()
    if not W.IsOpen() or W.pending then return end
    W.pending = true
    if C_Timer then
        C_Timer.After(0, function() W.pending = nil; mod:Call("Fenster", W.Refresh) end)
    else
        W.pending = nil
        W.Refresh()
    end
end

---------------------------------------------------------------------------
-- Hilfen fuer die Reiter
---------------------------------------------------------------------------
function W.Lower(s)
    return (tostring(s or ""):lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end

function W.Colored(name, quality)
    local c = W.QUALITY[quality or 1] or W.QUALITY[1]
    return "|c" .. c .. tostring(name) .. "|r"
end

function W.ClassColored(name, class)
    local cc = type(class) == "string" and rawget(_G, "RAID_CLASS_COLORS") and RAID_CLASS_COLORS[class]
    if type(cc) == "table" and type(cc.colorStr) == "string" then return "|c" .. cc.colorStr .. name .. "|r" end
    return name
end

function W.ShowItemTooltip(owner, id)
    if not GameTooltip or not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id)
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

-- Geld mit Vorzeichen in Gruen/Rot, 0 grau
function W.Signed(v)
    if not v or math.abs(v) < 0.5 then return W.GREY .. "0|r" end
    return (v > 0 and W.GREEN .. "+" or W.RED .. "-") .. "|r" .. ns.Money(math.floor(math.abs(v) + 0.5))
end

-- Geld oder grauer Strich
function W.MoneyOr(v)
    if not v then return W.GREY .. "–|r" end
    return ns.Money(math.floor(v + 0.5))
end

-- Auswahlliste der Charaktere: "*" = alle, sonst Name
function W.CharItems()
    local items = { { "*", L.ALL_CHARS } }
    local names = ns.Inventory.CharNames and ns.Inventory.CharNames() or {}
    for _, n in ipairs(names) do items[#items + 1] = { n, n } end
    return items
end

-- Zeile "Beschriftung ... Wert" in einem Bereich (Uebersicht, Buch, Post)
function W.ValueLine(parent, y, width)
    local l = parent:CreateFontString(nil, "ARTWORK", UI().FONT.label)
    l:SetPoint("TOPLEFT", 14, y)
    l:SetJustifyH("LEFT")
    local v = parent:CreateFontString(nil, "ARTWORK", UI().FONT.text)
    v:SetPoint("TOPRIGHT", -14, y)
    v:SetJustifyH("RIGHT")
    if width then l:SetWidth(width) end
    return { label = l, value = v, Set = function(self, a, b) self.label:SetText(a or ""); self.value:SetText(b or "") end }
end

-- Rechtsklick auf einen Gegenstand: Gegenstandsmenue des Kerns (wenn vorhanden)
function W.ItemMenu(id, owner)
    if not id or not Peon.OpenItemMenu then return end
    local name = ns.Inventory.ItemInfo(id)
    pcall(Peon.OpenItemMenu, { id = id, name = name, link = "item:" .. id }, owner)
end

function W.Init() end
