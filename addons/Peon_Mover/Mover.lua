-- Peon_Mover - Mover.lua
-- Fenster von Blizzard verschiebbar machen (Titelleiste), Groesse mit Strg + Mausrad,
-- Umschalt + Rechtsklick auf die Titelleiste setzt zurueck. Positionen in PeonMoverDB (accountweit).
--
-- Grundsaetze (siehe Peon_Mover_Konzept.md):
--   * Nichts von Blizzard ersetzen: nur HookScript / hooksecurefunc, Blizzard-Tabellen nur lesen.
--   * Geschuetzte Fenster im Kampf nie anfassen; was ansteht, wird nach dem Kampf nachgeholt.
--   * Gespeichert: x/y = linke obere Ecke in Einheiten von UIParent, s = Groesse (Skalierung).

local ADDON_NAME, ns = ...
local L = ns.L

local TITLE_H = 26                       -- Hoehe des Streifens oben, der als Titelleiste gilt
local MIN_SCALE, MAX_SCALE, STEP = 0.5, 2.0, 0.05

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "mover",
    title    = "Mover",
    db       = "PeonMoverDB",
    defaults = {
        enabled = true,     -- Verschieben erlaubt (Sperre = aus)
        frames  = {},       -- [Fenstername] = { x, y, s, off }
    },
    keepOnReset = { frames = true },   -- "Standardwerte" laesst die Fensterpositionen stehen
    onSlash  = function(m, cmd)
        if cmd == "zuruecksetzen" or cmd == "zurücksetzen" or cmd == "reset" then
            ns.ResetAll()
            m:Print(L.MSG_RESET_ALL)
        else
            m:OpenOptions()
        end
    end,
})
ns.mod = mod

ns.win = {}        -- [Name] = { name, frame, auto, hooked, orig, origScale, moving }
local byFrame = {}
local queue = {}   -- [Schluessel] = Funktion, laeuft nach dem Kampf
local applying = false
local combatHint = false
ns.queue = queue

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
local function Saved(name)
    local db = mod.db
    return db and type(db.frames) == "table" and db.frames[name] or nil
end

local function Entry(name)
    local frames = mod.db.frames
    local s = frames[name]
    if type(s) ~= "table" then s = {}; frames[name] = s end
    return s
end

-- leere Eintraege entfernen
local function Tidy(name)
    local s = Saved(name)
    if s and s.x == nil and s.s == nil and not s.off then mod.db.frames[name] = nil end
end

local function IsOff(name) local s = Saved(name) return s and s.off and true or false end

local function Protected(f)
    local ok, p = pcall(f.IsProtected, f)
    return ok and p and true or false
end

-- im Kampf gesperrt?
local function Locked(f) return InCombatLockdown() and Protected(f) end

local function Defer(key, fn) queue[key] = fn end

local function CombatHint()
    if combatHint then return end
    combatHint = true
    mod:Print(L.MSG_COMBAT)
end

-- Skalierung des Fensters gegenueber UIParent (Abstaende in SetPoint gelten in Fenster-Einheiten)
local function Rel(f)
    local p = UIParent:GetEffectiveScale()
    local e = f:GetEffectiveScale()
    if not p or p <= 0 or not e or e <= 0 then return 1 end
    return e / p
end

local function Round(v, n) local m = 10 ^ (n or 1) return math.floor(v * m + 0.5) / m end

local function RefreshOptions()
    if ns.RefreshList then mod:Call("Optionen", ns.RefreshList) end
end

---------------------------------------------------------------------------
-- Anwenden, Speichern, Zuruecksetzen
---------------------------------------------------------------------------
function ns.Apply(w)
    local s = Saved(w.name)
    local f = w.frame
    if not s or s.off or not w.hooked then return end
    if Locked(f) then Defer("apply:" .. w.name, function() ns.Apply(w) end) return end
    applying = true
    local ok, err = pcall(function()
        if s.s and math.abs((f:GetScale() or 1) - s.s) > 0.001 then f:SetScale(s.s) end
        local r = Rel(f)
        -- winzig versteckt (z. B. Peon_Bags haengt das Bankfenster in einen Rahmen mit Groesse 0,001): Abstaende
        -- waeren das Tausendfache, nach dem Zurueckholen saesse das Fenster am Bildschirmrand. Dann nichts setzen,
        -- das Umhaengen zurueck (SetParent) wendet die Lage erneut an.
        if s.x and s.y and r >= 0.05 then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.x / r, s.y / r)
        end
    end)
    applying = false
    if not ok then mod:ReportError("Anwenden " .. w.name, err) end
end

local function SavePosition(w)
    local f = w.frame
    local left, top = f:GetLeft(), f:GetTop()
    if not left or not top then return end
    local r = Rel(f)
    local s = Entry(w.name)
    s.x, s.y = Round(left * r), Round(top * r)
    mod:Dbg(("%s verschoben: %.1f / %.1f"):format(w.name, s.x, s.y))
end

-- Blizzards Position und Groesse wiederherstellen (ohne die gespeicherten Werte anzufassen)
local function Restore(w)
    local f = w.frame
    if not w.hooked then return end
    if Locked(f) then Defer("restore:" .. w.name, function() Restore(w) end) return end
    applying = true
    local ok, err = pcall(function()
        if w.origScale and math.abs((f:GetScale() or 1) - w.origScale) > 0.001 then f:SetScale(w.origScale) end
        if w.orig and #w.orig > 0 then
            f:ClearAllPoints()
            for _, p in ipairs(w.orig) do f:SetPoint(unpack(p, 1, p.n or #p)) end
        end
    end)
    applying = false
    if not ok then mod:ReportError("Zuruecksetzen " .. w.name, err) end
end

-- Position und Groesse eines Fensters zuruecksetzen (auch fuer noch nicht geladene Fenster)
function ns.Reset(name)
    if mod.db and mod.db.frames then mod.db.frames[name] = nil end
    queue["apply:" .. name] = nil
    local w = ns.win[name]
    if w then Restore(w) end
    RefreshOptions()
end

function ns.ResetAll()
    local names = {}
    for name in pairs(mod.db.frames) do names[#names + 1] = name end
    for _, name in ipairs(names) do ns.Reset(name) end
end

-- Mover fuer ein Fenster an/aus; die gespeicherten Werte bleiben fuer spaeter erhalten
function ns.Toggle(name)
    local s = Entry(name)
    s.off = (not s.off) or nil
    local w = ns.win[name]
    if w then
        if s.off then Restore(w) else ns.Apply(w) end
    end
    Tidy(name)
    RefreshOptions()
end

function ns.IsOff(name) return IsOff(name) end

---------------------------------------------------------------------------
-- Maus
---------------------------------------------------------------------------
-- liegt der Mauszeiger im Streifen der Titelleiste?
function ns.InTitle(f)
    local top = f:GetTop()
    if not top then return false end
    local _, cy = GetCursorPosition()
    local e = f:GetEffectiveScale()
    if not cy or not e or e <= 0 then return false end
    cy = cy / e
    return cy <= top + 2 and cy >= top - TITLE_H
end

local function Usable(w)
    return w and w.hooked and mod.db and mod.db.enabled and not IsOff(w.name)
end

local function StopMoving(w)
    local f = w.frame
    w.moving = false
    f:StopMovingOrSizing()
    if f.SetUserPlaced then pcall(f.SetUserPlaced, f, w.userPlaced or false) end
    SavePosition(w)
    ns.Apply(w)
    RefreshOptions()
end

local function OnMouseDown(f, button)
    local w = byFrame[f]
    if not Usable(w) or not ns.InTitle(f) then return end
    if button == "LeftButton" then
        if Locked(f) then CombatHint() return end
        w.userPlaced = f.IsUserPlaced and f:IsUserPlaced() or false
        w.moving = true
        f:StartMoving()
    elseif button == "RightButton" and IsShiftKeyDown() then
        if Locked(f) then CombatHint() return end
        ns.Reset(w.name)
    end
end

local function OnMouseUp(f)
    local w = byFrame[f]
    if w and w.moving then StopMoving(w) end
end

local function OnHide(f)
    local w = byFrame[f]
    if w and w.moving then StopMoving(w) end
end

local function OnMouseWheel(f, delta)
    if not IsControlKeyDown() then return end
    local w = byFrame[f]
    if not Usable(w) then return end
    if Locked(f) then CombatHint() return end
    local cur = f:GetScale() or 1
    local new = math.floor((cur + (delta > 0 and STEP or -STEP)) * 20 + 0.5) / 20
    if new < MIN_SCALE then new = MIN_SCALE elseif new > MAX_SCALE then new = MAX_SCALE end
    if math.abs(new - cur) < 0.001 then return end
    local s = Entry(w.name)
    if math.abs(new - (w.origScale or 1)) < 0.001 then s.s = nil else s.s = new end
    applying = true
    pcall(f.SetScale, f, new)
    applying = false
    ns.Apply(w)              -- gespeicherte Position bei neuer Groesse wieder genau dort
    Tidy(w.name)
    mod:Dbg(("%s Groesse %d %%"):format(w.name, math.floor(new * 100 + 0.5)))
    RefreshOptions()
end

local function OnShow(f)
    local w = byFrame[f]
    if w then ns.Apply(w) end
end

---------------------------------------------------------------------------
-- Mitlesen, wenn Blizzard das Fenster selbst setzt
---------------------------------------------------------------------------
local function OnClearAllPoints(f)
    if applying then return end
    local w = byFrame[f]
    if w then w.bliz = {} end
end

local function OnSetPoint(f, ...)
    if applying then return end
    local w = byFrame[f]
    if not w then return end
    -- Blizzards Wunschposition merken (fuer Zuruecksetzen)
    local p = { n = select("#", ...), ... }
    w.bliz = w.bliz or {}
    for i = #w.bliz, 1, -1 do if w.bliz[i][1] == p[1] then table.remove(w.bliz, i) end end
    w.bliz[#w.bliz + 1] = p
    w.orig = w.bliz
    if w.moving then return end
    local s = Saved(w.name)
    if s and not s.off and s.x then ns.Apply(w) end
end

-- Fenster umgehaengt (anderer Eltern-Rahmen, andere Gesamtgroesse): gespeicherte Lage neu anwenden
local function OnSetParent(f)
    if applying then return end
    local w = byFrame[f]
    if w and not w.moving and f:IsShown() then ns.Apply(w) end
end

local function OnSetScale(f, scale)
    if applying then return end
    local w = byFrame[f]
    if not w then return end
    w.origScale = scale
    local s = Saved(w.name)
    if s and not s.off and s.s then ns.Apply(w) end
end

---------------------------------------------------------------------------
-- Fenster finden und einhaengen
---------------------------------------------------------------------------
local function GetPoints(f)
    local t = {}
    for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do
        local p = { f:GetPoint(i) }
        p.n = 5
        t[#t + 1] = p
    end
    return t
end

local function Hook(w)
    local f = w.frame
    if w.hooked then return end
    if Locked(f) then Defer("hook:" .. w.name, function() Hook(w) end) return end
    local ok, err = pcall(function()
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        if f.IsMouseEnabled and not f:IsMouseEnabled() then f:EnableMouse(true) end
        if f.IsMouseWheelEnabled and not f:IsMouseWheelEnabled() then f:EnableMouseWheel(true) end
        w.orig = GetPoints(f)
        w.origScale = f:GetScale()
        f:HookScript("OnMouseDown", OnMouseDown)
        f:HookScript("OnMouseUp", OnMouseUp)
        f:HookScript("OnMouseWheel", OnMouseWheel)
        f:HookScript("OnShow", OnShow)
        f:HookScript("OnHide", OnHide)
        hooksecurefunc(f, "ClearAllPoints", OnClearAllPoints)
        hooksecurefunc(f, "SetPoint", OnSetPoint)
        hooksecurefunc(f, "SetScale", OnSetScale)
        if f.SetParent then hooksecurefunc(f, "SetParent", OnSetParent) end
    end)
    if not ok then
        mod:ReportError("Einhaengen " .. w.name, err)
        return
    end
    w.hooked = true
    mod:Dbg(("Fenster eingehaengt: %s%s%s"):format(w.name, w.auto and " (automatisch)" or "",
        Protected(f) and " (geschuetzt)" or ""))
    if f:IsShown() then ns.Apply(w) end
end

local function Consider(name, auto)
    if type(name) ~= "string" or ns.win[name] or ns.SkipName(name) then return end
    local f = _G[name]
    if type(f) ~= "table" or type(f.GetObjectType) ~= "function" or type(f.StartMoving) ~= "function" then return end
    if f.IsForbidden and f:IsForbidden() then return end
    local w = { name = name, frame = f, auto = auto and not ns.KNOWN[name] or false }
    ns.win[name] = w
    byFrame[f] = w
    Hook(w)
    return w
end

-- alle bekannten und von Blizzard gefuehrten Fenster suchen (nach dem Login und bei jedem Nachladen)
function ns.Scan()
    for name in pairs(ns.KNOWN) do Consider(name, false) end
    local panels = rawget(_G, "UIPanelWindows")
    if type(panels) == "table" then
        for name in pairs(panels) do Consider(name, true) end
    end
    RefreshOptions()
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
mod:On("INIT", function()
    if ns.CreateOptions then mod:Call("Optionen", ns.CreateOptions) end
end)
mod:On("LOGIN", function() ns.Scan() end)
mod:On("COMBAT_END", function()
    combatHint = false
    local list = {}
    for k, fn in pairs(queue) do list[#list + 1] = fn; queue[k] = nil end
    for _, fn in ipairs(list) do mod:Call("Nach dem Kampf", fn) end
end)
mod:RegisterEvent("ADDON_LOADED", function() if Peon.loggedIn then ns.Scan() end end)

if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Verschieben", "Größe", "Zurücksetzen", "Fensterliste", "Kampf", "Optionen" }) end
