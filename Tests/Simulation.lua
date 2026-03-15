local _, NS = ...

local System = NS.TestSystem

local function RunScenarioSpeedrunRegression()
    NS.Database.EnsureDB()
    System.LogInfo("Simulation scenario bootstrapped.")

    local run = NS.Run
    local oldNow = NS.NowGameTime
    local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
    local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)
    local backupRun = NS.Util.CopyTable(run)

    System.WithCleanup(function()
        System.BeginSection("Configure mock speedrun state")
        run.inInstance = true
        run.instanceName = "Mock Speedrun Dungeon"
        run.instanceType = "party"
        run.difficultyID = 1
        run.mapID = 999
        run.journalID = 0
        run.tier = 11
        run.dungeonKey = "999:1"
        run.active = true
        run.startGameTime = oldNow()
        run.startedAt = NS.NowEpoch()
        run.killedCount = 0
        run.kills = {}
        run.speedrunMode = "all"

        local bosses = {
            { name = "Opening Pull", key = "M:1", pb = 12.0, split = 10.0, ignored = false },
            { name = "Bridge Keeper", key = "M:2", pb = 25.0, split = 30.0, ignored = false },
            { name = "Side Event", key = "M:3", pb = 18.0, split = 20.0, ignored = true },
            { name = "Forge Master", key = "M:4", pb = 45.0, split = 40.0, ignored = false },
            { name = "Shadow Council", key = "M:5", pb = 75.0, split = 70.0, ignored = false },
            { name = "Final Tyrant", key = "M:6", pb = 120.0, split = 122.0, ignored = false },
        }

        local entries = {}
        local expectedDeltas = {}
        local elapsed = 0
        local pbComparison = 0

        for index, boss in ipairs(bosses) do
            entries[#entries + 1] = { name = boss.name, key = boss.key, order = index }
            elapsed = elapsed + boss.split
            if not boss.ignored then
                pbComparison = pbComparison + boss.pb
            end
            expectedDeltas[boss.name] = elapsed - pbComparison
        end

        NS.DB.Settings.ignoredBosses[run.instanceName] = {}
        NS.DB.Settings.autoIgnoredBosses[run.instanceName] = {}
        for _, boss in ipairs(bosses) do
            if boss.ignored then
                NS.DB.Settings.ignoredBosses[run.instanceName][boss.name] = true
            end
        end

        NS.ApplyBossEntries(entries, "simulation", run.tier, run.journalID)
        local node = NS.GetBestSplitsSubtable()
        node.Segments = node.Segments or {}
        node.FullRun = node.FullRun or {}

        for _, boss in ipairs(bosses) do
            node.Segments[boss.name] = boss.pb
            System.LogInfo(string.format("PB seeded: %s = %.3fs", boss.name, boss.pb))
        end

        System.EndSection("Configure mock speedrun state", "PASS")

        System.BeginSection("Execute per-boss split checks")
        local startTime = run.startGameTime
        elapsed = 0

        for _, boss in ipairs(bosses) do
            elapsed = elapsed + boss.split
            local fakeNow = startTime + elapsed
            NS.NowGameTime = function()
                return fakeNow
            end

            System.BeginSection("Kill " .. boss.name)
            System.LogInfo(string.format("Split time = %.3fs | ignored = %s | expected delta = %+.3fs",
                boss.split,
                tostring(boss.ignored),
                expectedDeltas[boss.name]))

            NS.RecordBossKill(nil, boss.name)

            local actualDelta = run.lastDelta or 0
            local expectedDelta = expectedDeltas[boss.name]
            System.AssertNear(actualDelta, expectedDelta, 0.001,
                "Run delta matches the calculated expectation after " .. boss.name)
            System.LogInfo(string.format("Actual delta recorded = %+.3fs", actualDelta))
            System.EndSection("Kill " .. boss.name, "PASS")
        end

        System.EndSection("Execute per-boss split checks", "PASS")
    end, function()
        NS.NowGameTime = oldNow
        NS.DB.Settings.ignoredBosses = oldIgnored
        NS.DB.Settings.autoIgnoredBosses = oldAutoIgnored

        for key in pairs(run) do
            run[key] = nil
        end
        for key, value in pairs(backupRun) do
            run[key] = value
        end
    end)
end

function NS.SimulateSpeedrun()
    RunScenarioSpeedrunRegression()
end

System.RegisterTest({
    id = "logic_scenario_speedrun_regression",
    suite = "Logic",
    subcategory = "Simulation",
    name = "Scenario speedrun regression",
    func = RunScenarioSpeedrunRegression,
})
