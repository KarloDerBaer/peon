-- Peon_Profession - Locales.lua
-- Allgemeine Texte (Fehler, Standardwerte) liefert der Peon-Kern (Peon.L)
local ADDON_NAME, ns = ...

local L = Peon.NewLocale()
ns.L = L

-- enUS (Standard)
L.TITLE          = "Professions"
L.DESC           = "Guide for leveling professions, with prices and shopping list from Peon Broker. Changes apply immediately."
L.HDR_MAIN       = "General"
L.MINIMAP        = "Show minimap button"
L.CRAFT_BAR      = "Guide bar on the profession window"
L.CRAFT_BAR_HINT = "A small bar above the profession window shows the next recipe of the guide."
L.OPEN           = "Open window"
L.SLASH_HINT     = "Chat: /prof opens the window, /prof optionen this page, /prof messungen compares measurements with the routes."
L.TOO_OLD        = "Peon is too old. Peon_Profession needs Peon 0.18 or newer."
L.MSG_COMBAT     = "Not during combat."

L.PROFS          = "Professions"
L.NO_PROFS       = "No profession learned yet."
L.NO_ROUTE       = "No route for this profession."
L.NOW            = "Now"
L.NEXT           = "Next steps up to %d"
L.DONE           = "Done: %s is at its maximum of %d."
L.DONE_ALL       = "Done: %s is at %d."
L.SKILL          = "%s  %d / %d"
L.CRAFT_N        = "about %dx, up to %d"
L.CRAFT_RANGE    = "%d-%d"
L.COLOR_LINE     = "%s (profession window)"
L.COLOR = { [0] = "|cffff8040orange|r", [1] = "|cffffff00yellow|r", [2] = "|cff40c040green|r", [3] = "|cff999999grey|r" }
L.NOT_LEARNED    = "|cff999999Not learned yet%s|r"
L.LEARN_AT       = ", trainer from %d"
L.LEARN_SRC      = { t = ", trainer from %d", v = ", vendor from %d", d = ", drop from %d", q = ", quest from %d", m = ", from %d" }
L.FREE_STEP      = "Any orange recipe from the profession window."
L.ALT            = "Instead: |cffffd100%s|r (%s). %s is already %s for you."
L.ALT_FREE       = "Suggestion: |cffffd100%s|r (%s)."
L.GATHER         = "Gather: %s"
L.ZONES          = "Zones: %s"
L.NO_ZONES       = "Zones: anywhere with suitable level"
L.TRAINER        = "Learn %s at the trainer (character level %d)."
L.TRAINER_BOOK   = "Learn %s from a book (vendor or quest), not at the trainer."
L.TRAINER_ROW    = "At %d: learn %s"
L.RANKS          = { [75] = "Journeyman", [150] = "Expert", [225] = "Artisan" }
L.RANK_LEVEL     = { [75] = 10, [150] = 20, [225] = 35 }

L.COL_MAT        = "Material"
L.COL_PER        = "Each"
L.COL_TOTAL      = "Total"
L.COL_HAVE       = "Stock"
L.COL_MISSING    = "Missing"
L.COL_UNIT       = "Price"
L.COL_COST       = "Cost"
L.COL_RANGE      = "Skill"
L.COL_RECIPE     = "Recipe"
L.COL_COUNT      = "Crafts"
L.VENDOR         = "Vendor"
L.NO_MATS        = "Materials appear after opening the profession window."
L.COST_NOW       = "Cost now: %s"
L.COST_ALL       = "Up to %d: about %s"
L.COST_PART      = " (%d without price)"
L.PRICES_BROKER  = "Prices: Broker"
L.PRICES_NONE    = "Prices: install Peon Broker for prices and shopping list"
L.HAVE_TIP       = "Bags and bank: %d, other characters: %d"

L.TO_LIST_STEP   = "To shopping list: step"
L.TO_LIST_MAX    = "To shopping list: up to %d"
L.LIST_NAME      = "Profession: %s"
L.LIST_ADDED     = "%d materials on list \"%s\"."
L.LIST_NOTHING   = "Nothing missing for this."
L.LIST_NO_BROKER = "Shopping list needs Peon Broker 0.94 or newer."

L.BAR_TEXT       = "Guide: %dx %s (up to %d)"
L.BAR_GATHER     = "Guide: gather %s (up to %d)"
L.BAR_SELECT     = "Select"
L.BAR_WINDOW     = "Guide"

L.MEASURE_HDR    = "Measurements compared with the routes:"
L.MEASURE_LINE   = "%s %d-%d %s: %s measured at %d"
L.MEASURE_UP     = "%s %s: skill gained %d-%d"
L.MEASURE_NONE   = "No differences found yet."

L.LAUNCH_SKILL   = "Profession and skill"
L.MM_HINT        = "Left click: window, right click: options"

L.AREAS          = { "Guide", "Gathering", "Prices and shopping list", "Profession window", "Options" }

if GetLocale() == "deDE" then
    L.TITLE          = "Berufe"
    L.DESC           = "Guide zum Leveln der Berufe, mit Preisen und Einkaufsliste von Peon Broker. Änderungen wirken sofort."
    L.HDR_MAIN       = "Allgemein"
    L.MINIMAP        = "Minimap-Button zeigen"
    L.CRAFT_BAR      = "Guide-Leiste am Berufsfenster"
    L.CRAFT_BAR_HINT = "Eine schmale Leiste über dem Berufsfenster zeigt das nächste Rezept des Guides."
    L.OPEN           = "Fenster öffnen"
    L.SLASH_HINT     = "Chat: /prof öffnet das Fenster, /prof optionen diese Seite, /prof messungen vergleicht Messungen mit den Routen."
    L.TOO_OLD        = "Peon ist zu alt. Peon_Profession braucht Peon 0.18 oder neuer."
    L.MSG_COMBAT     = "Nicht im Kampf."

    L.PROFS          = "Berufe"
    L.NO_PROFS       = "Noch kein Beruf erlernt."
    L.NO_ROUTE       = "Für diesen Beruf gibt es keine Route."
    L.NOW            = "Jetzt"
    L.NEXT           = "Weiter bis %d"
    L.DONE           = "Fertig: %s steht auf dem Höchstwert %d."
    L.DONE_ALL       = "Fertig: %s steht auf %d."
    L.SKILL          = "%s  %d / %d"
    L.CRAFT_N        = "ca. %dx, bis %d"
    L.CRAFT_RANGE    = "%d-%d"
    L.COLOR_LINE     = "%s (laut Berufsfenster)"
    L.COLOR = { [0] = "|cffff8040orange|r", [1] = "|cffffff00gelb|r", [2] = "|cff40c040grün|r", [3] = "|cff999999grau|r" }
    L.NOT_LEARNED    = "|cff999999Noch nicht erlernt%s|r"
    L.LEARN_AT       = ", beim Lehrer ab %d"
    L.LEARN_SRC      = { t = ", beim Lehrer ab %d", v = ", beim Händler, ab %d", d = ", als Beute, ab %d", q = ", aus einer Quest, ab %d", m = ", ab %d" }
    L.FREE_STEP      = "Ein beliebiges oranges Rezept aus dem Berufsfenster."
    L.ALT            = "Stattdessen: |cffffd100%s|r (%s). %s ist bei dir schon %s."
    L.ALT_FREE       = "Vorschlag: |cffffd100%s|r (%s)."
    L.GATHER         = "Sammeln: %s"
    L.ZONES          = "Gebiete: %s"
    L.NO_ZONES       = "Gebiete: überall mit passender Stufe"
    L.TRAINER        = "%s beim Lehrer lernen (ab Charakterstufe %d)."
    L.TRAINER_BOOK   = "%s gibt es als Buch (Händler oder Quest), nicht beim Lehrer."
    L.TRAINER_ROW    = "Bei %d: %s lernen"
    L.RANKS          = { [75] = "Geselle", [150] = "Experte", [225] = "Fachmann" }

    L.COL_MAT        = "Material"
    L.COL_PER        = "Je"
    L.COL_TOTAL      = "Gesamt"
    L.COL_HAVE       = "Vorrat"
    L.COL_MISSING    = "Fehlt"
    L.COL_UNIT       = "Preis"
    L.COL_COST       = "Kosten"
    L.COL_RANGE      = "Stufe"
    L.COL_RECIPE     = "Rezept"
    L.COL_COUNT      = "Anzahl"
    L.VENDOR         = "Händler"
    L.NO_MATS        = "Das Material erscheint, sobald das Berufsfenster einmal offen war."
    L.COST_NOW       = "Kosten jetzt: %s"
    L.COST_ALL       = "Bis %d: ca. %s"
    L.COST_PART      = " (%d ohne Preis)"
    L.PRICES_BROKER  = "Preise: Broker"
    L.PRICES_NONE    = "Preise: Peon Broker installieren für Preise und Einkaufsliste"
    L.HAVE_TIP       = "Taschen und Bank: %d, andere Charaktere: %d"

    L.TO_LIST_STEP   = "Auf Einkaufsliste: Schritt"
    L.TO_LIST_MAX    = "Auf Einkaufsliste: bis %d"
    L.LIST_NAME      = "Beruf: %s"
    L.LIST_ADDED     = "%d Materialien auf der Liste „%s“."
    L.LIST_NOTHING   = "Dafür fehlt nichts."
    L.LIST_NO_BROKER = "Die Einkaufsliste braucht Peon Broker 0.94 oder neuer."

    L.BAR_TEXT       = "Guide: %dx %s (bis %d)"
    L.BAR_GATHER     = "Guide: %s sammeln (bis %d)"
    L.BAR_SELECT     = "Auswählen"
    L.BAR_WINDOW     = "Guide"

    L.MEASURE_HDR    = "Messungen im Vergleich mit den Routen:"
    L.MEASURE_LINE   = "%s %d-%d %s: %s gemessen bei %d"
    L.MEASURE_UP     = "%s %s: Punkte bekommen %d-%d"
    L.MEASURE_NONE   = "Noch keine Abweichungen gefunden."

    L.LAUNCH_SKILL   = "Beruf und Stufe"
    L.MM_HINT        = "Linksklick: Fenster, Rechtsklick: Optionen"

    L.AREAS          = { "Guide", "Sammelberufe", "Preise und Einkaufsliste", "Berufsfenster", "Optionen" }
end
