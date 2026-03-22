local _, NS = ...

local Const = NS.Const
local Util = NS.Util

local function ResolveBossEntry(encounterID)
    local liveEncounterID = tonumber(encounterID)
    if not liveEncounterID then
        return nil
    end

    local entry = NS.Run.bossByDungeonEncounterID and NS.Run.bossByDungeonEncounterID[liveEncounterID]
    if not entry or not NS.Run.remaining[entry.key] then
        return nil
    end

    return entry
end

local function BuildPBProgress(entries, pbTable)
    local progress = {
        cumulativeDisplayByKey = {},
        cumulativeComparisonByKey = {},
        totalPB = 0,
    }

    local maxPB = 0
    for _, entry in ipairs(entries or {}) do
        local pbSplit = pbTable[entry.key] or pbTable[entry.name] or 0
        if pbSplit > 0 then
            progress.cumulativeDisplayByKey[entry.key] = pbSplit
            progress.cumulativeComparisonByKey[entry.key] = pbSplit
            if not NS.IsBossIgnored(entry.name) and pbSplit > maxPB then
                maxPB = pbSplit
            end
        end
    end

    progress.totalPB = maxPB
    return progress
end

local function GetActivePBSegments()
    return NS.Run.pbSegmentsSnapshot or {}
end

local function BuildColorState(r, g, b, hex)
    return {
        r = r or 1,
        g = g or 1,
        b = b or 1,
        hex = hex or "|cffffffff",
    }
end

local function GetIgnoredColorState()
    return BuildColorState(0.4, 0.4, 0.4, "|cff666666")
end

local function GetRowColorState(diffTime, isPB, isIgnored)
    if isIgnored then
        return GetIgnoredColorState()
    end
    if isPB then
        return BuildColorState(NS.Colors.gold.r, NS.Colors.gold.g, NS.Colors.gold.b, NS.Colors.gold.hex)
    end
    local r, g, b, hex = NS.GetPaceColor(diffTime, false)
    return BuildColorState(r, g, b, hex)
end

local function GetRunCompletionState(run)
    if not run or #run.entries == 0 then
        return false, nil
    end

    if run.speedrunMode == "last" then
        local lastEntry = run.entries[#run.entries]
        if lastEntry and run.kills[lastEntry.key] then
            return true, run.startGameTime + run.kills[lastEntry.key]
        end
        return false, nil
    end

    if (run.remainingCount or 0) > 0 then
        return false, nil
    end

    local maxKill = 0
    for _, killTime in pairs(run.kills or {}) do
        if killTime > maxKill then
            maxKill = killTime
        end
    end

    return true, run.startGameTime + maxKill
end

local function BuildRunPresentation(run, pbTable)
    run = run or NS.Run
    pbTable = pbTable or GetActivePBSegments()

    local progress = BuildPBProgress(run.entries, pbTable)
    local presentation = {
        rowsByKey = {},
        orderedRows = {},
        summary = {
            routePBTotal = (progress.totalPB and progress.totalPB > 0) and progress.totalPB or nil,
        },
    }

    local chronologicalLatestRow
    local maxSplit = -1
    local hasDiff = false

    local function GetChronologicalPreviousSplit(run, currentTime)
        local best = 0
        for _, split in pairs(run.kills or {}) do
            if split < (currentTime - 0.001) and split > best then
                best = split
            end
        end
        return best
    end

    for _, entry in ipairs(run.entries or {}) do
        local splitTime = run.kills and run.kills[entry.key] or nil
        local previous = splitTime and GetChronologicalPreviousSplit(run, splitTime) or nil
        local segmentTime = splitTime and ((previous and (splitTime - previous)) or splitTime) or nil
        if segmentTime and segmentTime < 0 then
            segmentTime = 0
        end

        local pbTime = progress.cumulativeDisplayByKey[entry.key]
        if pbTime ~= nil and pbTime <= 0 then
            pbTime = nil
        end

        local diffTime = nil
        local isPB = false
        if splitTime ~= nil then
            if pbTime ~= nil then
                diffTime = splitTime - pbTime
                isPB = splitTime <= (pbTime + 0.001)
            else
                isPB = true
            end
        end

        local isIgnored = NS.IsBossIgnored(entry.name)
        local color = splitTime ~= nil and GetRowColorState(diffTime or 0, isPB, isIgnored) or nil

        local row = {
            key = entry.key,
            entry = entry,
            pbTime = pbTime,
            splitTime = splitTime,
            segmentTime = segmentTime,
            diffTime = diffTime,
            isPB = isPB,
            isIgnored = isIgnored,
            color = color,
        }

        presentation.rowsByKey[entry.key] = row
        presentation.orderedRows[#presentation.orderedRows + 1] = row

        if splitTime ~= nil and not isIgnored then
            if splitTime > maxSplit then
                maxSplit = splitTime
                chronologicalLatestRow = row
            end
            if diffTime ~= nil then
                hasDiff = true
            end
        end
    end

    local finalRouteEntry = (run.entries and #run.entries > 0) and run.entries[#run.entries] or nil
    if finalRouteEntry then
        local finalPB = progress.cumulativeDisplayByKey[finalRouteEntry.key]
        if finalPB ~= nil and finalPB > 0 then
            presentation.summary.pbTotal = finalPB
        end
    end

    if chronologicalLatestRow then
        presentation.summary.splitTotal = chronologicalLatestRow.splitTime
        presentation.summary.splitColor = chronologicalLatestRow.color
        presentation.summary.latestRow = chronologicalLatestRow

        if hasDiff then
            presentation.summary.diffTotal = chronologicalLatestRow.diffTime
            presentation.summary.diffColor = chronologicalLatestRow.color
        end
    end

    return presentation
end

local function BuildRowVisualState(run, pbTable, bossKey)
    local presentation = BuildRunPresentation(run, pbTable)
    local row = presentation.rowsByKey[bossKey]
    if not row or row.splitTime == nil then
        return nil
    end

    local color = row.color or BuildColorState()
    return {
        entry = row.entry,
        splitCumulative = row.splitTime,
        splitSegment = row.segmentTime,
        cumulativePB = row.pbTime,
        delta = row.diffTime,
        isGold = row.isPB,
        r = color.r,
        g = color.g,
        b = color.b,
        hex = color.hex,
        totalPB = presentation.summary.pbTotal,
    }
end

local function PlayToastSoundOnce()
    local soundID = NS.DB and NS.DB.Settings and NS.DB.Settings.toastSoundID
    if not soundID or soundID <= 0 then
        return
    end

    local toastVol = (NS.DB.Settings.toastVolume ~= nil) and Util.Clamp(NS.DB.Settings.toastVolume, 0, 1) or nil
    local oldSFX = tonumber(GetCVar("Sound_SFXVolume") or "1") or 1
    if toastVol ~= nil then
        SetCVar("Sound_SFXVolume", tostring(toastVol))
    end

    local ok = pcall(PlaySound, soundID, "SFX")
    if not ok then
        pcall(PlaySoundFile, soundID, "SFX")
    end

    if toastVol ~= nil then
        C_Timer.After(0.25, function()
            SetCVar("Sound_SFXVolume", tostring(oldSFX))
        end)
    end
end

local function PreviewRewardForBossKey(run, pbTable, bossKey)
    local rowState = BuildRowVisualState(run or NS.Run, pbTable or GetActivePBSegments(), bossKey)
    if not rowState then
        return nil, nil
    end

    local tex = NS.GetPaceToastTexture(rowState.delta, rowState.isGold)
    NS.ShowToast(tex, rowState.isGold)
    PlayToastSoundOnce()
    return rowState, tex
end

local function SaveRunRecord(success)
    if NS.Run.isTest == true then
        return
    end

    local duration = (NS.Run.endGameTime > 0 and NS.Run.startGameTime > 0) and Util.RoundTime(NS.Run.endGameTime - NS.Run.startGameTime) or nil

    local bosses = {}
    for _, entry in ipairs(NS.Run.entries or {}) do
        bosses[#bosses + 1] = {
            key = entry.key,
            name = entry.name,
            encounterID = entry.dungeonEncounterID or entry.encounterID,
            journalEncounterID = entry.journalEncounterID,
            routeIndex = entry.routeIndex,
        }
    end

    local hasIgnoredEntries = NS.RunLogic.HasManualIgnoredEntries and
        NS.RunLogic.HasManualIgnoredEntries(NS.Run.instanceName, NS.Run.entries or {}) or false
    local pbMode = NS.Run.routeMode or ((NS.Run.speedrunMode == "last") and "last" or "route")
    local routeSaveBlocked = NS.Run.routeSaveBlocked
    if pbMode == "ignored" and not hasIgnoredEntries then
        if NS.Run.isTest == true and NS.Print then
            NS.Print(("Ignored-mode save corrected to route for %s"):format(tostring(NS.Run.instanceName or "")))
        end
        pbMode = "route"
        routeSaveBlocked = false
    end
    local record = {
        success = success and true or false,
        instanceName = NS.Run.instanceName,
        instanceType = NS.Run.instanceType,
        difficultyID = NS.Run.difficultyID,
        mapID = NS.Run.mapID,
        dungeonKey = NS.Run.dungeonKey,
        tier = NS.Run.tier,
        bossSource = NS.Run.bossSource,
        isTest = NS.Run.isTest == true,
        startedAt = NS.Run.startedAt,
        endedAt = NS.Run.endedAt,
        duration = duration,
        speedrunMode = NS.Run.speedrunMode,
        pbMode = pbMode,
        routeKey = (pbMode == "route" and success and not routeSaveBlocked)
            and NS.RunLogic.BuildRouteKeyFromIndices(NS.Run.killRouteIndices or {}) or nil,
        lastBossIndex = NS.Run.lastBossIndex,
        hasIgnoredEntries = hasIgnoredEntries,
        routeModeReason = NS.Run.routeModeReason,
        bosses = bosses,
        kills = Util.CopyTable(NS.Run.kills or {}),
        gameBuild = select(4, GetBuildInfo()),
    }

    table.insert(NS.DB.RunHistory, 1, record)
    if NS.Database and NS.Database.PurgeTestRunHistory then
        NS.Database.PurgeTestRunHistory(NS.DB)
    end
    while #NS.DB.RunHistory > Const.RUN_HISTORY.RUNS_MAX do
        table.remove(NS.DB.RunHistory)
    end

    if pbMode == "route" then
        NS.Database.ApplyRouteRecord(record)
    elseif pbMode == "ignored" then
        NS.Database.ApplyIgnoredRecord(record)
    elseif pbMode == "last" then
        NS.Database.ApplyLastBossRecord(record)
    end
end

local function RecordBossKill(encounterID, encounterName)
    if not NS.Run.active or NS.Run.startGameTime <= 0 then
        return
    end

    local bossEntry = ResolveBossEntry(encounterID)
    if not bossEntry or NS.Run.kills[bossEntry.key] ~= nil then
        return
    end

    local splitCumulative = Util.RoundTime(NS.NowGameTime() - NS.Run.startGameTime)
    NS.Run.kills[bossEntry.key] = splitCumulative
    bossEntry.completed = true
    bossEntry.killTimeMS = math.floor(splitCumulative * 1000 + 0.5)

    if NS.Run.remaining[bossEntry.key] then
        NS.Run.remaining[bossEntry.key] = nil
        NS.Run.remainingCount = math.max(0, (NS.Run.remainingCount or 0) - 1)
        NS.Run.killedCount = math.min(#NS.Run.entries, (NS.Run.killedCount or 0) + 1)
    end

    if bossEntry.routeIndex then
        NS.Run.killOrder[#NS.Run.killOrder + 1] = bossEntry.key
        NS.Run.killRouteIndices[#NS.Run.killRouteIndices + 1] = bossEntry.routeIndex
    end

    if NS.Run.routeMode == "ignored" then
        local ignoredNode = NS.Database.GetBestIgnoredNode(NS.Run.instanceName, true)
        if ignoredNode and bossEntry.routeIndex then
            NS.Database.UpdateBestSplit(ignoredNode, bossEntry.routeIndex, splitCumulative)
        end
    elseif NS.Run.routeMode == "route" and NS.RunLogic.HandleRouteProgression then
        NS.RunLogic.HandleRouteProgression()
    end

    if NS.Run.routeMode ~= "route" and NS.RunLogic.RefreshRunDisplay then
        NS.RunLogic.RefreshRunDisplay()
    end

    local pbSnapshot = GetActivePBSegments()
    local presentation = BuildRunPresentation(NS.Run, pbSnapshot)
    local rowState = presentation.rowsByKey[bossEntry.key]
    if not rowState then
        return
    end

    local isNewPB = rowState.isPB

    NS.Run.presentation = presentation

    local isRunComplete = false
    if NS.Run.speedrunMode == "last" then
        local lastEntry = NS.Run.entries[#NS.Run.entries]
        isRunComplete = lastEntry and lastEntry.key == bossEntry.key
    else
        isRunComplete = (NS.Run.remainingCount or 0) == 0 and #NS.Run.entries > 0
    end

    local comparisonNode
    if NS.Run.routeMode == "last" then
        comparisonNode = NS.Database.GetBestLastBossNode(NS.Run.instanceName, false)
    elseif NS.Run.routeMode == "ignored" then
        comparisonNode = NS.Database.GetBestIgnoredNode(NS.Run.instanceName, false)
    elseif NS.Run.activeRouteKey then
        comparisonNode = NS.Database.GetRouteNode(NS.Run.instanceName, NS.Run.activeRouteKey, false)
    end

    local isFullRunPB = false
    if isRunComplete then
        local existingRunPB = comparisonNode and comparisonNode.FullRun and comparisonNode.FullRun.duration
        local target = (existingRunPB and existingRunPB > 0) and existingRunPB or presentation.summary.pbTotal
        isFullRunPB = (not target or target == 0 or splitCumulative <= (target + 0.001))
    end
    local toastIsPB = isRunComplete and isFullRunPB or isNewPB

    if NS.DB.Settings.showTimerToast then
        local shouldToast = NS.DB.Settings.toastAllBosses or isRunComplete
        if shouldToast then
            local tex = NS.GetPaceToastTexture(rowState.diffTime, toastIsPB)
            NS.ShowToast(tex, toastIsPB)
            PlayToastSoundOnce()
        end
    end

    local summary = presentation.summary or {}
    local displayColor = summary.diffColor or summary.splitColor
    NS.Run.lastDelta = summary.diffTotal
    NS.Run.lastPBTotal = summary.pbTotal
    NS.Run.lastSplitCumulative = summary.splitTotal
    NS.Run.lastColorR, NS.Run.lastColorG, NS.Run.lastColorB, NS.Run.lastColorHex =
        displayColor and displayColor.r or nil,
        displayColor and displayColor.g or nil,
        displayColor and displayColor.b or nil,
        displayColor and displayColor.hex or nil
    NS.Run.lastIsPB = toastIsPB

    local completeNow, completionTime = NS.RunLogic.GetRunCompletionState(NS.Run)
    if completeNow and #NS.Run.entries > 0 then
        NS.RunLogic.StopRun(true, completionTime)
    end
end

NS.RunLogic.ResolveBossEntry = ResolveBossEntry
NS.RunLogic.BuildPBProgress = BuildPBProgress
NS.RunLogic.BuildRunPresentation = BuildRunPresentation
NS.RunLogic.BuildRowVisualState = BuildRowVisualState
NS.RunLogic.GetRunCompletionState = GetRunCompletionState
NS.RunLogic.PreviewRewardForBossKey = PreviewRewardForBossKey
NS.RunLogic.SaveRunRecord = SaveRunRecord
NS.RunLogic.RecordBossKill = RecordBossKill
