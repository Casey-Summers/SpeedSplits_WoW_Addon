local _, NS = ...

local Const = NS.Const
local Util = NS.Util

local function ResolveBossKey(encounterID, encounterName)
    if encounterID then
        local keyByID = "E:" .. tostring(tonumber(encounterID) or 0)
        if NS.Run.remaining[keyByID] then
            return keyByID
        end
    end

    local normalized = Util.NormalizeName(encounterName)
    if normalized ~= "" then
        local keyByName = "N:" .. normalized
        if NS.Run.remaining[keyByName] then
            return keyByName
        end

        for _, entry in ipairs(NS.Run.entries or {}) do
            if Util.NormalizeName(entry.name) == normalized and NS.Run.remaining[entry.key] then
                return entry.key
            end
        end
    end

    return nil
end

local function BuildPBProgress(entries, pbTable)
    local progress = {
        cumulativeDisplayByKey = {},
        cumulativeComparisonByKey = {},
        totalPB = 0,
    }

    local cumulative = 0
    for _, entry in ipairs(entries or {}) do
        if not NS.IsBossIgnored(entry.name) then
            cumulative = cumulative + (pbTable[entry.name] or 0)
        end
        progress.cumulativeDisplayByKey[entry.key] = cumulative
        progress.cumulativeComparisonByKey[entry.key] = cumulative
    end

    progress.totalPB = cumulative
    return progress
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

local function BuildRowVisualState(run, pbTable, bossKey)
    local splitCumulative = run.kills and run.kills[bossKey]
    if splitCumulative == nil then
        return nil
    end

    local entry
    for _, candidate in ipairs(run.entries or {}) do
        if candidate.key == bossKey then
            entry = candidate
            break
        end
    end
    if not entry then
        return nil
    end

    local previous = NS.UI.GetPreviousKilledCumulativeInTableOrder(run, bossKey)
    local splitSegment = previous and (splitCumulative - previous) or splitCumulative
    if splitSegment < 0 then
        splitSegment = 0
    end

    local progress = BuildPBProgress(run.entries, pbTable)
    local cumulativePB = progress.cumulativeDisplayByKey[bossKey] or 0
    local delta = splitCumulative - (progress.cumulativeComparisonByKey[bossKey] or 0)
    local oldSegPB = pbTable[entry.name]
    local isGold = (not oldSegPB) or (splitSegment <= oldSegPB + 0.001)
    local r, g, b, hex = NS.GetPaceColor(delta, false)

    return {
        entry = entry,
        splitCumulative = splitCumulative,
        splitSegment = splitSegment,
        cumulativePB = cumulativePB,
        delta = delta,
        isGold = isGold,
        r = r,
        g = g,
        b = b,
        hex = hex,
        totalPB = progress.totalPB or 0,
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

local function SaveRunRecord(success)
    if NS.Run.isTest == true then
        return
    end

    local duration = (NS.Run.endGameTime > 0 and NS.Run.startGameTime > 0) and (NS.Run.endGameTime - NS.Run.startGameTime) or nil

    local bosses = {}
    for _, entry in ipairs(NS.Run.entries or {}) do
        bosses[#bosses + 1] = {
            key = entry.key,
            name = entry.name,
            encounterID = entry.encounterID,
        }
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
        bosses = bosses,
        kills = NS.Run.kills,
        gameBuild = select(4, GetBuildInfo()),
    }

    table.insert(NS.DB.RunHistory, 1, record)
    if NS.Database and NS.Database.PurgeTestRunHistory then
        NS.Database.PurgeTestRunHistory(NS.DB)
    end
    while #NS.DB.RunHistory > Const.RUNS_MAX do
        table.remove(NS.DB.RunHistory)
    end

    if success and duration then
        NS.RunLogic.UpdateBestRunIfNeeded(duration)
    end
end

local function RecordBossKill(encounterID, encounterName)
    if not NS.Run.active or NS.Run.startGameTime <= 0 then
        return
    end

    local bossKey = ResolveBossKey(encounterID, encounterName)
    if not bossKey or NS.Run.kills[bossKey] ~= nil then
        return
    end

    local bossEntry
    for _, entry in ipairs(NS.Run.entries or {}) do
        if entry.key == bossKey then
            bossEntry = entry
            break
        end
    end
    if not bossEntry then
        return
    end

    local splitCumulative = NS.NowGameTime() - NS.Run.startGameTime
    NS.Run.kills[bossKey] = splitCumulative

    if NS.Run.remaining[bossKey] then
        NS.Run.remaining[bossKey] = nil
        NS.Run.remainingCount = math.max(0, (NS.Run.remainingCount or 0) - 1)
        NS.Run.killedCount = math.min(#NS.Run.entries, (NS.Run.killedCount or 0) + 1)
    end

    local node = NS.GetBestSplitsSubtable()
    local pbTable = node and node.Segments
    if not pbTable then
        return
    end

    local visualState = BuildRowVisualState(NS.Run, pbTable, bossKey)
    if not visualState then
        return
    end

    local isNewSegmentPB = (pbTable[bossEntry.name] == nil or pbTable[bossEntry.name] == 0) or
        (visualState.splitSegment <= (pbTable[bossEntry.name] + 0.001))
    if isNewSegmentPB then
        pbTable[bossEntry.name] = visualState.splitSegment
        visualState = BuildRowVisualState(NS.Run, pbTable, bossKey)
    end

    local isRunComplete = false
    if NS.Run.speedrunMode == "last" then
        local lastEntry = NS.Run.entries[#NS.Run.entries]
        isRunComplete = lastEntry and lastEntry.key == bossKey
    else
        isRunComplete = (NS.Run.remainingCount or 0) == 0 and #NS.Run.entries > 0
    end

    local isFullRunPB = false
    if isRunComplete then
        local existingPB = node and node.FullRun and node.FullRun.duration
        local target = (existingPB and existingPB > 0) and existingPB or visualState.cumulativePB
        isFullRunPB = (not target or target == 0 or visualState.splitCumulative <= (target + 0.001))
    end
    local toastIsPB = isRunComplete and isFullRunPB or isNewSegmentPB

    if NS.DB.Settings.showTimerToast then
        local shouldToast = NS.DB.Settings.toastAllBosses or isRunComplete
        if shouldToast then
            local tex = NS.GetPaceToastTexture(visualState.delta, toastIsPB)
            NS.ShowToast(tex, toastIsPB)
            PlayToastSoundOnce()
        end
    end

    NS.Run.lastDelta = visualState.delta
    NS.Run.lastPBTotal = visualState.totalPB
    NS.Run.lastSplitCumulative = visualState.splitCumulative
    NS.Run.lastColorR, NS.Run.lastColorG, NS.Run.lastColorB, NS.Run.lastColorHex =
        visualState.r, visualState.g, visualState.b, visualState.hex
    NS.Run.lastIsPB = toastIsPB

    NS.UI.SetRowKilled(
        bossKey,
        visualState.splitCumulative,
        visualState.cumulativePB,
        visualState.delta,
        visualState.r,
        visualState.g,
        visualState.b,
        visualState.hex,
        isNewSegmentPB
    )
    NS.UI.SetKillCount(NS.Run.killedCount, #NS.Run.entries)
    NS.UI.RefreshTotals(false)

    local completeNow = NS.RunLogic.GetRunCompletionState(NS.Run)
    if completeNow and #NS.Run.entries > 0 then
        NS.RunLogic.StopRun(true)
    end
end

NS.RunLogic.ResolveBossKey = ResolveBossKey
NS.RunLogic.BuildPBProgress = BuildPBProgress
NS.RunLogic.BuildRowVisualState = BuildRowVisualState
NS.RunLogic.GetRunCompletionState = GetRunCompletionState
NS.RunLogic.SaveRunRecord = SaveRunRecord
NS.RunLogic.RecordBossKill = RecordBossKill
