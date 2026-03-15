local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("ComputeSumOfBest totals known splits", "PB", function()
    local sum = NS.RunLogic.ComputeSumOfBest({
        Alpha = 10,
        Beta = 20,
    }, {
        { name = "Alpha" },
        { name = "Beta" },
    })
    System.Assert(sum == 30, 30, sum)
end)

System.RegisterTest("GetBestSplitsSubtable migrates old shape", "PB", function()
    local backupDB = NS.Util.CopyTable(SpeedSplitsDB)
    SpeedSplitsDB = {
        InstancePersonalBests = {
            Sample = {
                normal = {
                    pbBoss = { Alpha = 12 },
                    pbRun = { duration = 50 },
                },
            },
        },
        Settings = {},
        RunHistory = {},
    }
    NS.Database.EnsureDB()
    local node = NS.GetBestSplitsSubtable("Sample")
    local segmentAlpha = node.Segments.Alpha
    local duration = node.FullRun.duration
    SpeedSplitsDB = backupDB
    NS.Database.EnsureDB()
    System.Assert(segmentAlpha == 12, 12, segmentAlpha)
    System.Assert(duration == 50, 50, duration)
end)
