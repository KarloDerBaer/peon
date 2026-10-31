-- Peon_Mover - Frames.lua
-- Bekannte Fenster (Namen aus der Fensterliste von BlizzMove fuer Forever/Retail, ergaenzt).
-- Es werden nur Fenster angefasst, die es im Spiel wirklich gibt; fehlende werden uebersprungen.
-- Zusaetzlich findet Mover alle Fenster aus Blizzards Tabelle UIPanelWindows (nur lesen).

local ADDON_NAME, ns = ...
local de = GetLocale() == "deDE"

-- [Name des Fensters im Spiel] = { deutsch, englisch }
ns.KNOWN = {
    AddonList                 = { "Addon-Liste", "Addon list" },
    BankFrame                 = { "Bank", "Bank" },
    CharacterFrame            = { "Charakter", "Character" },
    ChatConfigFrame           = { "Chat-Einstellungen", "Chat settings" },
    DressUpFrame              = { "Anprobe", "Dressing room" },
    FriendsFrame              = { "Kontakte", "Social" },
    GameMenuFrame             = { "Spielmenü", "Game menu" },
    GossipFrame               = { "Gespräch", "Gossip" },
    GuildInviteFrame          = { "Gildeneinladung", "Guild invite" },
    GuildRegistrarFrame       = { "Gilde gründen", "Guild registrar" },
    HelpFrame                 = { "Hilfe", "Help" },
    ItemTextFrame             = { "Text lesen", "Item text" },
    LootFrame                 = { "Beute", "Loot" },
    MailFrame                 = { "Post", "Mail" },
    MerchantFrame             = { "Händler", "Merchant" },
    ModelPreviewFrame         = { "Vorschau", "Preview" },
    PetStableFrame            = { "Stall", "Stable" },
    StableFrame               = { "Stall", "Stable" },
    PetitionFrame             = { "Satzung", "Petition" },
    QuestFrame                = { "Quest", "Quest" },
    QuestLogFrame             = { "Questlog", "Quest log" },
    QuestLogPopupDetailFrame  = { "Questdetails", "Quest details" },
    QuickKeybindFrame         = { "Schnelle Tastenbelegung", "Quick keybind" },
    SettingsPanel             = { "Einstellungen", "Settings" },
    TabardFrame               = { "Wappenrock", "Tabard" },
    TaxiFrame                 = { "Flugmeister", "Flight master" },
    FlightMapFrame            = { "Flugkarte", "Flight map" },
    TradeFrame                = { "Handel", "Trade" },
    WorldMapFrame             = { "Weltkarte", "World map" },
    PVEFrame                  = { "Gruppensuche", "Group finder" },
    LFGParentFrame            = { "Gruppensuche", "Group finder" },
    SpellBookFrame            = { "Zauberbuch", "Spellbook" },
    PlayerSpellsFrame         = { "Zauberbuch und Talente", "Spellbook and talents" },
    PlayerTalentFrame         = { "Talente", "Talents" },
    TalentFrame               = { "Talente", "Talents" },
    AchievementFrame          = { "Erfolge", "Achievements" },
    AuctionHouseFrame         = { "Auktionshaus", "Auction house" },
    CalendarFrame             = { "Kalender", "Calendar" },
    ChannelFrame              = { "Chatkanäle", "Chat channels" },
    CollectionsJournal        = { "Sammlungen", "Collections" },
    CommunitiesFrame          = { "Gilde und Gemeinschaften", "Guild and communities" },
    CommunitiesGuildLogFrame  = { "Gildenprotokoll", "Guild log" },
    CommunitiesSettingsDialog = { "Gemeinschaft: Einstellungen", "Community settings" },
    EncounterJournal          = { "Dungeonkompendium", "Adventure guide" },
    GuildBankFrame            = { "Gildenbank", "Guild bank" },
    GuildControlUI            = { "Gildenverwaltung", "Guild control" },
    InspectFrame              = { "Betrachten", "Inspect" },
    ItemSocketingFrame        = { "Sockel", "Socketing" },
    MacroFrame                = { "Makros", "Macros" },
    ProfessionsFrame          = { "Berufe", "Professions" },
    ProfessionsBookFrame      = { "Berufsbuch", "Professions book" },
    InspectRecipeFrame        = { "Rezept ansehen", "Inspect recipe" },
    TradeSkillFrame           = { "Berufe", "Professions" },
    CraftFrame                = { "Berufe (Handwerk)", "Craft" },
    ClassTrainerFrame         = { "Lehrer", "Trainer" },
    TimeManagerFrame          = { "Uhr", "Clock" },
    TransmogFrame             = { "Transmogrifikation", "Transmogrification" },
    KeyBindingFrame           = { "Tastenbelegung", "Key bindings" },
    CooldownViewerSettings    = { "Abklingzeiten: Einstellungen", "Cooldown settings" },
}

-- Nie anfassen: Taschen (Blizzard ordnet sie selbst an, Bagnon ersetzt sie), kleine Einblendungen
ns.SKIP = {
    ContainerFrameCombinedBags = true, GroupLootContainer = true, TalkingHeadFrame = true,
    ReadyCheckFrame = true, DeathRecapFrame = true, PlayerChoiceFrame = true, SplashFrame = true,
    TutorialFrame = true, PingSystemTutorial = true, NamePlatesTutorial = true,
}
-- Fenster, die ein anderes Addon schon verschiebbar macht: [Fenster] = Addon
ns.OWNED_BY = {
    WorldMapFrame = "Leatrix_Maps",
}

function ns.SkipName(name)
    if ns.SKIP[name] then return true end
    if name:match("^ContainerFrame%d+$") then return true end
    local owner = ns.OWNED_BY[name]
    if owner and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(owner) then return true end
    return false
end

-- Anzeigename fuer die Fensterliste
function ns.DisplayName(name)
    local k = ns.KNOWN[name]
    if k then return de and k[1] or k[2] end
    return name
end
