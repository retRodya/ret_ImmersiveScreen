local _, ns = ...

-- The first page of the window: what the addon does, and options for the whole addon.

-- ActionStatus shows "Screen captured" on SCREENSHOT_SUCCEEDED, in Retail and
-- Forever alike. The failure message stays: the player should know about it.
local function SetScreenshotMessageHidden(hidden)
    if not ActionStatus then
        return
    end
    if hidden then
        ActionStatus:UnregisterEvent("SCREENSHOT_SUCCEEDED")
    else
        ActionStatus:RegisterEvent("SCREENSHOT_SUCCEEDED")
    end
end

ns.RegisterPage({
    key = "General",
    title = "General",
    settings = {
        {
            key = "hideScreenshotMessage",
            type = "checkbox",
            title = "Hide screenshot message",
            description = "Hides the \"Screen captured\" text in the middle of the screen after you take a screenshot. A failed screenshot is still reported.",
            default = false,
        },
    },

    Start = function(page)
        if ns.GetSetting(page.key, "hideScreenshotMessage") then
            SetScreenshotMessageHidden(true)
        end
    end,

    OnSettingChanged = function(_, key, value)
        if key == "hideScreenshotMessage" then
            SetScreenshotMessageHidden(value)
        end
    end,

    Create = function(page, frame)
        frame.title:SetText(ns.title)

        local notes = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        notes:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
        notes:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -8)
        notes:SetJustifyH("LEFT")
        notes:SetText(ns.notes)

        local settings = CreateFrame("Frame", nil, frame)
        settings:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -16)
        settings:SetPoint("BOTTOMRIGHT", -16, 16)
        local rows = ns.CreateSettingRows(settings, page.key, page.settings)

        function frame:Update()
            for _, row in ipairs(rows) do
                row.Update()
            end
        end
    end,
})
