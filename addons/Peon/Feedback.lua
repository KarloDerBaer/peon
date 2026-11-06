-- Peon - Feedback.lua
-- API 9: Module melden ihre Bereiche für Rückmeldungen (Peon_Feedback fragt sie ab).
-- Reine Erweiterung, bestehende Funktionen bleiben unverändert.
--
--   Peon.SetFeedbackAreas(ADDON_NAME, { "Radar", "Verkaufen", ... })
--   Peon.GetFeedbackAreas(ADDON_NAME)  -> Kopie der Liste (leer, wenn nichts gemeldet)
--
-- Schlüssel ist der Addon-Name (z. B. "Peon_Broker"), damit es ohne Modul-Interna geht.
-- Module dürfen jederzeit melden (auch beim Laden der Datei), Peon_Feedback liest erst beim Anzeigen.

local areas = {}

function Peon.SetFeedbackAreas(addon, list)
    if type(addon) ~= "string" or addon == "" or type(list) ~= "table" then return false end
    local t, seen = {}, {}
    for _, a in ipairs(list) do
        if type(a) == "string" and a ~= "" and not seen[a] then
            t[#t + 1] = a
            seen[a] = true
        end
    end
    areas[addon] = t
    return true
end

function Peon.GetFeedbackAreas(addon)
    local t, copy = areas[addon], {}
    if t then for i, a in ipairs(t) do copy[i] = a end end
    return copy
end

-- API 13: Alle gemeldeten Bereiche in PeonDB ablegen, damit sie der Peon Manager lesen kann
function Peon.SaveFeedbackAreas()
    if type(Peon.db) ~= "table" then return end
    local saved = {}
    for addon in pairs(areas) do saved[addon] = Peon.GetFeedbackAreas(addon) end
    Peon.db.feedbackAreas = saved
end

-- Bereiche des Kerns selbst
Peon.SetFeedbackAreas("Peon", (GetLocale() == "deDE")
    and { "Einstellungsseite", "Bausteine", "Liste", "Diagramm", "Minimap-Button", "Debug-Log", "Chatbefehle" }
    or  { "Options page", "Widgets", "List", "Chart", "Minimap button", "Debug log", "Chat commands" })
