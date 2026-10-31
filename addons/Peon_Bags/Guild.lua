-- Peon_Bags - Guild.lua
-- Gildenbank (vorbereitet nach Blizzards Retail-Schnittstelle, im Spiel noch nicht getestet):
-- Reiter je Fach, 98 Plaetze je Fach, Nehmen/Ablegen/Stapel teilen, Gold mit Einzahlen/Abheben.
-- Fehlt eine noetige Funktion, bleibt Blizzards Gildenbank-Fenster wie gehabt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local SLOTS_PER_TAB = 98
local w
local tabs, slots = {}, {}
local blizzVisit, byGame = false, false
ns.guildOpen = false

local NEEDED = { "GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetCurrentGuildBankTab", "SetCurrentGuildBankTab",
                 "QueryGuildBankTab", "GetGuildBankItemInfo", "GetGuildBankItemLink", "PickupGuildBankItem",
                 "AutoStoreGuildBankItem", "GetGuildBankMoney" }

function ns.GuildSupported()
    for _, n in ipairs(NEEDED) do
        if type(rawget(_G, n)) ~= "function" then return false, n end
    end
    return true
end

local function Replacing()
    return mod.db.replaceGuild and not blizzVisit and ns.GuildSupported()
        and not Peon.IsAddOnLoaded("Bagnon_GuildBank") and not ns.BagnonLoaded()
end

local function GBFrame() return rawget(_G, "GuildBankFrame") end

local function CloseGuild()
    if type(rawget(_G, "CloseGuildBankFrame")) == "function" then pcall(CloseGuildBankFrame)
    else
        local PIM = rawget(_G, "C_PlayerInteractionManager")
        if PIM and PIM.ClearInteraction then pcall(PIM.ClearInteraction, ns.PIT("GuildBanker", 10)) end
    end
end

local function CurrentTab()
    local t = ns.Try(rawget(_G, "GetCurrentGuildBankTab"))
    return ns.Num(t) and t or 1
end

---------------------------------------------------------------------------
-- Plaetze (eigene einfache Knoepfe; Gildenbank-Funktionen sind nicht geschuetzt)
---------------------------------------------------------------------------
local function SlotInfo(b)
    local tab = CurrentTab()
    local tex, count, locked, filtered, quality = ns.Try(GetGuildBankItemInfo, tab, b.slot)
    local link = ns.Try(GetGuildBankItemLink, tab, b.slot)
    if not tex and not link then return nil end
    local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    return { iconFileID = tex, stackCount = count, isLocked = locked, quality = quality, hyperlink = link, itemID = itemID or 0 }
end

local function UpdateGuildSlot(b)
    local info = SlotInfo(b)
    b.peonInfo = info
    b.hasItem = info and true or nil
    local SIT, SIC, SID = rawget(_G, "SetItemButtonTexture"), rawget(_G, "SetItemButtonCount"), rawget(_G, "SetItemButtonDesaturated")
    if SIT then pcall(SIT, b, info and info.iconFileID or nil) elseif b.icon then b.icon:SetTexture(info and info.iconFileID or nil) end
    if SIC then pcall(SIC, b, info and info.stackCount or 0) end
    if SID then pcall(SID, b, info and info.isLocked or false) end
    local SQ = rawget(_G, "SetItemButtonQuality")
    if SQ then pcall(SQ, b, mod.db.quality and info and info.quality or nil, info and info.hyperlink) end
    local alpha = 1
    if ns.search ~= "" and not ns.Matches(info) then alpha = 0.3 end
    b:SetAlpha(alpha)
end

local function OnClick(self, button)
    local tab = CurrentTab()
    local info = self.peonInfo
    if info and info.hyperlink and HandleModifiedItemClick and HandleModifiedItemClick(info.hyperlink) then return end
    if IsModifiedClick and IsModifiedClick("SPLITSTACK") then
        if info and not info.isLocked and (info.stackCount or 0) > 1 and not (CursorHasItem and CursorHasItem()) then
            if StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
                pcall(StackSplitFrame.OpenStackSplitFrame, StackSplitFrame, info.stackCount, self, "BOTTOMLEFT", "TOPLEFT")
            elseif rawget(_G, "OpenStackSplitFrame") then
                pcall(OpenStackSplitFrame, info.stackCount, self, "BOTTOMLEFT", "TOPLEFT")
            end
        end
        return
    end
    local kind, amount = nil, nil
    if GetCursorInfo then kind, amount = GetCursorInfo() end
    if kind == "money" and DepositGuildBankMoney then
        DepositGuildBankMoney(amount)
        if ClearCursor then ClearCursor() end
    elseif kind == "guildbankmoney" then
        if DropCursorMoney then DropCursorMoney() end
        if ClearCursor then ClearCursor() end
    elseif button == "RightButton" then
        AutoStoreGuildBankItem(tab, self.slot)
    else
        PickupGuildBankItem(tab, self.slot)
    end
end

local function NewGuildSlot(i)
    local name = "PeonBagsGuildItem" .. i
    local b
    local ok = pcall(function() b = CreateFrame("ItemButton", name, w.content) end)
    if not ok or not b then
        ok = pcall(function() b = CreateFrame("Button", name, w.content, "ItemButtonTemplate") end)
    end
    if not ok or not b then
        b = CreateFrame("Button", name, w.content)
        b:SetSize(ns.SLOT, ns.SLOT)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
    end
    b.slot = i
    b.peonBag, b.peonSlot = 0, i   -- fuer die gemeinsame Sortierung
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", OnClick)
    b:SetScript("OnDragStart", function(self) PickupGuildBankItem(CurrentTab(), self.slot) end)
    b:SetScript("OnReceiveDrag", function(self) PickupGuildBankItem(CurrentTab(), self.slot) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetGuildBankItem then pcall(GameTooltip.SetGuildBankItem, GameTooltip, CurrentTab(), self.slot) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Stapel teilen: Blizzards Teilen-Fenster ruft SplitStack(Knopf, Menge) auf
    b.SplitStack = function(self, n)
        if SplitGuildBankItem then SplitGuildBankItem(CurrentTab(), self.slot, n) end
    end
    return b
end

---------------------------------------------------------------------------
-- Reiter (Faecher)
---------------------------------------------------------------------------
local function TabInfo(i)
    local name, icon, viewable, canDeposit, numWithdrawals, remaining = ns.Try(GetGuildBankTabInfo, i)
    return { name = name, icon = icon, viewable = viewable, canDeposit = canDeposit, numWithdrawals = numWithdrawals, remaining = remaining }
end

local function SelectTab(i)
    ns.Try(rawget(_G, "SetCurrentGuildBankTab"), i)
    ns.Try(rawget(_G, "QueryGuildBankTab"), i)
    ns.RefreshGuild()
end

local function NewTab(i)
    local t = CreateFrame("Button", nil, w.bar)
    t:SetSize(26, 26)
    t:SetPoint("LEFT", w.bar, "LEFT", (i - 1) * 28, 0)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetAllPoints()
    t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    t.sel = t:CreateTexture(nil, "OVERLAY")
    t.sel:SetPoint("TOPLEFT", -3, 3)
    t.sel:SetPoint("BOTTOMRIGHT", 3, -3)
    t.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    t.sel:SetBlendMode("ADD")
    t.id = i
    t:SetScript("OnClick", function(self) SelectTab(self.id) end)
    t:SetScript("OnEnter", function(self)
        local info = TabInfo(self.id)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(info.name or ("#" .. self.id), 1, 1, 1)
        if info.remaining then
            local left = info.remaining < 0 and L.GUILD_UNLIMITED or tostring(info.remaining)
            GameTooltip:AddLine(L.GUILD_TAB_LEFT:format(left), nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return t
end

local function UpdateTabs()
    local n = ns.Try(GetNumGuildBankTabs) or 0
    local cur = CurrentTab()
    for i = 1, math.max(n, #tabs) do
        if i <= n then
            local t = tabs[i] or NewTab(i)
            tabs[i] = t
            local info = TabInfo(i)
            t.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            t.icon:SetDesaturated(not info.viewable)
            t.sel:SetShown(i == cur)
            t:Show()
        elseif tabs[i] then
            tabs[i]:Hide()
        end
    end
    w.bar:SetWidth(math.max(1, n * 28))
end

---------------------------------------------------------------------------
-- Inhalt
---------------------------------------------------------------------------
local function UpdateFooter()
    local money = ns.Try(GetGuildBankMoney) or 0
    local left = L.GUILD_MONEY:format(ns.Money(money))
    local wm = ns.Try(rawget(_G, "GetGuildBankWithdrawMoney"))
    local right = ""
    if ns.Num(wm) then
        right = L.GUILD_LEFT:format(wm < 0 and L.GUILD_UNLIMITED or ns.Money(math.min(wm, money)))
    end
    w:SetFooter(left, right)
end

function ns.RefreshGuild()
    if not w then return end
    UpdateTabs()
    local info = TabInfo(CurrentTab())
    local list = {}
    for i = 1, SLOTS_PER_TAB do
        local b = slots[i]
        if not b then b = NewGuildSlot(i); slots[i] = b end
        UpdateGuildSlot(b)
        list[i] = b
    end
    w.note:SetText((info.viewable == false) and L.GUILD_NO_VIEW or "")
    local sections = ns.BuildSections(w:Layout(), list)
    w:Arrange(sections, list)
    w:UpdateLayoutButton()
    UpdateFooter()
end

---------------------------------------------------------------------------
-- Gold: eigene Rueckfragen mit Geld-Eingabe (nur Eintraege in StaticPopupDialogs hinzufuegen)
---------------------------------------------------------------------------
local function MoneyPopup(key, text, fn)
    if type(rawget(_G, "StaticPopupDialogs")) ~= "table" then return end
    StaticPopupDialogs[key] = {
        text = text, button1 = rawget(_G, "ACCEPT") or "OK", button2 = rawget(_G, "CANCEL") or "Cancel",
        hasMoneyInputFrame = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function(self)
            local mi = self.moneyInputFrame or (self.GetMoneyInputFrame and self:GetMoneyInputFrame())
            local get = rawget(_G, "MoneyInputFrame_GetCopper")
            local amount = mi and get and get(mi) or 0
            if amount and amount > 0 then fn(amount) end
        end,
    }
end

---------------------------------------------------------------------------
-- Gildenbank auf/zu
---------------------------------------------------------------------------
local function OnGuildShow()
    ns.guildOpen = true
    if not Replacing() then return end
    ns.Tuck(GBFrame())
    w:Show()
    ns.Try(rawget(_G, "QueryGuildBankTab"), CurrentTab())
    ns.RefreshGuild()
end

local function OnGuildHide()
    ns.guildOpen = false
    blizzVisit = false
    byGame = true; w:Hide(); byGame = false
    ns.Untuck(GBFrame())
end
ns.OnGuildShow, ns.OnGuildHide = OnGuildShow, OnGuildHide

function ns.UpdateReplaceGuild()
    if not w or not ns.guildOpen then return end
    if Replacing() then OnGuildShow() else
        byGame = true; w:Hide(); byGame = false
        ns.Untuck(GBFrame())
    end
end

function ns.InitGuild()
    w = ns.NewWindow("guild", {
        title = L.TITLE_GUILD,
        point = { "TOPLEFT", 50, -120 },
        onHide = function()
            if ns.guildOpen and not byGame then CloseGuild() end
            if StaticPopup_Hide then pcall(StaticPopup_Hide, "PEON_BAGS_GB_DEPOSIT"); pcall(StaticPopup_Hide, "PEON_BAGS_GB_WITHDRAW") end
        end,
    })
    w.note = w.content:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    w.note:SetPoint("BOTTOMLEFT", w.content, "TOPLEFT", 0, 2)
    w:AddLayoutToggle()
    w:AddButton(L.BTN_DEPOSIT, 80, nil, function()
        local amount = GetCursorMoney and GetCursorMoney() or 0
        if amount and amount > 0 and DepositGuildBankMoney then
            DepositGuildBankMoney(amount); if DropCursorMoney then DropCursorMoney() end
        elseif StaticPopup_Show then StaticPopup_Show("PEON_BAGS_GB_DEPOSIT") end
    end)
    w.withdrawBtn = w:AddButton(L.BTN_WITHDRAW, 80, nil, function()
        if StaticPopup_Show then StaticPopup_Show("PEON_BAGS_GB_WITHDRAW") end
    end)
    w:AddButton(L.BTN_BLIZZARD, 80, L.BTN_BLIZZARD_TIP, function()
        blizzVisit = true
        byGame = true; w:Hide(); byGame = false
        ns.Untuck(GBFrame())
        local gb = GBFrame()
        if gb and not gb:IsShown() and type(rawget(_G, "ShowUIPanel")) == "function" then pcall(ShowUIPanel, gb) end
    end)
    MoneyPopup("PEON_BAGS_GB_DEPOSIT", L.GB_DEPOSIT_Q, function(n) if DepositGuildBankMoney then DepositGuildBankMoney(n) end end)
    MoneyPopup("PEON_BAGS_GB_WITHDRAW", L.GB_WITHDRAW_Q, function(n) if WithdrawGuildBankMoney then WithdrawGuildBankMoney(n) end end)

    w.OnSearch = function()
        if w.search and w.search:GetText() ~= ns.searchRaw then w.search:SetText(ns.searchRaw or "") end
        for _, b in pairs(slots) do
            b:SetAlpha((ns.search == "" or ns.Matches(b.peonInfo)) and 1 or 0.3)
        end
    end
    w.Apply = function()
        w:ApplyPosition()
        if w:IsShown() then ns.RefreshGuild() end
    end
    w.Apply()

    -- Blizzards Gildenbank-Fenster (wird erst beim ersten Besuch geladen) verstecken
    local function Check(panel)
        local gb = GBFrame()
        if panel and gb and panel == gb and ns.guildOpen and Replacing() then ns.Tuck(gb) end
    end
    if type(rawget(_G, "ShowUIPanel")) == "function" then hooksecurefunc("ShowUIPanel", Check) end

    local gbKind = ns.PIT("GuildBanker", 10)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
        if kind == gbKind then OnGuildShow() end
    end)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        if kind == gbKind and ns.guildOpen then OnGuildHide() end
    end)
    local function RefreshIfShown() if w:IsShown() then ns.RefreshGuild() end end
    for _, e in ipairs({ "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE_TABS", "GUILDBANK_ITEM_LOCK_CHANGED",
                         "GUILDBANK_UPDATE_WITHDRAWMONEY" }) do
        pcall(mod.RegisterEvent, mod, e, RefreshIfShown)
    end
    pcall(mod.RegisterEvent, mod, "GUILDBANK_UPDATE_MONEY", function() if w:IsShown() then UpdateFooter() end end)
    local ok, missing = ns.GuildSupported()
    mod:Dbg("Gildenbank: " .. (ok and "Schnittstelle vorhanden" or ("fehlt " .. tostring(missing))))
end
