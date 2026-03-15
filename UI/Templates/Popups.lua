local _, NS = ...

StaticPopupDialogs["SPEEDSPLITS_WIPE_CONFIRM"] = {
    text = "Are you sure you want to wipe ALL Personal Bests and Run History? This cannot be undone.",
    button1 = "Wipe Records",
    button2 = "Cancel",
    OnAccept = function()
        if NS.WipeDatabase then
            NS.WipeDatabase()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SPEEDSPLITS_FACTORY_RESET"] = {
    text = "Are you sure you want to reset ALL settings, colors, and layouts to factory out-of-the-box defaults? This will reload your UI.",
    button1 = "Reset to Factory",
    button2 = "Cancel",
    OnAccept = function()
        if NS.ResetToFactorySettings then
            NS.ResetToFactorySettings()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
