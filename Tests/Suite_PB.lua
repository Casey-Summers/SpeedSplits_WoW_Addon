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
            { name = "Alpha" },
            { name = "Beta" },
        })
        System.AssertEqual(sum, 30, "Known segment PBs sum to the expected total")
        System.EndSection("Compute sum of best", "PASS")
    end,
})

System.RegisterTest({
    id = "pb_legacy_shape_migration",
    suite = "PB",
    subcategory = "Migration",
    name = "Normalizes legacy personal best nodes",
    func = function()
        local backupDB = NS.Util.CopyTable(SpeedSplitsDB)

        System.WithCleanup(function()
            System.BeginSection("Seed a legacy InstancePersonalBests shape")
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
            System.AssertEqual(node.Segments.Alpha, 12, "Legacy pbBoss data moves into Segments")
            System.AssertEqual(node.FullRun.duration, 50, "Legacy pbRun data moves into FullRun")
            System.EndSection("Seed a legacy InstancePersonalBests shape", "PASS")
        end, function()
            SpeedSplitsDB = backupDB
            NS.Database.EnsureDB()
        end)
    end,
})
