local _, ns = ...

-- Controls shared by the window's pages: tooltips, undo buttons,
-- setting rows (checkbox, slider) and key buttons.

local CHECKBOX_HEIGHT = 28
local SLIDER_HEIGHT = 36
local SLIDER_X, SLIDER_WIDTH = 150, 170
-- The slider shows its value 6 px right of its frame; the undo button goes after it.
local SLIDER_UNDO_X = 56
local KEY_BUTTON_WIDTH = 140
local NOT_BOUND_TEXT = NOT_BOUND or "Not bound"

local function HasTemplate(name)
    return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

-- Retail's AddOns list uses the minimal checkbox; clients without it get the classic one.
local CHECKBOX_TEMPLATE = HasTemplate("MinimalCheckboxTemplate") and "MinimalCheckboxTemplate"
    or "UICheckButtonTemplate"
ns.CHECKBOX_TEMPLATE = CHECKBOX_TEMPLATE
-- The key buttons of the game's Key Bindings, where the client has them.
local KEY_BUTTON_TEMPLATE = HasTemplate("UIMenuButtonStretchTemplate") and "UIMenuButtonStretchTemplate"
    or "UIPanelButtonTemplate"

function ns.ShowTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR:GetRGB())
    local r, g, b = NORMAL_FONT_COLOR:GetRGB()
    GameTooltip:AddLine(text, r, g, b, true)
    GameTooltip:Show()
end

function ns.PlayCheckboxSound(checked)
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

-- Shown next to anything the player changed since the UI loaded,
-- so all changes are visible at a glance before the next reload.
function ns.CreateUndoButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    button:Hide()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("common-icon-undo")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetAtlas("common-icon-undo")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnEnter", function(self)
        ns.ShowTooltip(self, "Undo change", "Restores the state from the last UI reload.")
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    return button
end

--------------------------------------------------------------------------------
-- Setting rows
--------------------------------------------------------------------------------

-- A row is { frame, height, Update }. A disabled row belongs to a placeholder:
-- it shows the default value greyed out and cannot be changed.

local function CreateCheckboxRow(parent, ownerKey, setting, label, disabled)
    local checkbox = CreateFrame("CheckButton", nil, parent, CHECKBOX_TEMPLATE)
    checkbox:SetSize(24, 24)

    local text = checkbox:CreateFontString(nil, "ARTWORK", disabled and "GameFontDisable" or "GameFontHighlight")
    text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    text:SetText(label)
    -- Clicking the name toggles the checkbox too.
    checkbox:SetHitRectInsets(0, -(text:GetStringWidth() + 4), 0, 0)
    checkbox:SetEnabled(not disabled)

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        ns.PlayCheckboxSound(checked)
        ns.SetSetting(ownerKey, setting.key, checked)
        ns.RefreshWindow()
    end)
    checkbox:SetScript("OnEnter", function(self)
        ns.ShowTooltip(self, setting.title, setting.description)
    end)
    checkbox:SetScript("OnLeave", GameTooltip_Hide)

    local undo = ns.CreateUndoButton(checkbox)
    undo:SetPoint("LEFT", text, "RIGHT", 6, 0)
    undo:SetScript("OnClick", function()
        ns.UndoSetting(ownerKey, setting.key)
        ns.RefreshWindow()
    end)

    return {
        frame = checkbox,
        height = CHECKBOX_HEIGHT,
        Update = function()
            checkbox:SetChecked(ns.GetSetting(ownerKey, setting.key))
            undo:SetShown(ns.IsSettingChanged(ownerKey, setting.key))
        end,
    }
end

-- Rounded to a few decimals, so a value read back from SavedVariables
-- compares equal to the one the slider produced.
local function RoundToStep(setting, value)
    local steps = math.floor((value - setting.min) / setting.step + 0.5)
    return tonumber(string.format("%.3f", setting.min + steps * setting.step))
end

-- The slider of the game's Settings panel, the same in Retail and Forever.
local function CreateSliderRow(parent, ownerKey, setting, label, disabled)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(SLIDER_HEIGHT)
    frame:EnableMouse(true)

    local text = frame:CreateFontString(nil, "ARTWORK", disabled and "GameFontDisable" or "GameFontHighlight")
    text:SetPoint("LEFT", 4, 0)
    text:SetWidth(SLIDER_X - 8)
    text:SetJustifyH("LEFT")
    text:SetText(label)

    local slider = CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(SLIDER_WIDTH)
    slider:SetPoint("LEFT", SLIDER_X, 0)
    local right = MinimalSliderWithSteppersMixin.Label.Right
    slider:Init(ns.GetSetting(ownerKey, setting.key), setting.min, setting.max,
        math.floor((setting.max - setting.min) / setting.step + 0.5), {
            [right] = CreateMinimalSliderFormatter(right, function(value)
                return string.format(setting.format, value)
            end),
        })
    slider:SetEnabled(not disabled)

    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = RoundToStep(setting, value)
        if value ~= ns.GetSetting(ownerKey, setting.key) then
            ns.SetSetting(ownerKey, setting.key, value)
            ns.RefreshWindow()
        end
    end, frame)

    local function ShowSettingTooltip(owner)
        ns.ShowTooltip(owner, setting.title, setting.description)
    end
    frame:SetScript("OnEnter", ShowSettingTooltip)
    frame:SetScript("OnLeave", GameTooltip_Hide)
    -- HookScript: the slider's own OnEnter and OnLeave drive its hover look.
    slider.Slider:HookScript("OnEnter", ShowSettingTooltip)
    slider.Slider:HookScript("OnLeave", GameTooltip_Hide)

    local undo = ns.CreateUndoButton(frame)
    undo:SetPoint("LEFT", slider, "RIGHT", SLIDER_UNDO_X, 0)
    undo:SetScript("OnClick", function()
        ns.UndoSetting(ownerKey, setting.key)
        ns.RefreshWindow()
    end)

    return {
        frame = frame,
        height = SLIDER_HEIGHT,
        Update = function()
            local value = ns.GetSetting(ownerKey, setting.key)
            if slider.Slider:GetValue() ~= value then
                slider:SetValue(value)
            end
            undo:SetShown(ns.IsSettingChanged(ownerKey, setting.key))
        end,
    }
end

function ns.CreateSettingRow(parent, ownerKey, setting, label, disabled)
    if setting.type == "slider" then
        return CreateSliderRow(parent, ownerKey, setting, label, disabled)
    end
    return CreateCheckboxRow(parent, ownerKey, setting, label, disabled)
end

-- The owner's visible settings, one under another. Returns the rows.
function ns.CreateSettingRows(parent, ownerKey, settings, disabled)
    local rows = {}
    local y = 0
    for _, setting in ipairs(settings) do
        if not setting.hidden then
            local row = ns.CreateSettingRow(parent, ownerKey, setting, setting.title, disabled)
            row.frame:SetPoint("TOPLEFT", 0, y)
            if setting.type == "slider" then
                row.frame:SetPoint("TOPRIGHT", 0, y)
            end
            y = y - row.height
            table.insert(rows, row)
        end
    end
    return rows
end

--------------------------------------------------------------------------------
-- Key buttons
--------------------------------------------------------------------------------

-- Click, then press a key: it is saved to the game's key bindings at once, the
-- same bindings as in Key Bindings. Right-click clears the key. Works like the
-- game's own Key Bindings panel (Blizzard_Keybindings.lua) and shows its messages.

local listening -- the key button waiting for a key press

-- The game keeps bindings per context; its Key Bindings panel always passes the action's.
local function GetContext(action)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        return C_KeyBindings.GetBindingContextForAction(action)
    end
end

-- False if the game did not load the action from Bindings.xml.
local function IsKnownAction(action)
    if C_KeyBindings and C_KeyBindings.GetBindingIndex then
        return C_KeyBindings.GetBindingIndex(action) ~= nil
    end
    return true
end

local function StopListening()
    if listening then
        local button = listening
        listening = nil
        -- A frame with an OnKeyDown script takes the keyboard, so the script
        -- exists only while a button waits for a key.
        button:SetScript("OnKeyDown", nil)
        button:EnableKeyboard(false)
        button:UnlockHighlight()
        button:Update()
    end
end
ns.StopKeyListening = StopListening

-- Makes key the action's first key and keeps its second one. Returns the game's
-- message: the key is bound, or which command lost its key to it.
local function BindKey(action, key)
    local context = GetContext(action)
    local key1, key2 = GetBindingKey(action, nil, context)
    if key1 then
        SetBinding(key1, nil, context)
    end
    if key2 then
        SetBinding(key2, nil, context)
    end

    local message = KEY_BOUND
    local oldAction = GetBindingAction(key, nil, context)
    if oldAction ~= "" and oldAction ~= action then
        local old1, old2 = GetBindingKey(oldAction, nil, context)
        if old1 == key and old2 then
            message = PRIMARY_KEY_UNBOUND_ERROR:format(GetBindingName(oldAction))
        elseif (not old1 or old1 == key) and (not old2 or old2 == key) then
            message = KEY_UNBOUND_ERROR:format(GetBindingName(oldAction))
        end
    end

    if not SetBinding(key, action, context) then
        -- The game refused the key: everything stays as it was.
        if key1 then
            SetBinding(key1, action, context)
        end
        if key2 then
            SetBinding(key2, action, context)
        end
        return nil
    end
    if key2 and key2 ~= key then
        SetBinding(key2, action, context)
    end
    SaveBindings(GetCurrentBindingSet())
    return message
end

-- As in the game's panel, the second key, if any, becomes the first.
local function ClearKey(action)
    local context = GetContext(action)
    local key1, key2 = GetBindingKey(action, nil, context)
    if key1 then
        SetBinding(key1, nil, context)
    end
    if key2 then
        SetBinding(key2, action, context)
    end
    SaveBindings(GetCurrentBindingSet())
end

-- status: a font string on the page for the game's binding messages.
function ns.CreateKeyButton(parent, action, status)
    local button = CreateFrame("Button", nil, parent, KEY_BUTTON_TEMPLATE)
    button:SetSize(KEY_BUTTON_WIDTH, 22)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- While set, the text replaces the key and the button is disabled, e.g. "Combined Lens".
    function button:SetLockedText(text)
        self.lockedText = text
        self:Update()
    end

    function button:Update()
        self:SetEnabled(not self.lockedText)
        local key = GetBindingKey(action, nil, GetContext(action))
        self:SetText(self.lockedText or (key and GetBindingText(key)) or NOT_BOUND_TEXT)
    end

    local function OnKeyDown(self, key)
        if listening ~= self then
            return
        end
        if key == "ESCAPE" then
            StopListening()
            status:SetText(nil)
            return
        end
        -- Wait for the main key while only modifiers are held.
        if IsKeyPressIgnoredForBinding(key) then
            return
        end
        -- Release the keyboard first: whatever happens next, the game gets its keys back.
        StopListening()
        if InCombatLockdown() then
            status:SetText(ERR_NOT_IN_COMBAT)
            return
        end
        status:SetText(BindKey(action, CreateKeyChordStringUsingMetaKeyState(key)))
        ns.RefreshWindow()
    end

    button:SetScript("OnClick", function(self, mouseButton)
        local wasListening = listening == self
        StopListening()
        status:SetText(nil)
        if wasListening then
            return
        end
        if InCombatLockdown() then
            status:SetText(ERR_NOT_IN_COMBAT)
            return
        end
        if mouseButton == "RightButton" then
            ClearKey(action)
            ns.RefreshWindow()
            return
        end
        if not IsKnownAction(action) then
            status:SetText("The game has not loaded this addon's keys. Restart the game.")
            return
        end
        listening = self
        self:LockHighlight()
        self:SetScript("OnKeyDown", OnKeyDown)
        self:EnableKeyboard(true)
        status:SetText(SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL:format(GetBindingName(action), GetBindingText("ESCAPE")))
    end)

    button:SetScript("OnHide", StopListening)
    button:SetScript("OnEnter", function(self)
        ns.ShowTooltip(self, "Key", "Click, then press a key. Right-click clears the key. Escape cancels.")
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    return button
end
