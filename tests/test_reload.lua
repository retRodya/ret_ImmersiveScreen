-- GoOnline does not play on /reload.
local T = dofile("tests/harness.lua")
T.Load({ db = { schemaVersion = 1, enabled = { GoOnline = true } } })

T.Fire("PLAYER_ENTERING_WORLD", false, true)
T.Fire("LOADING_SCREEN_DISABLED")
T.TickAll(0.1)
assert(T.Bars() == nil, "no bars after /reload")

print("OK")
