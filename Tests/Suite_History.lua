local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "history_filter_defaults",
    suite = "History",
    subcategory = "Filters",
    name = "Builds default history filters",
    func = function()
        System.BeginSection("Create default history filters")
        local defaults = NS.Util.HistoryFilterDefaults()
        System.AssertEqual(defaults.search, "", "Search filter defaults to an empty string")
        System.AssertEqual(defaults.result, "Any", "Result filter defaults to Any")
        System.EndSection("Create default history filters", "PASS")
    end,
})

System.RegisterTest({
    id = "history_database_ensure_table",
    suite = "History",
    subcategory = "Database",
    name = "Ensures the database contains the new route-aware tables",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Rebuild database from an empty saved variable")
            SpeedSplitsDB = nil
            local db = NS.Database.EnsureDB()
            System.AssertEqual(type(db.RunHistory), "table", "RunHistory is created as a table")
            System.AssertEqual(type(db.InstanceRoutes), "table", "InstanceRoutes is created as a table")
            System.AssertEqual(type(db.InstanceBestRoute), "table", "InstanceBestRoute is created as a table")
            System.AssertEqual(type(db.InstanceBestLastBoss), "table", "InstanceBestLastBoss is created as a table")
            System.AssertEqual(type(db.InstanceBestIgnored), "table", "InstanceBestIgnored is created as a table")
            System.EndSection("Rebuild database from an empty saved variable", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})

System.RegisterTest({
    id = "history_delete_rebuilds_best_route",
    suite = "History",
    subcategory = "Database",
    name = "Deleting a route run rebuilds best-route data from remaining history",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Delete the fastest saved route run")
            local bestRun = {
                success = true,
                instanceName = "PB Delete Test",
                duration = 90,
                endedAt = 200,
                tier = 11,
                difficultyID = 8,
                difficultyName = "Mythic",
                mapID = 1234,
                pbMode = "route",
                routeKey = "1,2",
                bosses = {
                    { key = "A", name = "Boss A", routeIndex = 1 },
                    { key = "B", name = "Boss B", routeIndex = 2 },
                },
                kills = {
                    A = 40,
                    B = 90,
                },
            }
            local olderRun = {
                success = true,
                instanceName = "PB Delete Test",
                duration = 120,
                endedAt = 100,
                tier = 11,
                difficultyID = 8,
                difficultyName = "Mythic",
                mapID = 1234,
                pbMode = "route",
                routeKey = "1,2",
                bosses = {
                    { key = "A", name = "Boss A", routeIndex = 1 },
                    { key = "B", name = "Boss B", routeIndex = 2 },
                },
                kills = {
                    A = 50,
                    B = 120,
                },
            }

            SpeedSplitsDB = {
                SchemaVersion = 2,
                RunHistory = { bestRun, olderRun },
                InstanceRoutes = {},
                InstanceBestRoute = {},
                InstanceBestLastBoss = {},
                InstanceBestIgnored = {},
                Settings = {},
            }
            NS.Database.EnsureDB()
            NS.Database.RebuildPBDataFromHistory()

            NS.Database.DeleteRunRecord(bestRun)

            local node = NS.Database.GetBestRouteNode("PB Delete Test", false)
            System.AssertEqual(#NS.DB.RunHistory, 1, "The deleted run is removed from RunHistory")
            System.AssertEqual(node.FullRun.duration, 120, "Best-route full run falls back to the remaining run")
            System.AssertEqual(node.Splits[1], 50, "Boss A PB is rebuilt from remaining history")
            System.AssertEqual(node.Splits[2], 120, "Boss B PB is rebuilt from remaining history")
            System.EndSection("Delete the fastest saved route run", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})

System.RegisterTest({
    id = "history_delete_clears_last_instance_pb_node",
    suite = "History",
    subcategory = "Database",
    name = "Deleting the last route run clears the best-route node",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Delete the only saved route run")
            local onlyRun = {
                success = true,
                instanceName = "PB Delete Empty Test",
                duration = 75,
                pbMode = "route",
                routeKey = "1",
                bosses = {
                    { key = "A", name = "Boss A", routeIndex = 1 },
                },
                kills = {
                    A = 75,
                },
            }

            SpeedSplitsDB = {
                SchemaVersion = 2,
                RunHistory = { onlyRun },
                InstanceRoutes = {},
                InstanceBestRoute = {},
                InstanceBestLastBoss = {},
                InstanceBestIgnored = {},
                Settings = {},
            }
            NS.Database.EnsureDB()
            NS.Database.RebuildPBDataFromHistory()

            NS.Database.DeleteRunRecord(onlyRun)

            System.AssertEqual(#NS.DB.RunHistory, 0, "The only run is removed from RunHistory")
            System.AssertEqual(NS.DB.InstanceBestRoute["PB Delete Empty Test"], nil,
                "The best-route node is removed when no route runs remain")
            System.EndSection("Delete the only saved route run", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})
