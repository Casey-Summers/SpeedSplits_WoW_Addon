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
    name = "Preserves journal and dungeon encounter ids when journal bosses become entries",
    func = function()
        System.BeginSection("Build EJ entries")
        local entries = NS.Discovery.EJBossesToEntries({
            { name = "Boss One", journalEncounterID = 2222, dungeonEncounterID = 1234 },
            { name = "Boss Two", journalEncounterID = 3333, dungeonEncounterID = nil },
        })
        System.AssertEqual(entries[1].key, "E:1234", "Dungeon encounter ids use E-prefixed keys")
        System.AssertEqual(entries[1].journalEncounterID, 2222, "Journal encounter id is preserved on the entry")
        System.AssertEqual(entries[1].dungeonEncounterID, 1234, "Dungeon encounter id is preserved on the entry")
        System.AssertEqual(entries[2].key, "J:3333", "Journal-only bosses fall back to J-prefixed keys")
        System.EndSection("Build EJ entries", "PASS")
    end,
})
