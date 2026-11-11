-- Peon - Slash.lua
-- /peon             Optionen
-- /peon list        installierte Module
-- /peon debug <m>   Debug-Ausgaben eines Moduls an/aus
-- /peon fehler      gespeicherte Fehler zeigen, mit "leeren" loeschen
-- /peon ui pruefen  Grafiken von Blizzards Fenstern auslesen (ab 0.18.0, UIProbe.lua)
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
    elseif cmd == "fehler" or cmd == "errors" then
        local sub = rest:lower()
        if sub == "leeren" or sub == "clear" then
            Peon.Print(L.MSG_ERRORS_CLEARED:format(Peon.ClearErrors()))
            return
        end
        local list = Peon.db and Peon.db.errors
        if type(list) ~= "table" or #list == 0 then
            Peon.Print(L.MSG_ERRORS_NONE)
            return
        end
        Peon.Print(L.MSG_ERRORS_HEAD:format(#list))
        for i = #list, math.max(1, #list - 19), -1 do
            local e = list[i]
            print(("   %s %s %s (%dx): %s"):format(date("%d.%m. %H:%M", e.last or 0), tostring(e.addon), tostring(e.where), e.n or 1, tostring(e.msg)))
        end
    elseif cmd == "ui" and ns.UIProbe then
        ns.UIProbe.Slash(rest)
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
