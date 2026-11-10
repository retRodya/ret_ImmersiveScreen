local addonName, ns = ...

-- Ways to open the window: slash commands, the Addon Compartment
-- and the addon's page in Settings > AddOns.

SLASH_RETIMMERSIVESCREEN1 = "/retis"
SLASH_RETIMMERSIVESCREEN2 = "/retimmersivescreen"
SlashCmdList.RETIMMERSIVESCREEN = function()
    ns.ToggleWindow()
end

-- Named in the TOC (AddonCompartmentFunc).
function RetImmersiveScreen_OnAddonCompartmentClick()
    ns.ToggleWindow()
end

-- The button opens the window on top of the Settings panel and leaves the panel
-- open: closing it from addon code would commit game settings from tainted code.
local function RegisterSettingsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return
    end

    local page = CreateFrame("Frame")

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.title)

    local notes = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    notes:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    notes:SetText(ns.notes)

    local openButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    openButton:SetSize(200, 22)
    openButton:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -16)
    openButton:SetText("Open " .. addonName)
    openButton:SetScript("OnClick", function()
        ns.ShowWindow()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(page, addonName)
    Settings.RegisterAddOnCategory(category)
end

RegisterSettingsPage()
