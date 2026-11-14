-- Peon_Profession - CraftBar.lua
-- Schmale Leiste ueber dem Berufsfenster (Konzept Abschnitt 4, abschaltbar mit craftBar): naechstes Rezept des Guides
-- mit Anzahl, Knopf "Auswaehlen" (waehlt das Rezept im Berufsfenster) und Knopf "Guide" (oeffnet das Fenster).
-- Haengt ausserhalb des Berufsfensters, Blizzards Inhalt und Brokers Block bleiben unberuehrt.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod

local B = {}
B.TITLE_W, B.TITLE_H = 120, 20
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

-- Ab 0.2.0 (Wunsch KarloDerBaer): Knopf in der Titelleiste des Berufsfensters, oeffnet das Fenster.
-- Ab 0.2.1: roter Knopf mit Text "Peon Profession" rechts in der Leiste, links neben dem Schliessen-Knopf.
function B.UpdateTitleButton(host)
    local btn = B.title
    if not host or not mod.db.titleButton then if btn then btn:Hide() end return end
    if not btn then
        local U = Peon.UI
        btn = (U and U.TryFrame("Button", "PeonProfessionTitleButton", host, "UIPanelButtonTemplate"))
            or CreateFrame("Button", "PeonProfessionTitleButton", host, "UIPanelButtonTemplate")
        btn:SetSize(B.TITLE_W, B.TITLE_H)
        btn:SetText(L.TITLE_BTN_TEXT)
        btn:SetScript("OnClick", function() ns.Window.Toggle(B.key) end)
        btn:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(L.TITLE_BTN, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        B.title = btn
    end
    if btn.GetParent and btn:GetParent() ~= host then btn:SetParent(host) end
    -- ueber Titel und Rahmen (Ebenen siehe Peon_Ueberblick.md: Titel 510, eigene Knoepfe 520)
    if btn.SetFrameLevel and host.GetFrameLevel then btn:SetFrameLevel((host:GetFrameLevel() or 0) + 520) end
    btn:ClearAllPoints()
    local close = rawget(host, "CloseButton")
    if type(close) == "table" then
        btn:SetPoint("RIGHT", close, "LEFT", -2, 0)
    else
        btn:SetPoint("TOPRIGHT", host, "TOPRIGHT", -30, -2)
    end
    btn:Show()
end

function B.Update()
    local host = Host()
    if host then
        B.key = ns.Measure.OpenProfession() or B.key
        B.UpdateTitleButton(host)
    end
    if not mod.db.craftBar then if B.frame then B.frame:Hide() end return end
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
