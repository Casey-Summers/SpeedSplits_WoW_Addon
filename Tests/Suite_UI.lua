local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("EnsureUI creates main frames", "UI", function()
    NS.Database.EnsureDB()
    NS.UI.EnsureUI()
    System.Assert(NS.UI.timerFrame ~= nil, true, NS.UI.timerFrame ~= nil)
    System.Assert(NS.UI.bossFrame ~= nil, true, NS.UI.bossFrame ~= nil)
end)

System.RegisterTest("SetTotals updates footer text", "UI", function()
    NS.Database.EnsureDB()
    NS.UI.EnsureUI()
    NS.SetTotals(10, 12, 2, 1, 1, 1, "|cffffffff")
    System.Assert(NS.UI.totalPB:GetText() == "10.000", "10.000", NS.UI.totalPB:GetText())
end)
