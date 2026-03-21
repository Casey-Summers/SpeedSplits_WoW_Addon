local _, NS = ...

local Const = NS.Const
local Util = NS.Util

local function ApplyBossEntries(entries, source, context)
    NS.Run.entries = entries or {}
    NS.Run.bosses = NS.Run.entries
    NS.Run.bossSource = source or "none"
    context = context or {}
    NS.Run.instance = {
        uiMapID = tonumber(context.uiMapID) or nil,
        mapID = tonumber(context.mapID) or 0,
        journalInstanceID = tonumber(context.journalInstanceID) or nil,
        name = context.name or NS.Run.instanceName or "",
        difficultyID = tonumber(context.difficultyID) or NS.Run.difficultyID or 0,
        instanceType = context.instanceType or NS.Run.instanceType or "",
    }
    NS.Run.tier = tonumber(context.tier) or 0
    NS.Run.journalID = NS.Run.instance.journalInstanceID

    NS.Run.remaining = {}
    NS.Run.remainingCount = 0
    NS.Run.killedCount = 0
    NS.Run.kills = {}
    NS.Run.bossByJournalEncounterID = {}
    NS.Run.bossByDungeonEncounterID = {}

    local seen = {}
    for index, entry in ipairs(NS.Run.entries) do
        entry.rowIndex = tonumber(entry.rowIndex) or index
        entry.bossName = entry.bossName or entry.name or ""
        entry.name = entry.bossName
        entry.completed = false
        entry.killTimeMS = nil
        entry.encounterID = tonumber(entry.dungeonEncounterID or entry.encounterID) or nil
        entry.dungeonEncounterID = entry.encounterID
        entry.journalEncounterID = tonumber(entry.journalEncounterID) or nil

        if entry.key and entry.key ~= "" and not seen[entry.key] then
            seen[entry.key] = true
            NS.Run.remaining[entry.key] = true
            NS.Run.remainingCount = NS.Run.remainingCount + 1
        end
        if entry.journalEncounterID then
            NS.Run.bossByJournalEncounterID[entry.journalEncounterID] = entry
        end
        if entry.dungeonEncounterID then
            NS.Run.bossByDungeonEncounterID[entry.dungeonEncounterID] = entry
        end
    end

    NS.RunLogic.SyncAutoIgnoredBosses()

    local node = NS.GetBestSplitsSubtable()
    local pbSplits = node and node.Segments or {}
    NS.Run.pbSegmentsSnapshot = Util.CopyTable(pbSplits)
    NS.Run.presentation = NS.RunLogic.BuildRunPresentation(NS.Run, NS.Run.pbSegmentsSnapshot)
    NS.UI.RefreshBossTableData(NS.Run.entries, NS.Run.presentation)
    NS.UI.SetKillCount(0, #NS.Run.entries)
    NS.UI.RefreshTotals(false)
    NS.Run._bossLoaded = true
end

local function ForceLoadEJ()
    local context = NS.Discovery.BuildInstanceContext()
    if context.journalInstanceID then
        local ejBosses = NS.Discovery.GetEJBossesForInstance(context.journalInstanceID)
        if #ejBosses > 0 then
            ApplyBossEntries(NS.Discovery.EJBossesToEntries(ejBosses), "encounter_journal", context)
            return
        end
    end
    ApplyBossEntries({}, "none", context)
end

local function TryLoadBossList()
    if NS.Run._bossLoaded or not NS.Run.inInstance then
        return
    end
    NS.Run._bossLoadTries = (NS.Run._bossLoadTries or 0) + 1
    local entries, source, context, ready = NS.Discovery.BuildBossEntries()
    if not ready then
        if NS.Run._bossLoadTries >= Const.BOSS_MODEL.LOAD_MAX_TRIES then
            ForceLoadEJ()
            return
        end
        C_Timer.After(Const.BOSS_MODEL.LOAD_RETRY_DELAY, function()
            if NS.Run.inInstance and not NS.Run._bossLoaded then
                TryLoadBossList()
            end
        end)
        return
    end

    ApplyBossEntries(entries, source, context)
end

local function BeginInstanceSession()
    if NS.UI.EnsureUI then
        NS.UI.EnsureUI()
    end

    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    local context = NS.Discovery.BuildInstanceContext()

    NS.Run.instanceName = name or ""
    NS.Run.instanceType = instanceType or ""
    NS.Run.difficultyID = tonumber(difficultyID) or 0
    NS.Run.difficultyName = difficultyName or ""
    NS.Run.mapID = tonumber(mapID) or 0
    NS.Run.journalID = context.journalInstanceID
    NS.Run.tier = tonumber(context.tier) or 0
    NS.Run.dungeonKey = Util.GetDungeonKey(NS.Run.mapID, NS.Run.difficultyID)
    NS.Run.speedrunMode = (NS.DB and NS.DB.Settings and NS.DB.Settings.speedrunMode) or "all"
    NS.Run._bossLoadTries = 0
    NS.Run._bossLoaded = false
    NS.Run.instance = {
        uiMapID = tonumber(context.uiMapID) or nil,
        mapID = NS.Run.mapID,
        journalInstanceID = context.journalInstanceID,
        name = NS.Run.instanceName,
        difficultyID = NS.Run.difficultyID,
        instanceType = NS.Run.instanceType,
    }

    if NS.UI.ShowAddonFrames then
        NS.UI.ShowAddonFrames()
    end

    NS.Run.waitingForMove = true
    NS.UI.SetTimerText(0, false)
    TryLoadBossList()
end

NS.RunLogic.ApplyBossEntries = ApplyBossEntries
NS.RunLogic.TryLoadBossList = TryLoadBossList
NS.RunLogic.ForceLoadEJ = ForceLoadEJ
NS.RunLogic.BeginInstanceSession = BeginInstanceSession
