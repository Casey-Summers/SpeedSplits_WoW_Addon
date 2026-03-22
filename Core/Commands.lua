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
    elseif cmd == "dev" then
        if NS.DevTools and NS.DevTools.IsAvailable and NS.DevTools.IsAvailable() and NS.DevTools.HandleSlashCommand then
            NS.DevTools.HandleSlashCommand()
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
