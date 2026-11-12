-- Peon_Broker - Lots.lua
-- Stufe 2, H3 (ab 0.67, Konzept Peon_Broker_Neuaufbau.md, Abschnitte 6.2 und 6.3): Wiederverkauf-Kette.
-- Gekauftes und Abgebrochenes kommt per Post. Broker merkt sich deshalb jeden Aufkauf aus dem Radar und jede
-- abgebrochene unterbotene Auktion als Posten (Gegenstand, Menge, Einsatz, Zielpreis) und fuehrt bis zum Einstellen.
--
-- Speicher je Charakter (die Ware liegt in seiner Post und Tasche): PeonBrokerCharDB.lots = {
--   { id, key, qty, left (noch einzustellen), cost (Einsatz gesamt, nil = unbekannt), target (Zielpreis je Stueck),
--     src ("radar" oder "cancel"), t, posted = { price, qty, t } } }
--
-- Einstellen bleibt Blizzards Weg (Rechtsklick in der Tasche, Klick auf "Auktion erstellen"). Broker legt nichts selbst
-- ins Verkaufsfenster: SetPostItem aus Addon-Code beruehrt Blizzards Wert displayMode, danach blockiert das Spiel das
-- Benutzen aus der Tasche (Fehlerberichte 10 und 11, Broker 0.64.1).
--
-- Zielpreis eintragen (Konzept 6.2, KarloDerBaer 11.11.2026): schreibt per Klick den Zielpreis in Blizzards Preisfeld
-- (PriceInput:SetAmount, wie Broker 0.10 bis 0.12, im Spiel bestaetigt). Pruefung auf Blockaden: Meldet das Spiel
-- innerhalb von LT.BLOCK_WATCH Sekunden danach eine blockierte Aktion von Broker, merkt Broker das (acc.targetBlocked)
-- und bietet den Knopf nicht mehr an. Der Zielpreis steht dann nur noch im Rat.
--
-- Unterbotene abbrechen (Konzept 6.3): Jeder Klick bricht die naechste unterbotene Auktion ab (eine je Klick, das Spiel
-- erlaubt es nur aus einem Klick). Vorher nennt der Knopf, was an Einzahlung verloren geht.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local LT = {}
ns.Lots = LT

LT.BLOCK_WATCH = 60          -- Sekunden nach "Zielpreis eintragen", in denen eine Blockade dem Knopf zugeschrieben wird
LT.POSTED_KEEP = 2 * 86400   -- eingestellte Posten bleiben so lange (Fokus bewacht sie), danach weg
LT.MAX = 100                 -- hoechstens so viele Posten

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end
local function Money(v) return ns.Tooltip.Money(v) end
local function AHApi() return rawget(_G, "C_AuctionHouse") end

function LT.List()
    local c = mod.char
    if type(c) ~= "table" then return {} end
    if type(c.lots) ~= "table" then c.lots = {} end
    return c.lots
end

-- Neuer Posten (Radar-Kauf oder abgebrochene Auktion)
function LT.Add(key, qty, cost, target, src)
    if key == nil or not Num(qty) or qty < 1 then return nil end
    local list = LT.List()
    local c = mod.char
    c.lotSeq = (tonumber(c.lotSeq) or 0) + 1
    local lot = { id = c.lotSeq, key = key, qty = qty, left = qty, cost = Num(cost) and cost or nil,
                  target = Num(target) and math.floor(target + 0.5) or nil, src = src or "radar", t = time() }
    list[#list + 1] = lot
    while #list > LT.MAX do table.remove(list, 1) end
    mod:Dbg(("Posten: %s x%d, Ziel %s (%s)"):format(tostring(key), qty, tostring(lot.target), lot.src))
    LT.Changed()
    return lot
end

function LT.Remove(id)
    local list = LT.List()
    for i, lot in ipairs(list) do
        if lot.id == id then table.remove(list, i); LT.Changed(); return true end
    end
    return false
end

-- Posten, die noch eingestellt werden muessen
function LT.Open()
    local out = {}
    for _, lot in ipairs(LT.List()) do if (lot.left or 0) > 0 then out[#out + 1] = lot end end
    return out
end

function LT.Count() return #LT.Open() end

-- erster offener Posten zu einem Gegenstand (Variante oder Grund-ID)
function LT.ForKey(key)
    if key == nil then return nil end
    local id = ns.Data.ItemID(key)
    for _, lot in ipairs(LT.List()) do
        if (lot.left or 0) > 0 and (lot.key == key or ns.Data.ItemID(lot.key) == id) then return lot end
    end
    return nil
end

-- eingestellter Posten zu einem Gegenstand (fuer den Fokus: bewachen)
function LT.Posted(key)
    if key == nil then return nil end
    local best
    for _, lot in ipairs(LT.List()) do
        if lot.key == key and type(lot.posted) == "table" and (not best or lot.posted.t > best.posted.t) then best = lot end
    end
    return best
end

-- Stueck in den Taschen (ohne Bank)
function LT.InBags(key)
    local ci = rawget(_G, "C_Item")
    local id = ns.Data.ItemID(key)
    if not (ci and ci.GetItemCount and id) then return nil end
    local ok, n = pcall(ci.GetItemCount, id)
    return ok and Num(n) and n or nil
end

-- Einsatz je Stueck
function LT.UnitCost(lot)
    if not Num(lot.cost) or not Num(lot.qty) or lot.qty < 1 then return nil end
    return lot.cost / lot.qty
end

-- Eingestellt: offene Posten des Gegenstands um die Menge kuerzen (aelteste zuerst)
function LT.OnPosted(key, qty, price)
    if key == nil or not Num(qty) or qty < 1 then return 0 end
    local id, rest, hit = ns.Data.ItemID(key), qty, 0
    for _, lot in ipairs(LT.List()) do
        if rest <= 0 then break end
        if (lot.left or 0) > 0 and (lot.key == key or ns.Data.ItemID(lot.key) == id) then
            local take = math.min(lot.left, rest)
            lot.left, rest, hit = lot.left - take, rest - take, hit + take
            lot.posted = { price = Num(price) and price or nil, qty = (lot.posted and lot.posted.qty or 0) + take, t = time() }
        end
    end
    if hit > 0 then LT.Changed() end
    return hit
end

-- alte eingestellte Posten aufraeumen
function LT.Prune(now)
    now = now or time()
    local list = LT.List()
    for i = #list, 1, -1 do
        local lot = list[i]
        if (lot.left or 0) <= 0 and (not lot.posted or now - (lot.posted.t or 0) > LT.POSTED_KEEP) then table.remove(list, i) end
    end
end

---------------------------------------------------------------------------
-- Einstellen beobachten: sicherer Anhang an PostItem der beiden Verkaufsfenster merkt Gegenstand, Menge und Preis
-- (aus dem Rat, Advice.current), das Ereignis AUCTION_HOUSE_AUCTION_CREATED bestaetigt.
---------------------------------------------------------------------------
LT.POST_WAIT = 10
function LT.OnPostClick()
    local it = ns.Advice and ns.Advice.current
    if not it or it.key == nil then return end
    LT.pendingPost = { key = it.key, qty = Num(it.qty) and it.qty or 1, price = it.price, t = GetTime and GetTime() or 0 }
end

function LT.OnCreated()
    local p = LT.pendingPost
    LT.pendingPost = nil
    if not p or (GetTime and GetTime() or 0) - p.t > LT.POST_WAIT then return end
    LT.OnPosted(p.key, p.qty, p.price)
end

---------------------------------------------------------------------------
-- Zielpreis eintragen
---------------------------------------------------------------------------
function LT.CanFill()
    return not (type(mod.acc.targetBlocked) == "table")
end

-- Schreibt den Zielpreis des Postens in Blizzards Preisfeld. Rueckgabe true = eingetragen
function LT.FillTarget(sf, lot)
    if not LT.CanFill() or type(sf) ~= "table" or not lot or not Num(lot.target) then return false end
    local input = rawget(sf, "PriceInput")
    if type(input) ~= "table" or type(input.SetAmount) ~= "function" then return false end
    local ok = pcall(input.SetAmount, input, lot.target)
    if ok then
        LT.filledAt = GetTime and GetTime() or 0
        mod.acc.targetFills = (tonumber(mod.acc.targetFills) or 0) + 1
        mod:Dbg("Zielpreis eingetragen: " .. tostring(lot.target))
    end
    return ok
end

-- Das Spiel meldet eine blockierte Aktion von Broker: kurz nach "Zielpreis eintragen" gilt sie als Folge davon
function LT.OnBlocked(event, addon, fn)
    if addon ~= ADDON_NAME or not LT.filledAt then return end
    if (GetTime and GetTime() or 0) - LT.filledAt > LT.BLOCK_WATCH then return end
    mod.acc.targetBlocked = { t = time(), event = event, fn = type(fn) == "string" and fn or "?" }
    mod:Print(L.LOTS_FILL_BLOCKED)
end

---------------------------------------------------------------------------
-- Unterbotene abbrechen (Blizzards Reiter Auktionen)
---------------------------------------------------------------------------
-- Naechste unterbotene, nicht verkaufte Auktion (aelteste Zeile zuerst) und ihre Kosten
function LT.NextUndercut()
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do
        if r.status == "under" and not r.sold and r.id then return r, LT.CancelCost(r.id) end
    end
    return nil
end

function LT.CountUndercut()
    local n = 0
    for _, r in ipairs(ns.Auctions and ns.Auctions.rows or {}) do
        if r.status == "under" and not r.sold then n = n + 1 end
    end
    return n
end

function LT.CancelCost(id)
    local ah = AHApi()
    if not (ah and ah.GetCancelCost) then return nil end
    local ok, c = pcall(ah.GetCancelCost, id)
    return ok and Num(c) and c or nil
end

-- Ein Klick: naechste unterbotene Auktion abbrechen. Der neue Zielpreis ist das guenstigste fremde Angebot minus
-- Unterbieten (wie Verkaufen, F15).
function LT.CancelNext()
    return LT.CancelRow((LT.NextUndercut()))
end

-- ab 0.72: eine bestimmte Auktion abbrechen (Liste "Meine Auktionen"). Neues Ziel: guenstigstes fremdes Angebot
-- minus Unterbieten, ohne fremdes Angebot der bisherige Preis.
function LT.CancelRow(r)
    local ah = AHApi()
    if not r or not (ah and ah.CancelAuction) then return false end
    if Peon.InCombat and Peon.InCombat() then mod:Print(L.SELL_COMBAT); return false end
    local ok = pcall(ah.CancelAuction, r.id)
    if not ok then mod:Print(L.LOTS_CANCEL_FAILED); return false end
    local unit = Num(r.price) and r.qty and r.qty > 0 and r.price or nil
    local target = Num(r.other) and ns.Data.Undercut(r.other, r.key, mod.db) or unit
    LT.cancelling = { id = r.id, key = r.key, qty = r.qty or 1, target = target, unit = unit, name = r.name }
    return true
end

-- Abbruch bestaetigt: Posten mit dem neuen Preis
function LT.OnCanceled(auctionID)
    local c = LT.cancelling
    if not c or (auctionID ~= nil and auctionID ~= c.id) then return end
    LT.cancelling = nil
    LT.Add(c.key, c.qty, nil, c.target, "cancel")
    mod:Print(L.LOTS_CANCELED:format(c.name or tostring(c.key), c.target and Money(c.target) or "?"))
    if ns.Auctions then pcall(ns.Auctions.Query) end
end

---------------------------------------------------------------------------
-- Anzeige: Zahl am Reiter Verkaufen, Statuszeile, Liste
---------------------------------------------------------------------------
-- Text von Blizzards Reiter "Verkaufen" mit Zahl (nur der Text, wie "Markt" statt "Kaufen")
function LT.UpdateSellTab()
    local f = rawget(_G, "AuctionHouseFrame")
    local tab = type(f) == "table" and rawget(f, "SellTab") or nil
    if type(tab) ~= "table" or not tab.SetText or not ns.AHTouch() then return end
    local base = L.AHTAB_SELL_BASE
    local n = LT.Count()
    tab:SetText(n > 0 and (base .. " (" .. n .. ")") or base)
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
    if ns.AHTabs and ns.AHTabs.AlignSoon then ns.AHTabs.AlignSoon() end
end

function LT.StatusPart()
    local n = LT.Count()
    if n <= 0 then return nil end
    return L.LOTS_STATUS:format(n)
end

function LT.Changed()
    LT.UpdateSellTab()
    LT.RefreshPanel()
    if ns.Focus and ns.Focus.Update then ns.Focus.Update() end
end

-- Zeilen fuer die Liste "Zum Einstellen"
function LT.Rows()
    local rows, D = {}, ns.Data
    for _, lot in ipairs(LT.Open()) do
        local e = D.Lookup(lot.key)
        local id = D.ItemID(lot.key)
        local bags = LT.InBags(lot.key)
        rows[#rows + 1] = {
            lot = lot, key = lot.key, link = D.LinkFromKey and D.LinkFromKey(lot.key) or nil,
            name = (type(e) == "table" and e.nm) or D.ItemName(lot.key, e) or tostring(lot.key),
            quality = type(e) == "table" and e.ql or nil, icon = ns.Buy.Icon(id),
            qty = lot.left, unit = LT.UnitCost(lot), target = lot.target,
            now = type(e) == "table" and not e.gone and e.m or nil, bags = bags,
        }
    end
    return rows
end

-- Klick auf einen Posten: am Auktionator Brokers Flaeche schliessen und sagen, wie es weitergeht
function LT.Pick(row)
    if not row then return end
    local T = ns.AHTabs
    if ns.Scan.ahOpen and T and T.current then T.Close() end
    local text = (row.bags or 0) > 0 and L.LOTS_HINT_POST or L.LOTS_HINT_MAIL
    local ef = rawget(_G, "UIErrorsFrame")
    if type(ef) == "table" and ef.AddMessage then pcall(ef.AddMessage, ef, text, 1, 0.82, 0) end
    mod:Print(text)
end

-- Rechtsklick: Posten entfernen, In den Fokus, Gegenstand
function LT.Menu(row, owner)
    if not row then return end
    local mu = rawget(_G, "MenuUtil")
    if not (mu and mu.CreateContextMenu) then return end
    mu.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(row.name or "")
        root:CreateButton(L.LOTS_REMOVE, function() LT.Remove(row.lot.id) end)
        root:CreateButton(L.MENU_FOCUS or L.NTAB_FOCUS, function() mod:Call("Sprung", ns.Go.Focus, { key = row.key }) end)
        root:CreateButton(L.NTAB_ITEM, function() mod:Call("Sprung", ns.Go.Item, { key = row.key }) end)
    end)
end

---------------------------------------------------------------------------
-- Zum Einstellen im Reiter Verkaufen (ab 0.71, KarloDerBaer 12.11.2026, vorher im Radar)
-- Knopf "Zum Einstellen (n)" ueber Blizzards Angebotsliste rechts. Er legt Brokers Liste der Posten darueber
-- (eigene Flaeche, Blizzards Liste bleibt darunter unberuehrt). Ein Klick waehlt einen Posten, der Gold-Knopf
-- darunter legt ihn ins Verkaufsfenster: ein sicherer Knopf (SecureActionButtonTemplate) mit dem Makro
-- "/click <Taschenplatz> RightButton". Das ist derselbe Klick wie der Rechtsklick in der Tasche, Blizzards eigener
-- Code legt den Gegenstand hinein, Broker beruehrt keine Werte (Fehlerberichte 10 und 11). Findet Broker keinen
-- Taschenplatz mit Namen, sagt der Hinweis "Rechtsklick in der Tasche".
---------------------------------------------------------------------------
local function AHF() local f = rawget(_G, "AuctionHouseFrame"); return type(f) == "table" and f or nil end

-- Blizzards Liste rechts im Verkaufen (Massenware oder Einzelgegenstand), die gerade zu sehen ist
function LT.SellList()
    local f = AHF()
    if not f then return nil end
    for _, name in ipairs({ "CommoditiesSellList", "ItemSellList" }) do
        local l = rawget(f, name)
        if type(l) == "table" and l.IsShown and l:IsShown() then return l end
    end
    return nil
end

-- Steht Blizzards Auktionshaus gerade auf Verkaufen?
function LT.InSell()
    local f = AHF()
    if not (f and f.IsShown and f:IsShown()) then return false end
    for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
        local sf = rawget(f, name)
        if type(sf) == "table" and sf.IsShown and sf:IsShown() then return true end
    end
    return false
end

-- Erster Taschenplatz mit diesem Gegenstand: bag, slot
function LT.FindBagSlot(key)
    local cc = rawget(_G, "C_Container")
    if not (cc and cc.GetContainerNumSlots and cc.GetContainerItemID) then return nil end
    local id = ns.Data.ItemID(key)
    for bag = 0, 5 do
        local ok, n = pcall(cc.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(n)) or 0 do
            local ok2, iid = pcall(cc.GetContainerItemID, bag, slot)
            if ok2 and iid == id then
                local info = cc.GetContainerItemInfo and select(2, pcall(cc.GetContainerItemInfo, bag, slot))
                if not (type(info) == "table" and info.isLocked) then return bag, slot end
            end
        end
    end
    return nil
end

-- Taschenknopf mit Namen fuer bag/slot: Peon_Bags (PeonBagsItemN), sonst Blizzards Taschenfenster
function LT.FindButton(bag, slot)
    for i = 1, 400 do
        local b = rawget(_G, "PeonBagsItem" .. i)
        if b == nil then break end
        if b.peonBag == bag and b.peonSlot == slot then return "PeonBagsItem" .. i end
    end
    for f = 1, 13 do
        for i = 1, 40 do
            local name = "ContainerFrame" .. f .. "Item" .. i
            local b = rawget(_G, name)
            if b == nil then break end
            local okB, bb = pcall(function() return b.GetBagID and b:GetBagID() end)
            local okS, ss = pcall(function() return b:GetID() end)
            if okB and okS and bb == bag and ss == slot then return name end
        end
    end
    return nil
end

local function InCombat() return InCombatLockdown and InCombatLockdown() or false end

-- Posten waehlen: den sicheren Knopf auf seinen Taschenplatz richten
function LT.Select(row)
    LT.sel = row
    local b = LT.postButton
    if not b then return end
    local text, ready = L.LOTS_POST, false
    if not row then
        text = L.LOTS_PICK
    elseif not ((row.bags or 0) > 0) then
        text = L.LOTS_IN_MAIL
    elseif InCombat() then
        text = L.LOTS_COMBAT
    else
        local bag, slot = LT.FindBagSlot(row.key)
        local name = bag and LT.FindButton(bag, slot)
        if name then
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", "/click " .. name .. " RightButton")
            ready = true
        else
            text = L.LOTS_NO_SLOT
        end
    end
    if not ready and not InCombat() then b:SetAttribute("type", nil); b:SetAttribute("macrotext", nil) end
    b:SetText(text)
    if ready then b:Enable() else b:Disable() end
    LT.postHint:SetText(ready and "" or (row and ((row.bags or 0) > 0 and L.LOTS_HINT_POST or L.LOTS_HINT_MAIL) or ""))
end

function LT.BuildPanel()
    if LT.toggle or not ns.AHTouch() then return end
    local f, UI = AHF(), Peon.UI
    if not (f and UI) then return end
    -- Knopf ueber Blizzards Liste rechts
    local t = UI.Button(f, L.LOTS_BUTTON:format(0), 170, function() LT.ShowPanel(not (LT.panel and LT.panel:IsShown())) end)
    t:SetFrameLevel(520)
    UI.SetTooltip(t, { L.LOTS_TITLE, L.LOTS_TIP })
    t:Hide()
    LT.toggle = t
    -- Flaeche ueber Blizzards Liste
    local p = CreateFrame("Frame", "PeonBrokerLotsPanel", f)
    p:SetFrameLevel(370)
    p:EnableMouse(true)
    p:Hide()
    LT.panel = p
    local lp = UI.Panel(p, "list", true)
    lp:SetPoint("TOPLEFT", 0, 0)
    lp:SetPoint("BOTTOMRIGHT", 0, 34)
    LT.list = UI.Table(lp, {
        columns = {
            { key = "name", title = L.COL_ITEM, sort = function(r) return ns.Window.Lower(r.name) end,
              color = function(r) return UI.QualityColor(r.quality or 1) end },
            { key = "qty", title = L.FOCUS_R_QTY, width = 54, align = "RIGHT" },
            { key = "unit", title = L.LOTS_COL_COST, width = 84, align = "RIGHT",
              format = function(v) return v and ns.Tooltip.Money(math.floor(v + 0.5)) or "|cff999999-|r" end },
            { key = "target", title = L.FOCUS_R_TARGET, width = 84, align = "RIGHT", format = function(v) return v and ns.Tooltip.Money(v) or "?" end },
            { key = "now", title = L.LOTS_COL_NOW, width = 84, align = "RIGHT",
              format = function(v, r)
                  if not v then return "|cff999999-|r" end
                  local warn = r.target and v < r.target
                  return (warn and "|cffff5555" or "") .. ns.Tooltip.Money(v) .. (warn and "|r" or "")
              end },
            { key = "bags", title = L.LOTS_COL_BAGS, width = 70, align = "RIGHT",
              format = function(v) if v and v > 0 then return tostring(v) end return "|cff999999" .. L.LOTS_MAIL .. "|r" end },
        },
        sortKey = "name", icon = true, empty = L.LOTS_EMPTY,
        onClick = function(r, button)
            if button == "RightButton" then LT.Menu(r, LT.panel) else mod:Call("Posten", LT.Select, r) end
        end,
        onEnter = function(row, r)
            if not r then return end
            ns.Window.ShowItemTooltip(row, r.key)
            if GameTooltip and r.target and r.now and r.now < r.target then
                GameTooltip:AddLine(L.LOTS_UNDER_TARGET, 1, 0.4, 0.4, true)
                GameTooltip:Show()
            end
        end,
    })
    function LT.list:GetItems() return self.items end
    -- sicherer Knopf: legt den gewaehlten Posten per Klick ins Verkaufsfenster
    local b = CreateFrame("Button", "PeonBrokerLotPostButton", p, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(230, 24)
    b:SetPoint("BOTTOMLEFT", 4, 5)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b:SetText(L.LOTS_PICK)
    b:Disable()
    LT.postButton = b
    LT.postHint = UI.Text(p, "small", "", 300)
    LT.postHint:SetPoint("LEFT", b, "RIGHT", 10, 0)
    -- sichtbar nur auf Verkaufen: an Blizzards Verkaufsfenster haengen (sichere Anhaenge)
    for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame", "CommoditiesSellList", "ItemSellList" }) do
        local sf = rawget(f, name)
        if type(sf) == "table" and sf.HookScript then
            sf:HookScript("OnShow", function() mod:Call("Posten", LT.Place) end)
            sf:HookScript("OnHide", function() mod:Call("Posten", LT.Place) end)
        end
    end
    LT.Place()
end

-- Knopf und Flaeche an Blizzards sichtbare Liste legen, ausserhalb von Verkaufen verstecken
function LT.Place()
    if not LT.toggle then return end
    local list = LT.InSell() and not (ns.AHTabs and ns.AHTabs.current) and LT.SellList() or nil
    if not list then
        LT.toggle:Hide()
        LT.panel:Hide()
        return
    end
    LT.toggle:ClearAllPoints()
    LT.toggle:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", -40, 4)   -- ab 0.74: Blizzards Knopf Neu laden bleibt frei
    LT.toggle:Show()
    LT.panel:ClearAllPoints()
    LT.panel:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    LT.panel:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    LT.RefreshPanel()
end

function LT.ShowPanel(on)
    if not LT.panel then return end
    LT.panel:SetShown(on and LT.InSell() and true or false)
    LT.RefreshPanel()
end

function LT.RefreshPanel()
    if not LT.toggle then return end
    local open = LT.panel:IsShown()
    LT.toggle:SetText(open and L.LOTS_BACK or L.LOTS_BUTTON:format(LT.Count()))
    if not open then return end
    local rows = LT.Rows()
    LT.list:SetData(rows)
    -- gewaehlten Posten mit frischen Zahlen behalten
    local sel
    for _, r in ipairs(rows) do if LT.sel and r.lot == LT.sel.lot then sel = r end end
    LT.Select(sel)
end

function LT.Init()
    LT.Prune()
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function()
        mod:Call("Posten", function()
            LT.UpdateSellTab()
            local f = rawget(_G, "AuctionHouseFrame")
            if LT.hooked or not ns.AHTouch() or type(f) ~= "table" or not hooksecurefunc then return end
            for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
                local sf = rawget(f, name)
                if type(sf) == "table" and type(sf.PostItem) == "function" then
                    hooksecurefunc(sf, "PostItem", function() mod:Call("Posten", LT.OnPostClick) end)
                    LT.hooked = true
                end
            end
        end)
    end)
    pcall(mod.RegisterEvent, mod, "AUCTION_HOUSE_AUCTION_CREATED", function() mod:Call("Posten", LT.OnCreated) end)
    pcall(mod.RegisterEvent, mod, "AUCTION_CANCELED", function(_, id) mod:Call("Posten", LT.OnCanceled, id) end)
    mod:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, addon, fn) mod:Call("Posten", LT.OnBlocked, "ADDON_ACTION_BLOCKED", addon, fn) end)
    mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) mod:Call("Posten", LT.OnBlocked, "ADDON_ACTION_FORBIDDEN", addon, fn) end)
    pcall(mod.RegisterEvent, mod, "BAG_UPDATE_DELAYED", function() mod:Call("Posten", LT.RefreshPanel) end)
    mod:RegisterEvent("AUCTION_HOUSE_SHOW", function() mod:Call("Posten", LT.BuildPanel) end)
    mod:RegisterEvent("AUCTION_HOUSE_CLOSED", function() if LT.panel then LT.panel:Hide() end end)
    mod:RegisterEvent("PLAYER_REGEN_ENABLED", function() if LT.sel then mod:Call("Posten", LT.Select, LT.sel) end end)
end
