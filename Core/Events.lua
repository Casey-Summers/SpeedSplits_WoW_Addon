local _, NS = ...

local App = NS.App

local function EnableInstanceEvents()
    App:RegisterEvent("PLAYER_STARTED_MOVING")
    App:RegisterEvent("ENCOUNTER_END")
    App:RegisterEvent("BOSS_KILL")
    App:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    App:RegisterEvent("SCENARIO_UPDATE")
end

local function DisableInstanceEvents()
    App:UnregisterEvent("PLAYER_STARTED_MOVING")
    App:UnregisterEvent("ENCOUNTER_END")
    App:UnregisterEvent("BOSS_KILL")
    App:UnregisterEvent("SCENARIO_CRITERIA_UPDATE")
    App:UnregisterEvent("SCENARIO_UPDATE")
end

function NS.RefreshVisibility()
    if not NS.DB or not NS.DB.Settings or not NS.DB.Settings.visibility then
        return false, false
    end

    NS.UI.EnsureUI()

    local inInstance = IsInInstance()
    local visibility = NS.DB.Settings.visibility

    local function ShouldShow(typeKey)
        local setting = visibility[typeKey]
        if setting == "both" then
            return true
        elseif setting == "instance" then
            return inInstance
        elseif setting == "outdoor" then
            return not inInstance
        end
        return false
    end

    local timerVisible = ShouldShow("timer")
    local splitsVisible = ShouldShow("splits")

    if NS.UI.timerFrame then
        if timerVisible then NS.UI.timerFrame:Show() else NS.UI.timerFrame:Hide() end
    end
    if NS.UI.bossFrame then
        if splitsVisible then NS.UI.bossFrame:Show() else NS.UI.bossFrame:Hide() end
    end

    if not inInstance and timerVisible and not NS.Run.active and not NS.Run.waitingForMove then
        App:RegisterEvent("PLAYER_STARTED_MOVING")
        NS.Run.waitingForMove = true
        NS.UI.SetTimerText(0, false)
        if GetUnitSpeed and GetUnitSpeed("player") > 0 then
            NS.RunLogic.StartRunTimer()
            App:UnregisterEvent("PLAYER_STARTED_MOVING")
        end
    elseif not inInstance and not timerVisible and (NS.Run.active or NS.Run.waitingForMove) then
        NS.RunLogic.StopRun(false)
        NS.RunLogic.ResetRun()
    end

    return timerVisible, splitsVisible
end

local function EnterOrUpdateWorld()
    NS.Run.inInstance = IsInInstance() and true or false

    if not NS.Run.inInstance then
        DisableInstanceEvents()

        if NS.Run.active or NS.Run.waitingForMove then
            NS.RunLogic.StopRun(false)
        end

        NS.RunLogic.ResetRun()
        local timerVisible = NS.RefreshVisibility()
        if timerVisible then
            App:RegisterEvent("PLAYER_STARTED_MOVING")
            NS.Run.waitingForMove = true
            NS.UI.SetTimerText(0, false)
            if GetUnitSpeed("player") > 0 then
                NS.RunLogic.StartRunTimer()
                App:UnregisterEvent("PLAYER_STARTED_MOVING")
            end
        end
        return
    end

    EnableInstanceEvents()
    NS.RunLogic.ResetRun()
    NS.RunLogic.BeginInstanceSession()

    if GetUnitSpeed("player") > 0 then
        NS.RunLogic.StartRunTimer()
        App:UnregisterEvent("PLAYER_STARTED_MOVING")
    end
end

App:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= NS.ADDON_NAME then
            return
        end
        NS.Database.EnsureDB()
        NS.UpdateColorsFromSettings()
        NS.UI.EnsureUI()
        NS.RunLogic.ResetRun()
        if NS.CreateOptionsPanel then
            NS.CreateOptionsPanel()
        end
        NS.RefreshAllUI()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        EnterOrUpdateWorld()
        return
    end

    if event == "PLAYER_LEAVING_WORLD" then
        if NS.Run.active or NS.Run.waitingForMove then
            NS.RunLogic.StopRun(false)
        end
        DisableInstanceEvents()
        NS.UI.HideAddonFrames()
        NS.RunLogic.ResetRun()
        return
    end

    if event == "SCENARIO_CRITERIA_UPDATE" or event == "SCENARIO_UPDATE" then
        if NS.Run.inInstance and not NS.Run._bossLoaded then
            NS.RunLogic.TryLoadBossList()
        end
        return
    end

    if event == "PLAYER_STARTED_MOVING" then
        if NS.Run.waitingForMove and not NS.Run.active then
            NS.RunLogic.StartRunTimer()
            App:UnregisterEvent("PLAYER_STARTED_MOVING")
        end
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        if success == 1 then
            NS.RunLogic.RecordBossKill(encounterID, encounterName)
        end
        return
    end

    if event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        NS.RunLogic.RecordBossKill(encounterID, encounterName)
        return
    end
end)

App:RegisterEvent("ADDON_LOADED")
App:RegisterEvent("PLAYER_ENTERING_WORLD")
App:RegisterEvent("PLAYER_LEAVING_WORLD")
