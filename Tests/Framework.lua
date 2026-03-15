local _, NS = ...

NS.TestSystem = {
    Tests = {},
    Logs = {},
    TestLogs = {},
    Results = {}, -- [name] = "PASS" | "FAIL" | "PENDING"
}

local System = NS.TestSystem

function System.RegisterTest(name, suite, func)
    table.insert(System.Tests, { name = name, suite = suite, func = func })
    System.Results[name] = "PENDING"
end

System.LogFilter = "ALL" -- ALL, PASS, FAIL, INFO

function System.Log(msg, status)
    table.insert(System.Logs, {
        msg = msg,
        status = status or "NONE",
        testName = System.ActiveTest
    })

    if NS.TestUI and NS.TestUI.UpdateTerminal then
        NS.TestUI.UpdateTerminal()
    end
end

function System.LogDetail(testName, msg, status)
    if not testName then return end
    System.TestLogs[testName] = System.TestLogs[testName] or {}
    table.insert(System.TestLogs[testName], {
        msg = msg,
        status = status or "NONE"
    })

    if NS.TestUI and NS.TestUI.UpdateDetails then
        NS.TestUI.UpdateDetails()
    end
end

function System.Assert(condition, expectedMsg, actualMsg)
    if not System.ActiveTest then return condition end
    if condition then
        System.LogDetail(System.ActiveTest,
            "OK: Expected " .. tostring(expectedMsg) .. ", Actual: " .. tostring(actualMsg), "PASS")
    else
        local err = "FAILED: Expected " .. tostring(expectedMsg) .. ", got: " .. tostring(actualMsg)
        -- error is thrown so it stops the test and logs it
        error(err, 2)
    end
    return condition
end

function System.RunTest(testIndex)
    local test = System.Tests[testIndex]
    if not test then return end

    System.ActiveTest = test.name
    System.TestLogs[test.name] = {} -- clear previous detail logs
    System.Log("Running test: " .. test.name, "INFO")
    System.LogDetail(test.name, "Starting test...", "INFO")

    local ok, err = pcall(test.func)
    if ok then
        System.Results[test.name] = "PASS"
        System.Log("PASS: " .. test.name, "PASS")
        System.LogDetail(test.name, "Test completed successfully.", "PASS")
    else
        System.Results[test.name] = "FAIL"
        System.Log("FAIL: " .. test.name .. " - " .. tostring(err), "FAIL")
        System.LogDetail(test.name, "Error: " .. tostring(err), "FAIL")
    end

    System.ActiveTest = nil
    System.LastResult = { name = test.name, status = System.Results[test.name] }

    if NS.TestUI and NS.TestUI.RefreshStatusList then
        NS.TestUI.RefreshStatusList()
    end
    if NS.TestUI and NS.TestUI.UpdateTerminal then
        NS.TestUI.UpdateTerminal()
    end
end

function System.RunAllTests()
    System.Log("=== Starting All Tests ===", "INFO")
    for i = 1, #System.Tests do
        System.RunTest(i)
    end
    System.Log("=== Testing Complete ===", "INFO")
end
