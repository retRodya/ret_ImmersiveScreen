local _, ns = ...

-- While the logout countdown runs (/camp, /quit), the Letterbox bars close in,
-- in three stages that each grow at their own rate. Cancelling the logout gives
-- the bars back to the Lens. Timings are those of ret_Cinemator.

local KEY = "GoOffline"
local COUNTDOWN = 20 -- seconds of the game's logout countdown
local RETURN_SECONDS = 0.15 -- bars back after a cancelled logout

local frame
local elapsed -- seconds into the countdown, nil while there is none
local startHeight

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

local function OnUpdate(_, delta)
    elapsed = math.min(COUNTDOWN, elapsed + delta)
    ns.Letterbox.Hold(HeightAt(elapsed))
    if elapsed == COUNTDOWN then
        frame:SetScript("OnUpdate", nil)
    end
end

-- The bars start where they are, but not lower than the starting height.
local function StartCountdown()
    if elapsed then
        return
    end
    elapsed = 0
    startHeight = math.min(Setting("maxHeight"), math.max(ns.Letterbox.GetHeight(), Setting("startHeight")))
    ns.Letterbox.Hold(startHeight)
    frame:RegisterEvent("LOGOUT_CANCEL")
    frame:SetScript("OnUpdate", OnUpdate)
end

local function StopCountdown()
    if not elapsed then
        return
    end
    elapsed = nil
    frame:SetScript("OnUpdate", nil)
    frame:UnregisterEvent("LOGOUT_CANCEL")
    ns.Letterbox.Release(RETURN_SECONDS)
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
    description = "While the logout countdown runs, the Letterbox bars slowly close in. Cancelling the logout brings them back.",
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
    end,
})
