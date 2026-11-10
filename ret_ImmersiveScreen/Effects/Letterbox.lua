local _, ns = ...

-- Black bars at the top and bottom of the screen. The bar frame has no parent,
-- so the bars stay when HideUI hides the interface; its anchors make it cover
-- the same area as UIParent, at any UI scale. The frame is created on first use
-- and runs OnUpdate only while the bars move.

local KEY = "Letterbox"
local MIN_HEIGHT = 0.01 -- a texture must never be 0 high

local bars, top, bottom
local current = 0 -- bar height now, in percent of the screen height
local start, target = 0, 0
local elapsed, duration = 0, 0

local function Layout()
    local height = math.max(MIN_HEIGHT, bars:GetHeight() * current / 100)
    top:SetHeight(height)
    bottom:SetHeight(height)
end

local function Finish()
    bars:SetScript("OnUpdate", nil)
    current = target
    Layout()
    bars:SetShown(current > 0)
end

-- Smoothstep: starts and ends gently.
local function OnUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed >= duration then
        Finish()
        return
    end
    local progress = elapsed / duration
    current = start + (target - start) * progress * progress * (3 - 2 * progress)
    Layout()
end

local function CreateBars()
    bars = CreateFrame("Frame")
    bars:Hide()
    bars:SetFrameStrata("BACKGROUND")
    bars:SetFrameLevel(0)
    bars:EnableMouse(false)
    bars:SetAllPoints(UIParent)
    bars:SetScript("OnSizeChanged", Layout)

    top = bars:CreateTexture(nil, "BACKGROUND")
    top:SetColorTexture(0, 0, 0, 1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")

    bottom = bars:CreateTexture(nil, "BACKGROUND")
    bottom:SetColorTexture(0, 0, 0, 1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
end

-- A change in the middle of an animation continues from where the bars are now.
-- The full Animation duration is the way from no bars to Bar height; a shorter
-- way takes proportionally less time. seconds, optional, sets the time instead.
local function MoveTo(height, seconds)
    if not bars then
        CreateBars()
    end
    start, target, elapsed = current, height, 0
    duration = seconds
        or ns.GetSetting(KEY, "duration") * math.abs(target - start) / ns.GetSetting(KEY, "height")
    if duration <= 0 then
        Finish()
        return
    end
    bars:Show()
    bars:SetScript("OnUpdate", OnUpdate)
end

local active = false
local held = false -- LiteRP holds the bars, e.g. GoOffline during the logout countdown

-- What the Lens wants: Bar height while Letterbox is on, otherwise no bars.
local function LensHeight()
    return active and ns.GetSetting(KEY, "height") or 0
end

-- For LiteRP features. A mechanism only: it works even while the Letterbox
-- effect is disabled, and creates the bar frame on first use.
ns.Letterbox = {}

function ns.Letterbox.GetHeight()
    return current
end

-- Sets the bars to a height at once, every call, until Release. The Lens keeps
-- track of Letterbox meanwhile without moving the bars.
function ns.Letterbox.Hold(height)
    if not bars then
        CreateBars()
    end
    held = true
    target = height
    Finish()
end

-- Back to what the Lens wants, in the given number of seconds.
function ns.Letterbox.Release(seconds)
    if held then
        held = false
        MoveTo(LensHeight(), seconds)
    end
end

ns.RegisterModule({
    key = KEY,
    category = "Effects",
    title = "Letterbox",
    description = "Cinematic black bars at the top and bottom of the screen.",
    lens = true,
    enabledByDefault = true,
    combinedByDefault = true,
    settings = {
        {
            key = "height",
            type = "slider",
            title = "Bar height",
            description = "Height of each bar, in percent of the screen height.",
            min = 1,
            max = 25,
            step = 0.5,
            default = 10,
            format = "%.1f%%",
        },
        {
            key = "duration",
            type = "slider",
            title = "Animation duration",
            description = "How long the bars take to slide in and out, in seconds. At 0 they appear and disappear at once.",
            min = 0,
            max = 3,
            step = 0.1,
            default = 0.5,
            format = "%.1f s",
        },
    },

    Activate = function()
        active = true
        if not held then
            MoveTo(LensHeight())
        end
    end,

    Deactivate = function()
        active = false
        if not held then
            MoveTo(LensHeight())
        end
    end,

    -- While the bars are shown, a new height applies at once: the slider is a live preview.
    OnSettingChanged = function(_, key, value)
        if key == "height" and active and not held then
            target = value
            Finish()
        end
    end,
})
