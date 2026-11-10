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

ns.COMBINED_LENS = "CombinedLens"

local active = {} -- Effects their key has turned on

-- Binding action of an Effect or of the Combined Lens.
function ns.GetBindingAction(key)
    return "RETIMMERSIVESCREEN_" .. key:upper()
end

function ns.IsInCombinedLens(moduleKey)
    return ns.GetSetting(moduleKey, "combined")
end

local function SetActive(module, on)
    if (active[module.key] == true) == on then
        return
    end
    active[module.key] = on or nil
    local method = on and module.Activate or module.Deactivate
    if method then
        ns.SafeCall(method, module)
    end
end

local function ToggleEffect(key)
    local module = ns.GetModule(key)
    if module and module.lens and ns.IsRunning(key) and not ns.IsInCombinedLens(key) then
        SetActive(module, not active[key])
    end
end

-- If any of its Effects is on, the key turns them all off; otherwise all on.
-- One press always gives a clear state, even if the set changed meanwhile.
local function ToggleCombinedLens()
    local members = {}
    local anyActive = false
    for _, module in ipairs(ns.moduleList) do
        if module.lens and ns.IsRunning(module.key) and ns.IsInCombinedLens(module.key) then
            table.insert(members, module)
            anyActive = anyActive or active[module.key] == true
        end
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
