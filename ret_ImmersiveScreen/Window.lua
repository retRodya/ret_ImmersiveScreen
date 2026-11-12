local _, ns = ...

local WIDTH, HEIGHT = 600, 520
local LIST_WIDTH = 170
local ENTRY_HEIGHT = 22
local BUTTON_WIDTH = 120

-- Offsets of ButtonFrameTemplate's inset: title bar on top, button bar at the bottom.
local INSET_LEFT, INSET_RIGHT, INSET_TOP, INSET_BOTTOM = 4, -6, -24, 26

-- In the list on the left: where the +/- toggle, the labels and the module checkboxes sit.
local TOGGLE_X, LABEL_X, MODULE_X = 2, 24, 22

-- On a group's page: indent of module names under a section heading.
local SECTION_INDENT = 12

local PLACEHOLDER_TEXT = "Coming in a later version."

local window
local entries = {} -- list on the left, in display order
local pages = {} -- one page per entry
local selectedEntry

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Same look as the category list of the game's Settings panel.
local function UpdateEntry(entry)
    if entry == selectedEntry then
        entry.background:SetAtlas("Options_List_Active")
        entry.background:Show()
    elseif entry:IsMouseOver() then
        entry.background:SetAtlas("Options_List_Hover")
        entry.background:Show()
    else
        entry.background:Hide()
    end
    if entry.Update then
        entry:Update()
    end
end

local function Refresh()
    for _, entry in ipairs(entries) do
        UpdateEntry(entry)
    end
    for _, page in ipairs(pages) do
        if page.Update then
            page:Update()
        end
    end
    window.reloadButton:SetShown(ns.HasPendingChanges())
end

-- Controls call this after every change, so the whole window stays in sync.
function ns.RefreshWindow()
    if window and window:IsShown() then
        Refresh()
    end
end

local function SelectEntry(entry)
    selectedEntry = entry
    for _, other in ipairs(entries) do
        UpdateEntry(other)
        other.page:SetShown(other == entry)
    end
end

-- Modules of a collapsed group are hidden; the rest move up.
local function LayoutList()
    local y = -4
    for _, entry in ipairs(entries) do
        local visible = not (entry.module and ns.IsCollapsed(entry.category))
        entry:SetShown(visible)
        if visible then
            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", 4, y)
            entry:SetPoint("TOPRIGHT", -4, y)
            y = y - ENTRY_HEIGHT
        end
    end
end

--------------------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------------------

local function CreatePage(parent, titleText)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetPoint("TOPRIGHT", -16, -16)
    title:SetJustifyH("LEFT")
    title:SetText(titleText)
    page.title = title

    table.insert(pages, page)
    return page
end

-- A registered page fills its own frame.
local function CreateCustomPage(parent, pageInfo)
    local page = CreatePage(parent, pageInfo.title)
    if pageInfo.Create then
        pageInfo.Create(pageInfo, page)
    end
    return page
end

-- Overview of a group: enabled modules in white, disabled ones and placeholders
-- in grey, under their section headings if they have them.
local function CreateGroupPage(parent, category, modules)
    local page = CreatePage(parent, category)

    local names = {}
    local previous, previousIndent, gap = page.title, 0, -12
    local section
    for _, module in ipairs(modules) do
        if module.section and module.section ~= section then
            section = module.section
            local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            heading:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", -previousIndent, gap)
            heading:SetText(section)
            previous, previousIndent, gap = heading, 0, -6
        end
        local indent = module.section and SECTION_INDENT or 0
        local name = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        name:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", indent - previousIndent, gap)
        name:SetText(module.title)
        name.module = module
        table.insert(names, name)
        previous, previousIndent, gap = name, indent, -6
    end

    function page:Update()
        for _, name in ipairs(names) do
            name:SetFontObject(ns.IsEnabled(name.module.key) and "GameFontHighlight" or "GameFontDisable")
        end
    end

    return page
end

-- Buttons at the bottom of a module's settings, left to right: Defaults first,
-- then the module's own, e.g. Test.
local function CreateModuleButtons(parent, module)
    local list = {}
    if module.defaultsButton then
        table.insert(list, {
            title = SETTINGS_DEFAULTS or "Defaults",
            description = "Sets every setting on this page back to its default.",
            OnClick = function()
                ns.ResetSettings(module.key)
                ns.RefreshWindow()
            end,
        })
    end
    for _, info in ipairs(module.buttons or {}) do
        table.insert(list, info)
    end

    local previous
    for _, info in ipairs(list) do
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_WIDTH, 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else
            button:SetPoint("BOTTOMLEFT")
        end
        button:SetText(info.title)
        button:SetScript("OnClick", function()
            info.OnClick(module)
        end)
        button:SetScript("OnEnter", function(self)
            ns.ShowTooltip(self, info.title, info.description)
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        previous = button
    end
end

-- The page shows the module's settings only while it runs. Otherwise it tells
-- the player what to do next. A placeholder shows its future settings greyed out.
local function CreateModulePage(parent, module)
    local page = CreatePage(parent, module.title)

    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("TOPRIGHT", page.title, "BOTTOMRIGHT", 0, -8)
    description:SetJustifyH("LEFT")
    description:SetText(module.description)

    local top = description
    if module.placeholder then
        local note = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        note:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
        note:SetText(PLACEHOLDER_TEXT)
        top = note
    end

    local message = page:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    message:SetPoint("LEFT", 24, 0)
    message:SetPoint("RIGHT", -24, 0)
    message:SetJustifyH("CENTER")

    local settings = CreateFrame("Frame", nil, page)
    settings:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -12)
    settings:SetPoint("BOTTOMRIGHT", -16, 16)
    local rows = ns.CreateSettingRows(settings, module.key, module.settings, module.placeholder)
    CreateModuleButtons(settings, module)

    function page:Update()
        local text
        if not module.placeholder then
            local enabled, running = ns.IsEnabled(module.key), ns.IsRunning(module.key)
            if enabled and not running then
                text = "Type /reload to enable " .. module.title .. "."
            elseif running and not enabled then
                text = "Type /reload to disable " .. module.title .. "."
            elseif not enabled then
                text = "Check the box to enable " .. module.title .. "."
            end
        end

        message:SetText(text or "")
        message:SetShown(text ~= nil)
        settings:SetShown(text == nil)
        rows.Update()
    end

    return page
end

--------------------------------------------------------------------------------
-- List on the left
--------------------------------------------------------------------------------

local function CreateEntry(parent, page, text, fontObject)
    local entry = CreateFrame("Button", nil, parent)
    entry:SetHeight(ENTRY_HEIGHT)
    entry.page = page

    entry.background = entry:CreateTexture(nil, "BACKGROUND")
    entry.background:SetAllPoints()
    entry.background:Hide()

    entry.label = entry:CreateFontString(nil, "ARTWORK", fontObject)
    entry.label:SetPoint("LEFT", LABEL_X, 0)
    entry.label:SetText(text)

    entry:SetScript("OnEnter", UpdateEntry)
    entry:SetScript("OnLeave", UpdateEntry)
    entry:SetScript("OnClick", SelectEntry)

    table.insert(entries, entry)
    return entry
end

-- Controls inside an entry: moving onto them makes the entry get OnLeave
-- while the cursor is still over it, so they refresh the entry's hover too.
local function KeepEntryHover(control, entry)
    control:HookScript("OnEnter", function()
        UpdateEntry(entry)
    end)
    control:HookScript("OnLeave", function()
        UpdateEntry(entry)
    end)
end

-- Navigation only: pages and groups are gold, modules are white.
local function CreatePageEntry(parent, pageInfo, page)
    return CreateEntry(parent, page, pageInfo.title, "GameFontNormal")
end

local function CreateGroupEntry(parent, category, page)
    local entry = CreateEntry(parent, page, category, "GameFontNormal")
    entry.category = category

    local toggle = CreateFrame("Button", nil, entry)
    toggle:SetSize(20, 20)
    toggle:SetPoint("LEFT", TOGGLE_X, 0)
    toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    toggle:SetScript("OnClick", function()
        local collapsed = not ns.IsCollapsed(category)
        ns.SetCollapsed(category, collapsed)
        if collapsed and selectedEntry.module and selectedEntry.category == category then
            SelectEntry(entry)
        end
        LayoutList()
        Refresh()
    end)
    KeepEntryHover(toggle, entry)

    function entry:Update()
        local state = ns.IsCollapsed(category) and "Plus" or "Minus"
        toggle:SetNormalTexture("Interface\\Buttons\\UI-" .. state .. "Button-UP")
        toggle:SetPushedTexture("Interface\\Buttons\\UI-" .. state .. "Button-DOWN")
    end

    return entry
end

local function CreateModuleEntry(parent, module, page)
    local entry = CreateEntry(parent, page, module.title, module.placeholder and "GameFontDisable" or "GameFontHighlight")
    entry.category = module.category
    entry.module = module

    -- The module's on/off switch sits left of its name. A placeholder's cannot be checked.
    local checkbox = CreateFrame("CheckButton", nil, entry, ns.CHECKBOX_TEMPLATE)
    checkbox:SetSize(20, 20)
    checkbox:SetPoint("LEFT", MODULE_X, 0)
    checkbox:SetEnabled(not module.placeholder)
    entry.label:ClearAllPoints()
    entry.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        ns.PlayCheckboxSound(checked)
        ns.SetEnabled(module.key, checked)
        SelectEntry(entry)
        Refresh()
    end)
    checkbox:SetScript("OnEnter", function(self)
        local text = module.description
        if module.placeholder then
            text = text .. "\n\n" .. PLACEHOLDER_TEXT
        end
        ns.ShowTooltip(self, module.title, text)
    end)
    checkbox:SetScript("OnLeave", GameTooltip_Hide)
    KeepEntryHover(checkbox, entry)

    local undo = ns.CreateUndoButton(entry)
    undo:SetPoint("LEFT", entry.label, "RIGHT", 4, 0)
    undo:SetScript("OnClick", function()
        ns.UndoModule(module.key)
        Refresh()
    end)
    KeepEntryHover(undo, entry)

    function entry:Update()
        checkbox:SetChecked(ns.IsEnabled(module.key))
        undo:SetShown(ns.IsPending(module.key))
    end

    return entry
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local function CreateWindow()
    local frame = CreateFrame("Frame", "RetImmersiveScreenFrame", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    -- Above the game's Settings panel (HIGH), which can open this window.
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    ButtonFrameTemplate_HidePortrait(frame)
    frame:SetTitle(ns.title)
    -- Escape closes the window.
    table.insert(UISpecialFrames, frame:GetName())

    local list = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    list:SetPoint("TOPLEFT", INSET_LEFT, INSET_TOP)
    list:SetPoint("BOTTOMLEFT", INSET_LEFT, INSET_BOTTOM)
    list:SetWidth(LIST_WIDTH)

    -- The template's own inset becomes the work area on the right.
    local workArea = frame.Inset
    workArea:ClearAllPoints()
    workArea:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0)
    workArea:SetPoint("BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)

    local version = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", 12, 9)
    version:SetText(ns.version)

    local reloadButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reloadButton:SetSize(120, 22)
    reloadButton:SetPoint("BOTTOMRIGHT", INSET_RIGHT, 4)
    reloadButton:SetText(RELOADUI)
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    frame.reloadButton = reloadButton

    -- Pages and groups in .toc order; inside a group, modules in .toc order too.
    for _, item in ipairs(ns.listItems) do
        if item.page then
            CreatePageEntry(list, item.page, CreateCustomPage(workArea, item.page))
        else
            CreateGroupEntry(list, item.category, CreateGroupPage(workArea, item.category, item.modules))
            for _, module in ipairs(item.modules) do
                CreateModuleEntry(list, module, CreateModulePage(workArea, module))
            end
        end
    end
    LayoutList()
    SelectEntry(entries[1])

    frame:HookScript("OnShow", Refresh)
    -- A key button waiting for a key must never keep the keyboard after the window closes.
    frame:HookScript("OnHide", ns.StopKeyListening)

    -- Pages show game settings too (HideUI lists the names the game shows), and
    -- the player may change them in the game's Settings while this window is open.
    frame:HookScript("OnEvent", Refresh)
    frame:HookScript("OnShow", function(self)
        self:RegisterEvent("CVAR_UPDATE")
    end)
    frame:HookScript("OnHide", function(self)
        self:UnregisterEvent("CVAR_UPDATE")
    end)
    return frame
end

function ns.ShowWindow()
    if not window then
        window = CreateWindow()
    end
    window:Show()
end

function ns.ToggleWindow()
    if window and window:IsShown() then
        window:Hide()
    else
        ns.ShowWindow()
    end
end
