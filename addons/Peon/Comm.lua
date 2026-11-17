-- Peon - Comm.lua
-- Ab 0.23.0 (Kern-API 23): stiller Datenaustausch zwischen Peon-Nutzern (Peon.Comm).
-- Konzept: docs/konzepte/kern/Peon_Comm_Konzept.md (KarloDerBaer, 17.11.2026).
--
-- Was auf WoW Forever geht (Fund aus Profession Leveling Guide, MIT, Module/Netz.lua, und eigene Pruefung):
--   Laut Guide kommen Addon-Nachrichten ueber einen Kanal nicht an. Eigene Pruefung (17.11.2026): Die eigene
--   kommt zurueck, ob andere sie bekommen, ist offen. Unsichtbares Addon-Fluestern geht, aber nur an den
--   vollen Namen "Vorname Nachname". Der versteckte Kanal "PeonNet" ist der Treffpunkt: Wer drin ist, hat Peon.
--   Zum Test geht die Begruessung zusaetzlich einmal in den Kanal, PeonDB.comm.peers zeigt den Weg (w, c).
--   Nachrichten gehen per Addon-Fluestern an wenige zufaellige Mitglieder, die sie hoechstens
--   MAX_HOPS Mal weitergeben. So verbreiten sie sich auch zwischen Spielern, die sich nie direkt sehen.
--
-- Schnittstelle fuer Module (API 23, nur Erweiterung):
--   Peon.Comm.Register("dienst", { version = 1, onReceive = function(daten, info) end })
--       info.origin = Pruefwert des Urhebers (6 Zeichen, kein Name), info.hops = Spruenge,
--       info.direct = direkt an uns, info.reply(daten) = Antwort nur an den Absender
--   Peon.Comm.Send("dienst", daten [, { to = name }])   Tabelle, Text, Zahl oder Wahrheitswert
--   Peon.Comm.IsOn(), Peon.Comm.SetOn(an), Peon.Comm.Peers(), Peon.Comm.Known(), Peon.Comm.Status()
--   Peon.Comm.SendChannel("dienst", daten)   einmal an alle im Kanal, ohne Weitergabe (info.via = "c")
--   Fuer Peon_Debug: Peon.Comm.Listen(fn(richtung, art, wer, text)), Peon.Comm.SetShow("channel"|"whisper", an)
--
-- Der Kern kuemmert sich um Kanal, Mitgliederliste, Warteschlange, Takt, Teilen langer Nachrichten,
-- Weitergabe, doppelte Nachrichten und Pruefwert. Nicht im Kampf und nicht in Instanzen senden.
-- Charakternamen werden nie gespeichert oder angezeigt, sie liegen nur im Speicher zum Zustellen.
--
-- Erster Schritt (KarloDerBaer, 17.11.2026): noch kein Modul tauscht Daten. Der Kern meldet selbst den
-- Dienst "hello" an, mit dem sich Peon-Nutzer gegenseitig kennenlernen (Version, Kern-API). Was dabei
-- ankommt, steht in PeonDB.comm und zeigt nach dem Release, ob der Austausch funktioniert.
--
-- Nachricht (hoechstens 255 Zeichen): 1^dienst^urheber^spruenge^flags^nummer^teil^teile^daten
--   flags "d" = direkt, nicht weitergeben. Daten mit Encode verpackt, ^ | ~ und Nullzeichen maskiert.

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

local C = {}
ns.Comm = C
Peon.Comm = C

C.PREFIX       = "PEON"
C.PROTO        = "1"
C.CHANNELS     = { "PeonNet", "PeonNet2", "PeonNet3" }   -- Ausweichnamen, falls einer gesperrt ist
C.SEND_EVERY   = 1.25    -- Sekunden zwischen zwei Fluesternachrichten (Blizzard drosselt bei etwa 1 je Sek.)
C.FANOUT       = 3       -- eigene Nachricht an so viele Mitspieler
C.RELAY        = 2       -- weitergegebene Nachricht an so viele
C.MAX_HOPS     = 3       -- so oft wird eine Nachricht hoechstens weitergegeben
C.SEEN_TIME    = 1800    -- doppelte Nachrichten so lange erkennen
C.MAX_QUEUE    = 150
C.MAX_LEN      = 255
C.MAX_PARTS    = 8       -- laengere Daten lehnt Send ab
C.PART_TIME    = 120     -- Teile einer Nachricht so lange sammeln
C.JOIN_DELAY   = 15      -- erst nach den Standardkanaelen beitreten, sonst verschiebt sich deren Nummer
C.WATCH_EVERY  = 60
C.HELLO_FIRST  = 30
C.HELLO_EVERY  = 1800
C.REPLY_PAUSE  = 600     -- demselben Urheber hoechstens so oft antworten
C.OFFLINE_PAUSE = 900
C.MAX_NAMES    = 500
C.MAX_PEERS    = 200     -- gemerkte Peon-Nutzer (nur Pruefwerte)
C.PROBE_WAIT   = 8
C.ROSTER_ASK_EVERY = 60  -- Mitgliederliste hoechstens so oft beim Server anfordern (Sekunden)
C.HIDE_EVERY   = 5       -- Kanal nach Aenderung der Chatfenster hoechstens so oft verstecken

C.services = {}
C.names, C.nameSet = {}, {}    -- erreichbare Peon-Nutzer, nur im Speicher
C.queue = {}                   -- { ziel, text } oder { false, text, "CHANNEL" }
C.seen = {}                    -- schon verarbeitete Teile -> Zeit
C.parts = {}                   -- Teile langer Nachrichten
C.offline = {}                 -- Name -> bis wann nicht anfluestern
C.whispered = {}               -- Name -> Zeit des letzten Fluesterns
C.replied = {}                 -- Urheber -> Zeit der letzten Antwort
C.channel = nil                -- Name des beigetretenen Kanals
C.running = false
C.counter = 0
C.session = nil
C.show = { channel = false, whisper = false }   -- Peon_Debug: Kanal zeigen, Meldung "nicht online" zeigen
C.listeners = {}               -- Peon_Debug: wer jede Nachricht sehen will

local function Now() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function Secret(v) return Peon.IsSecret(v) end

---------------------------------------------------------------------------
-- Einstellungen und Speicher
---------------------------------------------------------------------------
function C.IsOn()
    return not (type(Peon.db) == "table" and Peon.db.commOff == true)
end

local function DB()
    local db = Peon.db
    if type(db) ~= "table" then return nil end
    local c = db.comm
    if type(c) ~= "table" then c = {}; db.comm = c end
    if type(c.peers) ~= "table" then c.peers = {} end
    for _, k in ipairs({ "sent", "recv", "relayed", "dup", "bad", "chanSent", "chanRecv" }) do
        if type(c[k]) ~= "number" then c[k] = 0 end
    end
    return c
end
C.DB = DB

local function Count(key, n)
    local c = DB()
    if c then c[key] = c[key] + (n or 1) end
end

---------------------------------------------------------------------------
-- Pruefwert und Namen
---------------------------------------------------------------------------
-- Kurzer Pruefwert statt Name (djb2, 6 Hex-Zeichen)
function C.Checksum(s)
    s = tostring(s or ""):lower()
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%06x"):format(h % 16777216)
end

-- Name zum Anfluestern: Forever-Charaktere heissen "Vorname Nachname". Einen Realm-Anhang ("-Realm") nimmt der
-- Server beim Fluestern nicht an ("nicht online", gesehen 17.11.2026), deshalb faellt er hier weg.
function C.Plain(name)
    if type(name) ~= "string" or Secret(name) then return nil end
    local n = name:match("^([^%-]*)") or name
    n = n:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if n == "" then return nil end
    return n
end

-- Schluessel fuer Namen: ohne Realm, klein geschrieben ("Vorname Nachname-Realm" -> "vorname nachname")
function C.BaseName(name)
    local n = C.Plain(name)
    return n and n:lower() or nil
end

-- Eigener Name mit Nachname (zweiter Wert von UnitName ist in Forever der Nachname, nicht der Realm)
function C.MyName()
    if not UnitName then return nil end
    local first, last = UnitName("player")
    if type(first) ~= "string" or Secret(first) or first == "" then return nil end
    if type(last) == "string" and not Secret(last) and last ~= "" then return first .. " " .. last end
    return first
end

-- Form eines Namens ohne den Namen selbst: "a a", "a-a" oder "a" (fuer die Pruefung)
local function NameForm(name)
    if type(name) ~= "string" or Secret(name) then return false end
    return (name:gsub("[^%s%-]+", "a"))
end

function C.MyCode()
    local n = C.MyName()
    return n and C.Checksum(C.BaseName(n)) or nil
end

local function IsMe(name)
    local me = C.MyName()
    return me ~= nil and C.BaseName(name) == C.BaseName(me)
end

function C.AddName(name)
    if type(name) ~= "string" or Secret(name) or name == "" or #name > 60 or name:find("[|,%^]") then return false end
    if IsMe(name) then return false end
    name = C.Plain(name)
    if not name then return false end
    local base = name:lower()
    if (C.offline[base] or 0) > Now() then return false end
    if C.nameSet[base] or #C.names >= C.MAX_NAMES then return false end   -- "Name" und "Name-Realm" nur einmal
    C.names[#C.names + 1] = name
    C.nameSet[base] = name
    return true
end

function C.RemoveName(name)
    local base = C.BaseName(name)
    if not base or not C.nameSet[base] then return end
    C.nameSet[base] = nil
    for i = #C.names, 1, -1 do if C.BaseName(C.names[i]) == base then table.remove(C.names, i) end end
end

-- bis zu k zufaellige Namen, ohne "except"
function C.RandomNames(k, except)
    local pool = {}
    for _, n in ipairs(C.names) do if n ~= except then pool[#pool + 1] = n end end
    local out = {}
    while #out < k and #pool > 0 do out[#out + 1] = table.remove(pool, math.random(#pool)) end
    return out
end

---------------------------------------------------------------------------
-- Verpacken: Tabellen, Texte, Zahlen, Wahrheitswerte. Ohne Lua-Code aus der Nachricht auszufuehren.
---------------------------------------------------------------------------
local ESC = { ["~"] = "~1", ["^"] = "~2", ["|"] = "~3", ["\0"] = "~4" }
local UNESC = { ["1"] = "~", ["2"] = "^", ["3"] = "|", ["4"] = "\0" }

local function Pack(v, out, depth)
    if Secret(v) then return false end
    local t = type(v)
    if t == "string" then
        if Secret(v) then return false end
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "number" then
        if Secret(v) or v ~= v or v == math.huge or v == -math.huge then return false end
        out[#out + 1] = "n" .. ("%.14g"):format(v) .. ";"
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "table" then
        if depth > 10 then return false, "deep" end   -- zu tief: alles ablehnen
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local tk, tx = type(k), type(x)
            if (tk == "string" or tk == "number") and (tx == "string" or tx == "number" or tx == "boolean" or tx == "table") then
                local mark = #out
                local ok, why = Pack(k, out, depth + 1)
                if ok then ok, why = Pack(x, out, depth + 1) end
                if why == "deep" then return false, why end
                if not ok then   -- einzelner unpassender Eintrag (geheim, NaN): auslassen
                    for i = #out, mark + 1, -1 do out[i] = nil end
                end
            end
        end
        out[#out + 1] = "}"
    else
        return false
    end
    return true
end

function C.Encode(v)
    local out = {}
    if not Pack(v, out, 0) then return nil end
    return (table.concat(out):gsub("[~%^|%z]", ESC))
end

local function Unpack(s, pos, depth)
    local c = s:sub(pos, pos)
    if c == "s" then
        local len, at = s:match("^(%d+):()", pos + 1)
        len = tonumber(len)
        if not len or at + len - 1 > #s then return nil end
        return s:sub(at, at + len - 1), at + len
    elseif c == "n" then
        local num, at = s:match("^([^;]+);()", pos + 1)
        num = tonumber(num)
        if not num then return nil end
        return num, at
    elseif c == "T" then return true, pos + 1
    elseif c == "F" then return false, pos + 1
    elseif c == "{" then
        if depth > 10 then return nil end
        local t = {}
        pos = pos + 1
        while true do
            if pos > #s then return nil end
            if s:sub(pos, pos) == "}" then return t, pos + 1 end
            local k, x
            k, pos = Unpack(s, pos, depth + 1)
            if k == nil or type(k) == "table" or type(k) == "boolean" then return nil end
            x, pos = Unpack(s, pos, depth + 1)
            if x == nil then return nil end
            t[k] = x
        end
    end
    return nil
end

function C.Decode(s)
    if type(s) ~= "string" or s == "" then return nil end
    s = s:gsub("~(%d)", UNESC)
    local ok, v, pos = pcall(Unpack, s, 1, 0)
    if not ok or v == nil or pos ~= #s + 1 then return nil end
    return v
end

---------------------------------------------------------------------------
-- Nachrichten bauen und lesen
---------------------------------------------------------------------------
local PATTERN = "^(%d+)%^([%w_]+)%^(%x%x%x%x%x%x)%^(%d+)%^(%a*)%^(%w+)%^(%d+)%^(%d+)%^(.*)$"

function C.Build(svc, origin, hops, flags, mid, i, n, payload)
    return table.concat({ C.PROTO, svc, origin, tostring(hops), flags or "", mid, tostring(i), tostring(n), payload or "" }, "^")
end

function C.Parse(text)
    if type(text) ~= "string" or Secret(text) or #text > C.MAX_LEN then return nil end
    local proto, svc, origin, hops, flags, mid, i, n, payload = text:match(PATTERN)
    if not proto then return nil end
    i, n, hops = tonumber(i), tonumber(n), tonumber(hops)
    if i < 1 or n < 1 or i > n or n > C.MAX_PARTS then return nil end
    return { proto = proto, svc = svc, origin = origin, hops = hops, flags = flags, mid = mid, i = i, n = n, payload = payload }
end

-- Jede gesendete und empfangene Peon-Nachricht melden (fuer Peon_Debug).
-- fn(richtung, art, wer, text): richtung "out" oder "in", art "WHISPER" oder "CHANNEL"
function C.Listen(fn)
    if type(fn) ~= "function" then return false end
    C.listeners[#C.listeners + 1] = fn
    return true
end

local function Notify(dir, kind, who, text)
    for _, fn in ipairs(C.listeners) do pcall(fn, dir, kind, who, text) end
end

local function NextId()
    if not C.session then C.session = ("%x"):format(math.random(0, 4095)) end
    C.counter = C.counter + 1
    return C.session .. ("%x"):format(C.counter)
end

---------------------------------------------------------------------------
-- Senden: Warteschlange, ein Fluestern je SEND_EVERY
---------------------------------------------------------------------------
local function Enqueue(target, text, kind)
    if #C.queue >= C.MAX_QUEUE then return false end
    if target then target = C.Plain(target); if not target then return false end end
    C.queue[#C.queue + 1] = { target, text, kind }
    return true
end

local function InInstance()
    local f = rawget(_G, "IsInInstance")
    if type(f) ~= "function" then return false end
    local ok, inside = pcall(f)
    return ok and inside == true
end

function C.CanSend()
    return C.IsOn() and C.running and not Peon.InCombat() and not InInstance()
end

function C.Tick()
    if not C.IsOn() or not C.running then wipe(C.queue); return end
    if Peon.InCombat() or InInstance() then return end    -- warten, nichts verwerfen
    local p = table.remove(C.queue, 1)
    if not p then return end
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or rawget(_G, "SendAddonMessage")
    if type(send) ~= "function" then return end
    if p[3] == "CHANNEL" then
        local id = C.ChannelId()
        if id <= 0 then return end
        if pcall(send, C.PREFIX, p[2], "CHANNEL", id) then Count("chanSent"); Notify("out", "CHANNEL", C.channel, p[2]) end
        return
    end
    local ok = pcall(send, C.PREFIX, p[2], "WHISPER", p[1])
    if ok then Count("sent"); Notify("out", "WHISPER", p[1], p[2]) end
    C.whispered[C.BaseName(p[1])] = Now()
end

-- Eine Nachricht an alle im Kanal (nur ein Teil, wird nicht weitergegeben). Rueckgabe: 1 oder 0
function C.SendChannel(svc, data)
    if not C.services[svc] or not C.IsOn() or not C.channel then return 0 end
    local payload = C.Encode(data)
    local origin = C.MyCode()
    if not payload or not origin then return 0 end
    local mid = NextId()
    local text = C.Build(svc, origin, 0, "d", mid, 1, 1, payload)
    if #text > C.MAX_LEN then return 0 end
    C.seen[origin .. ":" .. mid .. ":1"] = Now()
    return Enqueue(false, text, "CHANNEL") and 1 or 0
end

function C.Register(name, o)
    if type(name) ~= "string" or not name:match("^[%w_]+$") or #name > 12 or C.services[name] then return false end
    o = type(o) == "table" and o or {}
    C.services[name] = { name = name, version = tonumber(o.version) or 1, onReceive = o.onReceive }
    if Peon.loggedIn then C.Start() end
    return true
end

-- Rueckgabe: Zahl der eingereihten Fluesternachrichten (0 = nichts gesendet)
function C.Send(svc, data, opts)
    if not C.services[svc] or not C.IsOn() then return 0 end
    local payload = C.Encode(data)
    if not payload then return 0 end
    opts = type(opts) == "table" and opts or {}
    local origin = C.MyCode()
    if not origin then return 0 end
    local flags = opts.to and "d" or ""
    local mid = NextId()
    local room = C.MAX_LEN - #C.Build(svc, origin, 0, flags, mid, C.MAX_PARTS, C.MAX_PARTS, "")
    local chunks = {}
    local pos = 1
    repeat
        local stop = pos + room - 1
        -- Maskierung (~1) nicht zerschneiden
        if payload:sub(stop, stop) == "~" then stop = stop - 1 end
        chunks[#chunks + 1] = payload:sub(pos, stop)
        pos = stop + 1
    until pos > #payload
    if #chunks > C.MAX_PARTS then return 0 end
    local targets = opts.to and { opts.to } or C.RandomNames(C.FANOUT)
    local n = 0
    for i, chunk in ipairs(chunks) do
        C.seen[origin .. ":" .. mid .. ":" .. i] = Now()
        local text = C.Build(svc, origin, 0, flags, mid, i, #chunks, chunk)
        for _, t in ipairs(targets) do if Enqueue(t, text) then n = n + 1 end end
    end
    return n
end

---------------------------------------------------------------------------
-- Empfangen
---------------------------------------------------------------------------
local function Deliver(m, payload, sender, via)
    local s = C.services[m.svc]
    if not s or type(s.onReceive) ~= "function" then return end
    local data = C.Decode(payload)
    if data == nil then Count("bad"); return end
    local direct = m.flags:find("d", 1, true) ~= nil
    local info = { origin = m.origin, hops = m.hops, direct = direct, via = via or "w",
        reply = function(d) return C.Send(m.svc, d, { to = sender }) end }
    local ok, err = pcall(s.onReceive, data, info)
    if not ok then Peon.RecordError(ADDON_NAME, "Comm " .. m.svc, err, Peon.version) end
end

-- via: "w" Fluestern (Standard) oder "c" Kanal
function C.Receive(text, sender, via)
    if not C.IsOn() then return end
    local m = C.Parse(text)
    if not m then Count("bad"); return end
    if m.proto ~= C.PROTO then return end   -- neueres Format: nicht verstehen, nicht weitergeben
    C.AddName(sender)                       -- wer uns anfluestert, hat Peon
    local now = Now()
    local key = m.origin .. ":" .. m.mid .. ":" .. m.i
    if C.seen[key] then Count("dup"); return end
    C.seen[key] = now
    -- Beim ersten Sprung muss der Pruefwert zum Absender passen
    -- (kommt der Absender nur mit Vornamen, laesst sich das nicht pruefen)
    local sk = C.BaseName(sender)
    if m.hops == 0 and sk:find(" ", 1, true) and m.origin ~= C.Checksum(sk) then Count("bad"); return end
    if m.origin == C.MyCode() then return end
    Count("recv")
    -- Weitergeben (auch unbekannte Dienste, damit neuere Module ihre Daten verbreiten koennen)
    if m.flags == "" and m.hops < C.MAX_HOPS then
        local fwd = C.Build(m.svc, m.origin, m.hops + 1, "", m.mid, m.i, m.n, m.payload)
        local any = false
        for _, t in ipairs(C.RandomNames(C.RELAY, sender)) do
            if Enqueue(t, fwd) then any = true end
        end
        if any then Count("relayed") end
    end
    if m.n == 1 then return Deliver(m, m.payload, sender, via) end
    local pk = m.origin .. ":" .. m.mid
    local p = C.parts[pk]
    if not p then p = { n = m.n, got = {}, count = 0, t = now }; C.parts[pk] = p end
    if p.n ~= m.n or p.got[m.i] then return end
    p.got[m.i], p.count = m.payload, p.count + 1
    if p.count < p.n then return end
    C.parts[pk] = nil
    Deliver(m, table.concat(p.got), sender, via)
end

-- Alte Eintraege aufraeumen
function C.Purge()
    local now = Now()
    for k, t in pairs(C.seen) do if now - t > C.SEEN_TIME then C.seen[k] = nil end end
    for k, p in pairs(C.parts) do if now - p.t > C.PART_TIME then C.parts[k] = nil end end
    for k, t in pairs(C.offline) do if t <= now then C.offline[k] = nil end end
end

---------------------------------------------------------------------------
-- Kanal als Treffpunkt
---------------------------------------------------------------------------
local function GetChanId(name)
    if not GetChannelName then return 0 end
    local ok, id = pcall(GetChannelName, name)
    return ok and tonumber(id) or 0
end

function C.ChannelId()
    if C.channel then
        local id = GetChanId(C.channel)
        if id > 0 then return id end
    end
    for _, name in ipairs(C.CHANNELS) do
        local id = GetChanId(name)
        if id > 0 then C.channel = name; return id end
    end
    C.channel = nil
    return 0
end

function C.Hide()
    if C.show.channel or not C.channel or not ChatFrame_RemoveChannel then return end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        local list = f and rawget(f, "channelList")
        local inList = type(list) ~= "table"
        if not inList then
            for _, ch in ipairs(list) do if type(ch) == "string" and ch:lower() == C.channel:lower() then inList = true end end
        end
        if f and inList then pcall(ChatFrame_RemoveChannel, f, C.channel) end
    end
end

function C.Join(nr, try, done)
    nr, try = nr or 1, try or 1
    if not C.IsOn() or nr > #C.CHANNELS then if done then done(false) end return end
    if C.ChannelId() > 0 then C.Hide(); if done then done(true) end return end
    local name = C.CHANNELS[nr]
    local join = rawget(_G, "JoinTemporaryChannel") or rawget(_G, "JoinChannelByName")
    if join then pcall(join, name) end
    C_Timer.After(3, function()
        if C.ChannelId() > 0 then
            C.Hide()
            C.ReadRoster()
            if done then done(true) end
        elseif try < 3 then
            C.Join(nr, try + 1, done)     -- Beitritt dauert manchmal laenger
        else
            C.Join(nr + 1, 1, done)       -- Name gesperrt (Passwort, Bann): naechsten versuchen
        end
    end)
end

function C.Leave()
    local leave = rawget(_G, "LeaveChannelByName")
    for _, name in ipairs(C.CHANNELS) do
        if GetChanId(name) > 0 and leave then pcall(leave, name) end
    end
    C.channel = nil
end

-- Nummer des Kanals in der Kanalliste und Zahl der Mitglieder
function C.DisplayIndex()
    if not (C.channel and GetNumDisplayChannels and GetChannelDisplayInfo) then return nil end
    local want = C.channel:lower()
    for i = 1, (GetNumDisplayChannels() or 0) do
        local name, header, _, _, count = GetChannelDisplayInfo(i)
        if not header and type(name) == "string" and not Secret(name) and name:lower():find(want, 1, true) then
            return i, tonumber(count) or 0
        end
    end
    return nil
end

local function NameFromGuid(guid)
    if type(guid) ~= "string" or Secret(guid) or not GetPlayerInfoByGUID then return nil end
    local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
    if not ok or type(name) ~= "string" or Secret(name) or name == "" then return nil end
    -- Realm nicht anhaengen: Fluestern an "Name-Realm" kommt in Forever nicht an
    return C.Plain(name)
end

-- Mitgliederliste lesen. Rueckgabe: Zahl der gelesenen Namen
-- noAsk: nicht beim Server anfordern (bei CHANNEL_ROSTER_UPDATE, sonst fordert jede Antwort die naechste an)
function C.ReadRoster(noAsk)
    local idx, count = C.DisplayIndex()
    local roster = C_ChatInfo and C_ChatInfo.GetChannelRosterInfo
    if not idx or not roster then return 0 end
    local found = 0
    -- Die Anzahl ist oft 0, solange die Liste nicht geladen ist: lesen, bis nichts mehr kommt
    for r = 1, C.MAX_NAMES do
        local ok, name, _, _, guid = pcall(roster, idx, r)
        if not ok or (name == nil and guid == nil and r > (count or 0)) then break end
        if type(name) ~= "string" or Secret(name) or name == "" then name = NameFromGuid(guid) end
        if type(name) == "string" then
            if C.probe and C.probe.busy and IsMe(name) then C.probe.rosterForm = NameForm(name) end
            -- Fehlt in der Liste der Nachname, den vollen Namen aus der GUID nehmen
            local full = NameFromGuid(guid)
            local b, fb = C.BaseName(name), full and C.BaseName(full)
            if fb and (fb == b or fb:sub(1, #b + 1) == b .. " ") then name = full end
            found = found + 1
            C.AddName(name)
        end
    end
    -- Liste beim Server anfordern (kommt mit CHANNEL_ROSTER_UPDATE), nicht bei offenem Kanalfenster.
    -- Hoechstens einmal je ROSTER_ASK_EVERY: Ohne Bremse trennte der Chatserver die Verbindung (17.11.2026).
    local sel = rawget(_G, "SetSelectedDisplayChannel")
    local cf = rawget(_G, "ChannelFrame")
    local now = Now()
    if not noAsk and found <= 1 and sel and not (cf and cf.IsShown and cf:IsShown())
        and now - (C.rosterAskAt or -C.ROSTER_ASK_EVERY) >= C.ROSTER_ASK_EVERY then
        C.rosterAskAt = now
        pcall(sel, idx)
    end
    return found
end

---------------------------------------------------------------------------
-- Offline-Meldung des Spiels nach eigenem Fluestern ausblenden
---------------------------------------------------------------------------
function C.OfflineFilter(_, _, msg)
    local fmt = rawget(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S")
    if type(msg) ~= "string" or Secret(msg) or type(fmt) ~= "string" then return false end
    local pat = "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
    local name = msg:match(pat)
    if not name then return false end
    local base = C.BaseName(name)
    local at = C.whispered[base]
    if not at or Now() - at > 15 then return false end
    C.offline[base] = Now() + C.OFFLINE_PAUSE
    C.RemoveName(name)
    for i = #C.queue, 1, -1 do if C.BaseName(C.queue[i][1]) == base then table.remove(C.queue, i) end end
    return not C.show.whisper
end

-- Peon_Debug: kind "channel" (Kanal im Chatfenster lassen) oder "whisper" (Meldung "nicht online" zeigen)
function C.SetShow(kind, on)
    if kind ~= "channel" and kind ~= "whisper" then return false end
    C.show[kind] = on and true or false
    if kind == "channel" and C.channel then
        local f = rawget(_G, "ChatFrame1")
        local add = rawget(_G, "ChatFrame_AddChannel")
        if on and f and add then pcall(add, f, C.channel) elseif not on then C.Hide() end
    end
    return true
end

---------------------------------------------------------------------------
-- Start, Stopp, Ereignisse
---------------------------------------------------------------------------
local tickersMade = false
local function MakeTickers()
    if tickersMade or not (C_Timer and C_Timer.NewTicker) then return end
    tickersMade = true
    C_Timer.NewTicker(C.SEND_EVERY, C.Tick)
    C_Timer.NewTicker(C.WATCH_EVERY, function() C.Watch() end)
    C_Timer.NewTicker(C.HELLO_EVERY, function() C.SayHello() end)
end

function C.Watch()
    C.Purge()
    if not C.running then return end
    if C.ChannelId() == 0 then C.Join(1) else C.ReadRoster() end
    -- Noch niemanden begruesst (Liste war beim ersten Versuch leer): jetzt nachholen
    if not C.helloAt and #C.names > 0 then C.SayHello() end
end

-- Erst wenn ein Dienst angemeldet ist, eingeloggt und eingeschaltet
function C.Start()
    if C.running or not C.IsOn() or not next(C.services) or not Peon.loggedIn then return false end
    C.running = true
    local reg = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or rawget(_G, "RegisterAddonMessagePrefix")
    if reg then pcall(reg, C.PREFIX) end
    MakeTickers()
    C_Timer.After(C.JOIN_DELAY, function() if C.running then C.Join(1) end end)
    C_Timer.After(C.HELLO_FIRST, function() C.SayHello() end)
    return true
end

function C.Stop()
    C.running = false
    wipe(C.queue)
    wipe(C.names); wipe(C.nameSet)
    C.Leave()
end

function C.SetOn(on)
    if type(Peon.db) ~= "table" then return end
    Peon.db.commOff = (not on) and true or nil
    if on then C.Start() else C.Stop() end
end

function C.Peers() return #C.names end

function C.Known()
    local c = DB()
    local n = 0
    if c then for _ in pairs(c.peers) do n = n + 1 end end
    return n
end

function C.Status()
    local c = DB() or {}
    return { on = C.IsOn(), running = C.running, channel = C.channel, peers = #C.names, known = C.Known(),
        sent = c.sent or 0, recv = c.recv or 0, relayed = c.relayed or 0, queue = #C.queue }
end

---------------------------------------------------------------------------
-- Dienst "hello": gegenseitig kennenlernen (erster Schritt, keine Spieldaten)
---------------------------------------------------------------------------
local function HelloData(reply)
    return { v = tostring(Peon.version), a = Peon.API, r = reply and true or nil }
end

function C.SayHello(to)
    if not C.running then return 0 end
    local n = C.Send("hello", HelloData(false), to and { to = to } or nil)
    if n > 0 and not to then C.helloAt = Now() end
    -- Zum Test zusaetzlich einmal an alle im Kanal (hoechstens alle 30 Minuten), auch wenn sonst niemand
    -- bekannt ist: Die Mitgliederliste kann unvollstaendig sein, und die eigene kommt zurueck (Peon_Debug)
    if not to and Now() - (C.chanHelloAt or -C.HELLO_EVERY) >= C.HELLO_EVERY - 60 then
        if C.SendChannel("hello", HelloData(false)) > 0 then C.chanHelloAt = Now() end
    end
    return n
end

function C.OnHello(data, info)
    if type(data) ~= "table" then return end
    local c = DB()
    if not c then return end
    local now = Now()
    local p = c.peers[info.origin]
    if not p then
        p = { first = now, n = 0, hops = info.hops }
        c.peers[info.origin] = p
    end
    p.last, p.n = now, (p.n or 0) + 1
    p.hops = math.min(p.hops or info.hops, info.hops)
    -- Weg festhalten: w = Fluestern, c = Kanal
    if info.via == "c" then p.c = (p.c or 0) + 1 else p.w = (p.w or 0) + 1 end
    if type(data.v) == "string" and #data.v <= 20 then p.v = data.v end
    if type(data.a) == "number" then p.a = data.a end
    -- Obergrenze: die am laengsten nicht gesehenen fallen weg
    local n, oldest, oldKey = 0, nil, nil
    for k, e in pairs(c.peers) do
        n = n + 1
        if not oldest or (e.last or 0) < oldest then oldest, oldKey = e.last or 0, k end
    end
    if n > C.MAX_PEERS and oldKey then c.peers[oldKey] = nil end
    -- Direkt erhalten und keine Antwort: einmal antworten, damit sich beide kennen
    if info.hops == 0 and not data.r and now - (C.replied[info.origin] or 0) > C.REPLY_PAUSE then
        C.replied[info.origin] = now
        info.reply(HelloData(true))
    end
end

C.Register("hello", { version = 1, onReceive = C.OnHello })

---------------------------------------------------------------------------
-- Pruefung im Spiel: /peon teilen pruefen
-- Kommt eine Kanal-Nachricht an? Kommt Addon-Fluestern an (an sich selbst)? Ist die Mitgliederliste lesbar?
---------------------------------------------------------------------------
function C.Probe()
    if not C.IsOn() then Peon.Print(L.COMM_OFF_HINT); return false end
    if Peon.InCombat() then Peon.Print(L.COMM_PROBE_COMBAT); return false end
    if C.probe and C.probe.busy then return false end
    local me = C.MyName()
    if not me then return false end
    local reg = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or rawget(_G, "RegisterAddonMessagePrefix")
    if reg then pcall(reg, C.PREFIX) end
    local pr = { busy = true, mid = "p" .. NextId(), spaceEcho = false, hyphenEcho = false }
    C.probe = pr
    Peon.Print(L.COMM_PROBE_START)
    C.Join(1, 1, function(joined)
        local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or rawget(_G, "SendAddonMessage")
        local id = C.ChannelId()
        local code = C.MyCode() or "000000"
        local text = C.Build("probe", code, 0, "d", pr.mid, 1, 1, "")
        pr.joined = joined and id > 0
        if send and id > 0 then pr.chanSent = pcall(send, C.PREFIX, text, "CHANNEL", id) end
        -- Fluestern an sich selbst in beiden Schreibweisen: "Vorname Nachname" und "Vorname-Nachname"
        local hy = me:gsub(" ", "-")
        C.whispered[C.BaseName(me)] = Now()   -- Meldung "nicht online" ausblenden
        if send then
            pr.whisperSent = pcall(send, C.PREFIX, C.Build("probe", code, 0, "d", pr.mid .. "s", 1, 1, ""), "WHISPER", me)
            if hy ~= me then pcall(send, C.PREFIX, C.Build("probe", code, 0, "d", pr.mid .. "h", 1, 1, ""), "WHISPER", hy) end
        end
        pr.myForm = NameForm(me)
        pr.guidForm = (UnitGUID and NameForm(NameFromGuid(UnitGUID("player")))) or false
        pr.roster = C.ReadRoster()
        local _, count = C.DisplayIndex()
        pr.count = count
        C_Timer.After(C.PROBE_WAIT, function() C.ProbeDone() end)
    end)
    return true
end

function C.ProbeDone()
    local pr = C.probe
    if not pr or not pr.busy then return end
    pr.busy = false
    pr.roster = math.max(pr.roster or 0, C.ReadRoster())
    local build
    if GetBuildInfo then local ok, _, b = pcall(GetBuildInfo); if ok and not Secret(b) then build = b end end
    local c = DB()
    local res = { at = Now(), build = build, channel = C.channel or false, joined = pr.joined == true,
        chanSent = pr.chanSent == true, chanEcho = pr.chanEcho == true,
        whisperSent = pr.whisperSent == true, whisperEcho = pr.whisperEcho == true,
        spaceEcho = pr.spaceEcho == true, hyphenEcho = pr.hyphenEcho == true,
        myForm = pr.myForm or false, guidForm = pr.guidForm or false, rosterForm = pr.rosterForm or false,
        senderForm = pr.senderForm or false,
        roster = pr.roster or 0, count = pr.count or 0, peers = #C.names }
    if c then c.probe = res end
    local function YesNo(v) return v and L.COMM_YES or L.COMM_NO end
    Peon.Print(L.COMM_PROBE_CHANNEL:format(res.channel or "-", YesNo(res.joined)))
    Peon.Print(L.COMM_PROBE_CHAN_ECHO:format(YesNo(res.chanSent), YesNo(res.chanEcho)))
    Peon.Print(L.COMM_PROBE_WHISPER:format(YesNo(res.whisperSent), YesNo(res.spaceEcho), YesNo(res.hyphenEcho)))
    Peon.Print(L.COMM_PROBE_ROSTER:format(res.roster, res.count))
    Peon.Print(L.COMM_PROBE_SAVED)
    return res
end

-- Pruef-Nachricht erkannt? (eigene, mit der Nummer der laufenden Pruefung)
local function ProbeEcho(text, channel, sender)
    local pr = C.probe
    if not pr or not pr.busy then return false end
    local m = C.Parse(text)
    if not m or m.svc ~= "probe" then return false end
    if m.mid == pr.mid and channel ~= "WHISPER" then pr.chanEcho = true
    elseif m.mid == pr.mid .. "s" and channel == "WHISPER" then pr.spaceEcho, pr.whisperEcho = true, true
    elseif m.mid == pr.mid .. "h" and channel == "WHISPER" then pr.hyphenEcho, pr.whisperEcho = true, true
    else return false end
    pr.senderForm = pr.senderForm or NameForm(sender)
    return true
end

function C.OnAddon(prefix, text, channel, sender)
    if prefix ~= C.PREFIX or Secret(text) or Secret(sender) or Secret(channel) then return end
    Notify("in", channel, sender, text)
    if ProbeEcho(text, channel, sender) then return end
    if type(sender) ~= "string" or IsMe(sender) then return end
    if channel == "WHISPER" then
        C.Receive(text, sender, "w")
    elseif channel == "CHANNEL" then
        Count("chanRecv")
        C.Receive(text, sender, "c")
    end
end

local frame = CreateFrame("Frame")
C.frame = frame
for _, ev in ipairs({ "CHAT_MSG_ADDON", "CHANNEL_ROSTER_UPDATE", "CHAT_MSG_CHANNEL_JOIN", "UPDATE_CHAT_WINDOWS", "PLAYER_ENTERING_WORLD" }) do
    pcall(frame.RegisterEvent, frame, ev)
end
frame:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, ...)
    local ok, err = pcall(function(...)
        if event == "CHAT_MSG_ADDON" then
            C.OnAddon(a1, a2, a3, a4)
        elseif event == "PLAYER_ENTERING_WORLD" then
            C.Start()   -- laeuft er schon, passiert nichts
        elseif not C.running then
            return
        elseif event == "UPDATE_CHAT_WINDOWS" then
            -- gebremst, falls das Entfernen selbst wieder UPDATE_CHAT_WINDOWS ausloest
            if Now() - (C.hideAt or -C.HIDE_EVERY) >= C.HIDE_EVERY then C.hideAt = Now(); C.Hide() end
        elseif event == "CHANNEL_ROSTER_UPDATE" then
            C.ReadRoster(true)
        elseif event == "CHAT_MSG_CHANNEL_JOIN" then
            -- Text, Spieler, Sprache, Kanal, ... , 9. Grundname des Kanals
            local base = select(5, ...)
            local k = (type(base) == "string" and base ~= "" and base) or a4
            if C.channel and type(k) == "string" and not Secret(k) and k:lower():find(C.channel:lower(), 1, true) then
                if C.AddName(a2) then C.SayHello(a2) end
            end
        end
    end, ...)
    if not ok then Peon.RecordError(ADDON_NAME, "Comm " .. tostring(event), err, Peon.version) end
end)

if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    pcall(ChatFrameUtil.AddMessageEventFilter, "CHAT_MSG_SYSTEM", C.OfflineFilter)
elseif ChatFrame_AddMessageEventFilter then
    pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", C.OfflineFilter)
end

---------------------------------------------------------------------------
-- Kern-Optionen: Schalter und Stand (Seite "Peon")
---------------------------------------------------------------------------
function C.StatusText()
    local s = C.Status()
    if not s.on then return L.COMM_STATUS_OFF end
    return L.COMM_STATUS:format(s.channel or "-", s.peers, s.known, s.sent, s.recv, s.relayed)
end

function C.AddOption(panel, anchor)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
    title:SetText(L.COMM_OPT)
    local ok, cb = pcall(CreateFrame, "CheckButton", nil, panel, "UICheckButtonTemplate")
    if not ok or not cb then cb = CreateFrame("CheckButton", nil, panel) end
    cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -4)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(L.COMM_OPT_SHARE)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, -4)
    hint:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.COMM_OPT_HINT)
    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    status:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    status:SetJustifyH("LEFT")
    local function Refresh()
        cb:SetChecked(C.IsOn())
        status:SetText(C.StatusText())
    end
    cb:SetScript("OnClick", function(self)
        C.SetOn(self:GetChecked() and true or false)
        Refresh()
    end)
    panel:HookScript("OnShow", Refresh)
    Refresh()
    C.option = { title = title, check = cb, label = label, hint = hint, status = status, Refresh = Refresh }
    return status
end

---------------------------------------------------------------------------
-- /peon teilen [an | aus | pruefen]
---------------------------------------------------------------------------
function C.Slash(rest)
    local sub = (rest or ""):lower():match("^(%S*)")
    if sub == "an" or sub == "on" then
        C.SetOn(true)
        Peon.Print(L.COMM_NOW_ON)
    elseif sub == "aus" or sub == "off" then
        C.SetOn(false)
        Peon.Print(L.COMM_NOW_OFF)
    elseif sub == "pruefen" or sub == "check" then
        C.Probe()
    else
        Peon.Print(C.StatusText())
        for _, line in ipairs(L.COMM_HELP) do Peon.Print(line) end
    end
end
