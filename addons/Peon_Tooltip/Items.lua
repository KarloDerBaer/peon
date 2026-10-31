-- Peon_Tooltip - Items.lua
-- Gegenstands-Tooltips: Teile (Blizzard-Teile, je Addon ein Teil) erkennen, ordnen, ausblenden,
-- Trennlinien/Leerraum einfuegen; Qualitaet fuer die Rahmenfarbe merken.
-- Konzept: Peon_Tooltip_Konzept.md (Projektordner).
--
-- Ablauf je Tooltip:
--  1. Jede neue Zeile (AddLine/AddDoubleLine) bekommt ihre Herkunft: das erste Addon in der
--     Aufrufkette (debugstack), ohne Peon_Tooltip und ohne Blizzard_*.
--  2. Zeilen aus den Tooltip-Daten des Spiels markiert ein Zeilen-Nachlauf (AddLinePostCall) als
--     Blizzard, mit der Zeilenart (ItemName, ItemBinding, SellPrice ...).
--  3. Der Gegenstands-Nachlauf (AddTooltipPostCall, beim Einloggen angemeldet = als letzter) liest
--     alle Zeilen, teilt sie in Teile, merkt neue Teile und schreibt die Zeilen in der gewuenschten
--     Reihenfolge zurueck in dieselben Textfelder. Ueberzaehlige Zeilen werden geleert.
--  4. Kommen danach noch Zeilen dazu (spaete Addons), wird neu geordnet – sofort, sobald der
--     Tooltip angezeigt wird (Show/SetShown), sonst im naechsten Bild. Spaete Zeilen von Blizzard
--     selbst (Vergleich: "Wenn Ihr diesen Gegenstand ersetzt ...") bleiben immer unten (ab 0.6.1;
--     vorher flackerte der Vergleichs-Tooltip, weil Blizzard ihn alle 0,2 Sek. neu aufbaut).
--  5. Maximale Breite (ab 0.7.1): zu lange Zeilen bekommen Zeilenumbrueche. Ohne das wurde z. B. ein
--     langer Set-Bonus nach dem Umschreiben nicht mehr umgebrochen; der Vergleichs-Tooltip wurde so
--     breit, dass Blizzard den Gegenstands-Tooltip zur Seite schob – bei jedem Neuaufbau (Flackern).
--  6. Geheime Aufrufkette (ab 0.7.2): In Forever liefert debugstack im Kampf/in Instanzen teils einen
--     geheimen Text. Der wird nicht durchsucht (sonst Lua-Fehler), der Tooltip bleibt dann unangetastet.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
local IsSecret = ns.IsSecret

local ipairs, pairs, type, tostring, pcall = ipairs, pairs, type, tostring, pcall
local tinsert, tremove = table.insert, table.remove

---------------------------------------------------------------------------
-- Teile
---------------------------------------------------------------------------
-- Blizzard-Teile in der natuerlichen Reihenfolge eines Gegenstands-Tooltips
local BLIZZ = { "b:head", "b:dura", "b:req", "b:effects", "b:set", "b:desc", "b:price" }
local BLIZZ_SET = {}
for _, k in ipairs(BLIZZ) do BLIZZ_SET[k] = true end
ns.ITEM_BLIZZ_PARTS = BLIZZ

-- Zeilenart des Spiels (Name in Enum.TooltipDataLineType) -> Teil
local TYPE_PART = {
    ItemBinding = "b:head", EquipSlot = "b:head", ItemEnchantmentPermanent = "b:head",
    GemSocket = "b:head", GemSocketEnchantment = "b:head", ProfessionCraftingQuality = "b:head",
    ItemLevel = "b:head", ItemUpgradeLevel = "b:head",
    RestrictedRaceClass = "b:req", RestrictedFaction = "b:req", RestrictedSkill = "b:req",
    RestrictedPvPMedal = "b:req", RestrictedReputation = "b:req", RestrictedSpellKnown = "b:req",
    RestrictedLevel = "b:req", RestrictedArena = "b:req", RestrictedBg = "b:req",
    SellPrice = "b:price",
    ToyEffect = "b:effects", ToyDuration = "b:effects",
    ToyFlavorText = "b:desc", ToyDescription = "b:desc", ToySource = "b:desc",
}
local BLANK_TYPES = { Blank = true, Separator = true }

local TYPE_NAME = {}
local function BuildTypeNames()
    local e = Enum and Enum.TooltipDataLineType
    if type(e) ~= "table" then return end
    for k, v in pairs(e) do TYPE_NAME[v] = k end
end
BuildTypeNames()

-- Blizzard-Formattext ("Benötigt Stufe %d") -> Suchmuster
local function Pat(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local s = fmt:gsub("%%[%d%.%$]*[sdf]", "\1")
    s = s:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    s = s:gsub("\1", ".-")
    return "^" .. s .. "$"
end
local function Pats(...)
    local t = {}
    for i = 1, select("#", ...) do
        local p = Pat((select(i, ...)))
        if p then t[#t + 1] = p end
    end
    return t
end
local function Prefixes(...)
    local t = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and v ~= "" then t[#t + 1] = v end
    end
    return t
end

local P = {}
local function BuildPatterns()
    P.req = Pats(ITEM_MIN_LEVEL, ITEM_CLASSES_ALLOWED, ITEM_RACES_ALLOWED, ITEM_REQ_SKILL,
        ITEM_REQ_REPUTATION, ITEM_MIN_SKILL, ITEM_REQ_SPECIALIZATION, ITEM_REQ_ALLIANCE, ITEM_REQ_HORDE)
    P.dura = Pats(DURABILITY_TEMPLATE)
    P.setName = Pats(ITEM_SET_NAME)
    P.setBonus = Pats(ITEM_SET_BONUS, ITEM_SET_BONUS_GRAY)
    P.effects = Prefixes(ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC)
    P.sell = (type(SELL_PRICE) == "string" and SELL_PRICE ~= "") and (SELL_PRICE .. ":") or nil
end
BuildPatterns()

local function MatchAny(text, list)
    for _, p in ipairs(list) do
        if text:find(p) then return true end
    end
    return false
end
local function StartsAny(text, list)
    for _, p in ipairs(list) do
        if text:sub(1, #p) == p then return true end
    end
    return false
end

local function IsSep(k) return type(k) == "string" and k:sub(1, 2) == "s:" end
local function SepKind(k) return k:match("^s:(%a+):") end
ns.ItemIsSep, ns.ItemSepKind = IsSep, SepKind

---------------------------------------------------------------------------
-- Addon-Titel
---------------------------------------------------------------------------
local function StripColors(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function AddonTitle(folder)
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local t = fn and fn(folder, "Title")
    if type(t) == "string" and t ~= "" then return StripColors(t) end
    return folder
end

---------------------------------------------------------------------------
-- Reihenfolge, bekannte Teile
---------------------------------------------------------------------------
local function DB() return mod.db end

-- Blizzard-Teile vollstaendig, bekannte Addons dabei, keine doppelten/ungueltigen Eintraege
function ns.ItemEnsureOrder()
    local db = DB()
    if not db then return end
    if type(db.itemOrder) ~= "table" then db.itemOrder = {} end
    if type(db.itemHidden) ~= "table" then db.itemHidden = {} end
    if type(db.itemKnown) ~= "table" then db.itemKnown = {} end
    local order, seen, clean = db.itemOrder, {}, {}
    for _, k in ipairs(order) do
        if type(k) == "string" and not seen[k]
            and (BLIZZ_SET[k] or IsSep(k) or (k:sub(1, 2) == "a:" and db.itemKnown[k])) then
            seen[k] = true
            clean[#clean + 1] = k
        end
    end
    -- fehlende Blizzard-Teile hinter ihren natuerlichen Vorgaenger
    for i, k in ipairs(BLIZZ) do
        if not seen[k] then
            local pos = 0
            for j = i - 1, 1, -1 do
                for x, v in ipairs(clean) do
                    if v == BLIZZ[j] then pos = x break end
                end
                if pos > 0 then break end
            end
            tinsert(clean, pos + 1, k)
            seen[k] = true
        end
    end
    -- bekannte Addons, die fehlen, hinten anhaengen (in der Reihenfolge, in der sie entdeckt wurden)
    local missing = {}
    for k, info in pairs(db.itemKnown) do
        if not seen[k] and type(info) == "table" then missing[#missing + 1] = k end
    end
    table.sort(missing, function(a, b)
        return (db.itemKnown[a].seq or 0) < (db.itemKnown[b].seq or 0)
    end)
    for _, k in ipairs(missing) do clean[#clean + 1] = k end
    -- an Ort und Stelle ersetzen (andere halten evtl. die Tabelle)
    for i = #order, 1, -1 do order[i] = nil end
    for i, k in ipairs(clean) do order[i] = k end
end

-- Neue Teile eines Tooltips in die Reihenfolge aufnehmen; natural = Teile in Tooltip-Reihenfolge
local function Discover(natural)
    local db = DB()
    local order, known = db.itemOrder, db.itemKnown
    local now = time and time() or 0
    for i, k in ipairs(natural) do
        if k:sub(1, 2) == "a:" then
            local info = known[k]
            if type(info) ~= "table" then
                local seq = 0
                for _, v in pairs(known) do
                    if type(v) == "table" and (v.seq or 0) > seq then seq = v.seq end
                end
                info = { seq = seq + 1 }
                known[k] = info
            end
            info.title = AddonTitle(k:sub(3))
            info.seen = now
        end
        local inOrder = false
        for _, v in ipairs(order) do
            if v == k then inOrder = true break end
        end
        if not inOrder then
            -- hinter den naechsten Vorgaenger dieses Tooltips, der schon in der Liste steht
            local pos = 0
            for j = i - 1, 1, -1 do
                for x, v in ipairs(order) do
                    if v == natural[j] then pos = x break end
                end
                if pos > 0 then break end
            end
            tinsert(order, pos + 1, k)
            if ns.ItemOptionsChanged then ns.ItemOptionsChanged() end
        end
    end
end

-- Natuerliche Reihenfolge (Standard): Blizzard, dann Addons in Entdeckungsreihenfolge
function ns.ItemResetOrder()
    local db = DB()
    if not db then return end
    for i = #db.itemOrder, 1, -1 do db.itemOrder[i] = nil end
    db.itemHidden = {}
    ns.ItemEnsureOrder()
end

function ns.ItemAddSeparator(kind, afterKey)
    local db = DB()
    ns.ItemEnsureOrder()
    db.itemSepId = (tonumber(db.itemSepId) or 0) + 1
    local key = "s:" .. kind .. ":" .. db.itemSepId
    local pos = #db.itemOrder
    if afterKey then
        for i, v in ipairs(db.itemOrder) do
            if v == afterKey then pos = i break end
        end
    end
    tinsert(db.itemOrder, pos + 1, key)
    return key
end

function ns.ItemMove(key, dir)
    local order = DB().itemOrder
    for i, v in ipairs(order) do
        if v == key then
            local j = i + dir
            if j >= 1 and j <= #order then order[i], order[j] = order[j], order[i] end
            return
        end
    end
end

function ns.ItemRemove(key)
    local db = DB()
    for i, v in ipairs(db.itemOrder) do
        if v == key then tremove(db.itemOrder, i) break end
    end
    db.itemHidden[key] = nil
    if key:sub(1, 2) == "a:" then db.itemKnown[key] = nil end
end

-- Anzeigename eines Teils
function ns.ItemPartLabel(key)
    if key == "tail" then return L.PART_TAIL end
    if BLIZZ_SET[key] then return L["PART_" .. key:sub(3):upper()] or key end
    if IsSep(key) then
        return SepKind(key) == "line" and L.PART_SEP_LINE or L.PART_SEP_SPACE
    end
    local info = DB().itemKnown[key]
    return (type(info) == "table" and info.title) or key:sub(3)
end

function ns.ItemPartLoaded(key)
    if key:sub(1, 2) ~= "a:" then return true end
    return Peon.IsAddOnLoaded(key:sub(3)) and true or false
end

---------------------------------------------------------------------------
-- Zustand je Tooltip
---------------------------------------------------------------------------
local recs = {}
ns.itemRecs = recs

local function NewRec(tt)
    local rec = { tt = tt, src = {}, btype = {}, late = {}, marked = 0, touched = {}, seps = {} }
    recs[tt] = rec
    return rec
end

local function Active()
    local db = DB()
    return db and (db.itemParts or db.itemBorder == "quality" or db.itemWrap or ns.partsDebug)
end

-- Herkunft der gerade hinzugefuegten Zeile: erstes Addon in der Aufrufkette.
-- Zweiter Rueckgabewert true: Forever lieferte die Aufrufkette als geheimen Text (Kampf, Instanz);
-- der darf nicht durchsucht werden (0.7.2), die Herkunft ist dann unbekannt.
local function CallerAddon()
    if type(debugstack) ~= "function" then return nil end
    local st = debugstack(2, 30, 0)
    if IsSecret(st) then return nil, true end
    if type(st) ~= "string" then return nil end
    for folder in st:gmatch("[Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee][/\\][Aa][Dd][Dd][Oo][Nn][Ss][/\\]([^/\\%]\"]+)") do
        if folder ~= ADDON_NAME and not folder:find("^Blizzard_") then return folder end
    end
    return nil
end
ns.ItemCallerAddon = CallerAddon

local Arrange   -- weiter unten

local function ScheduleArrange(rec)
    if rec.scheduled then return end
    rec.scheduled = true
    local function run()
        rec.scheduled = false
        if recs[rec.tt] == rec and rec.done and rec.isItem and rec.pending then
            mod:Call("Items", Arrange, rec.tt, rec)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end

local function OnAddLine(tt)
    local rec = recs[tt]
    if not rec or rec.busy or not Active() then return end
    if tt.IsForbidden and tt:IsForbidden() then return end
    local n = tt:NumLines()
    if type(n) ~= "number" then return end
    local from, secret = CallerAddon()
    if secret then rec.secretSrc = true end   -- Herkunft unbekannt: diesen Tooltip nicht ordnen
    rec.src[n] = from or false
    -- Zeile nach dem Ordnen (spaetes Addon oder Blizzards Vergleich): nochmal ordnen, sobald der
    -- Tooltip gezeigt wird (OnShowCall), spaetestens im naechsten Bild
    if rec.done and rec.isItem then
        if not rec.src[n] then rec.late[n] = true end
        rec.pending = true
        ScheduleArrange(rec)
    end
end

local function HideSeps(rec)
    for _, tex in ipairs(rec.seps) do tex:Hide() end
end

-- Tooltip wird geleert: Schrift/Umbruch der veraenderten Zeilen zuruecksetzen, Zustand neu
local function OnCleared(tt)
    local rec = recs[tt]
    if not rec then return end
    local name = tt:GetName()
    if name then
        for j, t in pairs(rec.touched) do
            local fs = _G[name .. "TextLeft" .. j]
            if fs then
                if t.font and fs.SetFontObject then fs:SetFontObject(t.font) end
                if t.wrap ~= nil and fs.SetWordWrap then fs:SetWordWrap(t.wrap) end
            end
        end
    end
    HideSeps(rec)
    local seps = rec.seps
    rec = NewRec(tt)
    rec.seps = seps
end

-- Zeilen aus den Tooltip-Daten: Blizzard mit Zeilenart
local function OnLinePost(tt, lineData)
    local rec = recs[tt]
    if not rec or rec.busy then return end
    local n = tt:NumLines()
    if type(n) ~= "number" then return end
    local t = lineData and lineData.type
    local tname = (t ~= nil and not IsSecret(t)) and TYPE_NAME[t] or nil
    for i = rec.marked + 1, n do
        rec.src[i] = "Blizzard"
        rec.btype[i] = tname
    end
    rec.marked = n
end

---------------------------------------------------------------------------
-- Qualitaet (Rahmenfarbe)
---------------------------------------------------------------------------
local function QualityOf(tt, data)
    local link
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local ok, _, l = pcall(TooltipUtil.GetDisplayedItem, tt)
        if ok then link = l end
    end
    if not link and tt.GetItem then
        local ok, _, l = pcall(tt.GetItem, tt)
        if ok then link = l end
    end
    if IsSecret(link) or type(link) ~= "string" then link = nil end
    local q
    if link then
        local getInfo = C_Item and C_Item.GetItemInfo
        if getInfo then q = select(3, getInfo(link)) end
        if q == nil then q = tonumber(link:match("|cnIQ(%d+):")) end
    end
    if q == nil and data and C_Item and C_Item.GetItemQualityByID then
        local id = data.id
        if id ~= nil and not IsSecret(id) then q = C_Item.GetItemQualityByID(id) end
    end
    if IsSecret(q) then return nil end
    return tonumber(q)
end

function ns.QualityColor(q)
    if q == nil then return nil end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if type(r) == "number" then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
end

-- Rahmenfarbe fuer einen Gegenstands-Tooltip (nil = keine eigene Farbe)
function ns.ItemBorderColor(tt)
    local db = DB()
    if not db or db.itemBorder ~= "quality" then return nil end
    local rec = recs[tt]
    if not rec or not rec.isItem or rec.quality == nil then return nil end
    return ns.QualityColor(rec.quality)
end

---------------------------------------------------------------------------
-- Zeilen lesen
---------------------------------------------------------------------------
local function MoneyFrames(tt, name)
    local list = {}
    local n = tonumber(tt.shownMoneyFrames) or 0
    for i = 1, n do
        local mf = _G[name .. "MoneyFrame" .. i]
        if mf and mf.GetPoint then list[#list + 1] = mf end
    end
    return list
end

-- Zeile i lesen; false bei geheimem Text
local function Capture(tt, name, rec, i, money)
    local l = _G[name .. "TextLeft" .. i]
    local r = _G[name .. "TextRight" .. i]
    if not l then return nil end
    local lt = l:GetText()
    if IsSecret(lt) then return false end
    local e = { src = rec.src[i], bt = rec.btype[i], lt = lt, late = rec.late[i] }
    e.lr, e.lg, e.lb, e.la = l:GetTextColor()
    e.lfont = l.GetFontObject and l:GetFontObject() or nil
    if l.CanWordWrap then e.lw = l:CanWordWrap() end
    if r and r:IsShown() then
        local rt = r:GetText()
        if IsSecret(rt) then return false end
        if rt and rt ~= "" then
            e.rt = rt
            e.rr, e.rg, e.rb, e.ra = r:GetTextColor()
            e.rfont = r.GetFontObject and r:GetFontObject() or nil
        end
    end
    for _, mf in ipairs(money) do
        local p, rel, rp, x, y = mf:GetPoint(1)
        if rel == l and mf:IsShown() then
            e.money = e.money or {}
            e.money[#e.money + 1] = { mf, p, rp, x, y }
        end
    end
    if IsSecret(e.lr) or IsSecret(e.rr) then return false end
    return e
end

local function IsBlank(e)
    return (e.lt == nil or e.lt:find("^%s*$") ~= nil) and (e.rt == nil or e.rt:find("^%s*$") ~= nil)
        and not e.money
end

local function IsGreen(e)
    return type(e.lr) == "number" and e.lg > 0.9 and e.lr < 0.3 and e.lb < 0.3
end

local function IsDesc(e, text)
    local first = text:sub(1, 1)
    if first == '"' or text:sub(1, 3) == "\226\128\158" then return true end  -- " oder „
    return false
end

---------------------------------------------------------------------------
-- Zeilen in Teile einteilen; liefert Anzahl fester Zeilen oben (Name)
---------------------------------------------------------------------------
local function Classify(snap)
    local pinned = 1
    for i, e in ipairs(snap) do
        if e.bt == "ItemName" then pinned = i break end
    end
    local prev, inSet, inPrice = "b:head", false, false
    for i, e in ipairs(snap) do
        local text = e.lt or ""
        if i <= pinned then
            e.key = "pin"
        elseif e.late then
            e.key = "tail"                              -- spaete Blizzard-Zeilen (Vergleich): immer unten
        elseif P.sell and text:sub(1, #P.sell) == P.sell then
            e.key, inPrice = "b:price", true            -- auch Verkaufspreis als Text (BagBrother)
        elseif inPrice and e.src ~= "Blizzard" and text:find("^%s%s") then
            e.key = "b:price"                           -- Min/Max-Zeilen darunter
        elseif e.src and e.src ~= "Blizzard" then
            e.key, inPrice, inSet = "a:" .. e.src, false, false
        else
            inPrice = false
            local k
            local tn = e.bt
            if (tn and BLANK_TYPES[tn]) or IsBlank(e) then
                k = "blank"
            elseif tn and TYPE_PART[tn] then
                k = TYPE_PART[tn]
            elseif MatchAny(text, P.setName) then
                k, inSet = "b:set", true
            elseif MatchAny(text, P.setBonus) or (inSet and text:find("^%s")) then
                k = "b:set"
            elseif MatchAny(text, P.dura) then
                k = "b:dura"
            elseif MatchAny(text, P.req) then
                k = "b:req"
            elseif StartsAny(text, P.effects) then
                k = "b:effects"
            elseif IsDesc(e, text) then
                k = "b:desc"
            elseif IsGreen(e) and not inSet then
                k = "b:effects"
            else
                k = prev
            end
            if k ~= "b:set" and k ~= "blank" then inSet = false end
            if k ~= "blank" then prev = k end
            e.key = k
        end
    end
    -- leere Blizzard-Zeilen gehoeren zum folgenden Teil (fallen mit ihm weg)
    for i, e in ipairs(snap) do
        if e.key == "blank" then
            local k
            for j = i + 1, #snap do
                if snap[j].key ~= "blank" then k = snap[j].key break end
            end
            if not k or k == "pin" then
                for j = i - 1, 1, -1 do
                    if snap[j].key ~= "blank" then k = snap[j].key break end
                end
            end
            e.key = (k and k ~= "pin") and k or "b:head"
        end
    end
    return pinned
end
ns.ItemClassify = Classify

---------------------------------------------------------------------------
-- Gewuenschte Reihenfolge der Zeilen
---------------------------------------------------------------------------
local function BuildOutput(snap, pinned)
    local db = DB()
    local groups, natural = {}, {}
    local out = {}
    local tail = {}
    for i, e in ipairs(snap) do
        if i <= pinned then
            out[#out + 1] = e
        elseif e.key == "tail" then
            tail[#tail + 1] = e
        else
            local g = groups[e.key]
            if not g then
                g = {}
                groups[e.key] = g
                natural[#natural + 1] = e.key
            end
            g[#g + 1] = e
        end
    end
    Discover(natural)
    if not db.itemParts then
        -- nur erkennen, nichts aendern
        for i = pinned + 1, #snap do out[#out + 1] = snap[i] end
        return out, natural
    end
    local hidden = db.itemHidden
    local pending, used = {}, {}
    for _, k in ipairs(db.itemOrder) do
        if IsSep(k) then
            local kind = SepKind(k)
            local dup = false
            for _, p in ipairs(pending) do
                if p == kind then dup = true end
            end
            if not dup then pending[#pending + 1] = kind end
        elseif groups[k] then
            used[k] = true
            if not hidden[k] then
                for _, kind in ipairs(pending) do out[#out + 1] = { sep = kind } end
                pending = {}
                for _, e in ipairs(groups[k]) do out[#out + 1] = e end
            end
        end
    end
    for _, k in ipairs(natural) do      -- sollte nicht vorkommen (Discover nimmt alles auf)
        if not used[k] and not hidden[k] then
            for _, e in ipairs(groups[k]) do out[#out + 1] = e end
        end
    end
    for _, e in ipairs(tail) do out[#out + 1] = e end
    return out, natural
end

---------------------------------------------------------------------------
-- Schreiben
---------------------------------------------------------------------------
local function Touch(rec, j, fs)
    if rec.touched[j] then return end
    rec.touched[j] = {
        font = fs.GetFontObject and fs:GetFontObject() or nil,
        wrap = fs.CanWordWrap and fs:CanWordWrap() or nil,
    }
end

local function SepTexture(rec, tt, idx)
    local tex = rec.seps[idx]
    if not tex then
        tex = tt:CreateTexture(nil, "ARTWORK")
        if tex.SetColorTexture then tex:SetColorTexture(0.8, 0.8, 0.8, 0.35) end
        tex:SetHeight(1)
        rec.seps[idx] = tex
    end
    return tex
end

local function WriteLine(rec, tt, name, j, e)
    local l = _G[name .. "TextLeft" .. j]
    local r = _G[name .. "TextRight" .. j]
    if not l then return end
    Touch(rec, j, l)
    if e.sep then
        l:SetText(" ")
        l:SetTextColor(1, 1, 1, 1)
    else
        if e.lfont and l.SetFontObject then l:SetFontObject(e.lfont) end
        if e.lw ~= nil and l.SetWordWrap then l:SetWordWrap(e.lw) end
        l:SetText(e.lt)
        l:SetTextColor(e.lr or 1, e.lg or 1, e.lb or 1, e.la or 1)
    end
    l:Show()
    if r then
        if e.rt then
            if e.rfont and r.SetFontObject then r:SetFontObject(e.rfont) end
            r:SetText(e.rt)
            r:SetTextColor(e.rr or 1, e.rg or 1, e.rb or 1, e.ra or 1)
            r:Show()
        else
            r:SetText(nil)
            r:Hide()
        end
    end
end

local function ClearLine(name, j)
    local l = _G[name .. "TextLeft" .. j]
    local r = _G[name .. "TextRight" .. j]
    if l then l:SetText(nil) end
    if r then r:SetText(nil); r:Hide() end
end

local function DebugDump(out, snap)
    ns.partsDebug = nil
    mod:Print(L.MSG_PARTS_HEAD)
    for i, e in ipairs(snap) do
        local text = e.lt or ""
        if #text > 40 then text = text:sub(1, 40) .. "…" end
        local part = e.key == "pin" and L.ITEM_NAME_FIXED or ns.ItemPartLabel(e.key)
        mod:Print(("%d  |cff8ccf4d%s|r  %s%s"):format(i, part,
            e.bt and ("|cff888888[" .. e.bt .. "]|r ") or "", text))
    end
    local hidden = 0
    for _, e in ipairs(snap) do
        local found = false
        for _, o in ipairs(out) do if o == e then found = true break end end
        if not found then hidden = hidden + 1 end
    end
    mod:Print((L.MSG_PARTS_FOOT):format(#snap, hidden))
end

---------------------------------------------------------------------------
-- Maximale Breite (ab 0.7.1)
---------------------------------------------------------------------------
local measure
-- Breite eines Textes in der Schrift der Zeile fs (nil = nicht messbar)
local function TextWidth(fs, text)
    if not measure then
        if not (UIParent and UIParent.CreateFontString) then return nil end
        measure = UIParent:CreateFontString(nil, "BACKGROUND")
        if measure.SetAlpha then measure:SetAlpha(0) end
        if measure.SetPoint then measure:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -100, 100) end
    end
    local font, size, flags
    if fs.GetFont then font, size, flags = fs:GetFont() end
    if type(font) == "string" and type(size) == "number" and measure.SetFont then
        measure:SetFont(font, size, flags or "")
    elseif fs.GetFontObject and measure.SetFontObject then
        local fo = fs:GetFontObject()
        if fo then measure:SetFontObject(fo) end
    end
    measure:SetText(text)
    local w = measure.GetStringWidth and measure:GetStringWidth()
    return type(w) == "number" and w or nil
end
ns.ItemTextWidth = TextWidth

-- Text so umbrechen, dass keine Zeile breiter als maxW ist; nil = nichts zu tun
local function WrapText(fs, text, maxW)
    local out, changed = {}, false
    for seg in (text .. "\n"):gmatch("(.-)\n") do
        local w = TextWidth(fs, seg)
        if not w then return nil end
        if w <= maxW or seg:find("|H", 1, true) then   -- Links nie zerteilen
            out[#out + 1] = seg
        else
            local indent, rest = seg:match("^(%s*)(.-)%s*$")
            local cur
            for word in rest:gmatch("%S+") do
                local cand = cur and (cur .. " " .. word) or (indent .. word)
                local cw = cur and TextWidth(fs, cand) or 0
                if cur and cw and cw > maxW then
                    out[#out + 1] = cur
                    cur = indent .. word
                    changed = true
                else
                    cur = cand
                end
            end
            out[#out + 1] = cur or seg
        end
    end
    if not changed then return nil end
    return table.concat(out, "\n")
end
ns.ItemWrapText = WrapText

local function MaxWidth()
    local db = DB()
    if not db or not db.itemWrap then return nil end
    return tonumber(db.itemMaxWidth)
end

-- alle einfachen Zeilen (ohne rechte Spalte) auf die maximale Breite bringen; true = geaendert
local function WrapLines(tt, name)
    local maxW = MaxWidth()
    if not maxW then return false end
    local changed = false
    for j = 1, tt:NumLines() do
        local l = _G[name .. "TextLeft" .. j]
        local r = _G[name .. "TextRight" .. j]
        local rt = nil
        if r and r:IsShown() then rt = r:GetText() end
        if l and l:IsShown() and (rt == nil or (not IsSecret(rt) and rt == "")) then
            local t = l:GetText()
            if not IsSecret(t) and type(t) == "string" and #t > 10 then
                local nt = WrapText(l, t, maxW)
                if nt then
                    l:SetText(nt)
                    changed = true
                end
            end
        end
    end
    return changed
end

function Arrange(tt, rec)
    local db = DB()
    if not db or (tt.IsForbidden and tt:IsForbidden()) then return end
    local name = tt:GetName()
    if not name then return end
    local n = tt:NumLines()
    if type(n) ~= "number" or n < 1 then return end
    rec.pending = false
    if rec.secretSrc then return end       -- Herkunft geheim: nichts anfassen, Tooltip bleibt wie von Blizzard
    ns.ItemEnsureOrder()

    -- Zeilen lesen: beim ersten Mal alle, danach nur neu hinzugekommene
    local money = MoneyFrames(tt, name)
    if not rec.snap then
        local snap = {}
        for i = 1, n do
            local e = Capture(tt, name, rec, i, money)
            if e == false then return end      -- geheime Werte: nichts anfassen
            if e then snap[#snap + 1] = e end
        end
        rec.snap, rec.total = snap, n
        rec.cur = {}
        for i, e in ipairs(snap) do rec.cur[i] = e end
    elseif n > rec.total then
        for i = rec.total + 1, n do
            local e = Capture(tt, name, rec, i, money)
            if e == false then return end
            if e then
                rec.snap[#rec.snap + 1] = e
                rec.cur[i] = e
            end
        end
        rec.total = n
    end
    local snap = rec.snap

    local pinned = Classify(snap)
    local out = BuildOutput(snap, pinned)
    if ns.partsDebug then DebugDump(out, snap) end

    -- nichts umzustellen? (umgebrochen wird trotzdem)
    local same = #out == rec.total
    if same then
        for j, e in ipairs(out) do
            if rec.cur[j] ~= e then same = false break end
        end
    end

    rec.busy = true
    local ok, err = pcall(function()
        if same then
            if WrapLines(tt, name) then tt:Show() end
            return
        end
        local total = rec.total
        while total < #out do
            tt:AddLine(" ")
            total = total + 1
        end
        HideSeps(rec)
        local sepIdx = 0
        for j, e in ipairs(out) do
            if rec.cur[j] ~= e then
                WriteLine(rec, tt, name, j, e)
                rec.cur[j] = e
            end
            if e.sep == "line" then
                sepIdx = sepIdx + 1
                local tex = SepTexture(rec, tt, sepIdx)
                local l = _G[name .. "TextLeft" .. j]
                tex:ClearAllPoints()
                tex:SetPoint("LEFT", l, "LEFT", 0, 0)
                tex:SetPoint("RIGHT", tt, "RIGHT", -10, 0)
                tex:Show()
            end
        end
        for j = #out + 1, total do
            if rec.cur[j] ~= false then
                ClearLine(name, j)
                rec.cur[j] = false
            end
        end
        rec.total = total
        -- Muenzanzeigen an ihre neue Zeile haengen, versteckte Teile: Muenzen weg
        local at = {}
        for j, e in ipairs(out) do at[e] = j end
        for _, e in ipairs(snap) do
            if e.money then
                for _, m in ipairs(e.money) do
                    local mf = m[1]
                    if at[e] then
                        mf:ClearAllPoints()
                        mf:SetPoint(m[2], _G[name .. "TextLeft" .. at[e]], m[3], m[4], m[5])
                        mf:Show()
                    else
                        mf:Hide()
                    end
                end
            end
        end
        WrapLines(tt, name)
        tt:Show()   -- Groesse neu berechnen
    end)
    rec.busy = false
    if not ok then error(err, 0) end
end

---------------------------------------------------------------------------
-- Gegenstands-Nachlauf
---------------------------------------------------------------------------
local function OnItemPost(tt, data)
    local rec = recs[tt]
    if not rec or rec.busy then return end
    if tt.IsForbidden and tt:IsForbidden() then return end
    rec.isItem = true
    local db = DB()
    if not db then return end
    if db.itemBorder == "quality" then
        local ok, q = pcall(QualityOf, tt, data)
        rec.quality = ok and q or nil
        if ns.ApplyItemBorder then ns.ApplyItemBorder(tt) end
    end
    rec.done = true
    if db.itemParts or ns.partsDebug or db.itemWrap then
        mod:Call("Items", Arrange, tt, rec)
    else
        -- nur bekannte Teile sammeln (fuer die Optionsliste)
        mod:Call("Items", function()
            local name = tt:GetName()
            if not name then return end
            local snap, money = {}, MoneyFrames(tt, name)
            for i = 1, tt:NumLines() do
                local e = Capture(tt, name, rec, i, money)
                if e == false then return end
                if e then snap[#snap + 1] = e end
            end
            ns.ItemEnsureOrder()
            BuildOutput(snap, Classify(snap))
        end)
    end
end

---------------------------------------------------------------------------
-- Anmelden
---------------------------------------------------------------------------
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
ns.ITEM_TOOLTIPS = TOOLTIPS

local function HookTooltip(tt)
    if not tt or recs[tt] or type(tt.HookScript) ~= "function" then return end
    NewRec(tt)
    hooksecurefunc(tt, "AddLine", OnAddLine)
    hooksecurefunc(tt, "AddDoubleLine", OnAddLine)
    tt:HookScript("OnTooltipCleared", OnCleared)
    -- spaete Zeilen sofort ordnen, wenn der Tooltip gezeigt wird (gleiches Bild, kein Flackern)
    local function OnShowCall(t, shown)
        if shown == false then return end
        local rec = recs[t]
        if rec and rec.pending and not rec.busy and rec.done and rec.isItem and Active() then
            mod:Call("Items", Arrange, t, rec)
        end
    end
    if type(tt.Show) == "function" then hooksecurefunc(tt, "Show", OnShowCall) end
    if type(tt.SetShown) == "function" then hooksecurefunc(tt, "SetShown", OnShowCall) end
    tt:HookScript("OnHide", function(t)
        local rec = recs[t]
        if rec then HideSeps(rec) end
    end)
    if tt ~= GameTooltip then
        tt:HookScript("OnShow", function(t)
            if ns.ApplyItemBorder then ns.ApplyItemBorder(t) end
        end)
    end
end

ns.HookItemTooltip = function(tt)        -- Beispiel-Tooltip der Optionen (ab 0.7)
    local ok, err = pcall(HookTooltip, tt)
    if not ok then mod:ReportError("Items", err) end
end

for _, n in ipairs(TOOLTIPS) do
    local tt = _G[n]
    if tt then
        local ok, err = pcall(HookTooltip, tt)
        if not ok then mod:ReportError("Items", err) end
    end
end

-- Nachlaeufe erst beim Einloggen anmelden: dann laufen sie nach denen aller anderen Addons
mod:On("LOGIN", function()
    BuildTypeNames()
    BuildPatterns()
    ns.ItemEnsureOrder()
    local TDP = TooltipDataProcessor
    if not (TDP and Enum and Enum.TooltipDataType) then return end
    local function tracked(tt) return tt and recs[tt] ~= nil end
    if TDP.AddLinePostCall then
        TDP.AddLinePostCall(TDP.AllTypes or "ALL", function(tt, lineData)
            if tracked(tt) then OnLinePost(tt, lineData) end
        end)
    end
    if TDP.AddTooltipPostCall and Enum.TooltipDataType.Item then
        TDP.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tracked(tt) then OnItemPost(tt, data) end
        end)
    end
end)

mod:On("INIT", function() ns.ItemEnsureOrder() end)
mod:On("RESET", function() ns.ItemEnsureOrder() end)

-- /ttp teile: naechsten Gegenstands-Tooltip im Chat aufschluesseln
function ns.ItemPartsDebug()
    ns.partsDebug = true
    mod:Print(L.MSG_PARTS_WAIT)
end
