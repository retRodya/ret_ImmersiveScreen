local _, ns = ...

-- Moves the camera to the side, smoothly, with the game's own shoulder offset
-- (test_cameraOverShoulder, an experimental camera setting). The tween writes
-- the offset every frame while it moves; the CVar keeper brings the player's
-- own value back on /reload, logout and after a crash.

local GetCVar = C_CVar and C_CVar.GetCVar or GetCVar
local SetCVar = C_CVar and C_CVar.SetCVar or SetCVar

local KEY = "CameraShift"
local OFFSET = "test_cameraOverShoulder"
-- Accessibility settings that keep the character in the middle and cancel the offset.
local CENTERING = { "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" }

local tween
local ownOffset = 0 -- the player's own offset, kept while the camera is shifted

local function WriteOffset(value)
    SetCVar(OFFSET, string.format("%.3f", value))
end

-- The full Animation duration is the way between the player's own offset and
-- Camera offset; a shorter way takes proportionally less time.
local function MoveTo(target, finished)
    local span = math.abs(ns.GetSetting(KEY, "offset") - ownOffset)
    local seconds = 0
    if span > 0 then
        seconds = ns.GetSetting(KEY, "duration") * math.abs(target - tween.value) / span
    end
    tween:MoveTo(target, seconds, finished)
end

local active = false

ns.RegisterModule({
    key = KEY,
    category = "Effects",
    title = "CameraShift",
    description = "Moves the camera to the side, so your character stands off the centre of the frame. While it is on, the game does not warn about experimental camera features.",
    lens = true,
    settings = {
        {
            key = "offset",
            type = "slider",
            title = "Camera offset",
            description = "How far the camera moves to the side. Negative values move it the other way.",
            min = -15,
            max = 15,
            step = 0.1,
            default = 1.5,
            format = "%.1f",
        },
        {
            key = "duration",
            type = "slider",
            title = "Animation duration",
            description = "How long the camera takes to move, in seconds. At 0 it moves at once.",
            min = 0,
            max = 3,
            step = 0.1,
            default = 1,
            format = "%.1f s",
        },
    },

    -- Writing an experimental CVar makes the game ask to confirm experimental
    -- features. Like Lorewalker, we drop that event while CameraShift is enabled.
    Start = function()
        if GameEvent and GameEvent.UnregisterInternalEvent then
            GameEvent.UnregisterInternalEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
        end
    end,

    Activate = function()
        if GetCVar(OFFSET) == nil then
            return
        end
        active = true
        for _, name in ipairs(CENTERING) do
            ns.SetTemporaryCVar(KEY, name, "0", true)
        end
        local target = ns.GetSetting(KEY, "offset")
        ownOffset = tonumber(ns.HoldCVar(KEY, OFFSET, tostring(target))) or 0
        if not tween then
            tween = ns.CreateTween(tonumber(GetCVar(OFFSET)) or ownOffset, WriteOffset)
        end
        MoveTo(target)
    end,

    -- Back to the player's own offset first; the centering settings return after it.
    Deactivate = function()
        if not active then
            return
        end
        active = false
        MoveTo(ownOffset, function()
            ns.RestoreCVars(KEY)
        end)
    end,

    -- While shifted, a new offset applies at once: the slider is a live preview.
    OnSettingChanged = function(_, key, value)
        if key == "offset" and active then
            ns.HoldCVar(KEY, OFFSET, tostring(value))
            tween:MoveTo(value, 0)
        end
    end,
})
