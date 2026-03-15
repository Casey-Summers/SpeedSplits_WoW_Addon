local _, NS = ...
local System = NS.TestSystem

function NS.SimulateSpeedrun()
    System.Log("SIMULATION START: Speedrun with 7 bosses...", "INFO")
    
    -- Setup mock run
    local Run = NS.Run
    Run.inInstance = true
    Run.instanceName = "Mock Speedrun Dungeon"
    Run.instanceType = "party"
    Run.difficultyID = 1
    Run.mapID = 999
    Run.journalID = 0
    Run.tier = 11
    Run.dungeonKey = "999:1"
    Run.active = true
    Run.startGameTime = NS.NowGameTime()
    Run.startedAt = NS.NowEpoch()
    Run.killedCount = 0
    Run.kills = {}
    
    local mockBosses = {
        { name = "Gold Boss", key = "M:1", displayID = 52047 },
        { name = "Ahead Boss Fast", key = "M:2", displayID = 6110 },
        { name = "Ahead Boss Slow", key = "M:3", displayID = 52515 },
        { name = "Ignored Boss 1", key = "M:4", displayID = 52595 },
        { name = "Behind Boss T1", key = "M:5", displayID = 31042 },
        { name = "Behind Boss T2", key = "M:6", displayID = 12345 },
        { name = "Ignored Boss 2", key = "M:7", displayID = 0 },
        { name = "Behind Boss Over T2", key = "M:8", displayID = 999 },
    }
    
    local entries = {}
    for i, b in ipairs(mockBosses) do
        entries[#entries + 1] = { name = b.name, key = b.key, displayID = b.displayID, order = i }
    end
    
    -- Set ignored bosses in settings
    NS.DB.Settings.ignoredBosses = NS.DB.Settings.ignoredBosses or {}
    NS.DB.Settings.ignoredBosses[Run.instanceName] = {
        ["Ignored Boss 1"] = true,
        ["Ignored Boss 2"] = true,
    }
    
    NS.ApplyBossEntries(entries, "simulation", Run.tier, Run.journalID)
    
    -- Define logical PBs (segment times)
    local pbs = {
        ["Gold Boss"] = 60,
        ["Ahead Boss Fast"] = 60,
        ["Ahead Boss Slow"] = 60,
        ["Behind Boss T1"] = 60,
        ["Behind Boss T2"] = 60,
        ["Behind Boss Over T2"] = 60,
    }
    
    -- Inject PBs into DB
    local node = NS.GetBestSplitsSubtable()
    node.Segments = node.Segments or {}
    for name, time in pairs(pbs) do
        node.Segments[name] = time
    end
    
    -- Thresholds T1=5, T2=10
    local kills = {
        { name = "Gold Boss", time = 59.9 },             -- PB: 60s, Result: 59.9s (Gold/PB -0.1s)
        { name = "Ahead Boss Fast", time = 55.1 },       -- PB: 60s, Result: 55.1s (Green -4.9s)
        { name = "Ahead Boss Slow", time = 58.2 },       -- PB: 60s, Result: 58.2s (Green -1.8s)
        { name = "Behind Boss T1", time = 63.4 },        -- PB: 60s, Result: 63.4s (Yellow +3.4s)
        { name = "Behind Boss T2", time = 68.1 },        -- PB: 60s, Result: 68.1s (Red +8.1s)
        { name = "Behind Boss Over T2", time = 80.5 },   -- PB: 60s, Result: 80.5s (DarkRed +20.5s)
    }

    local elapsed = 0
    local cumulativePB = 0
    local startTime = Run.startGameTime
    
    -- Inject real PBs into the active run session as we go
    Run.pbSplits = Run.pbSplits or {}

    for i, k in ipairs(kills) do
        local segmentPB = pbs[k.name] or 60
        cumulativePB = cumulativePB + segmentPB
        Run.pbSplits[k.name] = cumulativePB -- Cumulative PB for the table to show
        
        elapsed = elapsed + k.time
        local fakeNow = startTime + elapsed
        
        -- Temporarily mock NowGameTime for the duration of RecordBossKill
        local oldNow = NS.NowGameTime
        NS.NowGameTime = function() return fakeNow end
        
        NS.RecordBossKill(nil, k.name)
        
        NS.NowGameTime = oldNow
    end
    
    System.Log("Simulation complete. Check the UI for colors.", "PASS")
end
