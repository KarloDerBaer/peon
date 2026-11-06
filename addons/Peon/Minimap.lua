-- Peon - Minimap.lua
-- Minimap-Button fuer Module (ab API 7). Aufbau wie der bewaehrte Button von Peon_Fishing:
-- rund am Rand der Minimap, mit der linken Maustaste verschiebbar, Position im Modul gespeichert.
--
--   defaults = { minimapAngle = 200, minimapShow = true, ... },
--   ranges   = { minimapAngle = { 0, 359, 1 } },
--
--   local btn = mod:NewMinimapButton({
--       icon      = "Interface\\Icons\\INV_Misc_Coin_02",   -- Pfad oder Datei-ID
--       name      = "PeonBrokerMinimapButton",              -- globaler Name (optional)
--       angleKey  = "minimapAngle",                         -- Standard
--       showKey   = "minimapShow",                          -- Standard; nil-Wert = anzeigen
--       onClick   = function(mod, button) end,              -- "LeftButton" / "RightButton"
--       onTooltip = function(mod, tooltip) tooltip:AddLine("...") end,
--       hint      = "Linksklick: ...",                      -- letzte Tooltip-Zeile (optional)
--       texts, defaultText, menu, update                    -- ab API 14: fuer den Starter, siehe Launcher.lua
--   })
--   btn:Update()   -- Position und Sichtbarkeit neu setzen (passiert auch bei CHANGED und RESET)

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L
local Module = Peon.ModulePrototype

function Module:NewMinimapButton(o)
    o = o or {}
    if self.minimapButton then return self.minimapButton end
    local mod = self
    local angleKey = o.angleKey or "minimapAngle"
    local showKey = o.showKey or "minimapShow"

    local btn = CreateFrame("Button", o.name, Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(o.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetPoint("TOPLEFT", 7, -6)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local function Angle()
        local a = mod.db and tonumber(mod.db[angleKey])
        return a or 200
    end

    function btn:UpdatePosition()
        local rad = math.rad(Angle())
        local r = (Minimap:GetWidth() / 2) + 10
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
    end

    function btn:Update()
        self:UpdatePosition()
        local show = not mod.db or mod.db[showKey] ~= false
        if show then self:Show() else self:Hide() end
    end

    local function ShowTooltip()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:AddLine(("|c%sPeon|r %s"):format(Peon.COLOR, mod.title))
        if o.onTooltip then mod:Call("Minimap", o.onTooltip, mod, GameTooltip) end
        if o.hint then GameTooltip:AddLine(o.hint, 0.6, 0.6, 0.6, true) end
        GameTooltip:AddLine(L.MINIMAP_DRAG, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end
    btn.ShowTooltip = ShowTooltip

    -- Ziehen: Winkel zwischen Minimap-Mitte und Mauszeiger
    local function OnDragUpdate()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        if not mx or not cx or not scale or scale == 0 then return end
        cx, cy = cx / scale, cy / scale
        if mod.db then mod.db[angleKey] = math.floor(math.deg(math.atan2(cy - my, cx - mx)) % 360) end
        btn:UpdatePosition()
    end

    btn:SetScript("OnClick", function(_, button)
        if GameTooltip then GameTooltip:Hide() end
        if o.onClick then mod:Call("Minimap", o.onClick, mod, button) end
    end)
    btn:SetScript("OnDragStart", function(b) b:SetScript("OnUpdate", OnDragUpdate) end)
    btn:SetScript("OnDragStop", function(b) b:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    self:On("CHANGED", function() btn:Update() end)
    self:On("RESET", function() btn:Update() end)

    self.minimapButton = btn
    btn:Update()
    -- Starter fuer Anzeigen wie Peon_Panel (ab API 14)
    self:NewLauncher({
        icon = o.icon, title = o.title, key = o.key, showKey = showKey, onClick = o.onClick, onTooltip = o.onTooltip,
        hint = o.hint, update = o.update, menu = o.menu, texts = o.texts, defaultText = o.defaultText,
    })
    return btn
end
