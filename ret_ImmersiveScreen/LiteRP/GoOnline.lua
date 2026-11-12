local _, ns = ...

-- After you enter the world, the Letterbox bars open from the middle of the
-- screen while their opacity goes from the starting to the ending one, at a
-- steady rate. Only on the first
-- login of a session, not on /reload or a zone change; it starts when the
-- loading screen is gone, so it is not hidden under it.

local KEY = "GoOnline"

local frame
local elapsed -- seconds into the animation, nil while it does not run

local function Setting(key)
    return ns.GetSetting(KEY, key)
end

local function Stop()
    elapsed = nil
    frame:SetScript("OnUpdate", nil)
    ns.Letterbox.Release(0)
end

local function OnUpdate(_, delta)
    elapsed = elapsed + delta
    local duration = Setting("duration")
    if elapsed >= duration then
        Stop()
        return
    end
    local progress = elapsed / duration
    local startOpacity = Setting("startOpacity")
    local opacity = startOpacity + (Setting("endOpacity") - startOpacity) * progress
    ns.Letterbox.Hold(Setting("startHeight") * (1 - progress), opacity / 100)
end

-- From the start again if it already runs, e.g. on a second Test.
local function Play()
    if Setting("duration") <= 0 then
        return
    end
    elapsed = 0
    ns.Letterbox.Hold(Setting("startHeight"), Setting("startOpacity") / 100)
    frame:SetScript("OnUpdate", OnUpdate)
end

ns.RegisterModule({
    key = KEY,
    category = "LiteRP",
    section = "Move",
    title = "GoOnline",
    description = "After you enter the world, the Letterbox bars open from the middle of the screen and fade out.",
    defaultsButton = true,
    buttons = {
        {
            title = "Test",
            description = "Plays the effect now, as after entering the world.",
            OnClick = Play,
        },
    },
    settings = {
        {
            key = "startHeight",
            type = "slider",
            title = "Starting bar height",
            description = "How high the bars start, in percent of the screen height. At 50 they meet in the middle.",
            min = 0,
            max = 50,
            step = 1,
            default = 50,
            format = "%d%%",
        },
        {
            key = "startOpacity",
            type = "slider",
            title = "Starting opacity",
            description = "How opaque the bars are when they start to open.",
            min = 0,
            max = 100,
            step = 1,
            default = 100,
            format = "%d%%",
        },
        {
            key = "endOpacity",
            type = "slider",
            title = "Ending opacity",
            description = "How opaque the bars are by the time they have opened. The opacity changes at a steady rate between the two.",
            min = 0,
            max = 100,
            step = 1,
            default = 0,
            format = "%d%%",
        },
        {
            key = "duration",
            type = "slider",
            title = "Animation duration",
            description = "How long the bars take to open and fade out, in seconds.",
            min = 0,
            max = 5,
            step = 0.1,
            default = 5,
            format = "%.1f s",
        },
    },

    Start = function()
        frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:SetScript("OnEvent", function(self, event, isInitialLogin)
            if event == "PLAYER_ENTERING_WORLD" then
                self:UnregisterEvent("PLAYER_ENTERING_WORLD")
                if isInitialLogin then
                    self:RegisterEvent("LOADING_SCREEN_DISABLED")
                end
            else
                self:UnregisterEvent("LOADING_SCREEN_DISABLED")
                Play()
            end
        end)
    end,
})
