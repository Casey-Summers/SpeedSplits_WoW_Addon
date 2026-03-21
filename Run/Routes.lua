local _, NS = ...

local Util = NS.Util

local function BuildEntryNameSet(entries)
    local names = {}
    for _, entry in ipairs(entries or {}) do
        local bossName = entry and entry.name
        if bossName and bossName ~= "" then
            names[bossName] = true
        end
    end
    return names
end

local function NormalizeManualIgnoredBosses(instanceName, entries)
    local settings = NS.DB and NS.DB.Settings
    local ignored = settings and settings.ignoredBosses and settings.ignoredBosses[instanceName]
    if type(ignored) ~= "table" then
        return nil, false
    end

    local validNames = BuildEntryNameSet(entries)
    local hasLiveIgnored = false
    for bossName in pairs(ignored) do
        if not validNames[bossName] then
            ignored[bossName] = nil
        else
            hasLiveIgnored = true
        end
    end

    return ignored, hasLiveIgnored
end

local function HasManualIgnoredEntries(instanceName, entries)
    local _, hasLiveIgnored = NormalizeManualIgnoredBosses(instanceName, entries)
    return hasLiveIgnored
end

local function ParseRouteKey(routeKey)
    local indices = {}
    for token in tostring(routeKey or ""):gmatch("[^,]+") do
        local value = tonumber(token)
        if value then
            indices[#indices + 1] = value
        end
    end
    return indices
end

local function BuildRouteKeyFromIndices(indices)
    local parts = {}
    for _, value in ipairs(indices or {}) do
        if type(value) == "number" then
            parts[#parts + 1] = tostring(value)
        end
    end
    return table.concat(parts, ",")
end

local function BuildEntryByRouteIndex(entries)
    local map = {}
    for _, entry in ipairs(entries or {}) do
        local routeIndex = tonumber(entry and entry.routeIndex)
        if routeIndex then
            map[routeIndex] = entry
        end
    end
    return map
end

local function ReorderEntriesByRouteKey(entries, routeKey)
    local ordered = {}
    local used = {}
    local byIndex = BuildEntryByRouteIndex(entries)

    for _, routeIndex in ipairs(ParseRouteKey(routeKey)) do
        local entry = byIndex[routeIndex]
        if entry and not used[entry.key] then
            used[entry.key] = true
            ordered[#ordered + 1] = entry
        end
    end

    for _, entry in ipairs(entries or {}) do
        if not used[entry.key] then
            ordered[#ordered + 1] = entry
        end
    end

    return ordered
end

local function RebuildEntryMappings()
    NS.Run.bosses = NS.Run.entries
    NS.Run.bossByJournalEncounterID = {}
    NS.Run.bossByDungeonEncounterID = {}

    for index, entry in ipairs(NS.Run.entries or {}) do
        entry.rowIndex = index
        entry.completed = NS.Run.kills[entry.key] ~= nil
        entry.killTimeMS = entry.completed and math.floor((NS.Run.kills[entry.key] or 0) * 1000 + 0.5) or nil

        if entry.journalEncounterID then
            NS.Run.bossByJournalEncounterID[entry.journalEncounterID] = entry
        end
        if entry.dungeonEncounterID then
            NS.Run.bossByDungeonEncounterID[entry.dungeonEncounterID] = entry
        end
    end
end

local function BuildSnapshotFromNode(node, entries)
    local snapshot = {}
    node = node or {}
    local splits = node.Splits or {}

    for _, entry in ipairs(entries or {}) do
        local routeIndex = tonumber(entry and entry.routeIndex)
        local splitTime = routeIndex and tonumber(splits[routeIndex]) or nil
        if routeIndex and splitTime and splitTime > 0 then
            snapshot[entry.key] = Util.RoundTime(splitTime)
        end
    end

    return snapshot
end

local function BuildSnapshotForRoute(instanceName, routeKey, entries)
    local node = routeKey and NS.Database.GetRouteNode(instanceName, routeKey, false) or nil
    return BuildSnapshotFromNode(node, entries)
end

local function RefreshRunDisplay()
    RebuildEntryMappings()
    NS.Run.presentation = NS.RunLogic.BuildRunPresentation(NS.Run, NS.Run.pbSegmentsSnapshot or {})
    if NS.UI and NS.UI.RefreshBossTableData then
        NS.UI.RefreshBossTableData(NS.Run.entries or {}, NS.Run.presentation)
    end
    if NS.UI and NS.UI.SetKillCount then
        NS.UI.SetKillCount(NS.Run.killedCount or 0, #NS.Run.entries)
    end
    if NS.UI and NS.UI.RefreshTotals then
        NS.UI.RefreshTotals(false)
    end
end

local function ApplyRouteDisplay(routeKey)
    if not routeKey or routeKey == "" then
        return
    end

    NS.Run.entries = ReorderEntriesByRouteKey(NS.Run.entries or {}, routeKey)
    NS.Run.activeRouteKey = routeKey
    NS.Run.routeExploring = false
    NS.Run.pbSegmentsSnapshot = BuildSnapshotForRoute(NS.Run.instanceName, routeKey, NS.Run.entries)
    RefreshRunDisplay()
end

local function BuildExploringEntries()
    local ordered = {}
    local used = {}

    for _, bossKey in ipairs(NS.Run.killOrder or {}) do
        for _, entry in ipairs(NS.Run.entries or {}) do
            if entry.key == bossKey and not NS.IsBossIgnored(entry.name) and not used[entry.key] then
                used[entry.key] = true
                ordered[#ordered + 1] = entry
                break
            end
        end
    end

    for _, entry in ipairs(NS.Run.entries or {}) do
        if not used[entry.key] and not NS.IsBossIgnored(entry.name) then
            used[entry.key] = true
            ordered[#ordered + 1] = entry
        end
    end

    for _, entry in ipairs(NS.Run.entries or {}) do
        if not used[entry.key] then
            used[entry.key] = true
            ordered[#ordered + 1] = entry
        end
    end

    return ordered
end

local function PrefixMatchesRoute(routeKey, prefix)
    local route = ParseRouteKey(routeKey)
    if #prefix > #route then
        return false
    end
    for i = 1, #prefix do
        if route[i] ~= prefix[i] then
            return false
        end
    end
    return true
end

local function FindBestMatchingRoute(instanceName, prefix)
    local routes = NS.Database.GetInstanceRoutes(instanceName, false)
    if not routes then
        return nil, nil
    end

    local bestKey
    local bestNode
    local bestDuration

    for routeKey, node in pairs(routes) do
        if routeKey ~= "BossIndex" and type(node) == "table" and PrefixMatchesRoute(routeKey, prefix) then
            local duration = tonumber(node.FullRun and node.FullRun.duration)
            if duration and duration > 0 and (not bestDuration or duration < bestDuration) then
                bestDuration = duration
                bestKey = routeKey
                bestNode = node
            end
        end
    end

    return bestKey, bestNode
end

local function SelectInitialEntries(entries)
    local instanceName = NS.Run.instanceName
    local speedrunMode = NS.Run.speedrunMode
    local defaultRouteKey = NS.Database.EnsureDefaultRoute(instanceName, entries)

    NS.Run.defaultRouteKey = defaultRouteKey
    NS.Run.killOrder = {}
    NS.Run.killRouteIndices = {}
    NS.Run.routeExploring = false
    NS.Run.routeSaveBlocked = false
    NS.Run.activeRouteKey = nil
    NS.Run.routeMode = "route"
    NS.Run.routeModeReason = "route-default"
    NS.Run.hasIgnoredEntries = false

    if speedrunMode == "last" then
        local lastEntry = entries[#entries]
        local selected = lastEntry and { lastEntry } or {}
        NS.Run.routeMode = "last"
        NS.Run.routeModeReason = "last"
        NS.Run.lastBossIndex = lastEntry and lastEntry.routeIndex or nil
        NS.Run.pbSegmentsSnapshot = BuildSnapshotFromNode(
            NS.Database.GetBestLastBossNode(instanceName, true),
            selected
        )
        return selected
    end

    if HasManualIgnoredEntries(instanceName, entries) then
        NS.Run.routeMode = "ignored"
        NS.Run.routeModeReason = "ignored-live-match"
        NS.Run.routeSaveBlocked = true
        NS.Run.hasIgnoredEntries = true
        NS.Run.pbSegmentsSnapshot = BuildSnapshotFromNode(
            NS.Database.GetBestIgnoredNode(instanceName, true),
            entries
        )
        return entries
    end

    local bestRoute = NS.Database.GetBestRouteNode(instanceName, false)
    local routeKey = bestRoute and bestRoute.RouteKey or defaultRouteKey
    local ordered = routeKey ~= "" and ReorderEntriesByRouteKey(entries, routeKey) or entries

    NS.Run.activeRouteKey = routeKey ~= "" and routeKey or nil
    NS.Run.pbSegmentsSnapshot = BuildSnapshotForRoute(instanceName, routeKey, ordered)
    return ordered
end

local function HandleRouteProgression()
    if NS.Run.routeMode ~= "route" then
        return
    end

    local routeKey = BuildRouteKeyFromIndices(NS.Run.killRouteIndices or {})
    local matchedKey = nil
    if routeKey ~= "" then
        matchedKey = select(1, FindBestMatchingRoute(NS.Run.instanceName, NS.Run.killRouteIndices or {}))
    end

    if matchedKey then
        ApplyRouteDisplay(matchedKey)
        return
    end

    NS.Run.routeExploring = true
    NS.Run.entries = BuildExploringEntries()
    RefreshRunDisplay()
end

local function HandleIgnoreStateChange()
    if not NS.Run or not NS.Run.inInstance or NS.Run.speedrunMode == "last" then
        return
    end

    local hasIgnored = HasManualIgnoredEntries(NS.Run.instanceName, NS.Run.entries)
    if hasIgnored then
        NS.Run.routeMode = "ignored"
        NS.Run.routeModeReason = "ignored-live-match"
        NS.Run.activeRouteKey = nil
        NS.Run.routeExploring = false
        NS.Run.routeSaveBlocked = true
        NS.Run.hasIgnoredEntries = true
        NS.Run.pbSegmentsSnapshot = BuildSnapshotFromNode(
            NS.Database.GetBestIgnoredNode(NS.Run.instanceName, true),
            NS.Run.entries
        )
        RefreshRunDisplay()
        return
    end

    if (NS.Run.killedCount or 0) == 0 and NS.Run.routeMode == "ignored" then
        NS.Run.routeMode = "route"
        NS.Run.routeModeReason = "route-default"
        NS.Run.routeExploring = false
        NS.Run.routeSaveBlocked = false
        NS.Run.hasIgnoredEntries = false

        local bestRoute = NS.Database.GetBestRouteNode(NS.Run.instanceName, false)
        local routeKey = bestRoute and bestRoute.RouteKey or NS.Run.defaultRouteKey
        if routeKey and routeKey ~= "" then
            NS.Run.entries = ReorderEntriesByRouteKey(NS.Run.entries or {}, routeKey)
            NS.Run.activeRouteKey = routeKey
            NS.Run.pbSegmentsSnapshot = BuildSnapshotForRoute(NS.Run.instanceName, routeKey, NS.Run.entries)
        else
            NS.Run.pbSegmentsSnapshot = {}
        end
        RefreshRunDisplay()
    end
end

NS.RunLogic.ParseRouteKey = ParseRouteKey
NS.RunLogic.BuildRouteKeyFromIndices = BuildRouteKeyFromIndices
NS.RunLogic.BuildSnapshotFromNode = BuildSnapshotFromNode
NS.RunLogic.BuildSnapshotForRoute = BuildSnapshotForRoute
NS.RunLogic.NormalizeManualIgnoredBosses = NormalizeManualIgnoredBosses
NS.RunLogic.HasManualIgnoredEntries = HasManualIgnoredEntries
NS.RunLogic.SelectInitialEntries = SelectInitialEntries
NS.RunLogic.RefreshRunDisplay = RefreshRunDisplay
NS.RunLogic.HandleRouteProgression = HandleRouteProgression
NS.RunLogic.HandleIgnoreStateChange = HandleIgnoreStateChange
