-- LiteRP: GoOnline after the first login, GoOffline during the logout countdown
-- (bars and interface fade), Defaults.
local T = dofile("tests/harness.lua")
local ns = T.Load({ db = { schemaVersion = 1, enabled = { GoOffline = true, GoOnline = true } } })
local Press = RetImmersiveScreen_OnBinding

-- GoOnline: on the first login it waits for the loading screen, then the bars
-- open from the middle and fade out at a steady rate.
T.Fire("PLAYER_ENTERING_WORLD", true, false)
assert(T.Bars() == nil, "nothing under the loading screen")
T.Fire("LOADING_SCREEN_DISABLED")
assert(T.Near(T.BarHeight(), 500) and T.Bars():GetAlpha() == 1, "starts closed and opaque")
T.TickAll(2.5)
assert(T.Near(T.BarHeight(), 250, 15) and T.Near(T.Bars():GetAlpha(), 0.5, 0.03), "half way at 2.5 of 5 s")
T.TickAll(2.6)
assert(not T.Bars().shown and T.Bars():GetAlpha() == 1, "gone, opacity reset")
local online = ns.GetModule("GoOnline")
online.buttons[1].OnClick(online)
assert(T.Near(T.BarHeight(), 500), "Test plays it at once")
T.TickAll(5.2)
assert(not T.Bars().shown)
ns.SetSetting("GoOnline", "endOpacity", 50)
online.buttons[1].OnClick(online)
T.TickAll(2.5)
assert(T.Near(T.Bars():GetAlpha(), 0.75, 0.03), "opacity half way between 100% and 50%")
T.TickAll(2.6)
ns.SetSetting("GoOnline", "endOpacity", 0)
print("  GoOnline ok")

-- GoOffline: the game shows its countdown dialog, then our handler runs.
local dialog = StaticPopup_Show("CAMP")
T.Fire("PLAYER_CAMPING")
assert(dialog:IsIgnoringParentAlpha(), "the countdown stays visible")
T.TickAll(1.5)
assert(T.Near(UIParent:GetAlpha(), 0.5, 0.02), "interface half faded")
assert(MinimapCluster.shown, "minimap hidden only once the interface is transparent")
T.TickAll(3.5)
assert(UIParent:GetAlpha() == 0 and not MinimapCluster.shown, "faded, minimap hidden")
assert(UIParent.shown, "the interface stays shown: hiding it would cancel the logout")
assert(T.Near(T.BarHeight(), 100, 1), "5 s of stage 1: 10%")
T.TickAll(5)
assert(T.Near(T.BarHeight(), 200, 1), "10 s: 20%")
T.TickAll(6)
assert(T.Near(T.BarHeight(), 380, 1), "stage 2 at 3%/s: 38%")
T.TickAll(5)
assert(T.Near(T.BarHeight(), 500, 1), "capped at 50%")
T.Fire("LOGOUT_CANCEL")
dialog.shown = false
T.TickAll(0.2)
assert(not T.Bars().shown, "bars gone")
assert(UIParent:GetAlpha() == 1 and MinimapCluster.shown, "interface and minimap back")
assert(not dialog:IsIgnoringParentAlpha(), "the dialog as it was")
print("  GoOffline bars and fade ok")

-- Chat focus during the countdown: the interface comes back, the bars turn
-- half transparent and keep growing; without focus the interface fades again.
local editBox = {}
local camp = StaticPopup_Show("CAMP")
T.Fire("PLAYER_CAMPING")
T.TickAll(3.5)
assert(UIParent:GetAlpha() == 0)
local before = T.BarHeight()
T.TriggerEvent("ChatFrame.OnEditBoxFocusGained", editBox)
T.TickAll(0.32)
assert(UIParent:GetAlpha() == 1 and MinimapCluster.shown, "chat focus: interface back")
assert(T.Near(T.Bars():GetAlpha(), 0.5), "bars half transparent")
assert(T.BarHeight() > before, "bars keep growing")
assert(not camp:IsIgnoringParentAlpha(), "no need to keep the dialog while the interface is visible")
-- Quick toggles: focus lost and gained again in the middle of the fades.
T.TriggerEvent("ChatFrame.OnEditBoxFocusLost", editBox)
T.TickAll(1)
T.TriggerEvent("ChatFrame.OnEditBoxFocusGained", editBox)
T.TickAll(0.1)
T.TriggerEvent("ChatFrame.OnEditBoxHide", editBox)
T.TickAll(3.2)
assert(UIParent:GetAlpha() == 0 and not MinimapCluster.shown and camp:IsIgnoringParentAlpha(), "faded again, dialog kept")
assert(T.Bars():GetAlpha() == 1, "bars opaque again")
T.Fire("LOGOUT_CANCEL")
camp.shown = false
T.TickAll(0.2)
assert(UIParent:GetAlpha() == 1, "fully back after the quick toggles")

-- /camp typed in chat: the fade starts once the chat input closes.
T.TriggerEvent("ChatFrame.OnEditBoxFocusGained", editBox)
T.Fire("PLAYER_CAMPING")
T.TickAll(1)
assert(UIParent:GetAlpha() == 1 and T.Near(T.Bars():GetAlpha(), 0.5), "no fade while typing")
T.TriggerEvent("ChatFrame.OnEditBoxFocusLost", editBox)
T.TickAll(3.2)
assert(UIParent:GetAlpha() == 0, "fades after the input closed")
T.Fire("LOGOUT_CANCEL")
T.TickAll(0.2)
assert(UIParent:GetAlpha() == 1)
print("  GoOffline chat focus ok")

-- The dialog shown after our handler; cancelled from code.
T.Fire("PLAYER_QUITING")
local quit = StaticPopup_Show("QUIT")
assert(quit:IsIgnoringParentAlpha(), "caught by the StaticPopup_Show hook")
T.TickAll(1)
CancelLogout()
quit.shown = false
T.TickAll(0.2)
assert(UIParent:GetAlpha() == 1 and not quit:IsIgnoringParentAlpha(), "back after CancelLogout")

-- Fade off: only the bars.
ns.SetSetting("GoOffline", "fadeInterface", false)
T.Fire("PLAYER_CAMPING")
T.TickAll(4)
assert(UIParent:GetAlpha() == 1 and MinimapCluster.shown, "no fade")
T.Fire("LOGOUT_CANCEL")
T.TickAll(0.2)
ns.SetSetting("GoOffline", "fadeInterface", true)

-- With HideUI on, the interface is already hidden: nothing to fade.
-- The bars start from the Lens height and return to it.
Press("CombinedLens")
T.TickAll(1)
assert(UIParent.shown == false and T.Near(T.BarHeight(), 100))
T.Fire("PLAYER_CAMPING")
T.TickAll(4)
assert(UIParent:GetAlpha() == 1 and MinimapCluster.shown, "hidden interface: no fade")
assert(T.BarHeight() > 100, "bars grew from the Lens height")
T.Fire("LOGOUT_CANCEL")
T.TickAll(0.2)
assert(T.Near(T.BarHeight(), 100), "back to the Lens height")

-- The Lens turned off during the countdown: the bars stay held, go after it.
T.Fire("PLAYER_CAMPING")
T.TickAll(2)
local held = T.BarHeight()
Press("CombinedLens")
T.TickAll(0.5)
assert(T.Near(T.BarHeight(), held, 50), "still held by GoOffline")
T.Fire("LOGOUT_CANCEL")
T.TickAll(0.2)
assert(not T.Bars().shown, "Lens off after the cancel: bars gone")
print("  GoOffline with HideUI and the Lens ok")

-- Defaults.
ns.SetSetting("GoOffline", "rate1", 7)
ns.SetSetting("GoOnline", "duration", 2)
ns.ResetSettings("GoOffline")
ns.ResetSettings("GoOnline")
assert(ns.GetSetting("GoOffline", "rate1") == 2 and ns.GetSetting("GoOnline", "duration") == 5, "defaults back")
print("  Defaults ok")

print("OK")
