-- Peon_Feedback - Feedback.lua
-- Anmeldung beim Kern, Datenhaltung (PeonFeedbackDB, accountweit), Befehle.
-- Zusatz zum Peon Manager: Einträge wandern beim Einlesen in den Manager, dort werden sie bearbeitet und gesendet.
-- Der Manager nennt in Data.lua (Peon_Bridge) den Zeitpunkt, bis zu dem er alles hat, das Addon löscht beim Laden bis dahin.
-- Braucht Peon API 7 (Liste, Minimap-Button). Bereiche je Modul ab API 9, sonst nur „Sonstiges“.

local ADDON_NAME, ns = ...
local L = ns.L

if (Peon.API or 0) < 7 then
    print("|cff8ccf4dPeon|r " .. L.TOO_OLD)
    return
end

ns.KINDS = { { "bug", L.KIND_BUG }, { "improve", L.KIND_IMPROVE }, { "idea", L.KIND_IDEA }, { "other", L.KIND_OTHER } }
ns.PRIOS = { { "low", L.PRIO_LOW }, { "mid", L.PRIO_MID }, { "high", L.PRIO_HIGH } }
ns.KIND_COLOR = { bug = "ff6060", improve = "66bbff", idea = "8ccf4d", other = "c0c0c0" }
ns.PRIO_COLOR = { low = "a0a0a0", mid = "ffd100", high = "ff5030" }

local KIND_SET, PRIO_SET = {}, {}
for _, k in ipairs(ns.KINDS) do KIND_SET[k[1]] = true end
for _, p in ipairs(ns.PRIOS) do PRIO_SET[p[1]] = true end

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "feedback",
    title    = L.TITLE,
    db       = "PeonFeedbackDB",
    defaults = {
        minimapShow  = true,
        minimapAngle = 200,
        entries      = {},       -- Liste der Rückmeldungen (siehe ns.Add)
        nextId       = 1,
        last         = {},       -- zuletzt gewählte Auswahl: module, kind, area, prio
        windowPos    = {},       -- point, x, y
    },
    ranges   = { minimapAngle = { 0, 359, 1 } },
    keepOnReset = { entries = true, nextId = true, last = true, windowPos = true },
    slash   = { "/feedback" },
    onSlash = function(m, cmd, rest)
        cmd = (cmd or ""):lower()
        if cmd == "optionen" or cmd == "options" then
            m:OpenOptions()
        else
            ns.Toggle()
        end
    end,
})
ns.mod = mod

-- ===== Hilfen =====

local function Label(list, value)
    for _, it in ipairs(list) do if it[1] == value then return it[2] end end
    return value or ""
end
ns.Label = Label

local function StripTitle(title)
    title = (title or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    title = title:gsub("^%s*Peon%s+", "")
    return title
end

-- Alle geladenen Peon-Addons: { { addon, Titel }, ... }, Kern zuerst
function ns.Modules()
    local out = {}
    local num = C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if type(name) == "string" and (name == "Peon" or name:match("^Peon_"))
           and (not C_AddOns.IsAddOnLoaded or C_AddOns.IsAddOnLoaded(name)) then
            local title
            if name == "Peon" then
                title = L.CORE
            else
                title = StripTitle(C_AddOns.GetAddOnMetadata(name, "Title"))
                if title == "" then title = name:gsub("^Peon_", "") end
            end
            out[#out + 1] = { name, title }
        end
    end
    table.sort(out, function(a, b)
        if a[1] == "Peon" then return b[1] ~= "Peon" end
        if b[1] == "Peon" then return false end
        return a[2]:lower() < b[2]:lower()
    end)
    return out
end

function ns.ModuleTitle(addon)
    for _, m in ipairs(ns.Modules()) do if m[1] == addon then return m[2] end end
    return (addon or ""):gsub("^Peon_", "")
end

-- Bereiche eines Moduls (API 9), immer mit „Sonstiges“ am Ende
function ns.Areas(addon)
    local out = {}
    if Peon.GetFeedbackAreas and addon then
        for _, a in ipairs(Peon.GetFeedbackAreas(addon)) do
            if a ~= L.OTHER then out[#out + 1] = { a, a } end
        end
    end
    out[#out + 1] = { L.OTHER, L.OTHER }
    return out
end

local function CharName()
    local first, second = UnitName("player")
    if type(second) == "string" and second ~= "" then return first .. " " .. second end
    return first or "?"
end

local function Market()
    local realm = GetRealmName and GetRealmName() or "?"
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    return realm .. " / " .. tostring(faction)
end

-- ===== Daten =====

-- e = { module, kind, area, prio, text } -> gespeicherter Eintrag oder nil, Fehlertext
function ns.Add(e)
    local db = mod.db
    if not db then return nil, "no db" end
    local text = strtrim(e.text or "")
    if text == "" then return nil, L.EMPTY_TEXT end
    local entry = {
        id     = db.nextId,
        t      = time(),
        module = e.module or "Peon",
        kind   = KIND_SET[e.kind] and e.kind or "other",
        area   = (e.area and e.area ~= "") and e.area or L.OTHER,
        prio   = PRIO_SET[e.prio] and e.prio or "mid",
        text   = text,
        char   = CharName(),
        market = Market(),
        zone   = GetRealZoneText and GetRealZoneText() or nil,
        ver    = C_AddOns.GetAddOnMetadata(e.module or "Peon", "Version"),
    }
    db.nextId = db.nextId + 1
    table.insert(db.entries, entry)
    mod:Dbg(("Add #%d %s/%s/%s/%s"):format(entry.id, entry.module, entry.kind, entry.area, entry.prio))
    return entry
end

function ns.Delete(id)
    local db = mod.db
    if not db then return false end
    for i, e in ipairs(db.entries) do
        if e.id == id then
            table.remove(db.entries, i)
            mod:Dbg("Delete #" .. id)
            return true
        end
    end
    return false
end

-- Eintrag bearbeiten (ab 0.2.0): f = { module, kind, area, prio, text } -> Eintrag oder nil, Fehlertext
function ns.Update(id, f)
    local db = mod.db
    if not db then return nil, "no db" end
    local text = strtrim(f.text or "")
    if text == "" then return nil, L.EMPTY_TEXT end
    for _, e in ipairs(db.entries) do
        if e.id == id then
            if f.module and f.module ~= e.module then
                e.module = f.module
                e.ver = C_AddOns.GetAddOnMetadata(f.module, "Version") or e.ver
            end
            if KIND_SET[f.kind] then e.kind = f.kind end
            if PRIO_SET[f.prio] then e.prio = f.prio end
            if f.area and f.area ~= "" then e.area = f.area end
            e.text = text
            e.edited = time()
            mod:Dbg("Update #" .. id)
            return e
        end
    end
    return nil, L.NOT_FOUND
end

-- Vom Manager Übernommenes löschen (ab 0.3.0). Rückgabe: Anzahl gelöscht
function ns.ApplyManagerMark()
    local data = rawget(_G, "PeonBridgeData")
    local upTo = type(data) == "table" and data.feedbackClearBefore
    local db = mod.db
    if type(upTo) ~= "number" or not db then return 0 end
    local keep, n = {}, 0
    for _, e in ipairs(db.entries) do
        if (e.edited or e.t or 0) <= upTo then n = n + 1 else keep[#keep + 1] = e end
    end
    db.entries = keep
    return n
end

-- Gespeichertes dem Spiel zum Schreiben geben, dort holt es der Manager ab
function ns.SendToManager()
    if ReloadUI then ReloadUI() end
end

function ns.Get(id)
    for _, e in ipairs(mod.db and mod.db.entries or {}) do if e.id == id then return e end end
end

function ns.Counts()
    local n, high = 0, 0
    for _, e in ipairs(mod.db and mod.db.entries or {}) do
        n = n + 1
        if e.prio == "high" then high = high + 1 end
    end
    return n, high
end

-- ===== Start =====

mod:On("INIT", function()
    ns.ApplyManagerMark()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
    mod:NewMinimapButton({
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        name = "PeonFeedbackMinimapButton",
        onClick = function(m, button)
            if button == "RightButton" then m:OpenOptions() else ns.Toggle() end
        end,
        onTooltip = function(m, tooltip)
            tooltip:AddLine(L.MM_COUNT:format(ns.Counts()), 1, 1, 1)
        end,
        hint = L.MM_HINT,
    })
end)
