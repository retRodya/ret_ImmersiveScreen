local addonName, ns = ...

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

ns.title = GetAddOnMetadata(addonName, "Title")
ns.version = GetAddOnMetadata(addonName, "Version")

-- Prints the version until the settings page exists.
SLASH_RETIMMERSIVESCREEN1 = "/retis"
SLASH_RETIMMERSIVESCREEN2 = "/retimmersivescreen"
SlashCmdList.RETIMMERSIVESCREEN = function()
    print(ns.title .. " " .. ns.version)
end
