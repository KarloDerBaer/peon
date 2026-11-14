-- Peon_Profession - Profession.lua
-- Berufe: Guide zum Leveln mit Preisen und Einkaufsliste von Peon Broker (Konzept
-- docs/konzepte/profession/Peon_Profession_Konzept.md). Anmeldung beim Kern, Einstellungen, Berufe des Charakters.
--
-- Schnittstelle fuer andere Module (nur lesend):
--   mod:Professions()      -> { { key, name, icon, skill, max } } Berufe des eingeloggten Charakters
--   mod:Step(key, skill)   -> Schritt der Route fuer diese Stufe (Tabelle aus Routes.lua) oder nil
--   mod:CraftTooltip(id)   -> Text Material und Gewinn fuer ein erlerntes Rezept (ab 0.2.0, fuer Brokers Tooltip)

local ADDON_NAME, ns = ...
local L = ns.L

-- Symbol (ab 0.2.2): Hammer und Spitzhacke wie Blizzards Reiter Uebersicht am Berufsfenster in Forever (Datei-Nummer)
ns.ICON = 8197101

-- Einstellungen des Berufsfensters, die bis Broker 0.94 dort lagen (Uebernahme in migrate)
ns.CRAFT_KEYS = { "craftList", "craftListWhich", "craftListMode", "craftListBest", "craftListLoss", "craftListUnknown",
    "craftBlock", "craftSummary", "craftColSrc", "craftColCost", "craftColSell", "craftHint" }

local mod = Peon:NewModule(ADDON_NAME, {
    key      = "profession",
    title    = "Profession",
    db       = "PeonProfessionDB",
    charDB   = "PeonProfessionCharDB",
    charKeys = { sel = true, known = true, skills = true, target = true },
    defaults = {
        minimapShow  = true,
        minimapAngle = 215,
        windowPos    = {},
        windowTab    = "guide",  -- ab 0.2.0: guide, route, mats
        showAll      = false,    -- ab 0.2.0: auch nicht gelernte Berufe in der Liste
        craftBar     = true,
        titleButton  = true,     -- ab 0.2.0: Knopf in der Titelleiste des Berufsfensters
        colors       = {},   -- [recipeID] = { [0..3] = { von, bis } }  gemessene Farben (Measure.lua)
        ups          = {},   -- [recipeID] = { von, bis }               Stufen, bei denen dieses Rezept Punkte gab
        sel          = 0,    -- je Charakter: zuletzt gewaehlter Beruf (Skill-Linie)
        known        = {},   -- je Charakter: [Beruf] = { [recipeID] = { out, n, m = { id, q, ... }, c } }
        skills       = {},   -- je Charakter: [Beruf] = letzte bekannte Stufe (Messung der Punkte)
        target       = {},   -- je Charakter (ab 0.2.0): [Beruf] = Zielstufe
        -- Berufsfenster (ab 0.2.0, vorher Peon_Broker ab 0.39): Gewinn in der Rezeptliste, Block unter den Reagenzien
        craftGuideMark = true,   -- Rezept des Guides mit gruenem Pfeil
        craftList    = true,     -- Gewinn rechts in der Rezeptliste
        craftListWhich = "all",  -- welche Rezepte: all, profit, top3, top5, top10
        craftListMode = "money", -- Betrag oder Prozent vom Material (pct)
        craftListBest = true,    -- bestes Rezept mit Goldmuenze
        craftListLoss = true,    -- Verluste zeigen (nur bei "all")
        craftListUnknown = true, -- Rezepte ohne Preis mit "?" (nur bei "all")
        craftBlock   = true,     -- Block unter den Reagenzien
        craftSummary = true,     -- Ergebniszeile Kosten, Ertrag, Gewinn
        craftColSrc  = true,     -- Spalte Quelle (Vorrat, Haendler, AH)
        craftColCost = true,     -- Spalte Kosten (Ledger oder Kaufpreis)
        craftColSell = true,     -- Spalte Erloes (Vorrat im AH verkauft, nach Gebuehr)
        craftHint    = true,     -- Hinweis: verkaufen oder herstellen
        craftTwinks  = false,    -- Vorrat der Twinks mitzaehlen (vorher Brokers keepAllChars)
        craftMigrated = false,   -- Einstellungen einmal von Broker uebernommen
    },
    ranges   = { minimapAngle = { 0, 359, 1 } },
    choices  = { windowTab = { guide = true, route = true, mats = true },
                 craftListWhich = { all = true, profit = true, top3 = true, top5 = true, top10 = true },
                 craftListMode = { money = true, pct = true } },
    -- Einstellungen des Berufsfensters einmal aus Peon_Broker uebernehmen (bis Broker 0.94 dort)
    migrate  = function(m, acc)
        if acc.craftMigrated == true then return end
        local b = rawget(_G, "PeonBrokerDB")
        if type(b) == "table" then
            for _, k in ipairs(ns.CRAFT_KEYS) do
                if acc[k] == nil and b[k] ~= nil then acc[k] = b[k] end
            end
            if acc.craftTwinks == nil and type(b.keepAllChars) == "boolean" then acc.craftTwinks = b.keepAllChars end
        end
        acc.craftMigrated = true
    end,
    keepOnReset = { windowPos = true, colors = true, ups = true, sel = true, known = true, skills = true, target = true,
                    craftMigrated = true },
    slash    = { "/prof" },
    onSlash  = function(m, cmd, rest)
        cmd = (cmd or ""):lower()
        if cmd == "optionen" or cmd == "options" or cmd == "config" then
            m:OpenOptions()
        elseif cmd == "messungen" or cmd == "measure" then
            ns.Measure.Report()
        elseif cmd == "pruefen" or cmd == "check" then
            ns.Craft.Probe()
        else
            ns.Window.Toggle()
        end
    end,
})
ns.mod = mod

-- Berufe: Skill-Linie des Spiels -> Art, Symbol, Namen (Rueckfall, falls das Spiel keinen Namen liefert)
ns.PROFS = {
    [171] = { craft = true,  icon = "Interface\\Icons\\Trade_Alchemy",               de = "Alchimie",          en = "Alchemy" },
    [164] = { craft = true,  icon = "Interface\\Icons\\Trade_BlackSmithing",         de = "Schmiedekunst",     en = "Blacksmithing" },
    [333] = { craft = true,  icon = "Interface\\Icons\\Trade_Engraving",             de = "Verzauberkunst",    en = "Enchanting" },
    [202] = { craft = true,  icon = "Interface\\Icons\\Trade_Engineering",           de = "Ingenieurskunst",   en = "Engineering" },
    [165] = { craft = true,  icon = "Interface\\Icons\\Trade_LeatherWorking",        de = "Lederverarbeitung", en = "Leatherworking" },
    [197] = { craft = true,  icon = "Interface\\Icons\\Trade_Tailoring",             de = "Schneiderei",       en = "Tailoring", alias = { "Schneidern" } },
    [185] = { craft = true,  icon = "Interface\\Icons\\INV_Misc_Food_15",            de = "Kochkunst",         en = "Cooking", book = 150 },
    [129] = { craft = true,  icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",  de = "Erste Hilfe",       en = "First Aid", book = 150 },
    [186] = { gather = true, icon = "Interface\\Icons\\Trade_Mining",                de = "Bergbau",           en = "Mining" },
    [182] = { gather = true, icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow", de = "Kräuterkunde",     en = "Herbalism" },
    [393] = { gather = true, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",       de = "Kürschnerei",       en = "Skinning" },
    [356] = { gather = true, icon = "Interface\\Icons\\Trade_Fishing",               de = "Angeln",            en = "Fishing", book = 150 },
}
ns.ORDER = { 171, 164, 333, 202, 165, 197, 185, 129, 186, 182, 393, 356 }

local byName
function ns.KeyForName(name)
    if type(name) ~= "string" then return nil end
    if not byName then
        byName = {}
        for key, p in pairs(ns.PROFS) do
            byName[p.de:lower()] = key
            byName[p.en:lower()] = key
            for _, a in ipairs(p.alias or {}) do byName[a:lower()] = key end
        end
    end
    return byName[name:lower()]
end

function ns.ProfName(key)
    local p = ns.PROFS[key]
    if not p then return "?" end
    local cur = ns.current and ns.current[key]
    if cur and cur.name then return cur.name end
    return (GetLocale() == "deDE") and p.de or p.en
end

-- Berufe des eingeloggten Charakters (GetProfessions: Haupt- und Nebenberufe, Angeln, Kochen, Erste Hilfe)
function ns.ReadProfessions()
    local out, map = {}, {}
    local GP, GI = rawget(_G, "GetProfessions"), rawget(_G, "GetProfessionInfo")
    if type(GP) == "function" and type(GI) == "function" then
        local idx = { GP() }
        for i = 1, select("#", GP()) do
            local id = idx[i]
            if id then
                local ok, name, icon, skill, max, _, _, line = pcall(GI, id)
                if ok and name then
                    local key = (ns.PROFS[line] and line) or ns.KeyForName(name)
                    if key and not map[key] and type(skill) == "number" and not Peon.IsSecret(skill) then
                        local e = { key = key, name = name, icon = icon or ns.PROFS[key].icon, skill = skill, max = tonumber(max) or skill }
                        out[#out + 1] = e
                        map[key] = e
                    end
                end
            end
        end
    end
    local order = {}
    for i, k in ipairs(ns.ORDER) do order[k] = i end
    table.sort(out, function(a, b) return (order[a.key] or 99) < (order[b.key] or 99) end)
    ns.current = map
    return out
end

function mod:Professions() return ns.ReadProfessions() end
function mod:Step(key, skill) return ns.Guide and ns.Guide.StepAt(key, skill) end
-- Ab 0.2.0 (fuer den Tooltip von Peon_Broker): "Material 1g 20s · Gewinn +35s" fuer ein erlerntes Rezept, sonst nil
function mod:CraftTooltip(itemID) return ns.Craft and ns.Craft.TooltipText(itemID) end

-- Geld: "1g 20s 5c" (mit Muenzbildern, wenn das Spiel sie kennt)
function ns.Money(c)
    if type(c) ~= "number" then return "" end
    c = math.floor(c + 0.5)
    if type(GetCoinTextureString) == "function" then
        local ok, s = pcall(GetCoinTextureString, c)
        if ok and type(s) == "string" then return s end
    end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local t = {}
    if g > 0 then t[#t + 1] = string.format("%.0fg", g) end
    if s > 0 then t[#t + 1] = s .. "s" end
    if k > 0 or #t == 0 then t[#t + 1] = k .. "c" end
    return table.concat(t, " ")
end

-- Namen und Symbole vom Spiel (Gegenstand oder Zauber)
function ns.ItemName(id)
    if type(id) ~= "number" then return nil end
    local CI = rawget(_G, "C_Item")
    if CI and CI.GetItemInfo then
        local ok, name, _, q = pcall(CI.GetItemInfo, id)
        if ok and type(name) == "string" then return name, q end
        if CI.RequestLoadItemDataByID then pcall(CI.RequestLoadItemDataByID, id) end
    end
    return nil
end

function ns.ItemIcon(id)
    local CI = rawget(_G, "C_Item")
    if CI and CI.GetItemIconByID then
        local ok, ic = pcall(CI.GetItemIconByID, id)
        if ok and ic then return ic end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.SpellName(id)
    local CS = rawget(_G, "C_Spell")
    if CS and CS.GetSpellName then
        local ok, n = pcall(CS.GetSpellName, id)
        if ok and type(n) == "string" then return n end
    end
    local GSI = rawget(_G, "GetSpellInfo")
    if type(GSI) == "function" then
        local ok, n = pcall(GSI, id)
        if ok and type(n) == "string" then return n end
    end
    return nil
end

function ns.SpellIcon(id)
    local CS = rawget(_G, "C_Spell")
    if CS and CS.GetSpellTexture then
        local ok, ic = pcall(CS.GetSpellTexture, id)
        if ok and ic then return ic end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

mod:On("INIT", function()
    if not Peon.UI or (tonumber(Peon.API) or 0) < 18 then mod:Print(L.TOO_OLD) end
    if ns.CreateOptions then mod:Call("Optionen", ns.CreateOptions) end
end)

mod:On("LOGIN", function()
    if ns.Measure then mod:Call("Messung", ns.Measure.Init) end
    if ns.CraftBar then mod:Call("Berufsfenster", ns.CraftBar.Init) end
    if ns.Craft then mod:Call("Berufsfenster Kosten", ns.Craft.Init) end
    if mod.NewMinimapButton then
        mod:Call("Minimap", mod.NewMinimapButton, mod, {
            icon = ns.ICON,
            name = "PeonProfessionMinimapButton",
            hint = L.MM_HINT,
            onClick = function(m, button)
                if button == "RightButton" then m:OpenOptions() else ns.Window.Toggle() end
            end,
            onTooltip = function(m, tt)
                for _, p in ipairs(ns.ReadProfessions()) do
                    tt:AddDoubleLine(p.name, p.skill .. " / " .. p.max, 1, 1, 1, 1, 0.82, 0)
                end
            end,
            texts = { { key = "skill", label = L.LAUNCH_SKILL, get = function() return ns.LauncherText() end } },
            defaultText = "skill",
        })
    end
end)

-- Leiste von Peon_Panel neu zeichnen (gewaehlter Beruf oder Stufe geaendert)
function ns.RefreshLauncher()
    if mod.launcher and mod.launcher.Refresh then mod:Call("Starter", mod.launcher.Refresh, mod.launcher) end
end

-- Text fuer Peon_Panel: der verfolgte Beruf (zuletzt im Fenster gewaehlt, ab 0.2.2 auch der dort gezeigte),
-- sonst der erste, der noch nicht fertig ist
function ns.LauncherText()
    local list = ns.ReadProfessions()
    local pick
    for _, p in ipairs(list) do if p.key == mod.db.sel then pick = p end end
    if not pick then for _, p in ipairs(list) do if not pick and p.skill < p.max then pick = p end end end
    pick = pick or list[1]
    if not pick then return "" end
    return ("%s %d/%d"):format(pick.name, pick.skill, pick.max)
end

if Peon.SetFeedbackAreas then Peon.SetFeedbackAreas(ADDON_NAME, L.AREAS) end
