-- Peon_Broker - Rating.lua
-- Ab 0.91 (Fehlerbericht 17): Einschaetzung eines Gegenstands. Ein kleines Fenster fragt, wie man die Chance auf
-- Gewinn einstuft (schlecht, mittel, gut), dazu eine Bemerkung als freier Text. Gespeichert werden ausserdem die
-- Daten, die Broker in diesem Moment zum Gegenstand hat, und ob das Radar ihn gerade vorschlaegt. So laesst sich
-- spaeter auswerten, was das Radar vielleicht falsch vorgeschlagen hat und warum.
-- Geoeffnet ueber das Gegenstandsmenue (Strg+Rechtsklick, Rechtsklick in Brokers Listen, auch im Radar).
--
-- Speicher (accountweit): PeonBrokerDB.ratings = { { key, name, t, market, rate ("bad", "mid", "good"), note,
--   data = { m, md, q, n, t } (Preisdaten des Markts), radar = { kind, qty, cost, gain, ref, limit, ... } oder nil,
--   radarGone = Grund oder nil (Vorschlag eben weggefallen), focus = true (stand im Fokus) } }, hoechstens Ra.MAX.
-- Die Auswertung im Peon Manager kommt spaeter (KarloDerBaer, 13.11.2026).

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local Ra = {}
ns.Rating = Ra

Ra.MAX = 500
Ra.RATES = { "bad", "mid", "good" }
Ra.NOTE_MAX = 250

local function Num(v) return type(v) == "number" and not Peon.IsSecret(v) end

function Ra.List()
    local acc = mod.acc
    if type(acc) ~= "table" then return {} end
    if type(acc.ratings) ~= "table" then acc.ratings = {} end
    return acc.ratings
end

-- Einfache Werte einer Tabelle kopieren (Zahlen, Texte, Wahrheitswerte), keine Unter-Tabellen
local function Flat(t)
    if type(t) ~= "table" then return nil end
    local out, any = {}, false
    for k, v in pairs(t) do
        local tv = type(v)
        if type(k) == "string" and (tv == "number" or tv == "string" or tv == "boolean") and not Peon.IsSecret(v) then
            out[k] = v
            any = true
        end
    end
    return any and out or nil
end

-- Momentaufnahme zum Gegenstand: Preisdaten, Vorschlag des Radars, Fokus
function Ra.Snapshot(key)
    local snap = {}
    local D = ns.Data
    local e = D and D.Lookup and D.Lookup(key) or nil
    if type(e) == "table" then
        snap.data = { m = Num(e.m) and e.m or nil, md = Num(e.md) and e.md or nil, q = Num(e.q) and e.q or nil,
                      n = Num(e.n) and e.n or nil, t = Num(e.t) and e.t or nil, gone = Num(e.gone) and e.gone or nil }
    end
    local R = ns.Radar
    if R and type(R.entries) == "table" and R.entries[key] then
        snap.radar = Flat(R.entries[key])
    elseif R and type(R.gone) == "table" and R.gone[key] then
        snap.radar = Flat(R.gone[key])
        snap.radarGone = true
    end
    if ns.Focus and ns.Focus.key == key then snap.focus = true end
    return snap
end

-- Einschaetzung speichern. Rueckgabe: der Eintrag
function Ra.Add(key, name, rate, note)
    if key == nil then return nil end
    local list = Ra.List()
    local snap = Ra.Snapshot(key)
    if type(note) == "string" then
        note = note:gsub("^%s+", ""):gsub("%s+$", "")
        if #note > Ra.NOTE_MAX then note = note:sub(1, Ra.NOTE_MAX) end
        if note == "" then note = nil end
    else
        note = nil
    end
    local entry = { key = key, name = name, t = time and time() or 0, market = ns.MarketKey and ns.MarketKey() or nil,
                    rate = rate, note = note, data = snap.data, radar = snap.radar, radarGone = snap.radarGone,
                    focus = snap.focus }
    list[#list + 1] = entry
    while #list > Ra.MAX do table.remove(list, 1) end
    return entry
end

-- letzte Einschaetzung zu einem Gegenstand (oder nil)
function Ra.Last(key)
    local list = Ra.List()
    for i = #list, 1, -1 do
        if list[i].key == key then return list[i] end
    end
    return nil
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
function Ra.Build()
    if Ra.win then return Ra.win end
    local UI = Peon.UI
    if not UI then return nil end
    local f = UI.Window("PeonBrokerRatingFrame", { title = L.RATE_TITLE, icon = "Interface\\Icons\\INV_Misc_Note_01",
        width = 420, height = 250 })
    f:SetFrameStrata("DIALOG")
    f.item = UI.Text(f, "label", "", 360)
    f.item:SetPoint("TOPLEFT", 70, -34)
    f.radarText = UI.Text(f, "small", "", 360)
    f.radarText:SetPoint("TOPLEFT", f.item, "BOTTOMLEFT", 0, -4)
    local rateLabel = UI.Text(f, "label", L.RATE_CHANCE)
    rateLabel:SetPoint("TOPLEFT", 24, -92)
    f.rateDrop = UI.Dropdown(f, 160, function()
        local out = {}
        for _, r in ipairs(Ra.RATES) do out[#out + 1] = { r, L["RATE_" .. r:upper()] } end
        return out
    end, function() return f.rate end, function(v) f.rate = v; Ra.UpdateSave() end)
    f.rateDrop:SetPoint("LEFT", rateLabel, "RIGHT", 16, 0)
    local noteLabel = UI.Text(f, "label", L.RATE_NOTE)
    noteLabel:SetPoint("TOPLEFT", 24, -134)
    f.note = UI.Input(f, 370, { maxLetters = Ra.NOTE_MAX })
    f.note:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 4, -2)
    f.save = UI.Button(f, L.RATE_SAVE, 120, function() mod:Call("Einschaetzung", Ra.Save) end, "gold")
    f.save:SetPoint("BOTTOMRIGHT", -14, 14)
    f.cancel = UI.Button(f, CANCEL or L.SET_CANCEL, 120, function() f:Hide() end)
    f.cancel:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
    Ra.win = f
    return f
end

function Ra.UpdateSave()
    local f = Ra.win
    if not f then return end
    if f.rate then f.save:Enable() else f.save:Disable() end
end

-- Fenster fuer einen Gegenstand oeffnen. item = { key oder id, name, link }
function Ra.Open(item)
    if type(item) ~= "table" then return false end
    local key = item.key
    if key == nil then key = item.link and ns.Data.KeyFromLink(item.link) or item.id end
    if key == nil then return false end
    local f = Ra.Build()
    if not f then return false end
    local name = item.name or ns.Data.ItemName(key, ns.Data.Lookup(key)) or tostring(key)
    f.key, f.name = key, name
    local last = Ra.Last(key)
    f.rate = nil
    f.item:SetText(name)
    local snap = Ra.Snapshot(key)
    if snap.radar and not snap.radarGone then f.radarText:SetText("|cff60e060" .. L.RATE_RADAR_YES .. "|r")
    elseif snap.radar then f.radarText:SetText("|cff999999" .. L.RATE_RADAR_GONE .. "|r")
    else f.radarText:SetText("|cff999999" .. L.RATE_RADAR_NO .. "|r") end
    if last then
        f.radarText:SetText(f.radarText:GetText() .. "  |cff999999" .. L.RATE_LAST:format(L["RATE_" .. tostring(last.rate):upper()] or "?") .. "|r")
    end
    f.note:SetText("")
    if f.rateDrop.GenerateMenu then pcall(f.rateDrop.GenerateMenu, f.rateDrop) end
    Ra.UpdateSave()
    f:ClearAllPoints()
    f:SetPoint("CENTER", 0, 80)
    f:Show()
    return true
end

function Ra.Save()
    local f = Ra.win
    if not (f and f.key ~= nil and f.rate) then return end
    Ra.Add(f.key, f.name, f.rate, f.note:GetText())
    mod:Print(L.RATE_SAVED:format(f.name or tostring(f.key), L["RATE_" .. f.rate:upper()] or f.rate))
    f:Hide()
end
