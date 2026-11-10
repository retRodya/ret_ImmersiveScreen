local addonName, ns = ...

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

ns.title = GetAddOnMetadata(addonName, "Title")
ns.notes = GetAddOnMetadata(addonName, "Notes")
ns.version = GetAddOnMetadata(addonName, "Version")

--------------------------------------------------------------------------------
-- Saved settings
--------------------------------------------------------------------------------

local SCHEMA_VERSION = 1

-- migrations[n] upgrades saved data from schema version n - 1 to n.
-- Version 0 means a fresh install: there is nothing to convert yet.
local migrations = {
    [1] = function() end,
}

local db

local function LoadDatabase()
    if type(ret_ImmersiveScreenDB) ~= "table" then
        ret_ImmersiveScreenDB = {}
    end
    local data = ret_ImmersiveScreenDB
    for version = (data.schemaVersion or 0) + 1, SCHEMA_VERSION do
        migrations[version](data)
        data.schemaVersion = version
    end
    for _, field in ipairs({ "enabled", "settings", "collapsed" }) do
        if type(data[field]) ~= "table" then
            data[field] = {}
        end
    end
    return data
end

-- A table in saved settings for core features outside modules, e.g. CVars.lua.
-- Available from ADDON_LOADED on.
function ns.GetSaved(field)
    local data = db[field]
    if type(data) ~= "table" then
        data = {}
        db[field] = data
    end
    return data
end

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------

ns.moduleList = {}
-- The window's list in registration (.toc) order: pages, and groups of modules.
ns.listItems = {}

local owners = {} -- modules and pages by key; both can own settings
local ownerList = {}
local groups = {} -- list items of module groups by category
local running = {}
local loggedIn = false
-- Setting values as they were when the UI loaded: loadedSettings[ownerKey][settingKey].
local loadedSettings = {}

-- One broken module or page must not stop the others: errors go to the
-- error handler (BugSack) and the caller carries on.
function ns.SafeCall(func, ...)
    local args = { n = select("#", ...), ... }
    xpcall(function()
        func(unpack(args, 1, args.n))
    end, geterrorhandler())
end

-- A setting is a table with:
--   key          unique within its owner, also the key in saved settings
--   type         "checkbox", "slider", or "heading" (a title over the rows below; no value)
--   title        label next to the control
--   description  tooltip text
--   default      value until the player changes it
--   min, max, step, format   sliders only; format is for string.format
--   hidden       optional: not shown on the owner's page (another page shows it)
--   IsShown      optional function: false hides the row and moves the rows below up
--   indent       optional: rows to the right, for a setting that belongs to the one above
local SETTING_TYPES = { checkbox = true, slider = true, heading = true }

local function RegisterSettings(owner)
    owner.settings = owner.settings or {}
    local byKey = {}
    for _, setting in ipairs(owner.settings) do
        assert(type(setting.key) == "string", "setting.key is required")
        assert(not byKey[setting.key], "setting already registered: " .. setting.key)
        assert(SETTING_TYPES[setting.type], "setting.type must be checkbox, slider or heading")
        assert(type(setting.title) == "string", "setting.title is required")
        if setting.type ~= "heading" then
            assert(type(setting.description) == "string", "setting.description is required")
            assert(setting.default ~= nil, "setting.default is required")
        end
        if setting.type == "slider" then
            assert(type(setting.min) == "number" and type(setting.max) == "number", "slider needs min and max")
            assert(type(setting.step) == "number" and type(setting.format) == "string", "slider needs step and format")
        end
        byKey[setting.key] = setting
    end
    owner.settingsByKey = byKey
end

local function AddOwner(owner)
    assert(type(owner.key) == "string", "key is required")
    assert(not owners[owner.key], "key already registered: " .. owner.key)
    assert(type(owner.title) == "string", "title is required")
    RegisterSettings(owner)
    owners[owner.key] = owner
    table.insert(ownerList, owner)
end

-- A module is an Effect or a LiteRP feature: a table with
--   key          unique id, also the key in saved settings; never rename
--   category     group in the window's list, e.g. "Effects"
--   section      optional heading on the group's page, e.g. "Stay"
--   title        name in the window's list
--   description  tooltip text and the line under the page title
--   placeholder  optional: shown greyed out, does nothing and saves nothing
--   lens         optional: an Effect with its own key that can join the Combined Lens
--   enabledByDefault, combinedByDefault   optional, false if not set
--   settings     optional list of settings shown on the module's page while it runs
--   Start(module)                          optional: once after login, if enabled
--   OnSettingChanged(module, key, value)   optional: a setting changed while running
--   Activate(module), Deactivate(module)   optional: its key turned it on or off
function ns.RegisterModule(module)
    assert(type(module.category) == "string", "module.category is required")
    assert(type(module.description) == "string", "module.description is required")
    if module.lens then
        -- Shown on the Lens page, not on the module's own page.
        module.settings = module.settings or {}
        table.insert(module.settings, {
            key = "combined",
            type = "checkbox",
            title = "In Combined Lens",
            description = module.title .. " turns on and off with the Combined Lens key instead of its own key.",
            default = module.combinedByDefault == true,
            hidden = true,
        })
    end
    AddOwner(module)
    table.insert(ns.moduleList, module)

    local group = groups[module.category]
    if not group then
        group = { category = module.category, modules = {} }
        groups[module.category] = group
        table.insert(ns.listItems, group)
    end
    table.insert(group.modules, module)
end

-- A page is an entry in the window's list that is not a module: a table with
--   key        unique among pages and modules, also the key in saved settings
--   title      name in the window's list
--   settings   optional, like a module's
--   Create(page, frame)   fills the page's frame below its title; may set frame:Update()
--   Start(page), OnSettingChanged(page, key, value)   optional, like a module's
function ns.RegisterPage(page)
    page.isPage = true
    AddOwner(page)
    table.insert(ns.listItems, { page = page })
end

function ns.GetModule(key)
    local owner = owners[key]
    if owner and not owner.isPage then
        return owner
    end
end

--------------------------------------------------------------------------------
-- Modules on and off
--------------------------------------------------------------------------------

-- What the player chose. Takes effect after /reload.
function ns.IsEnabled(key)
    local module = owners[key]
    if module.placeholder then
        return false
    end
    local enabled = db.enabled[key]
    if enabled == nil then
        return module.enabledByDefault == true
    end
    return enabled
end

function ns.SetEnabled(key, enabled)
    if not owners[key].placeholder then
        db.enabled[key] = enabled
    end
end

-- What runs in this session: the choice as it was when the UI loaded.
function ns.IsRunning(key)
    return running[key] == true
end

function ns.IsPending(key)
    return ns.IsEnabled(key) ~= ns.IsRunning(key)
end

function ns.HasPendingChanges()
    for _, module in ipairs(ns.moduleList) do
        if ns.IsPending(module.key) then
            return true
        end
    end
    return false
end

-- Undo: everything the player changed since the UI loaded can be set back.
-- For a module, "changed" is the same as pending.
function ns.UndoModule(key)
    ns.SetEnabled(key, ns.IsRunning(key))
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- Settings apply at once. Pages run from login; modules while they run.
local function IsOwnerRunning(owner)
    if owner.isPage then
        return loggedIn
    end
    return ns.IsRunning(owner.key)
end

function ns.GetSetting(ownerKey, key)
    local values = db.settings[ownerKey]
    local value = values and values[key]
    if value == nil then
        return owners[ownerKey].settingsByKey[key].default
    end
    return value
end

-- Placeholders save nothing.
function ns.SetSetting(ownerKey, key, value)
    local owner = owners[ownerKey]
    if owner.placeholder or ns.GetSetting(ownerKey, key) == value then
        return
    end
    local values = db.settings[ownerKey]
    if not values then
        values = {}
        db.settings[ownerKey] = values
    end
    values[key] = value
    if owner.OnSettingChanged and IsOwnerRunning(owner) then
        ns.SafeCall(owner.OnSettingChanged, owner, key, value)
    end
end

function ns.IsSettingChanged(ownerKey, key)
    return ns.GetSetting(ownerKey, key) ~= loadedSettings[ownerKey][key]
end

function ns.UndoSetting(ownerKey, key)
    ns.SetSetting(ownerKey, key, loadedSettings[ownerKey][key])
end

local function RememberLoadedSettings()
    for _, owner in ipairs(ownerList) do
        local values = {}
        for _, setting in ipairs(owner.settings) do
            if setting.type ~= "heading" then
                values[setting.key] = ns.GetSetting(owner.key, setting.key)
            end
        end
        loadedSettings[owner.key] = values
    end
end

--------------------------------------------------------------------------------
-- Window state
--------------------------------------------------------------------------------

-- Groups the player collapsed in the window's list.
function ns.IsCollapsed(category)
    return db.collapsed[category] == true
end

function ns.SetCollapsed(category, collapsed)
    db.collapsed[category] = collapsed or nil
end

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------

local function Start()
    loggedIn = true
    for _, owner in ipairs(ownerList) do
        local starts = owner.isPage or ns.IsEnabled(owner.key)
        if not owner.isPage and starts then
            running[owner.key] = true
        end
        if starts and owner.Start then
            ns.SafeCall(owner.Start, owner)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        db = LoadDatabase()
        RememberLoadedSettings()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        Start()
    end
end)
