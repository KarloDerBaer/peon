-- ============================================================================
--  Peon_ComboPoints
--  Runde Combo-Punkte im Blizzard-Stil waagerecht ueber dem Nameplate.
--
--  Zum Verstaendnis des Codes:
--  Combo-Punkte sind "secret values". Sie duerfen nicht verglichen, nicht
--  berechnet und nicht verkettet werden - aber sie duerfen in Variablen
--  abgelegt, weitergereicht und an Blizzards Setter uebergeben werden.
--  Darauf beruht dieses Addon an zwei Stellen:
--
--  1. Jeder Punkt ist eine eigene StatusBar mit SetMinMaxValues(i-1, i).
--     Alle bekommen denselben geheimen Wert; jede Leiste entscheidet
--     intern, ob sie voll oder leer ist. Der Lua-Code vergleicht nie.
--
--  2. Es gibt keine Abfrage "wie viele Punkte hat Gegner X". UnitPower
--     liefert nicht den Stand des Ziels, sondern den des Gegners, auf dem
--     zuletzt aufgebaut wurde, und GetComboPoints gibt fuer alles ausser
--     dem Ziel nur eine geheime Null. Also merkt sich das Addon den
--     geheimen Wert samt dem Nameplate, auf dem er entstanden ist, in
--     genau dem Moment, in dem er entsteht.
--
--  In WoW Forever haengen die Punkte am Gegner, nicht am Spieler, und es
--  kann immer nur EIN Gegner Punkte tragen. Daher gibt es genau einen
--  "Traeger". Nur er zeigt gefuellte Punkte - auch dann, wenn er gerade
--  nicht anvisiert ist. Das Anvisieren steuert allein, ob die leeren
--  Fassungen sichtbar sind.
--
--  Daraus folgt: hoechstens zwei Nameplates zeigen jemals etwas, naemlich
--  das Ziel und der Traeger. Fuer alle anderen wird nichts gebaut.
-- ============================================================================

-- ============================ Aussehen ======================================
-- Standardwerte; einstellbar unter Einstellungen > AddOns > Peon > ComboPoints.
-- Die Werte werden in ReadStyle() in die lokalen Variablen darunter kopiert.
local DEFAULTS = {
    size        = 15,                          -- Durchmesser eines Punktes
    gap         = 4,                           -- Abstand zwischen den Punkten
    yOffset     = 8,                           -- Hoehe ueber dem HP-Balken
    ringPad     = 1,                           -- Dicke des Randes
    showSockets = true,                        -- leere Fassungen am Ziel zeigen
    fillColor   = { 1.00, 0.24, 0.20 },        -- gefuellter Punkt
    socketColor = { 0.00, 0.00, 0.00, 0.70 },  -- leere Fassung
    ringColor   = { 0.85, 0.70, 0.32, 1.00 },  -- goldener Rand
}
local SIZE, GAP, Y_OFFSET, RING_PAD = 15, 4, 8, 1
local FILL, SOCKET, RING = DEFAULTS.fillColor, DEFAULTS.socketColor, DEFAULTS.ringColor
local SHOW_SOCKETS = true
local styleVersion = 0      -- steigt bei jeder Aenderung; Reihen gleichen sich dann an
-- ============================================================================

local CP_POWER    = Enum.PowerType.ComboPoints
local DEFAULT_MAX = 5
local SOLID       = "Interface\\Buttons\\WHITE8X8"       -- FileID 130871
local CIRCLE      = "Interface\\CharacterFrame\\TempPortraitAlphaMask" -- 130924
-- Beide Pfade sind auf Client 1.60.1 (Build 69913) per GetFileIDFromPath
-- nachgewiesen. Faellt der Kreis irgendwann weg: Interface\Masks\CircleMask
-- und Interface\Masks\CircleMaskScalable liegen ebenfalls vor.

-- Anmeldung beim Peon-Kern: Chat-Ausgaben, Fehlermeldung einmal pro Sitzung,
-- Debug-Log (/peon debug combopoints). Die Ereignisse laufen weiter ueber den
-- eigenen Rahmen, weil RegisterUnitEvent gebraucht wird.
local ADDON_NAME, ns = ...

local function IsColor(n)
    return function(v)
        if type(v) ~= "table" then return false end
        for i = 1, n do
            if type(v[i]) ~= "number" or v[i] < 0 or v[i] > 1 then return false end
        end
        return true
    end
end

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "combopoints",
    title    = "ComboPoints",
    db       = "PeonComboPointsDB",
    defaults = DEFAULTS,
    ranges   = {
        size    = { 8, 32, 1 },
        gap     = { 0, 16, 1 },
        yOffset = { -30, 60, 1 },
        ringPad = { 0, 4, 1 },
    },
    validate = {
        fillColor   = IsColor(3),
        socketColor = IsColor(4),
        ringColor   = IsColor(4),
    },
})
ns.mod = mod

local function ReadStyle()
    local db = mod.db
    if not db then return end
    SIZE, GAP, Y_OFFSET, RING_PAD = db.size, db.gap, db.yOffset, db.ringPad
    FILL, SOCKET, RING = db.fillColor, db.socketColor, db.ringColor
    SHOW_SOCKETS = db.showSockets
    styleVersion = styleVersion + 1
end

local frame = CreateFrame("Frame")

-- Der Gegner, auf dem die Punkte liegen. holderValue ist ein secret value:
-- er wird nur festgehalten und weitergereicht, nie angesehen.
--
-- Erkannt wird der Traeger ueber seinen Nameplate-Rahmen, nicht ueber die
-- GUID. UnitGUID traegt das Praedikat SecretWhenUnitIdentityRestricted und
-- liefert in Gruppe und Dungeon einen geheimen String; zwei davon zu
-- vergleichen wirft "attempt to compare a secret string value". Dasselbe
-- gilt fuer UnitIsUnit (SecretWhenUnitComparisonRestricted), das dort einen
-- geheimen Boolean liefern kann - und der laesst sich nicht einmal auf
-- Wahrheit testen. Rahmen dagegen sind gewoehnliche Lua-Objekte und immer
-- vergleichbar. Deshalb laeuft im Zeichenpfad kein einziger Unit-Vergleich.
--
-- Ein Rahmen allein reicht aber nicht: beim ersten Punkt kann das Nameplate
-- des Gegners noch gar nicht existieren, und ein verschwundenes und wieder
-- aufgetauchtes Plate ist ein neuer Rahmen. Deshalb gibt es zusaetzlich
-- holderIsTarget. Der Traeger wird ausschliesslich aus dem Ziel gesetzt,
-- also ist er so lange mit dem Ziel identisch, bis das Ziel wechselt - und
-- das meldet PLAYER_TARGET_CHANGED zuverlaessig, ganz ohne Unit-Vergleich.
-- Solange die Fahne steht, ist das Nameplate des Ziels der Traeger, auch
-- wenn holderFrame noch oder nicht mehr darauf zeigt.
--
-- holderGUID wird nur an einer Stelle gebraucht: um ein wiederauftauchendes
-- Nameplate dem Traeger zuzuordnen, waehrend ein anderer Gegner anvisiert
-- ist. Dort ist der Vergleich abgesichert.
local holderFrame, holderGUID, holderValue
local holderIsTarget = false

-- Das Nameplate, das zuletzt die leeren Fassungen gezeigt hat. Wird beim
-- Rendern gesetzt und nicht aus dem Ziel abgeleitet, damit es auch dann
-- stimmt, wenn das Nameplate des Ziels erst verspaetet auftaucht.
local socketFrame

-- Laenge der Reihe. Wird zwischengespeichert, weil UnitPowerMax laut API
-- geheim sein kann und der noetige Vergleich dann einen Fehler wuerfe.
local maxCP = DEFAULT_MAX

local dirtyFrames, dirtyUnits = {}, {}
local scheduled = false

local function GetHealthBar(uf)
    return uf.healthBar
        or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
        or uf.HealthBarsContainer
end

-- Aktuelles Unit-Token eines Nameplate-Rahmens, live statt gemerkt
local function UnitOf(uf)
    local np = uf.namePlateFrame
    return (np and np.namePlateUnitToken) or uf.unit
end

local function TargetFrame()
    local np = C_NamePlate.GetNamePlateForUnit("target")
    return np and np.UnitFrame or nil
end

-- Sind beide GUIDs geheim, wirft der Vergleich einen Fehler. Den faengt der
-- pcall ab; das Ergebnis lautet dann "nicht zuordenbar", was hier die
-- sichere Antwort ist. Der Test gegen nil davor ist erlaubt, weil Lua Werte
-- unterschiedlichen Typs gar nicht erst vergleicht.
local function SameGUID(a, b)
    if a == nil or b == nil then return false end
    local ok, equal = pcall(function() return a == b end)
    return ok and equal
end

local function ReadMaxCP()
    local n = UnitPowerMax("player", CP_POWER)
    if n >= 1 and n <= 10 then return n end
end

local function RefreshMaxCP()
    local ok, n = pcall(ReadMaxCP)
    maxCP = (ok and n) or DEFAULT_MAX
end

-- ------------------------------------------------------------------ Aufbau --
-- Groesse, Lage und Farben eines Punktes; beim Anlegen und nach jeder
-- Aenderung in den Optionen
local function StylePip(pip, row, index)
    pip:SetSize(SIZE, SIZE)
    pip:ClearAllPoints()
    pip:SetPoint("LEFT", row, "LEFT", (index - 1) * (SIZE + GAP), 0)
    pip:SetStatusBarColor(FILL[1], FILL[2], FILL[3])
    for _, t in ipairs({ pip.ringMask, pip.ring }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT",     pip, "TOPLEFT",     -RING_PAD,  RING_PAD)
        t:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT",  RING_PAD, -RING_PAD)
    end
    pip.ring:SetColorTexture(RING[1], RING[2], RING[3], RING[4])
    pip.socket:SetColorTexture(SOCKET[1], SOCKET[2], SOCKET[3], SOCKET[4])
end

local function CreatePip(row, index)
    local pip = CreateFrame("StatusBar", nil, row)
    pip:SetMinMaxValues(index - 1, index)
    pip:SetValue(index - 1)
    pip:SetStatusBarTexture(SOLID)

    local mask = pip:CreateMaskTexture()
    mask:SetAllPoints(pip)
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local ringMask = pip:CreateMaskTexture()
    ringMask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local ring = pip:CreateTexture(nil, "BACKGROUND", nil, -2)
    ring:AddMaskTexture(ringMask)

    local socket = pip:CreateTexture(nil, "BACKGROUND", nil, -1)
    socket:SetAllPoints(pip)
    socket:AddMaskTexture(mask)

    local fillTex = pip:GetStatusBarTexture()
    if fillTex and fillTex.AddMaskTexture then
        fillTex:AddMaskTexture(mask)
    end

    pip.socket, pip.ring, pip.ringMask = socket, ring, ringMask
    StylePip(pip, row, index)
    return pip
end

-- Reihe an die aktuellen Einstellungen anpassen (Groesse, Abstand, Farben)
local function StyleRow(row, count)
    for i, pip in ipairs(row.pips) do StylePip(pip, row, i) end
    row:SetSize(count * SIZE + (count - 1) * GAP, SIZE)
    row.styleVersion = styleVersion
end
ns.CreatePip, ns.StyleRow = CreatePip, StyleRow

-- Die Reihe wird pro Nameplate einmal angelegt und danach nur noch
-- angepasst. Frames lassen sich in WoW nicht freigeben, ein Neuaufbau bei
-- geaenderter Punktzahl waere also ein Leck.
local function EnsureRow(uf)
    local row = uf.cpRow
    if not row then
        row = CreateFrame("Frame", nil, uf)
        row.pips = {}
        uf.cpRow = row
    end

    if row.styleVersion ~= styleVersion then
        row:ClearAllPoints()
        row:SetPoint("BOTTOM", GetHealthBar(uf) or uf, "TOP", 0, Y_OFFSET)
        StyleRow(row, maxCP)
    end

    if uf.cpCount ~= maxCP then
        for i = #row.pips + 1, maxCP do
            row.pips[i] = CreatePip(row, i)
        end
        for i = 1, #row.pips do
            row.pips[i]:SetShown(i <= maxCP)
        end
        row:SetSize(maxCP * SIZE + (maxCP - 1) * GAP, SIZE)
        uf.cpCount = maxCP
    end

    return row
end

-- Alle Leisten bekommen denselben geheimen Wert; jede entscheidet anhand
-- ihres SetMinMaxValues, ob sie voll oder leer ist. Der Lua-Code vergleicht
-- dadurch nie.
local function Fill(row, value)
    for i = 1, maxCP do
        row.pips[i]:SetValue(value)
    end
end

-- Jede Leiste auf ihr eigenes Minimum, also die ganze Reihe leer.
local function Clear(row)
    for i = 1, maxCP do
        row.pips[i]:SetValue(i - 1)
    end
end

-- ------------------------------------------------- Ein einzelnes Nameplate --
local function Render(uf, unit, targetFrame)
    local row = uf.cpRow

    if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) then
        if row then row:Hide() end
        return
    end

    -- Beides reine Objektvergleiche und damit immer erlaubt. UnitIsUnit
    -- oder UnitGUID waeren hier die naheliegende, aber falsche Wahl: beide
    -- koennen geheime Werte liefern (siehe oben).
    local isTarget = (uf == targetFrame)
    local isHolder = (uf == holderFrame) or (holderIsTarget and isTarget)

    -- Hat die Fahne den Traeger erkannt, wird der Rahmen gleich
    -- nachgetragen. Damit findet ihn der naechste Durchlauf auch dann, wenn
    -- du inzwischen etwas anderes anvisierst.
    if isHolder then holderFrame = uf end

    if not isTarget and not isHolder then
        if row then row:Hide() end
        return
    end

    row = EnsureRow(uf)

    -- Leere Fassungen gehoeren zum Ziel, unabhaengig davon, wo die Punkte
    -- liegen.
    local socketAlpha = (isTarget and SHOW_SOCKETS) and 1 or 0
    for i = 1, maxCP do
        row.pips[i].socket:SetAlpha(socketAlpha)
        row.pips[i].ring:SetAlpha(socketAlpha)
    end
    if isTarget then socketFrame = uf end

    -- Punkte zeigt ausschliesslich der Traeger. Ein frisch anvisierter
    -- Gegner bleibt leer, weil UnitPower nicht zum Ziel gehoert, sondern
    -- weiterhin zum zuletzt bepunkteten Gegner.
    -- Der Test gegen nil ist auch bei einem secret value erlaubt und auf
    -- diesem Client nachgemessen: Lua vergleicht Werte unterschiedlichen
    -- Typs gar nicht erst. Verboten waeren nur echte Ordnungsvergleiche.
    if isHolder and holderValue ~= nil then
        Fill(row, holderValue)
    else
        Clear(row)
    end

    row:Show()
end

-- ------------------------------------------------------- Traegerverwaltung --
local function ForgetHolder()
    holderFrame, holderGUID, holderValue = nil, nil, nil
    holderIsTarget = false
end

local function SetHolderFromTarget()
    if not UnitExists("target") then
        ForgetHolder()
        return
    end
    -- TargetFrame() darf hier nil sein: baust du den ersten Punkt auf, bevor
    -- das Nameplate da ist, traegt holderIsTarget die Erkennung, bis das
    -- Plate auftaucht.
    holderFrame    = TargetFrame()
    holderGUID     = UnitGUID("target")
    holderValue    = UnitPower("player", CP_POWER)
    holderIsTarget = true
end

-- ---------------------------------------------------------------- Ablauf ---
-- Alles Anstehende wird zu einer Liste von Rahmen zusammengefasst, damit
-- jedes Nameplate pro Durchlauf genau einmal gezeichnet wird.
local function Flush()
    scheduled = false

    for unit in pairs(dirtyUnits) do
        if UnitExists(unit) then
            local np = C_NamePlate.GetNamePlateForUnit(unit)
            if np and np.UnitFrame then dirtyFrames[np.UnitFrame] = true end
        end
    end
    wipe(dirtyUnits)

    -- Einmal je Durchlauf bestimmt, nicht je Nameplate.
    local targetFrame = TargetFrame()

    -- Der Traeger wird immer mitgezogen, damit seine Punkte stehen bleiben,
    -- auch wenn er gerade nicht anvisiert ist. Kennen wir seinen Rahmen noch
    -- nicht, steht er beim Ziel.
    if holderFrame then dirtyFrames[holderFrame] = true end
    if holderIsTarget and targetFrame then dirtyFrames[targetFrame] = true end

    for uf in pairs(dirtyFrames) do
        Render(uf, UnitOf(uf), targetFrame)
    end
    wipe(dirtyFrames)
end

local function Schedule()
    if not scheduled then
        scheduled = true
        C_Timer.After(0, function() mod:Call("Flush", Flush) end)
    end
end

local function MarkUnit(unit)
    if unit then dirtyUnits[unit] = true; Schedule() end
end

local function MarkFrame(uf)
    if uf then dirtyFrames[uf] = true; Schedule() end
end

-- ----------------------------------------------------------------- Start ---
local function OnEvent(self, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        mod:Dbg("Login, Klasse " .. tostring(class))
        if class ~= "ROGUE" then
            self:UnregisterAllEvents()
            return
        end
        ns.active = true
        RefreshMaxCP()
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self:RegisterUnitEvent("UNIT_MAXPOWER", "player")

    elseif event == "UNIT_POWER_UPDATE" then
        if arg2 ~= "COMBO_POINTS" then return end
        -- Punkte entstehen nur am Ziel. Lag der Traeger vorher auf einem
        -- anderen Nameplate, hat jener Gegner sie genau jetzt verloren.
        local previous = holderFrame
        SetHolderFromTarget()
        if previous and previous ~= holderFrame then
            MarkFrame(previous)
        end
        MarkUnit("target")

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Das alte Ziel verliert die Fassungen, behaelt aber seine Punkte,
        -- falls es der Traeger ist. Ab jetzt sind Ziel und Traeger nicht
        -- mehr zwangslaeufig derselbe Gegner; erkannt wird er nur noch am
        -- Rahmen, den Render inzwischen nachgetragen hat.
        holderIsTarget = false
        MarkFrame(socketFrame)
        socketFrame = nil
        MarkUnit("target")

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local np = C_NamePlate.GetNamePlateForUnit(arg1)
        local uf = np and np.UnitFrame or nil
        if uf then
            -- Ein frisch vergebenes Plate gehoert diesem Gegner. Ob das der
            -- Traeger ist, kann nur die GUID sagen. Laesst sie sich nicht
            -- lesen, gilt es nicht als Traeger - und ein Verweis, der noch
            -- auf dieses Plate zeigt, wird aufgegeben. Lieber keine Punkte
            -- als Punkte am falschen Gegner.
            if SameGUID(UnitGUID(arg1), holderGUID) then
                holderFrame = uf
            elseif uf == holderFrame then
                holderFrame = nil
            end
        end
        MarkUnit(arg1)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Das Plate wird gleich fuer einen anderen Gegner wiederverwendet.
        -- Da der Traeger ueber den Rahmen erkannt wird, muessen die Verweise
        -- jetzt weg, sonst gilt der naechste Gegner auf diesem Plate
        -- faelschlich als Traeger.
        local np = C_NamePlate.GetNamePlateForUnit(arg1)
        local uf = np and np.UnitFrame
        if uf then
            if uf.cpRow then uf.cpRow:Hide() end
            if uf == holderFrame then holderFrame = nil end
            if uf == socketFrame then socketFrame = nil end
        end

    elseif event == "UNIT_MAXPOWER" then
        if arg2 == "COMBO_POINTS" then
            RefreshMaxCP()
            MarkFrame(holderFrame)
            MarkUnit("target")
        end

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        -- Kampfende und Gebietswechsel: die Punkte sind weg. Erst den alten
        -- Traeger vormerken, dann vergessen - beim Zeichnen ist er dann
        -- keiner mehr und wird geleert.
        MarkFrame(holderFrame)
        ForgetHolder()
        MarkUnit("target")
    end
end

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    mod:Call(event, OnEvent, self, event, arg1, arg2)
end)

-- Einstellungen: beim Laden uebernehmen, bei Aenderungen sofort neu zeichnen
local function StyleChanged()
    ReadStyle()
    if ns.UpdatePreview then ns.UpdatePreview() end
    if not ns.active then return end   -- kein Schurke: nichts an Nameplates zeichnen
    MarkFrame(holderFrame)
    MarkUnit("target")
end
mod:On("INIT", function()
    ReadStyle()
    if ns.CreateOptions then mod:Call("Options", ns.CreateOptions) end
end)
mod:On("CHANGED", StyleChanged)
mod:On("RESET", StyleChanged)
frame:RegisterEvent("PLAYER_LOGIN")

-- Bereiche für Rückmeldungen in Peon_Feedback (Kern ab API 9; mit älterem Kern wird nichts gemeldet)
if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, { "Anzeige", "Farben", "Optionen" }) end
