local _, ns = ...

-- Eases the camera's field of view (cameraFov) to the chosen angle and back to
-- the player's own, the one in the game's Graphics settings.

local KEY = "FOV"

-- The range of the game's own Field of View slider; numbers in case the client lacks it.
local defaultFov, minFov, maxFov = 90, 50, 90
if GetCameraFOVDefaults then
    defaultFov, minFov, maxFov = GetCameraFOVDefaults()
end

local fov = ns.CreateCVarTween(KEY, "cameraFov")
local active = false

ns.RegisterModule({
    key = KEY,
    category = "Effects",
    title = "FOV",
    description = "Smoothly changes the camera's field of view, then returns it to the one in the game's Graphics settings.",
    lens = true,
    settings = {
        {
            key = "fov",
            type = "slider",
            title = "Field of view",
            description = "The camera's field of view while FOV is on, in degrees. Smaller values look more cinematic.",
            min = minFov,
            max = maxFov,
            step = 1,
            default = math.max(minFov, math.min(maxFov, defaultFov - 20)),
            format = "%d",
        },
        {
            key = "duration",
            type = "slider",
            title = "Animation duration",
            description = "How long the field of view takes to change, in seconds. At 0 it changes at once.",
            min = 0,
            max = 3,
            step = 0.1,
            default = 1,
            format = "%.1f s",
        },
    },

    Activate = function()
        if not fov:IsAvailable() then
            return
        end
        active = true
        fov:Shift(ns.GetSetting(KEY, "fov"), ns.GetSetting(KEY, "duration"))
    end,

    Deactivate = function()
        if not active then
            return
        end
        active = false
        fov:Return(ns.GetSetting(KEY, "fov"), ns.GetSetting(KEY, "duration"))
    end,

    -- While on, a new angle applies at once: the slider is a live preview.
    OnSettingChanged = function(_, key, value)
        if key == "fov" and active then
            fov:Jump(value)
        end
    end,
})
