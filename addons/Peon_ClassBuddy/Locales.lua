-- Peon_ClassBuddy - Locales.lua
-- Allgemeine Texte (Fehler, Standardwerte, Positionen) liefert der Peon-Kern (Peon.L)
local ADDON_NAME, ns = ...

local L = Peon.NewLocale()
ns.L = L

-- enUS (Standard)
L.TITLE = "Class Buddy"
L.HELP = {
    "/peon classbuddy check - window for the soul shard check",
    "/peon classbuddy check start - start the check (destroys at most one shard per test)",
    "/peon classbuddy check result - show the results",
    "/peon classbuddy check send - send the results to the Peon Manager (needs Peon_Feedback)",
    "/peon classbuddy check clear - forget the results",
    "/peon classbuddy check off - stop the check",
}
L.P_START       = "Check started. Each test destroys at most one soul shard. In 1 second the first test runs by itself."
L.P_STEPS       = {
    "1. Click the button in the window.",
    "2. Make a macro with  /click PeonClassBuddyShard  and use it.",
    "3. Cast any spell from your action bar.",
    "4. Repeat 1 to 3 in combat.",
    "Then: /peon classbuddy check send",
}
L.P_NO_SHARD    = "no soul shard in the bags"
L.P_CURSOR_BUSY = "something is already on the cursor"
L.P_PICKUP_FAIL = "picking up failed"
L.P_WRONG_ITEM  = "wrong item on the cursor, put back"
L.P_DONE        = "destroyed"
L.P_NOT_DONE    = "not destroyed"
L.P_BLOCKED     = "blocked by the game"
L.P_ERROR       = "error"
L.P_RESULT      = "%s (%s): %s"
L.P_HEAD        = "Results of the soul shard check:"
L.P_NONE        = "No results yet. Start with /peon classbuddy check"
L.P_CLEARED     = "Results cleared."
L.P_OFF         = "Check stopped."
L.P_INFO_CLASS  = "Class: %s, soul shards in bags: %d, item family of the shard: %s"
L.P_INFO_BAG    = "Bag %d: %d slots, %d free, bag type %s, shards %d"
L.P_INFO_API    = "Functions: %s"
L.P_HOOKS       = "Seen while casting: %s"
L.P_COMBAT      = "combat"
L.P_FREE        = "no combat"
L.P_WAY = {
    event  = "without key press",
    click  = "button click",
    macro  = "macro /click",
    action = "action key",
}
L.P_BUTTON      = "Destroy shard (test)"
L.P_NOT_WARLOCK = "Note: this character is no warlock. The check still works if it has a soul shard."
L.P_MACRO_DONE  = "Macro \"PeonSplitter\" is on your cursor. Drop it on an action bar slot and press it."
L.P_MACRO_FAIL  = "Could not create the macro. Please make one yourself with: %s"
L.P_MACRO_COMBAT = "Macros cannot be created in combat."
L.P_SEND_DONE   = "Results handed to Peon Feedback. After /reload or logging out, the Peon Manager shows them under feedback, please send them from there."
L.P_SEND_FAIL   = "Sending failed: %s"
L.P_SEND_NO_FEEDBACK = "Peon_Feedback is not active. Please turn it on in the Peon Manager, /reload and send again."

L.G_TITLE   = "Class Buddy: soul shard test"
L.G_TEMP    = "This window is only here for a short test and goes away with the next version."
L.G_WHY     = "We want to find out whether Class Buddy may destroy surplus soul shards, and when. Each test destroys at most one shard. You need at least 8 soul shards."
L.G_STEP1   = "1. Start the check. A first test runs by itself after one second."
L.G_STEP2   = "2. Click this button:"
L.G_STEP3   = "3. Create the macro, drop it on your action bar and press it:"
L.G_STEP4   = "4. Cast any spell from your action bar (e.g. Shadow Bolt on a target)."
L.G_STEP5   = "5. Attack an enemy and repeat 2 to 4 while in combat. The test without key press runs again when combat starts."
L.G_STEP6   = "6. Send the result. Then /reload or log out and send the feedback in the Peon Manager."
L.G_BTN_START = "Start check"
L.G_BTN_MACRO = "Create macro"
L.G_BTN_SEND  = "Send result"
L.G_STATE   = "State"
L.G_OPEN    = "open"
L.G_SENT    = "Result handed over. Please send it in the Peon Manager."
L.G_HIDE    = "Do not show again"

if GetLocale() == "deDE" then
    L.TITLE = "Klassenbuddy"
    L.HELP = {
        "/peon classbuddy pruefen - Fenster zur Prüfung der Seelensplitter",
        "/peon classbuddy pruefen start - Prüfung starten (vernichtet je Test höchstens einen Splitter)",
        "/peon classbuddy pruefen ergebnis - Ergebnisse zeigen",
        "/peon classbuddy pruefen senden - Ergebnisse an den Peon Manager geben (braucht Peon_Feedback)",
        "/peon classbuddy pruefen leeren - Ergebnisse vergessen",
        "/peon classbuddy pruefen aus - Prüfung beenden",
    }
    L.P_START       = "Prüfung gestartet. Jeder Test vernichtet höchstens einen Seelensplitter. In 1 Sekunde läuft der erste Test von allein."
    L.P_STEPS       = {
        "1. Im Fenster auf den Knopf klicken.",
        "2. Ein Makro mit  /click PeonClassBuddyShard  anlegen und benutzen.",
        "3. Einen beliebigen Zauber von der Aktionsleiste wirken.",
        "4. 1 bis 3 im Kampf wiederholen.",
        "Danach: /peon classbuddy pruefen senden",
    }
    L.P_NO_SHARD    = "kein Seelensplitter in den Taschen"
    L.P_CURSOR_BUSY = "am Mauszeiger hängt schon etwas"
    L.P_PICKUP_FAIL = "Aufnehmen hat nicht geklappt"
    L.P_WRONG_ITEM  = "falscher Gegenstand am Mauszeiger, zurückgelegt"
    L.P_DONE        = "vernichtet"
    L.P_NOT_DONE    = "nicht vernichtet"
    L.P_BLOCKED     = "vom Spiel gesperrt"
    L.P_ERROR       = "Fehler"
    L.P_HEAD        = "Ergebnisse der Prüfung Seelensplitter:"
    L.P_NONE        = "Noch keine Ergebnisse. Starten mit /peon classbuddy pruefen"
    L.P_CLEARED     = "Ergebnisse gelöscht."
    L.P_OFF         = "Prüfung beendet."
    L.P_INFO_CLASS  = "Klasse: %s, Seelensplitter in den Taschen: %d, Gegenstandsfamilie des Splitters: %s"
    L.P_INFO_BAG    = "Tasche %d: %d Plätze, %d frei, Taschentyp %s, Splitter %d"
    L.P_INFO_API    = "Funktionen: %s"
    L.P_HOOKS       = "Beim Zaubern gesehen: %s"
    L.P_COMBAT      = "Kampf"
    L.P_FREE        = "kein Kampf"
    L.P_WAY = {
        event  = "ohne Tastendruck",
        click  = "Klick auf Knopf",
        macro  = "Makro /click",
        action = "Aktionstaste",
    }
    L.P_BUTTON      = "Splitter vernichten (Test)"
    L.P_NOT_WARLOCK = "Hinweis: Dieser Charakter ist kein Hexenmeister. Die Prüfung geht trotzdem, wenn er einen Seelensplitter hat."
    L.P_MACRO_DONE  = "Das Makro „PeonSplitter“ hängt am Mauszeiger. Leg es auf einen Platz der Aktionsleiste und drück es."
    L.P_MACRO_FAIL  = "Das Makro ließ sich nicht anlegen. Bitte selbst eines anlegen mit: %s"
    L.P_MACRO_COMBAT = "Im Kampf lassen sich keine Makros anlegen."
    L.P_SEND_DONE   = "Ergebnis an Peon Feedback übergeben. Nach /reload oder dem Ausloggen zeigt es der Peon Manager bei den Rückmeldungen, bitte von dort senden."
    L.P_SEND_FAIL   = "Senden hat nicht geklappt: %s"
    L.P_SEND_NO_FEEDBACK = "Peon_Feedback ist nicht aktiv. Bitte im Peon Manager einschalten, /reload und noch einmal senden."

    L.G_TITLE   = "Klassenbuddy: Test Seelensplitter"
    L.G_TEMP    = "Dieses Fenster ist nur vorübergehend für einen Test da und verschwindet mit der nächsten Version wieder."
    L.G_WHY     = "Wir wollen herausfinden, ob und wann der Klassenbuddy überzählige Seelensplitter vernichten darf. Jeder Test vernichtet höchstens einen Splitter. Du brauchst mindestens 8 Seelensplitter."
    L.G_STEP1   = "1. Prüfung starten. Ein erster Test läuft nach einer Sekunde von allein."
    L.G_STEP2   = "2. Auf diesen Knopf klicken:"
    L.G_STEP3   = "3. Makro anlegen, auf die Aktionsleiste legen und drücken:"
    L.G_STEP4   = "4. Einen beliebigen Zauber von der Aktionsleiste wirken (z. B. Schattenblitz auf ein Ziel)."
    L.G_STEP5   = "5. Einen Gegner angreifen und im Kampf 2 bis 4 wiederholen. Der Test ohne Tastendruck läuft bei Kampfbeginn noch einmal."
    L.G_STEP6   = "6. Ergebnis senden. Danach /reload oder ausloggen und die Rückmeldung im Peon Manager senden."
    L.G_BTN_START = "Prüfung starten"
    L.G_BTN_MACRO = "Makro anlegen"
    L.G_BTN_SEND  = "Ergebnis senden"
    L.G_STATE   = "Stand"
    L.G_OPEN    = "offen"
    L.G_SENT    = "Ergebnis übergeben. Bitte im Peon Manager senden."
    L.G_HIDE    = "Nicht mehr anzeigen"
end
