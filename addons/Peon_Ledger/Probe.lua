-- Peon_Ledger - Probe.lua
-- Pruefbefehl (Bauabschnitt L1, Konzept Peon_Ledger_Konzept.md Abschnitt 3): stellt fest, welche Funktionen und
-- Ereignisse des Spiels Ledger fuer Bestand und Buch nutzen kann. Alles nur lesend: nichts wird genommen, gekauft,
-- verkauft, verschickt oder zerstoert.
--   /ledger pruefen          -> Funktionen, Texte, Charakter; dazu das gerade offene Fenster
--   automatisch              -> Postfach, Haendler, Bank, Handel, Beruf, Beute, Quest-Belohnung, Flugmeister, Lehrer
--                               werden die ersten 3 Male beim Oeffnen mitgelesen (Schnappschuss)
--   Ereignisse               -> je Ereignis Anzahl, Zeit und die ersten 3 Werte
--   Mitlesen von Aufrufen    -> z. B. Haendlerkauf, Zerstoeren, Benutzen, Post verschicken (nur zaehlen, nach dem Aufruf)
-- Ergebnis in PeonLedgerDB.probe, .probeEvents, .probeHooks, .probeSnaps (nach /reload im WTF-Ordner lesbar).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Probe = P

P.SNAPS_MAX = 3        -- Schnappschuesse je Fenster
P.LIST_MAX  = 8        -- so viele Eintraege je Liste (Briefe, Haendlerwaren, Rezepte ...)

---------------------------------------------------------------------------
-- Was geprueft wird
---------------------------------------------------------------------------
-- Funktionen je Bereich: "Name" (global) oder "C_Ns.Name"
P.FUNCS = {
    { "GROUP_CONTAINER", { "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "C_Container.GetContainerItemLink",
        "C_Container.GetContainerItemID", "C_Container.ContainerIDToInventoryID", "C_Container.GetBagName", "C_Container.UseContainerItem",
        "C_Container.PickupContainerItem", "C_Container.GetItemCooldown", "C_Item.GetItemCount", "C_Item.GetItemInfo", "C_Item.GetItemSpell",
        "C_Item.IsItemDataCachedByID", "C_Item.RequestLoadItemDataByID", "C_Bank.FetchPurchasedBankTabData", "GetNumBankSlots",
        "IsReagentBankUnlocked" } },
    { "GROUP_INVENTORY", { "GetInventoryItemLink", "GetInventoryItemID", "GetInventoryItemCount", "GetInventorySlotInfo", "GetMoney" } },
    { "GROUP_MAIL", { "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxInvoiceInfo", "GetInboxItem", "GetInboxItemLink", "GetInboxText",
        "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem", "DeleteInboxItem", "CheckInbox", "SendMail", "SetSendMailMoney",
        "GetSendMailMoney", "GetSendMailPrice", "GetSendMailItem", "GetSendMailItemLink", "C_Mail.HasInboxMoney", "C_Mail.CanCheckInbox",
        "C_Mail.IsCommandPending" } },
    { "GROUP_MERCHANT", { "GetMerchantNumItems", "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantItemMaxStack", "BuyMerchantItem",
        "GetNumBuybackItems", "GetBuybackItemInfo", "GetBuybackItemLink", "BuybackItem", "CanMerchantRepair", "GetRepairAllCost",
        "RepairAllItems", "C_MerchantFrame.GetBuybackItemID", "C_MerchantFrame.IsMerchantItemRefundable" } },
    { "GROUP_TRADE", { "GetTradePlayerItemInfo", "GetTradePlayerItemLink", "GetTradeTargetItemInfo", "GetTradeTargetItemLink",
        "GetPlayerTradeMoney", "GetTargetTradeMoney", "AcceptTrade" } },
    { "GROUP_SKILL", { "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillItemLink", "GetTradeSkillRecipeLink", "GetTradeSkillNumMade",
        "GetTradeSkillNumReagents", "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink", "GetTradeSkillLine", "DoTradeSkill",
        "GetNumCrafts", "GetCraftInfo", "GetCraftItemLink", "GetCraftNumReagents", "GetCraftReagentInfo", "GetCraftReagentItemLink",
        "GetCraftDisplaySkillLine", "DoCraft", "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo",
        "C_TradeSkillUI.GetRecipeSchematic", "C_TradeSkillUI.CraftRecipe", "C_TradeSkillUI.GetTradeSkillLine",
        "C_TradeSkillUI.GetBaseProfessionInfo", "C_Spell.GetSpellInfo", "GetSpellInfo" } },
    { "GROUP_LOOT", { "GetNumLootItems", "GetLootSlotInfo", "GetLootSlotLink", "GetLootSlotType", "GetLootInfo", "LootSlot",
        "IsFishingLoot" } },
    { "GROUP_QUEST", { "GetNumQuestRewards", "GetNumQuestChoices", "GetQuestItemLink", "GetQuestItemInfo", "GetRewardMoney",
        "GetQuestLogRewardMoney", "GetTitleText", "C_QuestLog.GetTitleForQuestID" } },
    { "GROUP_OTHER", { "DeleteCursorItem", "CursorHasItem", "GetCursorInfo", "TakeTaxiNode", "TaxiNodeCost", "NumTaxiNodes",
        "BuyTrainerService", "GetTrainerServiceCost", "GetNumTrainerServices", "UseItemByName", "GetRealmName", "UnitName",
        "UnitFactionGroup", "C_DateAndTime.GetServerTimeLocal" } },
}

-- Ereignisse (unbekannte weist das Spiel ab - dann "unbekannt")
P.EVENTS = {
    "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_NEW_ITEMS_UPDATED", "ITEM_PUSH", "ITEM_LOCK_CHANGED",
    "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "PLAYER_MONEY", "PLAYER_EQUIPMENT_CHANGED",
    "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_SEND_INFO_UPDATE", "MAIL_FAILED",
    "CLOSE_INBOX_ITEM", "UPDATE_PENDING_MAIL",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE",
    "TRADE_SHOW", "TRADE_CLOSED", "TRADE_ACCEPT_UPDATE", "TRADE_MONEY_CHANGED", "TRADE_PLAYER_ITEM_CHANGED",
    "TRADE_TARGET_ITEM_CHANGED", "TRADE_REQUEST_CANCEL", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_CLOSE", "CRAFT_UPDATE", "NEW_RECIPE_LEARNED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "LOOT_OPENED", "LOOT_READY", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_SYSTEM",
    "QUEST_COMPLETE", "QUEST_TURNED_IN", "QUEST_FINISHED", "QUEST_LOOT_RECEIVED",
    "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED", "DELETE_ITEM_CONFIRM",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED",
    "AUCTION_CANCELED", "COMMODITY_PURCHASE_SUCCEEDED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

-- Texte, an denen spaeter Beute, Herstellen, Quests und Auktions-Post erkannt werden
P.STRINGS = {
    "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY", "LOOT_MONEY",
    "ERR_QUEST_REWARD_MONEY_S", "ERR_QUEST_REWARD_ITEM_S", "ERR_QUEST_REWARD_ITEM_MULT_IS",
    "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT", "AUCTION_WON_MAIL_SUBJECT",
    "AUCTION_OUTBID_MAIL_SUBJECT", "AUCTION_INVOICE_MAIL_SUBJECT", "ERR_AUCTION_SOLD_S",
    "ERR_TRADE_COMPLETE", "ERR_TRADE_CANCELLED", "ERR_MAIL_SENT", "ERR_ITEM_MAX_COUNT", "ERR_INV_FULL",
    "DELETE_ITEM", "DELETE_GOOD_ITEM", "REPAIR_COST", "BANK_CONTAINER", "BACKPACK_CONTAINER", "KEYRING_CONTAINER",
    "REAGENTBANK_CONTAINER", "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS", "NUM_BANKBAGSLOTS", "NUM_BANKGENERIC_SLOTS",
    "INVSLOT_FIRST_EQUIPPED", "INVSLOT_LAST_EQUIPPED",
}

-- Aufrufe mitlesen (hooksecurefunc: erst nach dem Aufruf, aendert nichts)
P.HOOKS = {
    "BuyMerchantItem", "BuybackItem", "RepairAllItems", "DeleteCursorItem", "UseItemByName", "SendMail",
    "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem", "TakeTaxiNode", "BuyTrainerService", "DoTradeSkill", "DoCraft",
    "C_Container.UseContainerItem", "C_Container.PickupContainerItem", "C_TradeSkillUI.CraftRecipe", "AcceptTrade",
}

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
-- Wert sicher als Text (geheime Werte werden nicht angefasst)
local function Str(v)
    if Peon.IsSecret(v) then return "<geheim>" end
    if type(v) == "table" then
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..."; break end
            local xs = (Peon.IsSecret(x) and "<geheim>") or (type(x) == "table" and "<table>") or tostring(x)
            parts[#parts + 1] = tostring(k) .. "=" .. xs
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end
P.Str = Str

-- Funktion zu einem Namen ("Name" oder "C_Ns.Name")
local function Lookup(name)
    local ns2, fn = name:match("^(C_[%w_]+)%.(.+)$")
    if ns2 then
        local t = rawget(_G, ns2)
        return type(t) == "table" and t[fn] or nil, t, fn
    end
    return rawget(_G, name), _G, name
end
P.Lookup = Lookup

-- Aufruf mit allen Rueckgabewerten als Text; Fehler als Text
local function Try(fn, ...)
    if type(fn) ~= "function" then return "fehlt" end
    local r = { pcall(fn, ...) }
    if not r[1] then return "Fehler: " .. Str(r[2]) end
    local out = {}
    for i = 2, table.maxn(r) do out[#out + 1] = Str(r[i]) end
    return table.concat(out, " | ")
end
P.Try = Try

local function F(name) return (Lookup(name)) end

-- Wert einer Funktion als Zahl (oder nil)
local function Num(name, ...)
    local fn = F(name)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and type(v) == "number" and not Peon.IsSecret(v) then return v end
    return nil
end

---------------------------------------------------------------------------
-- Ereignisse mitzaehlen, Aufrufe mitlesen, Fenster automatisch lesen
---------------------------------------------------------------------------
local frame
function P.Init()
    local acc = mod.acc
    acc.probeEvents = type(acc.probeEvents) == "table" and acc.probeEvents or {}
    acc.probeHooks = type(acc.probeHooks) == "table" and acc.probeHooks or {}
    acc.probeSnaps = type(acc.probeSnaps) == "table" and acc.probeSnaps or {}
    if frame then return end
    frame = CreateFrame("Frame")
    for _, ev in ipairs(P.EVENTS) do
        local ok = pcall(frame.RegisterEvent, frame, ev)
        local e = acc.probeEvents[ev]
        if type(e) ~= "table" then e = { count = 0, samples = {} }; acc.probeEvents[ev] = e end
        e.known = ok and true or false
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        mod:Call("Ereignis " .. event, P.OnEvent, event, ...)
    end)
    -- Aufrufe mitlesen
    if hooksecurefunc then
        for _, name in ipairs(P.HOOKS) do
            local fn, tbl, key = Lookup(name)
            local h = acc.probeHooks[name]
            if type(h) ~= "table" then h = { count = 0, samples = {} }; acc.probeHooks[name] = h end
            h.exists = type(fn) == "function"
            if h.exists then
                local ok = pcall(function()
                    if tbl == _G then
                        hooksecurefunc(key, function(...) P.OnHook(name, ...) end)
                    else
                        hooksecurefunc(tbl, key, function(...) P.OnHook(name, ...) end)
                    end
                end)
                h.hooked = ok and true or false
            end
        end
    end
end

function P.OnHook(name, ...)
    local h = mod.acc.probeHooks[name]
    if not h then return end
    h.count = (h.count or 0) + 1
    h.last = date("%Y-%m-%d %H:%M:%S")
    if #h.samples < 3 then
        local args = {}
        for i = 1, math.min(select("#", ...), 6) do args[#args + 1] = Str((select(i, ...))) end
        h.samples[#h.samples + 1] = table.concat(args, ", ")
    end
    mod:Dbg("Aufruf " .. name)
end

-- Fenster, die automatisch gelesen werden (Ereignis -> Kontext, Verzoegerung in Sek.)
P.CONTEXT_EVENTS = {
    MAIL_SHOW = { "mail", 1.0 }, MERCHANT_SHOW = { "merchant", 0.5 }, BANKFRAME_OPENED = { "bank", 0.5 },
    TRADE_ACCEPT_UPDATE = { "trade", 0.1 }, TRADE_SKILL_SHOW = { "skill", 0.5 }, CRAFT_SHOW = { "craft", 0.5 },
    LOOT_OPENED = { "loot", 0 }, QUEST_COMPLETE = { "quest", 0.2 }, TAXIMAP_OPENED = { "taxi", 0.2 }, TRAINER_SHOW = { "trainer", 0.5 },
}

P.open = {}   -- welche Fenster gerade offen sind
local CLOSE = { MAIL_CLOSED = "mail", MERCHANT_CLOSED = "merchant", BANKFRAME_CLOSED = "bank", TRADE_CLOSED = "trade",
                TRADE_SKILL_CLOSE = "skill", CRAFT_CLOSE = "craft", LOOT_CLOSED = "loot", QUEST_FINISHED = "quest",
                TAXIMAP_CLOSED = "taxi", TRAINER_CLOSED = "trainer" }

function P.OnEvent(event, ...)
    local e = mod.acc.probeEvents[event]
    local unit = ...
    -- Zauber-Ereignisse kommen fuer alle Einheiten: nur die eigenen zaehlen
    if event:find("^UNIT_SPELLCAST") and (Peon.IsSecret(unit) or unit ~= "player") then return end
    if e then
        e.count = (e.count or 0) + 1
        e.last = date("%Y-%m-%d %H:%M:%S")
        e.samples = type(e.samples) == "table" and e.samples or {}
        if #e.samples < 3 then
            local args = {}
            for i = 1, math.min(select("#", ...), 6) do args[#args + 1] = Str((select(i, ...))) end
            e.samples[#e.samples + 1] = table.concat(args, ", ")
        end
    end
    mod:Dbg(event)
    local c = P.CONTEXT_EVENTS[event]
    if c then
        P.open[c[1]] = true
        if C_Timer and c[2] > 0 then
            C_Timer.After(c[2], function() mod:Call("Pruefung", P.AutoSnap, c[1]) end)
        else
            P.AutoSnap(c[1])
        end
    elseif CLOSE[event] then
        P.open[CLOSE[event]] = nil
    elseif event == "TRADE_SHOW" then
        P.open.trade = true
    end
end

-- Schnappschuss eines Fensters, die ersten P.SNAPS_MAX Male
function P.AutoSnap(kind)
    local snaps = mod.acc.probeSnaps
    snaps[kind] = type(snaps[kind]) == "table" and snaps[kind] or {}
    if #snaps[kind] >= P.SNAPS_MAX then return end
    local s = P.Snap(kind)
    if not s then return end
    snaps[kind][#snaps[kind] + 1] = s
    mod:Dbg("Schnappschuss " .. kind)
    if #snaps[kind] == 1 then mod:Print(L.P_AUTO:format(L["CTX_" .. kind:upper()] or kind)) end
end

---------------------------------------------------------------------------
-- Schnappschuesse (nur lesend)
---------------------------------------------------------------------------
P.SNAP = {}

function P.Snap(kind)
    local fn = P.SNAP[kind]
    if not fn then return nil end
    local s = { kind = kind, time = date("%Y-%m-%d %H:%M:%S"), char = ns.CharName() }
    local ok, err = pcall(fn, s)
    if not ok then s.error = Str(err) end
    return s
end

-- Taschen: Anzahl Taschen, Plaetze, belegte Plaetze, ein Beispiel-Eintrag
function P.SNAP.bags(s, first, last)
    local C = rawget(_G, "C_Container")
    s.bags = {}
    if not C then s.error = "C_Container fehlt"; return end
    for bag = first or 0, last or (tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4) do
        local okn, n = pcall(C.GetContainerNumSlots, bag)
        n = okn and tonumber(n) or 0
        local used, sample = 0, nil
        for slot = 1, n do
            local oki, info = pcall(C.GetContainerItemInfo, bag, slot)
            if oki and type(info) == "table" then
                used = used + 1
                if not sample then sample = Str(info) end
            end
        end
        s.bags[#s.bags + 1] = ("Tasche %d: %d Plaetze, %d belegt%s"):format(bag, n, used, sample and (", z. B. " .. sample) or "")
    end
end

function P.SNAP.bank(s)
    s.bankContainer = Str(rawget(_G, "BANK_CONTAINER"))
    s.numBankSlots = Try(F("GetNumBankSlots"))
    local bank = tonumber(rawget(_G, "BANK_CONTAINER")) or -1
    local sub = {}
    P.SNAP.bags(sub, bank, bank)
    s.main = sub.bags
    local first = (tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4) + 1
    local count = tonumber(rawget(_G, "NUM_BANKBAGSLOTS")) or 6
    local sub2 = {}
    P.SNAP.bags(sub2, first, first + count - 1)
    s.bankBags = sub2.bags
    local reagent = tonumber(rawget(_G, "REAGENTBANK_CONTAINER"))
    if reagent then local sub3 = {}; P.SNAP.bags(sub3, reagent, reagent); s.reagent = sub3.bags end
end

function P.SNAP.mail(s)
    s.num = Try(F("GetInboxNumItems"))
    local n = Num("GetInboxNumItems") or 0
    s.letters = {}
    for i = 1, math.min(n, P.LIST_MAX) do
        local l = { header = Try(F("GetInboxHeaderInfo"), i), invoice = Try(F("GetInboxInvoiceInfo"), i) }
        l.item1 = Try(F("GetInboxItem"), i, 1)
        l.link1 = Try(F("GetInboxItemLink"), i, 1)
        s.letters[#s.letters + 1] = l
    end
    s.hasMoney = Try(F("C_Mail.HasInboxMoney"), 1)
end

function P.SNAP.merchant(s)
    s.num = Try(F("GetMerchantNumItems"))
    local n = Num("GetMerchantNumItems") or 0
    s.items = {}
    for i = 1, math.min(n, 3) do
        s.items[#s.items + 1] = Try(F("GetMerchantItemInfo"), i) .. " · " .. Try(F("GetMerchantItemLink"), i)
    end
    s.canRepair = Try(F("CanMerchantRepair"))
    s.repairCost = Try(F("GetRepairAllCost"))
    s.buyback = Try(F("GetNumBuybackItems"))
    if (Num("GetNumBuybackItems") or 0) > 0 then
        s.buyback1 = Try(F("GetBuybackItemInfo"), 1) .. " · " .. Try(F("GetBuybackItemLink"), 1)
    end
end

function P.SNAP.trade(s)
    s.player, s.target = {}, {}
    for i = 1, 7 do
        local p = Try(F("GetTradePlayerItemLink"), i)
        if p ~= "nil" and p ~= "" then s.player[#s.player + 1] = i .. ": " .. Try(F("GetTradePlayerItemInfo"), i) .. " · " .. p end
        local t = Try(F("GetTradeTargetItemLink"), i)
        if t ~= "nil" and t ~= "" then s.target[#s.target + 1] = i .. ": " .. Try(F("GetTradeTargetItemInfo"), i) .. " · " .. t end
    end
    s.playerMoney = Try(F("GetPlayerTradeMoney"))
    s.targetMoney = Try(F("GetTargetTradeMoney"))
end

function P.SNAP.skill(s)
    s.line = Try(F("GetTradeSkillLine"))
    s.num = Try(F("GetNumTradeSkills"))
    local n = Num("GetNumTradeSkills") or 0
    s.recipes = {}
    for i = 1, n do
        if #s.recipes >= 3 then break end
        local info = Try(F("GetTradeSkillInfo"), i)
        if not info:find("header", 1, true) then
            local r = { info = info, link = Try(F("GetTradeSkillItemLink"), i), made = Try(F("GetTradeSkillNumMade"), i),
                        reagents = Try(F("GetTradeSkillNumReagents"), i), reagent1 = Try(F("GetTradeSkillReagentInfo"), i, 1),
                        reagent1Link = Try(F("GetTradeSkillReagentItemLink"), i, 1) }
            s.recipes[#s.recipes + 1] = r
        end
    end
    -- moderne Berufs-Schnittstelle (falls vorhanden)
    local ids = F("C_TradeSkillUI.GetAllRecipeIDs")
    if type(ids) == "function" then
        local ok, list = pcall(ids)
        s.modernRecipes = ok and type(list) == "table" and #list or Str(list)
        if ok and type(list) == "table" and list[1] then
            s.modernInfo = Try(F("C_TradeSkillUI.GetRecipeInfo"), list[1])
            s.modernSchematic = Try(F("C_TradeSkillUI.GetRecipeSchematic"), list[1], false)
        end
    end
end

function P.SNAP.craft(s)
    s.line = Try(F("GetCraftDisplaySkillLine"))
    s.num = Try(F("GetNumCrafts"))
    s.first = Try(F("GetCraftInfo"), 1)
    s.firstLink = Try(F("GetCraftItemLink"), 1)
    s.reagent1 = Try(F("GetCraftReagentInfo"), 1, 1)
end

function P.SNAP.loot(s)
    s.num = Try(F("GetNumLootItems"))
    local n = Num("GetNumLootItems") or 0
    s.slots = {}
    for i = 1, math.min(n, P.LIST_MAX) do
        s.slots[#s.slots + 1] = Try(F("GetLootSlotType"), i) .. " · " .. Try(F("GetLootSlotInfo"), i) .. " · " .. Try(F("GetLootSlotLink"), i)
    end
    s.fishing = Try(F("IsFishingLoot"))
end

function P.SNAP.quest(s)
    s.title = Try(F("GetTitleText"))
    s.money = Try(F("GetRewardMoney"))
    s.rewards = Try(F("GetNumQuestRewards"))
    s.choices = Try(F("GetNumQuestChoices"))
    if (Num("GetNumQuestRewards") or 0) > 0 then
        s.reward1 = Try(F("GetQuestItemInfo"), "reward", 1) .. " · " .. Try(F("GetQuestItemLink"), "reward", 1)
    end
    if (Num("GetNumQuestChoices") or 0) > 0 then
        s.choice1 = Try(F("GetQuestItemInfo"), "choice", 1) .. " · " .. Try(F("GetQuestItemLink"), "choice", 1)
    end
end

function P.SNAP.taxi(s)
    s.nodes = Try(F("NumTaxiNodes"))
    local n = Num("NumTaxiNodes") or 0
    for i = 1, n do
        local c = Num("TaxiNodeCost", i)
        if c and c > 0 then s.costExample = i .. ": " .. c; break end
    end
end

function P.SNAP.trainer(s)
    s.num = Try(F("GetNumTrainerServices"))
    s.cost1 = Try(F("GetTrainerServiceCost"), 1)
end

-- Ausruestung: belegte Plaetze und ein Beispiel
function P.SNAP.equip(s)
    local used, sample = 0, nil
    local first = tonumber(rawget(_G, "INVSLOT_FIRST_EQUIPPED")) or 1
    local last = tonumber(rawget(_G, "INVSLOT_LAST_EQUIPPED")) or 19
    for slot = first, last do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        if ok and link then used = used + 1; if not sample then sample = slot .. ": " .. Str(link) end end
    end
    s.equipped = ("%d von %d Plaetzen belegt%s"):format(used, last - first + 1, sample and (", z. B. " .. sample) or "")
end

-- Benutzbare Gegenstaende in den Taschen: hat ein Trank/Essen einen Zauber? (fuer "Benutzt")
function P.SNAP.usable(s)
    local C, CI = rawget(_G, "C_Container"), rawget(_G, "C_Item")
    s.items = {}
    if not (C and CI and CI.GetItemSpell) then s.error = "C_Item.GetItemSpell fehlt"; return end
    for bag = 0, 4 do
        local okn, n = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (okn and tonumber(n) or 0) do
            local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.itemID and not Peon.IsSecret(info.itemID) then
                local oks, name, id = pcall(CI.GetItemSpell, info.itemID)
                if oks and name then
                    s.items[#s.items + 1] = Str(info.hyperlink) .. " -> Zauber " .. Str(name) .. " (" .. Str(id) .. ")"
                    if #s.items >= 3 then return end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Pruefbefehl
---------------------------------------------------------------------------
function P.Run()
    local acc = mod.acc
    mod:Print(L.P_START)
    local r = { time = date("%Y-%m-%d %H:%M:%S"), ledger = mod.version, peon = Peon.version, peonAPI = Peon.API,
                locale = GetLocale and GetLocale() or "?" }
    -- Spiel und Charakter
    r.build = Try(rawget(_G, "GetBuildInfo"))
    r.realm, r.char = ns.Realm(), ns.CharName()
    r.faction = Try(rawget(_G, "UnitFactionGroup"), "player")
    r.money = Num("GetMoney")
    mod:Print(L.P_CHAR:format(r.char, r.realm, ns.MoneyText(r.money)))
    -- Funktionen je Bereich
    r.funcs = {}
    for _, grp in ipairs(P.FUNCS) do
        local have, missing = 0, {}
        local entry = {}
        for _, name in ipairs(grp[2]) do
            local ok = type((Lookup(name))) == "function"
            entry[name] = ok
            if ok then have = have + 1 else missing[#missing + 1] = name end
        end
        r.funcs[grp[1]] = entry
        mod:Print(L.P_FUNCS:format(L[grp[1]] or grp[1], have, #grp[2]))
        if #missing > 0 then mod:Print(L.P_MISSING:format(table.concat(missing, ", "))) end
    end
    -- Texte und Konstanten
    r.strings = {}
    for _, name in ipairs(P.STRINGS) do r.strings[name] = Str(rawget(_G, name)) end
    -- Taschen, Ausruestung, benutzbare Gegenstaende (immer moeglich)
    r.bags = P.Snap("bags")
    r.equip = P.Snap("equip")
    r.usable = P.Snap("usable")
    -- Fenster, die gerade offen sind
    local open = {}
    for kind in pairs(P.open) do
        r["open_" .. kind] = P.Snap(kind)
        open[#open + 1] = L["CTX_" .. kind:upper()] or kind
    end
    table.sort(open)
    if #open > 0 then mod:Print(L.P_OPEN:format(table.concat(open, ", "))) else mod:Print(L.P_NOTHING_OPEN) end
    acc.probe = r
    mod:Print(L.P_SAVED)
    return r
end

-- Kurzer Stand fuer die Optionsseite
function P.Summary()
    local acc = mod.acc
    if not acc then return "" end
    local r = acc.probe
    local seen, known = 0, 0
    for _, e in pairs(acc.probeEvents or {}) do
        if type(e) == "table" and e.known then
            known = known + 1
            if (e.count or 0) > 0 then seen = seen + 1 end
        end
    end
    local snaps = {}
    for kind, list in pairs(acc.probeSnaps or {}) do
        if type(list) == "table" and #list > 0 then snaps[#snaps + 1] = (L["CTX_" .. kind:upper()] or kind) .. " " .. #list .. "×" end
    end
    table.sort(snaps)
    if type(r) ~= "table" then
        return L.PROBE_NEVER .. "\n" .. L.PROBE_LAST:format("–", seen, known, #snaps > 0 and table.concat(snaps, ", ") or L.PROBE_NONE)
    end
    return L.PROBE_LAST:format(r.time or "?", seen, known, #snaps > 0 and table.concat(snaps, ", ") or L.PROBE_NONE)
end
