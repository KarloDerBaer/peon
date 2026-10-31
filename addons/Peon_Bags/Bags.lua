-- Peon_Bags - Bags.lua
-- Modul, Einstellungen und gemeinsame Hilfen (Taschennummern, Gegenstandsdaten, Art, Suche,
-- Kampf-Warteschlange). Konzept: Peon_Bags_Konzept.md
--
-- Grundsaetze:
--   * Nichts von Blizzard ersetzen: nur hooksecurefunc / HookScript, Blizzard-Tabellen nur ergaenzen.
--   * Plaetze der Taschen und Bank sind Blizzards eigene Taschenknoepfe (ContainerFrameItemButtonTemplate).
--   * Solange Bagnon geladen ist, ersetzt Peon_Bags nichts (nur /peon bags).

local ADDON_NAME, ns = ...
local L = ns.L

if not Peon or (Peon.API or 0) < 6 then
    if Peon and Peon.Print then Peon.Print("Peon_Bags: " .. L.MSG_OLD_PEON) end
    return
end

local LAYOUTS = { bags = true, type = true }

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "bags",
    title    = "Bags",
    db       = "PeonBagsDB",
    defaults = {
        replace      = true,      -- Blizzard-Taschen und Bank ersetzen
        replaceGuild = true,      -- Gildenbank ersetzen
        bagCols      = 10,
        bagScale     = 100,
        bagLayout    = "bags",
        bagBar       = true,
        bankCols     = 14,
        bankScale    = 100,
        bankLayout   = "bags",
        guildCols    = 14,
        guildScale   = 100,
        guildLayout  = "bags",
        quality      = true,
        newGlow      = true,
        junk         = true,
        autoMerchant = true,
        autoBank     = true,
        autoMail     = true,
        autoAuction  = true,
        autoTrade    = true,
        autoGuild    = true,
        pos          = {},        -- [Fenster] = { x, y } linke obere Ecke in UIParent-Einheiten
    },
    ranges = {
        bagCols = { 6, 24, 1 }, bankCols = { 6, 24, 1 }, guildCols = { 6, 24, 1 },
        bagScale = { 50, 200, 5 }, bankScale = { 50, 200, 5 }, guildScale = { 50, 200, 5 },
    },
    choices  = { bagLayout = LAYOUTS, bankLayout = LAYOUTS, guildLayout = LAYOUTS },
    keepOnReset = { pos = true },
    onSlash  = function(m, cmd)
        if cmd == "optionen" or cmd == "options" or cmd == "config" then
            m:OpenOptions()
        else
            ns.ToggleBags()
        end
    end,
})
ns.mod = mod

---------------------------------------------------------------------------
-- Kleine Hilfen
---------------------------------------------------------------------------
function ns.C() return rawget(_G, "C_Container") or {} end

function ns.Num(v) return type(v) == "number" and v == v end

-- sicherer Aufruf einer Funktion, die es vielleicht nicht gibt
function ns.Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    return unpack(r, 2, table.maxn(r))
end

function ns.NumSlots(bag)
    local n = ns.Try(ns.C().GetContainerNumSlots, bag)
    return ns.Num(n) and n or 0
end

function ns.FreeSlots(bag)
    local n = ns.Try(ns.C().GetContainerNumFreeSlots, bag)
    return ns.Num(n) and n or 0
end

-- Taschen: 0 bis letzte normale Tasche; Reagenzientasche getrennt (Forever: 0-4 und 5)
function ns.BagIDs()
    local last = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    local ids = {}
    for b = 0, last do ids[#ids + 1] = b end
    return ids
end

function ns.ReagentBagID()
    local E = rawget(_G, "Enum")
    local id = type(E) == "table" and type(E.BagIndex) == "table" and E.BagIndex.ReagentBag or nil
    if ns.Num(id) then return id end
    local total = tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS"))
    local last = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    if total and total > last then return total end
    return nil
end

function ns.IsInventoryBag(bag)
    if not ns.Num(bag) then return false end
    local last = tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4
    if bag >= 0 and bag <= last then return true end
    return bag == ns.ReagentBagID()
end

-- Bank: aus Enum.BagIndex (Namen mit "bank"), sonst die klassische Belegung.
-- Rueckgabe: Liste { id, kind = "bank" | "reagent" | "account" } (nach Nummer sortiert, ohne Pruefung der Plaetze)
function ns.BankBags()
    if ns.bankBags then return ns.bankBags end
    local res, seen = {}, {}
    local E = rawget(_G, "Enum")
    local bi = type(E) == "table" and E.BagIndex or nil
    if type(bi) == "table" then
        for name, id in pairs(bi) do
            if type(name) == "string" and ns.Num(id) and not seen[id] then
                local n = name:lower()
                if n:find("bank") then
                    seen[id] = true
                    local kind = "bank"
                    if n:find("account") or n:find("warband") then kind = "account"
                    elseif n:find("reagent") then kind = "reagent" end
                    res[#res + 1] = { id = id, kind = kind }
                end
            end
        end
    end
    if #res == 0 then
        res[1] = { id = -1, kind = "bank" }
        local first = (tonumber(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or 4) + 1
        for b = first, first + 6 do res[#res + 1] = { id = b, kind = "bank" } end
    end
    -- Hauptfach (-1) zuerst, dann nach Nummer
    table.sort(res, function(a, b)
        if (a.id < 0) ~= (b.id < 0) then return a.id < 0 end
        return math.abs(a.id) < math.abs(b.id)
    end)
    ns.bankBags = res
    return res
end

function ns.IsBankBag(bag)
    for _, b in ipairs(ns.BankBags()) do if b.id == bag then return true end end
    return false
end

-- Gegenstand in einem Platz (Tabelle wie C_Container.GetContainerItemInfo, nil = leer)
function ns.ItemInfo(bag, slot)
    local info = ns.Try(ns.C().GetContainerItemInfo, bag, slot)
    if type(info) == "table" and info.itemID then return info end
    return nil
end

-- Name aus dem Link ("[Name]"), sonst vom Spiel
function ns.ItemName(info)
    if not info then return nil end
    local link = info.hyperlink
    if type(link) == "string" then
        local n = link:match("%[(.-)%]")
        if n and n ~= "" then return n end
    end
    local CI = rawget(_G, "C_Item")
    local n = CI and ns.Try(CI.GetItemInfo, info.itemID)
    return n
end

---------------------------------------------------------------------------
-- Art eines Gegenstands (Anordnung "nach Art")
---------------------------------------------------------------------------
ns.CATS = { "equip", "consumable", "trade", "quest", "misc", "junk", "free" }
ns.CAT_TITLE = { equip = L.CAT_EQUIP, consumable = L.CAT_CONSUMABLE, trade = L.CAT_TRADE, quest = L.CAT_QUEST,
                 misc = L.CAT_MISC, junk = L.CAT_JUNK, free = L.CAT_FREE }
-- Klassen-Nummern des Spiels (Enum.ItemClass): 0 Verbrauch, 2 Waffe, 3 Edelstein, 4 Ruestung, 5 Reagenz,
-- 7 Handwerkswaren, 8 Verbesserung, 9 Rezept, 12 Quest, 19 Beruf
local CLASS_CAT = { [0] = "consumable", [2] = "equip", [4] = "equip", [3] = "trade", [5] = "trade", [7] = "trade",
                    [8] = "trade", [9] = "trade", [19] = "trade", [12] = "quest" }

function ns.ItemClass(itemID)
    local CI = rawget(_G, "C_Item")
    local fn = CI and CI.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
    local r = { ns.Try(fn, itemID) }
    return r[6]
end

-- quest = true, wenn das Spiel den Gegenstand als Quest-Gegenstand meldet
function ns.Category(info, quest)
    if not info then return "free" end
    if quest then return "quest" end
    if info.quality == 0 and not info.hasNoValue then return "junk" end
    local cls = ns.ItemClass(info.itemID)
    return cls and CLASS_CAT[cls] or "misc"
end

---------------------------------------------------------------------------
-- Suche: Namensteil, Gross/klein und Umlaute egal
---------------------------------------------------------------------------
local FOLD = { ["ä"] = "a", ["ö"] = "o", ["ü"] = "u", ["ß"] = "ss", ["Ä"] = "a", ["Ö"] = "o", ["Ü"] = "u",
               ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["á"] = "a", ["à"] = "a" }
function ns.Fold(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for k, v in pairs(FOLD) do s = s:gsub(k, v) end
    return s:lower()
end

ns.search, ns.searchRaw = "", ""
function ns.Matches(info)
    if ns.search == "" then return true end
    if not info then return false end
    local name = ns.ItemName(info)
    return ns.Fold(name):find(ns.search, 1, true) ~= nil
end

function ns.SetSearch(text)
    ns.searchRaw = text or ""
    text = ns.Fold(strtrim(text or ""))
    if text == ns.search then return end
    ns.search = text
    if ns.OnSearch then ns.OnSearch() end
end

---------------------------------------------------------------------------
-- Kampf: was im Kampf nicht geht, wird danach nachgeholt
---------------------------------------------------------------------------
ns.queue = {}
local combatHint = false
function ns.Locked(frame)
    if not InCombatLockdown() then return false end
    if not frame then return true end
    local ok, p = pcall(frame.IsProtected, frame)
    return ok and p and true or false
end

function ns.Defer(key, fn)
    ns.queue[key] = fn
    if not combatHint then combatHint = true; mod:Dbg("im Kampf vorgemerkt: " .. key) end
end

mod:On("COMBAT_END", function()
    combatHint = false
    local q = ns.queue
    ns.queue = {}
    for key, fn in pairs(q) do mod:Call("Nachholen " .. key, fn) end
end)

---------------------------------------------------------------------------
-- Fenster-Art des Spiels (PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE)
---------------------------------------------------------------------------
function ns.PIT(name, fallback)
    local E = rawget(_G, "Enum")
    local t = type(E) == "table" and E.PlayerInteractionType or nil
    local v = type(t) == "table" and t[name] or nil
    return ns.Num(v) and v or fallback
end

-- Bagnon (oder ein anderes Taschen-Addon) geladen? Dann ersetzt Peon_Bags nichts.
function ns.BagnonLoaded()
    return Peon.IsAddOnLoaded("Bagnon") and true or false
end

function ns.Replacing()
    return mod.db and mod.db.replace and not ns.BagnonLoaded()
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
mod:On("INIT", function()
    if ns.CreateOptions then mod:Call("Optionen", ns.CreateOptions) end
end)

mod:On("LOGIN", function()
    if ns.BagnonLoaded() and mod.db.replace then mod:Print(L.MSG_BAGNON) end
    if ns.InitInventory then mod:Call("Taschen", ns.InitInventory) end
    if ns.InitBank then mod:Call("Bank", ns.InitBank) end
    if ns.InitGuild then mod:Call("Gildenbank", ns.InitGuild) end
end)

local function ApplyAll()
    for _, w in pairs(ns.windows or {}) do
        if w.Apply then mod:Call("Anwenden", w.Apply, w) end
    end
    if ns.UpdateReplace then mod:Call("Ersetzen", ns.UpdateReplace) end
end
ns.ApplyAll = ApplyAll
mod:On("CHANGED", ApplyAll)
mod:On("RESET", ApplyAll)

if Peon.SetFeedbackAreas then
    Peon.SetFeedbackAreas(ADDON_NAME, { "Taschen", "Bank", "Gildenbank", "Anordnung", "Suche", "Plätze",
        "Öffnen/Schließen", "Taschenleiste", "Optionen" })
end
