-- Peon_Bags - Inventory.lua
-- Taschenfenster: alle Taschen in einem Fenster, Reagenzientasche als eigener Abschnitt, Anordnung (ab 0.5)
-- Klassisch, Nach Art oder Individuell, Taschenleiste, Suche, freie Plaetze, Gold.
-- Oeffnen ueber Blizzards Taschen-Funktionen (nur mitgelesen) und automatisch an Haendler, Bank usw.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local w            -- Fenster
local barButtons = {}
local stale = true
local autoOpened = nil   -- Art des Fensters, das die Taschen automatisch geoeffnet hat

---------------------------------------------------------------------------
-- Plaetze sammeln und anordnen
---------------------------------------------------------------------------
local function SortItems(a, b)
    local ia, ib = a.peonInfo, b.peonInfo
    if (ia ~= nil) ~= (ib ~= nil) then return ia ~= nil end
    if ia and ib then
        local qa, qb = ia.quality or 1, ib.quality or 1
        if qa ~= qb then return qa > qb end
        local na, nb = ns.ItemName(ia) or "", ns.ItemName(ib) or ""
        if na ~= nb then return na < nb end
        local ca, cb = ia.stackCount or 0, ib.stackCount or 0
        if ca ~= cb then return ca > cb end
    end
    if a.peonBag ~= b.peonBag then return a.peonBag < b.peonBag end
    return a.peonSlot < b.peonSlot
end
ns.SortItems = SortItems

-- Neu erhalten? Ein neuer Gegenstand bleibt in "Neu", bis das Fenster schliesst (keepNew), auch wenn das
-- Ueberfahren mit der Maus ihn schon als gesehen markiert hat.
local function IsNew(b, keepNew)
    local info = b.peonInfo
    if not info then return false end
    if not b.peonBag or not keepNew then return b.peonIsNew and true or false end
    local k = b.peonBag .. ":" .. b.peonSlot
    if b.peonIsNew then keepNew[k] = info.itemID return true end
    return keepNew[k] == info.itemID
end

-- Abschnitte fuer eine Liste von Plaetzen nach Anordnung bauen (ab 0.5)
-- cfg = { layout = "classic" | "type" | "custom", catsOff, groupsOff, collapsed, useGroups, keepNew }
--   (Window:SectionConfig), ein Text gilt als layout ohne weitere Einstellungen
-- main = Plaetze (Taschenreihenfolge), extra = weitere Abschnitte { title, items, key } (bleiben eigene Abschnitte)
-- Eigene Bereiche (nur "custom" mit useGroups) stehen oben und ziehen ihre Gegenstaende auch aus den weiteren
-- Abschnitten ab. Mit Bereichen nehmen alle Ueberschriften abgelegte Gegenstaende an (target).
-- Jeder Abschnitt hat einen Schluessel (key) fuers Einklappen: g<id>, c:<Kategorie>, other, reagent ...
function ns.BuildSections(cfg, main, extra)
    if type(cfg) ~= "table" then cfg = { layout = cfg } end
    local layout = cfg.layout or "classic"
    local catsOff, groupsOff, collapsed = cfg.catsOff or {}, cfg.groupsOff or {}, cfg.collapsed or {}
    local sections = {}
    local target
    local own = {}
    if cfg.useGroups and layout == "custom" then
        for _, g in ipairs(ns.Groups()) do
            if not groupsOff[g.id] then own[#own + 1] = g end
        end
    end
    local hasGroups = #own > 0
    if hasGroups then
        target = ns.GROUP_NONE
        local byId = {}
        for _, g in ipairs(own) do
            local sec = { name = g.name, items = {}, target = g.id, keepEmpty = true, key = "g" .. g.id }
            byId[g.id] = sec
            sections[#sections + 1] = sec
        end
        local function Split(list)
            local rest = {}
            for _, b in ipairs(list) do
                local gid = ns.GroupOf(b.peonInfo)
                local sec = gid and byId[gid]
                if sec then table.insert(sec.items, b) else rest[#rest + 1] = b end
            end
            return rest
        end
        main = Split(main)
        local restExtra = {}
        for i, sec in ipairs(extra or {}) do
            restExtra[i] = { title = sec.title, items = Split(sec.items), key = sec.key }
        end
        extra = restExtra
        for _, sec in ipairs(sections) do
            table.sort(sec.items, SortItems)
            sec.title = #sec.items > 0 and sec.name or L.GROUP_EMPTY:format(sec.name)
        end
    end
    if layout == "type" or layout == "custom" then
        local groups, rest, anyCat = {}, {}, false
        for _, c in ipairs(ns.CATS) do
            groups[c] = {}
            if not catsOff[c] then anyCat = true end
        end
        for _, b in ipairs(main) do
            local cat = ns.Category(b.peonInfo, b.peonQuest, IsNew(b, cfg.keepNew), catsOff)
            if cat then table.insert(groups[cat], b) else rest[#rest + 1] = b end
        end
        for _, c in ipairs(ns.CatOrder()) do
            local g = groups[c]
            if g and #g > 0 then
                table.sort(g, SortItems)
                sections[#sections + 1] = { title = ns.CAT_TITLE[c], items = g, target = target, key = "c:" .. c }
            end
        end
        -- Uebrige: der Rest in Taschenreihenfolge, mit Ueberschrift nur, wenn es andere Abschnitte gibt
        sections[#sections + 1] = { title = (hasGroups or anyCat) and L.SEC_OTHER or nil, items = rest,
                                    target = target, keepEmpty = hasGroups, key = "other" }
    else
        sections[#sections + 1] = { title = nil, items = main, key = "other" }
    end
    for _, sec in ipairs(extra or {}) do
        local items = sec.items
        if layout ~= "classic" then
            items = {}
            for i, b in ipairs(sec.items) do items[i] = b end
            table.sort(items, SortItems)
        end
        sections[#sections + 1] = { title = sec.title, items = items, target = target, key = sec.key }
    end
    for _, sec in ipairs(sections) do
        if sec.title and sec.key and collapsed[sec.key] then sec.collapsed = true end
    end
    return sections
end

-- Plaetze einer Tasche (angelegt und aktualisiert); nil, wenn im Kampf noch nicht anlegbar
local function BagSlots(bag, parent, list, all)
    local n = ns.NumSlots(bag)
    local complete = true
    ns.BagFrame(bag, parent)
    for s = 1, n do
        local b = ns.Slot(bag, s, parent)
        if b then
            ns.UpdateSlot(b)
            list[#list + 1] = b
            all[#all + 1] = b
        else
            complete = false
        end
    end
    -- Plaetze, die es nicht mehr gibt (kleinere Tasche), ausblenden
    local old = ns.slots[bag]
    if old then
        for s, b in pairs(old) do
            if s > n then all[#all + 1] = b end
        end
    end
    return complete
end
ns.CollectBagSlots = BagSlots

local function UpdateFooter()
    if not w then return end
    local free, total = 0, 0
    for _, bag in ipairs(ns.BagIDs()) do
        free = free + ns.FreeSlots(bag)
        total = total + ns.NumSlots(bag)
    end
    local left = L.FREE:format(free, total)
    local rb = ns.ReagentBagID()
    local rn = rb and ns.NumSlots(rb) or 0
    if rn > 0 then left = left .. "   " .. L.FREE_REAGENT:format(ns.FreeSlots(rb), rn) end
    w:SetFooter(left, ns.Money(GetMoney and GetMoney() or 0))
end

local function UpdateBar()
    for _, bb in ipairs(barButtons) do bb:Refresh() end
end

local function Refresh()
    if not w then return end
    stale = false
    local main, all, extra = {}, {}, {}
    local complete = true
    for _, bag in ipairs(ns.BagIDs()) do
        if not BagSlots(bag, w.content, main, all) then complete = false end
    end
    local rb = ns.ReagentBagID()
    if rb and ns.NumSlots(rb) > 0 then
        local r = {}
        if not BagSlots(rb, w.content, r, all) then complete = false end
        extra[1] = { title = L.SEC_REAGENT, items = r, key = "reagent" }
    elseif rb then
        BagSlots(rb, w.content, {}, all)
    end
    if not complete then
        if not ns.queue["bags:refresh"] then mod:Print(L.MSG_COMBAT) end
        ns.Defer("bags:refresh", Refresh)
    end
    w:Arrange(ns.BuildSections(w:SectionConfig(), main, extra), all)
    UpdateFooter()
    UpdateBar()
end
ns.RefreshBags = Refresh

local function ForSlots(fn)
    for _, bag in ipairs(ns.BagIDs()) do
        for _, b in pairs(ns.slots[bag] or {}) do fn(b) end
    end
    local rb = ns.ReagentBagID()
    if rb then for _, b in pairs(ns.slots[rb] or {}) do fn(b) end end
end

---------------------------------------------------------------------------
-- Taschenleiste
---------------------------------------------------------------------------
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local BACKPACK_TEX = "Interface\\Buttons\\Button-Backpack-Up"

local function InvID(bag)
    if bag == 0 then return nil end
    local id = ns.Try(ns.C().ContainerIDToInventoryID, bag)
    if ns.Num(id) then return id end
    local f = rawget(_G, "ContainerIDToInventoryID")
    id = ns.Try(f, bag)
    return ns.Num(id) and id or nil
end

local function NewBarButton(parent, bag, x, forSlots)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(24, 24)
    b:SetPoint("LEFT", parent, "LEFT", x, 0)
    b.bag = bag
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    function b:Refresh()
        if self.bag == 0 then self.icon:SetTexture(BACKPACK_TEX) return end
        local inv = InvID(self.bag)
        local tex = inv and GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
        self.icon:SetTexture(tex or EMPTY_BAG)
    end
    local function Drop(self)
        if self.bag == 0 then
            if PutItemInBackpack then PutItemInBackpack() end
        else
            local inv = InvID(self.bag)
            if inv and PutItemInBag then PutItemInBag(inv) end
        end
    end
    b:SetScript("OnClick", function(self)
        if CursorHasItem and CursorHasItem() then Drop(self)
        elseif self.bag ~= 0 then
            local inv = InvID(self.bag)
            if inv and PickupBagFromSlot then PickupBagFromSlot(inv) end
        end
    end)
    b:SetScript("OnDragStart", function(self)
        local inv = InvID(self.bag)
        if inv and PickupBagFromSlot then PickupBagFromSlot(inv) end
    end)
    b:SetScript("OnReceiveDrag", Drop)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local inv = InvID(self.bag)
        local has = inv and GameTooltip.SetInventoryItem and GameTooltip:SetInventoryItem("player", inv)
        if not has then
            GameTooltip:SetText(self.bag == 0 and L.BACKPACK or L.EMPTY_BAG, 1, 1, 1)
        end
        GameTooltip:Show()
        ns.focusBag = self.bag
        forSlots(ns.UpdateMatch)
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ns.focusBag = nil
        forSlots(ns.UpdateMatch)
    end)
    b:Refresh()
    return b
end
ns.NewBarButton, ns.InvID = NewBarButton, InvID

local function BuildBar()
    local x = 0
    local ids = ns.BagIDs()
    local rb = ns.ReagentBagID()
    if rb then ids[#ids + 1] = rb end
    for _, bag in ipairs(ids) do
        barButtons[#barButtons + 1] = NewBarButton(w.bar, bag, x, ForSlots)
        x = x + 26
    end
    w.bar:SetWidth(math.max(1, x))
end

---------------------------------------------------------------------------
-- Oeffnen / Schliessen
---------------------------------------------------------------------------
function ns.ShowBags() if w then w:Show() end end
function ns.HideBags() if w then w:Hide() end end
function ns.ToggleBags() if w then autoOpened = nil; w:Toggle() end end

-- Aufrufe aus Blizzards Taschen-Funktionen, die nur intern weitergereicht werden, nicht doppelt zaehlen
local function Stack()
    local ok, s = pcall(debugstack)
    if not ok or Peon.IsSecret(s) then return "" end   -- geheimer Text (Kampf/Instanz) darf nicht durchsucht werden
    return type(s) == "string" and s or ""
end

local hooked = false
local function HookToggles()
    if hooked then return end
    hooked = true
    if type(rawget(_G, "ToggleAllBags")) == "function" then
        hooksecurefunc("ToggleAllBags", function()
            if ns.Replacing() and not Stack():find("Manager") then ns.ToggleBags() end
        end)
    end
    if type(rawget(_G, "ToggleBackpack")) == "function" then
        hooksecurefunc("ToggleBackpack", function()
            if not ns.Replacing() then return end
            local s = Stack()
            if not s:find("ToggleAllBags") and not s:find("Manager") then ns.ToggleBags() end
        end)
    end
    if type(rawget(_G, "ToggleBag")) == "function" then
        hooksecurefunc("ToggleBag", function(bag)
            if not ns.Replacing() or not ns.IsInventoryBag(bag) then return end
            local s = Stack()
            if not s:find("OpenBackpack") and not s:find("ToggleBackpack") and not s:find("ToggleAllBags") and not s:find("Manager") then
                ns.ToggleBags()
            end
        end)
    end
end

-- Blizzards Taschenfenster unsichtbar machen (umhaengen in einen versteckten Rahmen), nichts ersetzen
local hiddenParent
local origParent = {}
local function Hide(frame)
    if not frame or frame:GetParent() == hiddenParent then return end
    if ns.Locked(frame) then ns.Defer("hide:" .. tostring(frame), function() Hide(frame) end) return end
    origParent[frame] = frame:GetParent()
    frame:SetParent(hiddenParent)
end
local function Unhide(frame)
    if not frame or frame:GetParent() ~= hiddenParent then return end
    if ns.Locked(frame) then ns.Defer("unhide:" .. tostring(frame), function() Unhide(frame) end) return end
    frame:SetParent(origParent[frame] or rawget(_G, "ContainerFrameContainer") or UIParent)
end

local function ContainerFrames()
    local list = {}
    local n = tonumber(rawget(_G, "NUM_CONTAINER_FRAMES")) or 13
    for i = 1, n do
        local f = rawget(_G, "ContainerFrame" .. i)
        if f then list[#list + 1] = f end
    end
    return list
end

local function CheckFrame(frame)
    local ok, bag = pcall(frame.GetID, frame)
    local mine = ok and (ns.IsInventoryBag(bag) or (ns.IsBankBag(bag) and bag ~= 0))
    if ns.Replacing() and mine then Hide(frame) else Unhide(frame) end
end

local function HookFrames()
    hiddenParent = CreateFrame("Frame")
    hiddenParent:Hide()
    for _, f in ipairs(ContainerFrames()) do
        if f.SetID then hooksecurefunc(f, "SetID", function(self) CheckFrame(self) end) end
    end
    local comb = rawget(_G, "ContainerFrameCombinedBags")
    if comb and comb.HookScript then
        comb:HookScript("OnShow", function(self) if ns.Replacing() then Hide(self) end end)
    end
end

-- Hauptschalter geaendert: Blizzards Fenster wieder freigeben bzw. verstecken
function ns.UpdateReplace()
    if not hiddenParent then return end
    for _, f in ipairs(ContainerFrames()) do CheckFrame(f) end
    local comb = rawget(_G, "ContainerFrameCombinedBags")
    if comb then if ns.Replacing() then Hide(comb) else Unhide(comb) end end
    if ns.UpdateReplaceBank then ns.UpdateReplaceBank() end
    if ns.UpdateReplaceGuild then ns.UpdateReplaceGuild() end
end

-- automatisch oeffnen
local AUTO = {
    { "Merchant", 5, "autoMerchant" }, { "Banker", 8, "autoBank" }, { "MailInfo", 17, "autoMail" },
    { "Auctioneer", 21, "autoAuction" }, { "TradePartner", 1, "autoTrade" }, { "GuildBanker", 10, "autoGuild" },
}
local function AutoKey(kind)
    for _, a in ipairs(AUTO) do
        if ns.PIT(a[1], a[2]) == kind then return a[3] end
    end
end

local function OnInteractShow(kind)
    if not ns.Replacing() then return end
    local key = AutoKey(kind)
    if key and mod.db[key] and w and not w:IsShown() then
        w:Show()
        autoOpened = kind
    end
end

local function OnInteractHide(kind)
    if autoOpened and autoOpened == kind and w then
        autoOpened = nil
        w:Hide()
    end
end
ns.OnInteractShow, ns.OnInteractHide = OnInteractShow, OnInteractHide

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
function ns.InitInventory()
    w = ns.NewWindow("bag", {
        title = L.TITLE_BAGS,
        template = "PortraitFrameFlatTemplate", portrait = "Interface\\Icons\\INV_Misc_Bag_08", portraitSize = 36,
        border = "HeldBagLayout",
        point = { "BOTTOMRIGHT", -60, 100 },
        onShow = function() Refresh() end,
        onHide = function() autoOpened = nil end,
    })
    local name = UnitName and UnitName("player")
    if name then w.title:SetText(name .. " – " .. L.TITLE_BAGS) end
    w.useGroups = true
    local C = ns.C()
    if type(C.SortBags) == "function" then
        w.sortBtn = w:AddButton(L.BTN_SORT, 80, L.BTN_SORT_TIP, function()
            if not InCombatLockdown() then pcall(C.SortBags) end
        end)
    end
    w:AddSetupButton()
    BuildBar()
    w.OnSearch = function()
        if w.search and w.search:GetText() ~= ns.searchRaw then w.search:SetText(ns.searchRaw or "") end
        ForSlots(ns.UpdateMatch)
    end
    w.Apply = function()
        w:ApplyPosition()
        w.bar:SetShown(mod.db.bagBar and true or false)
        if w:IsShown() then Refresh() else stale = true end
    end
    w.Apply()

    -- Knoepfe gleich anlegen (nicht erst beim ersten Oeffnen im Kampf)
    if not InCombatLockdown() then
        local main, all = {}, {}
        for _, bag in ipairs(ns.BagIDs()) do BagSlots(bag, w.content, main, all) end
        local rb = ns.ReagentBagID()
        if rb then BagSlots(rb, w.content, main, all) end
        for _, b in ipairs(all) do b:Hide() end
    end

    HookToggles()
    HookFrames()
    ns.UpdateReplace()

    local dirty = {}
    mod:RegisterEvent("BAG_UPDATE", function(_, bag) if ns.Num(bag) then dirty[bag] = true end end)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if mod.launcher then mod.launcher:Refresh() end
        local any = false
        for bag in pairs(dirty) do if ns.IsInventoryBag(bag) then any = true end end
        wipe(dirty)
        if any or stale then
            if w:IsShown() then Refresh() else stale = true end
        end
    end)
    mod:RegisterEvent("ITEM_LOCK_CHANGED", function(_, bag, slot)
        if not w:IsShown() or not ns.Num(bag) or not ns.Num(slot) then return end
        local b = ns.slots[bag] and ns.slots[bag][slot]
        if b then ns.UpdateSlot(b) end
    end)
    mod:RegisterEvent("BAG_UPDATE_COOLDOWN", function()
        if w:IsShown() then ForSlots(ns.UpdateCooldown) end
    end)
    local function RefreshIfShown() if w:IsShown() then Refresh() else stale = true end end
    for _, e in ipairs({ "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED", "QUEST_REMOVED", "BAG_CONTAINER_UPDATE",
                         "BAG_SLOT_FLAGS_UPDATED", "PLAYER_EQUIPMENT_CHANGED" }) do
        pcall(mod.RegisterEvent, mod, e, RefreshIfShown)
    end
    mod:RegisterEvent("PLAYER_MONEY", function() if w:IsShown() then UpdateFooter() end end)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind) OnInteractShow(kind) end)
    pcall(mod.RegisterEvent, mod, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind) OnInteractHide(kind) end)
    mod:Dbg("Taschenfenster bereit, ersetzen = " .. tostring(ns.Replacing()))
end
