-- Peon_Profession - AltClick.lua (ab 0.7.0)
-- Alt + Klick auf einen Gegenstand in der Tasche: Entzaubern (Waffen und Ruestung ab gruen, Verzauberkunst gelernt)
-- oder Schlossknacken (verschlossene Kassette, nur Schurke). Idee wie das Addon Molinari, eigener Code.
-- Im Handelsfenster: Alt + Klick auf das Feld "Wird nicht gehandelt" des anderen knackt dessen Kassette.
--
-- Ablauf: Zeigt das Spiel den Tooltip eines Taschenplatzes (GameTooltip:SetBagItem) oder eines Handelsfelds
-- (SetTradeTargetItem), prueft AltClick, ob es fuer den Gegenstand eine Aktion gibt. Dann steht im Tooltip ein
-- Hinweis. Ist Alt gedrueckt und kein Kampf, legt sich ein unsichtbarer sicherer Knopf genau ueber den Platz. Der
-- Klick geht auf diesen Knopf, das Spiel erlaubt den Zauber.
-- Der Knopf wird nur an dieselbe Stelle gesetzt, nie an den Platz gehaengt (ab 0.7.2): Ein sicherer Knopf, der an
-- einem normalen Knopf haengt, kann vom Spiel gesperrt werden. Er wirkt immer beim Loslassen (useOnKeyDown = false),
-- unabhaengig von der Einstellung ActionButtonUseKeyDown. Muster wie das Gifte-Symbol in Peon_ClassBuddy.
--   Tasche: Makro "/cast Zauber" und "/use Tasche Platz" (der Zauber zielt auf den Gegenstand).
--   Handel: der Knopf wirkt den Zauber, PostClick waehlt im selben Klick das Feld als Ziel (ClickTargetTradeButton).
-- Laesst man Alt los, verlaesst den Platz, schliesst den Handel oder beginnt ein Kampf, verschwindet der Knopf.
-- Verschlossen erkennt AltClick an der Tooltipzeile LOCKED des Spiels ("Verschlossen"), nicht an Gegenstandsnummern:
-- So bietet es eine schon geknackte Kassette nicht noch einmal an.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local A = {}
ns.AltClick = A

A.DISENCHANT = 13262   -- Entzaubern
A.PICKLOCK   = 1804    -- Schlossknacken

local btn, owner
A.current = nil        -- { kind, spell, bag, slot, trade, macro } auf das der Knopf gerade eingestellt ist

local function Secret(v) return Peon.IsSecret and Peon.IsSecret(v) end
local function Num(v) if v == nil or Secret(v) or type(v) ~= "number" then return nil end return v end
local function Str(v) if v == nil or Secret(v) or type(v) ~= "string" then return nil end return v end

local function LastBag()
    return Num(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or Num(rawget(_G, "NUM_BAG_SLOTS")) or 4
end

function A.Known(id)
    for _, fn in ipairs({ rawget(_G, "IsPlayerSpell"), C_SpellBook and C_SpellBook.IsSpellKnown, rawget(_G, "IsSpellKnown") }) do
        if type(fn) == "function" then
            local ok, r = pcall(fn, id)
            if ok and r == true then return true end
        end
    end
    return false
end

-- Text fuer "verschlossen" (Spiel, sonst Rueckfall)
function A.LockedText()
    return Str(rawget(_G, "LOCKED")) or ((GetLocale() == "deDE") and "Verschlossen" or "Locked")
end

-- Steht in den Tooltipzeilen "verschlossen"? lines: Liste von Texten
function A.HasLockedLine(lines)
    local want = A.LockedText()
    for _, t in ipairs(lines or {}) do
        t = Str(t)
        if t and strtrim(t) == want then return true end
    end
    return false
end

-- Zeilen des sichtbaren Tooltips
local function ScanLines(tt)
    local lines = {}
    local name = tt and tt.GetName and tt:GetName()
    local n = tt and tt.NumLines and Num(tt:NumLines()) or 0
    if name then
        for i = 1, n do
            local fs = rawget(_G, name .. "TextLeft" .. i)
            if fs and fs.GetText then lines[#lines + 1] = fs:GetText() end
        end
    end
    return lines
end

-- Zeilen aus den Tooltipdaten des Spiels (C_TooltipInfo), sonst nil
local function InfoLines(fnName, ...)
    local TI = rawget(_G, "C_TooltipInfo")
    if not (TI and TI[fnName]) then return nil end
    local ok, data = pcall(TI[fnName], ...)
    if not (ok and type(data) == "table" and type(data.lines) == "table") then return nil end
    local lines = {}
    for _, l in ipairs(data.lines) do if type(l) == "table" then lines[#lines + 1] = l.leftText end end
    return #lines > 0 and lines or nil
end

-- Zeilen des Tooltips fuer einen Taschenplatz: zuerst die Daten des Spiels, sonst die Zeilen des sichtbaren Tooltips
function A.TooltipLines(tt, bag, slot)
    return InfoLines("GetBagItem", bag, slot) or ScanLines(tt)
end

-- Zeilen des Tooltips fuer ein Feld des Handelspartners
function A.TradeLines(tt, index)
    return InfoLines("GetTradeTargetItem", index) or ScanLines(tt)
end

-- Welche Aktion passt? item = { id, quality, classID, subID, locked } -> "picklock", "disenchant" oder nil
function A.Decide(item, knows)
    if type(item) ~= "table" then return nil end
    knows = knows or A.Known
    if item.locked then
        return knows(A.PICKLOCK) and "picklock" or nil
    end
    local q, c = item.quality, item.classID
    if q and q >= 2 and q <= 4 and (c == 2 or c == 4) and not (c == 2 and item.subID == 20) then   -- 20 = Angel
        return knows(A.DISENCHANT) and "disenchant" or nil
    end
    return nil
end

-- Gegenstand auf einem Taschenplatz lesen
function A.ReadItem(bag, slot, lines)
    local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    if type(info) ~= "table" then return nil end
    local id = Num(info.itemID)
    if not id then return nil end
    local item = { id = id, quality = Num(info.quality), locked = A.HasLockedLine(lines) }
    local fn = C_Item and C_Item.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
    if fn then
        local ok, _, _, _, _, _, classID, subID = pcall(fn, id)
        if ok then item.classID, item.subID = Num(classID), Num(subID) end
    end
    return item
end

function A.SpellFor(kind)
    local id = (kind == "picklock") and A.PICKLOCK or A.DISENCHANT
    return ns.SpellName(id)
end

function A.Macro(spell, bag, slot)
    return ("/cast %s\n/use %d %d"):format(spell, bag, slot)
end

-- Feld "Wird nicht gehandelt" im Handelsfenster
function A.TradeSlot()
    return Num(rawget(_G, "TRADE_ENCHANT_SLOT")) or 7
end

---------------------------------------------------------------------------
-- Der Knopf ueber dem Taschenplatz oder dem Handelsfeld
---------------------------------------------------------------------------
function A.Hide()
    if not btn or InCombatLockdown() then return end
    btn:Hide()
    btn:ClearAllPoints()
    btn:SetAttribute("macrotext", nil)
    btn:SetAttribute("spell", nil)
    A.current, owner = nil, nil
end

-- Knopf an die Stelle von target setzen, ohne ihn dort anzuhaengen (Bildschirmposition ueber UIParent)
function A.Place(target)
    local l, b = Num(target.GetLeft and target:GetLeft()), Num(target.GetBottom and target:GetBottom())
    local w, h = Num(target.GetWidth and target:GetWidth()), Num(target.GetHeight and target:GetHeight())
    if not (l and b and w and h) then return false end
    local s = (Num(target.GetEffectiveScale and target:GetEffectiveScale()) or 1) / (Num(btn:GetEffectiveScale()) or 1)
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
    btn:SetSize(w * s, h * s)
    return true
end

-- where: { bag, slot } fuer die Tasche oder { trade = Feld } fuer das Handelsfenster
local function Arm(target, kind, where)
    if not btn or InCombatLockdown() or not target then return false end
    local spell = A.SpellFor(kind)
    if not spell then return false end
    local cur = { kind = kind, spell = spell, bag = where.bag, slot = where.slot, trade = where.trade }
    if where.trade then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spell)
        btn:SetAttribute("macrotext", nil)
    else
        cur.macro = A.Macro(spell, where.bag, where.slot)
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", cur.macro)
        btn:SetAttribute("spell", nil)
    end
    if not A.Place(target) then return false end
    if target.GetFrameStrata then btn:SetFrameStrata(target:GetFrameStrata()) end
    if target.GetFrameLevel then btn:SetFrameLevel((Num(target:GetFrameLevel()) or 0) + 10) end
    btn:Show()
    A.current = cur
    owner = target
    if where.trade then
        mod:Dbg(("AltClick: %s auf Handelsfeld %d"):format(kind, where.trade))
    else
        mod:Dbg(("AltClick: %s auf Tasche %d Platz %d"):format(kind, where.bag, where.slot))
    end
    return true
end

-- Hinweis in den Tooltip schreiben und bei gedrueckter Alt-Taste scharf schalten
local function Offer(tt, kind, where)
    local spell = A.SpellFor(kind)
    if not spell then return end
    if tt and tt.AddLine then
        tt:AddLine(L.ALTCLICK_HINT:format(spell), 0.5, 0.8, 1)
        if tt.Show then tt:Show() end
    end
    if IsAltKeyDown() and not InCombatLockdown() then
        local target = tt and tt.GetOwner and tt:GetOwner()
        if target and target ~= btn then Arm(target, kind, where) end
    end
end

-- Aus dem Tooltip-Hook der Taschen
function A.OnBagTooltip(tt, bag, slot)
    if not (mod.db and mod.db.altClick) then return end
    bag, slot = Num(bag), Num(slot)
    if not bag or not slot or bag < 0 or bag > LastBag() then return end   -- nur eigene Taschen, keine Bank
    local kind = A.Decide(A.ReadItem(bag, slot, A.TooltipLines(tt, bag, slot)))
    if kind then Offer(tt, kind, { bag = bag, slot = slot }) end
end

-- Aus dem Tooltip-Hook des Handelsfensters: nur das Feld "Wird nicht gehandelt" des anderen und nur
-- Schlossknacken (fremde Gegenstaende lassen sich nicht entzaubern)
function A.OnTradeTooltip(tt, index)
    if not (mod.db and mod.db.altClick) then return end
    index = Num(index)
    if not index or index ~= A.TradeSlot() then return end
    if not A.HasLockedLine(A.TradeLines(tt, index)) or not A.Known(A.PICKLOCK) then return end
    Offer(tt, "picklock", { trade = index })
end

-- Nach dem Klick (Loslassen): im Handel das Feld als Ziel waehlen (noch im selben Klick), dann den Knopf entfernen
function A.PostClick()
    local cur = A.current
    if cur and cur.trade then
        local targeting = rawget(_G, "SpellIsTargeting")
        local click = rawget(_G, "ClickTargetTradeButton")
        if click and (not targeting or targeting()) then
            local ok, err = pcall(click, cur.trade)
            if not ok then mod:Dbg("AltClick: Handelsfeld nicht gewaehlt: " .. tostring(err)) end
        else
            mod:Dbg("AltClick: Zauber wartet nicht auf ein Ziel")
        end
    end
    A.Hide()
end

local function OnModifier()
    if InCombatLockdown() then return end
    if not IsAltKeyDown() then A.Hide() return end
    -- Alt erst gedrueckt, als die Maus schon ueber dem Platz war: Tooltip neu aufbauen lassen
    local o = GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner()
    if o and o ~= btn and o.IsMouseOver and o:IsMouseOver() then
        local fn = o.GetScript and o:GetScript("OnEnter")
        if fn then pcall(fn, o) end
    end
end

function A.Init()
    if btn then return end
    btn = CreateFrame("Button", "PeonProfessionAltClick", UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetAttribute("useOnKeyDown", false)
    btn:Hide()
    -- Der Knopf liegt ueber dem Platz, der Platz verliert die Maus und damit den Tooltip: wieder aufbauen
    btn:SetScript("OnEnter", function()
        local o = owner
        local fn = o and o.GetScript and o:GetScript("OnEnter")
        if fn then pcall(fn, o) end
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
        A.Hide()
    end)
    btn:SetScript("PostClick", function() mod:Call("AltClick", A.PostClick) end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("MODIFIER_STATE_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("TRADE_CLOSED")
    ev:SetScript("OnEvent", function(_, e)
        if e == "MODIFIER_STATE_CHANGED" then mod:Call("AltClick", OnModifier) else A.Hide() end
    end)
    if GameTooltip and GameTooltip.SetBagItem then
        hooksecurefunc(GameTooltip, "SetBagItem", function(tt, bag, slot) mod:Call("AltClick", A.OnBagTooltip, tt, bag, slot) end)
    end
    if GameTooltip and GameTooltip.SetTradeTargetItem then
        hooksecurefunc(GameTooltip, "SetTradeTargetItem", function(tt, index) mod:Call("AltClick", A.OnTradeTooltip, tt, index) end)
    end
end

-- Fuer Tests
function A.Button() return btn end
