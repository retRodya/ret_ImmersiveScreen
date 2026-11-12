local _, ns = ...

-- While the logout countdown runs (/camp, /quit), the Letterbox bars close in,
-- in three stages that each grow at their own rate, and the interface can fade
-- out; its countdown dialog stays visible. While chat has focus (Enter, or a
-- click into the chat input), the interface comes back and the bars turn half
-- transparent, still growing. Cancelling the logout gives the bars back to the
-- Lens and the interface comes back. Bar timings are those of ret_Cinemator.

local KEY = "GoOffline"
local COUNTDOWN = 20 -- seconds of the game's logout countdown
local RETURN_SECONDS = 0.15 -- bars and interface back after a cancelled logout
local CHAT_SECONDS = 0.3 -- interface and bar opacity when chat gains or loses focus
local CHAT_BAR_ALPHA = 0.5
local COUNTDOWN_DIALOGS = { CAMP = true, QUIT = true }

local frame
local elapsed -- seconds into the countdown, nil while there is none
local startHeight
local chatFocused = false
local barAlpha, barAlphaTarget = 1, 1

local function Setting(key)
    return ns.GetSetting(KEY, key)
end

local function HeightAt(seconds)
    local remaining, growth = seconds, 0
    for stage = 1, 3 do
        local duration = Setting("duration" .. stage)
        growth = growth + math.min(remaining, duration) * Setting("rate" .. stage)
        remaining = math.max(0, remaining - duration)
    end
    return math.min(Setting("maxHeight"), startHeight + growth)
end

-- Runs while the countdown runs or the bar opacity still moves.
local function OnUpdate(_, delta)
    elapsed = math.min(COUNTDOWN, elapsed + delta)
    local step = delta * (1 - CHAT_BAR_ALPHA) / CHAT_SECONDS
    if barAlpha < barAlphaTarget then
        barAlpha = math.min(barAlphaTarget, barAlpha + step)
    else
        barAlpha = math.max(barAlphaTarget, barAlpha - step)
    end
    ns.Letterbox.Hold(HeightAt(elapsed), barAlpha)
    if elapsed == COUNTDOWN and barAlpha == barAlphaTarget then
        frame:SetScript("OnUpdate", nil)
    end
end

-- The countdown dialog must stay readable while the interface fades.
local function KeepCountdownDialog(which)
    local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    if dialog then
        ns.InterfaceFade.Keep(dialog)
    end
end

-- Chat focus brings the interface back and makes the bars half transparent;
-- without it the interface fades and the bars are opaque.
local function ApplyChatFocus()
    barAlphaTarget = chatFocused and CHAT_BAR_ALPHA or 1
    frame:SetScript("OnUpdate", OnUpdate)
    if not Setting("fadeInterface") then
        return
    end
    if chatFocused then
        ns.InterfaceFade.In(CHAT_SECONDS)
    else
        ns.InterfaceFade.Out(Setting("fadeDuration"))
        for which in pairs(COUNTDOWN_DIALOGS) do
            KeepCountdownDialog(which)
        end
    end
end

local function SetChatFocused(focused)
    if chatFocused == focused then
        return
    end
    chatFocused = focused
    if elapsed then
        ApplyChatFocus()
    end
end

-- The bars start where they are, but not lower than the starting height.
-- If /camp was typed in chat, the fade starts once the chat input closes.
local function StartCountdown()
    if elapsed then
        return
    end
    elapsed = 0
    startHeight = math.min(Setting("maxHeight"), math.max(ns.Letterbox.GetHeight(), Setting("startHeight")))
    barAlpha = chatFocused and CHAT_BAR_ALPHA or 1
    ns.Letterbox.Hold(startHeight, barAlpha)
    frame:RegisterEvent("LOGOUT_CANCEL")
    ApplyChatFocus()
end

local function StopCountdown()
    if not elapsed then
        return
    end
    elapsed = nil
    frame:SetScript("OnUpdate", nil)
    frame:UnregisterEvent("LOGOUT_CANCEL")
    ns.Letterbox.Release(RETURN_SECONDS)
    ns.InterfaceFade.In(RETURN_SECONDS)
end

local function HeightSetting(key, title, description, default)
    return {
        key = key,
        type = "slider",
        title = title,
        description = description,
        min = 0,
        max = 50,
        step = 1,
        default = default,
        format = "%d%%",
    }
end

local function StageSettings(stage, duration, rate)
    return {
        key = "duration" .. stage,
        type = "slider",
        title = "Stage " .. stage .. " duration",
        description = "How long stage " .. stage .. " of the countdown lasts, in seconds.",
        min = 0,
        max = 20,
        step = 1,
        default = duration,
        format = "%d s",
    }, {
        key = "rate" .. stage,
        type = "slider",
        title = "Stage " .. stage .. " growth per second",
        description = "How much the bars grow each second of stage " .. stage .. ", in percent of the screen height.",
        min = 0,
        max = 50,
        step = 0.5,
        default = rate,
        format = "%.1f%%",
    }
end

local settings = {
    {
        key = "fadeInterface",
        type = "checkbox",
        title = "Fade the interface",
        description = "The interface fades out while the countdown runs; the countdown itself stays visible. An interface hidden with HideUI or Alt+Z stays hidden.",
        default = true,
    },
    {
        key = "fadeDuration",
        type = "slider",
        title = "Interface fade duration",
        description = "How long the interface takes to fade out, in seconds.",
        min = 0,
        max = 10,
        step = 0.5,
        default = 3,
        format = "%.1f s",
        indent = 1,
        IsShown = function()
            return ns.GetSetting(KEY, "fadeInterface")
        end,
    },
    HeightSetting("startHeight", "Minimum starting bar height",
        "The bars start at least this high, in percent of the screen height. Bars already shown start where they are.", 0),
    HeightSetting("maxHeight", "Maximum bar height",
        "The bars stop growing at this height, in percent of the screen height. At 50 they meet in the middle.", 50),
}
for stage, numbers in ipairs({ { 10, 2 }, { 6, 3 }, { 3, 4 } }) do
    local duration, rate = StageSettings(stage, numbers[1], numbers[2])
    table.insert(settings, duration)
    table.insert(settings, rate)
end

ns.RegisterModule({
    key = KEY,
    category = "LiteRP",
    section = "Stay",
    title = "GoOffline",
    description = "While the logout countdown runs, the Letterbox bars slowly close in and the interface can fade out. Typing in chat brings the interface back and makes the bars half transparent. Cancelling the logout brings everything back.",
    defaultsButton = true,
    settings = settings,

    Start = function()
        frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_CAMPING")
        frame:RegisterEvent("PLAYER_QUITING") -- Blizzard's spelling
        frame:SetScript("OnEvent", function(_, event)
            if event == "LOGOUT_CANCEL" then
                StopCountdown()
            else
                StartCountdown()
            end
        end)
        -- The countdown can also end from code, e.g. its Cancel button.
        hooksecurefunc("CancelLogout", StopCountdown)
        -- The game may show the countdown dialog after our event handler ran.
        hooksecurefunc("StaticPopup_Show", function(which)
            if elapsed and COUNTDOWN_DIALOGS[which] then
                KeepCountdownDialog(which)
            end
        end)
        -- The chat input reports its focus through EventRegistry, in Retail and Forever.
        if EventRegistry and EventRegistry.RegisterCallback then
            local owner = {}
            EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function()
                SetChatFocused(true)
            end, owner)
            for _, event in ipairs({ "ChatFrame.OnEditBoxFocusLost", "ChatFrame.OnEditBoxHide" }) do
                EventRegistry:RegisterCallback(event, function()
                    SetChatFocused(false)
                end, owner)
            end
        end
    end,
})
