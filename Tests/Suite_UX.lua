local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "ux_format_time_seconds",
    suite = "UX",
    subcategory = "Formatting",
    name = "Formats plain second values",
    func = function()
        System.BeginSection("Format plain seconds")
        System.AssertEqual(NS.Util.FormatTime(12.345), "12.345", "Second-only durations keep millisecond precision")
        System.EndSection("Format plain seconds", "PASS")
    end,
})

System.RegisterTest({
    id = "ux_format_delta_positive",
    suite = "UX",
    subcategory = "Formatting",
    name = "Formats positive delta values",
    func = function()
        System.BeginSection("Format positive deltas")
        System.AssertEqual(NS.Util.FormatDelta(2.5), "+2.500", "Positive deltas include a leading plus sign")
        System.EndSection("Format positive deltas", "PASS")
    end,
})

System.RegisterTest({
    id = "ux_pace_color_tie_is_gold",
    suite = "UX",
    subcategory = "Color Rules",
    name = "Treats pace ties as gold",
    func = function()
        System.BeginSection("Resolve pace color for a tie")
        local _, _, _, hex = NS.GetPaceColor(0, false)
        System.AssertEqual(hex, NS.Colors.gold.hex, "A zero delta resolves to the gold pace color")
        System.EndSection("Resolve pace color for a tie", "PASS")
    end,
})
