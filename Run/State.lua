local _, NS = ...

local Run = NS.Run or {}

Run.inInstance = Run.inInstance or false
Run.active = Run.active or false
Run.waitingForMove = Run.waitingForMove or false
Run.instanceName = Run.instanceName or ""
Run.instanceType = Run.instanceType or ""
Run.difficultyID = Run.difficultyID or 0
Run.mapID = Run.mapID or 0
Run.journalID = Run.journalID or nil
Run.tier = Run.tier or 0
Run.dungeonKey = Run.dungeonKey or ""
Run.bossSource = Run.bossSource or "none"
Run.instance = Run.instance or {}
Run.bosses = Run.bosses or {}
Run.bossByJournalEncounterID = Run.bossByJournalEncounterID or {}
Run.bossByDungeonEncounterID = Run.bossByDungeonEncounterID or {}
Run.pbSegmentsSnapshot = Run.pbSegmentsSnapshot or {}
Run.entries = Run.entries or {}
Run.remaining = Run.remaining or {}
Run.remainingCount = Run.remainingCount or 0
Run.killedCount = Run.killedCount or 0
Run.kills = Run.kills or {}
Run.startGameTime = Run.startGameTime or 0
Run.endGameTime = Run.endGameTime or 0
Run.startedAt = Run.startedAt or 0
Run.endedAt = Run.endedAt or 0
Run.speedrunMode = Run.speedrunMode or "all"
Run.isTest = Run.isTest or false
Run.routeMode = Run.routeMode or "route"
Run.activeRouteKey = Run.activeRouteKey or nil
Run.defaultRouteKey = Run.defaultRouteKey or nil
Run.killOrder = Run.killOrder or {}
Run.killRouteIndices = Run.killRouteIndices or {}
Run.routeExploring = Run.routeExploring or false
Run.routeSaveBlocked = Run.routeSaveBlocked or false
Run.lastBossIndex = Run.lastBossIndex or nil
Run.routeModeReason = Run.routeModeReason or "route-default"
Run.hasIgnoredEntries = Run.hasIgnoredEntries or false
Run._bossLoadTries = Run._bossLoadTries or 0
Run._bossLoaded = Run._bossLoaded or false

NS.Run = Run

local function IsBossIgnored(bossName)
    local db = NS.DB
    local instanceName = NS.Run and NS.Run.instanceName
    if not instanceName or instanceName == "" or not bossName or not db then
        return false
    end
    local settings = db.Settings
    if not settings then
        return false
    end
    return (settings.ignoredBosses and settings.ignoredBosses[instanceName] and settings.ignoredBosses[instanceName][bossName]) or
        (settings.autoIgnoredBosses and settings.autoIgnoredBosses[instanceName] and settings.autoIgnoredBosses[instanceName][bossName]) or
        false
end

local function ResetRun()
    Run.active = false
    Run.waitingForMove = false
    if NS.RunLogic.CancelTimerTicker then
        NS.RunLogic.CancelTimerTicker()
    end
    Run.entries = {}
    Run.bosses = {}
    Run.instance = {}
    Run.bossByJournalEncounterID = {}
    Run.bossByDungeonEncounterID = {}
    Run.pbSegmentsSnapshot = {}
    Run.presentation = nil
    Run.remaining = {}
    Run.remainingCount = 0
    Run.killedCount = 0
    Run.kills = {}
    Run.startGameTime = 0
    Run.endGameTime = 0
    Run.startedAt = 0
    Run.endedAt = 0
    Run.isTest = false
    Run.routeMode = "route"
    Run.activeRouteKey = nil
    Run.defaultRouteKey = nil
    Run.killOrder = {}
    Run.killRouteIndices = {}
    Run.routeExploring = false
    Run.routeSaveBlocked = false
    Run.lastBossIndex = nil
    Run.routeModeReason = "route-default"
    Run.hasIgnoredEntries = false
    Run.lastDelta = 0
    Run.lastColorR, Run.lastColorG, Run.lastColorB, Run.lastColorHex = nil, nil, nil, nil
    Run._bossLoadTries = 0
    Run._bossLoaded = false
end

local function ResetRunPresentation()
    if NS.UI.SetTimerText then
        NS.UI.SetTimerText(0, false)
    end
    if NS.UI.SetKillCount then
        NS.UI.SetKillCount(0, 0)
    end
    if NS.UI.ClearBossRows then
        NS.UI.ClearBossRows()
    end
    if NS.SetTotals then
        NS.SetTotals(nil, nil, nil)
    end
    if NS.UI.SetTimerDelta then
        NS.UI.SetTimerDelta(nil)
    end
end

NS.RunLogic.IsBossIgnored = IsBossIgnored
NS.RunLogic.ResetRun = ResetRun
NS.UI.ResetRunPresentation = ResetRunPresentation
NS.IsBossIgnored = IsBossIgnored
