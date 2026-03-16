local _, NS = ...

SLASH_SPEEDSPLITS1 = "/ss"
SlashCmdList.SPEEDSPLITS = function(msg)
    NS.Database.EnsureDB()
    local cmd = strsplit(" ", msg or "", 2)
    cmd = (cmd or ""):lower()

    if cmd == "history" or cmd == "h" then
        NS.UI.ToggleHistoryFrame()
    elseif cmd == "test" then
        if NS.Debug and NS.Debug.enableTestUI and NS.Tests and NS.Tests.Open then
            NS.Tests.Open()
        elseif NS.Print then
            NS.Print("Test UI is disabled in normal runtime.")
        end
    elseif cmd == "debugobj" then
        NS.Debug.objectiveTrace = not NS.Debug.objectiveTrace
        if NS.Print then
            NS.Print("Objective debug: " .. (NS.Debug.objectiveTrace and "ON" or "OFF"))
        end
    elseif cmd == "reset" then
        if NS.UI and NS.UI.Popups and NS.UI.Popups.ShowFactoryReset then
            NS.UI.Popups.ShowFactoryReset()
        end
    else
        if NS.OpenOptions then
            NS.OpenOptions()
        elseif Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("SpeedSplits")
        end
    end
end
