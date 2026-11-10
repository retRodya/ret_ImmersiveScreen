local _, ns = ...

-- Moves the camera to the side, smoothly, with the game's own shoulder offset
-- (test_cameraOverShoulder, an experimental camera setting).

local KEY = "CameraShift"
-- Accessibility settings that keep the character in the middle and cancel the offset.
local CENTERING = { "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" }

local camera = ns.CreateCVarTween(KEY, "test_cameraOverShoulder")
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
        if not camera:IsAvailable() then
            return
        end
        active = true
        for _, name in ipairs(CENTERING) do
            ns.SetTemporaryCVar(KEY, name, "0", true)
        end
        camera:Shift(ns.GetSetting(KEY, "offset"), ns.GetSetting(KEY, "duration"))
    end,

    -- The centering settings return once the camera is back.
    Deactivate = function()
        if not active then
            return
        end
        active = false
        camera:Return(ns.GetSetting(KEY, "offset"), ns.GetSetting(KEY, "duration"))
    end,

    -- While shifted, a new offset applies at once: the slider is a live preview.
    OnSettingChanged = function(_, key, value)
        if key == "offset" and active then
            camera:Jump(value)
        end
    end,
})
