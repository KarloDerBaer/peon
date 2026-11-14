-- Peon_Profession - Guide.lua
-- Rechnen ohne Fenster: Schritt der Route zur Stufe, Anzahl, Rezept des Schritts, Ersatzrezept, Plan bis zum Hoechstwert.
-- Grundlage: ns.Routes (Routes.lua) und die im Berufsfenster gelesenen Rezepte (mod.db.known, Measure.lua).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local G = {}
ns.Guide = G

G.RANK_MAX = { 75, 150, 225, 300 }

function G.Route(key) return ns.Routes and ns.Routes[key] end

-- Schritt fuer die Stufe: der erste mit from <= skill < to. Unter dem ersten: der erste. Ueber dem letzten: nil.
function G.StepAt(key, skill)
    local r = G.Route(key)
    if type(r) ~= "table" or not r[1] then return nil end
    skill = tonumber(skill) or 0
    if skill < r[1].from then return r[1], 1 end
    for i, s in ipairs(r) do
        if skill >= s.from and skill < s.to then return s, i end
    end
    return nil
end

-- Geschaetzte Herstellungen von der Stufe bis zum Ende des Schritts (Anteil von n, aufgerundet)
function G.Remaining(step, skill)
    if type(step) ~= "table" or not step.n then return nil end
    local span = step.to - step.from
    if span <= 0 then return step.n end
    local from = math.max(step.from, tonumber(skill) or step.from)
    local left = math.max(0, step.to - from)
    return math.max(left > 0 and 1 or 0, math.ceil(step.n * left / span - 0.0001))
end

-- Erlernte Rezepte des Berufs (aus dem Berufsfenster, je Charakter)
function G.Known(key)
    local k = mod.db.known
    return type(k) == "table" and type(k[key]) == "table" and k[key] or {}
end

-- Rezept des Schritts unter den erlernten: ueber die Zauber-ID oder den Ergebnis-Gegenstand. Rueckgabe: recipeID, Eintrag
function G.KnownFor(key, step)
    if type(step) ~= "table" then return nil end
    local known = G.Known(key)
    if step.spell and known[step.spell] then return step.spell, known[step.spell] end
    if step.item then
        for id, rec in pairs(known) do
            if rec.out == step.item then return id, rec end
        end
    end
    return nil
end

-- Material je Herstellung als Liste { { id, q } }: aus dem Berufsfenster, sonst aus der Route
function G.MatsOf(rec, step)
    local m = (type(rec) == "table" and type(rec.m) == "table" and rec.m) or (type(step) == "table" and step.mats)
    local out = {}
    if type(m) ~= "table" then return out end
    for i = 1, #m - 1, 2 do
        if type(m[i]) == "number" and type(m[i + 1]) == "number" then out[#out + 1] = { id = m[i], q = m[i + 1] } end
    end
    return out
end

-- Name und Symbol eines Rezepts (Gegenstand bevorzugt, sonst Zauber)
function G.RecipeName(item, spell, rec)
    local name, q
    if item then name, q = ns.ItemName(item) end
    if not name and spell then name = ns.SpellName(spell) end
    if not name and type(rec) == "table" then name = rec.name end
    return name or ("#" .. tostring(item or spell or "?")), q
end

function G.RecipeIcon(item, spell)
    if item then return ns.ItemIcon(item) end
    if spell then return ns.SpellIcon(spell) end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Kosten einer Herstellung nach Kaufpreis (nil, wenn ein Preis fehlt)
function G.CraftCost(mats)
    local sum = 0
    for _, m in ipairs(mats) do
        local p = ns.Prices.Unit(m.id)
        if not p then return nil end
        sum = sum + p * m.q
    end
    return sum
end

-- Ersatzrezept: unter den erlernten das orange mit den geringsten Kosten je Herstellung, sonst das gelbe.
-- Ohne Preise zaehlt die Menge an Material. Rueckgabe: recipeID, Eintrag oder nil.
function G.Alternative(key, except)
    local best, bestRec, bestScore, bestColor
    for id, rec in pairs(G.Known(key)) do
        local c = rec.c
        if id ~= except and (c == 0 or c == 1) then
            local mats = G.MatsOf(rec)
            local cost = G.CraftCost(mats)
            local score
            if cost then score = cost / math.max(1, rec.n or 1) else
                score = 1e9
                for _, m in ipairs(mats) do score = score + m.q end
            end
            if not best or c < bestColor or (c == bestColor and score < bestScore)
                or (c == bestColor and score == bestScore and id < best) then
                best, bestRec, bestScore, bestColor = id, rec, score, c
            end
        end
    end
    return best, bestRec
end

-- Naechster Rang beim Lehrer, wenn der Hoechstwert fast erreicht ist. Rueckgabe: Text oder nil
function G.TrainerHint(key, skill, max)
    if max == 0 then return L.LEARN_FIRST:format(L.RANKS[0]) end
    if not max or max >= 300 or not L.RANKS[max] then return nil end
    if skill < max - 25 then return nil end
    local p = ns.PROFS[key]
    if p and p.book and max == p.book then return L.TRAINER_BOOK:format(L.RANKS[max]) end
    return L.TRAINER:format(L.RANKS[max], L.RANK_LEVEL[max] or 0)
end

-- Ansicht eines Schritts fuer Fenster und Leiste:
-- { step, index, from, to, count, gather, item, spell, recipeID, rec, color, mats = { { id, q } },
--   alt = { id, rec, name, color }, learned, learn = { skill, src } }
function G.View(key, step, skill, index)
    if type(step) ~= "table" then return nil end
    local v = { step = step, index = index, from = math.max(step.from, skill or step.from), to = step.to }
    v.count = G.Remaining(step, skill)
    if step.gather or not ns.PROFS[key] or ns.PROFS[key].gather then
        v.gather = step.gather or {}
        v.zones = step
        return v
    end
    v.item, v.spell = step.item, step.spell
    v.recipeID, v.rec = G.KnownFor(key, step)
    v.learned = v.recipeID ~= nil
    v.color = v.rec and v.rec.c
    v.mats = G.MatsOf(v.rec, step)
    v.learn = step.spell and ns.Learn and ns.Learn[step.spell]
    v.name = (step.item or step.spell) and G.RecipeName(step.item, step.spell, v.rec) or nil
    -- Rezept zu leicht (gruen, grau) oder Schritt ohne festes Rezept: Ersatz vorschlagen
    if (v.color and v.color >= 2) or not (step.item or step.spell) then
        local id, rec = G.Alternative(key, v.recipeID)
        if id then
            v.alt = { id = id, rec = rec, color = rec.c, name = G.RecipeName(rec.out, id, rec), item = rec.out }
            v.altMats = G.MatsOf(rec)
        end
    end
    return v
end

-- Was jetzt hergestellt wird (Ersatz, falls vorhanden): Material, Rezept-ID, Ergebnis
function G.Active(v)
    if not v then return nil end
    if v.alt then return v.altMats, v.alt.id, v.alt.item end
    return v.mats, v.recipeID or v.spell, v.item
end

-- Plan von der Stufe bis zum Ziel: { { from, to, count, step, index, item, spell, gather } }. Ab 0.2.0 mit Ziel ueber
-- den Hoechstwert hinaus: An jeder Ranggrenze (75, 150, 225), die noch gelernt werden muss, steht eine Lehrerzeile
-- { trainer = true, from, rank }, Schritte ueber die Grenze werden dort geteilt. Nicht gelernt (max 0): zuerst Lehrling.
-- target = nil: bis zum Hoechstwert (Verhalten bis 0.1.0, danach eine Lehrerzeile).
function G.Plan(key, skill, max, target)
    local out = {}
    local r = G.Route(key)
    if type(r) ~= "table" then return out end
    skill, max = tonumber(skill) or 0, tonumber(max) or 300
    local untilT = math.min(300, tonumber(target) or max)
    -- Grenzen, an denen ein Rang fehlt
    local need = {}
    for _, b in ipairs({ 75, 150, 225 }) do
        if b >= max and b >= skill and b < untilT then need[#need + 1] = b end
    end
    if max <= 0 then out[#out + 1] = { trainer = true, from = 0, to = 0, rank = L.RANKS[0] } end
    local pending = 1
    local function Trainer(upTo)
        while need[pending] and need[pending] <= upTo do
            local b = need[pending]
            out[#out + 1] = { trainer = true, from = b, to = b, rank = L.RANKS[b] }
            pending = pending + 1
        end
    end
    for i, s in ipairs(r) do
        if s.to > skill and s.from < untilT then
            local from, to = math.max(s.from, skill), math.min(s.to, untilT)
            -- an fehlenden Raengen teilen
            local cuts = { from }
            for _, b in ipairs(need) do if b > from and b < to then cuts[#cuts + 1] = b end end
            cuts[#cuts + 1] = to
            for c = 1, #cuts - 1 do
                local a, z = cuts[c], cuts[c + 1]
                Trainer(a)
                local e = { from = a, to = z, step = s, index = i, item = s.item, spell = s.spell, gather = s.gather }
                if s.n then
                    local span = math.max(1, s.to - s.from)
                    e.count = math.max(1, math.ceil(s.n * (z - a) / span - 0.0001))
                end
                out[#out + 1] = e
            end
        end
    end
    Trainer(untilT)
    if target == nil and max < 300 and L.RANKS[max] and max > 0 then
        out[#out + 1] = { trainer = true, from = max, to = max, rank = L.RANKS[max] }
    end
    return out
end

-- Zielstufe eines Berufs: gespeichert, sonst der Hoechstwert (ist er erreicht: der naechste Rang), nicht gelernt 75
function G.Target(key, skill, max)
    local t = type(mod.db.target) == "table" and tonumber(mod.db.target[key])
    skill, max = tonumber(skill) or 0, tonumber(max) or 0
    if t and t > skill then return math.min(300, t) end
    if max <= 0 then return 75 end
    if max > skill then return max end
    return math.min(300, max + 75)
end

function G.SetTarget(key, value)
    value = math.floor(tonumber(value) or 0)
    if value < 1 then value = nil else value = math.min(300, value) end
    if type(mod.db.target) ~= "table" then mod.db.target = {} end
    mod.db.target[key] = value
    return value
end

-- Bedarf an Material fuer eine Reihe von Schritten (Plan-Zeilen) zusammenzaehlen: { [itemID] = Stueck }
function G.Need(key, rows)
    local need = {}
    for _, e in ipairs(rows) do
        if e.step and e.count and not e.trainer then
            local _, rec = G.KnownFor(key, e.step)
            for _, m in ipairs(G.MatsOf(rec, e.step)) do
                need[m.id] = (need[m.id] or 0) + m.q * e.count
            end
        end
    end
    return need
end
