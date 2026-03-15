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

local function SaveRunRecord(success)
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
        startedAt = NS.Run.startedAt,
        endedAt = NS.Run.endedAt,
        duration = duration,
        speedrunMode = NS.Run.speedrunMode,
        bosses = bosses,
        kills = NS.Run.kills,
        gameBuild = select(4, GetBuildInfo()),
    }

    table.insert(NS.DB.RunHistory, 1, record)
    while #NS.DB.RunHistory > Const.RUNS_MAX do
        table.remove(NS.DB.RunHistory)
    end

    if success and duration then
        NS.RunLogic.UpdateBestRunIfNeeded(duration)
    end
end

local function GetIgnoreTables(instanceName)
    local settings = NS.DB and NS.DB.Settings
    if not settings or not instanceName or instanceName == "" then
        return nil, nil
    end

    settings.ignoredBosses = settings.ignoredBosses or {}
    settings.autoIgnoredBosses = settings.autoIgnoredBosses or {}
    settings.ignoredBosses[instanceName] = settings.ignoredBosses[instanceName] or {}
    settings.autoIgnoredBosses[instanceName] = settings.autoIgnoredBosses[instanceName] or {}

    return settings.ignoredBosses[instanceName], settings.autoIgnoredBosses[instanceName]
end

local function SyncAutoIgnoredBosses()
    local instanceName = NS.Run and NS.Run.instanceName
    if not instanceName or instanceName == "" then
        return
    end

    local manualIgnored, autoIgnored = GetIgnoreTables(instanceName)
    if not manualIgnored or not autoIgnored then
        return
    end

    wipe(autoIgnored)

    if NS.Run.speedrunMode ~= "last" then
        return
    end

    local lastEntry = NS.Run.entries[#NS.Run.entries]
    if not lastEntry then
        return
    end

    for _, entry in ipairs(NS.Run.entries) do
        if entry.key ~= lastEntry.key and not manualIgnored[entry.name] then
            autoIgnored[entry.name] = true
        end
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
    local bossName = bossEntry.name

    local splitCumulative = NS.NowGameTime() - NS.Run.startGameTime
    NS.Run.kills[bossKey] = splitCumulative

    if NS.Run.remaining[bossKey] then
        NS.Run.remaining[bossKey] = nil
        NS.Run.remainingCount = math.max(0, (NS.Run.remainingCount or 0) - 1)
        NS.Run.killedCount = math.min(#NS.Run.entries, (NS.Run.killedCount or 0) + 1)
    end

    local prevCumulative = NS.UI.GetPreviousKilledCumulativeInTableOrder(NS.Run, bossKey)
    local splitSegment = prevCumulative and (splitCumulative - prevCumulative) or splitCumulative
    if splitSegment < 0 then
        splitSegment = 0
    end

    local node = NS.GetBestSplitsSubtable()
    local pbTable = node and node.Segments
    if not pbTable then
        return
    end

    local oldSegmentPB = pbTable[bossName]
    local isNewSegmentPB = (oldSegmentPB == nil or oldSegmentPB == 0) or (splitSegment <= oldSegmentPB + 0.001)

    local cumulativePB_Comparison = 0
    for _, entry in ipairs(NS.Run.entries) do
        if not NS.IsBossIgnored(entry.name) then
            cumulativePB_Comparison = cumulativePB_Comparison + (pbTable[entry.name] or 0)
        end
        if entry.key == bossKey then
            break
        end
    end
    local deltaOverallAtKill = splitCumulative - cumulativePB_Comparison

    if isNewSegmentPB then
        pbTable[bossName] = splitSegment
    end

    local isRunComplete
    if NS.Run.speedrunMode == "last" then
        local lastEntry = NS.Run.entries[#NS.Run.entries]
        isRunComplete = lastEntry and lastEntry.key == bossKey
    else
        isRunComplete = (NS.Run.remainingCount or 0) == 0 and #NS.Run.entries > 0
    end

    local isFullRunPB = false
    if isRunComplete then
        local existingPB = node and node.FullRun and node.FullRun.duration
        local target = (existingPB and existingPB > 0) and existingPB or cumulativePB_Comparison
        isFullRunPB = (not target or target == 0 or splitCumulative <= (target + 0.001))
    end
    local toastIsPB = isRunComplete and isFullRunPB or isNewSegmentPB

    if NS.DB.Settings.showTimerToast then
        local shouldToast = NS.DB.Settings.toastAllBosses or isRunComplete
        if shouldToast then
            local tex = NS.GetPaceToastTexture(deltaOverallAtKill, toastIsPB)
            NS.ShowToast(tex, toastIsPB)
        end
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

    NS.PlayToastSoundOnce = PlayToastSoundOnce

    local cumulativePB_Display = 0
    for _, entry in ipairs(NS.Run.entries) do
        if not NS.IsBossIgnored(entry.name) then
            cumulativePB_Display = cumulativePB_Display + (pbTable[entry.name] or 0)
        end
        if entry.key == bossKey then
            break
        end
    end

    local pbTotalTableSum = NS.RunLogic.ComputeSumOfBest(pbTable, NS.Run.entries) or 0
    local deltaOverall = splitCumulative - cumulativePB_Comparison
    local r, g, b, hex = NS.GetPaceColor(deltaOverall, toastIsPB)

    NS.Run.lastDelta = deltaOverall
    NS.Run.lastPBTotal = pbTotalTableSum
    NS.Run.lastSplitCumulative = splitCumulative
    NS.Run.lastColorR, NS.Run.lastColorG, NS.Run.lastColorB, NS.Run.lastColorHex = r, g, b, hex
    NS.Run.lastIsPB = toastIsPB

    NS.UI.SetRowKilled(bossKey, splitCumulative, cumulativePB_Display, deltaOverall, r, g, b, hex, isNewSegmentPB, pbTable[bossName])
    NS.UI.SetKillCount(NS.Run.killedCount, #NS.Run.entries)
    NS.UI.RefreshTotals(false)

    if NS.Run.speedrunMode == "last" then
        local lastEntry = NS.Run.entries[#NS.Run.entries]
        isRunComplete = lastEntry and lastEntry.key == bossKey
    else
        isRunComplete = (NS.Run.remainingCount or 0) == 0
    end

    if isRunComplete and #NS.Run.entries > 0 then
        NS.RunLogic.StopRun(true)
    end
end

local function ApplyBossEntries(entries, source, tier, journalID)
    NS.Run.entries = entries or {}
    NS.Run.bossSource = source or "none"
    NS.Run.tier = tonumber(tier) or 0
    NS.Run.journalID = journalID

    NS.Run.remaining = {}
    NS.Run.remainingCount = 0
    NS.Run.killedCount = 0
    NS.Run.kills = {}

    local seen = {}
    for _, entry in ipairs(NS.Run.entries) do
        if entry.key and entry.key ~= "" and not seen[entry.key] then
            seen[entry.key] = true
            NS.Run.remaining[entry.key] = true
            NS.Run.remainingCount = NS.Run.remainingCount + 1
        end
    end

    SyncAutoIgnoredBosses()

    local node = NS.GetBestSplitsSubtable()
    local pbSplits = node and node.Segments or {}
    NS.UI.RenderBossTable(NS.Run.entries, pbSplits)
    NS.UI.SetKillCount(0, #NS.Run.entries)
    NS.UI.RefreshTotals(false)
    NS.Run._bossLoaded = true
end

local function ForceLoadEJ()
    local tier, journalID = NS.Discovery.GetJournalTierAndInstanceIDForCurrentInstance()
    if journalID then
        local ejBosses = NS.Discovery.GetEJBossesForInstance(journalID)
        if #ejBosses > 0 then
            ApplyBossEntries(NS.Discovery.EJBossesToEntries(ejBosses), "encounter_journal", tier, journalID)
            return
        end
    end
    ApplyBossEntries({}, "none", tier, journalID)
end

local function TryLoadBossList()
    if NS.Run._bossLoaded or not NS.Run.inInstance then
        return
    end
    NS.Run._bossLoadTries = (NS.Run._bossLoadTries or 0) + 1
    local entries, source, tier, journalID, ready = NS.Discovery.BuildBossEntries()
    if not ready then
        if NS.Run._bossLoadTries >= Const.BOSS_LOAD_MAX_TRIES then
            ForceLoadEJ()
            return
        end
        C_Timer.After(Const.BOSS_LOAD_RETRY_DELAY, function()
            if NS.Run.inInstance and not NS.Run._bossLoaded then
                TryLoadBossList()
            end
        end)
        return
    end

    ApplyBossEntries(entries, source, tier, journalID)
end

local function BeginInstanceSession()
    if NS.UI.EnsureUI then
        NS.UI.EnsureUI()
    end

    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    local tier, journalID = NS.Discovery.GetJournalTierAndInstanceIDForCurrentInstance()

    NS.Run.instanceName = name or ""
    NS.Run.instanceType = instanceType or ""
    NS.Run.difficultyID = tonumber(difficultyID) or 0
    NS.Run.difficultyName = difficultyName or ""
    NS.Run.mapID = tonumber(mapID) or 0
    NS.Run.journalID = journalID
    NS.Run.tier = tonumber(tier) or 0
    NS.Run.dungeonKey = Util.GetDungeonKey(NS.Run.mapID, NS.Run.difficultyID)
    NS.Run.speedrunMode = (NS.DB and NS.DB.Settings and NS.DB.Settings.speedrunMode) or "all"
    NS.Run._bossLoadTries = 0
    NS.Run._bossLoaded = false

    if NS.UI.ShowAddonFrames then
        NS.UI.ShowAddonFrames()
    end

    NS.Run.waitingForMove = true
    NS.UI.SetTimerText(0, false)
    TryLoadBossList()
end

NS.RunLogic.ResolveBossKey = ResolveBossKey
NS.RunLogic.SaveRunRecord = SaveRunRecord
NS.RunLogic.SyncAutoIgnoredBosses = SyncAutoIgnoredBosses
NS.RunLogic.RecordBossKill = RecordBossKill
NS.RunLogic.ApplyBossEntries = ApplyBossEntries
NS.RunLogic.TryLoadBossList = TryLoadBossList
NS.RunLogic.ForceLoadEJ = ForceLoadEJ
NS.RunLogic.BeginInstanceSession = BeginInstanceSession

NS.ApplyBossEntries = ApplyBossEntries
NS.RecordBossKill = RecordBossKill
NS.BeginInstanceSession = BeginInstanceSession
