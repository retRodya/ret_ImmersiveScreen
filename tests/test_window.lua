-- The settings window: list, pages, settings with undo, key buttons.
local T = dofile("tests/harness.lua")
local ns = T.Load()

SlashCmdList.RETIMMERSIVESCREEN()
local window = RetImmersiveScreenFrame
assert(window and window.shown, "/retis opens the window")

-- The list in .toc order; every page opens.
local entries = T.FindAll(function(f) return f.kind == "Button" and rawget(f, "page") end)
local titles = {}
for _, entry in ipairs(entries) do
    table.insert(titles, entry.label.text)
    entry:Click()
end
assert(table.concat(titles, ",") == "General,Effects,HideUI,Letterbox,CameraShift,FOV,Lens,LiteRP,GoOffline,GoOnline",
    "list: " .. table.concat(titles, ","))

-- Defaults: HideUI and Letterbox on and in the Combined Lens, the rest off.
assert(ns.IsRunning("HideUI") and ns.IsRunning("Letterbox") and not ns.IsEnabled("CameraShift"))
assert(ns.IsInCombinedLens("HideUI") and ns.IsInCombinedLens("Letterbox") and not ns.IsInCombinedLens("FOV"))

-- A module turns on or off after /reload; the button shows meanwhile.
ns.SetEnabled("Letterbox", false)
ns.RefreshWindow()
assert(window.reloadButton.shown, "Reload UI shown")
ns.UndoModule("Letterbox")
ns.RefreshWindow()
assert(not window.reloadButton.shown, "undo hides it")

-- Sliders round to their step; undo goes back to the loaded value.
T.Slider("Bar height"):SetValue(7.26)
assert(ns.GetSetting("Letterbox", "height") == 7.5 and ns.IsSettingChanged("Letterbox", "height"), "rounded to 0.5")
ns.UndoSetting("Letterbox", "height")
assert(ns.GetSetting("Letterbox", "height") == 10)
print("  list, settings, undo ok")

-- General: the screenshot message.
ns.SetSetting("General", "hideScreenshotMessage", true)
assert(not ActionStatus.events.SCREENSHOT_SUCCEEDED, "hidden")
ns.SetSetting("General", "hideScreenshotMessage", false)
assert(ActionStatus.events.SCREENSHOT_SUCCEEDED, "back")

-- HideUI lists only names the game shows, plus the highlighted unit's name.
assert(T.RowShown("NPC names") and T.RowShown("Friendly players") and T.RowShown("Minions"))
assert(not T.RowShown("My name") and not T.RowShown("Enemy players"), "names off in the game are not listed")
assert(T.RowShown("Highlighted unit"))
T.cvars.UnitNameOwn = "1"
window.scripts.OnEvent(window, "CVAR_UPDATE", "UnitNameOwn")
assert(T.RowShown("My name"), "turned on in the game: listed at once")
T.cvars.UnitNameOwn = "0"
T.cvars.UnitNameFocused = "0"
window.scripts.OnEvent(window, "CVAR_UPDATE", "UnitNameFocused")
assert(not T.RowShown("My name") and T.RowShown("Highlighted unit"), "highlighted unit always listed")
print("  HideUI names list ok")

-- GoOffline: the fade duration shows only while the fade is on.
assert(T.RowShown("Interface fade duration"))
ns.SetSetting("GoOffline", "fadeInterface", false)
ns.RefreshWindow()
assert(not T.RowShown("Interface fade duration"), "hidden with its checkbox off")
ns.SetSetting("GoOffline", "fadeInterface", true)
ns.RefreshWindow()

-- Defaults and Test buttons.
local defaults, tests = {}, {}
for _, f in ipairs(T.frames) do
    if f.template == "UIPanelButtonTemplate" and rawget(f, "text") == "Defaults" then table.insert(defaults, f) end
    if f.template == "UIPanelButtonTemplate" and rawget(f, "text") == "Test" then table.insert(tests, f) end
end
assert(#defaults == 2 and #tests == 1, "Defaults on GoOffline and GoOnline, Test on GoOnline")
ns.SetSetting("GoOffline", "rate2", 9)
defaults[1]:Click()
assert(ns.GetSetting("GoOffline", "rate2") == 3, "Defaults resets the page")
print("  LiteRP pages ok")

-- Escape Button on the Lens page, off by default.
assert(T.RowShown("Escape Button") and ns.GetSetting("Lens", "escapeButton") == false)

-- Key buttons: nothing listens until a button is clicked.
local status
for _, f in ipairs(T.frames) do
    if f.kind == "FontString" and f.font == "GameFontHighlightSmall" then status = f end
end
local keyButtons = T.FindAll(function(f) return f.kind == "Button" and rawget(f, "SetLockedText") ~= nil end)
assert(#keyButtons == 5, "HideUI, Letterbox, CameraShift, FOV and Combined Lens")
local function PressKey(key)
    local takers = 0
    for _, f in ipairs(T.frames) do
        local handler = f.scripts.OnKeyDown
        if handler and f.shown then
            takers = takers + 1
            handler(f, key)
        end
    end
    return takers
end
assert(PressKey("W") == 0 and T.bindings.W == "MOVEFORWARD", "no frame takes keys before a click")

ns.SetSetting("Letterbox", "combined", false)
ns.RefreshWindow()
local free = {}
for _, button in ipairs(keyButtons) do
    if button.enabled then table.insert(free, button) end
end
assert(#free == 4, "Letterbox, CameraShift, FOV and Combined Lens are free")
local letterbox = free[1]

letterbox:Click("LeftButton")
assert(status.text:find("Press a key to bind to Letterbox"), "the game's prompt")
assert(PressKey("LSHIFT") == 1, "only the clicked button listens; a lone modifier waits")
PressKey("L")
assert(T.bindings["CTRL-L"] == "RETIMMERSIVESCREEN_LETTERBOX" and status.text == KEY_BOUND, "bound")
assert(letterbox.text == "CTRL-L", "the button shows the key")
assert(PressKey("W") == 0, "keyboard released")

letterbox:Click("LeftButton")
PressKey("J")
assert(status.text == 'Для команды "Jump" не назначена клавиша!', "the game's message for a taken key")

letterbox:Click("LeftButton")
PressKey("ESCAPE")
assert(PressKey("W") == 0 and T.bindings["CTRL-J"] == "RETIMMERSIVESCREEN_LETTERBOX", "Escape cancels")

letterbox:Click("RightButton")
assert(T.bindings["CTRL-J"] == nil and letterbox.text == "Not bound", "right-click clears")

letterbox:Click("LeftButton")
window:Hide()
window:Show()
assert(PressKey("W") == 0, "closing the window releases the keyboard")
print("  key buttons ok")

print("OK")
