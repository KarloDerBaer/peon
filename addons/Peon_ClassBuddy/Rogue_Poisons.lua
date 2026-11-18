-- Peon_ClassBuddy - Rogue_Poisons.lua (Schurke, ab 0.4.0)
-- Gifte mit einer Taste auftragen und daran erinnern (Konzept Abschnitt 10).
--
-- Die Taste: unsichtbarer sicherer Knopf PeonClassBuddyPoison (Tastenbelegung, Makro /click PeonClassBuddyPoison).
-- Jeder Druck traegt EIN Gift auf, zuerst auf die Haupthand, dann auf die Nebenhand, jeweils nur wenn es fehlt oder
-- bald ablaeuft. Das Spiel legt den Gegenstand ueber Blizzards Knopfvorlage auf die Waffe (Attribut target-slot,
-- wie der Koeder in Peon_Fishing). Ausserhalb des Kampfes entscheidet PreClick bei jedem Druck neu, im Kampf duerfen
-- sich die Attribute nicht aendern: Dann gilt, was beim Kampfbeginn vorbereitet war.
-- useOnKeyDown = false: Der Knopf wirkt beim Loslassen. So klappen Tastenbelegung (Druecken und Loslassen) und
-- /click (nur Loslassen) unabhaengig von der Einstellung ActionButtonUseKeyDown.
--
-- Ersetzen: Liegt noch ein Gift auf der Waffe, fragt das Spiel nach (StaticPopup REPLACE_ENCHANT). Kam die Frage
-- direkt nach unserem Knopf, bestaetigt der Klassenbuddy sie selbst (C_Item.ReplaceEnchant). Sperrt das Spiel das,
-- erscheint die Frage wieder und es wird in dieser Sitzung nicht mehr versucht.
--
-- Erinnerung: Fehlt ein Gift oder laeuft es bald ab, und liegt ein passendes in den Taschen, kommt einmal eine
-- Warnung (Bildschirmmitte, Chat, Ton). Nicht im Kampf, nicht tot, nicht auf dem Flug, nicht in Stadt oder Gasthaus
-- (ausser in einer Instanz). Fest dazu: nach dem Einloggen, beim Betreten einer Instanz, nach dem Wiederbeleben und
-- beim Bereitschaftscheck. Wird ein gewaehltes Gift knapp, kommt ebenfalls einmal eine Warnung.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local P = {}
ns.Poisons = P

local MAIN, OFF = 16, 17     -- INVSLOT_MAINHAND, INVSLOT_OFFHAND
local MACRO_NAME, MACRO_BODY = "PeonGift", "/click PeonClassBuddyPoison"
local ICON = "Ability_Poisons"
local REPLACE_WINDOW = 3     -- Sekunden nach dem Druck, in denen die Frage zum Ersetzen zu uns gehoert
local TICK = 10              -- Sekunden zwischen zwei Pruefungen ausserhalb des Kampfes
local REPEAT_GAP = 15        -- Sekunden, in denen feste Zeitpunkte nicht noch einmal warnen

-- Gifte je Art, niedrigster Rang zuerst (Gegenstandsnummern aus dem klassischen Spiel)
local KINDS = { "instant", "deadly", "crippling", "mind", "wound" }
local ITEMS = {
    instant   = { 6947, 6949, 6950, 8926, 8927, 8928 },   -- Sofort wirkendes Gift I bis VI
    deadly    = { 2892, 2893, 8984, 8985, 20844 },        -- Toedliches Gift I bis V
    crippling = { 3775, 3776 },                           -- Verkrueppelndes Gift I und II
    mind      = { 5237, 6951, 9186 },                     -- Gedankenbenebelndes Gift I bis III
    wound     = { 10918, 10920, 10921, 10922 },           -- Wundgift I bis IV
}
P.KINDS, P.ITEMS, P.MAIN, P.OFF = KINDS, ITEMS, MAIN, OFF

local active = false
local btn
local prepared               -- Zustand, auf den der Knopf gerade eingestellt ist (oder nil)
local pending                -- letzter Druck: { hand, item, t }
local warned = {}            -- Hand -> schon gewarnt
local lastStock, dropped, stockWarned = {}, {}, {}
local replaceBlocked = false
local popupArgs
local applied = 0            -- in dieser Sitzung aufgetragen (Druecke mit Gift)
local lastWarn = -math.huge  -- Zeit der letzten Warnung

local function Num(v) if v == nil or Peon.IsSecret(v) or type(v) ~= "number" then return nil end return v end
local function Bool(v) if Peon.IsSecret(v) then return nil end return v and true or false end

local function LastBag()
    return Num(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or Num(rawget(_G, "NUM_BAG_SLOTS")) or 4
end

---------------------------------------------------------------------------
-- Taschen und Waffen
---------------------------------------------------------------------------
-- Gifte in den Taschen: itemID -> Anzahl
function P.Bags()
    local counts = {}
    local known = {}
    for _, list in pairs(ITEMS) do for _, id in ipairs(list) do known[id] = true end end
    for bag = 0, LastBag() do
        local slots = Num(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local id = Num(C_Container.GetContainerItemID(bag, slot))
            if id and known[id] then
                local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                local n = type(info) == "table" and Num(info.stackCount) or 1
                counts[id] = (counts[id] or 0) + n
            end
        end
    end
    return counts
end

local function Usable(id)
    local fn = (C_Item and C_Item.IsUsableItem) or rawget(_G, "IsUsableItem")
    if not fn then return true end
    local ok, usable = pcall(fn, id)
    if not ok or Peon.IsSecret(usable) then return true end
    return usable == true
end

-- Hoechster nutzbarer Rang einer Art in den Taschen
function P.Best(kind, counts)
    local list = ITEMS[kind]
    if not list then return nil end
    counts = counts or P.Bags()
    for i = #list, 1, -1 do
        local id = list[i]
        if (counts[id] or 0) > 0 and Usable(id) then return id end
    end
    return nil
end

-- Alle Gifte einer Art in den Taschen (alle Raenge)
function P.Count(kind, counts)
    counts = counts or P.Bags()
    local n = 0
    for _, id in ipairs(ITEMS[kind] or {}) do n = n + (counts[id] or 0) end
    return n
end

-- Waffe in der Hand (itemID) oder nil. Nur Waffen, keine Angel und kein Schild.
function P.Weapon(hand)
    local id = Num(GetInventoryItemID("player", hand))
    if not id then return nil end
    local info = C_Item and C_Item.GetItemInfoInstant
    if info then
        local ok, _, _, _, _, _, classID, subID = pcall(info, id)
        classID, subID = ok and Num(classID), ok and Num(subID)
        if classID and classID ~= 2 then return nil end   -- 2 = Waffe
        if subID == 20 then return nil end                -- Angel
    end
    return id
end

-- Gift auf der Hand: hat (true/false), Restsekunden, Ladungen. nil, wenn das Spiel es nicht verraet.
function P.Enchant(hand)
    if not GetWeaponEnchantInfo then return nil end
    local r = { pcall(GetWeaponEnchantInfo) }
    if not r[1] then return nil end
    local o = (hand == MAIN) and 1 or 5
    local has, ms, charges = r[o + 1], r[o + 2], r[o + 3]
    if Peon.IsSecret(has) or Peon.IsSecret(ms) or Peon.IsSecret(charges) then return nil end
    has = Bool(has)
    if has == nil then return nil end
    return has, has and ((Num(ms) or 0) / 1000) or 0, has and Num(charges) or 0
end

---------------------------------------------------------------------------
-- Was ist zu tun?
---------------------------------------------------------------------------
local function KindOf(hand)
    local db = mod.db
    return hand == MAIN and db.poisonMain or db.poisonOff
end

-- Zustand einer Hand oder nil, wenn es fuer sie nichts zu tun gibt (kein Gift gewaehlt, keine Waffe, unbekannt)
function P.State(hand, counts)
    local db = mod.db
    local kind = KindOf(hand)
    if not db or kind == "none" or not ITEMS[kind] then return nil end
    local weapon = P.Weapon(hand)
    if not weapon then return nil end
    local has, left, charges = P.Enchant(hand)
    if has == nil then return nil end
    local s = { hand = hand, kind = kind, weapon = weapon, has = has, left = left, charges = charges }
    s.low = has and (left < db.poisonRenew * 60
        or (db.poisonCharges > 0 and charges > 0 and charges < db.poisonCharges)) or false
    s.need = (not has) or s.low
    s.item = P.Best(kind, counts)
    return s
end

-- Naechste Hand, die jetzt ein Gift bekommt, oder nil
function P.Next()
    local db = mod.db
    if not (active and db and db.poisonOn) then return nil end
    local counts = P.Bags()
    for _, hand in ipairs({ MAIN, OFF }) do
        local s = P.State(hand, counts)
        if s and s.need and s.item then return s end
    end
    return nil
end

-- Knopf auf die naechste Hand einstellen (nur ausserhalb des Kampfes)
function P.Prepare()
    if not btn or InCombatLockdown() then return false end
    local s = P.Next()
    prepared = s
    if s then
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", "item:" .. s.item)
        btn:SetAttribute("target-slot", s.hand)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("item", nil)
        btn:SetAttribute("target-slot", nil)
    end
    return s ~= nil
end

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
local function KindName(kind) return L["PO_KIND_" .. kind] or kind end
local function HandName(hand) return hand == MAIN and L.PO_MAIN or L.PO_OFF end
local function Minutes(sec) return math.max(1, math.ceil(sec / 60)) end

-- Eine Zeile je Hand
function P.StatusLines()
    local db = mod.db
    local lines = {}
    local counts = P.Bags()
    for _, hand in ipairs({ MAIN, OFF }) do
        local kind = KindOf(hand)
        local text
        if kind == "none" then
            text = L.PO_ST_NONE_CHOSEN
        elseif not P.Weapon(hand) then
            text = L.PO_ST_NO_WEAPON
        else
            local s = P.State(hand, counts)
            if not s then
                text = L.PO_ST_UNKNOWN
            else
                if s.has then
                    text = L.PO_ST_LEFT:format(Minutes(s.left))
                    if s.charges > 0 then text = text .. " " .. L.PO_ST_CHARGES:format(s.charges) end
                else
                    text = L.PO_ST_MISSING
                end
                if s.need and not s.item then text = text .. ", " .. L.PO_ST_NO_ITEM:format(KindName(kind)) end
            end
        end
        if kind == "none" then
            lines[#lines + 1] = L.PO_ST_LINE_NONE:format(HandName(hand), text)
        else
            lines[#lines + 1] = L.PO_ST_LINE:format(HandName(hand), KindName(kind), text)
        end
    end
    return lines
end

function P.PrintStatus()
    if not active then return mod:Print(L.PO_NOT_ROGUE) end
    if not mod.db.poisonOn then return mod:Print(L.PO_OFF_MSG) end
    for _, line in ipairs(P.StatusLines()) do mod:Print(line) end
end

-- Kurzer Text fuer die Panel-Leiste: Minuten je Hand
function P.ShortText()
    if not active then return "" end
    local parts = {}
    local counts = P.Bags()
    for _, hand in ipairs({ MAIN, OFF }) do
        local s = P.State(hand, counts)
        if s then parts[#parts + 1] = s.has and tostring(Minutes(s.left)) or L.PO_SHORT_MISSING end
    end
    return table.concat(parts, " / ")
end

---------------------------------------------------------------------------
-- Die Taste
---------------------------------------------------------------------------
-- Vor der Aktion: neu einstellen (nicht im Kampf) und merken, dass eine Frage zum Ersetzen jetzt zu uns gehoert
local function OnPreClick(_, _, down)
    if down then return end
    if not InCombatLockdown() then P.Prepare() end
    pending = prepared and { hand = prepared.hand, item = prepared.item, t = GetTime() } or nil
end

local function OnPostClick(_, _, down)
    if down then return end
    local db = mod.db
    if not (active and db and db.poisonOn) then return P.PrintStatus() end
    if prepared then
        applied = applied + 1
        mod:Dbg(("Gift auftragen: %s auf Platz %d"):format(tostring(prepared.item), prepared.hand))
    else
        -- nichts zu tun: kurz sagen, wie es steht
        P.PrintStatus()
    end
end

local function CreateButton()
    if btn then return btn end
    btn = CreateFrame("Button", "PeonClassBuddyPoison", UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetScript("PreClick", function(...) mod:Call("Gifte", OnPreClick, ...) end)
    btn:SetScript("PostClick", function(...) mod:Call("Gifte", OnPostClick, ...) end)
    return btn
end

---------------------------------------------------------------------------
-- Ersetzen ohne Nachfrage
---------------------------------------------------------------------------
local function OnReplacePopup(a1, a2)
    local db = mod.db
    if not (active and db and db.poisonOn and db.poisonReplace) or replaceBlocked then return end
    if not pending or GetTime() - pending.t > REPLACE_WINDOW then return end
    local fn = (C_Item and C_Item.ReplaceEnchant) or rawget(_G, "ReplaceEnchant")
    if not fn then return end
    popupArgs = { a1, a2 }
    pending = nil
    local ok, err = pcall(fn)
    if not ok then
        mod:Dbg("Ersetzen: " .. Peon.S(err))
        return
    end
    if StaticPopup_Hide then StaticPopup_Hide("REPLACE_ENCHANT") end
    mod:Dbg("Ersetzen bestaetigt")
end

local function OnBlocked(_, addon, func)
    if addon ~= ADDON_NAME or not tostring(func):find("ReplaceEnchant") or replaceBlocked then return end
    replaceBlocked = true
    mod:Print(L.PO_REPLACE_BLOCKED)
    if popupArgs and StaticPopup_Show then StaticPopup_Show("REPLACE_ENCHANT", popupArgs[1], popupArgs[2]) end
end

---------------------------------------------------------------------------
-- Erinnerung
---------------------------------------------------------------------------
local function CanWarn()
    local db = mod.db
    if not (active and db and db.poisonOn and db.poisonWarn) then return false end
    if InCombatLockdown() then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") == true then return false end
    if UnitOnTaxi and UnitOnTaxi("player") == true then return false end
    if IsResting and IsResting() == true then
        local inInstance = IsInInstance and IsInInstance()
        if inInstance ~= true then return false end
    end
    return true
end

local function Warn(msg)
    mod:Print(msg)
    local rw = rawget(_G, "RaidWarningFrame")
    if rw and RaidNotice_AddMessage then
        pcall(RaidNotice_AddMessage, rw, msg, (ChatTypeInfo and ChatTypeInfo.RAID_WARNING) or { r = 1, g = 0.3, b = 0.1 })
    elseif UIErrorsFrame then
        UIErrorsFrame:AddMessage(msg, 1, 0.3, 0.1)
    end
    if mod.db.poisonSound and PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
end

-- force: an festen Zeitpunkten (Einloggen, Instanz, Wiederbeleben, Bereitschaftscheck) auch erneut warnen
function P.Check(force)
    local db = mod.db
    if not (active and db and db.poisonOn) then return end
    local counts = P.Bags()
    local can = CanWarn()

    -- Gift fehlt oder laeuft ab. Feste Zeitpunkte kurz hintereinander warnen nur einmal.
    if force and GetTime() - lastWarn < REPEAT_GAP then force = false end
    local needing, due = {}, false
    for _, hand in ipairs({ MAIN, OFF }) do
        local s = P.State(hand, counts)
        if s and s.need and s.item then
            needing[#needing + 1] = hand
            if force or not warned[hand] then due = true end
        elseif s and not s.need then
            warned[hand] = false
        end
    end
    if can and due then
        local names = {}
        for _, hand in ipairs(needing) do warned[hand] = true; names[#names + 1] = HandName(hand) end
        lastWarn = GetTime()
        Warn(L.PO_WARN_HANDS:format(table.concat(names, L.PO_AND)))
    end

    -- Vorrat: einmal warnen, wenn ein gewaehltes Gift knapp wird
    if db.poisonLow <= 0 then return end
    local seen = {}
    for _, hand in ipairs({ MAIN, OFF }) do
        local kind = KindOf(hand)
        if ITEMS[kind] and not seen[kind] and P.Weapon(hand) then
            seen[kind] = true
            local c = P.Count(kind, counts)
            local prev = lastStock[kind]
            lastStock[kind] = c
            if prev and prev > c then dropped[kind] = true end
            if c > db.poisonLow then
                stockWarned[kind], dropped[kind] = false, false
            elseif not stockWarned[kind] and can and (dropped[kind] or (force and c > 0)) then
                stockWarned[kind] = true
                Warn(c > 0 and L.PO_WARN_LOW:format(c, KindName(kind)) or L.PO_WARN_EMPTY:format(KindName(kind)))
            end
        end
    end
end

local function Tick()
    if not active or InCombatLockdown() then return end
    P.Prepare()
    P.Check(false)
    if ns.poisonLauncher then ns.poisonLauncher:Refresh() end
end
P.Tick = Tick

local function Later(sec, fn)
    if C_Timer and C_Timer.After then C_Timer.After(sec, function() mod:Call("Gifte", fn) end) else mod:Call("Gifte", fn) end
end

---------------------------------------------------------------------------
-- Makro, Bericht, Panel
---------------------------------------------------------------------------
function P.MakeMacro()
    if Peon.InCombat() then return mod:Print(L.SH_MACRO_COMBAT) end
    local index = GetMacroIndexByName and GetMacroIndexByName(MACRO_NAME) or 0
    if not index or index == 0 then
        local ok, res = pcall(CreateMacro, MACRO_NAME, ICON, MACRO_BODY, true)
        if not ok or not res then return mod:Print(L.SH_MACRO_FAIL:format(MACRO_BODY)) end
        index = res
    end
    if PickupMacro then pcall(PickupMacro, index) end
    mod:Print(L.PO_MACRO_DONE)
end

-- /peon classbuddy gifte
function P.Report()
    P.PrintStatus()
    if not active then return end
    local counts = P.Bags()
    local parts = {}
    for _, kind in ipairs(KINDS) do
        local c = P.Count(kind, counts)
        if c > 0 then parts[#parts + 1] = ("%s %d"):format(KindName(kind), c) end
    end
    mod:Print(L.PO_REPORT_BAGS:format(#parts > 0 and table.concat(parts, ", ") or L.PO_REPORT_NONE))
end

function P.IsActive() return active end
function P.Applied() return applied end

---------------------------------------------------------------------------
-- Panel (ab 0.4.0): Linksklick traegt auf, Rechtsklick waehlt die Gifte je Waffe
--
-- Ein Klick auf das Symbol in Peon Panel ist ein gewoehnlicher Klick und darf kein Gift auftragen. Darum legt sich
-- beim Darueberfahren (Tooltip) der unsichtbare sichere Knopf PeonClassBuddyPoisonPanel genau ueber das Symbol.
-- Er klickt die Gift-Taste (Typ click), gibt Rechtsklick, Tooltip und Ziehen an das Symbol weiter und verschwindet
-- beim Verlassen. Er wird nur positioniert, nie an das Symbol gehaengt: Sonst wuerde das Panel selbst geschuetzt
-- und liesse sich im Kampf nicht mehr ordnen. Im Kampf darf er nicht bewegt werden. Er verschwindet beim
-- Kampfbeginn, ein Klick auf das Symbol sagt dann, dass im Kampf nur die Taste geht.
---------------------------------------------------------------------------
local overlay, overlayOwner

local function OwnerScript(name, ...)
    local o = overlayOwner
    local fn = o and o.GetScript and o:GetScript(name)
    if fn then fn(o, ...) end
end

function P.HideOverlay()
    if not overlay or InCombatLockdown() then return end
    overlay:Hide()
    overlay:ClearAllPoints()
    overlayOwner = nil
end

-- Den sicheren Knopf ueber owner legen (nur ausserhalb des Kampfes)
function P.Attach(owner)
    if not overlay or not owner or InCombatLockdown() then return false end
    local l, b = owner:GetLeft(), owner:GetBottom()
    local w, h = owner:GetWidth(), owner:GetHeight()
    if type(l) ~= "number" or type(b) ~= "number" or Peon.IsSecret(l) or Peon.IsSecret(b) then return false end
    local s = (owner:GetEffectiveScale() or 1) / (overlay:GetEffectiveScale() or 1)
    overlayOwner = owner
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
    overlay:SetSize(w * s, h * s)
    overlay:SetFrameStrata(owner:GetFrameStrata() or "HIGH")
    overlay:SetFrameLevel((owner:GetFrameLevel() or 0) + 10)
    overlay:Show()
    return true
end

local function CreateOverlay()
    if overlay then return overlay end
    overlay = CreateFrame("Button", "PeonClassBuddyPoisonPanel", UIParent, "SecureActionButtonTemplate")
    overlay:Hide()
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:RegisterForDrag("LeftButton")
    overlay:SetAttribute("useOnKeyDown", false)
    overlay:SetAttribute("type1", "click")
    overlay:SetAttribute("clickbutton1", btn)
    overlay:SetScript("PostClick", function(_, button)
        mod:Call("Gifte", function()
            if button == "RightButton" then
                OwnerScript("OnClick", "RightButton")
            elseif ns.poisonLauncher then
                ns.poisonLauncher:Refresh()
            end
        end)
    end)
    overlay:SetScript("OnEnter", function() mod:Call("Gifte", OwnerScript, "OnEnter") end)
    overlay:SetScript("OnLeave", function()
        mod:Call("Gifte", function()
            OwnerScript("OnLeave")
            if GameTooltip then GameTooltip:Hide() end
            P.HideOverlay()
        end)
    end)
    overlay:SetScript("OnDragStart", function() mod:Call("Gifte", OwnerScript, "OnDragStart") end)
    overlay:SetScript("OnDragStop", function()
        mod:Call("Gifte", function()
            OwnerScript("OnDragStop")
            P.HideOverlay()
        end)
    end)
    return overlay
end

-- Gift je Waffe waehlen
function P.SetKind(hand, kind)
    local db = mod.db
    if not db or not (ITEMS[kind] or kind == "none") then return end
    local key = hand == MAIN and "poisonMain" or "poisonOff"
    db[key] = kind
    mod:Fire("CHANGED", key)
    if mod.page and mod.page.Refresh then mod.page:Refresh() end
end

function P.FillMenu(root)
    local counts = P.Bags()
    for _, hand in ipairs({ MAIN, OFF }) do
        root:CreateTitle(hand == MAIN and L.PO_MAIN_SEL or L.PO_OFF_SEL)
        local function isSel(v) return KindOf(hand) == v end
        local function setSel(v) P.SetKind(hand, v) end
        for _, kind in ipairs(KINDS) do
            root:CreateRadio(L.PO_MENU_KIND:format(KindName(kind), P.Count(kind, counts)), isSel, setSel, kind)
        end
        root:CreateRadio(L.PO_KIND_none, isSel, setSel, "none")
    end
end

-- Vorrat je Hand fuer die Leiste
function P.StockText()
    if not active then return "" end
    local parts = {}
    local counts = P.Bags()
    for _, hand in ipairs({ MAIN, OFF }) do
        local kind = KindOf(hand)
        if ITEMS[kind] and P.Weapon(hand) then parts[#parts + 1] = tostring(P.Count(kind, counts)) end
    end
    return table.concat(parts, " / ")
end

local function AddLauncher()
    if not mod.AddLauncher then return end
    ns.poisonLauncher = mod:AddLauncher({
        key = "poisons", title = L.PO_TITLE, icon = "Interface\\Icons\\" .. ICON,
        texts = {
            { key = "time", label = L.PO_TEXT_TIME, get = P.ShortText },
            { key = "stock", label = L.PO_TEXT_STOCK, get = P.StockText },
            { key = "both", label = L.PO_TEXT_BOTH, get = function()
                return L.PO_TEXT_BOTH_FMT:format(P.ShortText(), P.StockText())
            end },
        },
        defaultText = "time",
        onClick = function(_, button)
            if button == "RightButton" then return end
            if InCombatLockdown() then return mod:Print(L.PO_PANEL_COMBAT) end
            P.PrintStatus()
        end,
        menu = function(_, root) P.FillMenu(root) end,
        onTooltip = function(_, tt)
            for _, line in ipairs(P.StatusLines()) do tt:AddLine(line, 1, 1, 1) end
            local counts = P.Bags()
            local stock = {}
            for _, hand in ipairs({ MAIN, OFF }) do
                local kind = KindOf(hand)
                if ITEMS[kind] then stock[#stock + 1] = L.PO_MENU_KIND:format(KindName(kind), P.Count(kind, counts)) end
            end
            if #stock > 0 then tt:AddLine(L.PO_TIP_STOCK:format(table.concat(stock, ", ")), 0.8, 0.8, 0.8, true) end
            tt:AddLine(L.PO_TIP_PANEL, 0.6, 0.6, 0.6, true)
            local owner = tt.GetOwner and tt:GetOwner()
            if owner and owner ~= overlay and active then P.Attach(owner) end
        end,
    })
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
local function Start()
    active = true
    CreateButton()
    CreateOverlay()
    if hooksecurefunc and type(rawget(_G, "StaticPopup_Show")) == "function" then
        hooksecurefunc("StaticPopup_Show", function(which, a1, a2)
            if which == "REPLACE_ENCHANT" then mod:Call("Gifte", OnReplacePopup, a1, a2) end
        end)
    end
    mod:RegisterEvent("ADDON_ACTION_BLOCKED", OnBlocked)
    mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", OnBlocked)
    mod:RegisterEvent("BAG_UPDATE_DELAYED", Tick)
    mod:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Tick)
    mod:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then Tick() end end)
    mod:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Later(3, function()
            local inInstance = IsInInstance and IsInInstance()
            P.Check(inInstance == true)
        end)
    end)
    mod:RegisterEvent("READY_CHECK", function() P.Check(true) end)
    mod:RegisterEvent("PLAYER_UNGHOST", function() Later(2, function() P.Check(true) end) end)
    mod:RegisterEvent("PLAYER_ALIVE", function() Later(2, function() P.Check(true) end) end)
    -- Kampfbeginn: Knopf noch schnell einstellen, solange es geht. Kampfende: neu einstellen und pruefen.
    mod:On("COMBAT_START", function()
        P.Prepare()
        P.HideOverlay()
    end)
    mod:On("COMBAT_END", Tick)
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(TICK, function() mod:Call("Gifte", Tick) end) end
    P.Prepare()
    Later(5, function() P.Check(true) end)
    mod:Dbg("Schurke: Gifte aktiv")
end

ns.ForClass("ROGUE", AddLauncher)   -- ab 0.4.0 nur fuer Schurken
mod:On("CHANGED", function() if active then Tick() end end)
mod:On("RESET", function() if active then Tick() end end)
mod:On("LOGIN", function()
    if ns.PlayerClass() ~= "ROGUE" then return end
    Start()
end)

-- fuer Tests
P._State = function() return { prepared = prepared, pending = pending, warned = warned, replaceBlocked = replaceBlocked } end
