local _, NS = ...

NS.TestSystem = NS.TestSystem or {}

local System = NS.TestSystem

local function Now()
    if GetTimePreciseSec then
        return GetTimePreciseSec()
    end
    return GetTime and GetTime() or 0
end

local function SafeToString(value)
    if type(value) == "table" then
        local ok, text = pcall(function()
            return tostring(value)
        end)
        return ok and text or "<table>"
    end
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function NormalizeToken(value)
    local text = tostring(value or ""):lower()
    text = text:gsub("[^%w]+", "_")
    text = text:gsub("^_+", "")
    text = text:gsub("_+$", "")
    if text == "" then
        return "test"
    end
    return text
end

local function MakeTestId(suite, name)
    return NormalizeToken(suite) .. "_" .. NormalizeToken(name)
end

local function NotifyStatus()
    if NS.TestUI and NS.TestUI.RefreshStatusList then
        NS.TestUI.RefreshStatusList()
    end
end

local function NotifyRuns()
    if NS.TestUI and NS.TestUI.UpdateTerminal then
        NS.TestUI.UpdateTerminal()
    end
end

local function NotifyDetails()
    if NS.TestUI and NS.TestUI.UpdateDetails then
        NS.TestUI.UpdateDetails()
    end
end

local function EnsureState()
    System.RegisteredTests = System.RegisteredTests or {}
    System.RegisteredTestsById = System.RegisteredTestsById or {}
    System.ResultsByTest = System.ResultsByTest or {}
    System.RunHistory = System.RunHistory or {}
    System.DetailsByRunId = System.DetailsByRunId or {}
    System.LatestRunByTestId = System.LatestRunByTestId or {}
    System.SessionMessages = System.SessionMessages or {}
    System.SuiteOrder = System.SuiteOrder or { "UI", "Discovery", "Logic", "PB", "History", "UX" }
    System.LogFilter = System.LogFilter or "ALL"
    System.NextRunId = System.NextRunId or 0

    -- Compatibility aliases for older code paths.
    System.Tests = System.RegisteredTests
    System.Results = System.ResultsByTest
    System.Logs = System.RunHistory
    System.TestLogs = System.DetailsByRunId
end

EnsureState()

local function GetTestByNameOrId(nameOrId)
    EnsureState()
    if not nameOrId then
        return nil
    end

    if System.RegisteredTestsById[nameOrId] then
        return System.RegisteredTestsById[nameOrId]
    end

    for _, test in ipairs(System.RegisteredTests) do
        if test.name == nameOrId then
            return test
        end
    end

    return nil
end

local function GetRunById(runId)
    if not runId then
        return nil
    end
    for _, run in ipairs(System.RunHistory) do
        if run.runId == runId then
            return run
        end
    end
    return nil
end

local function AddDetail(runId, entry)
    if not runId then
        return nil
    end

    System.DetailsByRunId[runId] = System.DetailsByRunId[runId] or {}
    entry.sequence = #System.DetailsByRunId[runId] + 1
    entry.timestamp = Now()
    table.insert(System.DetailsByRunId[runId], entry)
    NotifyDetails()
    return entry
end

local function AddSessionMessage(message, status)
    table.insert(System.SessionMessages, {
        message = SafeToString(message),
        status = status or "INFO",
        timestamp = Now(),
    })
    NotifyDetails()
end

local function RecordFailure(label, expected, actual)
    AddDetail(System.ActiveRunId, {
        kind = "assertion",
        status = "FAIL",
        label = label or "Assertion failed",
        expected = SafeToString(expected),
        actual = SafeToString(actual),
        message = label or "Assertion failed",
    })
    error(string.format("%s | expected=%s | actual=%s",
        SafeToString(label or "Assertion failed"),
        SafeToString(expected),
        SafeToString(actual)), 2)
end

function System.RegisterTest(nameOrDef, suite, func)
    EnsureState()

    local test
    if type(nameOrDef) == "table" then
        test = {
            id = nameOrDef.id,
            suite = nameOrDef.suite,
            subcategory = nameOrDef.subcategory,
            name = nameOrDef.name,
            func = nameOrDef.func,
        }
    else
        test = {
            name = nameOrDef,
            suite = suite,
            func = func,
        }
    end

    test.suite = tostring(test.suite or "Misc")
    test.subcategory = tostring(test.subcategory or "General")
    test.name = tostring(test.name or "Unnamed Test")
    test.id = tostring(test.id or MakeTestId(test.suite, test.name))

    if type(test.func) ~= "function" then
        error("RegisterTest requires a function for test '" .. test.name .. "'", 2)
    end

    local existing = System.RegisteredTestsById[test.id]
    if existing then
        existing.suite = test.suite
        existing.subcategory = test.subcategory
        existing.name = test.name
        existing.func = test.func
    else
        table.insert(System.RegisteredTests, test)
        System.RegisteredTestsById[test.id] = test
    end

    System.ResultsByTest[test.id] = System.ResultsByTest[test.id] or "PENDING"
    return test.id
end

function System.GetSuites()
    EnsureState()

    local seen = {}
    local ordered = {}

    for _, suite in ipairs(System.SuiteOrder) do
        for _, test in ipairs(System.RegisteredTests) do
            if test.suite == suite and not seen[suite] then
                seen[suite] = true
                ordered[#ordered + 1] = suite
                break
            end
        end
    end

    for _, test in ipairs(System.RegisteredTests) do
        if not seen[test.suite] then
            seen[test.suite] = true
            ordered[#ordered + 1] = test.suite
        end
    end

    return ordered
end

function System.GetSuiteSummary()
    EnsureState()

    local summary = {}
    for _, suite in ipairs(System.GetSuites()) do
        summary[suite] = {
            total = 0,
            pass = 0,
            fail = 0,
            pending = 0,
            running = 0,
        }
    end

    for _, test in ipairs(System.RegisteredTests) do
        local bucket = summary[test.suite]
        if bucket then
            bucket.total = bucket.total + 1
            local status = System.ResultsByTest[test.id] or "PENDING"
            if status == "PASS" then
                bucket.pass = bucket.pass + 1
            elseif status == "FAIL" then
                bucket.fail = bucket.fail + 1
            elseif status == "RUNNING" then
                bucket.running = bucket.running + 1
            else
                bucket.pending = bucket.pending + 1
            end
        end
    end

    return summary
end

function System.GetLastRun()
    return System.RunHistory[#System.RunHistory]
end

function System.GetRunHistory()
    return System.RunHistory
end

function System.GetRunDetails(runId)
    return System.DetailsByRunId[runId] or {}
end

function System.GetSelectedOrLastRun(selectedRunId)
    return GetRunById(selectedRunId) or System.GetLastRun()
end

function System.BeginTestRun(test)
    EnsureState()

    System.NextRunId = System.NextRunId + 1
    local run = {
        runId = System.NextRunId,
        testId = test.id,
        suite = test.suite,
        subcategory = test.subcategory,
        name = test.name,
        status = "RUNNING",
        startedAt = Now(),
    }

    table.insert(System.RunHistory, run)
    System.DetailsByRunId[run.runId] = {}
    System.LatestRunByTestId[test.id] = run.runId
    System.ResultsByTest[test.id] = "RUNNING"
    System.ActiveRunId = run.runId
    System.ActiveTestId = test.id
    System.ActiveTest = test.name
    System.LastResult = { name = test.name, suite = test.suite, status = "RUNNING", runId = run.runId }

    AddDetail(run.runId, {
        kind = "info",
        status = "INFO",
        message = "Test run started.",
    })

    NotifyStatus()
    NotifyRuns()
    return run
end

function System.EndTestRun(status, summary)
    local run = GetRunById(System.ActiveRunId)
    if not run then
        return nil
    end

    run.status = status or "PASS"
    run.finishedAt = Now()
    run.duration = math.max(0, (run.finishedAt or run.startedAt) - (run.startedAt or 0))
    run.summary = summary or run.summary

    System.ResultsByTest[run.testId] = run.status
    System.LastResult = {
        name = run.name,
        suite = run.suite,
        status = run.status,
        runId = run.runId,
    }

    if run.status == "PASS" then
        AddDetail(run.runId, {
            kind = "result",
            status = "PASS",
            message = summary or "Test completed successfully.",
        })
    elseif run.status == "FAIL" then
        AddDetail(run.runId, {
            kind = "result",
            status = "FAIL",
            message = summary or "Test failed.",
        })
    end

    System.ActiveRunId = nil
    System.ActiveTestId = nil
    System.ActiveTest = nil

    NotifyStatus()
    NotifyRuns()
    NotifyDetails()
    return run
end

function System.LogInfo(message, status)
    local runId = System.ActiveRunId
    if not runId then
        AddSessionMessage(message, status or "INFO")
        return
    end

    AddDetail(runId, {
        kind = "info",
        status = status or "INFO",
        message = SafeToString(message),
    })
end

function System.BeginSection(label)
    AddDetail(System.ActiveRunId, {
        kind = "section_start",
        status = "INFO",
        label = SafeToString(label),
        message = SafeToString(label),
    })
end

function System.EndSection(label, status)
    AddDetail(System.ActiveRunId, {
        kind = "section_end",
        status = status or "INFO",
        label = SafeToString(label),
        message = SafeToString(label),
    })
end

function System.AssertEqual(actual, expected, label)
    local success = (actual == expected)
    if success then
        AddDetail(System.ActiveRunId, {
            kind = "assertion",
            status = "PASS",
            label = label or "AssertEqual",
            expected = SafeToString(expected),
            actual = SafeToString(actual),
            message = label or "AssertEqual",
        })
    else
        RecordFailure(label or "AssertEqual", expected, actual)
    end
    return true
end

function System.AssertNear(actual, expected, tolerance, label)
    tolerance = tonumber(tolerance) or 0.001
    local delta = math.abs((tonumber(actual) or 0) - (tonumber(expected) or 0))
    local success = delta <= tolerance
    if success then
        AddDetail(System.ActiveRunId, {
            kind = "assertion",
            status = "PASS",
            label = label or "AssertNear",
            expected = string.format("%s (+/-%s)", SafeToString(expected), SafeToString(tolerance)),
            actual = SafeToString(actual),
            message = label or "AssertNear",
        })
    else
        RecordFailure(label or "AssertNear", SafeToString(expected) .. " (+/-" .. SafeToString(tolerance) .. ")", actual)
    end
    return true
end

function System.AssertTrue(condition, label, actual)
    local success = condition and true or false
    if success then
        AddDetail(System.ActiveRunId, {
            kind = "assertion",
            status = "PASS",
            label = label or "AssertTrue",
            expected = "true",
            actual = SafeToString(actual == nil and condition or actual),
            message = label or "AssertTrue",
        })
    else
        RecordFailure(label or "AssertTrue", true, actual == nil and condition or actual)
    end
    return true
end

function System.Fail(label, expected, actual)
    RecordFailure(label or "Fail", expected, actual)
end

function System.WithCleanup(body, cleanup)
    local ok, err = xpcall(body, function(message)
        return message
    end)

    if cleanup then
        local cleanupOk, cleanupErr = pcall(cleanup)
        if not cleanupOk then
            AddDetail(System.ActiveRunId, {
                kind = "cleanup",
                status = "FAIL",
                message = "Cleanup failed: " .. SafeToString(cleanupErr),
            })
            error(SafeToString(cleanupErr), 0)
        end
    end

    if not ok then
        error(err, 0)
    end
end

function System.Log(message, status)
    System.LogInfo(message, status)
end

function System.LogDetail(testName, message, status)
    local test = GetTestByNameOrId(testName)
    local runId = System.ActiveRunId
    if test and System.LatestRunByTestId[test.id] then
        runId = System.LatestRunByTestId[test.id]
    end

    if not runId then
        AddSessionMessage(message, status or "INFO")
        return
    end

    AddDetail(runId, {
        kind = "info",
        status = status or "INFO",
        message = SafeToString(message),
    })
end

function System.Assert(condition, expectedMsg, actualMsg)
    if condition then
        AddDetail(System.ActiveRunId, {
            kind = "assertion",
            status = "PASS",
            label = "Assert",
            expected = SafeToString(expectedMsg),
            actual = SafeToString(actualMsg),
            message = "Assert",
        })
        return true
    end
    RecordFailure("Assert", expectedMsg, actualMsg)
end

function System.RunTest(testRef)
    EnsureState()

    local test
    if type(testRef) == "number" then
        test = System.RegisteredTests[testRef]
    else
        test = GetTestByNameOrId(testRef)
    end
    if not test then
        AddSessionMessage("Test not found: " .. SafeToString(testRef), "FAIL")
        return nil
    end

    local run = System.BeginTestRun(test)
    local ok, err = pcall(test.func)
    if ok then
        System.EndTestRun("PASS", "Test completed successfully.")
    else
        AddDetail(run.runId, {
            kind = "error",
            status = "FAIL",
            message = SafeToString(err),
        })
        System.EndTestRun("FAIL", SafeToString(err))
    end

    return run.runId
end

function System.RunTestById(testId)
    return System.RunTest(testId)
end

function System.RunSuite(suite)
    local ranAny = false
    for _, test in ipairs(System.RegisteredTests) do
        if test.suite == suite then
            ranAny = true
            System.RunTest(test.id)
        end
    end

    if not ranAny then
        AddSessionMessage("No tests are registered for suite: " .. SafeToString(suite), "INFO")
    end
end

function System.RunAllTests()
    if #System.RegisteredTests == 0 then
        AddSessionMessage("No tests are currently registered.", "INFO")
        return
    end

    for _, test in ipairs(System.RegisteredTests) do
        System.RunTest(test.id)
    end
end

function System.ClearRunHistory()
    System.RunHistory = {}
    System.DetailsByRunId = {}
    System.LatestRunByTestId = {}
    System.SessionMessages = {}
    System.LastResult = nil
    System.ActiveRunId = nil
    System.ActiveTestId = nil
    System.ActiveTest = nil

    for _, test in ipairs(System.RegisteredTests) do
        System.ResultsByTest[test.id] = "PENDING"
    end

    System.Tests = System.RegisteredTests
    System.Results = System.ResultsByTest
    System.Logs = System.RunHistory
    System.TestLogs = System.DetailsByRunId

    NotifyStatus()
    NotifyRuns()
    NotifyDetails()
end
