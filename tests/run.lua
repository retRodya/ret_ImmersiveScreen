-- Runs each test file in its own LuaJIT process, so every one starts with a
-- freshly loaded addon. From the repository root:
--
--   luajit tests/run.lua

local FILES = {
    "tests/test_window.lua",
    "tests/test_effects.lua",
    "tests/test_literp.lua",
    "tests/test_reload.lua",
}

local interpreter = arg[-1] or "luajit"
local failed = 0
for _, file in ipairs(FILES) do
    io.write(file, ": ")
    io.flush()
    local ok = os.execute('"' .. interpreter .. '" ' .. file)
    -- LuaJIT returns the exit code (5.1) or true/false (5.2 compatibility).
    if ok ~= 0 and ok ~= true then
        failed = failed + 1
    end
end
print(failed == 0 and "ALL PASSED" or (failed .. " FILE(S) FAILED"))
os.exit(failed == 0 and 0 or 1)
