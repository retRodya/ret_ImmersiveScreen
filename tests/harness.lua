-- Stand-ins for the WoW API, enough to load the addon outside the game and
-- drive it: frames with scripts and events, CVars, key bindings, Alt+Z and Esc.
-- They check behaviour (what gets called, with which values), not looks.
--
--   local T = dofile("tests/harness.lua")
--   local ns = T.Load({ db = { ... }, cvars = { ... } })

local ADDON = "ret_ImmersiveScreen"
local T = { frames = {}, unregistered = {}, overrides = {}, dialogs = {} }
local frames = T.frames
local function noop() end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

local Object = {}
Object.__index = function(_, key)
    local method = rawget(Object, key)
    if method then
        return method
    end
    -- Unknown WoW methods do nothing; plain fields stay nil.
    if type(key) == "string" and key:match("^%u") then
        return noop
    end
end

local function New(kind, name, parent)
    local o = setmetatable({
        kind = kind, name = name, parent = parent, scripts = {},
        shown = true, enabled = true, alpha = 1, ignoreParentAlpha = false,
    }, Object)
    if name then
        _G[name] = o
    end
    table.insert(frames, o)
    return o
end
T.New = New

function Object:SetScript(name, func) self.scripts[name] = func end
function Object:GetScript(name) return self.scripts[name] end
function Object:HookScript(name, func)
    local old = self.scripts[name]
    self.scripts[name] = function(...)
        if old then old(...) end
        func(...)
    end
end
function Object:CreateFontString(name, _, font)
    local text = New("FontString", name, self)
    text.font = font
    text.row = self
    return text
end
function Object:CreateTexture() return New("Texture", nil, self) end
function Object:SetText(text)
    assert(text == nil or type(text) == "string" or type(text) == "number", "SetText with " .. type(text))
    self.text = text
end
function Object:GetText() return self.text end
function Object:GetStringWidth() return 50 end
function Object:SetFontObject(font) assert(type(font) == "string", "font object") self.font = font end
-- Like the game: OnShow and OnHide run only when the state changes.
function Object:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Object:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Object:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Object:IsShown() return self.shown end
function Object:IsMouseOver() return false end
function Object:SetChecked(checked) self.checked = not not checked end
function Object:GetChecked() return self.checked end
function Object:SetEnabled(enabled) self.enabled = not not enabled end
function Object:Enable() self.enabled = true end
function Object:Disable() self.enabled = false end
function Object:IsEnabled() return self.enabled end
function Object:GetName() return self.name end
function Object:SetAlpha(alpha) self.alpha = alpha end
function Object:GetAlpha() return self.alpha end
function Object:SetIgnoreParentAlpha(ignore) self.ignoreParentAlpha = ignore end
function Object:IsIgnoringParentAlpha() return self.ignoreParentAlpha end
function Object:SetHeight(height) self.height = height end
function Object:GetHeight() return 1000 end
function Object:GetValue() return self.value or 0 end
function Object:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Object:Click(button)
    if self.kind == "CheckButton" then self.checked = not self.checked end
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end
function Object:RegisterEvent(event) self.events = self.events or {} self.events[event] = true end
function Object:UnregisterEvent(event) if self.events then self.events[event] = nil end end
function Object:UnregisterAllEvents() self.events = {} end

-- MinimalSliderWithSteppersTemplate: Init, RegisterCallback, SetValue, SetEnabled.
local function MakeSlider(o)
    o.Slider = New("Slider", nil, o)
    function o:Init(value, min, max, steps, formatters)
        assert(type(value) == "number" and min < max and steps > 0, "slider init")
        for _, format in pairs(formatters) do assert(type(format(value)) == "string") end
        self.Slider.value = value
    end
    function o:RegisterCallback(_, func, owner) self.callback = function(v) func(owner, v) end end
    function o:SetValue(value)
        self.Slider.value = value
        if self.callback then self.callback(value) end
    end
    function o:SetEnabled(enabled) self.sliderEnabled = enabled end
end

function CreateFrame(kind, name, parent, template)
    local o = New(kind, name, parent)
    o.template = template
    if template == "MinimalSliderWithSteppersTemplate" then MakeSlider(o) end
    if template == "ButtonFrameTemplate" then o.Inset = New("Frame", nil, o) end
    return o
end

--------------------------------------------------------------------------------
-- Game API
--------------------------------------------------------------------------------

C_XMLUtil = { GetTemplateInfo = function(name) return name ~= "UIMenuButtonStretchTemplate" and {} or nil end }
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "0.1.0-dev" or ("[" .. field .. "]") end }
MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
function CreateMinimalSliderFormatter(_, format) return format end
HIGHLIGHT_FONT_COLOR = { GetRGB = function() return 1, 1, 1 end }
NORMAL_FONT_COLOR = HIGHLIGHT_FONT_COLOR
SOUNDKIT = {}
PlaySound = noop
GameTooltip_Hide = noop
UISpecialFrames = {}
ButtonFrameTemplate_HidePortrait = noop
RELOADUI = "Reload UI"
ReloadUI = noop
SlashCmdList = {}
Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = noop }
unpack = unpack or table.unpack
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
geterrorhandler = function()
    return function(err)
        io.stderr:write("ERROR in addon code: " .. tostring(err) .. "\n")
        os.exit(1)
    end
end

-- Key bindings, per context like the game's.
local CONTEXT = 7
T.bindings = { W = "MOVEFORWARD", ESCAPE = "TOGGLEGAMEMENU", ["CTRL-J"] = "JUMP" }
local function CheckContext(context) assert(context == CONTEXT, "binding context not passed") end
C_KeyBindings = {
    GetBindingContextForAction = function() return CONTEXT end,
    GetBindingIndex = function(action) return action:match("^RETIMMERSIVESCREEN_") and 1 or nil end,
}
function GetBindingKey(action, _, context)
    CheckContext(context)
    for key, bound in pairs(T.bindings) do if bound == action then return key end end
end
function GetBindingAction(key, _, context) CheckContext(context) return T.bindings[key] or "" end
function SetBinding(key, action, context) CheckContext(context) T.bindings[key] = action return true end
function GetBindingText(key) return key end
function GetBindingName(action) return _G["BINDING_NAME_" .. action] or action end
SaveBindings = noop
function GetCurrentBindingSet() return 1 end
function IsKeyPressIgnoredForBinding(key) return key:match("SHIFT") ~= nil end
function CreateKeyChordStringUsingMetaKeyState(key) return "CTRL-" .. key end
BINDING_NAME_JUMP = "Jump"
KEY_BOUND = "Key Bound Successfully"
KEY_UNBOUND_ERROR = 'Для команды "%s" не назначена клавиша!'
PRIMARY_KEY_UNBOUND_ERROR = "%s primary key unbound"
SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL = "Press a key to bind to %s, or %s to cancel."
ERR_NOT_IN_COMBAT = "You can't do that while in combat"

-- CVars; T.onCVarWrite(name, value) sees every write.
T.cvars = {
    UnitNameOwn = "0", UnitNameNPC = "1", ShowQuestUnitCircles = "1",
    UnitNameFriendlyPlayerName = "1", UnitNameFriendlyMinionName = "1",
    UnitNameEnemyPlayerName = "0", UnitNameEnemyMinionName = "1",
    UnitNameFocused = "1", SoftTargetIconInteract = "1",
    test_cameraOverShoulder = "0", CameraKeepCharacterCentered = "1",
    CameraReduceUnexpectedMovement = "1", cameraFov = "90",
}
C_CVar = {
    GetCVar = function(name) return T.cvars[name] end,
    SetCVar = function(name, value)
        assert(T.cvars[name] ~= nil, "SetCVar on a CVar the client lacks: " .. name)
        assert(type(value) == "string", "SetCVar value must be a string: " .. name)
        T.cvars[name] = value
        if T.onCVarWrite then T.onCVarWrite(name, value) end
        return true
    end,
}
function GetCameraFOVDefaults() return 90, 50, 90 end

-- The interface, Alt+Z and Esc.
UIParent = New("Frame", "UIParent")
MinimapCluster = New("Frame", "MinimapCluster", UIParent)
GameTooltip = New("GameTooltip", "GameTooltip")
ActionStatus = New("Frame", "ActionStatus")
ActionStatus.events = { SCREENSHOT_SUCCEEDED = true }
T.closedWindows, T.menuOpened, T.inCombat = 0, 0, false
function SetUIVisibility(shown) UIParent.shown = shown end
function CloseMenus() end
function CloseAllWindows() T.closedWindows = T.closedWindows + 1 end
function securecall(func, ...) if type(func) == "string" then func = _G[func] end return func(...) end
function GetAppropriateTopLevelParent() return UIParent end
function RunBinding() error("RunBinding is protected") end
function InCombatLockdown() return T.inCombat end
-- Like the game's: the hook runs after the original, whose results are kept.
function hooksecurefunc(name, hook)
    local original = _G[name]
    _G[name] = function(...)
        local results = { original(...) }
        hook(...)
        return unpack(results)
    end
end
-- The game's Esc: a hidden interface comes back; otherwise the game menu opens.
function ToggleGameMenu()
    if not UIParent.shown then UIParent.shown = true return end
    T.menuOpened = T.menuOpened + 1
end
function SetOverrideBindingClick(_, _, key, buttonName)
    assert(not T.inCombat, "override binding changed in combat")
    T.overrides[key] = buttonName
end
function ClearOverrideBindings()
    assert(not T.inCombat, "override binding cleared in combat")
    wipe(T.overrides)
end
GameEvent = { UnregisterInternalEvent = function(event) T.unregistered[event] = true end }
-- EventRegistry callbacks get their owner first, like the game's CallbackRegistry.
T.callbacks = {}
EventRegistry = {
    RegisterCallback = function(_, event, func, owner)
        T.callbacks[event] = T.callbacks[event] or {}
        table.insert(T.callbacks[event], function(...) func(owner, ...) end)
    end,
}
function T.TriggerEvent(event, ...)
    for _, callback in ipairs(T.callbacks[event] or {}) do callback(...) end
end
CancelLogout = noop
function StaticPopup_Show(which)
    local dialog = T.dialogs[which] or New("Frame", nil, UIParent)
    T.dialogs[which] = dialog
    dialog.shown = true
    return dialog
end
function StaticPopup_FindVisible(which)
    local dialog = T.dialogs[which]
    return dialog and dialog.shown and dialog or nil
end

--------------------------------------------------------------------------------
-- Loading and driving
--------------------------------------------------------------------------------

function T.Fire(event, ...)
    for _, f in ipairs(frames) do
        local events = rawget(f, "events")
        if events and events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- options.db: saved settings to start with; options.cvars: CVars to add or change.
function T.Load(options)
    options = options or {}
    ret_ImmersiveScreenDB = options.db
    for name, value in pairs(options.cvars or {}) do T.cvars[name] = value end
    local ns = {}
    local toc = assert(io.open(ADDON .. "/" .. ADDON .. ".toc")):read("*a")
    for line in toc:gmatch("[^\r\n]+") do
        if not line:match("^#") and line:match("%.lua$") then
            assert(loadfile(ADDON .. "/" .. line:gsub("\\", "/")))(ADDON, ns)
        end
    end
    T.Fire("ADDON_LOADED", ADDON)
    T.Fire("PLAYER_LOGIN")
    return ns
end

function T.FindAll(test)
    local found = {}
    for _, f in ipairs(frames) do if test(f) then table.insert(found, f) end end
    return found
end

-- Every OnUpdate, in steps of 0.02 s.
function T.TickAll(seconds)
    for _ = 1, math.floor(seconds / 0.02 + 0.5) do
        for _, f in ipairs(frames) do
            local update = f.scripts.OnUpdate
            if update then update(f, 0.02) end
        end
    end
end

-- The CVar keeper's queue, until it is empty.
function T.FlushCVars()
    for _ = 1, 5000 do
        local keeper
        for _, f in ipairs(frames) do
            local events = rawget(f, "events")
            if events and events.PLAYER_LOGOUT and f.scripts.OnUpdate then keeper = f end
        end
        if not keeper then return end
        keeper.scripts.OnUpdate(keeper, 0.02)
    end
    error("CVar queue never empties")
end

function T.Bars()
    for _, f in ipairs(frames) do
        if f.kind == "Frame" and f.scripts.OnSizeChanged then return f end
    end
end

function T.BarHeight()
    local bars = T.Bars()
    for _, f in ipairs(frames) do
        if f.kind == "Texture" and f.parent == bars and rawget(f, "height") then return f.height end
    end
    return 0
end

-- An override binding wins over the game's TOGGLEGAMEMENU, as in the game.
function T.PressEscape()
    local button = T.overrides.ESCAPE
    if button then _G[button]:Click() else ToggleGameMenu() end
end

-- PLAYER_REGEN_DISABLED comes before the lockdown, PLAYER_REGEN_ENABLED after it.
function T.SetCombat(on)
    if on then
        T.Fire("PLAYER_REGEN_DISABLED")
        T.inCombat = true
    else
        T.inCombat = false
        T.Fire("PLAYER_REGEN_ENABLED")
    end
end

-- A font string with this text whose row is shown.
function T.RowShown(text)
    for _, f in ipairs(frames) do
        if f.kind == "FontString" and rawget(f, "text") == text and f.row and f.row.shown then return true end
    end
    return false
end

-- The slider of the row labelled text.
function T.Slider(text)
    for _, f in ipairs(frames) do
        if f.kind == "FontString" and rawget(f, "text") == text then
            for _, s in ipairs(frames) do
                if s.template == "MinimalSliderWithSteppersTemplate" and s.parent == f.row then return s end
            end
        end
    end
end

function T.Near(a, b, tolerance)
    return math.abs(a - b) <= (tolerance or 1e-6)
end

return T
