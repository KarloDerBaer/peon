-- Peon_Bridge - Bridge.lua (bis 0.3.0 Peon_Client)
-- Verbindung zwischen Spiel und Peon Manager auf dem PC (Design: docs/konzepte/manager/Peon_GitHub_Design.md, Abschnitt 4).
--
-- Die Bridge ist nur der Transport. Inhalte melden sich als Kanal an (ns.RegisterChannel), der erste ist "broker"
-- (Channel_Broker.lua). Ein Kanal arbeitet nur, wenn der Manager ihn freischaltet.
--
-- Spiel -> Manager: Kanaele legen Momentaufnahmen in PeonBridgeDB.queue. Das Spiel schreibt PeonBridgeDB bei Reload,
--   Ausloggen oder Beenden nach WTF (Peon_Bridge.lua), dort liest der Manager.
-- Manager -> Spiel: Der Manager schreibt Data.lua in diesen Ordner (PeonBridgeData, nie mit ausgeliefert):
--   fmt = 2, t, manager = Version, channels = { broker = true }, ack = { [id] = true }, markets = { ... } (Kanal broker),
--   errorsClearBefore = Zeitpunkt (Fehlerspeicher des Kerns bis dahin loeschen, ab 0.5.0)
--   Ohne channels (Platzhalter, altes Format, kein Manager) ist kein Kanal freigeschaltet.

local ADDON_NAME, ns = ...
local L = ns.L

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "bridge",            -- /peon bridge ...
    title    = "Bridge",
    db       = "PeonBridgeDB",
    defaults = {
        queueMax    = 10,           -- Komplettscans bis zur Abholung
        liveMax     = 500,          -- Live-Abfragen bis zur Abholung (0 = keine)
        offerButton = true,         -- nach einem Scan Knopf "An Manager" anbieten
        freshDays   = 7,            -- Werte des Managers gelten so viele Tage (Rechenmodell Kapitel 8, FRISCH)
    },
    ranges   = { queueMax = { 1, 30, 1 }, liveMax = { 0, 2000, 50 }, freshDays = { 1, 30, 1 } },
    onSlash  = function(m, cmd) ns.Slash(cmd) end,
})
ns.mod = mod

ns.FMT = 1        -- Format der Momentaufnahmen (Peon_Client_Design.md, Abschnitt 6.3)
ns.DATA_FMT = 2   -- Format von Data.lua mit channels (Peon_GitHub_Design.md, Abschnitt 4.3)

---------------------------------------------------------------------------
-- Kanaele
---------------------------------------------------------------------------
-- def: title (Anzeige), start = function() (wird bei Freischaltung aufgerufen, Rueckgabe true = laeuft),
--      status = function(on) -> Liste von Zeilen fuer den Stand
ns.channels, ns.channelOrder = {}, {}

function ns.RegisterChannel(key, def)
    if type(key) ~= "string" or type(def) ~= "table" then return end
    if not ns.channels[key] then ns.channelOrder[#ns.channelOrder + 1] = key end
    ns.channels[key] = def
end

-- Ist der Kanal vom Manager freigeschaltet?
function ns.ChannelOn(key)
    local d = ns.ManagerData()
    if not d or d.fmt ~= ns.DATA_FMT or type(d.channels) ~= "table" then return false end
    return d.channels[key] == true
end

-- Freigeschaltete Kanaele starten. Rueckgabe: Anzahl laufender Kanaele
function ns.StartChannels()
    local n = 0
    for _, key in ipairs(ns.channelOrder) do
        local def = ns.channels[key]
        if def.running then
            n = n + 1
        elseif ns.ChannelOn(key) and type(def.start) == "function" then
            local ok, r = pcall(def.start)
            if ok and r then def.running = true; n = n + 1
            elseif not ok then mod:ReportError("Kanal " .. key, r) end
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Warteschlange und Bestaetigung
---------------------------------------------------------------------------
-- Warteschlange und Zustand liegen ausserhalb der Einstellungen (bleiben bei "Standardwerte")
function ns.Prepare()
    local acc = mod.acc
    if type(acc.queue) ~= "table" then acc.queue = {} end
    if type(acc.nameIds) ~= "table" then acc.nameIds = {} end   -- itemIDs, deren Namen der Manager schon hat
    if type(acc.seq) ~= "number" then acc.seq = 0 end
    -- ab Peon_Client 0.3.0 haengen an jedem Namen Haendlerpreis und Warenart: alle Namen einmal neu schicken
    if acc.nameFmt ~= 2 then acc.nameIds, acc.nameFmt = {}, 2 end
    acc.fmt = ns.FMT
end

-- Daten des Managers (Data.lua), nil wenn nicht da
function ns.ManagerData()
    local d = rawget(_G, "PeonBridgeData")
    if type(d) ~= "table" then return nil end
    return d
end

-- Abgeholte Momentaufnahmen aus der Warteschlange loeschen. Rueckgabe: Anzahl geloescht
function ns.ApplyAck()
    local d = ns.ManagerData()
    local ack = d and d.ack
    if type(ack) ~= "table" then return 0 end
    local keep, n = {}, 0
    for _, e in ipairs(mod.acc.queue) do
        if type(e) == "table" and e.id ~= nil and ack[e.id] then
            n = n + 1
            -- als uebergeben gilt ein Name erst mit Haendlerpreis (sonst beim naechsten Scan nochmal, Spiel kannte ihn noch nicht)
            if type(e.names) == "table" then
                for id, v in pairs(e.names) do
                    if type(v) ~= "string" or v:match("^[^|]*|[^|]*|%d+") then mod.acc.nameIds[id] = true end
                end
            end
        else
            keep[#keep + 1] = e
        end
    end
    mod.acc.queue = keep
    if n > 0 then
        mod.acc.ackAt, mod.acc.ackN = (type(d.t) == "number" and d.t) or time(), n
    end
    return n
end

-- Der Manager hat Fehler uebernommen: im Fehlerspeicher des Kerns loeschen (Kern ab API 12, sonst nichts zu tun)
function ns.ApplyErrorClear()
    local d = ns.ManagerData()
    local upTo = d and d.errorsClearBefore
    if type(upTo) ~= "number" or not Peon.ClearErrors then return 0 end
    return Peon.ClearErrors(upTo)
end

-- Zaehler fuer Anzeige und Tests
function ns.QueueInfo()
    local scans, live, bytes, last = 0, 0, 0, nil
    for _, e in ipairs(mod.acc.queue or {}) do
        if e.kind == "scan" then scans = scans + 1 else live = live + 1 end
        bytes = bytes + (type(e.rows) == "string" and #e.rows or 0) + 200
        if type(e.names) == "table" then for _ in pairs(e.names) do bytes = bytes + 30 end end
        if type(e.t) == "number" and (not last or e.t > last) then last = e.t end
    end
    return scans, live, bytes, last
end

function ns.Size(bytes)
    if bytes >= 1024 * 1024 then return ("%.1f MB"):format(bytes / 1024 / 1024) end
    return ("%d KB"):format(math.max(1, math.floor(bytes / 1024 + 0.5)))
end

function ns.When(t)
    if type(t) ~= "number" then return "?" end
    return date("%d.%m. %H:%M", t)
end

function ns.Send()
    if ReloadUI then ReloadUI() end
end

function ns.Slash(cmd)
    cmd = (cmd or ""):lower()
    if cmd == "senden" or cmd == "send" then
        ns.Send()
    elseif cmd == "status" then
        for _, line in ipairs(ns.StatusLines()) do mod:Print(line) end
    else
        mod:OpenOptions()
    end
end

function ns.StatusLines()
    local out = {}
    local d = ns.ManagerData()
    if d and type(d.t) == "number" then
        out[#out + 1] = L.ST_MANAGER:format(ns.When(d.t), type(d.manager) == "string" and d.manager or "?")
    else
        out[#out + 1] = L.ST_MANAGER_NONE
    end
    for _, key in ipairs(ns.channelOrder) do
        local def, on = ns.channels[key], ns.ChannelOn(key)
        out[#out + 1] = (on and L.ST_CHANNEL_ON or L.ST_CHANNEL_OFF):format(key)
        if type(def.status) == "function" then
            local ok, lines = pcall(def.status, on)
            if ok and type(lines) == "table" then for _, l in ipairs(lines) do out[#out + 1] = l end end
        end
    end
    local scans, live, bytes, last = ns.QueueInfo()
    if scans + live == 0 then out[#out + 1] = L.ST_QUEUE_EMPTY
    else out[#out + 1] = L.ST_QUEUE:format(scans, live, ns.Size(bytes)) end
    if last then out[#out + 1] = L.ST_LAST:format(ns.When(last)) end
    if mod.acc.ackAt then out[#out + 1] = L.ST_ACK:format(ns.When(mod.acc.ackAt), mod.acc.ackN or 0)
    else out[#out + 1] = L.ST_ACK_NONE end
    return out
end

mod:On("INIT", function()
    ns.Prepare()
    local n = ns.ApplyAck()
    if n > 0 then mod:Dbg(("Bestaetigt: %d Momentaufnahmen geloescht"):format(n)) end
    ns.ApplyErrorClear()
    ns.StartChannels()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
end)

mod:On("LOGIN", function()
    ns.StartChannels()
end)

-- Bereiche für Rückmeldungen (Kern ab API 9; mit älterem Kern wird nichts gemeldet)
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Übergabe", "Warteschlange", "Knopf am Auktionshaus", "Werte des Managers", "Optionen" }) end
