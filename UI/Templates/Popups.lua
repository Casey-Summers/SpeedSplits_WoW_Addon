local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Popups = NS.UI.Popups or {}

local WIPE_CONFIRM_ID = "SPEEDSPLITS_WIPE_CONFIRM"
local FACTORY_RESET_ID = "SPEEDSPLITS_FACTORY_RESET"

StaticPopupDialogs[WIPE_CONFIRM_ID] = {
    text = "Are you sure you want to wipe ALL Personal Bests and Run History? This cannot be undone.",
    button1 = "Wipe Records",
    button2 = "Cancel",
    OnAccept = function()
        if NS.WipeAllRecordsAndRebuild then
            NS.WipeAllRecordsAndRebuild()
        elseif NS.WipeDatabase then
            NS.WipeDatabase()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs[FACTORY_RESET_ID] = {
    text =
    "Are you sure you want to reset ALL settings, colors, and layouts to factory out-of-the-box defaults? This will reload your UI.",
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

function NS.UI.Popups.ShowWipeConfirm()
    StaticPopup_Show(WIPE_CONFIRM_ID)
end

function NS.UI.Popups.ShowFactoryReset()
    StaticPopup_Show(FACTORY_RESET_ID)
end
