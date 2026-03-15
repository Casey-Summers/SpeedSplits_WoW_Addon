local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("History filter defaults", "History", function()
    local defaults = NS.Util.HistoryFilterDefaults()
    System.Assert(defaults.search == "", "", defaults.search)
    System.Assert(defaults.result == "Any", "Any", defaults.result)
end)

System.RegisterTest("DB ensure creates history table", "History", function()
    local backupDB = NS.Util.CopyTable(SpeedSplitsDB)
    SpeedSplitsDB = nil
    local db = NS.Database.EnsureDB()
    local runHistoryType = type(db.RunHistory)
    SpeedSplitsDB = backupDB
    NS.Database.EnsureDB()
    System.Assert(runHistoryType == "table", "table", runHistoryType)
end)
