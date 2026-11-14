-- Peon_ClassBuddy - Probe.lua
-- Pruefbefehl /peon classbuddy pruefen (Konzept Abschnitt 4.3): Darf ein Addon einen Seelensplitter vernichten,
-- und wenn ja, wann? Getestet werden vier Wege, jeweils ausserhalb und im Kampf:
--   event   ohne Tastendruck (Zeitgeber nach dem Befehl und beim Kampfbeginn)
--   click   Klick auf einen Knopf im kleinen Fenster
--   macro   Makro mit /click PeonClassBuddyShard (unsichtbarer Knopf)
--   action  Aktionstaste: mitlesen nach Blizzards Aufruf (hooksecurefunc, PostClick), dann im selben Tastendruck
-- Jeder Weg vernichtet je Zustand (Kampf, kein Kampf) hoechstens EINEN Splitter. Ergebnisse in PeonClassBuddyDB.probe.
-- Sicherheit: nur Gegenstand 6265. Haengt nach dem Aufnehmen etwas anderes am Mauszeiger, wird es zurueckgelegt.

local ADDON_NAME, ns = ...
local L = ns.L

local P = {}
ns.Probe = P

local SHARD = 6265          -- Seelensplitter
local CHECK_DELAY = 0.5     -- so lange nach dem Vernichten nachzaehlen
local HOOK_FUNCS = { "UseAction", "ActionButtonDown", "ActionButtonUp", "CastSpellByName", "CastSpellByID" }

local armed = false
local hooked = false
local lastBlocked           -- { func, t } aus ADDON_ACTION_BLOCKED/FORBIDDEN fuer dieses Addon
local macroBtn

local function DB()
    local db = ns.mod.db
    if not db then return nil end
    if type(db.probe) ~= "table" then db.probe = {} end
    local p = db.probe
    if type(p.results) ~= "table" then p.results = {} end
    if type(p.hooks) ~= "table" then p.hooks = {} end
    return p
end

local function Num(v) if v == nil or Peon.IsSecret(v) or type(v) ~= "number" then return nil end return v end

local function InCombat() return Peon.InCombat() end
local function StateKey(combat) return combat and "kampf" or "frei" end

---------------------------------------------------------------------------
-- Taschen
---------------------------------------------------------------------------
local function LastBag()
    return Num(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")) or Num(rawget(_G, "NUM_BAG_SLOTS")) or 4
end

local function SlotItem(bag, slot)
    local id = C_Container.GetContainerItemID(bag, slot)
    return Num(id)
end

local function BagInfo(bag)
    local slots = Num(C_Container.GetContainerNumSlots(bag)) or 0
    local free, family = C_Container.GetContainerNumFreeSlots(bag)
    return slots, Num(free) or 0, Num(family)
end

-- Alle Taschen mit Zahl der Splitter
function P.ScanBags()
    local list, total = {}, 0
    for bag = 0, LastBag() do
        local slots, free, family = BagInfo(bag)
        local shards = 0
        for slot = 1, slots do
            if SlotItem(bag, slot) == SHARD then shards = shards + 1 end
        end
        total = total + shards
        list[#list + 1] = { bag = bag, slots = slots, free = free, family = family, shards = shards }
    end
    return list, total
end

-- Ein Splitter zum Vernichten: zuerst in normalen Taschen (Familie 0), sonst irgendeiner. Jeweils der letzte Platz.
function P.FindShard()
    local normal, any
    for bag = 0, LastBag() do
        local slots, _, family = BagInfo(bag)
        for slot = 1, slots do
            if SlotItem(bag, slot) == SHARD then
                any = { bag, slot }
                if family == 0 or family == nil then normal = { bag, slot } end
            end
        end
    end
    local hit = normal or any
    if hit then return hit[1], hit[2] end
end

local function CursorItemID()
    local kind, id = GetCursorInfo()
    if Peon.IsSecret(kind) or Peon.IsSecret(id) then return nil end
    if kind ~= "item" then return nil end
    return Num(id)
end

---------------------------------------------------------------------------
-- Ergebnis festhalten
---------------------------------------------------------------------------
local function Record(way, combat, ok, why, extra)
    local p = DB()
    if not p then return end
    local key = way .. "_" .. StateKey(combat)
    local r = { ok = ok and true or false, why = why, at = time() }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    p.results[key] = r
    ns.mod:Print(L.P_RESULT:format(L.P_WAY[way] or way, combat and L.P_COMBAT or L.P_FREE, why))
    if ns.Guide then ns.Guide.Refresh() end
end

-- Ergebnis eines Wegs (fuer das Fenster)
function P.Result(way, combat)
    local p = DB()
    return p and p.results[way .. "_" .. StateKey(combat)] or nil
end

local function HasResult(way, combat)
    local p = DB()
    return p and p.results[way .. "_" .. StateKey(combat)] ~= nil
end

-- Einen Splitter vernichten. way: event, click, macro, action. hook: welcher Aufruf es ausgeloest hat
function P.TryDelete(way, hook)
    local combat = InCombat()
    if HasResult(way, combat) then return end
    local extra = { hook = hook }
    if CursorHasItem() then return Record(way, combat, false, L.P_CURSOR_BUSY, extra) end
    local bag, slot = P.FindShard()
    if not bag then return Record(way, combat, false, L.P_NO_SHARD, extra) end
    local _, before = P.ScanBags()
    lastBlocked = nil

    local okPick, errPick = pcall(C_Container.PickupContainerItem, bag, slot)
    local onCursor = CursorItemID()
    if not okPick or onCursor ~= SHARD then
        if CursorHasItem() then ClearCursor() end
        extra.err = not okPick and Peon.S(errPick) or nil
        return Record(way, combat, false, onCursor and L.P_WRONG_ITEM or L.P_PICKUP_FAIL, extra)
    end

    local okDel, errDel = pcall(DeleteCursorItem)
    if CursorHasItem() then ClearCursor() end   -- nicht vernichtet: zurueck an seinen Platz
    extra.err = not okDel and Peon.S(errDel) or nil

    C_Timer.After(CHECK_DELAY, function()
        ns.mod:Call("Pruefung", function()
            local _, after = P.ScanBags()
            local blocked = lastBlocked and lastBlocked.func or nil
            extra.blocked = blocked
            local done = after < before
            local why = done and L.P_DONE or (blocked and L.P_BLOCKED .. " (" .. blocked .. ")")
                or (extra.err and L.P_ERROR .. ": " .. extra.err) or L.P_NOT_DONE
            Record(way, combat, done, why, extra)
        end)
    end)
end

---------------------------------------------------------------------------
-- Wege
---------------------------------------------------------------------------
local function TryLater(way)
    C_Timer.After(1, function()
        if armed then ns.mod:Call("Pruefung", P.TryDelete, way) end
    end)
end

local function OnHook(name)
    if not armed then return end
    local p = DB()
    if p then p.hooks[name] = (p.hooks[name] or 0) + 1 end
    P.TryDelete("action", name)
end

local function InstallHooks()
    if hooked then return end
    hooked = true
    for _, name in ipairs(HOOK_FUNCS) do
        if type(rawget(_G, name)) == "function" then
            hooksecurefunc(name, function() ns.mod:Call("Pruefung", OnHook, name) end)
        end
    end
    for i = 1, 12 do
        local b = rawget(_G, "ActionButton" .. i)
        if b and b.HookScript then
            b:HookScript("PostClick", function() ns.mod:Call("Pruefung", OnHook, "PostClick") end)
        end
    end
end

-- Klick auf den Knopf im Fenster (Guide.lua)
function P.ClickTest()
    if not armed then P.Start() end
    P.TryDelete("click")
end

-- Makro mit /click anlegen und an den Mauszeiger haengen, damit es auf die Leiste gezogen werden kann
local MACRO_NAME = "PeonSplitter"
local MACRO_BODY = "/click PeonClassBuddyShard"
function P.MakeMacro()
    local m = ns.mod
    if InCombat() then return m:Print(L.P_MACRO_COMBAT) end
    local index = GetMacroIndexByName and GetMacroIndexByName(MACRO_NAME) or 0
    if not index or index == 0 then
        local ok, res = pcall(CreateMacro, MACRO_NAME, "INV_Misc_QuestionMark", MACRO_BODY, true)
        if not ok or not res then return m:Print(L.P_MACRO_FAIL:format(MACRO_BODY)) end
        index = res
    end
    if PickupMacro then pcall(PickupMacro, index) end
    m:Print(L.P_MACRO_DONE)
end

local function MakeMacroButton()
    if macroBtn then return end
    macroBtn = CreateFrame("Button", "PeonClassBuddyShard", UIParent)
    macroBtn:Hide()
    macroBtn:SetScript("OnClick", function()
        ns.mod:Call("Pruefung", function()
            if not armed then P.Start() end
            P.TryDelete("macro")
        end)
    end)
end

---------------------------------------------------------------------------
-- Uebersicht
---------------------------------------------------------------------------
local function FamilyOfShard()
    local fn = (C_Item and C_Item.GetItemFamily) or rawget(_G, "GetItemFamily")
    if not fn then return nil end
    local ok, v = pcall(fn, SHARD)
    return ok and Num(v) or nil
end

function P.Overview()
    local p = DB()
    local bags, total = P.ScanBags()
    local family = FamilyOfShard()
    local class = ns.PlayerClass()
    local apis = {}
    for _, name in ipairs({ "DeleteCursorItem", "UseAction", "ActionButtonDown", "CastSpellByName" }) do
        apis[#apis + 1] = name .. "=" .. (type(rawget(_G, name)) == "function" and "ja" or "nein")
    end
    apis[#apis + 1] = "ActionButton1=" .. (rawget(_G, "ActionButton1") and "ja" or "nein")
    local m = ns.mod
    m:Print(L.P_INFO_CLASS:format(tostring(class), total, tostring(family)))
    for _, b in ipairs(bags) do
        if b.slots > 0 then m:Print(L.P_INFO_BAG:format(b.bag, b.slots, b.free, tostring(b.family), b.shards)) end
    end
    m:Print(L.P_INFO_API:format(table.concat(apis, ", ")))
    if class ~= "WARLOCK" then m:Print(L.P_NOT_WARLOCK) end
    if p then
        p.info = { class = class, shards = total, family = family, bags = bags, apis = table.concat(apis, ", "),
            build = select(2, GetBuildInfo()), at = time() }
    end
end

function P.Report()
    local p = DB()
    local m = ns.mod
    if not p or next(p.results) == nil then return m:Print(L.P_NONE) end
    m:Print(L.P_HEAD)
    for _, way in ipairs({ "event", "click", "macro", "action" }) do
        for _, combat in ipairs({ false, true }) do
            local r = p.results[way .. "_" .. StateKey(combat)]
            if r then
                local text = tostring(r.why) .. (r.hook and (" [" .. r.hook .. "]") or "")
                m:Print("   " .. L.P_RESULT:format(L.P_WAY[way], combat and L.P_COMBAT or L.P_FREE, text))
            end
        end
    end
    local seen = {}
    for name, n in pairs(p.hooks) do seen[#seen + 1] = name .. " " .. n .. "x" end
    table.sort(seen)
    if #seen > 0 then m:Print("   " .. L.P_HOOKS:format(table.concat(seen, ", "))) end
end

---------------------------------------------------------------------------
-- Befehl
---------------------------------------------------------------------------
function P.Start()
    armed = true
    InstallHooks()
    MakeMacroButton()
    if ns.Guide then ns.Guide.Show() end
    P.Overview()
    local m = ns.mod
    m:Print(L.P_START)
    for _, line in ipairs(L.P_STEPS) do m:Print("   " .. line) end
    TryLater("event")
end

function P.Stop()
    armed = false
    ns.mod:Print(L.P_OFF)
end

function P.Slash(rest)
    if rest == "ergebnis" or rest == "result" or rest == "results" then
        P.Report()
    elseif rest == "leeren" or rest == "clear" then
        local p = DB()
        if p then p.results, p.hooks = {}, {} end
        ns.mod:Print(L.P_CLEARED)
    elseif rest == "aus" or rest == "off" or rest == "stop" then
        P.Stop()
    elseif rest == "senden" or rest == "send" then
        P.Send()
    elseif rest == "" and ns.Guide and ns.Guide.Show() then
        -- Fenster fuehrt durch die Pruefung, gestartet wird mit dem Knopf
    else
        P.Start()
    end
end

function P.OnLogin()
    ns.mod:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, addon, func)
        if addon == ADDON_NAME then lastBlocked = { func = tostring(func), t = GetTime() } end
    end)
    ns.mod:RegisterEvent("ADDON_ACTION_FORBIDDEN", function(_, addon, func)
        if addon == ADDON_NAME then lastBlocked = { func = tostring(func), t = GetTime() } end
    end)
    -- Kampfbeginn: Weg ohne Tastendruck noch einmal, diesmal im Kampf
    ns.mod:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if armed then TryLater("event") end
    end)
end

-- fuer Tests
P._IsArmed = function() return armed end

---------------------------------------------------------------------------
-- Ergebnis ueber Peon_Feedback an den Peon Manager (Kern-API 22)
---------------------------------------------------------------------------
-- Kurzer Text mit allem, was fuer die Auswertung noetig ist. Keine Namen, nur Zahlen und Ja/Nein.
function P.BuildText()
    local p = DB() or { results = {}, hooks = {} }
    local info = p.info or {}
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    add(("Prüfung Seelensplitter: ClassBuddy %s, Build %s, Klasse %s"):format(tostring(ns.mod.version),
        tostring(info.build or select(2, GetBuildInfo())), tostring(info.class or ns.PlayerClass())))
    local bags = {}
    for _, b in ipairs(info.bags or {}) do
        if (b.slots or 0) > 0 then bags[#bags + 1] = ("%d:%d Plätze/%d frei/Typ %s/%d Splitter"):format(b.bag, b.slots, b.free, tostring(b.family), b.shards) end
    end
    add("Taschen: " .. (#bags > 0 and table.concat(bags, ", ") or "-"))
    add("Familie 6265: " .. tostring(info.family) .. ", Funktionen: " .. tostring(info.apis or "-"))
    for _, way in ipairs({ "event", "click", "macro", "action" }) do
        for _, combat in ipairs({ false, true }) do
            local key = way .. "_" .. StateKey(combat)
            local r = p.results[key]
            if r then
                add(("%s: %s (%s)%s%s"):format(key, r.ok and "ja" or "nein", tostring(r.why),
                    r.hook and (" Aufruf " .. r.hook) or "", r.blocked and (" gesperrt " .. r.blocked) or ""))
            else
                add(key .. ": nicht getestet")
            end
        end
    end
    local seen = {}
    for name, n in pairs(p.hooks or {}) do seen[#seen + 1] = name .. " " .. n .. "x" end
    table.sort(seen)
    add("Aufrufe beim Zaubern: " .. (#seen > 0 and table.concat(seen, ", ") or "keine"))
    return table.concat(lines, "\n")
end

-- true, wenn der Eintrag an Peon_Feedback ging
function P.Send()
    local m = ns.mod
    if not (Peon.AddFeedback and Peon.CanAddFeedback and Peon.CanAddFeedback()) then
        m:Print(L.P_SEND_NO_FEEDBACK)
        return false
    end
    local entry, err = Peon.AddFeedback({ module = ADDON_NAME, kind = "other", area = "Prüfung", prio = "high", text = P.BuildText() })
    if not entry then
        m:Print(L.P_SEND_FAIL:format(tostring(err)))
        return false
    end
    local p = DB()
    if p then p.sent = time() end
    m:Print(L.P_SEND_DONE)
    if ns.Guide then ns.Guide.Refresh() end
    return true
end

-- Knopf fuer das Makro gleich beim Laden, damit /click auch ohne vorherigen Start etwas findet
MakeMacroButton()
