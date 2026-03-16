local _, NS = ...

NS.Tests = NS.Tests or {}

-- Keep test-only globals behind NS.Tests so the normal addon runtime only sees a
-- single, explicit test surface when /ss test is available.
function NS.Tests.Open()
    if NS.TestUI and NS.TestUI.CreateTestFrame then
        NS.TestUI.CreateTestFrame()
    end
end

function NS.Tests.RegisterSuite(name, suite, func)
    if NS.TestSystem and NS.TestSystem.RegisterTest then
        NS.TestSystem.RegisterTest(name, suite, func)
    end
end

function NS.Tests.RunAll()
    if NS.TestSystem and NS.TestSystem.RunAllTests then
        NS.TestSystem.RunAllTests()
    end
end

NS.Tests.Simulation = NS.Tests.Simulation or {}
NS.Tests.Simulation.SimulateSpeedrun = function()
    if NS.SimulateSpeedrun then
        NS.SimulateSpeedrun()
    end
end
