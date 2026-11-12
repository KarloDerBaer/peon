-- Peon - Notice.lua
-- Ab 0.20.0 (Kern-API 20): einmalige Hinweise der Module, zum Beispiel nach einem Update.
-- Ein Modul meldet einen Hinweis mit mod:AddNotice({ id = "...", title = "...", text = "..." }).
-- Nach dem Einloggen zeigt der Kern alle noch nicht gesehenen Hinweise einmal in einem Fenster.
-- Gesehen wird je Konto gemerkt (PeonDB.noticesSeen[id] = Zeit). /peon neu zeigt alle wieder.
--
-- Beispiel (in einem Modul, am besten direkt nach Peon:NewModule):
--   if mod.AddNotice then   -- haelt das Modul mit aelterem Kern lauffaehig
--       mod:AddNotice({
--           id    = "umbau-2026-11",          -- Pflicht, nie wieder aendern (sonst erscheint er erneut)
--           date  = "12.11.2026",             -- optional, wird angezeigt
--           title = "Broker neu aufgebaut",
--           text  = { "Erster Absatz.", "Zweiter Absatz." },   -- Text oder Liste von Absaetzen
--       })
--   end

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L
local UI = ns.UI

local N = {}
ns.Notice = N
N.list = {}          -- alle gemeldeten Hinweise in Reihenfolge der Anmeldung
N.byId = {}
N.DELAY = 5          -- Sekunden nach dem Einloggen
N.RETRY = 10         -- Sekunden bis zum naechsten Versuch im Kampf

local function Plain(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Seen()
    local db = Peon.db
    if type(db) ~= "table" then return nil end
    if type(db.noticesSeen) ~= "table" then db.noticesSeen = {} end
    return db.noticesSeen
end

---------------------------------------------------------------------------
-- Anmelden (API 20)
---------------------------------------------------------------------------
-- o.id (Pflicht), o.title, o.text (Text oder Liste), o.date, o.from (Name des Absenders)
function Peon.AddNotice(o)
    if type(o) ~= "table" or type(o.id) ~= "string" or o.id == "" then return false end
    if N.byId[o.id] then return false end
    local text = o.text
    if type(text) ~= "table" then text = { tostring(text or "") } end
    local n = { id = o.id, title = tostring(o.title or ""), text = text,
        date = o.date and tostring(o.date) or nil, from = Plain(o.from or "Peon") }
    N.list[#N.list + 1] = n
    N.byId[n.id] = n
    -- Nach dem Einloggen gemeldet (Modul spaeter geladen): ebenfalls zeigen
    if Peon.loggedIn then N.Schedule(1) end
    return true
end

-- Am Modul: Name als Absender, Schluessel des Moduls vor der id (keine Kollision zwischen Modulen)
function Peon.ModulePrototype:AddNotice(o)
    if type(o) ~= "table" or type(o.id) ~= "string" or o.id == "" then return false end
    local c = {}
    for k, v in pairs(o) do c[k] = v end
    c.id = self.key .. ":" .. o.id
    c.from = o.from or self.title
    return Peon.AddNotice(c)
end

-- Noch nicht gesehene Hinweise
function N.Unseen()
    local seen, out = Seen(), {}
    if not seen then return out end
    for _, n in ipairs(N.list) do
        if not seen[n.id] then out[#out + 1] = n end
    end
    return out
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local W, H = 520, 460
local PAD = 20
local TEXT_W = W - 2 * PAD - 30   -- Platz fuer die Bildlaufleiste

local function Height(fs, fallback)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if type(h) ~= "number" or h <= 0 then h = fallback or 14 end
    return h
end

local function Build()
    local f = UI.Window("PeonNoticeFrame", { title = L.NOTICE_TITLE, icon = "Interface\\Icons\\INV_Pick_02", width = W, height = H })
    f:SetFrameStrata("DIALOG")

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, f) end
    scroll:SetPoint("TOPLEFT", PAD, -66)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 26, 52)
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(TEXT_W, 10)
    scroll:SetScrollChild(content)
    f.scroll, f.content = scroll, content
    f.parts = {}

    f.hint = UI.Text(f, "sub", L.NOTICE_AGAIN)
    f.hint:SetPoint("BOTTOMLEFT", PAD, 22)
    f.ok = UI.Button(f, L.NOTICE_OK, 130, function() f:Hide() end)
    f.ok:SetPoint("BOTTOMRIGHT", -PAD, 16)
    N.frame = f
    return f
end

local function Part(f, i, role)
    local p = f.parts[i]
    if not p then
        p = UI.Text(f.content, role, "", TEXT_W)
        f.parts[i] = p
    end
    if p.SetFontObject and UI.FONT[role] then pcall(p.SetFontObject, p, UI.FONT[role]) end
    p:ClearAllPoints()
    p:Show()
    return p
end

-- Hinweise ins Fenster schreiben (Liste in Anzeige-Reihenfolge)
function N.Fill(list)
    local f = N.frame or Build()
    for _, p in ipairs(f.parts) do p:Hide() end
    for _, d in ipairs(f.dividers or {}) do d:Hide() end
    f.dividers = f.dividers or {}
    local y, i, nd = 0, 0, 0
    local function Add(role, text, gap)
        i = i + 1
        local p = Part(f, i, role)
        p:SetText(text)
        y = y + (gap or 0)
        p:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -y)
        y = y + Height(p)
    end
    for k, n in ipairs(list) do
        if k > 1 then
            nd = nd + 1
            local d = f.dividers[nd]
            if not d then d = UI.Divider(f.content, TEXT_W); f.dividers[nd] = d end
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(y + 12))
            d:Show()
            y = y + 25
        end
        Add("big", n.title)
        Add("sub", n.date and (n.from .. "  ·  " .. n.date) or n.from, 3)
        for _, para in ipairs(n.text) do Add("text", tostring(para), 10) end
    end
    f.content:SetHeight(math.max(y + 10, 10))
    f.shownList = list
    return f
end

-- Fenster mit den Hinweisen zeigen. all = auch gesehene (fuer /peon neu)
function N.Show(all)
    local list = all and N.list or N.Unseen()
    if #list == 0 then return false end
    local ok, err = pcall(function()
        local f = N.Fill(list)
        if f.scroll.SetVerticalScroll then f.scroll:SetVerticalScroll(0) end
        f:Show()
    end)
    if not ok then Peon.ReportCoreError("Notice", err); return false end
    -- Gesehen, sobald gezeigt: auch Schliessen mit ESC oder X zaehlt
    local seen, now = Seen(), time and time() or 0
    if seen then for _, n in ipairs(list) do seen[n.id] = seen[n.id] or now end end
    return true
end

---------------------------------------------------------------------------
-- Nach dem Einloggen: kurz warten, nie im Kampf
---------------------------------------------------------------------------
function N.Try()
    N.pending = false
    if #N.Unseen() == 0 then return end
    if Peon.InCombat() then N.Schedule(N.RETRY); return end
    N.Show(false)
end

function N.Schedule(sec)
    if N.pending then return end
    N.pending = true
    if C_Timer and C_Timer.After then C_Timer.After(sec or N.DELAY, N.Try) else N.Try() end
end

function N.OnLogin()
    if #N.Unseen() > 0 then N.Schedule(N.DELAY) end
end

-- /peon neu
function N.Slash()
    if #N.list == 0 then Peon.Print(L.NOTICE_NONE); return end
    if Peon.InCombat() then Peon.Print(L.NOTICE_COMBAT); return end
    N.Show(true)
end
