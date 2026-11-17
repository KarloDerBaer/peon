-- Peon_Warhorn - Filter.lua
-- Filter fuer die Eintraege aus Search.lua, ohne Fenster (gut zu testen).
-- Gruppen: freier Platz fuer eine gewaehlte Rolle, Klassen "nur mit" oder "nur ohne", ohne meine Klasse,
--          Stufe (ein Mitglied im Bereich), hoechstens n Mitglieder.
-- Mitspieler: spielt eine gewaehlte Rolle, gewaehlte Klasse, Stufe im Bereich.
-- Eintraege mit geheimen Werten werden nie herausgefiltert (lieber zeigen als falsch verstecken).

local ADDON_NAME, ns = ...
local mod = ns.mod

local F = {}
ns.Filter = F

-- Klassen in Forever (Reihenfolge wie Blizzards CLASS_SORT_ORDER, soweit vorhanden)
F.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
F.ROLE_OF = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }

function F.MyClass()
    local _, c = UnitClass("player")
    return c
end

-- Rollen aus Blizzards Rollenwahl der Gruppensuche
function F.MyRoles()
    local r = {}
    if C_LFGListRoles and C_LFGListRoles.GetRoles then
        local ok, t = pcall(C_LFGListRoles.GetRoles)
        if ok and type(t) == "table" and not Peon.IsSecret(t) then
            r.tank, r.healer, r.dps = t.tank == true, t.healer == true, t.dps == true
        end
    end
    return r
end

local function Fresh(t)
    t.roles = type(t.roles) == "table" and t.roles or {}
    t.classes = type(t.classes) == "table" and t.classes or {}
    if t.mode ~= "with" and t.mode ~= "without" then t.mode = "with" end
    t.noMyClass = t.noMyClass == true
    t.levelMin = tonumber(t.levelMin) or 0
    t.levelMax = tonumber(t.levelMax) or 0
    t.sizeMax = tonumber(t.sizeMax) or 0
    return t
end

-- Standardwerte je Charakter: Gruppen mit freiem Platz fuer meine Rollen, Mitspieler ohne Filter
function F.InitDefaults()
    local db = mod.db
    if not db then return end
    local g = Fresh(type(db.gFilter) == "table" and db.gFilter or {})
    if not g.init then
        g.roles = F.MyRoles()
        g.init = true
    end
    db.gFilter = g
    local p = Fresh(type(db.pFilter) == "table" and db.pFilter or {})
    p.init = true
    db.pFilter = p
end

function F.Reset(kind)
    local db = mod.db
    if kind == "groups" then db.gFilter = {} else db.pFilter = {} end
    F.InitDefaults()
end

local function AnyRole(roles)
    return roles and (roles.tank or roles.healer or roles.dps) and true or false
end
local function AnyClass(classes)
    for _, on in pairs(classes or {}) do if on then return true end end
    return false
end

function F.Group(e, f, myClass)
    if e.isSolo then return false end
    if e.secret then return true end
    if AnyRole(f.roles) then
        local fit = false
        for key, role in pairs(F.ROLE_OF) do
            if f.roles[key] and (e.free[role] or 0) > 0 then fit = true end
        end
        if not fit then return false end
    end
    if AnyClass(f.classes) then
        local has = false
        for c, on in pairs(f.classes) do if on and (e.classes[c] or 0) > 0 then has = true end end
        if f.mode == "without" then
            if has then return false end
        elseif not has then
            return false
        end
    end
    if f.noMyClass and myClass and (e.classes[myClass] or 0) > 0 then return false end
    if f.levelMin > 0 and e.levelMax and e.levelMax < f.levelMin then return false end
    if f.levelMax > 0 and e.levelMin and e.levelMin > f.levelMax then return false end
    if f.sizeMax > 0 and e.numMembers > f.sizeMax then return false end
    return true
end

function F.Player(e, f)
    if not e.isSolo then return false end
    if e.secret then return true end
    if AnyRole(f.roles) then
        local fit = false
        local pr = e.playerRoles or {}
        for key in pairs(F.ROLE_OF) do if f.roles[key] and pr[key] then fit = true end end
        if not fit then return false end
    end
    if AnyClass(f.classes) and not (e.leaderClass and f.classes[e.leaderClass]) then return false end
    local lvl = e.leaderLevel
    if lvl then
        if f.levelMin > 0 and lvl < f.levelMin then return false end
        if f.levelMax > 0 and lvl > f.levelMax then return false end
    end
    return true
end

-- Liste fuer einen Reiter: Treffer und Anzahl aller Eintraege dieser Art
function F.Apply(list, kind)
    local db = mod.db
    local f = Fresh(kind == "groups" and db.gFilter or db.pFilter)
    local myClass = F.MyClass()
    local out, total = {}, 0
    for _, e in ipairs(list or {}) do
        local isKind = (kind == "groups") ~= (e.isSolo == true)
        if isKind or e.secret then total = total + 1 end
        local pass
        if kind == "groups" then pass = F.Group(e, f, myClass) else pass = F.Player(e, f) end
        if pass then out[#out + 1] = e end
    end
    return out, total
end

-- Freie Plaetze fuer die gewaehlten Rollen (Sortierung der Spalte Rollen)
function F.FreeFor(e, roles)
    local n = 0
    for key, role in pairs(F.ROLE_OF) do
        if not AnyRole(roles) or roles[key] then n = n + (e.free[role] or 0) end
    end
    return n
end

F.AnyRole, F.AnyClass = AnyRole, AnyClass
