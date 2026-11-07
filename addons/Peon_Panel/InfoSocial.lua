-- Peon_Panel - InfoSocial.lua
-- Freunde online, Gilde online und beobachteter Ruf. Namen stehen nur im Tooltip und werden nicht gespeichert.

local ADDON_NAME, ns = ...
local L = ns.L
local mod = ns.mod
if not mod then return end

local MAX_LINES = 15

-- Leere oder geheime Texte zeigen wir nicht
local function Plain(v)
    if v == nil or v == "" or Peon.IsSecret(v) then return nil end
    return v
end

---------------------------------------------------------------------------
-- Freunde: Spielfreunde und Battle.net-Freunde
---------------------------------------------------------------------------
-- online, gesamt
function ns.FriendCounts()
    local online = ns.Num(C_FriendList.GetNumOnlineFriends()) or 0
    local total = ns.Num(C_FriendList.GetNumFriends()) or 0
    local bn = rawget(_G, "BNGetNumFriends")
    if bn then
        local bnTotal, bnOnline = bn()
        online = online + (ns.Num(bnOnline) or 0)
        total = total + (ns.Num(bnTotal) or 0)
    end
    return online, total
end

local function FriendLines(tt)
    local shown = 0
    local function Add(left, right)
        shown = shown + 1
        if shown <= MAX_LINES then tt:AddDoubleLine(left, right or "", 1, 1, 1, 0.7, 0.7, 0.7) end
    end
    for i = 1, ns.Num(C_FriendList.GetNumFriends()) or 0 do
        local f = C_FriendList.GetFriendInfoByIndex(i)
        if f and f.connected and Plain(f.name) then Add(f.name, Plain(f.area)) end
    end
    local bn, net = rawget(_G, "BNGetNumFriends"), rawget(_G, "C_BattleNet")
    if bn and net and net.GetFriendAccountInfo then
        for i = 1, ns.Num((bn())) or 0 do
            local a = net.GetFriendAccountInfo(i)
            local game = a and a.gameAccountInfo
            if game and game.isOnline and Plain(a.accountName) then Add(a.accountName, Plain(game.characterName)) end
        end
    end
    if shown > MAX_LINES then tt:AddLine(L.SOCIAL_MORE:format(shown - MAX_LINES), 0.7, 0.7, 0.7) end
    if shown == 0 then tt:AddLine(L.FRIENDS_NONE, 1, 1, 1) end
end

ns.DefineInfo({
    key = "friends", title = L.FRIENDS_TITLE, icon = "Interface\\Icons\\INV_Misc_GroupLooking", side = "right",
    label = L.FRIENDS_LABEL, defaultText = "online",
    events = { "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED", "BN_DISCONNECTED" },
    texts = {
        { key = "online", label = L.SOCIAL_ONLINE, get = function()
            local online, total = ns.FriendCounts()
            return ("%d/%d"):format(online, total)
        end },
    },
    onClick = function() ns.OpenBlizzard("ToggleFriendsFrame", 1) end,
    onTooltip = function(_, tt) FriendLines(tt) end,
    init = function()
        mod:On("LOGIN", function() C_FriendList.ShowFriends() end)
    end,
})

---------------------------------------------------------------------------
-- Gilde
---------------------------------------------------------------------------
local ROSTER_WAIT = 60

local function InGuild() return IsInGuild() and true or false end

local function RequestRoster()
    if InGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

ns.DefineInfo({
    key = "guild", title = L.GUILD_TITLE, icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01", side = "right",
    label = L.GUILD_LABEL, defaultText = "online", available = InGuild, tick = ROSTER_WAIT,
    events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
    texts = {
        { key = "online", label = L.SOCIAL_ONLINE, get = function()
            local total, online = GetNumGuildMembers()
            return ("%d/%d"):format(ns.Num(online) or 0, ns.Num(total) or 0)
        end },
    },
    onClick = function()
        if not ns.OpenBlizzard("ToggleGuildFrame") then ns.OpenBlizzard("ToggleCommunitiesFrame") end
    end,
    onTooltip = function(_, tt)
        local guildName = Plain((GetGuildInfo("player")))
        if guildName then tt:AddLine(guildName, 1, 1, 1) end
        local shown = 0
        local total = ns.Num((GetNumGuildMembers())) or 0
        for i = 1, total do
            local name, _, _, level, _, zone, _, _, online = GetGuildRosterInfo(i)
            if online and Plain(name) then
                shown = shown + 1
                if shown <= MAX_LINES then
                    tt:AddDoubleLine(("%s (%s)"):format(name, tostring(level)), Plain(zone) or "", 1, 1, 1, 0.7, 0.7, 0.7)
                end
            end
        end
        if shown > MAX_LINES then tt:AddLine(L.SOCIAL_MORE:format(shown - MAX_LINES), 0.7, 0.7, 0.7) end
    end,
    init = function(l)
        mod:On("LOGIN", RequestRoster)
        -- Der Takt holt die Liste neu, die Antwort kommt als GUILD_ROSTER_UPDATE
        local refresh = l.Refresh
        l.Refresh = function(self)
            local now = time()
            if not self.rosterAt or now - self.rosterAt >= ROSTER_WAIT then
                self.rosterAt = now
                RequestRoster()
            end
            refresh(self)
        end
    end,
})

---------------------------------------------------------------------------
-- Beobachteter Ruf
---------------------------------------------------------------------------
-- Name, Rangname, aktueller Wert im Rang, Spanne des Rangs (0 = hoechster Rang)
function ns.WatchedFaction()
    local rep = rawget(_G, "C_Reputation")
    local data = rep and rep.GetWatchedFactionData and rep.GetWatchedFactionData()
    if not data or not Plain(data.name) then return nil end
    local standing = data.reaction and rawget(_G, "FACTION_STANDING_LABEL" .. tostring(data.reaction)) or ""
    local low, high, cur = ns.Num(data.currentReactionThreshold), ns.Num(data.nextReactionThreshold), ns.Num(data.currentStanding)
    if not low or not high or not cur then return data.name, standing, 0, 0 end
    return data.name, standing, cur - low, high - low
end

local function RepPercent(value, span)
    if span <= 0 then return nil end
    return ("%.0f %%"):format(value / span * 100)
end

ns.DefineInfo({
    key = "rep", title = L.REP_TITLE, icon = "Interface\\Icons\\INV_Misc_Note_01", side = "left",
    label = L.REP_LABEL, defaultText = "standing",
    available = function() return ns.WatchedFaction() ~= nil end,
    events = { "UPDATE_FACTION" },
    texts = {
        { key = "standing", label = L.REP_STANDING, get = function()
            local name, standing, value, span = ns.WatchedFaction()
            if not name then return nil end
            local pct = RepPercent(value, span)
            return pct and ("%s %s"):format(standing, pct) or standing
        end },
        { key = "name", label = L.REP_NAME, get = function()
            local name, _, value, span = ns.WatchedFaction()
            if not name then return nil end
            local pct = RepPercent(value, span)
            return pct and ("%s %s"):format(name, pct) or name
        end },
        { key = "value", label = L.REP_VALUE, get = function()
            local name, _, value, span = ns.WatchedFaction()
            if not name then return nil end
            if span <= 0 then return "-" end
            return ("%s/%s"):format(Peon.ShortNumber(value), Peon.ShortNumber(span))
        end },
    },
    onClick = function() ns.OpenBlizzard("ToggleCharacter", "ReputationFrame") end,
    onTooltip = function(_, tt)
        local name, standing, value, span = ns.WatchedFaction()
        if not name then return end
        tt:AddLine(name, 1, 1, 1)
        tt:AddLine(standing, 0.7, 0.7, 0.7)
        if span > 0 then tt:AddLine(("%s / %s (%s)"):format(Peon.ShortNumber(value), Peon.ShortNumber(span), RepPercent(value, span)), 1, 1, 1) end
    end,
})
