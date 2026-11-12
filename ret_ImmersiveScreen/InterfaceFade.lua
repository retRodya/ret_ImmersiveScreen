local _, ns = ...

-- Fades the whole interface (UIParent). Out and In fade it to transparent and
-- back without hiding it: during the logout countdown it must stay shown, since
-- hiding its dialog cancels the logout. The minimap draws its pins regardless
-- of its parent's opacity, so it is hidden once the interface is transparent.
-- Frames that must stay visible, e.g. that dialog, can be kept opaque.
-- Reveal and Conceal fade in and out an interface hidden as Alt+Z does.
-- A mechanism only: it creates its frame on first use.

ns.InterfaceFade = {}

local tween
local faded = false -- Out was called and In not yet
-- The opacity before the first Out, kept until In has fully brought it back:
-- an Out in the middle of an In must not take a half-way value for it.
local alphaBefore
local minimapHidden = false
local kept = {} -- kept[frame] = whether it ignored its parent's opacity before

local function SetMinimapHidden(hidden)
    if not MinimapCluster then
        return
    end
    if hidden and MinimapCluster:IsShown() then
        MinimapCluster:Hide()
        minimapHidden = true
    elseif not hidden and minimapHidden then
        MinimapCluster:Show()
        minimapHidden = false
    end
end

local function FadeTo(alpha, seconds, finished)
    if not tween then
        tween = ns.CreateTween(UIParent:GetAlpha(), function(value)
            UIParent:SetAlpha(value)
        end)
    end
    -- Someone else may have changed it since our last step.
    tween.value = UIParent:GetAlpha()
    tween:MoveTo(alpha, seconds, finished)
end

-- Only a shown interface fades; a hidden one (Alt+Z, HideUI) has nothing to fade.
function ns.InterfaceFade.Out(seconds)
    if not UIParent:IsShown() then
        return
    end
    faded = true
    alphaBefore = alphaBefore or UIParent:GetAlpha()
    FadeTo(0, seconds, function()
        SetMinimapHidden(true)
    end)
end

function ns.InterfaceFade.In(seconds)
    if not faded then
        return
    end
    faded = false
    SetMinimapHidden(false)
    for frame, ignored in pairs(kept) do
        frame:SetIgnoreParentAlpha(ignored)
    end
    wipe(kept)
    FadeTo(alphaBefore, seconds, function()
        alphaBefore = nil
    end)
end

-- For HideUI: brings back an interface hidden as Alt+Z does, fading it in.
-- Also brings a half faded one back to full, cancelling a Conceal.
function ns.InterfaceFade.Reveal(seconds)
    if not UIParent:IsShown() then
        UIParent:SetAlpha(0)
        SetUIVisibility(true)
    end
    FadeTo(1, seconds)
end

-- Fades the interface out, then hides it as Alt+Z does, opaque again for
-- whoever shows it next.
function ns.InterfaceFade.Conceal(seconds)
    FadeTo(0, seconds, function()
        SetUIVisibility(false)
        UIParent:SetAlpha(1)
        tween.value = 1
    end)
end

function ns.InterfaceFade.IsFaded()
    return faded
end

-- Stays opaque while the interface fades, until In.
function ns.InterfaceFade.Keep(frame)
    if not faded or kept[frame] ~= nil then
        return
    end
    kept[frame] = frame.IsIgnoringParentAlpha and frame:IsIgnoringParentAlpha() or false
    frame:SetIgnoreParentAlpha(true)
end
