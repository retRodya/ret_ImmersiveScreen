local _, ns = ...

-- Whether chat has focus (Enter, or a click into the chat input), for the
-- Effects and LiteRP features that let the player see chat while typing.
-- The chat input reports its focus through EventRegistry, in Retail and
-- Forever; subscribing there does not taint the game's code.
--
-- While HideUI hides the interface, the chat input cannot take focus: the game
-- opens it with ChatFrameUtil.ActivateChat, which our OnOpen listeners hear
-- first, so they can bring the interface back and give the input its focus.
-- A mechanism only: it subscribes on first use.

ns.ChatFocus = {
    SECONDS = 0.3, -- the interface and the bar opacity follow chat focus this fast
    BAR_ALPHA = 0.5, -- bar opacity while chat has focus
}

local focused = false
local listeners = {}
local openListeners = {}
local installed = false

local function SetFocused(value)
    if focused == value then
        return
    end
    focused = value
    for _, listener in ipairs(listeners) do
        ns.SafeCall(listener, value)
    end
end

local function OnOpen(editBox)
    for _, listener in ipairs(openListeners) do
        ns.SafeCall(listener, editBox)
    end
end

local function Install()
    if installed then
        return
    end
    installed = true
    if EventRegistry and EventRegistry.RegisterCallback then
        local owner = {}
        EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function()
            SetFocused(true)
        end, owner)
        for _, event in ipairs({ "ChatFrame.OnEditBoxFocusLost", "ChatFrame.OnEditBoxHide" }) do
            EventRegistry:RegisterCallback(event, function()
                SetFocused(false)
            end, owner)
        end
    end
    if ChatFrameUtil and ChatFrameUtil.ActivateChat then
        hooksecurefunc(ChatFrameUtil, "ActivateChat", OnOpen)
    elseif ChatEdit_ActivateChat then
        hooksecurefunc("ChatEdit_ActivateChat", OnOpen)
    end
end

function ns.ChatFocus.IsFocused()
    return focused
end

-- listener(focused) runs whenever chat gains or loses focus.
function ns.ChatFocus.Subscribe(listener)
    Install()
    table.insert(listeners, listener)
end

-- listener(editBox) runs after the game opened the chat input.
function ns.ChatFocus.OnOpen(listener)
    Install()
    table.insert(openListeners, listener)
end
