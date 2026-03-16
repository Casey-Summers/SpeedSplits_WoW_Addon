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
