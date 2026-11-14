-- Peon_Profession - Books.lua
-- Ab 0.3.0 (Wunsch KarloDerBaer 14.11.2026): Bei Erster Hilfe, Kochkunst und Angeln gibt es den Rang Experte als Buch
-- beim Haendler statt beim Lehrer. Der Guide nennt Buch, Preis und Haendler der eigenen Fraktion und setzt auf Klick
-- einen Wegpunkt auf der Karte (Blizzards Kartenmarkierung, C_Map.SetUserWaypoint).
--
-- Haendlerdaten: aus "Profession Leveling Guide" 2.7.2 von icêheal (MIT-Lizenz, Text in Routes.lua),
-- Daten_Forever_Haendler.lua, dort im Spiel auf dem Forever-Client gesammelt (Stand 23.10.2026).
-- Namen der Gebiete liefert das Spiel (C_Map), Namen der Buecher ebenfalls (C_Item).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local K = {}
ns.Books = K

-- [Beruf] = { rank = Hoechstwert, ab dem das Buch den naechsten Rang bringt, item, skill (noetige Stufe), price (Kupfer),
--             vendors = { { npc, name, map (uiMapID), x, y, faction (nil = beide) } } }
K.DATA = {
    [129] = { rank = 150, item = 16084, skill = 125, price = 9000, vendors = {     -- Erste Hilfe fuer Experten
        { npc = 2805, name = "Deneb Walker", map = 1417, x = 27.1, y = 58.8, faction = "Alliance" },
        { npc = 13476, name = "Balai Lok'Wein", map = 1445, x = 36.5, y = 30.5, faction = "Horde" },
    } },
    [185] = { rank = 150, item = 16072, skill = 125, price = 10000, vendors = {    -- Expertenkochbuch
        { npc = 3955, name = "Shandrina", map = 1440, x = 49.5, y = 67.1, faction = "Alliance" },
        { npc = 12033, name = "Wulan", map = 1443, x = 26.2, y = 69.8, faction = "Horde" },
    } },
    [356] = { rank = 150, item = 16083, skill = 125, price = 10000, vendors = {    -- Expertenangeln
        { npc = 2626, name = "Old Man Heming", map = 1434, x = 27.4, y = 77.2 },
    } },
}

local function Faction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return type(f) == "string" and f or nil
end

-- Buch fuer den naechsten Rang (max = aktueller Hoechstwert), nil wenn es keins gibt
function K.For(key, max)
    local b = K.DATA[key]
    if not b or (max and max ~= b.rank) then return nil end
    return b
end

-- Haendler der eigenen Fraktion (neutrale zaehlen fuer beide), der erste passende
function K.Vendor(b)
    if type(b) ~= "table" then return nil end
    local f = Faction()
    for _, v in ipairs(b.vendors) do
        if not v.faction or v.faction == f then return v end
    end
    return b.vendors[1]
end

function K.ZoneName(map)
    local CM = rawget(_G, "C_Map")
    if CM and CM.GetMapInfo then
        local ok, info = pcall(CM.GetMapInfo, map)
        if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
    end
    return "#" .. tostring(map)
end

-- "Deneb Walker, Arathihochland (27.1, 58.8)"
function K.Place(v)
    return ("%s, %s (%.1f, %.1f)"):format(v.name, K.ZoneName(v.map), v.x, v.y)
end

-- Hinweis fuer den Guide: Buch, Preis, Haendler. nil ohne Buch
function K.Hint(key, max)
    local b = K.For(key, max)
    local v = K.Vendor(b)
    if not v then return nil end
    local name = ns.ItemName(b.item) or ("#" .. b.item)
    return L.BOOK_HINT:format(L.RANKS[b.rank] or "", name, ns.Money(b.price), K.Place(v), b.skill)
end

-- Wegpunkt auf der Karte setzen (wie ein Klick des Spielers auf die Karte, kein geschuetzter Aufruf)
function K.Waypoint(v)
    if type(v) ~= "table" then return false end
    local CM, P = rawget(_G, "C_Map"), rawget(_G, "UiMapPoint")
    if not (CM and CM.SetUserWaypoint and P and P.CreateFromCoordinates) then mod:Print(L.WAYPOINT_NONE); return false end
    if CM.CanSetUserWaypointOnMap then
        local ok, can = pcall(CM.CanSetUserWaypointOnMap, v.map)
        if not ok or not can then mod:Print(L.WAYPOINT_NONE); return false end
    end
    local ok = pcall(function()
        CM.SetUserWaypoint(P.CreateFromCoordinates(v.map, v.x / 100, v.y / 100))
        local ST = rawget(_G, "C_SuperTrack")
        if ST and ST.SetSuperTrackedUserWaypoint then ST.SetSuperTrackedUserWaypoint(true) end
    end)
    if ok then mod:Print(L.WAYPOINT_SET:format(K.Place(v))) else mod:Print(L.WAYPOINT_NONE) end
    return ok
end

-- Wegpunkt zum Buchhaendler des Berufs
function K.Mark(key, max)
    return K.Waypoint(K.Vendor(K.For(key, max)))
end
