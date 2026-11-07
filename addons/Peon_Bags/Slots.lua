-- Peon_Bags - Slots.lua
-- Plaetze der Taschen und Bank: Blizzards Taschenknoepfe (ContainerFrameItemButtonTemplate) in einem
-- kleinen Rahmen je Tasche (Rahmen-ID = Taschennummer, Knopf-ID = Platznummer). Klicks, Benutzen, Ziehen,
-- Stapel teilen und Tooltip erledigt Blizzards Code. Hier: Anlegen und Aussehen (Symbol, Anzahl, Qualitaet,
-- neu, Quest, Muell, Abklingzeit, gesperrt, Suche).

local ADDON_NAME, ns = ...
local mod = ns.mod
if not mod then return end

ns.bagFrames = {}   -- [Tasche] = Rahmen (ID = Tasche)
ns.slots = {}       -- [Tasche] = { [Platz] = Knopf }
local count = 0

-- Rahmen je Tasche (Eltern der Knoepfe). Ein Fenster kann den Rahmen spaeter zu sich holen.
function ns.BagFrame(bag, parent)
    local f = ns.bagFrames[bag]
    if not f then
        f = CreateFrame("Frame", nil, parent or UIParent)
        f:SetID(bag)
        f:SetSize(1, 1)
        ns.bagFrames[bag] = f
    elseif parent and f:GetParent() ~= parent then
        f:SetParent(parent)
    end
    f:ClearAllPoints()
    f:SetAllPoints(parent or UIParent)
    return f
end

local function NewButton(bag, slot, parent)
    count = count + 1
    local name = "PeonBagsItem" .. count
    local b
    local ok = pcall(function() b = CreateFrame("ItemButton", name, parent, "ContainerFrameItemButtonTemplate") end)
    if not ok or not b then
        ok = pcall(function() b = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate") end)
    end
    if not ok or not b then return nil end
    -- Blizzard-Skripte, die ein Blizzard-Taschenfenster als Eltern erwarten, abschalten (eigener Knopf)
    b:SetScript("OnEvent", nil)
    b:SetScript("OnShow", nil)
    b:SetID(slot)
    if b.SetBagID then pcall(b.SetBagID, b, bag) end
    b.peonBag, b.peonSlot = bag, slot
    b.Cooldown = b.Cooldown or _G[name .. "Cooldown"]
    b.QuestTex = b.IconQuestTexture or _G[name .. "IconQuestTexture"]
    if b.BattlepayItemTexture then b.BattlepayItemTexture:Hide() end
    b.UpdateTooltip = b.UpdateTooltip or b:GetScript("OnEnter")
    -- neu: beim Ueberfahren als gesehen markieren
    b:HookScript("OnEnter", function(self)
        local CN = rawget(_G, "C_NewItems")
        if self.peonIsNew and CN and CN.RemoveNewItem then
            pcall(CN.RemoveNewItem, self.peonBag, self.peonSlot)
            ns.UpdateSlot(self)
        end
    end)
    return b
end

-- Knopf fuer Tasche/Platz holen oder anlegen (nil im Kampf, wenn das Anlegen dort nicht geht)
function ns.Slot(bag, slot, parent)
    local list = ns.slots[bag]
    if not list then list = {}; ns.slots[bag] = list end
    local b = list[slot]
    if b then return b end
    if InCombatLockdown() and not ns.allowCombatCreate then return nil end
    b = NewButton(bag, slot, ns.BagFrame(bag, parent))
    list[slot] = b
    return b
end

local function Tex(b, ...) local f = rawget(_G, "SetItemButtonTexture") if f then pcall(f, b, ...) elseif b.icon then b.icon:SetTexture(...) end end
local function Cnt(b, ...) local f = rawget(_G, "SetItemButtonCount") if f then pcall(f, b, ...) end end
local function Desat(b, v) local f = rawget(_G, "SetItemButtonDesaturated") if f then pcall(f, b, v) end end
local function TexColor(b, r, g, bl) local f = rawget(_G, "SetItemButtonTextureVertexColor") if f then pcall(f, b, r, g, bl) end end

local EMPTY_TEX = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

-- Aussehen eines Platzes aktualisieren
function ns.UpdateSlot(b)
    if not b then return end
    local db = mod.db
    local bag, slot = b.peonBag, b.peonSlot
    local info = ns.ItemInfo(bag, slot)
    b.peonInfo = info
    b.hasItem = info and true or nil        -- fuer Blizzards Vorlage
    b.readable = info and info.isReadable or nil

    Tex(b, info and info.iconFileID or EMPTY_TEX)
    Cnt(b, info and info.stackCount or 0)
    Desat(b, info and info.isLocked or false)

    -- Qualitaet
    local quality = info and info.quality
    local SQ = rawget(_G, "SetItemButtonQuality")
    if db.quality and info and SQ then
        pcall(SQ, b, quality, info.hyperlink, false, info.isBound)
    elseif SQ then
        pcall(SQ, b, nil)
    end
    if b.IconBorder and not db.quality then b.IconBorder:Hide() end

    -- Quest
    local questInfo = info and ns.Try(ns.C().GetContainerItemQuestInfo, bag, slot)
    local isQuest = type(questInfo) == "table" and (questInfo.isQuestItem or questInfo.questID) and true or false
    if b.QuestTex then
        if isQuest then
            local tex = (questInfo.questID and not questInfo.isActive) and rawget(_G, "TEXTURE_ITEM_QUEST_BANG")
                or rawget(_G, "TEXTURE_ITEM_QUEST_BORDER")
            if tex then b.QuestTex:SetTexture(tex) end
            b.QuestTex:Show()
        else
            b.QuestTex:Hide()
        end
    end
    b.peonQuest = isQuest

    -- Muell
    local junk = info and quality == 0 and not info.hasNoValue
    if b.JunkIcon then b.JunkIcon:SetShown(db.junk and junk and true or false) end
    if db.junk and junk and not info.isLocked then TexColor(b, 0.6, 0.6, 0.6)
    elseif not (info and info.isLocked) then TexColor(b, 1, 1, 1) end

    -- neu
    local CN = rawget(_G, "C_NewItems")
    b.peonIsNew = info and CN and ns.Try(CN.IsNewItem, bag, slot) and true or false   -- Kategorie "Neu" (ab 0.5)
    local isNew = b.peonIsNew and db.newGlow and true or false
    b.peonNew = isNew
    if b.NewItemTexture then
        if isNew then
            local atlas = rawget(_G, "NEW_ITEM_ATLAS_BY_QUALITY")
            local a = type(atlas) == "table" and quality and atlas[quality] or "bags-glow-white"
            pcall(b.NewItemTexture.SetAtlas, b.NewItemTexture, a)
            b.NewItemTexture:Show()
            if b.flashAnim and not b.flashAnim:IsPlaying() then pcall(b.flashAnim.Play, b.flashAnim) end
            if b.newitemglowAnim and not b.newitemglowAnim:IsPlaying() then pcall(b.newitemglowAnim.Play, b.newitemglowAnim) end
        else
            b.NewItemTexture:Hide()
            if b.flashAnim and b.flashAnim:IsPlaying() then pcall(b.flashAnim.Stop, b.flashAnim) end
            if b.newitemglowAnim and b.newitemglowAnim:IsPlaying() then pcall(b.newitemglowAnim.Stop, b.newitemglowAnim) end
        end
    end

    ns.UpdateCooldown(b)
    ns.UpdateMatch(b)
end

function ns.UpdateCooldown(b)
    if not b or not b.Cooldown then return end
    local start, duration, enable = 0, 0, 0
    if b.hasItem then
        start, duration, enable = ns.Try(ns.C().GetContainerItemCooldown, b.peonBag, b.peonSlot)
    end
    local CF = rawget(_G, "CooldownFrame_Set")
    if CF then pcall(CF, b.Cooldown, start or 0, duration or 0, enable or 0) end
end

-- Suche und Hervorhebung einer Tasche (Taschenleiste)
function ns.UpdateMatch(b)
    local alpha = 1
    if ns.search ~= "" and not ns.Matches(b.peonInfo) then alpha = 0.3 end
    if ns.focusBag and b.peonBag ~= ns.focusBag then alpha = 0.3 end
    b:SetAlpha(alpha)
end
