-- Peon - Slash.lua
-- /peon             Optionen
-- /peon list        installierte Module
-- /peon debug <m>   Debug-Ausgaben eines Moduls an/aus
-- /peon <m> [...]   Befehl an ein Modul weiterreichen

local ADDON_NAME, ns = ...
local Peon = ns.Peon
local L = ns.L

SLASH_PEON1 = "/peon"
SlashCmdList.PEON = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "" or cmd == "optionen" or cmd == "options" then
        Peon:OpenOptions()
    elseif cmd == "list" or cmd == "liste" or cmd == "module" or cmd == "modules" then
        local lines = ns.ModuleLines()
        if #lines == 0 then
            Peon.Print(L.MSG_NO_MODULES)
        else
            Peon.Print(L.MSG_MODULES)
            for _, line in ipairs(lines) do print("   " .. line) end
        end
    elseif cmd == "debug" then
        local mod = Peon:GetModule(rest:match("^(%S+)") or "")
        if mod then
            mod:ToggleDebug()
        else
            Peon.Print(L.MSG_UNKNOWN_MODULE:format(rest))
        end
    elseif cmd == "help" or cmd == "hilfe" or cmd == "?" then
        for _, line in ipairs(L.HELP) do Peon.Print(line) end
    else
        local mod = Peon:GetModule(cmd)
        if mod then
            mod:HandleSlash(rest)
        else
            Peon.Print(L.MSG_UNKNOWN_MODULE:format(cmd))
            for _, line in ipairs(L.HELP) do Peon.Print(line) end
        end
    end
end
