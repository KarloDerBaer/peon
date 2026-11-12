-- Peon_Bags - Bank.lua
-- Bankfenster: erscheint mit der Bank, Blizzards Bankfenster wird solange unsichtbar gemacht (in einen
-- winzigen, sichtbaren Rahmen umgehaengt - so bleibt die Bank offen). Plaetze wie bei den Taschen
-- (Blizzards Taschenknoepfe); Materiallager und Accountbank als eigene Abschnitte, falls es sie gibt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local w
local barButtons = {}
local blizzVisit = false   -- "Blizzard" gedrueckt: dieser Besuch mit Blizzards Fenster
local byGame = false       -- Fenster schliesst, weil die Bank zu ist (nicht selbst schliessen)
ns.bankOpen = false

---------------------------------------------------------------------------
-- Blizzard-Fenster unsichtbar machen, ohne es zu schliessen
---------------------------------------------------------------------------
local tiny
function ns.Tiny()
    if not tiny then
        tiny = CreateFrame("Frame", nil, UIParent)
        tiny:SetSize(1, 1)
        tiny:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        tiny:SetScale(0.001)
        tiny:SetAlpha(0)
        tiny:EnableMouse(false)
    end
    return tiny
end

-- Blizzard-Fenster verstecken bzw. zurueckholen (frame = BankFrame oder GuildBankFrame)
function ns.Tuck(frame)
    if not frame or frame:GetParent() == ns.Tiny() then return end
    if ns.Locked(frame) then ns.Defer("tuck:" .. tostring(frame), function() ns.Tuck(frame) end) return end
    frame.peonParent = frame:GetParent()
    frame:SetParent(ns.Tiny())
end

-- Texte neu setzen, damit das Spiel ihre Breite neu misst. Im winzigen Rahmen (Groesse 0,001) misst es Texte
-- riesig breit (Schrift hat eine Mindestgroesse) und behaelt das, solange sich der Text nicht aendert. Blizzards
-- Geldanzeigen setzen jede Muenze auf diese Breite (MoneyFrame_Update). In der Bank lag der Kaufen-Knopf, der
-- rechts am Betrag haengt, so bei x = 4878, das Fenster endet bei 496 (Fehlerbericht 0.6.0).
local function RemeasureTexts(frame, depth)
    if depth > 8 then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if type(t) == "string" and not Peon.IsSecret(t) and t ~= "" then r:SetText(""); r:SetText(t) end
        end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if type(c) == "table" then RemeasureTexts(c, depth + 1) end
    end
end

-- Geldanzeigen eines Blizzard-Fensters neu berechnen lassen (Bank: Kosten unten links, eigenes Gold unten rechts)
local function RefreshMoney(frame)
    local panel = rawget(frame, "BankPanel")
    if type(panel) ~= "table" then return end
    for _, key in ipairs({ "MoneyDisplay", "MoneyFrame" }) do
        local m = rawget(panel, key)
        if type(m) == "table" and type(m.Refresh) == "function" then pcall(m.Refresh, m) end
    end
end

local function Remeasure(frame)
    if not frame:IsShown() or frame:GetParent() == ns.Tiny() then return end
    pcall(RemeasureTexts, frame, 0)
    RefreshMoney(frame)
end

function ns.Untuck(frame)
    if not frame or frame:GetParent() ~= ns.Tiny() then return end
    if ns.Locked(frame) then ns.Defer("untuck:" .. tostring(frame), function() ns.Untuck(frame) end) return end
    frame:SetParent(frame.peonParent or UIParent)
    Remeasure(frame)
    -- die neue Groesse gilt vielleicht erst nach dem naechsten Bildaufbau: dann noch einmal
    local CT = rawget(_G, "C_Timer")
    if CT and type(CT.After) == "function" then CT.After(0, function() Remeasure(frame) end) end
end

local function BankFrame() return rawget(_G, "BankFrame") end

-- Blizzards Bankfenster wieder zeigen (Untuck misst Texte und Geldanzeigen neu)
local function ShowBlizzardBank()
    local bf = BankFrame()
    if not bf then return end
    ns.Untuck(bf)
    if not bf:IsShown() and type(rawget(_G, "ShowUIPanel")) == "function" then pcall(ShowUIPanel, bf) end
    if bf:IsShown() and bf:GetParent() ~= ns.Tiny() then pcall(bf.Raise, bf) end
end

local function CloseBank()
    local CB = rawget(_G, "C_Bank")
    if CB and type(CB.CloseBankFrame) == "function" then pcall(CB.CloseBankFrame)
    elseif type(rawget(_G, "CloseBankFrame")) == "function" then pcall(CloseBankFrame) end
end

---------------------------------------------------------------------------
-- Inhalt
---------------------------------------------------------------------------
local function ActiveBags()
    local list = {}
    for _, b in ipairs(ns.BankBags()) do
        if ns.NumSlots(b.id) > 0 then list[#list + 1] = b end
    end
    return list
end

local function ForSlots(fn)
    for _, b in ipairs(ns.BankBags()) do
        for _, s in pairs(ns.slots[b.id] or {}) do fn(s) end
    end
end

local function UpdateFooter()
    local free, total = 0, 0
    for _, b in ipairs(ActiveBags()) do
        if b.kind == "bank" then
            free = free + ns.FreeSlots(b.id)
            total = total + ns.NumSlots(b.id)
        end
    end
    w:SetFooter(L.FREE:format(free, total), ns.Money(GetMoney and GetMoney() or 0))
end

local function Refresh()
    if not w then return end
    local main, all, reagent, account = {}, {}, {}, {}
    local complete = true
    for _, b in ipairs(ns.BankBags()) do
        local target = b.kind == "reagent" and reagent or b.kind == "account" and account or main
        if ns.NumSlots(b.id) > 0 or ns.slots[b.id] then
            if not ns.CollectBagSlots(b.id, w.content, target, all) then complete = false end
        end
    end
    if not complete then ns.Defer("bank:refresh", Refresh) end
    local extra = {}
    if #reagent > 0 then extra[#extra + 1] = { title = L.SEC_REAGENTBANK, items = reagent, key = "reagentbank" } end
    if #account > 0 then extra[#extra + 1] = { title = L.SEC_ACCOUNT, items = account, key = "account" } end
    w:Arrange(ns.BuildSections(w:SectionConfig(), main, extra), all)
    for _, bb in ipairs(barButtons) do bb:Refresh() end
    UpdateFooter()
end
ns.RefreshBank = Refresh

-- Leiste: nur Bank-Taschenplaetze, die das Spiel als Ausruestungsplatz kennt (klassische Bank-Taschen)
local function BuildBar()
    local x = 0
    for _, b in ipairs(ns.BankBags()) do
        if b.id > 0 and b.kind == "bank" and ns.InvID(b.id) then
            barButtons[#barButtons + 1] = ns.NewBarButton(w.bar, b.id, x, ForSlots)
            x = x + 26
        end
    end
    w.bar:SetWidth(math.max(1, x))
end

---------------------------------------------------------------------------
-- Bank auf/zu
---------------------------------------------------------------------------
local function Replacing() return ns.Replacing() and not blizzVisit end

local function OnBankShow()
    ns.bankOpen = true
    if not Replacing() then return end
    ns.Tuck(BankFrame())
    if #barButtons == 0 then BuildBar() end
    w:Show()
    Refresh()
end

local function OnBankHide()
    ns.bankOpen = false
    blizzVisit = false
    byGame = true
    w:Hide()
    byGame = false
    ns.Untuck(BankFrame())
end
ns.OnBankShow, ns.OnBankHide = OnBankShow, OnBankHide

-- Hauptschalter geaendert
function ns.UpdateReplaceBank()
    if not w then return end
    if ns.bankOpen and not Replacing() then
        byGame = true; w:Hide(); byGame = false
        ShowBlizzardBank()
    elseif ns.bankOpen and Replacing() then
        OnBankShow()
    end
end

function ns.InitBank()
    w = ns.NewWindow("bank", {
        title = L.TITLE_BANK,
        template = "PortraitFrameTemplate", portrait = "npc",
        point = { "TOPLEFT", 50, -120 },
        onHide = function()
            -- selbst geschlossen (X, ESC): Bank schliessen
            if ns.bankOpen and not byGame then CloseBank() end
        end,
    })
    w.useGroups = true
    local C = ns.C()
    if type(C.SortBankBags) == "function" then
        w:AddButton(L.BTN_SORT, 80, L.BTN_SORT_TIP, function()
            if not InCombatLockdown() then pcall(C.SortBankBags) end
        end)
    end
    w:AddButton(L.BTN_BLIZZARD, 80, L.BTN_BLIZZARD_TIP, function()
        blizzVisit = true
        byGame = true; w:Hide(); byGame = false
        ShowBlizzardBank()
    end)
    w:AddSetupButton()
    w.OnSearch = function()
        if w.search and w.search:GetText() ~= ns.searchRaw then w.search:SetText(ns.searchRaw or "") end
        ForSlots(ns.UpdateMatch)
    end
    w.Apply = function()
        w:ApplyPosition()
        if w:IsShown() then Refresh() end
    end
    w.Apply()

    -- Blizzards Bankfenster verstecken, sobald es erscheint
    local function Check(panel)
        if panel and panel == BankFrame() and ns.bankOpen and Replacing() then ns.Tuck(panel) end
    end
    if type(rawget(_G, "ShowUIPanel")) == "function" then hooksecurefunc("ShowUIPanel", Check) end
    local bf = BankFrame()
    if bf and bf.HookScript then bf:HookScript("OnShow", function(self) Check(self) end) end

    local banker = ns.PIT("Banker", 8)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
        if kind == banker then OnBankShow() end
    end)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        if kind == banker and ns.bankOpen then OnBankHide() end
    end)
    pcall(mod.RegisterEvent, mod, "BANKFRAME_OPENED", function() if not ns.bankOpen then OnBankShow() end end)
    pcall(mod.RegisterEvent, mod, "BANKFRAME_CLOSED", function() if ns.bankOpen then OnBankHide() end end)

    local dirty = false
    mod:RegisterEvent("BAG_UPDATE", function(_, bag) if ns.IsBankBag(bag) then dirty = true end end)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if dirty and w:IsShown() then Refresh() end
        dirty = false
    end)
    local function RefreshIfShown() if w:IsShown() then Refresh() end end
    for _, e in ipairs({ "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
                         "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED", "REAGENTBANK_PURCHASED" }) do
        pcall(mod.RegisterEvent, mod, e, RefreshIfShown)
    end
    mod:RegisterEvent("ITEM_LOCK_CHANGED", function(_, bag, slot)
        if not w:IsShown() or not ns.Num(bag) or not ns.Num(slot) then return end
        local b = ns.slots[bag] and ns.slots[bag][slot]
        if b then ns.UpdateSlot(b) end
    end)
    mod:RegisterEvent("BAG_UPDATE_COOLDOWN", function() if w:IsShown() then ForSlots(ns.UpdateCooldown) end end)
    mod:RegisterEvent("PLAYER_MONEY", function() if w:IsShown() then UpdateFooter() end end)
end
