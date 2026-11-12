local _, ns = ...

-- One key per Effect, plus the Combined Lens. An Effect in the Combined Lens
-- has no key of its own, so its row says so instead of offering a key.

local ROW_HEIGHT = 28
local KEY_X, COMBINED_X = 130, 290

local function CreateHeader(parent, text, x)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", x, 0)
    header:SetText(text)
end

ns.RegisterPage({
    key = "Lens",
    title = "Lens",
    settings = {
        {
            -- Shown under the Combined Lens key rather than in a list.
            key = "escapeButton",
            type = "checkbox",
            title = "Escape Button",
            description = "Turning the Combined Lens off with its key turns off every effect, as Esc does, not only the effects in the Combined Lens.",
            default = false,
            hidden = true,
        },
    },

    Create = function(page, frame)
        local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        intro:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
        intro:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -8)
        intro:SetJustifyH("LEFT")
        intro:SetText("Each effect turns on and off with its own key. Effects in the Combined Lens turn on only with the Combined Lens key.")

        local grid = CreateFrame("Frame", nil, frame)
        grid:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
        grid:SetPoint("BOTTOMRIGHT", -16, 16)

        -- The result of the last key change.
        local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        status:SetJustifyH("LEFT")

        CreateHeader(grid, "Effect", 0)
        CreateHeader(grid, "Key", KEY_X)
        CreateHeader(grid, "Combined Lens", COMBINED_X)

        -- Each row is centred on the same line: name, key button, checkbox.
        local rows = {}
        local y = -18 - ROW_HEIGHT / 2
        for _, module in ipairs(ns.moduleList) do
            if module.lens then
                local name = grid:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                name:SetPoint("LEFT", grid, "TOPLEFT", 0, y)
                name:SetText(module.title)

                local keyButton = ns.CreateKeyButton(grid, ns.GetBindingAction(module.key), status)
                keyButton:SetPoint("LEFT", grid, "TOPLEFT", KEY_X, y)

                local combined = ns.CreateSettingRow(grid, module.key, module.settingsByKey.combined, "", module.placeholder)
                combined.frame:SetPoint("LEFT", grid, "TOPLEFT", COMBINED_X, y)

                table.insert(rows, { module = module, name = name, keyButton = keyButton, combined = combined })
                y = y - ROW_HEIGHT
            end
        end

        y = y - 16
        local lensName = grid:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        lensName:SetPoint("LEFT", grid, "TOPLEFT", 0, y)
        lensName:SetText("Combined Lens")
        local lensKey = ns.CreateKeyButton(grid, ns.GetBindingAction(ns.COMBINED_LENS), status)
        lensKey:SetPoint("LEFT", grid, "TOPLEFT", KEY_X, y)
        -- Under the Combined Lens key, which it changes.
        y = y - ROW_HEIGHT
        local escapeButton = ns.CreateSettingRow(grid, page.key, page.settingsByKey.escapeButton, "Escape Button")
        escapeButton.frame:SetPoint("LEFT", grid, "TOPLEFT", KEY_X, y)

        status:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - 28)
        status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

        function frame:Update()
            for _, row in ipairs(rows) do
                local module = row.module
                local locked
                if module.placeholder then
                    locked = "Coming later"
                elseif ns.IsInCombinedLens(module.key) then
                    locked = "Combined Lens"
                end
                row.keyButton:SetLockedText(locked)
                row.name:SetFontObject(ns.IsEnabled(module.key) and "GameFontHighlight" or "GameFontDisable")
                row.combined.Update()
            end
            lensKey:Update()
            escapeButton.Update()
        end

        frame:HookScript("OnHide", function()
            status:SetText("")
        end)
    end,
})
