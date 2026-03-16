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
    name = "Ensures the database contains a run history table",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Rebuild database from an empty saved variable")
            SpeedSplitsDB = nil
            local db = NS.Database.EnsureDB()
            System.AssertEqual(type(db.RunHistory), "table", "RunHistory is created as a table")
            System.EndSection("Rebuild database from an empty saved variable", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})

System.RegisterTest({
    id = "history_purges_test_records",
    suite = "History",
    subcategory = "Database",
    name = "Removes saved test runs from Run History",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Purge historical test records during database init")
            SpeedSplitsDB = {
                RunHistory = {
                    { instanceName = "Mock Speedrun Dungeon", bossSource = "simulation", duration = 120 },
                    { instanceName = "Real Dungeon", bossSource = "encounter_journal", duration = 240 },
                },
                InstancePersonalBests = {},
                Settings = {},
            }

            local db = NS.Database.EnsureDB()
            System.AssertEqual(#db.RunHistory, 1, "Only non-test run history records remain after migration")
            System.AssertEqual(db.RunHistory[1].instanceName, "Real Dungeon", "The real run history entry is retained")
            System.EndSection("Purge historical test records during database init", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})
