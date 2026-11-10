local _, ns = ...

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
