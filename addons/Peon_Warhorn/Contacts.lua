-- Peon_Warhorn - Contacts.lua
-- Ab 0.5.0 (Wunsch KarloDerBaer): Anfragen merken und in den Listen markieren.
--   * Gemerkt wird jedes Fluestern an einen Spieler (auch aus dem normalen Chat, CHAT_MSG_WHISPER_INFORM) und
--     jede Einladung aus Warhorn. Gruppen zaehlen ueber ihren Anfuehrer.
--   * Markierung: kleines Sprechblasen-Symbol vor dem Namen, im Tooltip "Angefluestert vor ..." und
--     "Eingeladen vor ...".
--   * Je Charakter in PeonWarhornCharDB.contacts = { [name klein, ohne Realm] = { whisper = Zeit, invite = Zeit } }.
--     Wie lange, steht in PeonWarhornDB.contactKeep (Minuten, Einstellung "Anfragen merken").

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local C = {}
ns.Contacts = C

C.KEEP_CHOICES = { 30, 60, 120, 240, 1440 }
C.KEEP_DEFAULT = 120
C.ICON = "|TInterface\\GossipFrame\\GossipGossipIcon:12:12|t "

local function Secret(v) return Peon.IsSecret(v) end
local function Now() return time and time() or 0 end

function C.Key(name)
    if type(name) ~= "string" or Secret(name) or name == "" then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

-- Minuten, nur die Werte der Auswahl
function C.KeepMinutes()
    local m = mod.db and tonumber(mod.db.contactKeep)
    for _, v in ipairs(C.KEEP_CHOICES) do if v == m then return m end end
    return C.KEEP_DEFAULT
end

function C.SetKeep(min)
    if not mod.db then return end
    mod.db.contactKeep = min
    C.Prune()
    C.Changed()
end

function C.KeepText(min)
    if min < 60 then return L.KEEP_MIN:format(min) end
    if min == 60 then return L.KEEP_HOUR end
    if min >= 1440 then return L.KEEP_DAY end
    return L.KEEP_HOURS:format(math.floor(min / 60))
end

local function List()
    if not mod.db then return nil end
    if type(mod.db.contacts) ~= "table" then mod.db.contacts = {} end
    return mod.db.contacts
end

-- Alte Eintraege entfernen
function C.Prune()
    local list = List()
    if not list then return end
    local limit = Now() - C.KeepMinutes() * 60
    for k, e in pairs(list) do
        if type(e) ~= "table" then
            list[k] = nil
        else
            for _, f in ipairs({ "whisper", "invite" }) do
                if type(e[f]) ~= "number" or e[f] < limit then e[f] = nil end
            end
            if not (e.whisper or e.invite) then list[k] = nil end
        end
    end
end

-- Listen neu zeichnen, damit die Markierung gleich erscheint
function C.Changed()
    if ns.Window and ns.Window.frame and ns.Window.Update then mod:Call("Liste", ns.Window.Update) end
    if ns.Who and ns.Who.Update then mod:Call("Wer-Liste", ns.Who.Update) end
end

-- kind: "whisper" oder "invite"
function C.Record(name, kind)
    local k, list = C.Key(name), List()
    if not (k and list) or (kind ~= "whisper" and kind ~= "invite") then return end
    local e = type(list[k]) == "table" and list[k] or {}
    e[kind] = Now()
    list[k] = e
    C.Changed()
end

-- Eintrag, solange er gilt: { whisper = Zeit, invite = Zeit } (einzelne Felder koennen fehlen)
function C.Get(name)
    local k, list = C.Key(name), List()
    if not (k and list) then return nil end
    local e = list[k]
    if type(e) ~= "table" then return nil end
    local limit = Now() - C.KeepMinutes() * 60
    local w = type(e.whisper) == "number" and e.whisper >= limit and e.whisper or nil
    local i = type(e.invite) == "number" and e.invite >= limit and e.invite or nil
    if not (w or i) then return nil end
    return { whisper = w, invite = i }
end

-- Name mit Symbol davor, wenn angefragt
function C.Mark(name, text)
    if C.Get(name) then return C.ICON .. (text or "") end
    return text
end

-- Zeilen fuer den Tooltip
function C.AddTooltip(tip, name)
    local e = C.Get(name)
    if not (e and tip) then return end
    local now = Now()
    if e.whisper then tip:AddLine(C.ICON .. L.TIP_WHISPERED:format(ns.Window.AgeText(now - e.whisper)), 0.4, 0.9, 1) end
    if e.invite then tip:AddLine(C.ICON .. L.TIP_INVITED:format(ns.Window.AgeText(now - e.invite)), 0.4, 0.9, 1) end
end

-- Jedes Fluestern zaehlt, auch aus dem normalen Chat
mod:RegisterEvent("CHAT_MSG_WHISPER_INFORM", function(event, text, target)
    if Secret(target) then return end
    mod:Call("Anfragen", C.Record, target, "whisper")
end)

mod:On("INIT", function() mod:Call("Anfragen", C.Prune) end)
