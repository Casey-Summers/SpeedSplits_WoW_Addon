local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("FormatTime seconds", "UX", function()
    System.Assert(NS.Util.FormatTime(12.345) == "12.345", "12.345", NS.Util.FormatTime(12.345))
end)

System.RegisterTest("FormatDelta positive", "UX", function()
    System.Assert(NS.Util.FormatDelta(2.5) == "+2.500", "+2.500", NS.Util.FormatDelta(2.5))
end)

System.RegisterTest("Pace color tie is gold", "UX", function()
    local r, g, b, hex = NS.GetPaceColor(0, false)
    System.Assert(hex == NS.Colors.gold.hex, NS.Colors.gold.hex, hex)
end)
