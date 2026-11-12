-- Effects and keys: HideUI, Letterbox, CameraShift, FOV, the Combined Lens,
-- Esc, and the CVar keeper (staggered writes, logout, crash recovery).
local T = dofile("tests/harness.lua")

-- A session that crashed left our values: names off, camera shifted ("1.500000"
-- is how the game may return "1.5"). The player had enemy names off on purpose.
local ns = T.Load({
    db = {
        schemaVersion = 1,
        enabled = { CameraShift = true, FOV = true },
        cvarBaseline = {
            UnitNameNPC = { value = "1", forced = "0" },
            UnitNameEnemyPlayerName = { value = "0", forced = "0" },
            test_cameraOverShoulder = { value = "0", forced = "1.5" },
        },
    },
    cvars = { UnitNameNPC = "0", test_cameraOverShoulder = "1.500000" },
})
local cvars = T.cvars
local Press = RetImmersiveScreen_OnBinding

assert(cvars.UnitNameNPC == "1", "crash recovery: names back")
assert(cvars.UnitNameEnemyPlayerName == "0", "a value the player chose stays")
assert(cvars.test_cameraOverShoulder == "0", "crash recovery compares numbers as numbers")
assert(next(T.overrides) == nil, "Esc untouched before any effect was used")
print("  crash recovery ok")

-- Combined Lens on: Alt+Z, names one at a time, bars slide in.
local writes = {}
T.onCVarWrite = function(name, value) table.insert(writes, name .. "=" .. value) end
Press("CombinedLens")
assert(UIParent.shown == false and T.closedWindows == 1, "Alt+Z: windows closed, interface hidden")
assert(#writes == 0, "no CVar written in the key press itself")
T.TickAll(0.02)
assert(#writes == 1, "first name on the next frame")
T.TickAll(0.06)
assert(#writes == 1, "the next waits 0.1 s")
T.TickAll(0.06)
assert(#writes == 2, "second name after 0.1 s")
T.FlushCVars()
assert(cvars.UnitNameNPC == "0" and cvars.ShowQuestUnitCircles == "0" and cvars.UnitNameFocused == "0", "names hidden")
for _, write in ipairs(writes) do
    assert(not write:find("UnitNameOwn") and not write:find("UnitNameEnemyPlayerName"), "names off in the game are never written")
end
assert(cvars.SoftTargetIconInteract == "1", "not in the Names section: untouched")
assert(T.overrides.ESCAPE, "Esc taken while an effect is on")
T.TickAll(0.2)
local mid = T.BarHeight()
assert(mid > 1 and mid < 100, "bars half way: " .. mid)
T.TickAll(1)
assert(T.Near(T.BarHeight(), 100) and T.Bars().scripts.OnUpdate == nil, "bars at 10%, OnUpdate gone")
print("  Combined Lens on ok")

-- Off: interface back at once, names one by one, bars slide out.
Press("CombinedLens")
assert(UIParent.shown, "interface back")
T.FlushCVars()
assert(cvars.UnitNameNPC == "1" and cvars.ShowQuestUnitCircles == "1" and cvars.UnitNameFocused == "1", "names back")
T.TickAll(0.1)
local partly = T.BarHeight()
assert(partly > 0 and partly < 100, "sliding out")
Press("CombinedLens")
T.TickAll(0.02)
assert(T.BarHeight() >= partly - 1e-6, "turned back from where the bars were")
T.TickAll(1)
Press("CombinedLens")
T.FlushCVars()
T.TickAll(1)
assert(not T.Bars().shown, "bars hidden at 0")
assert(next(T.overrides) == nil, "Esc given back when everything is off")

-- On and off before anything was written: no writes at all.
writes = {}
Press("CombinedLens")
Press("CombinedLens")
T.FlushCVars()
assert(#writes == 0, "nothing written: " .. table.concat(writes, " "))
T.TickAll(1)
T.onCVarWrite = nil
print("  Combined Lens off ok")

-- An unchecked name stays; live slider; duration 0.
ns.SetSetting("HideUI", "nameNPC", false)
Press("CombinedLens")
T.FlushCVars()
T.TickAll(1)
assert(cvars.UnitNameNPC == "1", "unchecked name stays visible")
ns.SetSetting("Letterbox", "height", 20)
assert(T.Near(T.BarHeight(), 200), "height slider applies at once")
ns.SetSetting("Letterbox", "height", 10)
Press("CombinedLens")
T.FlushCVars()
T.TickAll(1)
ns.SetSetting("HideUI", "nameNPC", true)
ns.SetSetting("Letterbox", "duration", 0)
Press("CombinedLens")
assert(T.Near(T.BarHeight(), 100), "duration 0: at once")
Press("CombinedLens")
T.FlushCVars()
assert(not T.Bars().shown)
ns.SetSetting("Letterbox", "duration", 0.5)

-- Interface hidden with Alt+Z before: HideUI leaves it alone and hidden.
UIParent.shown = false
T.closedWindows = 0
Press("CombinedLens")
Press("CombinedLens")
T.FlushCVars()
T.TickAll(1)
assert(UIParent.shown == false and T.closedWindows == 0, "stays hidden, Alt+Z not repeated")
UIParent.shown = true
print("  names, slider, Alt+Z ok")

-- Esc: the first turns everything off, the next opens the game menu.
T.menuOpened = 0
Press("CombinedLens")
T.PressEscape()
T.FlushCVars()
T.TickAll(1)
assert(UIParent.shown and not T.Bars().shown and cvars.UnitNameNPC == "1", "first Esc: everything off")
assert(T.menuOpened == 0 and next(T.overrides) == nil, "menu not opened, Esc given back")
T.PressEscape()
assert(T.menuOpened == 1, "second Esc opens the menu")

-- Letterbox alone, interface visible: the same.
ns.SetSetting("Letterbox", "combined", false)
Press("Letterbox")
T.PressEscape()
T.TickAll(1)
assert(not T.Bars().shown and T.menuOpened == 1, "bars off, menu not opened")
ns.SetSetting("Letterbox", "combined", true)

-- Combat: Esc is the game's; the hook after ToggleGameMenu turns effects off.
Press("CombinedLens")
T.SetCombat(true)
assert(next(T.overrides) == nil, "override lifted as combat starts")
T.PressEscape()
T.FlushCVars()
T.TickAll(1)
assert(UIParent.shown and not T.Bars().shown, "combat Esc: interface back, effects off")
T.SetCombat(false)
assert(next(T.overrides) == nil, "nothing on after combat: no override")
T.SetCombat(true)
T.closedWindows = 0
Press("CombinedLens")
assert(T.closedWindows == 1 and UIParent.shown == false and next(T.overrides) == nil, "combat: Alt+Z body, no override")
T.SetCombat(false)
assert(T.overrides.ESCAPE, "override set after combat")
T.PressEscape()
T.FlushCVars()
T.TickAll(1)
assert(UIParent.shown and next(T.overrides) == nil)
print("  Esc ok")

-- Chat while the Combined Lens is on: the interface fades back in and takes the
-- input's focus, names stay hidden, the bars turn half transparent; closing chat
-- hides the interface again.
Press("CombinedLens")
T.FlushCVars()
T.TickAll(1)
assert(UIParent.shown == false)
T.OpenChat()
assert(UIParent.shown and T.focus == T.chatBox, "Enter: interface back, the input has focus")
T.TickAll(0.32)
assert(UIParent:GetAlpha() == 1 and T.Near(T.Bars():GetAlpha(), 0.5), "faded in, bars half transparent")
assert(cvars.UnitNameNPC == "0", "names stay hidden while typing")
T.CloseChat()
T.TickAll(0.32)
assert(UIParent.shown == false and UIParent:GetAlpha() == 1 and T.Bars():GetAlpha() == 1, "hidden again, all opaque")
-- The Lens turned off in the middle of typing: the interface ends fully shown,
-- and closing chat afterwards leaves it alone.
T.OpenChat()
T.TickAll(0.1)
Press("CombinedLens")
T.FlushCVars()
T.TickAll(1)
assert(UIParent.shown and UIParent:GetAlpha() == 1, "Lens off: interface fully shown")
T.CloseChat()
T.TickAll(0.5)
assert(UIParent.shown and UIParent:GetAlpha() == 1, "closing chat after the Lens went off changes nothing")
-- Letterbox alone: only the bars react.
ns.SetSetting("Letterbox", "combined", false)
Press("Letterbox")
T.TickAll(1)
T.OpenChat()
T.TickAll(0.32)
assert(T.Near(T.Bars():GetAlpha(), 0.5) and UIParent:GetAlpha() == 1, "bars half transparent")
T.CloseChat()
T.TickAll(0.32)
assert(T.Bars():GetAlpha() == 1, "bars opaque again")
Press("Letterbox")
T.TickAll(1)
ns.SetSetting("Letterbox", "combined", true)
print("  chat focus ok")

-- CameraShift.
local function Offset() return tonumber(cvars.test_cameraOverShoulder) end
assert(T.unregistered.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED, "experimental warning dropped at Start")
Press("CameraShift")
assert(cvars.CameraKeepCharacterCentered == "0" and cvars.CameraReduceUnexpectedMovement == "0", "centering off at once")
T.TickAll(0.5)
assert(Offset() > 0.1 and Offset() < 1.4, "half way: " .. Offset())
T.TickAll(1)
assert(T.Near(Offset(), 1.5), "shifted")
Press("CameraShift")
T.TickAll(0.3)
partly = Offset()
assert(partly > 0 and partly < 1.5 and cvars.CameraKeepCharacterCentered == "0", "coming back, centering still off")
Press("CameraShift")
T.TickAll(0.02)
assert(Offset() >= partly - 1e-6, "turned back from where it was")
T.TickAll(2)
ns.SetSetting("CameraShift", "offset", -3)
assert(T.Near(Offset(), -3), "offset slider applies at once")
ns.SetSetting("CameraShift", "offset", 1.5)
Press("CameraShift")
T.TickAll(2)
T.FlushCVars()
assert(Offset() == 0 and cvars.CameraKeepCharacterCentered == "1" and cvars.CameraReduceUnexpectedMovement == "1",
    "camera back, then centering back")
print("  CameraShift ok")

-- FOV.
local function Fov() return tonumber(cvars.cameraFov) end
assert(ns.GetSetting("FOV", "fov") == 70, "default: 20 below the game's default")
Press("FOV")
T.TickAll(0.5)
assert(Fov() > 71 and Fov() < 89, "half way: " .. Fov())
T.TickAll(1)
assert(T.Near(Fov(), 70))
ns.SetSetting("FOV", "fov", 60)
assert(T.Near(Fov(), 60), "slider applies at once")
ns.SetSetting("FOV", "fov", 70)
Press("FOV")
T.TickAll(2)
T.FlushCVars()
assert(Fov() == 90, "back to the player's own")
print("  FOV ok")

-- Escape Button: turning the Combined Lens off turns every effect off.
Press("CombinedLens")
Press("CameraShift")
T.TickAll(2)
Press("CombinedLens")
T.FlushCVars()
T.TickAll(2)
assert(UIParent.shown and not T.Bars().shown and T.Near(Offset(), 1.5), "off: only the Combined Lens goes")
Press("CombinedLens")
ns.SetSetting("Lens", "escapeButton", true)
Press("CombinedLens")
T.FlushCVars()
T.TickAll(2)
assert(UIParent.shown and not T.Bars().shown and Offset() == 0, "Escape Button: CameraShift went too")
assert(next(T.overrides) == nil and T.menuOpened == 1, "like the first Esc: no menu, Esc given back")
Press("CameraShift")
T.TickAll(2)
Press("CombinedLens")
assert(UIParent.shown == false and T.Near(Offset(), 1.5), "the first press still turns the Combined Lens on")
Press("CombinedLens")
T.FlushCVars()
T.TickAll(2)
assert(Offset() == 0, "second press: everything off")
ns.SetSetting("Lens", "escapeButton", false)
print("  Escape Button ok")

-- /reload or logout in the middle of everything: all back at once.
Press("CombinedLens")
Press("CameraShift")
Press("FOV")
T.TickAll(0.12)
T.Fire("PLAYER_LOGOUT")
assert(cvars.UnitNameNPC == "1" and cvars.ShowQuestUnitCircles == "1" and cvars.UnitNameFocused == "1", "names")
assert(Offset() == 0 and Fov() == 90 and cvars.CameraKeepCharacterCentered == "1", "camera")
local baseline = ret_ImmersiveScreenDB.cvarBaseline
assert(baseline.UnitNameNPC.value == "1" and baseline.UnitNameOwn == nil, "baseline: what the player has; untouched CVars absent")
print("  logout ok")

print("OK")
