-- Peon_Broker - Shop.lua
-- Abgleich der Einkaufslisten mit dem Peon Manager. Beide Seiten koennen aendern, je Eintrag gewinnt die neuere Aenderung.
-- Aufbau: lists = { { id, name, pct, u, items = { [Schluessel] = { wish, max, name, q, icon, u } } } },
--         gone = { lists = { [id] = Zeit }, items = { ["id|Schluessel"] = Zeit } } (Loeschmarken).
-- Bei gleicher Zeit bleibt der eigene Stand. Die Regeln muessen gleich bleiben wie in manager/src/core/shopping.js.

local ADDON_NAME, ns = ...

local S = {}
ns.Shop = S

S.GONE_DAYS = 60   -- so lange bleiben Loeschmarken stehen

local function Num(v) return tonumber(v) or 0 end

function S.Find(lists, id)
    for i, l in ipairs(lists) do
        if l.id == id then return l, i end
    end
    return nil
end

-- Schluessel aus einer Loeschmarke: Zahl wie in den Listen, sonst Text
local function KeyOf(text)
    return tonumber(text) or text
end

local function Copy(it, u)
    local c = {}
    for k, v in pairs(it) do c[k] = v end
    c.u = u
    return c
end

-- inc = { lists, gone } einmischen. Rueckgabe: true, wenn sich etwas geaendert hat
function S.Merge(lists, gone, inc)
    if type(inc) ~= "table" then return false end
    local changed = false
    for _, il in ipairs(type(inc.lists) == "table" and inc.lists or {}) do
        if type(il) == "table" and type(il.id) == "string" then
            local iu = Num(il.u)
            local goneL = Num(gone.lists[il.id])
            local l = S.Find(lists, il.id)
            local skip = false
            if not l then
                if goneL >= iu then
                    skip = true
                else
                    l = { id = il.id, name = il.name, pct = il.pct, u = iu, items = {} }
                    lists[#lists + 1] = l
                    gone.lists[il.id] = nil
                    changed = true
                end
            elseif iu > Num(l.u) then
                l.name, l.pct, l.u = il.name, il.pct, iu
                changed = true
            end
            if not skip then
                for key, it in pairs(type(il.items) == "table" and il.items or {}) do
                    local u = type(it) == "table" and Num(it.u) or 0
                    local gk = il.id .. "|" .. tostring(key)
                    local cur = l.items[key]
                    local newer
                    if cur then newer = u > Num(cur.u) else newer = u > Num(gone.items[gk]) end
                    if newer and type(it) == "table" then
                        l.items[key] = Copy(it, u)
                        gone.items[gk] = nil
                        changed = true
                    end
                end
            end
        end
    end
    local g = type(inc.gone) == "table" and inc.gone or {}
    for id, t in pairs(type(g.lists) == "table" and g.lists or {}) do
        local when = Num(t)
        local l, at = S.Find(lists, id)
        if l and when >= Num(l.u) then
            table.remove(lists, at)
            l = nil
            changed = true
        end
        if not l and when > Num(gone.lists[id]) then
            gone.lists[id] = when
            changed = true
        end
    end
    for gk, t in pairs(type(g.items) == "table" and g.items or {}) do
        local when = Num(t)
        local id, text = tostring(gk):match("^(.-)|(.*)$")
        if id then
            local key = KeyOf(text)
            local l = S.Find(lists, id)
            local cur = l and l.items[key]
            if cur and when >= Num(cur.u) then
                l.items[key] = nil
                cur = nil
                changed = true
            end
            if not cur and when > Num(gone.items[gk]) then
                gone.items[gk] = when
                changed = true
            end
        end
    end
    return changed
end

-- Alte Loeschmarken entfernen
function S.Purge(gone, now)
    local limit = now - S.GONE_DAYS * 86400
    for _, part in ipairs({ gone.lists, gone.items }) do
        for k, t in pairs(part) do
            if Num(t) < limit then part[k] = nil end
        end
    end
end

-- Zeit fuer eine Aenderung: immer spaeter als die letzte, auch innerhalb einer Sekunde
function S.NextU(now, ...)
    local u = now
    for i = 1, select("#", ...) do
        local old = select(i, ...)
        if old and Num(old) + 1 > u then u = Num(old) + 1 end
    end
    return u
end
