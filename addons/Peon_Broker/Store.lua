-- Peon_Broker - Store.lua
-- Speicherform der Preisdaten in der Datei (ab 0.130.0, mit KarloDerBaer abgestimmt 20.11.2026)
--
-- WoW Forever laedt eine SavedVariables-Datei mit mehr als etwa 262.000 verschiedenen Werten nicht ("constant table
-- overflow"), Broker startet dann leer und ueberschreibt die Datei. Jeder Text zaehlt als eigener Wert, egal wie lang.
-- Fast alle Werte waren Texte der Gegenstaende (Schluessel, Name, Link, Tageswerte, Absatz). Darum:
--   * Beim Abmelden und vor /reload (PLAYER_LOGOUT) kommen alle Texte eines Gegenstands in einen einzigen Text e.x,
--     beim Laden (Migration, vor allem anderen) werden sie wieder getrennt. Im Spiel aendert sich nichts.
--     e.x = "Feld=Wert\nFeld=Wert..."; ein Wert beginnt mit "s" (Text) oder "t" (Tabelle einer Ebene, Eintraege durch
--     Tab getrennt, je "Name=" und "n"/"s"/"b" mit Wert). Zahlen und Ja/Nein bleiben eigene Felder (sie wiederholen sich).
--   * Varianten ("itemID:voller Name") speichern keinen Namen, er steht im Schluessel.
--   * Varianten ohne Angebot seit S.VARIANT_DAYS Tagen fallen weg (Langzeitwerte liefert der Peon Manager).
--   * Beim Packen schaetzt Broker die Zahl der Werte (acc.svEst) und merkt sich je Charakter die Zahl der Gegenstaende
--     (char.svItems). Beim Laden warnt er bei vielen Werten oder wenn die Daten fehlen.
-- Der Peon Manager liest e.x ebenso (manager/src/core/broker.js).

local ADDON_NAME, ns = ...
local mod = ns.mod
local L = ns.L

local S = {}
ns.Store = S

S.VARIANT_DAYS = 7         -- Varianten ohne Angebot so lange behalten
S.WARN         = 180000    -- ab so vielen geschaetzten Werten warnen (Grenze des Spiels etwa 262.000)
S.LOST_ITEMS   = 1000      -- fehlen die Daten, obwohl beim letzten Abmelden so viele Gegenstaende da waren: Hinweis
S.REST         = 3000      -- grob geschaetzte Werte ausserhalb der Gegenstaende

local function IsVariant(key)
    return ns.Data.IsVariantKey(key)
end

local function NumText(x)
    if x == math.floor(x) and math.abs(x) < 1e15 then return ("%.0f"):format(x) end
    return ("%.17g"):format(x)
end

local function Clean(s) return not s:find("[\n\t]") end

-- Tabelle einer Ebene als Text, nil wenn das nicht verlustfrei geht
local function PackTable(t)
    local parts = {}
    for k, v in pairs(t) do
        if type(k) ~= "string" or not k:match("^[%a_][%w_]*$") then return nil end
        local tv = type(v)
        if tv == "number" then parts[#parts + 1] = k .. "=n" .. NumText(v)
        elseif tv == "string" and Clean(v) then parts[#parts + 1] = k .. "=s" .. v
        elseif tv == "boolean" then parts[#parts + 1] = k .. "=b" .. (v and "1" or "0")
        else return nil end
    end
    table.sort(parts)
    return table.concat(parts, "\t")
end

local function UnpackTable(s)
    local t = {}
    for part in s:gmatch("[^\t]+") do
        local k, c, v = part:match("^([%a_][%w_]*)=(.)(.*)$")
        if k then
            if c == "n" then t[k] = tonumber(v)
            elseif c == "b" then t[k] = v == "1"
            else t[k] = v end
        end
    end
    return t
end

-- Einen Gegenstand packen (in place). Rueckgabe: true, wenn e.x entstanden ist
function S.PackItem(key, e)
    if type(e) ~= "table" or e.x ~= nil then return false end
    if IsVariant(key) then e.nm = nil end
    local names = {}
    for f, v in pairs(e) do
        if type(f) == "string" and f:match("^[%a_][%w_]*$") then
            if (type(v) == "string" and Clean(v)) or type(v) == "table" then names[#names + 1] = f end
        end
    end
    if #names == 0 then return false end
    table.sort(names)
    local parts = {}
    for _, f in ipairs(names) do
        local v = e[f]
        if type(v) == "string" then
            parts[#parts + 1] = f .. "=s" .. v
            e[f] = nil
        else
            local pt = PackTable(v)
            if pt then parts[#parts + 1] = f .. "=t" .. pt; e[f] = nil end
        end
    end
    if #parts == 0 then return false end
    e.x = table.concat(parts, "\n")
    return true
end

-- Einen Gegenstand entpacken (in place); Varianten bekommen den Namen aus dem Schluessel
function S.UnpackItem(key, e)
    if type(e) ~= "table" then return end
    local x = e.x
    if type(x) == "string" then
        e.x = nil
        for line in x:gmatch("[^\n]+") do
            local f, c, v = line:match("^([%a_][%w_]*)=(.)(.*)$")
            if f and e[f] == nil then
                if c == "t" then e[f] = UnpackTable(v) else e[f] = v end
            end
        end
    end
    if e.nm == nil and IsVariant(key) then e.nm = tostring(key):match("^%d+:(.+)$") end
end

function S.UnpackAll(acc)
    if type(acc) ~= "table" or type(acc.markets) ~= "table" then return 0 end
    local n = 0
    for _, m in pairs(acc.markets) do
        if type(m) == "table" and type(m.items) == "table" then
            for key, e in pairs(m.items) do S.UnpackItem(key, e); n = n + 1 end
        end
    end
    return n
end

-- Variante ohne Angebot seit VARIANT_DAYS Tagen?
function S.Stale(key, e, now)
    if not IsVariant(key) or type(e) ~= "table" or (tonumber(e.q) or 0) > 0 then return false end
    local last = ns.Data.Seen(e) or e.gone
    return type(last) == "number" and now - last >= S.VARIANT_DAYS * 86400
end

-- Alles packen. Rueckgabe: Zahl der Gegenstaende, geschaetzte Zahl der Werte, entfernte Varianten
function S.PackAll(acc, now)
    if type(acc) ~= "table" or type(acc.markets) ~= "table" then return 0, 0, 0 end
    now = now or time()
    local items, est, dropped, nums = 0, S.REST, 0, {}
    for _, m in pairs(acc.markets) do
        if type(m) == "table" and type(m.items) == "table" then
            local drop = {}
            for key, e in pairs(m.items) do
                if S.Stale(key, e, now) then drop[#drop + 1] = key end
            end
            for _, key in ipairs(drop) do m.items[key] = nil end
            dropped = dropped + #drop
            for key, e in pairs(m.items) do
                if type(e) == "table" then
                    S.PackItem(key, e)
                    items = items + 1
                    if type(key) == "string" then est = est + 1
                    elseif type(key) == "number" and not nums[key] then nums[key] = true; est = est + 1 end
                    if e.x then est = est + 1 end
                    for _, v in pairs(e) do
                        if type(v) == "number" and not nums[v] then nums[v] = true; est = est + 1 end
                    end
                end
            end
        end
    end
    ns.Data.vIndex = nil
    acc.svEst = est
    return items, est, dropped
end

-- Zahl der Gegenstaende in allen Maerkten
function S.CountItems(acc)
    local n = 0
    if type(acc) ~= "table" or type(acc.markets) ~= "table" then return 0 end
    for _, m in pairs(acc.markets) do
        if type(m) == "table" and type(m.items) == "table" then for _ in pairs(m.items) do n = n + 1 end end
    end
    return n
end

-- Beim Laden (INIT): warnen bei vielen Werten und wenn die Daten fehlen
function S.Check()
    local acc, char = mod.acc, mod.char
    if type(acc) ~= "table" then return end
    if type(acc.svEst) == "number" and acc.svEst >= S.WARN then
        mod:Print(L.MSG_SV_BIG:format(Peon.ShortNumber and Peon.ShortNumber(acc.svEst) or tostring(acc.svEst)))
    end
    if type(char) == "table" and (tonumber(char.svItems) or 0) >= S.LOST_ITEMS and S.CountItems(acc) == 0 then
        mod:Print(L.MSG_SV_LOST:format(char.svItems))
    end
end

function S.OnLogout()
    local items = S.PackAll(mod.acc)
    if type(mod.char) == "table" then mod.char.svItems = items end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function()
    if mod.initialized then mod:Call("Speichern", S.OnLogout) end
end)
