local _, ns = ...

local GetCVar = C_CVar and C_CVar.GetCVar or GetCVar
local SetCVar = C_CVar and C_CVar.SetCVar or SetCVar

-- A number that eases to a target (smoothstep: starts and ends gently) and
-- calls apply(value) on every step. OnUpdate runs only while it moves.
-- A new target in the middle continues from the current value.

function ns.CreateTween(value, apply)
    local frame = CreateFrame("Frame")
    local tween = { value = value }
    local start, target, elapsed, duration = value, value, 0, 0
    local onFinished

    local function Finish()
        frame:SetScript("OnUpdate", nil)
        tween.value = target
        apply(target)
        local callback = onFinished
        onFinished = nil
        if callback then
            callback()
        end
    end

    local function Step(_, delta)
        elapsed = elapsed + delta
        if elapsed >= duration then
            Finish()
            return
        end
        local progress = elapsed / duration
        tween.value = start + (target - start) * progress * progress * (3 - 2 * progress)
        apply(tween.value)
    end

    -- seconds 0 jumps at once. finished, optional, runs when the target is reached,
    -- unless another MoveTo comes first.
    function tween:MoveTo(newTarget, seconds, finished)
        start, target, elapsed, duration = self.value, newTarget, 0, seconds
        onFinished = finished
        if seconds <= 0 then
            Finish()
        else
            frame:SetScript("OnUpdate", Step)
        end
    end

    return tween
end

-- One number CVar that an Effect eases to its value and back to the player's
-- own, e.g. the camera offset or the field of view. The CVar is written every
-- frame while it moves; the CVar keeper brings the player's value back on
-- /reload, logout and after a crash. The frame is created on first use.
function ns.CreateCVarTween(owner, name)
    local mover = {}
    local tween
    local own = 0 -- the player's own value, kept while the Effect holds the CVar

    local function Write(value)
        SetCVar(name, string.format("%.3f", value))
    end

    -- The full duration is the way between the player's own value and target;
    -- a shorter way takes proportionally less time.
    local function MoveTo(goal, target, seconds, finished)
        local span = math.abs(target - own)
        local time = 0
        if span > 0 then
            time = seconds * math.abs(goal - tween.value) / span
        end
        tween:MoveTo(goal, time, finished)
    end

    function mover:IsAvailable()
        return GetCVar(name) ~= nil
    end

    function mover:Shift(target, seconds)
        own = tonumber(ns.HoldCVar(owner, name, tostring(target))) or 0
        if not tween then
            tween = ns.CreateTween(tonumber(GetCVar(name)) or own, Write)
        end
        MoveTo(target, target, seconds)
    end

    -- Back to the player's value; then the owner's other kept CVars return too.
    function mover:Return(target, seconds)
        MoveTo(own, target, seconds, function()
            ns.RestoreCVars(owner)
        end)
    end

    -- At once, e.g. while the player drags the slider.
    function mover:Jump(target)
        ns.HoldCVar(owner, name, tostring(target))
        tween:MoveTo(target, 0)
    end

    return mover
end
