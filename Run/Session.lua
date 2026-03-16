local _, NS = ...

local Const = NS.Const
local Util = NS.Util

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

    NS.RunLogic.SyncAutoIgnoredBosses()

    local node = NS.GetBestSplitsSubtable()
    local pbSplits = node and node.Segments or {}
    NS.UI.RefreshBossTableData(NS.Run.entries, pbSplits)
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

NS.RunLogic.ApplyBossEntries = ApplyBossEntries
NS.RunLogic.TryLoadBossList = TryLoadBossList
NS.RunLogic.ForceLoadEJ = ForceLoadEJ
NS.RunLogic.BeginInstanceSession = BeginInstanceSession
