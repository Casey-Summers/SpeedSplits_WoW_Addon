local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("Objective text parsing", "Discovery", function()
    local parsed = NS.Discovery.ExtractBossNameFromObjectiveText("0/1 Defeat Waxface")
    System.Assert(parsed == "Waxface", "Waxface", parsed)
end)

System.RegisterTest("EJ entry keys preserve encounter IDs", "Discovery", function()
    local entries = NS.Discovery.EJBossesToEntries({
        { name = "Boss One", encounterID = 1234 },
        { name = "Boss Two", encounterID = nil },
    })
    System.Assert(entries[1].key == "E:1234", "E:1234", entries[1].key)
    System.Assert(entries[2].key == "N:bosstwo", "N:bosstwo", entries[2].key)
end)
