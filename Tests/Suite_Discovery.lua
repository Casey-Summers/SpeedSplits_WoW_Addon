local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "discovery_objective_text_parsing",
    suite = "Discovery",
    subcategory = "Objective Parsing",
    name = "Extracts boss names from scenario objective text",
    func = function()
        System.BeginSection("Parse scenario objective text")
        local parsed = NS.Discovery.ExtractBossNameFromObjectiveText("0/1 Defeat Waxface")
        System.AssertEqual(parsed, "Waxface", "Parsed boss name matches expected value")
        System.EndSection("Parse scenario objective text", "PASS")
    end,
})

System.RegisterTest({
    id = "discovery_ej_entry_key_generation",
    suite = "Discovery",
    subcategory = "Encounter Journal",
    name = "Preserves encounter ids when journal bosses become entries",
    func = function()
        System.BeginSection("Build EJ entries")
        local entries = NS.Discovery.EJBossesToEntries({
            { name = "Boss One", encounterID = 1234 },
            { name = "Boss Two", encounterID = nil },
        })
        System.AssertEqual(entries[1].key, "E:1234", "Encounter id backed bosses use E-prefixed keys")
        System.AssertEqual(entries[2].key, "N:bosstwo", "Name-only bosses fall back to normalized N-prefixed keys")
        System.EndSection("Build EJ entries", "PASS")
    end,
})
