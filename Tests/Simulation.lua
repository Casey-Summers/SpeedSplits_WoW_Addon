local _, NS = ...

local System = NS.TestSystem
local Util = NS.Util

local TEST_ID = "logic_live_path_speedrun_simulation"
local TEST_NAME = "Live-path speedrun simulation"
local DEFAULT_PBSplitsRoutes = {
    {
        routeKey = "1,2,3,4,5,6",
        duration = 120.010,
        PBSplitsRoutes = {
            [1] = 22.100,
            [2] = 48.010,
            [3] = 66.500,
            [4] = 82.100,
            [5] = 96.000,
            [6] = 120.010,
        },
    },
    {
        routeKey = "2,3,1,4,5,6",
        duration = 116.500,
        PBSplitsRoutes = {
            [1] = 58.500,
            [2] = 18.000,
            [3] = 36.000,
            [4] = 74.000,
            [5] = 93.000,
            [6] = 116.500,
        },
    },
}

local DEFAULT_PBSplitsIgnored = {
    duration = 119.250,
    PBSplitsIgnored = {
        [1] = 22.200,
        [2] = 48.010,
        [3] = 65.100,
        [4] = 81.900,
        [5] = 95.000,
        [6] = 119.250,
    },
}

local DEFAULT_PBSplitsLastBoss = {
    duration = 120.010,
    PBSplitsLastBoss = {
        [6] = 120.010,
    },
}

local DEFAULT_splitsByKey = {
    ["E:1001"] = 22.524,
    ["E:1002"] = 43.666,
    ["E:1003"] = 70.666,
    ["E:1004"] = 102.816,
    ["E:1005"] = 148.815,
    ["E:1006"] = 179.816,
}

NS.TestsSimulation = NS.TestsSimulation or {}

local Simulation = NS.TestsSimulation

Simulation.active = Simulation.active == true
Simulation.interactive = Simulation.interactive == true
Simulation.ActiveScenario = Simulation.ActiveScenario or nil
Simulation._sandbox = Simulation._sandbox or nil

Simulation.scenario = Simulation.scenario or {
    instance = {
        name = "Mock Speedrun Dungeon",
        mapID = 999,
        difficultyID = 1,
        difficultyName = "Simulation",
        instanceType = "party",
        tier = 11,
        journalInstanceID = 0,
    },
    mode = {
        speedrunMode = "all", -- "all" or "last"
        completeRun = true,
        leaveInteractive = true,
    },
    database = {
        routes = Util.CopyTable(DEFAULT_PBSplitsRoutes),
        bestRouteKey = nil,
        ignoredPBs = Util.CopyTable(DEFAULT_PBSplitsIgnored),
        lastBossPBs = Util.CopyTable(DEFAULT_PBSplitsLastBoss),
    },
    bosses = {
        { name = "Opening Pull",   key = "E:1001", encounterID = 1001, routeIndex = 1 },
        { name = "Bridge Keeper",  key = "E:1002", encounterID = 1002, routeIndex = 2 },
        { name = "Side Event",     key = "E:1003", encounterID = 1003, routeIndex = 3, ignored = true },
        { name = "Forge Master",   key = "E:1004", encounterID = 1004, routeIndex = 4 },
        { name = "Shadow Council", key = "E:1005", encounterID = 1005, routeIndex = 5 },
        { name = "Final Tyrant",   key = "E:1006", encounterID = 1006, routeIndex = 6 },
    },
    run = {
        killSequence = { "E:1001", "E:1002", "E:1003", "E:1004", "E:1005", "E:1006" },
        splitsByKey = Util.CopyTable(DEFAULT_splitsByKey),
    },
    flags = {
        enableManualIgnores = false,
        exploratoryRoute = false,
        unmatchedExploration = false,
    },
}

local function CopyRunTable()
    return Util.CopyTable(NS.Run or {})
end

local function RestoreRunTable(snapshot)
    snapshot = snapshot or {}
    for key in pairs(NS.Run or {}) do
        NS.Run[key] = nil
    end
    for key, value in pairs(snapshot) do
        NS.Run[key] = value
    end
end

local function DeepMerge(base, overrides)
    local merged = Util.CopyTable(base or {})
    for key, value in pairs(overrides or {}) do
        if type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = DeepMerge(merged[key], value)
        elseif type(value) == "table" then
            merged[key] = Util.CopyTable(value)
        else
            merged[key] = value
        end
    end
    return merged
end

local function GetScenario()
    return Util.CopyTable(Simulation.scenario or {})
end

local function GetBossByKey(scenario, bossKey)
    for _, boss in ipairs(scenario.bosses or {}) do
        if boss.key == bossKey then
            return boss
        end
    end
    return nil
end

local function GetBossByRouteIndex(scenario, routeIndex)
    for _, boss in ipairs(scenario.bosses or {}) do
        if tonumber(boss.routeIndex) == tonumber(routeIndex) then
            return boss
        end
    end
    return nil
end

local function GetLastBoss(scenario)
    local lastBoss
    for _, boss in ipairs(scenario.bosses or {}) do
        if not lastBoss or (tonumber(boss.routeIndex) or 0) > (tonumber(lastBoss.routeIndex) or 0) then
            lastBoss = boss
        end
    end
    return lastBoss
end

local function BuildEntriesFromScenario(scenario)
    local entries = {}
    for _, boss in ipairs(scenario.bosses or {}) do
        entries[#entries + 1] = {
            name = boss.name,
            bossName = boss.name,
            key = boss.key,
            rowIndex = tonumber(boss.routeIndex) or #entries + 1,
            encounterID = boss.encounterID,
            dungeonEncounterID = boss.encounterID,
            journalEncounterID = boss.journalEncounterID,
            routeIndex = boss.routeIndex,
        }
    end
    table.sort(entries, function(a, b)
        return (tonumber(a.routeIndex) or 0) < (tonumber(b.routeIndex) or 0)
    end)
    return entries
end

local function BuildBossPayload(scenario, includeOnlyLastBoss)
    local bosses = {}
    for _, boss in ipairs(scenario.bosses or {}) do
        if not includeOnlyLastBoss or boss == GetLastBoss(scenario) then
            bosses[#bosses + 1] = {
                key = boss.key,
                name = boss.name,
                encounterID = boss.encounterID,
                dungeonEncounterID = boss.encounterID,
                journalEncounterID = boss.journalEncounterID,
                routeIndex = tonumber(boss.routeIndex),
            }
        end
    end
    return bosses
end

local function BuildKillsFromSplits(scenario, splitsByIndex, includeOnlyLastBoss)
    local kills = {}
    for routeIndex, splitTime in pairs(splitsByIndex or {}) do
        local boss = GetBossByRouteIndex(scenario, routeIndex)
        if boss and (not includeOnlyLastBoss or boss == GetLastBoss(scenario)) then
            kills[boss.key] = Util.RoundTime(splitTime)
        end
    end
    return kills
end

local function BuildSeedRecordFromRoute(pbMode, seed, scenario)
    local includeOnlyLastBoss = pbMode == "last"
    local lastBoss = GetLastBoss(scenario)
    local PBSplits

    if pbMode == "route" then
        PBSplits = seed and seed.PBSplitsRoutes or {}
    elseif pbMode == "ignored" then
        PBSplits = seed and seed.PBSplitsIgnored or {}
    else
        PBSplits = seed and seed.PBSplitsLastBoss or {}
    end

    return {
        success = true,
        instanceName = scenario.instance.name,
        instanceType = scenario.instance.instanceType,
        difficultyID = scenario.instance.difficultyID,
        difficultyName = scenario.instance.difficultyName,
        mapID = scenario.instance.mapID,
        dungeonKey = Util.GetDungeonKey(scenario.instance.mapID, scenario.instance.difficultyID),
        tier = scenario.instance.tier,
        bossSource = "simulation",
        startedAt = 0,
        endedAt = 0,
        duration = Util.RoundTime(seed and seed.duration or
            (lastBoss and seed and seed.splits and seed.splits[lastBoss.routeIndex]) or 0),
        speedrunMode = pbMode == "last" and "last" or "all",
        pbMode = pbMode,
        routeKey = pbMode == "route" and seed.routeKey or nil,
        lastBossIndex = lastBoss and tonumber(lastBoss.routeIndex) or nil,
        hasIgnoredEntries = pbMode == "ignored",
        bosses = BuildBossPayload(scenario, includeOnlyLastBoss),
        kills = BuildKillsFromSplits(scenario, PBSplits, includeOnlyLastBoss),
        isTest = true,
    }
end

local function ApplyBestRouteOverride(scenario)
    local routeKey = scenario.database and scenario.database.bestRouteKey
    if not routeKey or routeKey == "" then
        return
    end

    local node = NS.Database.GetRouteNode(scenario.instance.name, routeKey, false)
    if not node then
        return
    end

    local promoted = Util.CopyTable(node)
    promoted.RouteKey = routeKey
    NS.DB.InstanceBestRoute[scenario.instance.name] = promoted
end

local function ApplyManualIgnoreSettings(scenario)
    local instanceName = scenario.instance.name
    NS.DB.Settings.ignoredBosses = NS.DB.Settings.ignoredBosses or {}
    NS.DB.Settings.autoIgnoredBosses = NS.DB.Settings.autoIgnoredBosses or {}
    NS.DB.Settings.ignoredBosses[instanceName] = {}
    NS.DB.Settings.autoIgnoredBosses[instanceName] = {}

    if not (scenario.flags and scenario.flags.enableManualIgnores) then
        return
    end

    for _, boss in ipairs(scenario.bosses or {}) do
        if boss.ignored == true then
            NS.DB.Settings.ignoredBosses[instanceName][boss.name] = true
        end
    end
end

local function SeedScenarioDatabase(scenario)
    local instanceName = scenario.instance.name

    NS.DB.InstanceRoutes[instanceName] = nil
    NS.DB.InstanceBestRoute[instanceName] = nil
    NS.DB.InstanceBestLastBoss[instanceName] = nil
    NS.DB.InstanceBestIgnored[instanceName] = nil

    for _, routeSeed in ipairs((scenario.database and scenario.database.routes) or {}) do
        NS.Database.ApplyRouteRecord(BuildSeedRecordFromRoute("route", routeSeed, scenario))
    end

    if scenario.database and scenario.database.ignoredPBs then
        NS.Database.ApplyIgnoredRecord(BuildSeedRecordFromRoute("ignored", scenario.database.ignoredPBs, scenario))
    end

    if scenario.database and scenario.database.lastBossPBs then
        NS.Database.ApplyLastBossRecord(BuildSeedRecordFromRoute("last", scenario.database.lastBossPBs, scenario))
    end

    ApplyBestRouteOverride(scenario)
    ApplyManualIgnoreSettings(scenario)

    System.LogInfo(("Seeded simulation DB for %s"):format(instanceName))
end

local function BuildInstanceContext(scenario)
    return {
        mapID = scenario.instance.mapID,
        uiMapID = scenario.instance.mapID,
        journalInstanceID = scenario.instance.journalInstanceID,
        name = scenario.instance.name,
        difficultyID = scenario.instance.difficultyID,
        instanceType = scenario.instance.instanceType,
        tier = scenario.instance.tier,
    }
end

local function ApplySimulationMetadata(scenario)
    NS.Run.inInstance = true
    NS.Run.instanceName = scenario.instance.name
    NS.Run.instanceType = scenario.instance.instanceType
    NS.Run.difficultyID = scenario.instance.difficultyID
    NS.Run.difficultyName = scenario.instance.difficultyName
    NS.Run.mapID = scenario.instance.mapID
    NS.Run.journalID = scenario.instance.journalInstanceID
    NS.Run.tier = scenario.instance.tier
    NS.Run.dungeonKey = Util.GetDungeonKey(scenario.instance.mapID, scenario.instance.difficultyID)
    NS.Run.speedrunMode = scenario.mode.speedrunMode
    NS.Run.isTest = true
    NS.Run.waitingForMove = false
    NS.Run._bossLoadTries = 0
    NS.Run._bossLoaded = false
end

local function CreateSandboxSnapshot()
    local scenario = Simulation.ActiveScenario or Simulation.scenario or {}
    local instanceName = scenario.instance and scenario.instance.name or nil

    return {
        run = CopyRunTable(),
        nowGameTime = NS.NowGameTime,
        nowEpoch = NS.NowEpoch,
        instanceName = instanceName,
        runHistory = Util.CopyTable(NS.DB.RunHistory or {}),
        instanceRoutes = instanceName and Util.CopyTable(NS.DB.InstanceRoutes[instanceName] or {}) or nil,
        instanceBestRoute = instanceName and Util.CopyTable(NS.DB.InstanceBestRoute[instanceName] or {}) or nil,
        instanceBestLastBoss = instanceName and Util.CopyTable(NS.DB.InstanceBestLastBoss[instanceName] or {}) or nil,
        instanceBestIgnored = instanceName and Util.CopyTable(NS.DB.InstanceBestIgnored[instanceName] or {}) or nil,
        ignoredBosses = instanceName and Util.CopyTable((NS.DB.Settings.ignoredBosses or {})[instanceName] or {}) or nil,
        autoIgnoredBosses = instanceName and Util.CopyTable((NS.DB.Settings.autoIgnoredBosses or {})[instanceName] or {}) or
            nil,
    }
end

local function RestoreSandboxSnapshot(snapshot)
    if not snapshot then
        return
    end

    NS.NowGameTime = snapshot.nowGameTime or NS.NowGameTime
    NS.NowEpoch = snapshot.nowEpoch or NS.NowEpoch

    local instanceName = snapshot.instanceName
    if instanceName and instanceName ~= "" then
        NS.DB.InstanceRoutes = NS.DB.InstanceRoutes or {}
        NS.DB.InstanceBestRoute = NS.DB.InstanceBestRoute or {}
        NS.DB.InstanceBestLastBoss = NS.DB.InstanceBestLastBoss or {}
        NS.DB.InstanceBestIgnored = NS.DB.InstanceBestIgnored or {}
        NS.DB.Settings.ignoredBosses = NS.DB.Settings.ignoredBosses or {}
        NS.DB.Settings.autoIgnoredBosses = NS.DB.Settings.autoIgnoredBosses or {}

        NS.DB.InstanceRoutes[instanceName] = next(snapshot.instanceRoutes or {}) and
            Util.CopyTable(snapshot.instanceRoutes) or nil
        NS.DB.InstanceBestRoute[instanceName] = next(snapshot.instanceBestRoute or {}) and
            Util.CopyTable(snapshot.instanceBestRoute) or nil
        NS.DB.InstanceBestLastBoss[instanceName] = next(snapshot.instanceBestLastBoss or {}) and
            Util.CopyTable(snapshot.instanceBestLastBoss) or nil
        NS.DB.InstanceBestIgnored[instanceName] = next(snapshot.instanceBestIgnored or {}) and
            Util.CopyTable(snapshot.instanceBestIgnored) or nil
        NS.DB.Settings.ignoredBosses[instanceName] = next(snapshot.ignoredBosses or {}) and
            Util.CopyTable(snapshot.ignoredBosses) or nil
        NS.DB.Settings.autoIgnoredBosses[instanceName] = next(snapshot.autoIgnoredBosses or {}) and
            Util.CopyTable(snapshot.autoIgnoredBosses) or nil
    end

    RestoreRunTable(snapshot.run)
end

local function PreviewRowReward(rowData)
    if not rowData or not rowData.key then
        return false
    end

    local rowState = NS.RunLogic.PreviewRewardForBossKey(NS.Run, NS.Run.pbSegmentsSnapshot or {}, rowData.key)
    return rowState ~= nil
end

local function LogScenarioSummary(scenario)
    local routeCount = #((scenario.database and scenario.database.routes) or {})
    local killCount = #((scenario.run and scenario.run.killSequence) or {})
    System.LogInfo(("Scenario: mode=%s routes=%d kills=%d interactive=%s"):format(
        tostring(scenario.mode.speedrunMode),
        routeCount,
        killCount,
        scenario.mode.leaveInteractive and "true" or "false"
    ))
end

local function DriveScenarioRun(scenario)
    local entries = BuildEntriesFromScenario(scenario)
    local baseGameTime = 1000
    local syntheticGameTime = baseGameTime
    local syntheticEpoch = 1700000000

    NS.NowGameTime = function()
        return syntheticGameTime
    end
    NS.NowEpoch = function()
        return syntheticEpoch
    end

    ApplySimulationMetadata(scenario)
    NS.RunLogic.ApplyBossEntries(entries, "simulation", BuildInstanceContext(scenario))
    NS.RunLogic.StartRunTimer()

    System.LogInfo(("Started simulation for %s using source=%s"):format(
        tostring(NS.Run.instanceName),
        tostring(NS.Run.bossSource)
    ))

    for _, bossKey in ipairs(scenario.run.killSequence or {}) do
        local boss = GetBossByKey(scenario, bossKey)
        local splitTime = scenario.run.splitsByKey and scenario.run.splitsByKey[bossKey] or nil
        if boss and type(splitTime) == "number" then
            syntheticGameTime = baseGameTime + Util.RoundTime(splitTime)
            syntheticEpoch = syntheticEpoch + math.max(1, math.floor(splitTime))
            System.LogInfo(("Kill %s at %s"):format(boss.name, Util.FormatTime(splitTime)))
            NS.RunLogic.RecordBossKill(boss.encounterID, boss.name)
        end
    end

    if scenario.mode.completeRun ~= true and NS.Run.active then
        syntheticEpoch = syntheticEpoch + 1
        NS.RunLogic.StopRun(false, syntheticGameTime)
        System.LogInfo("Stopped simulation early as an incomplete run")
    end

    local modeReason = NS.Run.routeModeReason or NS.Run.routeMode or "unknown"
    System.LogInfo(("Completed simulation drive: active=%s routeMode=%s reason=%s routeKey=%s"):format(
        NS.Run.active and "true" or "false",
        tostring(NS.Run.routeMode),
        tostring(modeReason),
        tostring(NS.Run.activeRouteKey)
    ))
end

function Simulation.GetDefaultScenario()
    return GetScenario()
end

function Simulation.HandleRowClick(rowData, button)
    if button ~= "LeftButton" or not Simulation.active or not Simulation.interactive then
        return false
    end
    return PreviewRowReward(rowData)
end

function Simulation.Stop(reason)
    if not Simulation._sandbox then
        return false
    end

    if reason then
        System.LogInfo(reason)
    end

    RestoreSandboxSnapshot(Simulation._sandbox)
    Simulation._sandbox = nil
    Simulation.active = false
    Simulation.interactive = false
    Simulation.ActiveScenario = nil

    if NS.RefreshAllUI then
        NS.RefreshAllUI()
    elseif NS.UI and NS.UI.ResetRunPresentation then
        NS.UI.ResetRunPresentation()
    end

    return true
end

function Simulation.RunScenario(overrides)
    if Simulation.active then
        Simulation.Stop("Replacing previous active simulation.")
    end

    NS.Database.EnsureDB()
    if NS.UI and NS.UI.EnsureUI then
        NS.UI.EnsureUI()
    end

    local scenario = DeepMerge(GetScenario(), overrides or {})
    local ok, err = xpcall(function()
        if NS.Run.active and NS.Run.isTest ~= true then
            error("Refusing to start a simulation during a live run.", 0)
        end

        Simulation.ActiveScenario = Util.CopyTable(scenario)
        Simulation._sandbox = CreateSandboxSnapshot()
        Simulation.active = true
        Simulation.interactive = scenario.mode.leaveInteractive == true

        SeedScenarioDatabase(scenario)
        LogScenarioSummary(scenario)
        DriveScenarioRun(scenario)
        if scenario.mode.leaveInteractive ~= true then
            Simulation.Stop("Stopping non-interactive simulation.")
        end
    end, function(message)
        return tostring(message)
    end)

    if not ok then
        Simulation.Stop("Cleaning up failed simulation state.")
        error(err, 0)
    end

    return true
end

function NS.SimulateSpeedrun()
    return System.RunTestById(TEST_ID)
end

NS.StopSimulatedSpeedrun = Simulation.Stop

System.RegisterTest({
    id = TEST_ID,
    suite = "Logic",
    subcategory = "Simulation",
    name = TEST_NAME,
    func = function()
        System.BeginSection("Launch the default route-aware simulation scenario")
        Simulation.RunScenario()

        System.AssertTrue(NS.DB.InstanceRoutes[Simulation.ActiveScenario.instance.name] ~= nil,
            "Simulation seeds route data in the sandbox")
        System.AssertTrue(NS.DB.InstanceBestRoute[Simulation.ActiveScenario.instance.name] ~= nil,
            "Simulation seeds the best-route node in the sandbox")
        System.AssertTrue(NS.DB.InstanceBestLastBoss[Simulation.ActiveScenario.instance.name] ~= nil,
            "Simulation seeds the last-boss node in the sandbox")
        System.AssertTrue(NS.DB.InstanceBestIgnored[Simulation.ActiveScenario.instance.name] ~= nil,
            "Simulation seeds the ignored-mode node in the sandbox")
        System.AssertEqual(NS.Run.bossSource, "simulation", "Simulation uses the live ApplyBossEntries source")
        System.AssertTrue(NS.Run.startGameTime > 0, "Simulation starts the run through the live timer path",
            NS.Run.startGameTime)
        System.EndSection("Launch the default route-aware simulation scenario", "PASS")

        System.BeginSection("Populate the live Splits table with run results")
        local rows = NS.UI and NS.UI.data or {}
        System.AssertTrue(type(rows) == "table" and #rows > 0, "Simulation populates visible split rows", #rows)

        local firstRow = rows[1]
        local lastRow = rows[#rows]
        System.AssertTrue(firstRow ~= nil, "The first visible split row exists", firstRow ~= nil)
        System.AssertTrue(lastRow ~= nil, "The final visible split row exists", lastRow ~= nil)
        if firstRow then
            System.AssertTrue(firstRow.cols ~= nil and firstRow.cols[2] ~= nil,
                "Rows contain PB data for display", firstRow.cols ~= nil and firstRow.cols[2] ~= nil)
            System.AssertTrue(firstRow.cols[3] ~= nil, "Rows contain live split data for display", firstRow.cols and firstRow.cols[3] ~= nil)
            System.AssertTrue(firstRow.cols[4] ~= nil, "Rows contain diff data for display", firstRow.cols and firstRow.cols[4] ~= nil)
        end
        if lastRow then
            System.AssertTrue(lastRow.cols ~= nil and tostring(lastRow.cols[4] and lastRow.cols[4].value or "") ~= "",
                "Completed simulation rows expose a diff value", lastRow.cols and lastRow.cols[4] and lastRow.cols[4].value)
        end
        System.EndSection("Populate the live Splits table with run results", "PASS")

        System.BeginSection("Expose live presentation data for diff and color validation")
        local presentation = NS.Run.presentation
        System.AssertTrue(presentation ~= nil, "Simulation builds a live run presentation", presentation ~= nil)
        System.AssertTrue(presentation and presentation.summary ~= nil, "Simulation builds a live presentation summary",
            presentation and presentation.summary ~= nil)
        System.AssertTrue(presentation and presentation.summary and presentation.summary.splitTotal ~= nil,
            "Simulation computes a live split total", presentation and presentation.summary and presentation.summary.splitTotal)
        System.AssertTrue(presentation and presentation.summary and presentation.summary.pbTotal ~= nil,
            "Simulation computes a live PB total", presentation and presentation.summary and presentation.summary.pbTotal)
        System.AssertTrue(presentation and presentation.summary and presentation.summary.diffTotal ~= nil,
            "Simulation computes a live diff total", presentation and presentation.summary and presentation.summary.diffTotal)
        System.AssertTrue(presentation and presentation.summary and presentation.summary.diffColor ~= nil,
            "Simulation computes a live diff color state", presentation and presentation.summary and presentation.summary.diffColor ~= nil)
        System.EndSection("Expose live presentation data for diff and color validation", "PASS")

        System.BeginSection("Verify row preview hook stays live")
        local previewRow = NS.UI and NS.UI.data and NS.UI.data[1] or nil
        local handled = Simulation.HandleRowClick(previewRow, "LeftButton")
        System.AssertTrue(handled == true, "Left-click preview delegates to PreviewRewardForBossKey", handled)
        System.EndSection("Verify row preview hook stays live", "PASS")

        System.BeginSection("Leave the simulation active for manual inspection")
        System.AssertTrue(Simulation.active == true, "Simulation remains active after the test entry completes", Simulation.active)
        System.AssertTrue(Simulation.interactive == true, "Simulation remains interactive for row-click previews",
            Simulation.interactive)
        System.EndSection("Leave the simulation active for manual inspection", "PASS")
    end,
})
