local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("ResolveBossKey by normalized name", "Logic", function()
    local oldEntries = NS.Run.entries
    local oldRemaining = NS.Run.remaining
    NS.Run.entries = {
        { key = "N:testboss", name = "Test Boss" },
    }
    NS.Run.remaining = {
        ["N:testboss"] = true,
    }
    local key = NS.RunLogic.ResolveBossKey(nil, "Test Boss")
    NS.Run.entries = oldEntries
    NS.Run.remaining = oldRemaining
    System.Assert(key == "N:testboss", "N:testboss", key)
end)

System.RegisterTest("ResetRun clears timing state", "Logic", function()
    local backup = NS.Util.CopyTable(NS.Run)
    NS.Run.active = true
    NS.Run.startGameTime = 123
    NS.Run.kills = { a = 1 }
    NS.RunLogic.ResetRun()
    local wasInactive = (NS.Run.active == false)
    local startWasZero = (NS.Run.startGameTime == 0)
    local killsWereEmpty = (next(NS.Run.kills) == nil)
    for k in pairs(NS.Run) do
        NS.Run[k] = nil
    end
    for k, v in pairs(backup) do
        NS.Run[k] = v
    end
    System.Assert(wasInactive, false, not wasInactive)
    System.Assert(startWasZero, 0, startWasZero and 0 or 123)
    System.Assert(killsWereEmpty, "empty", killsWereEmpty and "empty" or "not empty")
end)
