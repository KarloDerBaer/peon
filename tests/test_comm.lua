-- Peon-Kern: Datenaustausch zwischen Peon-Nutzern (Comm.lua, API 23, ab 0.23.0).
-- Mehrere Spieler laufen in getrennten Umgebungen (eigener Kern, eigene PeonDB). Ein nachgebautes Netz
-- verhaelt sich wie WoW Forever: Addon-Nachrichten im Kanal kommen nicht an, Addon-Fluestern schon.
-- Prueft: Verpacken und Entpacken, Pruefwert, Nachrichtenformat, Start erst nach dem Einloggen, Kanal beitreten
-- und verstecken, Ausweichkanal, Mitgliederliste (auch Namen ueber die Spieler-ID), Kennenlernen mit Antwort und
-- Weitergabe, keine Namen in PeonDB, gefaelschter Urheber, doppelte Nachrichten, Grenzen der Weitergabe, direkte
-- Nachrichten, lange Nachrichten in Teilen, Takt und Warteschlange, Kampf und Instanz, Offline-Meldung, Abschalten
-- und wieder Einschalten, geheime Werte, Fehler im Dienst, unbekannter Dienst und neueres Format, Obergrenze,
-- neuer Spieler im Kanal, Pruefbefehl, /peon teilen, Schalter in den Kern-Optionen.
-- Ausfuehren aus dem AddOns-Ordner (siehe tests/README.md).
local realPrint = print
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local out = {}
local function fail(msg) realPrint("FEHLER: " .. msg); os.exit(1) end
local function check(c, msg) if not c then fail(msg) end end

local function TocMeta(dir) local m = {} local f = io.open(dir .. "/" .. dir .. ".toc") if f then for l in f:lines() do local k, v = l:match("^##%s*([%w%-]+):%s*(.-)%s*$") if k then m[k] = v end end f:close() end return m end
local meta = { Peon = TocMeta("Peon") }

---------------------------------------------------------------------------
-- Gemeinsame Welt: Uhr, Netz, Kanaele
---------------------------------------------------------------------------
local now = 1800000000
local net = {}            -- unterwegs: { from, prefix, text, kind, target }
local channels = {}       -- Kanalname -> { [Spieler] = true }
local locked = {}         -- gesperrte Kanalnamen
local players = {}        -- Name -> Umgebung
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })

-- Rahmen-Nachbau: merkt Skripte, Ereignisse, Text und Haken, alles andere tut nichts
local function W()
  local o = { scripts = {}, events = {}, txt = "", checked = false, shown = true }
  local m = {}
  function m.SetScript(s, n, f) s.scripts[n] = f end
  function m.GetScript(s, n) return s.scripts[n] end
  function m.HookScript(s, n, f) local old = s.scripts[n] s.scripts[n] = function(...) if old then old(...) end f(...) end end
  function m.RegisterEvent(s, e) s.events[e] = true end
  function m.SetText(s, t) s.txt = t end
  function m.GetText(s) return s.txt end
  function m.SetChecked(s, v) s.checked = v and true or false end
  function m.GetChecked(s) return s.checked end
  function m.IsShown(s) return s.shown end
  function m.CreateFontString() return W() end
  function m.CreateTexture() return W() end
  return setmetatable(o, { __index = function(_, k)
    if m[k] then return m[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
  end })
end

local function NewPlayer(name, opts)
  opts = opts or {}
  local env = setmetatable({}, { __index = _G })
  env._G = env
  local P = { name = name, env = env, timers = {}, frames = {}, joined = {}, removed = {}, out = {}, combat = false, instance = false, opts = opts }
  env.print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end P.out[#P.out+1] = table.concat(t, " ") end
  env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  env.GetLocale = function() return os.getenv("LOC") or "deDE" end
  env.GetTime = function() return now end
  env.GetServerTime = function() return now end
  env.time = function() return now end
  env.date = os.date
  env.issecretvalue = function(v) return v == SECRET end
  env.InCombatLockdown = function() return P.combat end
  env.UnitAffectingCombat = function() return false end
  env.IsInInstance = function() return P.instance, P.instance and "party" or "none" end
  env.UnitName = function(u) if u == "player" then return name, "Stein" end end
  env.GetBuildInfo = function() return "1.60.1", 70009 end
  env.UnitGUID = function(u) if u == "player" then return "Player-" .. name end end
  env.SlashCmdList = {}
  env.UISpecialFrames = {}
  env.NUM_CHAT_WINDOWS = 2
  env.ChatFrame1, env.ChatFrame2 = W(), W()
  env.ERR_CHAT_PLAYER_NOT_FOUND_S = "Kein Spieler namens '%s' ist online."
  env.ChatFrame_RemoveChannel = function(f, ch) P.removed[#P.removed + 1] = ch end
  env.ChatFrame_AddChannel = function(f, ch) P.added = ch end
  env.ChatFrame_AddMessageEventFilter = function(ev, fn) P.filter = fn end
  env.C_AddOns = { GetAddOnMetadata = function(a, f) return meta[a] and meta[a][f] end,
    IsAddOnLoaded = function() return true end, GetNumAddOns = function() return 1 end,
    GetAddOnInfo = function(i) return ({ "Peon" })[i] end }
  env.CreateFrame = function(kind, fname, parent, tmpl)
    if tmpl and tmpl ~= "UICheckButtonTemplate" then error("Couldn't find inherited node \"" .. tmpl .. "\"") end
    local f = W()
    P.frames[#P.frames + 1] = f
    return f
  end
  env.C_Timer = {
    After = function(s, fn) P.timers[#P.timers + 1] = { at = now + s, fn = fn } end,
    NewTicker = function(s, fn) P.tickers = P.tickers or {}; P.tickers[#P.tickers + 1] = { every = s, fn = fn } end,
  }
  -- Kanaele
  env.JoinTemporaryChannel = function(ch)
    P.joinTries = (P.joinTries or 0) + 1
    if locked[ch] then return end
    channels[ch] = channels[ch] or {}
    channels[ch][name] = true
    P.joined[ch] = true
  end
  env.LeaveChannelByName = function(ch) if channels[ch] then channels[ch][name] = nil end P.joined[ch] = nil end
  local function JoinedList()
    local l = {}
    for ch in pairs(P.joined) do l[#l + 1] = ch end
    table.sort(l)
    return l
  end
  env.GetChannelName = function(ch)
    for i, c in ipairs(JoinedList()) do if c == ch then return i + 2, ch end end
    return 0
  end
  env.GetNumDisplayChannels = function() return #JoinedList() + 1 end
  env.GetChannelDisplayInfo = function(i)
    if i == 1 then return "Allgemein", true end   -- Ueberschrift
    local ch = JoinedList()[i - 1]
    local n = 0
    for _ in pairs(channels[ch] or {}) do n = n + 1 end
    return ch, false, false, 0, opts.zeroCount and 0 or n
  end
  env.SetSelectedDisplayChannel = function(i) P.requested = i end
  env.GetPlayerInfoByGUID = function(guid)
    local n = guid:match("^Player%-(.+)$")
    -- Forever: voller Name, bei anderen Spielern mit Realm (beim eigenen Charakter leer)
    if n then return "Krieger", "WARRIOR", "Mensch", "Human", 2, n .. " Stein", n == name and "" or "Fremdrealm" end
  end
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) P.prefix = p end,
    SendAddonMessage = function(prefix, text, kind, target)
      check(#text <= 255, "Nachricht hoechstens 255 Zeichen: " .. #text)
      net[#net + 1] = { from = name, prefix = prefix, text = text, kind = kind, target = target }
      P.sent = (P.sent or 0) + 1
    end,
    GetChannelRosterInfo = function(idx, r)
      local ch = JoinedList()[idx - 1]
      if not ch then return nil end
      local l = {}
      for n in pairs(channels[ch] or {}) do l[#l + 1] = n end
      table.sort(l)
      local n = l[r]
      if not n then return nil end
      -- Forever zeigt Namen im Kanal teils nicht an: dann nur die Spieler-ID
      if players[n] and players[n].opts.hiddenName then return "", false, false, "Player-" .. n end
      return n .. " Stein", false, false, "Player-" .. n
    end,
  }
  -- Kern laden
  local ns = {}
  for _, f in ipairs({ "Locales.lua", "Core.lua", "Module.lua", "Options.lua", "Comm.lua", "Slash.lua" }) do
    local chunk, err = loadfile("Peon/" .. f)
    if not chunk then fail(err) end
    setfenv(chunk, env)
    chunk("Peon", ns)
  end
  P.ns, P.Peon, P.C = ns, env.Peon, ns.Comm
  env.PeonDB = opts.db or {}
  P.Peon.db = env.PeonDB
  P.fire = function(event, ...)
    for _, f in ipairs(P.frames) do
      if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
  end
  players[name] = P
  return P
end

-- Zeit vorstellen und faellige Zeitgeber aller Spieler ausfuehren
local function Advance(sec)
  if sec > 1 then for _ = 1, math.floor(sec) - 1 do Advance(1) end sec = 1 end
  now = now + sec
  local again = true
  while again do
    again = false
    for _, P in pairs(players) do
      local due, keep = {}, {}
      for _, t in ipairs(P.timers) do if t.at <= now then due[#due + 1] = t else keep[#keep + 1] = t end end
      P.timers = keep
      for _, t in ipairs(due) do t.fn(); again = true end
    end
  end
end

-- Netz wie in Forever: Fluestern nur an den vollen Namen ("Vorname Nachname"), nicht an den Vornamen allein
-- und nicht mit Realm-Anhang. Absender anderer Spieler mit Realm. Kanal-Nachrichten erreichen alle Mitglieder.
local delivered, lost, realmLost = 0, 0, 0
local chanWorks = true    -- wie in Forever (gepruefte mit zwei Spielern): Kanal-Nachrichten kommen bei allen an
local function Flush()
  while #net > 0 do
    local m = table.remove(net, 1)
    if m.kind == "WHISPER" then
      local first, last = m.target:match("^([^%s%-]+)[%s%-](.+)$")
      local to = last == "Stein" and players[first]
      if m.target:find(" ", 1, true) and m.target:find("-", 1, true) then realmLost = realmLost + 1 end
      if to and not to.offline then
        delivered = delivered + 1
        -- Absender kommt mit Realm-Anhang, wenn es ein anderer Spieler ist
        to.fire("CHAT_MSG_ADDON", m.prefix, m.text, "WHISPER", m.from .. " Stein" .. (to.name == m.from and "" or "-Fremdrealm"))
      else
        lost = lost + 1
      end
    elseif m.kind == "CHANNEL" and chanWorks then
      local ch = players[m.from] and players[m.from].C.channel
      for n in pairs(channels[ch] or {}) do
        local to = players[n]
        if to and not to.offline then to.fire("CHAT_MSG_ADDON", m.prefix, m.text, "CHANNEL", m.from .. " Stein" .. (to.name == m.from and "" or "-Fremdrealm")) end
      end
    end
  end
end

-- Alle Warteschlangen leeren: Takt fuer Takt senden und zustellen
local function Pump(rounds)
  for _ = 1, rounds or 200 do
    local busy = false
    for _, P in pairs(players) do
      if #P.C.queue > 0 then busy = true end
      P.C.Tick()
    end
    Flush()
    now = now + 2
    if not busy and #net == 0 then return end
  end
end

local function Login(P)
  P.Peon.loggedIn = true
  P.fire("PLAYER_ENTERING_WORLD")
end

local function Dump(v, seen)
  if type(v) ~= "table" then return tostring(v) end
  local t = {}
  for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. Dump(x) end
  return "{" .. table.concat(t, ",") .. "}"
end

---------------------------------------------------------------------------
-- 1. Laden, API, TOC
---------------------------------------------------------------------------
math.randomseed(7)
local A = NewPlayer("Arnulf")
local C, Peon, L = A.C, A.Peon, A.ns.L
check(Peon.API >= 24 and Peon.Comm == C, "Kern-API 24, Peon.Comm")
local toc = io.open("Peon/Peon.toc"):read("*a")
check(toc:find("Notice.lua%s+Comm.lua%s+Slash.lua"), "Comm.lua in der TOC nach Notice und vor Slash")
local src = io.open("Peon/Comm.lua"):read("*a")
check(not src:find("loadstring") and not src:find("RunScript"), "kein fremder Code beim Entpacken")
check(C.IsOn(), "von Anfang an an")
check(C.services.hello, "Kern meldet den Dienst hello selbst an")
check(not C.running and #A.timers == 0, "vor dem Einloggen kein Start")
for _, f in ipairs({ "Register", "Send", "IsOn", "SetOn", "Peers", "Known", "Status" }) do check(type(C[f]) == "function", "Schnittstelle " .. f) end

---------------------------------------------------------------------------
-- 2. Verpacken und Entpacken
---------------------------------------------------------------------------
local data = { 1, 2.5, -3, "a^b|c~d\0e", true, false, x = { y = { z = "tief" } }, [10] = "zehn", leer = "" }
local enc = C.Encode(data)
check(enc and not enc:find("[%^|%z]"), "Verpackt ohne ^, | und Nullzeichen")
local dec = C.Decode(enc)
check(dec and dec[1] == 1 and dec[2] == 2.5 and dec[3] == -3 and dec[4] == "a^b|c~d\0e" and dec[5] == true and dec[6] == false, "Liste zurueck")
check(dec.x.y.z == "tief" and dec[10] == "zehn" and dec.leer == "", "verschachtelt und Schluessel zurueck")
check(C.Decode(C.Encode("Text")) == "Text" and C.Decode(C.Encode(42)) == 42 and C.Decode(C.Encode(false)) == false, "einfache Werte")
check(C.Decode(C.Encode(1234567890123)) == 1234567890123, "grosse Zahl")
check(C.Encode(function() end) == nil and C.Encode(0/0) == nil and C.Encode(SECRET) == nil, "Funktion, NaN, geheimer Wert abgelehnt")
local partial = C.Decode(C.Encode({ a = 1, f = function() end, s = SECRET }))
check(partial and partial.a == 1 and partial.f == nil and partial.s == nil, "unpassende Eintraege einer Tabelle ausgelassen")
check(C.Decode("") == nil and C.Decode("x") == nil and C.Decode("s5:ab") == nil and C.Decode("{n1;") == nil and C.Decode("n1;n2;") == nil, "kaputte Daten -> nil")
local deep = {}
local d = deep
for _ = 1, 20 do d.n = {}; d = d.n end
check(C.Encode(deep) == nil, "zu tief verschachtelt abgelehnt")

---------------------------------------------------------------------------
-- 3. Pruefwert und Format
---------------------------------------------------------------------------
check(#C.Checksum("Arnulf") == 6 and C.Checksum("Arnulf") == C.Checksum("arnulf"), "Pruefwert 6 Zeichen, gross/klein egal")
check(C.Checksum("Arnulf") ~= C.Checksum("Bertha"), "verschiedene Namen, verschiedene Pruefwerte")
check(C.BaseName("Arnulf Stein-Fremdrealm") == "arnulf stein" and C.BaseName(" Arnulf  Stein") == "arnulf stein" and C.BaseName("Arnulf") == "arnulf", "Vor- und Nachname, Realm faellt weg")
check(C.Plain("Arnulf Stein-Fremdrealm") == "Arnulf Stein" and C.Plain("Arnulf") == "Arnulf" and C.Plain("-x") == nil and C.Plain(SECRET) == nil, "Name zum Anfluestern ohne Realm")
check(C.MyName() == "Arnulf Stein" and C.MyCode() == C.Checksum("arnulf stein"), "eigener Name mit Nachname")
local msg = C.Build("hello", "abc123", 2, "d", "1f", 1, 3, "n1;")
local m = C.Parse(msg)
check(m and m.svc == "hello" and m.origin == "abc123" and m.hops == 2 and m.flags == "d" and m.mid == "1f" and m.i == 1 and m.n == 3 and m.payload == "n1;", "Nachricht bauen und lesen")
check(C.Parse(("x"):rep(256)) == nil and C.Parse("1^hello^xyz^0^^1^1^1^") == nil and C.Parse("1^hello^abc123^0^^1^2^1^") == nil and C.Parse("1^hello^abc123^0^^1^1^9^") == nil, "falsches Format abgelehnt")
check(C.Parse(SECRET) == nil, "geheimer Text abgelehnt")

---------------------------------------------------------------------------
-- 4. Start nach dem Einloggen, Kanal beitreten und verstecken, Mitgliederliste
---------------------------------------------------------------------------
local B = NewPlayer("Bertha")
local Cc = NewPlayer("Carlo", { hiddenName = true })
local D = NewPlayer("Dagmar")
local E = NewPlayer("Edwin")
A.fire("PLAYER_ENTERING_WORLD")
check(not C.running, "ohne Login kein Start")
for _, P in ipairs({ A, B, Cc, D, E }) do Login(P) end
check(C.running and A.prefix == "PEON", "gestartet, Praefix angemeldet")
check(#A.tickers == 3, "Takt, Waechter und Begruessung als Zeitgeber")
Login(A)
check(#A.tickers == 3, "zweites Betreten startet nicht doppelt")
Advance(C.JOIN_DELAY - 1)
check(not A.joined.PeonNet, "nicht sofort beitreten (Standardkanaele zuerst)")
Advance(2); Advance(4)
check(A.joined.PeonNet and C.channel == "PeonNet", "Kanal PeonNet beigetreten")
check(A.removed[1] == "PeonNet" and #A.removed == 2, "Kanal aus allen Chatfenstern entfernt")
A.fire("UPDATE_CHAT_WINDOWS")
check(#A.removed == 4, "nach Aenderung der Chatfenster erneut versteckt")
C.ReadRoster()
check(C.Peers() == 4, "vier andere erreichbar, eigener Name ausgelassen: " .. C.Peers())
check(C.nameSet["carlo stein"] == "Carlo Stein", "Name ueber die Spieler-ID, wenn die Liste ihn nicht zeigt")
check(not C.nameSet["arnulf stein"], "sich selbst nicht")

---------------------------------------------------------------------------
-- 5. Kennenlernen: Begruessung im Kanal, Antwort per Fluestern
---------------------------------------------------------------------------
Advance(C.HELLO_FIRST)
Pump()
local function Known(P) return P.C.Known() end
check(Known(A) == 4, "A kennt alle vier (Begruessungen im Kanal und Antworten): " .. Known(A))
local reached = 0
for _, P in ipairs({ B, Cc, D, E }) do if P.Peon.db.comm.peers[C.MyCode()] then reached = reached + 1 end end
check(reached == 4, "alle vier kennen A ueber den Kanal: " .. reached)
check((B.Peon.db.comm.peers[C.MyCode()].c or 0) >= 1, "Begruessung kam ueber den Kanal")
check((A.Peon.db.comm.peers[B.C.MyCode()].w or 0) >= 1 or (A.Peon.db.comm.peers[B.C.MyCode()].c or 0) >= 1, "B bei A bekannt")
local pa = B.Peon.db.comm.peers[C.MyCode()]
check(pa.v == Peon.version and pa.a == Peon.API and pa.n >= 1 and pa.first and pa.last, "Version, API, Anzahl und Zeit gemerkt")
for _, P in ipairs({ A, B, Cc, D, E }) do
  local s = Dump(P.Peon.db)
  for n in pairs(players) do check(not s:find(n), "kein Charaktername in PeonDB von " .. P.name .. ": " .. n) end
end
local cdb = A.Peon.db.comm
check(cdb.chanSent > 0 and cdb.recv > 0 and cdb.chanRecv > 0, "Zaehler gesendet und empfangen")
local relayedAll = 0
for _, P in ipairs({ A, B, Cc, D, E }) do relayedAll = relayedAll + P.Peon.db.comm.relayed end
check(relayedAll == 0, "ab 0.24.0 nichts weitergegeben")
local st = C.Status()
check(st.on and st.running and st.channel == "PeonNet" and st.peers == 4 and st.known == Known(A), "Stand: " .. Dump(st))
check(C.StatusText():find("PeonNet") and C.StatusText():find(tostring(st.known)), "Stand als Text")
-- Antwort nur einmal je Urheber in REPLY_PAUSE
local R
for _, P in ipairs({ B, Cc, D, E }) do if P.C.replied[C.MyCode()] then R = P end end
check(R, "mindestens einer hat A direkt geantwortet")
R.C.OnHello({ v = "x", a = 1 }, { origin = C.MyCode(), hops = 0, reply = function() fail("zweite Antwort") end })
check(true, "keine zweite Antwort kurz danach")
-- Antworten loesen keine Antwort aus
local replied = false
B.C.OnHello({ v = "x", a = 1, r = true }, { origin = "fedcba", hops = 0, reply = function() replied = true end })
check(not replied, "auf eine Antwort wird nicht geantwortet")
-- Weitergegebene Begruessung: keine Antwort (Urheber unbekannt)
B.C.OnHello({ v = "x", a = 1 }, { origin = "abcdef", hops = 1, reply = function() replied = true end })
check(not replied, "auf weitergegebene Begruessung keine Antwort")
-- Erste Begruessung: jeder antwortet einmal. Spaetere Begruessungen im Kanal: keine Antworten mehr
check(C.helloAt and C.SayHello() == 0, "Begruessung hoechstens alle 30 Minuten")
local sentBefore = 0
for _, P in ipairs({ B, Cc, D, E }) do sentBefore = sentBefore + P.Peon.db.comm.sent end
C.helloAt = now - C.HELLO_EVERY
check(C.SayHello() == 1, "naechste Begruessung: eine Nachricht im Kanal")
for _, P in ipairs({ B, Cc, D, E }) do wipe(P.C.replied) end
Pump()
local sentAfter = 0
for _, P in ipairs({ B, Cc, D, E }) do sentAfter = sentAfter + P.Peon.db.comm.sent end
check(sentAfter == sentBefore, "auf spaetere Begruessung im Kanal antwortet niemand")

---------------------------------------------------------------------------
-- 6. Eigener Dienst: Senden, Empfangen, Teile, Weitergabe-Grenzen
---------------------------------------------------------------------------
local got = {}
for _, P in ipairs({ A, B, Cc, D, E }) do
  P.C.Register("test", { version = 1, onReceive = function(d, info) got[#got + 1] = { who = P.name, d = d, info = info } end })
end
check(C.Register("test", {}) == false and C.Register("mit leer", {}) == false and C.Register(("x"):rep(13), {}) == false, "Dienst nur einmal, Name nur Buchstaben, Ziffern, _ und hoechstens 12 Zeichen")
check(C.Send("unbekannt", 1) == 0, "unbekannter Dienst sendet nicht")
check(C.Send("test", function() end) == 0, "nicht verpackbare Daten senden nicht")
local n = C.Send("test", { gruss = "hallo" })
check(n == 1 and C.queue[#C.queue][3] == "CHANNEL", "an alle: eine Nachricht in den Kanal: " .. n)
Pump()
local whoGot = {}
for _, g in ipairs(got) do whoGot[g.who] = (whoGot[g.who] or 0) + 1 end
local reachedN, twice = 0, false
for _, c in pairs(whoGot) do reachedN = reachedN + 1; if c > 1 then twice = true end end
check(reachedN == 4 and not twice and not whoGot.Arnulf, "alle vier, keiner doppelt, der Urheber nicht: " .. Dump(whoGot))
check(got[1].d.gruss == "hallo" and got[1].info.origin == C.MyCode() and got[1].info.via == "c", "Daten, Urheber, Weg Kanal")
for _, g in ipairs(got) do check(g.info.hops == 0, "keine Weitergabe") end
-- Ohne Kanal kann nicht an alle gesendet werden
local chSave = C.channel
C.channel = nil
check(C.Send("test", 1) == 0 and C.SendChannel("test", 1) == 0, "ohne Kanal nichts an alle")
C.channel = chSave
-- Lange Daten in Teilen
got = {}
local long = ("Erzader am Hang "):rep(60)
n = C.Send("test", { t = long })
check(n > 1, "lange Daten in mehreren Teilen: " .. n)
Pump()
check(#got == 4 and got[1].d.t == long and got[#got].d.t == long, "lange Daten bei allen vollstaendig zusammengesetzt")
check(C.Send("test", ("y"):rep(5000)) == 0, "zu lange Daten abgelehnt")
-- Direkt an einen Spieler: keine Weitergabe, Antwort ueber info.reply
got = {}
n = C.Send("test", "nur fuer dich", { to = "Bertha Stein" })
check(n == 1, "direkt an einen")
Pump()
check(#got == 1 and got[1].who == "Bertha" and got[1].info.direct and got[1].info.via == "w", "nur Bertha, per Fluestern")
check(got[1].info.name == "Arnulf Stein", "Name des Absenders ohne Realm (API 24)")
got[1].info.reply("zurueck")
got = {}
Pump()
check(#got == 1 and got[1].who == "Arnulf" and got[1].d == "zurueck" and got[1].info.direct, "Antwort kommt beim Absender an")

---------------------------------------------------------------------------
-- 7. Schutz: gefaelschter Urheber, doppelt, Grenzen, unbekannter Dienst, neueres Format, Fehler im Dienst
---------------------------------------------------------------------------
local bdb = B.Peon.db.comm
local bad0 = bdb.bad
got = {}
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("test", C.Checksum("dagmar stein"), 0, "", "aa1", 1, 1, C.Encode("falsch")), "WHISPER", "Edwin Stein-Fremdrealm")
check(bdb.bad == bad0 + 1 and #got == 0, "Urheber passt beim ersten Sprung nicht zum Absender: verworfen")
local good = B.C.Build("test", C.Checksum("edwin stein"), 0, "", "aa2", 1, 1, C.Encode("echt"))
B.fire("CHAT_MSG_ADDON", "PEON", good, "WHISPER", "Edwin Stein-Fremdrealm")
local dup0 = bdb.dup
B.fire("CHAT_MSG_ADDON", "PEON", good, "WHISPER", "Edwin Stein-Fremdrealm")
check(#got == 1 and bdb.dup == dup0 + 1, "doppelte Nachricht erkannt")
local q0 = #B.C.queue
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("test", "abcdef", C.MAX_HOPS, "", "aa3", 1, 1, C.Encode(1)), "WHISPER", "Edwin Stein-Fremdrealm")
check(#B.C.queue == q0 and #got == 2, "nach " .. C.MAX_HOPS .. " Spruengen nicht mehr weitergegeben, aber zugestellt")
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("test", "abcdef", 1, "d", "aa4", 1, 1, C.Encode(1)), "WHISPER", "Edwin Stein-Fremdrealm")
check(#B.C.queue == q0, "direkte Nachricht nicht weitergegeben")
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("neu", "abcdef", 1, "", "aa5", 1, 1, C.Encode(1)), "WHISPER", "Edwin Stein-Fremdrealm")
check(#B.C.queue > q0 and #got == 3, "unbekannter Dienst wird weitergegeben, nicht zugestellt")
wipe(B.C.queue)
B.fire("CHAT_MSG_ADDON", "PEON", "2^test^abcdef^1^^aa6^1^1^n1;", "WHISPER", "Edwin Stein-Fremdrealm")
check(#B.C.queue == 0 and #got == 3, "neueres Format: weder verstanden noch weitergegeben")
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("test", "abcdef", 1, "", "aa7", 1, 1, C.Encode(1)), "WHISPER", SECRET)
B.fire("CHAT_MSG_ADDON", "PEON", SECRET, "WHISPER", "Edwin Stein-Fremdrealm")
check(#got == 3, "geheime Werte ignoriert")
B.fire("CHAT_MSG_ADDON", "ANDERS", good, "WHISPER", "Edwin Stein-Fremdrealm")
check(#got == 3, "fremdes Praefix ignoriert")
B.C.Register("kaputt", { onReceive = function() error("kaputt im Dienst") end })
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("kaputt", "abcdef", 1, "", "aa8", 1, 1, C.Encode(1)), "WHISPER", "Edwin Stein-Fremdrealm")
local errs = B.Peon.db.errors or {}
check(#errs == 1 and errs[1].where == "Comm kaputt" and errs[1].msg:find("kaputt im Dienst"), "Fehler im Dienst gespeichert, kein Abbruch")
wipe(B.C.queue)

-- Absender kommt nur mit Vornamen: Pruefwert nicht pruefbar, trotzdem annehmen
local r0 = B.Peon.db.comm.recv
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("test", C.Checksum("edwin stein"), 0, "", "aa9", 1, 1, C.Encode(1)), "WHISPER", "Edwin")
check(B.Peon.db.comm.recv == r0 + 1, "Absender ohne Nachname angenommen")

---------------------------------------------------------------------------
-- 8. Takt, Warteschlange, Kampf, Instanz
---------------------------------------------------------------------------
wipe(net)
for i = 1, 5 do C.queue[#C.queue + 1] = { "Bertha", "x" .. i } end
C.Tick()
check(#net == 1 and #C.queue == 4, "ein Fluestern je Takt")
A.combat = true
C.Tick()
check(#net == 1 and #C.queue == 4, "im Kampf nichts senden, nichts verwerfen")
A.combat = false
A.instance = true
C.Tick()
check(#net == 1 and #C.queue == 4 and not C.CanSend(), "in Instanzen nichts senden")
A.instance = false
check(C.CanSend(), "danach wieder")
wipe(C.queue); wipe(net)
for i = 1, C.MAX_QUEUE + 20 do C.queue[#C.queue + 1] = { "Bertha", "x" } end
check(C.Send("test", 1) == 0, "volle Warteschlange nimmt nichts mehr an")
wipe(C.queue)

---------------------------------------------------------------------------
-- 9. Offline-Meldung des Spiels
---------------------------------------------------------------------------
C.queue[1] = { "Dagmar Stein", "x" }
C.Tick()
C.queue[1] = { "Dagmar Stein", "y" }
check(A.filter, "Filter fuer Systemmeldungen angemeldet")
check(A.filter(nil, "CHAT_MSG_SYSTEM", "Kein Spieler namens 'Dagmar Stein' ist online.") == true, "Offline-Meldung nach eigenem Fluestern ausgeblendet")
check(not C.nameSet["dagmar stein"] and #C.queue == 0, "Spieler entfernt, Warteschlange bereinigt")
check(C.AddName("Dagmar Stein-Fremdrealm") == false, "fuer eine Weile nicht wieder aufgenommen")
check(A.filter(nil, "CHAT_MSG_SYSTEM", "Kein Spieler namens 'Fremder' ist online.") == false, "fremde Offline-Meldung bleibt sichtbar")
check(A.filter(nil, "CHAT_MSG_SYSTEM", "Etwas anderes") == false, "andere Meldungen bleiben")
now = now + C.OFFLINE_PAUSE + 1
C.Purge()
check(C.AddName("Dagmar Stein") == true, "nach der Pause wieder erreichbar")

---------------------------------------------------------------------------
-- 10. Neuer Spieler im Kanal wird begruesst
---------------------------------------------------------------------------
local F = NewPlayer("Frieda")
Login(F)
Advance(C.JOIN_DELAY + 5)
A.fire("CHAT_MSG_CHANNEL_JOIN", "", "Frieda Stein", "", "5. PeonNet", "Frieda Stein", "", 0, 5, "PeonNet")
check(C.nameSet["frieda stein"] and #C.queue == 1 and C.queue[1][1] == "Frieda Stein", "neuer Spieler im Kanal bekommt eine direkte Begruessung")
A.fire("CHAT_MSG_CHANNEL_JOIN", "", "Gustav", "", "1. Allgemein", "Gustav", "", 0, 1, "Allgemein")
check(not C.nameSet.gustav, "Beitritt in anderen Kanaelen zaehlt nicht")
Pump()
check(F.Peon.db.comm.peers[C.MyCode()] and A.Peon.db.comm.peers[F.C.MyCode()], "beide kennen sich nach Begruessung und Antwort")

---------------------------------------------------------------------------
-- 11. Obergrenze der gemerkten Peon-Nutzer
---------------------------------------------------------------------------
local fdb = F.Peon.db.comm
for i = 1, C.MAX_PEERS + 5 do
  now = now + 1
  F.C.OnHello({ v = "1", a = 23, r = true }, { origin = ("%06x"):format(i), hops = 1, reply = function() end })
end
local cnt = 0
for _ in pairs(fdb.peers) do cnt = cnt + 1 end
check(cnt == C.MAX_PEERS and not fdb.peers[("%06x"):format(1)] and fdb.peers[("%06x"):format(C.MAX_PEERS + 5)], "hoechstens " .. C.MAX_PEERS .. ", die aeltesten fallen weg")

---------------------------------------------------------------------------
-- 12. Abschalten und wieder Einschalten
---------------------------------------------------------------------------
C.queue[1] = { "Bertha", "x" }
A.env.SlashCmdList.PEON("teilen aus")
check(not C.IsOn() and A.Peon.db.commOff == true and not C.running, "/peon teilen aus schaltet ab")
check(not A.joined.PeonNet and not channels.PeonNet.Arnulf and #C.queue == 0 and C.Peers() == 0, "Kanal verlassen, Warteschlange und Namen geleert")
check(A.out[#A.out]:find(L.COMM_NOW_OFF, 1, true), "Meldung im Chat")
check(C.Send("test", 1) == 0, "aus: nichts senden")
got = {}
A.fire("CHAT_MSG_ADDON", "PEON", C.Build("test", C.Checksum("bertha stein"), 0, "", "bb1", 1, 1, C.Encode(1)), "WHISPER", "Bertha Stein-Fremdrealm")
check(#got == 0, "aus: nichts annehmen")
C.Watch()
check(not A.joined.PeonNet, "aus: Waechter tritt nicht bei")
A.env.SlashCmdList.PEON("teilen")
check(A.out[#A.out - #L.COMM_HELP]:find(L.COMM_STATUS_OFF, 1, true), "Stand zeigt aus")
A.env.SlashCmdList.PEON("teilen an")
check(C.IsOn() and A.Peon.db.commOff == nil and C.running, "/peon teilen an schaltet ein")
Advance(C.JOIN_DELAY + 5)
check(A.joined.PeonNet and C.Peers() > 0, "wieder im Kanal, Mitglieder gelesen")
check(#A.tickers == 3, "Zeitgeber nicht doppelt")

-- Ausweichkanal und Waechter
local G = NewPlayer("Gesine")
locked.PeonNet = true
Login(G)
Advance(C.JOIN_DELAY + 30)
check(G.C.channel == "PeonNet2" and G.joined.PeonNet2, "gesperrter Kanal: Ausweichname PeonNet2")
locked.PeonNet = nil
G.env.LeaveChannelByName("PeonNet2")
G.C.Watch()
Advance(5)
check(G.C.channel == "PeonNet", "Waechter tritt nach Verlust neu bei")

-- Liste ohne Anzahl (Forever meldet oft 0): trotzdem lesen, sonst beim Server anfordern
local H = NewPlayer("Hilde", { zeroCount = true })
Login(H)
Advance(C.JOIN_DELAY + 5)
check(H.C.Peers() >= 3, "Mitglieder gelesen, obwohl das Spiel 0 meldet")
channels.PeonNet = { Hilde = true }
wipe(H.C.names); wipe(H.C.nameSet)
H.C.ReadRoster()
check(H.requested, "fast leere Liste: beim Server angefordert")
-- Bremse: Antwort des Servers fordert nicht die naechste an, sonst hoechstens einmal je Minute
H.requested = nil
for _ = 1, 20 do H.fire("CHANNEL_ROSTER_UPDATE") end
check(not H.requested, "Liste vom Server loest keine neue Anfrage aus")
H.C.ReadRoster()
check(not H.requested, "innerhalb einer Minute nicht noch einmal angefordert")
now = now + H.C.ROSTER_ASK_EVERY
H.C.ReadRoster()
check(H.requested, "nach einer Minute wieder angefordert")
-- Verstecken nur, wenn der Kanal im Fenster steht, nach Aenderung der Chatfenster gebremst
local hr = #H.removed
rawset(H.env.ChatFrame1, "channelList", { "Allgemein" })
rawset(H.env.ChatFrame2, "channelList", { "Allgemein", "PeonNet" })
H.C.Hide()
check(#H.removed == hr + 1, "nur aus dem Fenster entfernt, in dem der Kanal steht")
now = now + H.C.HIDE_EVERY
hr = #H.removed
for _ = 1, 10 do H.fire("UPDATE_CHAT_WINDOWS") end
check(#H.removed == hr + 1, "viele Aenderungen der Chatfenster: nur einmal versteckt")
rawset(H.env.ChatFrame1, "channelList", nil); rawset(H.env.ChatFrame2, "channelList", nil)

-- Begruessung nachholen, wenn beim ersten Versuch niemand da war
local I = NewPlayer("Ingo")
channels.PeonNet = {}
Login(I)
Advance(C.HELLO_FIRST + 1)
check(I.C.helloAt ~= nil, "allein: Begruessung trotzdem in den Kanal")
-- War der Kanal bei der ersten Begruessung noch nicht da, holt der Waechter sie nach
I.C.helloAt = nil; wipe(I.C.queue)
local chI = I.C.channel
I.C.channel = nil
check(I.C.SayHello() == 0 and not I.C.helloAt, "ohne Kanal keine Begruessung")
I.C.channel = chI
I.C.Watch()
check(I.C.helloAt and #I.C.queue > 0, "Waechter holt die Begruessung nach")

---------------------------------------------------------------------------
-- 13. Pruefbefehl: Kanal-Nachricht und Fluestern an sich selbst, Liste lesbar
---------------------------------------------------------------------------
channels.PeonNet = { Arnulf = true, Bertha = true, Carlo = true }
A.env.SlashCmdList.PEON("teilen pruefen")
check(A.out[#A.out]:find(L.COMM_PROBE_START, 1, true), "Pruefung startet")
check(C.probe.busy, "laeuft")
check(C.Probe() == false, "kein zweiter Lauf gleichzeitig")
local kinds = {}
for _, x in ipairs(net) do kinds[x.kind] = (kinds[x.kind] or 0) + 1 end
check(kinds.CHANNEL == 1 and kinds.WHISPER == 1, "eine Kanal-Nachricht und ein Fluestern an sich selbst")
local targets = {}
for _, x in ipairs(net) do if x.kind == "WHISPER" then targets[x.target] = true end end
check(targets["Arnulf Stein"], "an den vollen Namen")
Flush()
Advance(C.PROBE_WAIT + 1)
local pr = A.Peon.db.comm.probe
check(pr and pr.joined and pr.channel == "PeonNet" and pr.chanSent and pr.chanEcho, "Kanal: gesendet und angekommen")
check(pr.whisperSent and pr.whisperEcho and pr.spaceEcho == nil and pr.hyphenEcho == nil, "Fluestern an sich selbst angekommen")
check(pr.myForm == "a a" and pr.guidForm == "a a" and pr.rosterForm == "a a" and pr.senderForm == "a a", "Form der Namen ohne Namen gespeichert: " .. Dump(pr))
check(pr.roster == 3 and pr.count == 3 and pr.build == 70009 and pr.at ~= nil, "Mitgliederliste und Build gespeichert: " .. Dump(pr))
local tail = table.concat(A.out, "\n", #A.out - 4)
check(tail:find(L.COMM_PROBE_SAVED, 1, true) and tail:find("PeonNet"), "Ergebnis im Chat")
check(not Dump(pr):find("Arnulf") and not Dump(pr):find("Bertha") and not Dump(pr):find("Stein"), "keine Namen im Ergebnis")
A.combat = true
check(C.Probe() == false and A.out[#A.out]:find(L.COMM_PROBE_COMBAT, 1, true), "nicht im Kampf")
A.combat = false
C.SetOn(false)
check(C.Probe() == false and A.out[#A.out]:find(L.COMM_OFF_HINT, 1, true), "aus: Hinweis statt Pruefung")
C.SetOn(true)
Advance(C.JOIN_DELAY + 5)

---------------------------------------------------------------------------
-- 14. Schalter in den Kern-Optionen
---------------------------------------------------------------------------
A.ns.CreateOptions()
local o = C.option
check(o and o.check and o.title.txt == L.COMM_OPT and o.label.txt == L.COMM_OPT_SHARE and o.hint.txt == L.COMM_OPT_HINT, "Abschnitt mit Schalter und Hinweis")
check(o.check.checked == true and o.status.txt:find("PeonNet"), "Schalter an, Stand sichtbar")
o.check.checked = false
o.check.scripts.OnClick(o.check)
check(not C.IsOn() and o.status.txt == L.COMM_STATUS_OFF, "Klick schaltet aus")
o.check.checked = true
o.check.scripts.OnClick(o.check)
check(C.IsOn() and C.running, "Klick schaltet ein")
A.Peon.db.commOff = true
local panelShow
for _, f in ipairs(A.frames) do if f.scripts.OnShow then panelShow = f end end
panelShow.scripts.OnShow(panelShow)
check(o.check.checked == false, "Anzeige folgt dem gespeicherten Wert")
A.Peon.db.commOff = nil

-- Englische Texte vollstaendig
for _, k in ipairs({ "COMM_OPT", "COMM_OPT_SHARE", "COMM_OPT_HINT", "COMM_STATUS", "COMM_STATUS_OFF", "COMM_OFF_HINT", "COMM_NOW_ON", "COMM_NOW_OFF", "COMM_PROBE_START", "COMM_PROBE_COMBAT", "COMM_PROBE_CHANNEL", "COMM_PROBE_CHAN_ECHO", "COMM_PROBE_WHISPER", "COMM_PROBE_ROSTER", "COMM_PROBE_SAVED", "COMM_YES", "COMM_NO" }) do
  check(L[k] ~= k, "Text " .. k)
end
check(type(L.COMM_HELP) == "table" and #L.COMM_HELP == 2, "Hilfe")
check(not (A.Peon.db.errors and #A.Peon.db.errors > 0), "keine Fehler bei A: " .. Dump(A.Peon.db.errors))

---------------------------------------------------------------------------
-- 15. Erste Begruessung mit Antwort, Weg je Peon-Nutzer, Nachrichten von Peon 0.23.0
---------------------------------------------------------------------------
Advance(C.JOIN_DELAY + 5)
channels.PeonNet = { Arnulf = true, Bertha = true, Dagmar = true }
check(C.channel == "PeonNet" and B.C.channel == "PeonNet", "A und B im Kanal")
C.ReadRoster()
wipe(C.queue); C.helloAt = nil; wipe(B.C.replied)
local chanBefore = A.Peon.db.comm.chanSent
local function ChanQueued() local k = 0 for _, q in ipairs(C.queue) do if q[3] == "CHANNEL" then k = k + 1 end end return k end
C.SayHello()
check(ChanQueued() == 1, "Begruessung einmal in den Kanal")
C.SayHello()
check(ChanQueued() == 1, "innerhalb von 30 Minuten nicht noch einmal")
check(C.SayHello("Bertha Stein") >= 1 and ChanQueued() == 1, "direkte Begruessung nicht in den Kanal")
Pump()
check(A.Peon.db.comm.chanSent == chanBefore + 1, "Kanal-Nachricht gesendet")
local pB = B.Peon.db.comm.peers[C.MyCode()]
check(pB and (pB.c or 0) >= 1 and B.Peon.db.comm.chanRecv >= 1, "B kennt A ueber den Kanal: " .. Dump(pB))
local pA = A.Peon.db.comm.peers[B.C.MyCode()]
check(pA and (pA.w or 0) >= 1, "Antwort von B kam per Fluestern: " .. Dump(pA))
check(A.Peon.db.comm.peers[C.MyCode()] == nil, "eigene Kanal-Nachricht nicht als fremder Nutzer gezaehlt")
-- Peon 0.23.0 schickt Fluestern ohne Flag d: wird weiter verstanden und weitergegeben
local relB = B.Peon.db.comm.relayed
local gotOld = #got
B.fire("CHAT_MSG_ADDON", "PEON", B.C.Build("test", C.Checksum("edwin stein"), 0, "", "alt1", 1, 1, C.Encode("alt")), "WHISPER", "Edwin Stein-Fremdrealm")
check(B.Peon.db.comm.relayed == relB + 1 and #got == gotOld + 1, "Nachricht von 0.23.0 zugestellt und weitergegeben")

---------------------------------------------------------------------------
-- 16. Schalter fuer Peon_Debug
---------------------------------------------------------------------------
local heardA, heardB = {}, {}
check(C.Listen(function(d, k, w, t) heardA[#heardA + 1] = d .. k end) and not C.Listen("x"), "Listen nimmt nur Funktionen")
B.C.Listen(function(d, k, w, t) heardB[#heardB + 1] = d .. k .. ":" .. tostring(w) end)
local errB = #(B.Peon.db.errors or {})
B.C.Listen(function() error("kaputt") end)
C.Send("test", 1, { to = "Bertha Stein" })
Pump()
check(table.concat(heardA, ","):find("outWHISPER", 1, true), "A sieht die eigene Nachricht")
check(table.concat(heardB, ","):find("inWHISPER:Arnulf Stein-Fremdrealm", 1, true), "B sieht die empfangene Nachricht mit Absender")
check(#(B.Peon.db.errors or {}) == errB, "Fehler im Zuhoerer stoert nicht: " .. Dump(B.Peon.db.errors))
local r = #A.removed
check(C.SetShow("channel", true) and A.added == "PeonNet", "Kanal wieder ins Chatfenster")
A.fire("UPDATE_CHAT_WINDOWS")
check(#A.removed == r, "Kanal bleibt sichtbar")
C.SetShow("channel", false)
check(#A.removed > r, "Kanal wieder versteckt")
C.SetShow("whisper", true)
check(C.AddName("Zora Stein"), "Zora erreichbar")
C.whispered["zora stein"] = now
check(A.filter(nil, "CHAT_MSG_SYSTEM", "Kein Spieler namens 'Zora Stein' ist online.") == false and not C.nameSet["zora stein"], "Meldung sichtbar, Name trotzdem entfernt")
C.SetShow("whisper", false)
check(C.SetShow("anderes", true) == false, "unbekannter Schalter abgelehnt")

check(realmLost == 0, "nie an einen Namen mit Realm gefluestert: " .. realmLost)
for _, P in pairs(players) do for _, n in ipairs(P.C.names) do check(not n:find("-", 1, true), "gemerkter Name ohne Realm: " .. n) end end

realPrint("Zugestellte Fluesternachrichten im Test: " .. delivered)
realPrint("ALLE TESTS OK")
