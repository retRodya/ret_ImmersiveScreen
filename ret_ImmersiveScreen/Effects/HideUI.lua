local _, ns = ...

-- Hides the interface exactly like Alt+Z, and the names the player chose.
--
-- Interface: the body of the game's Alt+Z binding (TOGGLEUI in
-- Bindings_Standard.xml). RunBinding("TOGGLEUI") itself is protected.
--
-- Names: the entries of the game's Names settings. Only names the game shows
-- now are listed, each with a checkbox that is on by default. So HideUI never
-- writes a setting that is already off, and a name the player turns on in the
-- game's settings appears in the list.

local KEY = "HideUI"

-- In the order of the game's Names section; labels are the game's own strings.
-- parent: listed only while the parent is shown in the game, indented under it.
local NAMES = {
    {
        key = "nameOwn",
        label = UNIT_NAME_OWN or "My name",
        cvars = { "UnitNameOwn" },
    },
    {
        key = "nameSurname",
        label = UNIT_SECONDARY_NAME_OWN or "My surname",
        cvars = { "UnitSurnameOwn" },
        parent = "nameOwn",
    },
    {
        -- The game's NPC names dropdown sets all of these; quest circles belong to the NPCs.
        key = "nameNPC",
        label = SHOW_NPC_NAMES or "NPC names",
        cvars = { "UnitNameNPC", "UnitNameHostleNPC", "UnitNameInteractiveNPC", "UnitNameFriendlySpecialNPCName", "ShowQuestUnitCircles" },
    },
    {
        key = "nameCritters",
        label = UNIT_NAME_NONCOMBAT_CREATURE or "Critters and companions",
        cvars = { "UnitNameNonCombatCreatureName" },
    },
    {
        key = "nameFriendlyPlayers",
        label = UNIT_NAME_FRIENDLY or "Friendly players",
        cvars = { "UnitNameFriendlyPlayerName" },
    },
    {
        key = "nameFriendlyMinions",
        label = UNIT_NAME_FRIENDLY_MINIONS or "Minions",
        cvars = { "UnitNameFriendlyMinionName" },
        parent = "nameFriendlyPlayers",
    },
    {
        key = "nameEnemyPlayers",
        label = UNIT_NAME_ENEMY or "Enemy players",
        cvars = { "UnitNameEnemyPlayerName" },
    },
    {
        key = "nameEnemyMinions",
        label = UNIT_NAME_ENEMY_MINIONS or "Minions",
        cvars = { "UnitNameEnemyMinionName" },
        parent = "nameEnemyPlayers",
    },
    {
        -- Not in the game's Names section: the label is ours, and the entry is
        -- always listed, since the player cannot turn it on in the game.
        key = "nameFocused",
        label = "Highlighted unit",
        description = "The name of your target, of the unit under the cursor and of the NPC highlighted for interaction. The game shows it even when other names are off. Hidden while HideUI is on.",
        cvars = { "UnitNameFocused" },
        alwaysListed = true,
    },
}

local namesByKey = {}
for _, entry in ipairs(NAMES) do
    namesByKey[entry.key] = entry
end

-- As the player set it in the game, even while HideUI holds it off.
-- A CVar the client lacks counts as off.
local function IsShownInGame(entry)
    if entry.parent and not IsShownInGame(namesByKey[entry.parent]) then
        return false
    end
    for _, name in ipairs(entry.cvars) do
        local value = ns.GetOriginalCVar(KEY, name)
        if value ~= nil and value ~= "0" then
            return true
        end
    end
    return false
end

local function IsListed(entry)
    return entry.alwaysListed or IsShownInGame(entry)
end

local function AnyNameListed()
    for _, entry in ipairs(NAMES) do
        if IsListed(entry) then
            return true
        end
    end
    return false
end

local settings = {
    {
        key = "names",
        type = "heading",
        title = NAMES_LABEL or "Names",
        IsShown = AnyNameListed,
    },
}
for _, entry in ipairs(NAMES) do
    table.insert(settings, {
        key = entry.key,
        type = "checkbox",
        title = entry.label,
        description = entry.description or "Hidden while HideUI is on. Listed because the game's Names settings show it now.",
        default = true,
        indent = entry.parent and 1 or 0,
        IsShown = function()
            return IsListed(entry)
        end,
    })
end

-- Alt+Z does nothing while another frame is the top level parent of the interface.
local function CanUseAltZ()
    return GetAppropriateTopLevelParent() == UIParent
end

local function HideInterface()
    securecall("CloseMenus")
    securecall("CloseAllWindows")
    SetUIVisibility(false)
end

-- The interface may already be hidden with Alt+Z; then it stays hidden afterwards.
local interfaceWasShown
local active = false

-- Chat: while it has focus, the interface HideUI hid fades back in, so the
-- player sees what they type; names stay hidden. Without focus it fades out
-- and hides again.
local function HidesInterface()
    return active and interfaceWasShown
end

local function OnChatOpen(editBox)
    if HidesInterface() and not UIParent:IsShown() then
        ns.InterfaceFade.Reveal(ns.ChatFocus.SECONDS)
        if GetCurrentKeyBoardFocus() ~= editBox then
            editBox:SetFocus()
        end
    end
end

local function OnChatFocus(focused)
    if not HidesInterface() then
        return
    end
    if focused then
        ns.InterfaceFade.Reveal(ns.ChatFocus.SECONDS)
    else
        ns.InterfaceFade.Conceal(ns.ChatFocus.SECONDS)
    end
end

ns.RegisterModule({
    key = KEY,
    category = "Effects",
    title = "HideUI",
    description = "Hides the interface exactly like Alt+Z, and the names you choose. Names are hidden and shown again step by step, one game setting at a time, to save resources.",
    lens = true,
    enabledByDefault = true,
    combinedByDefault = true,
    settings = settings,

    Start = function()
        ns.ChatFocus.OnOpen(OnChatOpen)
        ns.ChatFocus.Subscribe(OnChatFocus)
    end,

    Activate = function(module)
        active = true
        for _, entry in ipairs(NAMES) do
            if IsShownInGame(entry) and ns.GetSetting(KEY, entry.key) then
                for _, name in ipairs(entry.cvars) do
                    ns.SetTemporaryCVar(module.key, name, "0")
                end
            end
        end
        interfaceWasShown = UIParent:IsShown() and CanUseAltZ()
        if interfaceWasShown then
            HideInterface()
        end
    end,

    -- The game may have shown the interface already, e.g. on Esc in combat, and
    -- chat may have it half faded: either way it ends fully shown.
    Deactivate = function(module)
        active = false
        ns.RestoreCVars(module.key)
        if interfaceWasShown then
            ns.InterfaceFade.Reveal(0)
        end
    end,
})
