local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "pb_sum_of_best_known_segments",
    suite = "PB",
    subcategory = "Computation",
    name = "Totals a sum of best from known segments",
    func = function()
        System.BeginSection("Compute sum of best")
        local sum = NS.RunLogic.ComputeSumOfBest({
            Alpha = 10,
            Beta = 20,
        }, {
            { key = "Alpha", name = "Alpha" },
            { key = "Beta", name = "Beta" },
        })
        System.AssertEqual(sum, 30, "Known segment PBs sum to the expected total")
        System.EndSection("Compute sum of best", "PASS")
    end,
})

System.RegisterTest({
    id = "pb_schema_upgrade_migrates_data_in_place",
    suite = "PB",
    subcategory = "Migration",
    name = "Upgrading migrates BossIndex data in place and preserves history",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Seed a pre-migration route-aware saved variable shape")
            SpeedSplitsDB = {
                SchemaVersion = 2,
                RunHistory = {
                    { instanceName = "Legacy Dungeon", duration = 120 },
                },
                InstanceRoutes = {
                    ["Legacy Dungeon"] = {
                        BossIndex = {
                            Alpha = 1,
                            Beta = 2,
                        },
                        ["1,2"] = {
                            Splits = { [1] = 12, [2] = 34 },
                            FullRun = { duration = 34 },
                        },
                    },
                },
                InstanceBestRoute = {},
                InstanceBestLastBoss = {},
                InstanceBestIgnored = {},
                Settings = {},
            }
            local db = NS.Database.EnsureDB()
            System.AssertEqual(#db.RunHistory, 1, "Run history is preserved during migration")
            System.AssertEqual(type(db.InstanceRoutes), "table", "InstanceRoutes is created")
            System.AssertEqual(type(db.InstanceBestRoute), "table", "InstanceBestRoute is created")
            System.AssertEqual(type(db.InstanceBestLastBoss), "table", "InstanceBestLastBoss is created")
            System.AssertEqual(type(db.InstanceBestIgnored), "table", "InstanceBestIgnored is created")
            System.AssertEqual(db.InstanceRoutes["Legacy Dungeon"].BossIndex[1], "Alpha",
                "BossIndex is migrated to use route indices as keys")
            System.AssertEqual(db.InstanceRoutes["Legacy Dungeon"].BossIndex[2], "Beta",
                "BossIndex preserves the AJ boss ordering")
            System.EndSection("Seed a pre-migration route-aware saved variable shape", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})

System.RegisterTest({
    id = "pb_schema_upgrade_removes_legacy_segments_alias_from_routes",
    suite = "PB",
    subcategory = "Migration",
    name = "Upgrading moves route Segments into Splits and removes the Segments alias",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Seed a route entry that still uses the legacy Segments alias")
            SpeedSplitsDB = {
                SchemaVersion = 2,
                RunHistory = {},
                InstanceRoutes = {
                    ["Legacy Dungeon"] = {
                        BossIndex = {
                            Alpha = 1,
                        },
                        ["1"] = {
                            Segments = { [1] = 12 },
                            FullRun = { duration = 34 },
                        },
                    },
                },
                InstanceBestRoute = {},
                InstanceBestLastBoss = {},
                InstanceBestIgnored = {},
                Settings = {},
            }

            local db = NS.Database.EnsureDB()
            local node = db.InstanceRoutes["Legacy Dungeon"]["1"]

            System.AssertEqual(node.Splits[1], 12, "Legacy route splits are preserved under Splits")
            System.AssertTrue(node.Segments == nil, "Legacy Segments alias is removed from route entries", node.Segments)
            System.EndSection("Seed a route entry that still uses the legacy Segments alias", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})

System.RegisterTest({
    id = "pb_apply_route_record_populates_default_route",
    suite = "PB",
    subcategory = "Persistence",
    name = "Completed route records populate route splits and full-run data",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Route Persistence Test"
        local oldRoutes = NS.Util.CopyTable(NS.DB.InstanceRoutes)
        local oldBestRoute = NS.Util.CopyTable(NS.DB.InstanceBestRoute)

        System.WithCleanup(function()
            System.BeginSection("Persist a completed route record")
            NS.DB.InstanceRoutes[instanceName] = nil
            NS.DB.InstanceBestRoute[instanceName] = nil

            NS.Database.ApplyRouteRecord({
                pbMode = "route",
                success = true,
                instanceName = instanceName,
                routeKey = "1,2",
                duration = 42.5,
                endedAt = 123456,
                bosses = {
                    { key = "A", name = "Boss A", routeIndex = 1 },
                    { key = "B", name = "Boss B", routeIndex = 2 },
                },
                kills = {
                    A = 10.5,
                    B = 42.5,
                },
            })

            local routeNode = NS.DB.InstanceRoutes[instanceName]["1,2"]
            local bestNode = NS.DB.InstanceBestRoute[instanceName]
            local bossIndex = NS.DB.InstanceRoutes[instanceName].BossIndex
            System.AssertEqual(bossIndex[1], "Boss A", "BossIndex stores boss names by route index")
            System.AssertEqual(bossIndex[2], "Boss B", "BossIndex keeps sequential AJ-style numbering")
            System.AssertEqual(routeNode.Splits[1], 10.5, "First boss split is written to the route node")
            System.AssertEqual(routeNode.Splits[2], 42.5, "Final boss split is written to the route node")
            System.AssertEqual(routeNode.FullRun.duration, 42.5, "Route full-run PB is stored")
            System.AssertEqual(bestNode.RouteKey, "1,2", "Best route points at the saved route key")
            System.EndSection("Persist a completed route record", "PASS")
        end, function()
            NS.DB.InstanceRoutes = oldRoutes
            NS.DB.InstanceBestRoute = oldBestRoute
        end)
    end,
})

System.RegisterTest({
    id = "pb_apply_ignored_record_requires_live_ignored_entries",
    suite = "PB",
    subcategory = "Persistence",
    name = "Ignored-mode PBs are not updated without explicit ignored entries",
    func = function()
        NS.Database.EnsureDB()
        local instanceName = "Ignored Guard Test"
        local oldBestIgnored = NS.Util.CopyTable(NS.DB.InstanceBestIgnored)

        System.WithCleanup(function()
            System.BeginSection("Reject an ignored record without ignored entries")
            NS.DB.InstanceBestIgnored[instanceName] = nil

            NS.Database.ApplyIgnoredRecord({
                pbMode = "ignored",
                success = true,
                instanceName = instanceName,
                hasIgnoredEntries = false,
                duration = 33,
                bosses = {
                    { key = "A", name = "Boss A", routeIndex = 1 },
                },
                kills = {
                    A = 33,
                },
            })

            System.AssertEqual(NS.DB.InstanceBestIgnored[instanceName], nil,
                "Ignored PB table is left untouched when no live ignored entries exist")

            NS.Database.ApplyIgnoredRecord({
                pbMode = "ignored",
                success = true,
                instanceName = instanceName,
                hasIgnoredEntries = true,
                duration = 33,
                endedAt = 123456,
                bosses = {
                    { key = "A", name = "Boss A", routeIndex = 1 },
                },
                kills = {
                    A = 33,
                },
            })

            local node = NS.DB.InstanceBestIgnored[instanceName]
            System.AssertEqual(node.Splits[1], 33, "Ignored PBs are stored when the record confirms live ignored entries")
            System.AssertEqual(node.FullRun.duration, 33, "Ignored full-run PB is stored for real ignored runs")
            System.EndSection("Reject an ignored record without ignored entries", "PASS")
        end, function()
            NS.DB.InstanceBestIgnored = oldBestIgnored
        end)
    end,
})
