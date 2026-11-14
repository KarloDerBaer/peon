-- Peon_Profession - CraftBar.lua
-- Schmale Leiste ueber dem Berufsfenster (Konzept Abschnitt 4, abschaltbar mit craftBar): naechstes Rezept des Guides
-- mit Anzahl, Knopf "Auswaehlen" (waehlt das Rezept im Berufsfenster) und Knopf "Guide" (oeffnet das Fenster).
-- Haengt ausserhalb des Berufsfensters, Blizzards Inhalt und Brokers Block bleiben unberuehrt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local B = {}
ns.CraftBar = B

local function Host()
    for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
        local f = rawget(_G, name)
        if type(f) == "table" and f.IsShown and f:IsShown() then return f end
    end
    return nil
end

function B.Create(host)
    if B.frame then
        if B.host ~= host then
            B.frame:SetParent(host)
            B.frame:ClearAllPoints()
            B.frame:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 2)
            B.frame:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 2)
            B.host = host
        end
        return B.frame
    end
    local U = Peon.UI
    local f = (U and U.TryFrame("Frame", "PeonProfessionCraftBar", host, "InsetFrameTemplate")) or CreateFrame("Frame", "PeonProfessionCraftBar", host)
    f:SetHeight(28)
    f:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 2)
    f:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 2)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(20, 20)
    f.icon:SetPoint("LEFT", 6, 0)
    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.text:SetJustifyH("LEFT")
    local function Btn(text, width, fn)
        local b = (U and U.Button(f, text, width, fn)) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        if not U then b:SetSize(width, 22); b:SetText(text); b:SetScript("OnClick", fn) end
        return b
    end
    f.guide = Btn(L.BAR_WINDOW, 70, function() ns.Window.Open(B.key) end)
    f.guide:SetPoint("RIGHT", -4, 0)
    f.select = Btn(L.BAR_SELECT, 90, function() mod:Call("Berufsfenster", B.Select) end)
    f.select:SetPoint("RIGHT", f.guide, "LEFT", -4, 0)
    f.text:SetPoint("RIGHT", f.select, "LEFT", -6, 0)
    if f.text.SetWordWrap then f.text:SetWordWrap(false) end
    B.frame, B.host = f, host
    return f
end

-- Rezept im offenen Berufsfenster auswaehlen (C_TradeSkillUI.OpenRecipe, wie ein Klick auf einen Rezeptlink)
function B.Select()
    local id = B.recipeID
    local ts = rawget(_G, "C_TradeSkillUI")
    if not id or not (ts and ts.OpenRecipe) then return false end
    return pcall(ts.OpenRecipe, id)
end

function B.Update()
    if not mod.db.craftBar then if B.frame then B.frame:Hide() end return end
    local host = Host()
    if not host then if B.frame then B.frame:Hide() end return end
    local key, skill = ns.Measure.OpenProfession()
    if not key or not skill or not ns.Guide.Route(key) then if B.frame then B.frame:Hide() end return end
    local step, i = ns.Guide.StepAt(key, skill)
    local v = step and ns.Guide.View(key, step, skill, i)
    if not v then if B.frame then B.frame:Hide() end return end
    local f = B.Create(host)
    B.key = key
    if v.gather then
        local names = {}
        for _, id in ipairs(v.gather) do names[#names + 1] = ns.ItemName(id) or ("#" .. id) end
        f.icon:SetTexture(v.gather[1] and ns.ItemIcon(v.gather[1]) or ns.PROFS[key].icon)
        f.text:SetText(L.BAR_GATHER:format(table.concat(names, ", "), v.to))
        B.recipeID = nil
    else
        local _, recipeID, item = ns.Guide.Active(v)
        local spell = v.alt and v.alt.id or v.spell
        local name = ns.Guide.RecipeName(item, spell, v.alt and v.alt.rec or v.rec)
        if not (v.item or v.spell or v.alt) then name = L.FREE_STEP end
        f.icon:SetTexture(ns.Guide.RecipeIcon(item, spell))
        f.text:SetText(L.BAR_TEXT:format(v.count or 0, name, v.to))
        -- nur erlernte Rezepte lassen sich auswaehlen
        B.recipeID = (v.alt and v.alt.id) or v.recipeID
    end
    f.select:SetEnabled(B.recipeID ~= nil)
    f:Show()
end

function B.Init()
    pcall(mod.RegisterEvent, mod, "TRADE_SKILL_CLOSE", function() if B.frame then B.frame:Hide() end end)
    mod:On("CHANGED", function() B.Update() end)
end
