local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "logic_resolve_boss_entry_by_dungeon_encounter_id",
    suite = "Logic",
    subcategory = "Boss Resolution",
    name = "Resolves a remaining boss entry from a dungeon encounter id",
    func = function()
        local oldEntries = NS.Run.entries
        local oldRemaining = NS.Run.remaining
        local oldBossMap = NS.Run.bossByDungeonEncounterID

        System.WithCleanup(function()
            System.BeginSection("Seed a single remaining boss")
            NS.Run.entries = {
                { key = "E:9001", name = "Test Boss", dungeonEncounterID = 9001 },
            }
            NS.Run.remaining = {
                ["E:9001"] = true,
            }
            NS.Run.bossByDungeonEncounterID = {
                [9001] = NS.Run.entries[1],
            }
            local entry = NS.RunLogic.ResolveBossEntry(9001)
            System.AssertEqual(entry, NS.Run.entries[1], "ResolveBossEntry returns the boss row mapped to the live encounter id")
            System.EndSection("Seed a single remaining boss", "PASS")
        end, function()
            NS.Run.entries = oldEntries
            NS.Run.remaining = oldRemaining
            NS.Run.bossByDungeonEncounterID = oldBossMap
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
    id = "logic_stale_manual_ignores_do_not_force_ignored_mode",
    suite = "Logic",
    subcategory = "Ignore Rules",
    name = "Stale manual ignores are pruned and do not switch a route run into ignored mode",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Stale Ignore Test"
        local oldInstanceName = NS.Run.instanceName
        local oldSpeedrunMode = NS.Run.speedrunMode
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Ignore only live entries when selecting initial route mode")
            NS.Run.instanceName = instanceName
            NS.Run.speedrunMode = "all"
            NS.DB.Settings.ignoredBosses[instanceName] = { ["Old Boss"] = true }
            NS.DB.Settings.autoIgnoredBosses[instanceName] = {}

            local selected = NS.RunLogic.SelectInitialEntries({
                { key = "A", name = "Boss A", routeIndex = 1 },
                { key = "B", name = "Boss B", routeIndex = 2 },
            })

            System.AssertEqual(NS.Run.routeMode, "route", "Stale ignored names do not force ignored mode")
            System.AssertTrue(NS.Run.routeSaveBlocked ~= true, "Route persistence remains enabled")
            System.AssertEqual(NS.DB.Settings.ignoredBosses[instanceName]["Old Boss"], nil,
                "Unknown ignored boss names are pruned from settings")
            System.AssertEqual(#selected, 2, "The live boss list remains intact")
            System.EndSection("Ignore only live entries when selecting initial route mode", "PASS")
        end, function()
            NS.Run.instanceName = oldInstanceName
            NS.Run.speedrunMode = oldSpeedrunMode
            NS.DB.Settings.ignoredBosses = oldIgnored
            NS.DB.Settings.autoIgnoredBosses = oldAutoIgnored
        end)
    end,
})

System.RegisterTest({
    id = "logic_last_boss_mode_auto_ignore",
    suite = "Logic",
    subcategory = "Ignore Rules",
    name = "Leaves auto-ignore empty in last boss mode",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Auto Ignore Test"
        local oldInstanceName = NS.Run.instanceName
        local oldSpeedrunMode = NS.Run.speedrunMode
        local oldEntries = NS.Run.entries
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Clear automatic ignore state in last boss mode")
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

            System.AssertTrue(next(NS.DB.Settings.autoIgnoredBosses[instanceName]) == nil,
                "Last-boss mode no longer auto-ignores any rows",
                next(NS.DB.Settings.autoIgnoredBosses[instanceName]))
            System.EndSection("Clear automatic ignore state in last boss mode", "PASS")
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
    name = "Switches an active run into ignored mode when a manual ignore appears",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Auto Ignore Clear Test"
        local oldInstanceName = NS.Run.instanceName
        local oldSpeedrunMode = NS.Run.speedrunMode
        local oldEntries = NS.Run.entries
        local oldRouteMode = NS.Run.routeMode
        local oldRouteSaveBlocked = NS.Run.routeSaveBlocked
        local oldInInstance = NS.Run.inInstance
        local oldSnapshot = NS.Util.CopyTable(NS.Run.pbSegmentsSnapshot or {})
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Switch the live run to ignored mode")
            NS.Run.instanceName = instanceName
            NS.Run.speedrunMode = "all"
            NS.Run.routeMode = "route"
            NS.Run.routeSaveBlocked = false
            NS.Run.inInstance = true
            NS.Run.entries = {
                { key = "A", name = "Boss A", routeIndex = 1 },
                { key = "B", name = "Boss B", routeIndex = 2 },
            }
            NS.Run.pbSegmentsSnapshot = {}
            NS.DB.Settings.ignoredBosses[instanceName] = { ["Boss B"] = true }
            NS.DB.Settings.autoIgnoredBosses[instanceName] = {}
            local node = NS.Database.GetBestIgnoredNode(instanceName, true)
            node.Splits[1] = 45

            NS.RunLogic.HandleIgnoreStateChange()

            System.AssertEqual(NS.Run.routeMode, "ignored", "Manual ignore switches the run into ignored mode")
            System.AssertTrue(NS.Run.routeSaveBlocked == true, "Ignored mode blocks route persistence")
            System.AssertEqual(NS.Run.pbSegmentsSnapshot["A"], 45, "Ignored-mode PBs are loaded immediately")
            System.EndSection("Switch the live run to ignored mode", "PASS")
        end, function()
            NS.Run.instanceName = oldInstanceName
            NS.Run.speedrunMode = oldSpeedrunMode
            NS.Run.entries = oldEntries
            NS.Run.routeMode = oldRouteMode
            NS.Run.routeSaveBlocked = oldRouteSaveBlocked
            NS.Run.inInstance = oldInInstance
            NS.Run.pbSegmentsSnapshot = oldSnapshot
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
                frames = {
                    boss = {
                        x = 99,
                        y = 98,
                        columns = { pb = 111, split = 112, diff = 113 },
                    },
                },
            }
            NS.DB.DefaultLayout = {
                ui = {
                    frames = {
                        boss = {
                            x = 12,
                            y = 34,
                            columns = { pb = 85, split = 90, diff = 95 },
                        },
                    },
                },
            }

            ReloadUI = function()
                reloaded = true
            end
            NS.RefreshAllUI = function() end

            NS.ResetLayout()

            System.AssertEqual(NS.DB.ui.frames.boss.columns.pb, 85, "ResetLayout restores saved PB column width")
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
    id = "logic_layout_initialize_migrates_legacy_shape",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "InitializeDefaults migrates legacy top-level layout fields into nested frame layout state",
    func = function()
        NS.Database.EnsureDB()

        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})
        local oldDefaultLayout = NS.DB.DefaultLayout and NS.Util.CopyTable(NS.DB.DefaultLayout) or nil

        System.WithCleanup(function()
            System.BeginSection("Migrate a legacy layout snapshot")
            NS.DB.ui = {
                cols = { pb = 101, split = 102, delta = 103 },
                historyCols = { date = 141, dungeon = 221, expansion = 142, result = 131, mode = 81, time = 82, diff = 121, delete = 31 },
                frames = {
                    boss = { relPoint = "TOPLEFT", x = 11, y = 22, w = 600, h = 333 },
                    history = { relPoint = "BOTTOM", x = 44, y = 55, w = 900, h = 444 },
                },
            }

            NS.UI.InitializeDefaults()

            System.AssertEqual(NS.DB.ui.frames.boss.relativePoint, "TOPLEFT",
                "Legacy relPoint migrates into relativePoint")
            System.AssertEqual(NS.DB.ui.frames.boss.width, 600, "Legacy boss width migrates into width")
            System.AssertEqual(NS.DB.ui.frames.boss.height, 333, "Legacy boss height migrates into height")
            System.AssertEqual(NS.DB.ui.frames.boss.columns.pb, 101, "Legacy boss columns migrate into nested columns")
            System.AssertEqual(NS.DB.ui.frames.boss.columns.diff, 103, "Legacy delta migrates into nested diff width")
            System.AssertEqual(NS.DB.ui.frames.history.columns.dungeon, 221,
                "Legacy history column widths migrate into nested columns")
            System.EndSection("Migrate a legacy layout snapshot", "PASS")
        end, function()
            NS.DB.ui = oldUI
            NS.DB.DefaultLayout = oldDefaultLayout
        end)
    end,
})

System.RegisterTest({
    id = "logic_apply_frame_layout_uses_wow_restore_order",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "ApplyFrameLayout uses the required WoW restore order",
    func = function()
        local calls = {}
        local frame = {
            SetClampedToScreen = function() end,
            SetScale = function()
                calls[#calls + 1] = "SetScale"
            end,
            SetSize = function()
                calls[#calls + 1] = "SetSize"
            end,
            ClearAllPoints = function()
                calls[#calls + 1] = "ClearAllPoints"
            end,
            SetPoint = function()
                calls[#calls + 1] = "SetPoint"
            end,
            SetResizeBounds = function() end,
            SetResizable = function() end,
        }

        System.BeginSection("Apply a saved frame layout")
        NS.UI.ApplyFrameLayout(frame, {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 451,
            height = 156,
            scale = 1,
            shown = true,
            columns = { pb = 85, split = 100, diff = 70 },
        }, "boss")

        System.AssertEqual(calls[1], "SetScale", "Frame scale is applied first")
        System.AssertEqual(calls[2], "SetSize", "Frame size is applied second")
        System.AssertEqual(calls[3], "ClearAllPoints", "Existing anchors are cleared before SetPoint")
        System.AssertEqual(calls[4], "SetPoint", "Frame anchors are restored after ClearAllPoints")
        System.EndSection("Apply a saved frame layout", "PASS")
    end,
})

System.RegisterTest({
    id = "logic_capture_current_layout_writes_normalized_frame_metadata",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "CaptureCurrentLayout stores point-based frame geometry",
    func = function()
        NS.Database.EnsureDB()

        local oldTimerFrame = NS.UI.timerFrame
        local oldBossFrame = NS.UI.bossFrame
        local oldHistoryFrame = NS.UI.history.frame
        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})

        System.WithCleanup(function()
            System.BeginSection("Capture live frame geometry into the saved layout snapshot")
            local function MakeFrame(point, relativePoint, x, y, w, h)
                return {
                    GetPoint = function()
                        return point, UIParent, relativePoint, x, y
                    end,
                    GetWidth = function()
                        return w
                    end,
                    GetHeight = function()
                        return h
                    end,
                    GetScale = function()
                        return 1
                    end,
                    IsShown = function()
                        return true
                    end,
                }
            end

            NS.UI.timerFrame = MakeFrame("TOP", "TOP", -10.1234, -55.9876, 200.3456, 70.6543)
            NS.UI.bossFrame = MakeFrame("CENTER", "CENTER", 12.3456, 34.5678, 499.9999, 250.1111)
            NS.UI.history.frame = MakeFrame("BOTTOMRIGHT", "BOTTOMRIGHT", -20.5555, 15.4444, 850.4444, 501.5555)
            NS.DB.ui = {}

            NS.UI.CaptureCurrentLayout()

            System.AssertEqual(NS.DB.ui.frames.boss.point, "CENTER", "Boss frame point is captured")
            System.AssertEqual(NS.DB.ui.frames.history.relativePoint, "BOTTOMRIGHT",
                "History frame relativePoint is captured")
            System.AssertNear(NS.DB.ui.frames.boss.width, 500, 0.001, "Boss frame width is normalized")
            System.AssertNear(NS.DB.ui.frames.history.x, -20.556, 0.001, "History frame x-offset is normalized")
            System.EndSection("Capture live frame geometry into the saved layout snapshot", "PASS")
        end, function()
            NS.UI.timerFrame = oldTimerFrame
            NS.UI.bossFrame = oldBossFrame
            NS.UI.history.frame = oldHistoryFrame
            NS.DB.ui = oldUI
        end)
    end,
})

System.RegisterTest({
    id = "logic_restore_frame_geom_falls_back_and_clamps",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "RestoreFrameGeom clamps invalid saved geometry and falls back per frame",
    func = function()
        NS.Database.EnsureDB()

        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})

        System.WithCleanup(function()
            System.BeginSection("Restore an invalid boss frame snapshot using validation rules")
            local applied = {}
            local frame = {
                ClearAllPoints = function() end,
                SetPoint = function(_, point, _, relPoint, x, y)
                    applied.point = point
                    applied.relPoint = relPoint
                    applied.x = x
                    applied.y = y
                end,
                SetSize = function(_, w, h)
                    applied.w = w
                    applied.h = h
                end,
                SetScale = function(_, scale)
                    applied.scale = scale
                end,
                SetClampedToScreen = function(_, value)
                    applied.clamped = value
                end,
                SetResizable = function() end,
                SetResizeBounds = function(_, minW, minH, maxW, maxH)
                    applied.minW = minW
                    applied.minH = minH
                    applied.maxW = maxW
                    applied.maxH = maxH
                end,
            }

            NS.DB.ui = {
                frames = {
                    boss = {
                        point = "NOT_A_POINT",
                        relativePoint = "ALSO_BAD",
                        x = 999999,
                        y = -999999,
                        width = 10,
                        height = 10,
                    },
                },
            }

            local restored = NS.UI.RestoreFrameGeom("boss", frame, 520, 320)

            System.AssertTrue(restored == true, "RestoreFrameGeom treats the saved snapshot as present")
            System.AssertEqual(applied.point, "CENTER", "Invalid point falls back to a valid anchor")
            System.AssertEqual(applied.relPoint, "CENTER", "Invalid relativePoint falls back to a valid anchor")
            System.AssertEqual(applied.w, 450, "Boss width is clamped to the minimum width")
            System.AssertEqual(applied.h, NS.Const.SPLITS_LAYOUT.MIN_HEIGHT,
                "Boss height is clamped to the minimum height")
            System.AssertEqual(applied.clamped, true, "Restore reapplies clamped-to-screen behavior")
            System.EndSection("Restore an invalid boss frame snapshot using validation rules", "PASS")
        end, function()
            NS.DB.ui = oldUI
        end)
    end,
})

System.RegisterTest({
    id = "logic_restore_frame_geom_uses_factory_defaults_when_missing",
    suite = "Logic",
    subcategory = "Layout Reset",
    name = "RestoreFrameGeom applies the Config factory layout when no saved snapshot exists",
    func = function()
        NS.Database.EnsureDB()

        local oldUI = NS.Util.CopyTable(NS.DB.ui or {})

        System.WithCleanup(function()
            System.BeginSection("Restore a missing boss snapshot from Config factory defaults")
            local applied = {}
            local frame = {
                ClearAllPoints = function() end,
                SetPoint = function(_, point, _, relPoint, x, y)
                    applied.point = point
                    applied.relPoint = relPoint
                    applied.x = x
                    applied.y = y
                end,
                SetSize = function(_, w, h)
                    applied.w = w
                    applied.h = h
                end,
                SetScale = function(_, scale)
                    applied.scale = scale
                end,
                SetClampedToScreen = function(_, value)
                    applied.clamped = value
                end,
                SetResizable = function() end,
                SetResizeBounds = function(_, minW, minH, maxW, maxH)
                    applied.minW = minW
                    applied.minH = minH
                    applied.maxW = maxW
                    applied.maxH = maxH
                end,
            }

            NS.DB.ui = {
                frames = {},
            }

            local restored = NS.UI.RestoreFrameGeom("boss", frame, 520, 320)

            System.AssertTrue(restored == false, "RestoreFrameGeom reports no saved snapshot was present", restored)
            System.AssertEqual(applied.point, NS.FactoryDefaults.ui.frames.boss.point,
                "Missing boss snapshot falls back to Config point")
            System.AssertEqual(applied.relPoint, NS.FactoryDefaults.ui.frames.boss.relativePoint,
                "Missing boss snapshot falls back to Config relativePoint")
            System.AssertEqual(applied.w, NS.FactoryDefaults.ui.frames.boss.width,
                "Missing boss snapshot falls back to Config width")
            System.AssertEqual(applied.h, NS.FactoryDefaults.ui.frames.boss.height,
                "Missing boss snapshot falls back to Config height")
            System.AssertNear(applied.x, NS.FactoryDefaults.ui.frames.boss.x, 0.001,
                "Missing boss snapshot falls back to Config x-offset")
            System.AssertNear(applied.y, NS.FactoryDefaults.ui.frames.boss.y, 0.001,
                "Missing boss snapshot falls back to Config y-offset")
            System.EndSection("Restore a missing boss snapshot from Config factory defaults", "PASS")
        end, function()
            NS.DB.ui = oldUI
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
                frames = {
                    boss = { x = 1, y = 2, columns = { pb = 80, split = 81, diff = 82 } },
                    history = { x = 3, y = 4 },
                },
            }
            NS.UI.CaptureCurrentLayout = function()
                NS.DB.ui.frames.boss.columns.pb = 120
                NS.DB.ui.frames.boss.columns.split = 121
                NS.DB.ui.frames.boss.x = 55
                NS.DB.ui.frames.history.width = 900
            end

            NS.SaveDefaultLayout()

            System.AssertEqual(NS.DB.DefaultLayout.ui.frames.boss.columns.pb, 120,
                "SaveDefaultLayout captures the live PB width")
            System.AssertEqual(NS.DB.DefaultLayout.ui.frames.boss.x, 55, "SaveDefaultLayout captures the live boss position")
            System.AssertEqual(NS.DB.DefaultLayout.ui.frames.history.width, 900,
                "SaveDefaultLayout captures the live history dimensions")
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
        local oldRoutes = NS.Util.CopyTable(NS.DB.InstanceRoutes or {})
        local oldBestRoute = NS.Util.CopyTable(NS.DB.InstanceBestRoute or {})
        local oldBestLast = NS.Util.CopyTable(NS.DB.InstanceBestLastBoss or {})
        local oldBestIgnored = NS.Util.CopyTable(NS.DB.InstanceBestIgnored or {})
        local oldReloadUI = ReloadUI
        local reloaded = false

        System.WithCleanup(function()
            System.BeginSection("Simulate wiping records")
            NS.DB.RunHistory = { { instanceName = "Test" } }
            NS.DB.InstanceRoutes = { Test = { BossIndex = { Boss = 1 }, ["1"] = { Splits = { [1] = 10 } } } }
            NS.DB.InstanceBestRoute = { Test = { RouteKey = "1", Splits = { [1] = 10 } } }
            NS.DB.InstanceBestLastBoss = { Test = { Splits = { [1] = 10 } } }
            NS.DB.InstanceBestIgnored = { Test = { Splits = { [1] = 10 } } }
            ReloadUI = function()
                reloaded = true
            end

            NS.WipeDatabase(true)

            System.AssertEqual(#NS.DB.RunHistory, 0, "Simulated wipe clears run history")
            System.AssertEqual(next(NS.DB.InstanceRoutes), nil, "Simulated wipe clears instance routes")
            System.AssertEqual(next(NS.DB.InstanceBestRoute), nil, "Simulated wipe clears best-route data")
            System.AssertEqual(next(NS.DB.InstanceBestLastBoss), nil, "Simulated wipe clears last-boss PBs")
            System.AssertEqual(next(NS.DB.InstanceBestIgnored), nil, "Simulated wipe clears ignored-mode PBs")
            System.AssertTrue(reloaded == false, "Simulated wipe does not reload the UI", reloaded)
            System.EndSection("Simulate wiping records", "PASS")
        end, function()
            NS.DB.RunHistory = oldHistory
            NS.DB.InstanceRoutes = oldRoutes
            NS.DB.InstanceBestRoute = oldBestRoute
            NS.DB.InstanceBestLastBoss = oldBestLast
            NS.DB.InstanceBestIgnored = oldBestIgnored
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
            NS.DB.ui.frames.boss = {
                point = "TOPLEFT",
                relativePoint = "TOPLEFT",
                x = 1,
                y = 2,
                width = 999,
                height = 888,
                columns = { pb = 123, split = 321, diff = 654 },
            }
            NS.DB.ui.frames.history = {
                point = "TOPLEFT",
                relativePoint = "TOPLEFT",
                x = 3,
                y = 4,
                width = 777,
                height = 666,
                columns = { date = 1, dungeon = 2, expansion = 3, result = 4, mode = 5, time = 6, diff = 7, delete = 8 },
            }
            ReloadUI = function()
                reloaded = true
            end

            NS.ResetToFactorySettings(true)

            System.AssertEqual(NS.DB.Settings.speedrunMode, NS.FactoryDefaults.Settings.speedrunMode,
                "Simulated factory reset restores factory settings")
            System.AssertEqual(NS.DB.ui.frames.boss.columns.pb, NS.FactoryDefaults.ui.frames.boss.columns.pb,
                "Simulated factory reset restores factory layout")
            System.AssertEqual(NS.DB.ui.frames.boss.columns.split, NS.FactoryDefaults.ui.frames.boss.columns.split,
                "Simulated factory reset restores factory split width")
            System.AssertEqual(NS.DB.ui.frames.boss.columns.diff, NS.FactoryDefaults.ui.frames.boss.columns.diff,
                "Simulated factory reset restores factory diff width")
            System.AssertEqual(NS.DB.ui.frames.history.columns.date, NS.FactoryDefaults.ui.frames.history.columns.date,
                "Simulated factory reset restores factory history column widths")
            System.AssertEqual(NS.DB.DefaultLayout.ui.frames.boss.columns.pb, NS.FactoryDefaults.ui.frames.boss.columns.pb,
                "Simulated factory reset refreshes the default layout snapshot")
            System.AssertEqual(NS.DB.ui.frames.boss.point, NS.FactoryDefaults.ui.frames.boss.point,
                "Simulated factory reset restores normalized boss frame geometry")
            System.AssertNear(NS.DB.ui.frames.boss.x, NS.FactoryDefaults.ui.frames.boss.x, 0.001,
                "Simulated factory reset restores boss x-offset from Config")
            System.AssertNear(NS.DB.ui.frames.boss.y, NS.FactoryDefaults.ui.frames.boss.y, 0.001,
                "Simulated factory reset restores boss y-offset from Config")
            System.AssertEqual(NS.DB.ui.frames.history.width, NS.FactoryDefaults.ui.frames.history.width,
                "Simulated factory reset restores history width from Config")
            System.AssertEqual(NS.DB.ui.frames.history.height, NS.FactoryDefaults.ui.frames.history.height,
                "Simulated factory reset restores history height from Config")
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
            bossByDungeonEncounterID = NS.Run.bossByDungeonEncounterID,
            pbSegmentsSnapshot = NS.Run.pbSegmentsSnapshot,
            presentation = NS.Run.presentation,
            routeMode = NS.Run.routeMode,
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
                { key = "E:101", name = "Boss A", dungeonEncounterID = 101, routeIndex = 1 },
                { key = "E:102", name = "Boss B", dungeonEncounterID = 102, routeIndex = 2 },
            }
            NS.Run.remaining = { ["E:101"] = true, ["E:102"] = true }
            NS.Run.bossByDungeonEncounterID = {
                [101] = NS.Run.entries[1],
                [102] = NS.Run.entries[2],
            }
            NS.Run.remainingCount = 2
            NS.Run.killedCount = 0
            NS.Run.kills = {}
            NS.Run.routeMode = "ignored"
            NS.Run.pbSegmentsSnapshot = { ["E:101"] = 60, ["E:102"] = 120 }
            NS.Run.presentation = nil

            local node = NS.Database.GetBestIgnoredNode("Equal Pace Test", true)
            node.Splits = { [1] = 60, [2] = 120 }
            node.FullRun = { duration = 120 }
            System.LogInfo("Seeded PBs for Boss A and Boss B at 60 seconds each.")
            System.EndSection("Seed a two-boss equal-pace run", "PASS")

            System.BeginSection("Record equal-pace kills")
            NS.NowGameTime = function()
                return 160
            end
            NS.RunLogic.RecordBossKill(101, "Boss A")
            System.AssertNear(NS.Run.lastDelta or 0, 0, 0.001, "Boss A delta remains at zero")

            NS.NowGameTime = function()
                return 220
            end
            NS.RunLogic.RecordBossKill(102, "Boss B")
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
            NS.Run.bossByDungeonEncounterID = oldState.bossByDungeonEncounterID
            NS.Run.pbSegmentsSnapshot = oldState.pbSegmentsSnapshot
            NS.Run.presentation = oldState.presentation
            NS.Run.routeMode = oldState.routeMode
            NS.DB.Settings.showTimerToast = oldState.showTimerToast
        end)
    end,
})

System.RegisterTest({
    id = "logic_record_boss_kill_ignores_unmapped_objective_rows",
    suite = "Logic",
    subcategory = "Boss Resolution",
    name = "Ignores live encounter ids that are not mapped to a boss row",
    func = function()
        local oldNow = NS.NowGameTime
        local oldState = NS.Util.CopyTable(NS.Run)

        System.WithCleanup(function()
            System.BeginSection("Seed objective fallback rows without dungeon encounter ids")
            NS.Run.active = true
            NS.Run.startGameTime = 100
            NS.Run.entries = {
                { key = "N:bossona", name = "Boss One", dungeonEncounterID = nil },
            }
            NS.Run.remaining = { ["N:bossona"] = true }
            NS.Run.remainingCount = 1
            NS.Run.killedCount = 0
            NS.Run.kills = {}
            NS.Run.bossByDungeonEncounterID = {}
            NS.NowGameTime = function()
                return 150
            end
            System.EndSection("Seed objective fallback rows without dungeon encounter ids", "PASS")

            System.BeginSection("Ignore an unmapped kill event")
            NS.RunLogic.RecordBossKill(777, "Boss One")
            System.AssertEqual(NS.Run.kills["N:bossona"], nil, "No split is recorded for an unmapped encounter id")
            System.AssertEqual(NS.Run.remainingCount, 1, "Remaining boss count is unchanged")
            System.EndSection("Ignore an unmapped kill event", "PASS")
        end, function()
            NS.NowGameTime = oldNow
            for key in pairs(NS.Run) do
                NS.Run[key] = nil
            end
            for key, value in pairs(oldState) do
                NS.Run[key] = value
            end
        end)
    end,
})

System.RegisterTest({
    id = "logic_new_segment_pb_updates_db_but_keeps_run_snapshot",
    suite = "Logic",
    subcategory = "Pace Calculation",
    name = "Ignored mode updates stored PBs while keeping the current run snapshot frozen",
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
            bossByDungeonEncounterID = NS.Run.bossByDungeonEncounterID,
            pbSegmentsSnapshot = NS.Run.pbSegmentsSnapshot,
            presentation = NS.Run.presentation,
            routeMode = NS.Run.routeMode,
            showTimerToast = NS.DB.Settings.showTimerToast,
        }

        System.WithCleanup(function()
            System.BeginSection("Seed a single-boss run with a frozen PB snapshot")
            NS.UI.SetRowKilled = function() end
            NS.UI.SetKillCount = function() end
            NS.UI.RefreshTotals = function() end
            NS.ShowToast = function() end
            NS.DB.Settings.showTimerToast = false

            NS.Run.instanceName = "Frozen PB Test"
            NS.Run.speedrunMode = "all"
            NS.Run.routeMode = "ignored"
            NS.Run.active = true
            NS.Run.startGameTime = 100
            NS.Run.entries = {
                { key = "E:2001", name = "Boss A", dungeonEncounterID = 2001, routeIndex = 1 },
            }
            NS.Run.remaining = { ["E:2001"] = true }
            NS.Run.remainingCount = 1
            NS.Run.killedCount = 0
            NS.Run.kills = {}
            NS.Run.bossByDungeonEncounterID = {
                [2001] = NS.Run.entries[1],
            }
            NS.Run.pbSegmentsSnapshot = { ["E:2001"] = 60 }

            local node = NS.Database.GetBestIgnoredNode("Frozen PB Test", true)
            node.Splits = { [1] = 60 }
            System.EndSection("Seed a single-boss run with a frozen PB snapshot", "PASS")

            System.BeginSection("Record a faster split without mutating the run snapshot")
            NS.NowGameTime = function()
                return 150
            end

            NS.RunLogic.RecordBossKill(2001, "Boss A")

            System.AssertEqual(node.Splits[1], 50, "The persisted ignored-mode PB is updated immediately")
            System.AssertEqual(NS.Run.pbSegmentsSnapshot["E:2001"], 60,
                "The active run PB snapshot stays frozen at the pre-run value")
            System.AssertEqual(NS.Run.lastPBTotal, 60,
                "The row visual state continues to compare against the old PB for this run")
            System.EndSection("Record a faster split without mutating the run snapshot", "PASS")
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
            NS.Run.bossByDungeonEncounterID = oldState.bossByDungeonEncounterID
            NS.Run.pbSegmentsSnapshot = oldState.pbSegmentsSnapshot
            NS.Run.presentation = oldState.presentation
            NS.Run.routeMode = oldState.routeMode
            NS.DB.Settings.showTimerToast = oldState.showTimerToast
        end)
    end,
})

System.RegisterTest({
    id = "logic_exploring_route_falls_back_to_fastest_route_pbs",
    suite = "Logic",
    subcategory = "Route Tracking",
    name = "A new unmatched route keeps exploratory ordering but compares against the fastest saved route",
    func = function()
        NS.Database.EnsureDB()

        local oldRoutes = NS.Util.CopyTable(NS.DB.InstanceRoutes or {})
        local oldBestRoute = NS.Util.CopyTable(NS.DB.InstanceBestRoute or {})
        local oldState = NS.Util.CopyTable(NS.Run)

        System.WithCleanup(function()
            System.BeginSection("Switch from a matching route to exploratory mode with fastest-route PBs")
            NS.DB.InstanceRoutes["Exploring Route Test"] = {
                BossIndex = {
                    [1] = "Boss 1",
                    [2] = "Boss 2",
                    [3] = "Boss 3",
                    [4] = "Boss 4",
                },
                ["1,2,3,4"] = {
                    Splits = { [1] = 10, [2] = 20, [3] = 30, [4] = 40 },
                    FullRun = { duration = 40 },
                },
                ["2,3,1,4"] = {
                    Splits = { [1] = 25, [2] = 8, [3] = 16, [4] = 32 },
                    FullRun = { duration = 32 },
                },
            }
            NS.DB.InstanceBestRoute["Exploring Route Test"] = {
                RouteKey = "2,3,1,4",
                Splits = { [1] = 25, [2] = 8, [3] = 16, [4] = 32 },
                FullRun = { duration = 32 },
            }

            NS.Run.instanceName = "Exploring Route Test"
            NS.Run.routeMode = "route"
            NS.Run.entries = {
                { key = "B1", name = "Boss 1", routeIndex = 1 },
                { key = "B2", name = "Boss 2", routeIndex = 2 },
                { key = "B3", name = "Boss 3", routeIndex = 3 },
                { key = "B4", name = "Boss 4", routeIndex = 4 },
            }
            NS.Run.kills = {
                B1 = 10,
                B2 = 20,
                B4 = 30,
            }
            NS.Run.killOrder = { "B1", "B2", "B4" }
            NS.Run.killRouteIndices = { 1, 2, 4 }
            NS.Run.killedCount = 3
            NS.Run.activeRouteKey = "1,2,3,4"
            NS.Run.pbSegmentsSnapshot = {
                B1 = 10,
                B2 = 20,
                B3 = 30,
                B4 = 40,
            }

            NS.RunLogic.HandleRouteProgression()

            System.AssertTrue(NS.Run.routeExploring == true, "The run is marked as exploring once no saved route matches the prefix")
            System.AssertEqual(NS.Run.activeRouteKey, "2,3,1,4", "Exploring runs compare against the fastest saved route")
            System.AssertEqual(NS.Run.entries[1].key, "B1", "Killed bosses stay at the top in live kill order")
            System.AssertEqual(NS.Run.entries[2].key, "B2", "Second killed boss remains second")
            System.AssertEqual(NS.Run.entries[3].key, "B4", "The newly explored boss remains in killed order")
            System.AssertEqual(NS.Run.pbSegmentsSnapshot.B1, 25, "Boss 1 PB falls back to the fastest saved route")
            System.AssertEqual(NS.Run.pbSegmentsSnapshot.B2, 8, "Boss 2 PB falls back to the fastest saved route")
            System.AssertEqual(NS.Run.pbSegmentsSnapshot.B4, 32, "Boss 4 PB falls back to the fastest saved route")
            System.EndSection("Switch from a matching route to exploratory mode with fastest-route PBs", "PASS")
        end, function()
            NS.DB.InstanceRoutes = oldRoutes
            NS.DB.InstanceBestRoute = oldBestRoute
            for key in pairs(NS.Run) do
                NS.Run[key] = nil
            end
            for key, value in pairs(oldState) do
                NS.Run[key] = value
            end
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
System.RegisterTest({
    id = "logic_out_of_order_kills_calculate_positive_segments",
    suite = "Logic",
    subcategory = "Pace Calculation",
    name = "Ensures positive chronological segments when bosses are killed out of order",
    func = function()
        NS.Database.EnsureDB()
        local oldState = NS.Util.CopyTable(NS.Run)

        System.WithCleanup(function()
            System.BeginSection("Seed a three-boss out-of-order run")
            NS.Run.active = true
            NS.Run.startGameTime = 100
            NS.Run.entries = {
                { key = "1", name = "Boss 1" },
                { key = "2", name = "Boss 2" },
                { key = "3", name = "Boss 3" },
            }
            NS.Run.kills = {
                ["1"] = 10,  -- Boss 1 killed at 10s
                ["3"] = 25,  -- Boss 3 killed at 25s (BEFORE Boss 2)
                ["2"] = 40,  -- Boss 2 killed at 40s
            }
            NS.Run.pbSegmentsSnapshot = { ["Boss 1"] = 15, ["Boss 2"] = 15, ["Boss 3"] = 15 }

            local presentation = NS.RunLogic.BuildRunPresentation(NS.Run, NS.Run.pbSegmentsSnapshot)

            local row1 = presentation.rowsByKey["1"]
            local row2 = presentation.rowsByKey["2"]
            local row3 = presentation.rowsByKey["3"]

            System.AssertEqual(row1.segmentTime, 10, "Boss 1 segment is its split time")
            System.AssertEqual(row3.segmentTime, 15, "Boss 3 segment (25-10) is positive and chronological")
            System.AssertEqual(row2.segmentTime, 15, "Boss 2 segment (40-25) is positive even if it follows out-of-order in table")

            System.AssertEqual(presentation.summary.diffTotal, row2.diffTime, "Footer diff total matches the last kill in chronological order (Boss 2)")

            System.EndSection("Seed a three-boss out-of-order run", "PASS")
        end, function()
            for key in pairs(NS.Run) do NS.Run[key] = nil end
            for key, value in pairs(oldState) do NS.Run[key] = value end
        end)
    end,
})
