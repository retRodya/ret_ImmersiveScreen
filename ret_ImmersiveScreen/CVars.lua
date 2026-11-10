local _, ns = ...

-- Game settings (CVars) that an Effect changes for a while, e.g. the names
-- HideUI turns off. The original values come back when the Effect ends,
-- on /reload and on logout.
--
-- Changes are written one CVar at a time, WRITE_INTERVAL apart: each write
-- makes the game update the names of every unit around, and many writes close
-- together drop the FPS. On logout and /reload everything goes back at once.
--
-- SavedVariables are written only on a clean exit, so the originals of a session
-- that crashed are lost. For that case the values from the last clean exit are
-- kept too: if at login a CVar still holds the value we forced, it gets the
-- kept value back.

local GetCVar = C_CVar and C_CVar.GetCVar or GetCVar
local SetCVar = C_CVar and C_CVar.SetCVar or SetCVar

local WRITE_INTERVAL = 0.1 -- seconds between two CVar writes

local originals = {} -- originals[owner][name]: the value before the change
local queue = {} -- CVar names waiting to be written, oldest first
-- pending[name] = { value = <to write>, restores = <owner whose original this is, if any> }
local pending = {}
local events = CreateFrame("Frame")

-- Saved: baseline[name] = { value = <at the last clean exit>, forced = <our value> }.
local function GetBaseline()
    return ns.GetSaved("cvarBaseline")
end

local sinceWrite = 0

-- OnUpdate runs only while the queue has CVars in it.
local function WriteNext(_, elapsed)
    sinceWrite = sinceWrite + elapsed
    if sinceWrite < WRITE_INTERVAL then
        return
    end
    sinceWrite = 0
    local name = table.remove(queue, 1)
    local job = name and pending[name]
    -- A job is gone if HoldCVar took the CVar back meanwhile.
    if job then
        pending[name] = nil
        if GetCVar(name) ~= job.value then
            SetCVar(name, job.value)
        end
        -- Back to the original: the Effect no longer holds this CVar.
        local kept = job.restores and originals[job.restores]
        if kept then
            kept[name] = nil
        end
    end
    if #queue == 0 then
        events:SetScript("OnUpdate", nil)
    end
end

-- A newer wish for the same CVar replaces the waiting one and keeps its place.
local function Queue(name, value, restores)
    if not pending[name] then
        table.insert(queue, name)
    end
    pending[name] = { value = value, restores = restores }
    -- The first write comes on the next frame, the rest WRITE_INTERVAL apart.
    if not events:GetScript("OnUpdate") then
        sinceWrite = WRITE_INTERVAL
        events:SetScript("OnUpdate", WriteNext)
    end
end

-- Remembers the original before the first change; the baseline notes what we force.
local function Keep(owner, name, current, forced)
    local kept = originals[owner]
    if not kept then
        kept = {}
        originals[owner] = kept
    end
    if kept[name] == nil then
        kept[name] = current
        events:RegisterEvent("PLAYER_LOGOUT")
    end
    GetBaseline()[name] = { value = kept[name], forced = forced }
    return kept[name]
end

-- Skips CVars the client does not have. While the original is still waiting
-- to be written back, it stays kept and the restore is cancelled.
-- now: written at once instead of queued, for a CVar another change depends on.
function ns.SetTemporaryCVar(owner, name, value, now)
    local current = GetCVar(name)
    if current == nil then
        return
    end
    Keep(owner, name, current, value)
    if not now then
        Queue(name, value)
        return
    end
    if pending[name] then
        pending[name] = { value = value }
    end
    if current ~= value then
        SetCVar(name, value)
    end
end

-- For a CVar the Effect writes itself, e.g. every frame of an animation:
-- keeps the original like SetTemporaryCVar and returns it. forced is the value
-- the Effect is heading for, for the crash check at login.
function ns.HoldCVar(owner, name, forced)
    local current = GetCVar(name)
    if current == nil then
        return nil
    end
    -- A restore still waiting in the queue would undo the Effect's own writes.
    pending[name] = nil
    return Keep(owner, name, current, forced)
end

-- The value as the player set it: the kept original while an Effect holds the CVar.
function ns.GetOriginalCVar(owner, name)
    local kept = originals[owner]
    if kept and kept[name] ~= nil then
        return kept[name]
    end
    return GetCVar(name)
end

function ns.RestoreCVars(owner)
    local kept = originals[owner]
    if not kept then
        return
    end
    for name, value in pairs(kept) do
        Queue(name, value, owner)
    end
end

-- The game may return a number CVar in another format, e.g. "1.500000" for "1.5".
local function SameValue(a, b)
    if a == b then
        return true
    end
    local x, y = tonumber(a), tonumber(b)
    return x ~= nil and y ~= nil and math.abs(x - y) < 0.001
end

-- After a crash: a CVar that still holds our forced value gets back the value
-- it had at the last clean exit.
local function RecoverAfterCrash()
    for name, entry in pairs(GetBaseline()) do
        if not SameValue(entry.value, entry.forced) and SameValue(GetCVar(name), entry.forced) then
            SetCVar(name, entry.value)
        end
    end
end

-- Logout and /reload: everything goes back at once, and the baseline takes
-- the values the player has now, including changes made in the game's options.
local function RestoreAll()
    wipe(queue)
    wipe(pending)
    events:SetScript("OnUpdate", nil)
    for owner, kept in pairs(originals) do
        for name, value in pairs(kept) do
            if GetCVar(name) ~= value then
                SetCVar(name, value)
            end
        end
        originals[owner] = nil
    end
    for name, entry in pairs(GetBaseline()) do
        entry.value = GetCVar(name) or entry.value
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        RecoverAfterCrash()
        if next(GetBaseline()) then
            self:RegisterEvent("PLAYER_LOGOUT")
        end
    elseif event == "PLAYER_LOGOUT" then
        RestoreAll()
    end
end)
