local _, NS = ...

SLASH_SPEEDSPLITS1 = "/ss"
SlashCmdList.SPEEDSPLITS = function(msg)
    NS.Database.EnsureDB()
    local cmd = strsplit(" ", msg or "", 2)
    cmd = (cmd or ""):lower()

    if cmd == "history" or cmd == "h" then
        NS.UI.ToggleHistoryFrame()
    elseif cmd == "test" then
        if NS.Tests and NS.Tests.Open then
            NS.Tests.Open()
        end
    elseif cmd == "debugobj" then
        SpeedSplits_DebugObjectives = not SpeedSplits_DebugObjectives
        if NS.Print then
            NS.Print("Objective debug: " .. (SpeedSplits_DebugObjectives and "ON" or "OFF"))
        end
    elseif cmd == "reset" then
        StaticPopup_Show("SPEEDSPLITS_FACTORY_RESET")
    else
        if NS.OpenOptions then
            NS.OpenOptions()
        elseif Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("SpeedSplits")
        end
    end
end
