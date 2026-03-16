local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "logic_resolve_boss_key_by_name",
    suite = "Logic",
    subcategory = "Boss Resolution",
    name = "Resolves a remaining boss key from a normalized name",
    func = function()
        local oldEntries = NS.Run.entries
        local oldRemaining = NS.Run.remaining

        System.WithCleanup(function()
            System.BeginSection("Seed a single remaining boss")
            NS.Run.entries = {
                { key = "N:testboss", name = "Test Boss" },
            }
            NS.Run.remaining = {
                ["N:testboss"] = true,
            }
            local key = NS.RunLogic.ResolveBossKey(nil, "Test Boss")
            System.AssertEqual(key, "N:testboss", "ResolveBossKey returns the normalized name key")
            System.EndSection("Seed a single remaining boss", "PASS")
        end, function()
            NS.Run.entries = oldEntries
            NS.Run.remaining = oldRemaining
        end)
    end,
})

System.RegisterTest({
    id = "logic_reset_run_clears_timing_state",
    suite = "Logic",
    subcategory = "State Reset",
    name = "Clears timing state during run reset",
    func = function()
        local backup = NS.Util.CopyTable(NS.Run)

        System.WithCleanup(function()
            System.BeginSection("Mutate active run state before reset")
            NS.Run.active = true
            NS.Run.startGameTime = 123
            NS.Run.kills = { a = 1 }
            NS.RunLogic.ResetRun()
            System.AssertTrue(NS.Run.active == false, "ResetRun clears the active flag", NS.Run.active)
            System.AssertEqual(NS.Run.startGameTime, 0, "ResetRun zeroes startGameTime")
            System.AssertTrue(next(NS.Run.kills) == nil, "ResetRun clears recorded kills", next(NS.Run.kills))
            System.EndSection("Mutate active run state before reset", "PASS")
        end, function()
            for key in pairs(NS.Run) do
                NS.Run[key] = nil
            end
            for key, value in pairs(backup) do
                NS.Run[key] = value
            end
        end)
    end,
})

System.RegisterTest({
    id = "logic_last_boss_mode_auto_ignore",
    suite = "Logic",
    subcategory = "Ignore Rules",
    name = "Auto-ignores non-final bosses in last boss mode",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Auto Ignore Test"
        local oldInstanceName = NS.Run.instanceName
        local oldSpeedrunMode = NS.Run.speedrunMode
        local oldEntries = NS.Run.entries
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Seed manual and automatic ignore state")
            NS.Run.instanceName = instanceName
            NS.Run.speedrunMode = "last"
            NS.Run.entries = {
                { key = "A", name = "Boss A" },
                { key = "B", name = "Boss B" },
                { key = "C", name = "Boss C" },
            }
            NS.DB.Settings.ignoredBosses[instanceName] = { ["Boss B"] = true }
            NS.DB.Settings.autoIgnoredBosses[instanceName] = {}

            NS.RunLogic.SyncAutoIgnoredBosses()

            System.AssertTrue(NS.DB.Settings.autoIgnoredBosses[instanceName]["Boss A"] == true,
                "The first non-final boss becomes auto-ignored",
                NS.DB.Settings.autoIgnoredBosses[instanceName]["Boss A"])
            System.AssertEqual(NS.DB.Settings.autoIgnoredBosses[instanceName]["Boss B"], nil,
                "Manually ignored bosses are not duplicated into auto-ignore state")
            System.AssertEqual(NS.DB.Settings.autoIgnoredBosses[instanceName]["Boss C"], nil,
                "The final boss is never auto-ignored")
            System.EndSection("Seed manual and automatic ignore state", "PASS")
        end, function()
            NS.Run.instanceName = oldInstanceName
            NS.Run.speedrunMode = oldSpeedrunMode
            NS.Run.entries = oldEntries
            NS.DB.Settings.ignoredBosses = oldIgnored
            NS.DB.Settings.autoIgnoredBosses = oldAutoIgnored
        end)
    end,
})

System.RegisterTest({
    id = "logic_all_bosses_mode_clears_auto_ignore",
    suite = "Logic",
    subcategory = "Ignore Rules",
    name = "Clears auto-ignored bosses when returning to all bosses mode",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Auto Ignore Clear Test"
        local oldInstanceName = NS.Run.instanceName
        local oldSpeedrunMode = NS.Run.speedrunMode
        local oldEntries = NS.Run.entries
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Clear automatic ignore state while preserving manual ignores")
            NS.Run.instanceName = instanceName
            NS.Run.speedrunMode = "all"
            NS.Run.entries = {
                { key = "A", name = "Boss A" },
                { key = "B", name = "Boss B" },
            }
            NS.DB.Settings.ignoredBosses[instanceName] = { ["Boss B"] = true }
            NS.DB.Settings.autoIgnoredBosses[instanceName] = { ["Boss A"] = true }

            NS.RunLogic.SyncAutoIgnoredBosses()

            System.AssertTrue(next(NS.DB.Settings.autoIgnoredBosses[instanceName]) == nil,
                "All-bosses mode empties automatic ignore state",
                next(NS.DB.Settings.autoIgnoredBosses[instanceName]))
            System.AssertTrue(NS.DB.Settings.ignoredBosses[instanceName]["Boss B"] == true,
                "Manual ignores remain intact after clearing auto-ignore state",
                NS.DB.Settings.ignoredBosses[instanceName]["Boss B"])
            System.EndSection("Clear automatic ignore state while preserving manual ignores", "PASS")
        end, function()
            NS.Run.instanceName = oldInstanceName
            NS.Run.speedrunMode = oldSpeedrunMode
            NS.Run.entries = oldEntries
            NS.DB.Settings.ignoredBosses = oldIgnored
            NS.DB.Settings.autoIgnoredBosses = oldAutoIgnored
        end)
    end,
})

System.RegisterTest({
    id = "logic_reset_layout_restores_saved_default",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "Restores the saved default layout when ResetLayout is used",
    func = function()
        NS.Database.EnsureDB()

        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})
        local oldDefaultLayout = NS.DB.DefaultLayout and NS.Util.CopyTable(NS.DB.DefaultLayout) or nil
        local oldReloadUI = ReloadUI
        local oldRefreshAllUI = NS.RefreshAllUI
        local reloaded = false

        System.WithCleanup(function()
            System.BeginSection("Reset from a modified layout back to the saved default")
            NS.DB.ui = {
                cols = { pb = 111, split = 112, delta = 113 },
                frames = { boss = { x = 99, y = 98 } },
            }
            NS.DB.DefaultLayout = {
                ui = {
                    cols = { pb = 85, split = 90, delta = 95 },
                    frames = { boss = { x = 12, y = 34 } },
                },
            }

            ReloadUI = function()
                reloaded = true
            end
            NS.RefreshAllUI = function() end

            NS.ResetLayout()

            System.AssertEqual(NS.DB.ui.cols.pb, 85, "ResetLayout restores saved PB column width")
            System.AssertEqual(NS.DB.ui.frames.boss.x, 12, "ResetLayout restores saved boss-frame position")
            System.AssertTrue(reloaded == true, "ResetLayout still triggers a UI reload", reloaded)
            System.EndSection("Reset from a modified layout back to the saved default", "PASS")
        end, function()
            NS.DB.ui = oldUI
            NS.DB.DefaultLayout = oldDefaultLayout
            ReloadUI = oldReloadUI
            NS.RefreshAllUI = oldRefreshAllUI
        end)
    end,
})

System.RegisterTest({
    id = "logic_save_default_layout_captures_live_layout",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "Saves the current live layout into DefaultLayout",
    func = function()
        NS.Database.EnsureDB()

        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})
        local oldDefaultLayout = NS.DB.DefaultLayout and NS.Util.CopyTable(NS.DB.DefaultLayout) or nil
        local oldCapture = NS.UI.CaptureCurrentLayout

        System.WithCleanup(function()
            System.BeginSection("Save a live layout snapshot")
            NS.DB.ui = {
                cols = { pb = 80, split = 81, delta = 82 },
                frames = { boss = { x = 1, y = 2 } },
            }
            NS.UI.CaptureCurrentLayout = function()
                NS.DB.ui.cols.pb = 120
                NS.DB.ui.cols.split = 121
                NS.DB.ui.frames.boss.x = 55
            end

            NS.SaveDefaultLayout()

            System.AssertEqual(NS.DB.DefaultLayout.ui.cols.pb, 120, "SaveDefaultLayout captures the live PB width")
            System.AssertEqual(NS.DB.DefaultLayout.ui.frames.boss.x, 55, "SaveDefaultLayout captures the live boss position")
            System.EndSection("Save a live layout snapshot", "PASS")
        end, function()
            NS.DB.ui = oldUI
            NS.DB.DefaultLayout = oldDefaultLayout
            NS.UI.CaptureCurrentLayout = oldCapture
        end)
    end,
})

System.RegisterTest({
    id = "logic_wipe_database_simulation",
    suite = "Logic",
    subcategory = "Database",
    name = "Simulates wiping records without reloading UI",
    func = function()
        NS.Database.EnsureDB()

        local oldHistory = NS.Util.CopyTable(NS.DB.RunHistory or {})
        local oldPBs = NS.Util.CopyTable(NS.DB.InstancePersonalBests or {})
        local oldReloadUI = ReloadUI
        local reloaded = false

        System.WithCleanup(function()
            System.BeginSection("Simulate wiping records")
            NS.DB.RunHistory = { { instanceName = "Test" } }
            NS.DB.InstancePersonalBests = { Test = { Segments = { Boss = 10 } } }
            ReloadUI = function()
                reloaded = true
            end

            NS.WipeDatabase(true)

            System.AssertEqual(#NS.DB.RunHistory, 0, "Simulated wipe clears run history")
            System.AssertEqual(next(NS.DB.InstancePersonalBests), nil, "Simulated wipe clears personal bests")
            System.AssertTrue(reloaded == false, "Simulated wipe does not reload the UI", reloaded)
            System.EndSection("Simulate wiping records", "PASS")
        end, function()
            NS.DB.RunHistory = oldHistory
            NS.DB.InstancePersonalBests = oldPBs
            ReloadUI = oldReloadUI
        end)
    end,
})

System.RegisterTest({
    id = "logic_factory_reset_simulation",
    suite = "Logic",
    subcategory = "Database",
    name = "Simulates a factory reset without reloading UI",
    func = function()
        NS.Database.EnsureDB()

        local oldSettings = NS.Util.CopyTable(NS.DB.Settings or {})
        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})
        local oldDefaultLayout = NS.DB.DefaultLayout and NS.Util.CopyTable(NS.DB.DefaultLayout) or nil
        local oldReloadUI = ReloadUI
        local reloaded = false

        System.WithCleanup(function()
            System.BeginSection("Simulate resetting to factory defaults")
            NS.DB.Settings.speedrunMode = "last"
            NS.DB.ui.cols.pb = 123
            ReloadUI = function()
                reloaded = true
            end

            NS.ResetToFactorySettings(true)

            System.AssertEqual(NS.DB.Settings.speedrunMode, NS.FactoryDefaults.Settings.speedrunMode,
                "Simulated factory reset restores factory settings")
            System.AssertEqual(NS.DB.ui.cols.pb, NS.FactoryDefaults.ui.cols.pb,
                "Simulated factory reset restores factory layout")
            System.AssertEqual(NS.DB.DefaultLayout.ui.cols.pb, NS.FactoryDefaults.ui.cols.pb,
                "Simulated factory reset refreshes the default layout snapshot")
            System.AssertTrue(reloaded == false, "Simulated factory reset does not reload the UI", reloaded)
            System.EndSection("Simulate resetting to factory defaults", "PASS")
        end, function()
            NS.DB.Settings = oldSettings
            NS.DB.ui = oldUI
            NS.DB.DefaultLayout = oldDefaultLayout
            ReloadUI = oldReloadUI
        end)
    end,
})

System.RegisterTest({
    id = "logic_equal_pace_delta_is_zero",
    suite = "Logic",
    subcategory = "Pace Calculation",
    name = "Keeps the run delta at zero when every split matches PB",
    func = function()
        NS.Database.EnsureDB()

        local oldNow = NS.NowGameTime
        local oldSetRowKilled = NS.UI.SetRowKilled
        local oldSetKillCount = NS.UI.SetKillCount
        local oldRefreshTotals = NS.UI.RefreshTotals
        local oldShowToast = NS.ShowToast
        local oldState = {
            instanceName = NS.Run.instanceName,
            speedrunMode = NS.Run.speedrunMode,
            active = NS.Run.active,
            startGameTime = NS.Run.startGameTime,
            entries = NS.Run.entries,
            remaining = NS.Run.remaining,
            remainingCount = NS.Run.remainingCount,
            killedCount = NS.Run.killedCount,
            kills = NS.Run.kills,
            showTimerToast = NS.DB.Settings.showTimerToast,
        }

        System.WithCleanup(function()
            System.BeginSection("Seed a two-boss equal-pace run")
            NS.UI.SetRowKilled = function() end
            NS.UI.SetKillCount = function() end
            NS.UI.RefreshTotals = function() end
            NS.ShowToast = function() end
            NS.DB.Settings.showTimerToast = false

            NS.Run.instanceName = "Equal Pace Test"
            NS.Run.speedrunMode = "all"
            NS.Run.active = true
            NS.Run.startGameTime = 100
            NS.Run.entries = {
                { key = "A", name = "Boss A" },
                { key = "B", name = "Boss B" },
            }
            NS.Run.remaining = { A = true, B = true }
            NS.Run.remainingCount = 2
            NS.Run.killedCount = 0
            NS.Run.kills = {}

            local node = NS.GetBestSplitsSubtable("Equal Pace Test")
            node.Segments = { ["Boss A"] = 60, ["Boss B"] = 60 }
            node.FullRun = { duration = 120 }
            System.LogInfo("Seeded PBs for Boss A and Boss B at 60 seconds each.")
            System.EndSection("Seed a two-boss equal-pace run", "PASS")

            System.BeginSection("Record equal-pace kills")
            NS.NowGameTime = function()
                return 160
            end
            NS.RunLogic.RecordBossKill(nil, "Boss A")
            System.AssertNear(NS.Run.lastDelta or 0, 0, 0.001, "Boss A delta remains at zero")

            NS.NowGameTime = function()
                return 220
            end
            NS.RunLogic.RecordBossKill(nil, "Boss B")
            System.AssertNear(NS.Run.lastDelta or 0, 0, 0.001, "Boss B delta remains at zero")
            System.EndSection("Record equal-pace kills", "PASS")
        end, function()
            NS.NowGameTime = oldNow
            NS.UI.SetRowKilled = oldSetRowKilled
            NS.UI.SetKillCount = oldSetKillCount
            NS.UI.RefreshTotals = oldRefreshTotals
            NS.ShowToast = oldShowToast

            NS.Run.instanceName = oldState.instanceName
            NS.Run.speedrunMode = oldState.speedrunMode
            NS.Run.active = oldState.active
            NS.Run.startGameTime = oldState.startGameTime
            NS.Run.entries = oldState.entries
            NS.Run.remaining = oldState.remaining
            NS.Run.remainingCount = oldState.remainingCount
            NS.Run.killedCount = oldState.killedCount
            NS.Run.kills = oldState.kills
            NS.DB.Settings.showTimerToast = oldState.showTimerToast
        end)
    end,
})

System.RegisterTest({
    id = "logic_reset_run_no_longer_requires_ui",
    suite = "Logic",
    subcategory = "State Reset",
    name = "Keeps ResetRun state-only and UI-agnostic",
    func = function()
        local oldSetTimerText = NS.UI.SetTimerText
        local oldSetKillCount = NS.UI.SetKillCount
        local oldClearBossRows = NS.UI.ClearBossRows
        local oldSetTotals = NS.SetTotals
        local oldSetTimerDelta = NS.UI.SetTimerDelta
        local called = false

        System.WithCleanup(function()
            System.BeginSection("Reset run state without touching presentation")
            NS.UI.SetTimerText = function() called = true end
            NS.UI.SetKillCount = function() called = true end
            NS.UI.ClearBossRows = function() called = true end
            NS.SetTotals = function() called = true end
            NS.UI.SetTimerDelta = function() called = true end

            NS.Run.active = true
            NS.Run.kills = { A = 1 }
            NS.RunLogic.ResetRun()

            System.AssertTrue(called == false, "ResetRun no longer performs UI side effects", called)
            System.EndSection("Reset run state without touching presentation", "PASS")
        end, function()
            NS.UI.SetTimerText = oldSetTimerText
            NS.UI.SetKillCount = oldSetKillCount
            NS.UI.ClearBossRows = oldClearBossRows
            NS.SetTotals = oldSetTotals
            NS.UI.SetTimerDelta = oldSetTimerDelta
        end)
    end,
})

System.RegisterTest({
    id = "logic_build_pb_progress_respects_ignored_bosses",
    suite = "Logic",
    subcategory = "Pace Calculation",
    name = "BuildPBProgress excludes ignored bosses from cumulative totals",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "PB Progress Ignore Test"
        local oldInstanceName = NS.Run.instanceName
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Calculate cumulative PB progress with one ignored boss")
            NS.Run.instanceName = instanceName
            NS.DB.Settings.ignoredBosses[instanceName] = { ["Boss B"] = true }
            NS.DB.Settings.autoIgnoredBosses[instanceName] = {}

            local progress = NS.RunLogic.BuildPBProgress({
                { key = "A", name = "Boss A" },
                { key = "B", name = "Boss B" },
                { key = "C", name = "Boss C" },
            }, {
                ["Boss A"] = 10,
                ["Boss B"] = 20,
                ["Boss C"] = 30,
            })

            System.AssertEqual(progress.cumulativeDisplayByKey.A, 10, "Boss A cumulative PB includes its own segment")
            System.AssertEqual(progress.cumulativeDisplayByKey.B, 10, "Ignored boss does not increase cumulative PB")
            System.AssertEqual(progress.cumulativeDisplayByKey.C, 40, "Later non-ignored bosses still accumulate")
            System.AssertEqual(progress.totalPB, 40, "Total PB excludes ignored segments")
            System.EndSection("Calculate cumulative PB progress with one ignored boss", "PASS")
        end, function()
            NS.Run.instanceName = oldInstanceName
            NS.DB.Settings.ignoredBosses = oldIgnored
            NS.DB.Settings.autoIgnoredBosses = oldAutoIgnored
        end)
    end,
})

System.RegisterTest({
    id = "logic_completion_helper_supports_last_boss_mode",
    suite = "Logic",
    subcategory = "Pace Calculation",
    name = "GetRunCompletionState completes only on the final kill in last boss mode",
    func = function()
        local oldRun = NS.Util.CopyTable(NS.Run)

        System.WithCleanup(function()
            System.BeginSection("Evaluate last-boss mode completion")
            NS.Run.speedrunMode = "last"
            NS.Run.startGameTime = 100
            NS.Run.entries = {
                { key = "A", name = "Boss A" },
                { key = "B", name = "Boss B" },
            }
            NS.Run.kills = { A = 15 }

            local completeA = NS.RunLogic.GetRunCompletionState(NS.Run)
            System.AssertTrue(completeA == false, "Killing a non-final boss does not complete a last-boss run", completeA)

            NS.Run.kills.B = 40
            local completeB, endTime = NS.RunLogic.GetRunCompletionState(NS.Run)
            System.AssertTrue(completeB == true, "The final boss completes a last-boss run", completeB)
            System.AssertEqual(endTime, 140, "Completion time uses the last boss cumulative split")
            System.EndSection("Evaluate last-boss mode completion", "PASS")
        end, function()
            for key in pairs(NS.Run) do
                NS.Run[key] = nil
            end
            for key, value in pairs(oldRun) do
                NS.Run[key] = value
            end
        end)
    end,
})
