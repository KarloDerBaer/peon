-- Peon_Beispiel - Locales.lua
-- Allgemeine Texte (Fehler, Standardwerte, Positionen) liefert der Peon-Kern (Peon.L)
local ADDON_NAME, ns = ...

local L = Peon.NewLocale()
ns.L = L

-- enUS (Standard)
L.DESC       = "Template module. Changes apply immediately."
L.HDR_MAIN   = "General"
L.ENABLED    = "Enabled"
L.SIZE       = "Size"
L.SIZE_HINT  = "Just an example value."
L.MODE       = "Mode"
L.MODE_A     = "A"
L.MODE_B     = "B"
L.SLASH_HINT = "Chat: /peon beispiel opens this panel."

if GetLocale() == "deDE" then
    L.DESC       = "Vorlage für ein Modul. Änderungen wirken sofort."
    L.HDR_MAIN   = "Allgemein"
    L.ENABLED    = "Eingeschaltet"
    L.SIZE       = "Größe"
    L.SIZE_HINT  = "Nur ein Beispielwert."
    L.MODE       = "Modus"
    L.SLASH_HINT = "Chat: /peon beispiel öffnet dieses Menü."
end
