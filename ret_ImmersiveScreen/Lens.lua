local addonName, ns = ...

-- Keys: each Effect turns on and off with its own key, unless it is in the
-- Combined Lens; then only the Combined Lens key controls it. So an Effect
-- has exactly one key at any time, and there are no transitions between
-- lenses to manage.

-- Names in the game's Key Bindings; the bindings themselves are in Bindings.xml.
BINDING_HEADER_RETIMMERSIVESCREEN = addonName
BINDING_NAME_RETIMMERSIVESCREEN_COMBINEDLENS = "Combined Lens"
BINDING_NAME_RETIMMERSIVESCREEN_HIDEUI = "HideUI"
BINDING_NAME_RETIMMERSIVESCREEN_LETTERBOX = "Letterbox"
BINDING_NAME_RETIMMERSIVESCREEN_CAMERASHIFT = "CameraShift"
BINDING_NAME_RETIMMERSIVESCREEN_FOV = "FOV"

ns.COMBINED_LENS = "CombinedLens"

local active = {} -- Effects their key has turned on

-- Binding action of an Effect or of the Combined Lens.
function ns.GetBindingAction(key)
    return "RETIMMERSIVESCREEN_" .. key:upper()
end

function ns.IsInCombinedLens(moduleKey)
    return ns.GetSetting(moduleKey, "combined")
end

local UpdateEscape

local function SetActive(module, on)
    if (active[module.key] == true) == on then
        return
    end
    active[module.key] = on or nil
    local method = on and module.Activate or module.Deactivate
    if method then
        ns.SafeCall(method, module)
    end
    UpdateEscape()
end

local function DeactivateAll()
    for _, module in ipairs(ns.moduleList) do
        if active[module.key] then
            SetActive(module, false)
        end
    end
end

--------------------------------------------------------------------------------
-- Esc
--------------------------------------------------------------------------------

-- While an Effect is on, the first Esc turns every Effect off and does nothing
-- else; the next one works as usual. For that, an override binding sends the
-- game menu's keys to our button.
--
-- Override bindings cannot change in combat. So they are lifted when combat
-- starts (PLAYER_REGEN_DISABLED still allows it) and set again after it. In
-- combat Esc works as usual, and a hook after ToggleGameMenu turns the Effects
-- off. RegisterGameMenuEscHandler must not be used: it sorts Blizzard's handler
-- table from addon code, and the tainted table then blocks protected calls of
-- later handlers, e.g. SpellStopCasting().

local escapeButton -- created when an Effect is first turned on
local escapeBound = false

local function SetEscapeBound(bound)
    if bound == escapeBound then
        return
    end
    if bound then
        local keys = { GetBindingKey("TOGGLEGAMEMENU", nil, ns.GetBindingContext("TOGGLEGAMEMENU")) }
        if #keys == 0 then
            keys[1] = "ESCAPE"
        end
        for _, key in ipairs(keys) do
            SetOverrideBindingClick(escapeButton, true, key, escapeButton:GetName())
        end
    else
        ClearOverrideBindings(escapeButton)
    end
    escapeBound = bound
end

local function CreateEscape()
    escapeButton = CreateFrame("Button", "RetImmersiveScreenEscapeButton")
    escapeButton:SetScript("OnClick", DeactivateAll)
    escapeButton:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            SetEscapeBound(false)
        else
            UpdateEscape()
        end
    end)
    -- A hook cannot be removed, so it is set once.
    hooksecurefunc("ToggleGameMenu", function()
        if next(active) then
            DeactivateAll()
        end
    end)
end

function UpdateEscape()
    local anyActive = next(active) ~= nil
    if anyActive and not escapeButton then
        CreateEscape()
    end
    if not escapeButton then
        return
    end
    if anyActive then
        escapeButton:RegisterEvent("PLAYER_REGEN_DISABLED")
        escapeButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        escapeButton:UnregisterAllEvents()
    end
    if not InCombatLockdown() then
        SetEscapeBound(anyActive)
    end
end

--------------------------------------------------------------------------------
-- Keys
--------------------------------------------------------------------------------

local function ToggleEffect(key)
    local module = ns.GetModule(key)
    if module and module.lens and ns.IsRunning(key) and not ns.IsInCombinedLens(key) then
        SetActive(module, not active[key])
    end
end

-- If any of its Effects is on, the key turns them all off; otherwise all on.
-- One press always gives a clear state, even if the set changed meanwhile.
-- With Escape Button on, turning it off acts as Esc: every Effect goes off.
local function ToggleCombinedLens()
    local members = {}
    local anyActive = false
    for _, module in ipairs(ns.moduleList) do
        if module.lens and ns.IsRunning(module.key) and ns.IsInCombinedLens(module.key) then
            table.insert(members, module)
            anyActive = anyActive or active[module.key] == true
        end
    end
    if anyActive and ns.GetSetting("Lens", "escapeButton") then
        DeactivateAll()
        return
    end
    for _, module in ipairs(members) do
        SetActive(module, not anyActive)
    end
end

-- Called by the bindings in Bindings.xml.
function RetImmersiveScreen_OnBinding(key)
    if key == ns.COMBINED_LENS then
        ToggleCombinedLens()
    else
        ToggleEffect(key)
    end
end
