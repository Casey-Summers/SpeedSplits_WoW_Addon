local _, NS = ...

NS.TestUI = NS.TestUI or {}

local UI = NS.TestUI
local System = NS.TestSystem

local function GetStatusColor(status)
    if status == "PASS" then
        return "|cff00ff00"
    end
    if status == "FAIL" then
        return "|cffff4444"
    end
    if status == "RUNNING" then
        return "|cff00ccff"
    end
    if status == "INFO" then
        return "|cff00ccff"
    end
    return "|cffaaaaaa"
end

local function MatchesFilter(run)
    local filter = System.LogFilter or "ALL"
    if filter == "ALL" then
        return true
    end
    if filter == "INFO" then
        return run.status == "RUNNING"
    end
    return run.status == filter
end

local function IsVisibleRun(selectedRunId, visibleRuns)
    for _, run in ipairs(visibleRuns) do
        if run.runId == selectedRunId then
            return true
        end
    end
    return false
end

local function CreateActionButton(parent, text, y, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(180, 32)
    btn:SetPoint("TOP", 0, y)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function BuildSuiteButtons(container)
    UI.suiteButtons = UI.suiteButtons or {}

    for _, btn in ipairs(UI.suiteButtons) do
        btn:Hide()
    end

    local suiteY = -10
    for index, suite in ipairs(System.GetSuites()) do
        local btn = UI.suiteButtons[index]
        if not btn then
            btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            btn:SetSize(160, 32)
            UI.suiteButtons[index] = btn
        end

        btn:Show()
        btn:SetPoint("TOP", container, "TOP", 10, suiteY)
        btn:SetText(suite .. " Suite")
        btn:SetScript("OnClick", function()
            System.RunSuite(suite)
        end)
        suiteY = suiteY - 35
    end

    container:SetHeight(math.max(1, 10 + (#System.GetSuites() * 35)))
end

function UI.CreateTestFrame()
    if UI.frame then
        UI.frame:Show()
        UI.RefreshStatusList()
        UI.UpdateTerminal()
        return
    end

    local frame = CreateFrame("Frame", "SpeedSplitsTestFrame", UIParent, "BackdropTemplate")
    frame:SetSize(980, 620)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.95)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    UI.frame = frame

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -15)
    title:SetText("SpeedSplits Modular Test Environment")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local leftPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", 15, -50)
    leftPanel:SetPoint("BOTTOMLEFT", 15, 15)
    leftPanel:SetWidth(200)
    leftPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    leftPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    leftPanel:SetBackdropBorderColor(1, 1, 1, 0.2)

    local pinned = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    pinned:SetPoint("TOPLEFT", 0, 0)
    pinned:SetPoint("TOPRIGHT", 0, 0)
    pinned:SetHeight(155)
    pinned:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    pinned:SetBackdropColor(0.2, 0.2, 0.2, 0.4)
    pinned:SetBackdropBorderColor(1, 1, 0, 0.3)

    CreateActionButton(pinned, "|cffffff00Run All Tests|r", -10, function()
        System.RunAllTests()
    end)
    CreateActionButton(pinned, "Simulate This Instance", -45, function()
        System.LogInfo("Simulation helper: finding current instance data.", "INFO")
        NS.RunLogic.BeginInstanceSession()
    end)
    CreateActionButton(pinned, "Simulate speedrun", -80, function()
        if System.RunTestById and System.RegisteredTestsById["logic_scenario_speedrun_regression"] then
            System.RunTestById("logic_scenario_speedrun_regression")
        elseif NS.SimulateSpeedrun then
            NS.SimulateSpeedrun()
        end
    end)
    CreateActionButton(pinned, "Clear Runs", -115, function()
        System.ClearRunHistory()
    end)

    local categoryLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    categoryLabel:SetPoint("TOPLEFT", 10, -160)
    categoryLabel:SetText("|cffffff00Test Categories|r")

    local suiteScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    suiteScroll:SetPoint("TOPLEFT", 0, -180)
    suiteScroll:SetPoint("BOTTOMRIGHT", -25, 170)

    local suiteContent = CreateFrame("Frame", nil, suiteScroll)
    suiteContent:SetSize(175, 1)
    suiteScroll:SetScrollChild(suiteContent)
    UI.suiteContent = suiteContent
    BuildSuiteButtons(suiteContent)

    local statusFrame = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    statusFrame:SetPoint("TOPLEFT", 0, -395)
    statusFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    statusFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    statusFrame:SetBackdropColor(0, 0, 0, 0.3)
    statusFrame:SetBackdropBorderColor(1, 1, 1, 0.1)
    UI.statusFrame = statusFrame

    local statusText = statusFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 10, -10)
    statusText:SetPoint("BOTTOMRIGHT", -10, 10)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    UI.statusText = statusText

    local rightPanel = CreateFrame("Frame", nil, frame)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", -15, 15)

    local lastResultFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    lastResultFrame:SetPoint("TOPLEFT", 0, 0)
    lastResultFrame:SetPoint("TOPRIGHT", 0, 0)
    lastResultFrame:SetHeight(24)
    lastResultFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    lastResultFrame:SetBackdropColor(0.2, 0.2, 0.2, 0.6)
    lastResultFrame:SetBackdropBorderColor(1, 1, 1, 0.2)

    local lastResultText = lastResultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lastResultText:SetPoint("LEFT", 10, 0)
    lastResultText:SetText("|cff888888Latest Result:|r None")
    UI.lastResultText = lastResultText

    local filterLabel = lastResultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLabel:SetPoint("RIGHT", -80, 0)
    filterLabel:SetText("Filter:")

    local filterButton = CreateFrame("Button", nil, lastResultFrame, "UIPanelButtonTemplate")
    filterButton:SetSize(60, 18)
    filterButton:SetPoint("RIGHT", filterLabel, "RIGHT", 65, 0)
    filterButton:SetText(System.LogFilter or "ALL")
    UI.filterButton = filterButton

    local filters = { "ALL", "PASS", "FAIL", "INFO" }
    filterButton:SetScript("OnClick", function(self)
        local current = System.LogFilter or "ALL"
        local nextIndex = 1
        for i, value in ipairs(filters) do
            if value == current then
                nextIndex = (i % #filters) + 1
                break
            end
        end
        System.LogFilter = filters[nextIndex]
        self:SetText(System.LogFilter)
        UI.UpdateTerminal()
    end)

    local termFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    termFrame:SetPoint("TOPLEFT", lastResultFrame, "BOTTOMLEFT", 0, -5)
    termFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    termFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    termFrame:SetBackdropColor(0, 0, 0, 0.8)
    termFrame:SetBackdropBorderColor(0, 0.8, 1, 0.4)

    local leftTermFrame = CreateFrame("Frame", nil, termFrame, "BackdropTemplate")
    leftTermFrame:SetPoint("TOPLEFT", 0, 0)
    leftTermFrame:SetPoint("BOTTOMLEFT", 0, 0)
    leftTermFrame:SetWidth(310)
    leftTermFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    leftTermFrame:SetBackdropBorderColor(1, 1, 1, 0.08)

    local rightTermFrame = CreateFrame("Frame", nil, termFrame)
    rightTermFrame:SetPoint("TOPLEFT", leftTermFrame, "TOPRIGHT", 0, 0)
    rightTermFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    local leftScroll = CreateFrame("ScrollFrame", "SpeedSplitsTestTermLeftScroll", leftTermFrame,
        "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", 8, -8)
    leftScroll:SetPoint("BOTTOMRIGHT", -28, 25)

    local leftContent = CreateFrame("Frame", nil, leftScroll)
    leftContent:SetSize(280, 10)
    leftScroll:SetScrollChild(leftContent)
    UI.leftTermContent = leftContent

    local rightScroll = CreateFrame("ScrollFrame", "SpeedSplitsTestTermRightScroll", rightTermFrame,
        "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", 8, -8)
    rightScroll:SetPoint("BOTTOMRIGHT", -28, 25)

    local helpText = termFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("BOTTOMLEFT", 10, 5)
    helpText:SetText("|cff888888Hover over a test on the left to inspect its low-level detail trail.|r")

    local rightContent = CreateFrame("Frame", nil, rightScroll)
    rightContent:SetSize(480, 10)
    rightScroll:SetScrollChild(rightContent)

    local rightText = rightContent:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    rightText:SetPoint("TOPLEFT", 10, -10)
    rightText:SetWidth(450)
    rightText:SetJustifyH("LEFT")
    rightText:SetJustifyV("TOP")
    UI.rightTermText = rightText

    local rightTextEB = CreateFrame("EditBox", nil, rightContent)
    rightTextEB:SetPoint("TOPLEFT", rightText, "TOPLEFT", 0, 0)
    rightTextEB:SetPoint("BOTTOMRIGHT", rightText, "BOTTOMRIGHT", 0, 0)
    rightTextEB:SetMultiLine(true)
    rightTextEB:SetAutoFocus(false)
    rightTextEB:SetFontObject("ChatFontNormal")
    rightTextEB:SetTextColor(1, 1, 1, 0) -- Invisible text to overlay nicely
    rightTextEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    rightTextEB:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    rightTextEB:SetScript("OnChar", function() end)
    UI.rightTermEB = rightTextEB
    UI.rightTermContent = rightContent

    UI.RefreshStatusList()
    UI.UpdateTerminal()
end

function UI.RefreshStatusList()
    if not UI.statusText then
        return
    end

    local summary = System.GetSuiteSummary()
    local lines = { "|cffffff00Registered Suites|r" }
    local totalRegistered = #System.RegisteredTests
    local totalRuns = #System.RunHistory

    lines[#lines + 1] = string.format("|cffbbbbbbTests:|r %d   |cffbbbbbbRuns:|r %d", totalRegistered, totalRuns)

    for _, suite in ipairs(System.GetSuites()) do
        local bucket = summary[suite]
        if bucket then
            local suiteStatus = "PENDING"
            if bucket.fail > 0 then
                suiteStatus = "FAIL"
            elseif bucket.running > 0 then
                suiteStatus = "RUNNING"
            elseif bucket.pass > 0 and bucket.pending == 0 then
                suiteStatus = "PASS"
            end
            lines[#lines + 1] = string.format(
                "%s|r |cff888888(%d)|r  |cff00ff00P:%d|r  |cffff4444F:%d|r  |cff00ccffR:%d|r  |cffaaaaaaQ:%d|r",
                GetStatusColor(suiteStatus) .. suite,
                bucket.total,
                bucket.pass,
                bucket.fail,
                bucket.running,
                bucket.pending
            )
        end
    end

    UI.statusText:SetText(table.concat(lines, "\n"))

    if System.LastResult and UI.lastResultText then
        local color = GetStatusColor(System.LastResult.status)
        UI.lastResultText:SetText(string.format("|cffbbbbbbLatest Result:|r %s%s|r (%s%s|r)",
            color,
            System.LastResult.name,
            color,
            System.LastResult.status))
    elseif UI.lastResultText then
        UI.lastResultText:SetText("|cff888888Latest Result:|r None")
    end

    if UI.suiteContent then
        BuildSuiteButtons(UI.suiteContent)
    end
end

function UI.HighlightSelectedRun()
    if not UI.leftRunPool then
        return
    end

    for _, row in ipairs(UI.leftRunPool) do
        if row:IsShown() and row.runId == UI.SelectedRunId then
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            row:SetBackdropColor(1, 1, 1, 0.08)
            row:SetBackdropBorderColor(1, 1, 1, 0.12)
        else
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            row:SetBackdropColor(0, 0, 0, 0.25)
            row:SetBackdropBorderColor(1, 1, 1, 0.04)
        end
    end
end

function UI.GetRunRow(index)
    UI.leftRunPool = UI.leftRunPool or {}
    if not UI.leftRunPool[index] then
        local row = CreateFrame("Button", nil, UI.leftTermContent, "BackdropTemplate")
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameText:SetPoint("TOPLEFT", 8, -6)
        row.nameText:SetPoint("TOPRIGHT", -8, -6)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetJustifyV("TOP")

        row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.statusText:SetPoint("BOTTOMLEFT", 8, 6)
        row.statusText:SetPoint("BOTTOMRIGHT", -8, 6)
        row.statusText:SetJustifyH("LEFT")
        row.statusText:SetJustifyV("BOTTOM")

        UI.leftRunPool[index] = row
    end

    return UI.leftRunPool[index]
end

function UI.UpdateTerminal()
    if not UI.leftTermContent then
        return
    end

    if UI.leftRunPool then
        for _, row in ipairs(UI.leftRunPool) do
            row:Hide()
        end
    end

    local visibleRuns = {}
    for _, run in ipairs(System.GetRunHistory()) do
        if MatchesFilter(run) then
            visibleRuns[#visibleRuns + 1] = run
        end
    end

    for index, run in ipairs(visibleRuns) do
        local row = UI.GetRunRow(index)
        row:Show()
        row.runId = run.runId
        row:SetSize(280, 44)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * 48))

        row.nameText:SetText(string.format("|cff999999[%s]|r %s", run.suite, run.name))
        row.statusText:SetText(string.format("%s%s|r", GetStatusColor(run.status), run.status))

        row:SetScript("OnEnter", function(self)
            UI.SelectedRunId = self.runId
            UI.UpdateDetails()
            UI.HighlightSelectedRun()
        end)
        row:SetScript("OnClick", function(self)
            UI.SelectedRunId = self.runId
            UI.UpdateDetails()
            UI.HighlightSelectedRun()
        end)
    end

    UI.leftTermContent:SetHeight(math.max(48, (#visibleRuns * 48) + 10))

    if #visibleRuns == 0 then
        UI.SelectedRunId = nil
    elseif not UI.SelectedRunId or not IsVisibleRun(UI.SelectedRunId, visibleRuns) then
        UI.SelectedRunId = visibleRuns[#visibleRuns].runId
    end

    UI.HighlightSelectedRun()
    UI.UpdateDetails()

    local scroll = _G["SpeedSplitsTestTermLeftScroll"]
    if scroll then
        C_Timer.After(0.05, function()
            scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
        end)
    end
end

function UI.UpdateDetails()
    if not UI.rightTermText then
        return
    end

    local run = UI.SelectedRunId and System.GetSelectedOrLastRun(UI.SelectedRunId) or nil
    if not run then
        if System.SessionMessages and #System.SessionMessages > 0 then
            local lines = { "|cffffff00Session Messages|r" }
            for _, message in ipairs(System.SessionMessages) do
                lines[#lines + 1] = string.format("%s%s|r", GetStatusColor(message.status), message.message)
            end
            UI.rightTermText:SetText(table.concat(lines, "\n"))
            if UI.rightTermEB then UI.rightTermEB:SetText("") end
        elseif #System.RunHistory > 0 then
            UI.rightTermText:SetText("|cff888888No test runs match the current filter.|r")
            if UI.rightTermEB then UI.rightTermEB:SetText("") end
        else
            UI.rightTermText:SetText("|cff888888No executed tests yet. Run a suite or hover a test row once one exists.|r")
            if UI.rightTermEB then UI.rightTermEB:SetText("") end
        end
        UI.rightTermContent:SetHeight(UI.rightTermText:GetStringHeight() + 20)
        return
    end

    local lines = {
        string.format("|cffffff00%s|r", run.name),
        string.format("|cffbbbbbbSuite:|r %s   |cffbbbbbbSubcategory:|r %s   |cffbbbbbbStatus:|r %s%s|r",
            run.suite,
            run.subcategory or "General",
            GetStatusColor(run.status),
            run.status),
    }

    local details = System.GetRunDetails(run.runId)
    if #details == 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cff888888No low-level details were recorded for this run.|r"
    else
        for _, detail in ipairs(details) do
            local color = GetStatusColor(detail.status)
            if detail.kind == "section_start" then
                lines[#lines + 1] = ""
                lines[#lines + 1] = string.format("|cffffff00Section: %s|r", detail.label or detail.message or "Unnamed")
            elseif detail.kind == "section_end" then
                lines[#lines + 1] = string.format("|cff666666End Section: %s|r", detail.label or detail.message or "Unnamed")
            elseif detail.kind == "assertion" then
                lines[#lines + 1] = string.format("%s[%s]|r %s", color, detail.status, detail.label or detail.message or "Assertion")
                lines[#lines + 1] = string.format("  |cffbbbbbbExpected:|r %s", detail.expected or "nil")
                lines[#lines + 1] = string.format("  |cffbbbbbbActual:|r %s", detail.actual or "nil")
            else
                lines[#lines + 1] = string.format("%s[%s]|r %s", color, detail.status or "INFO", detail.message or "")
            end
        end
    end

    UI.rightTermText:SetText(table.concat(lines, "\n"))
    
    if UI.rightTermEB then
        local rawLines = {}
        for _, line in ipairs(lines) do
            rawLines[#rawLines + 1] = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        end
        UI.rightTermEB:SetText(table.concat(rawLines, "\n"))
    end
    
    UI.rightTermContent:SetHeight(UI.rightTermText:GetStringHeight() + 20)
end
