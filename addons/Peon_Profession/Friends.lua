-- Peon_Profession - Friends.lua
-- ab 0.6.0 (KarloDerBaer, 18.11.2026, Konzept docs/konzepte/profession/Peon_Profession_Codex.md Abschnitt 8):
-- "Rezepte der Freunde". Blizzards Berufslinks lassen sich in Forever nicht beim anderen oeffnen. Ueber Peon.Comm
-- (Kern-API 24) tauschen Peon-Nutzer die Rezepte ihres eingeloggten Charakters aus. Gespeichert und im Codex gezeigt
-- werden nur Freunde (auch Battle.net) und Gildenmitglieder, 30 Tage ab dem letzten Mal gesehen.
--
-- Dienst "recipes", Version 1 (Regeln fuer Module: docs/konzepte/kern/Peon_Comm_Konzept.md Abschnitt 8):
--   { v, k = "s", f, p = { [Beruf] = { s, c, h } } }        Stand an alle (Kanal), f = erster nach dem Einloggen
--   { v, k = "q", p = { Beruf, ... } }                       Frage per Fluestern an den Absender eines Stands
--   { v, k = "l", p, s, h, i, n, ids = "b36,b36,..." }       Liste eines Berufs per Fluestern, in Teilen i/n
-- Speicher: PeonProfessionDB.friends[name klein] = { name, at, p = { [Beruf] = { s, h, ids = { [recipeID] = true } } } }

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local F = {}
ns.Friends = F

F.SVC          = "recipes"
F.VERSION      = 1
F.KEEP_DAYS    = 30
F.MAX_FRIENDS  = 200
F.MAX_IDS      = 1000
F.PER_PART     = 150
F.SEND_GAP     = 60      -- Stand hoechstens einmal pro Minute
F.PAUSE        = 600     -- Frage und Antwort je Spieler hoechstens alle 10 Minuten
F.CACHE_TIME   = 60      -- Freundesliste und Gilde so lange merken
F.FIRST_DELAY  = 45      -- erster Stand nach dem Einloggen (der Kern tritt nach etwa 18 Sekunden dem Kanal bei)

F.asked, F.answered, F.echoed = {}, {}, {}   -- Name klein -> Zeit (nur im Speicher)
F.incoming = {}                              -- Name klein .. ":" .. Beruf -> { h, n, parts = {} }

local function Now() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function Num(v) return type(v) == "number" and v == v and not Peon.IsSecret(v) end
local function Str(v) return type(v) == "string" and not Peon.IsSecret(v) and v ~= "" and v or nil end
local function Comm()
    local c = rawget(Peon, "Comm")
    if type(c) == "table" and (tonumber(Peon.API) or 0) >= 24 then return c end
    return nil
end

local function Store()
    local t = mod.db.friends
    if type(t) ~= "table" then t = {}; mod.db.friends = t end
    return t
end

local function Key(name)
    local c = Comm()
    local k = c and c.BaseName(name)
    if not k or #k > 60 then return nil end
    return k
end

---------------------------------------------------------------------------
-- Freunde und Gilde (Namen ohne Realm, klein), kurz gemerkt
---------------------------------------------------------------------------
function F.Circle()
    local now = Now()
    if F.circle and now - (F.circleAt or 0) < F.CACHE_TIME then return F.circle end
    local set = {}
    local function Add(name)
        local k = Str(name) and Key(name)
        if k then set[k] = true end
    end
    local FL = rawget(_G, "C_FriendList")
    if type(FL) == "table" and FL.GetNumFriends and FL.GetFriendInfoByIndex then
        local ok, n = pcall(FL.GetNumFriends)
        for i = 1, (ok and tonumber(n) or 0) do
            local ok2, info = pcall(FL.GetFriendInfoByIndex, i)
            if ok2 and type(info) == "table" then Add(info.name) end
        end
    end
    local BN, BNum = rawget(_G, "C_BattleNet"), rawget(_G, "BNGetNumFriends")
    if type(BN) == "table" and BN.GetFriendNumGameAccounts and BN.GetFriendGameAccountInfo and BNum then
        local ok, n = pcall(BNum)
        for i = 1, (ok and tonumber(n) or 0) do
            local ok2, m = pcall(BN.GetFriendNumGameAccounts, i)
            for j = 1, (ok2 and tonumber(m) or 0) do
                local ok3, g = pcall(BN.GetFriendGameAccountInfo, i, j)
                if ok3 and type(g) == "table" then Add(g.characterName) end
            end
        end
    end
    local inGuild, num, info = rawget(_G, "IsInGuild"), rawget(_G, "GetNumGuildMembers"), rawget(_G, "GetGuildRosterInfo")
    if inGuild and num and info then
        local ok, yes = pcall(inGuild)
        if ok and yes then
            local ok2, n = pcall(num)
            for i = 1, (ok2 and tonumber(n) or 0) do
                local ok3, name = pcall(info, i)
                if ok3 then Add(name) end
            end
        end
    end
    F.circle, F.circleAt = set, now
    return set
end

function F.InCircle(name)
    local k = Key(name)
    return k ~= nil and F.Circle()[k] == true
end

---------------------------------------------------------------------------
-- Eigene Rezepte (nur der eingeloggte Charakter)
---------------------------------------------------------------------------
local function SortedIds(list)
    local ids = {}
    for id in pairs(type(list) == "table" and list or {}) do
        if Num(id) and id > 0 and id < 1e7 and id == math.floor(id) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

local function Hash(ids)
    local c = Comm()
    local parts = {}
    for i, id in ipairs(ids) do parts[i] = ("%x"):format(id) end
    return c and c.Checksum(table.concat(parts, ",")) or ""
end

local function B36(n)
    local d, s = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    repeat local r = n % 36; s = d:sub(r + 1, r + 1) .. s; n = math.floor(n / 36) until n == 0
    return s
end

-- { [Beruf] = { s = Stufe, ids = {...}, h = Pruefwert } } fuer die Berufe mit gelesenen Rezepten
function F.Own()
    local out = {}
    for _, p in ipairs(ns.ReadProfessions()) do
        local ids = SortedIds(ns.Guide.Known(p.key))
        if #ids > 0 and #ids <= F.MAX_IDS then out[p.key] = { s = p.skill, ids = ids, h = Hash(ids) } end
    end
    return out
end

local function Summary(first)
    local p, any = {}, false
    for key, e in pairs(F.Own()) do p[key] = { s = e.s, c = #e.ids, h = e.h }; any = true end
    if not any then return nil end
    return { v = F.VERSION, k = "s", f = first and true or nil, p = p }
end

-- Stand an alle. force: auch ohne Aenderung (erster nach dem Einloggen)
function F.Announce(force)
    local c = Comm()
    if not (c and c.IsOn() and c.channel) then return false end
    local now = Now()
    if F.sentAt and now - F.sentAt < F.SEND_GAP then return false end
    local data = Summary(not F.sentFirst)
    if not data then return false end
    local sig = {}
    for key, e in pairs(data.p) do sig[#sig + 1] = key .. "=" .. e.h end
    table.sort(sig)
    sig = table.concat(sig, ";")
    if not force and sig == F.lastSig then return false end
    if c.Send(F.SVC, data) > 0 then
        F.sentAt, F.lastSig, F.sentFirst = now, sig, true
        return true
    end
    return false
end

-- Nach dem Lesen eines Berufsfensters (Measure.ReadAll): geaendert? dann bald melden
function F.OwnChanged()
    if not (C_Timer and C_Timer.After) then return F.Announce(false) end
    if F.pending then return end
    F.pending = true
    local wait = math.max(5, F.SEND_GAP - (Now() - (F.sentAt or 0)))
    C_Timer.After(wait, function()
        F.pending = false
        mod:Call("Rezepte teilen", F.Announce, false)
    end)
end

---------------------------------------------------------------------------
-- Empfangen
---------------------------------------------------------------------------
local function ValidKey(key) return Num(key) and ns.PROFS[key] ~= nil end

local function Entry(name, create)
    local k = Key(name)
    if not k then return nil end
    local t = Store()
    local e = t[k]
    if not e and create then
        local n = 0
        local oldest, oldKey
        for kk, x in pairs(t) do
            n = n + 1
            if not oldest or (x.at or 0) < oldest then oldest, oldKey = x.at or 0, kk end
        end
        if n >= F.MAX_FRIENDS and oldKey then t[oldKey] = nil end
        e = { name = Comm().Plain(name), at = Now(), p = {} }
        t[k] = e
    end
    return e
end

local function OnSummary(d, info)
    if type(d.p) ~= "table" or not F.InCircle(info.name) then return end
    local e = Entry(info.name, true)
    if not e then return end
    e.at = Now()
    local want = {}
    for key, x in pairs(d.p) do
        if ValidKey(key) and type(x) == "table" and Num(x.c) and Str(x.h) and #x.h <= 8 then
            local have = e.p[key]
            if not (have and have.h == x.h) then want[#want + 1] = key end
            if have and Num(x.s) and x.s >= 0 and x.s <= 1000 then have.s = x.s end
        end
    end
    -- Berufe, die er nicht mehr meldet, fallen weg
    for key in pairs(e.p) do if d.p[key] == nil then e.p[key] = nil end end
    local k, now = Key(info.name), Now()
    if #want > 0 and now - (F.asked[k] or 0) >= F.PAUSE then
        F.asked[k] = now
        info.reply({ v = F.VERSION, k = "q", p = want })
    end
    -- Erster Stand nach seinem Einloggen: eigenen Stand zurueck, damit er unsere Liste holen kann
    if d.f and now - (F.echoed[k] or 0) >= F.PAUSE then
        local mine = Summary(false)
        if mine then F.echoed[k] = now; info.reply(mine) end
    end
end

local function OnQuestion(d, info)
    if type(d.p) ~= "table" then return end
    local k, now = Key(info.name), Now()
    if not k or now - (F.answered[k] or 0) < F.PAUSE then return end
    F.answered[k] = now
    local own = F.Own()
    for i, key in ipairs(d.p) do
        if i > 20 then break end
        local e = ValidKey(key) and own[key]
        if e then
            local n = math.max(1, math.ceil(#e.ids / F.PER_PART))
            for part = 1, n do
                local chunk = {}
                for j = (part - 1) * F.PER_PART + 1, math.min(#e.ids, part * F.PER_PART) do chunk[#chunk + 1] = B36(e.ids[j]) end
                info.reply({ v = F.VERSION, k = "l", p = key, s = e.s, h = e.h, i = part, n = n, ids = table.concat(chunk, ",") })
            end
        end
    end
end

local function OnList(d, info)
    local key = d.p
    if not (ValidKey(key) and Num(d.i) and Num(d.n) and d.n >= 1 and d.n <= 10 and d.i >= 1 and d.i <= d.n
        and Str(d.h) and #d.h <= 8 and type(d.ids) == "string" and #d.ids <= 1600) then return end
    if not F.InCircle(info.name) then return end
    local k = Key(info.name)
    local slot = k .. ":" .. key
    local inc = F.incoming[slot]
    if not inc or inc.h ~= d.h or inc.n ~= d.n then inc = { h = d.h, n = d.n, parts = {}, got = 0 }; F.incoming[slot] = inc end
    if inc.parts[d.i] then return end
    inc.parts[d.i], inc.got = d.ids, inc.got + 1
    if inc.got < inc.n then return end
    F.incoming[slot] = nil
    local ids, count = {}, 0
    for part = 1, inc.n do
        for t in inc.parts[part]:gmatch("[^,]+") do
            local id = tonumber(t, 36)
            if id and id > 0 and id < 1e7 then
                if not ids[id] then count = count + 1 end
                ids[id] = true
            end
            if count > F.MAX_IDS then return end
        end
    end
    local e = Entry(info.name, true)
    if not e then return end
    e.at = Now()
    e.p[key] = { s = (Num(d.s) and d.s >= 0 and d.s <= 1000) and d.s or nil, h = d.h, ids = ids }
    if ns.Window and ns.Window.IsOpen and ns.Window.IsOpen() and ns.Window.Refresh then mod:Call("Fenster", ns.Window.Refresh) end
end

function F.OnReceive(d, info)
    if type(d) ~= "table" or type(info) ~= "table" or not Str(info.name) then return end
    if not Num(d.v) or d.v < 1 then return end
    if d.k == "s" then OnSummary(d, info)
    elseif d.k == "q" then OnQuestion(d, info)
    elseif d.k == "l" then OnList(d, info) end
end

---------------------------------------------------------------------------
-- Fuer den Codex
---------------------------------------------------------------------------
-- { [recipeID] = { "Name", ... } } der Freunde fuer einen Beruf
function F.ByRecipe(key)
    local out = {}
    for _, e in pairs(Store()) do
        local p = type(e) == "table" and type(e.p) == "table" and e.p[key]
        if p and type(p.ids) == "table" and Str(e.name) then
            for id in pairs(p.ids) do
                local l = out[id]
                if not l then l = {}; out[id] = l end
                l[#l + 1] = e.name
            end
        end
    end
    for _, l in pairs(out) do table.sort(l) end
    return out
end

-- Alte Eintraege entfernen (30 Tage)
function F.Purge()
    local limit = Now() - F.KEEP_DAYS * 86400
    local t = Store()
    for k, e in pairs(t) do
        if type(e) ~= "table" or (e.at or 0) < limit then t[k] = nil end
    end
end

-- /prof freunde
function F.Report()
    local list = {}
    for _, e in pairs(Store()) do if type(e) == "table" and Str(e.name) then list[#list + 1] = e end end
    table.sort(list, function(a, b) return (a.at or 0) > (b.at or 0) end)
    if not Comm() then mod:Print(L.FR_NO_COMM) return end
    if #list == 0 then mod:Print(L.FR_NONE) return end
    mod:Print(L.FR_HEAD:format(#list))
    for _, e in ipairs(list) do
        local profs = {}
        for key, p in pairs(e.p or {}) do
            local n = 0
            for _ in pairs(p.ids or {}) do n = n + 1 end
            profs[#profs + 1] = ("%s %d"):format(ns.ProfName(key), n)
        end
        table.sort(profs)
        local days = math.floor((Now() - (e.at or 0)) / 86400)
        print(("   %s: %s (%s)"):format(e.name, #profs > 0 and table.concat(profs, ", ") or "-", days < 1 and L.FR_TODAY or L.FR_DAYS:format(days)))
    end
end

function F.Init()
    F.Purge()
    local c = Comm()
    if not c then return end
    c.Register(F.SVC, { version = F.VERSION, onReceive = function(d, info) mod:Call("Rezepte der Freunde", F.OnReceive, d, info) end })
    if C_Timer and C_Timer.After then
        C_Timer.After(F.FIRST_DELAY, function() mod:Call("Rezepte teilen", F.Announce, true) end)
        -- Kanal war noch nicht da: spaeter noch einmal
        C_Timer.After(F.FIRST_DELAY * 3, function() if not F.sentFirst then mod:Call("Rezepte teilen", F.Announce, true) end end)
    end
end
