local _, NS = ...
NS.TestUI = {}
local UI = NS.TestUI
local System = NS.TestSystem

function UI.CreateTestFrame()
    if UI.frame then
        UI.frame:Show()
        UI.RefreshStatusList() -- Update status list in case new results came in
        return
    end

    local f = CreateFrame("Frame", "SpeedSplitsTestFrame", UIParent, "BackdropTemplate")
    f:SetSize(850, 550) -- Slightly larger to accommodate two columns
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.frame = f

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -15)
    title:SetText("SpeedSplits Modular Test Environment")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- Left Panel: Actions
    local leftPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
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

    local function CreateActionBtn(parent, text, y, func, colorType)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(180, 32)
        btn:SetPoint("TOP", 0, y)
        btn:SetText(text)
        btn:SetScript("OnClick", func)
        return btn
    end

    -- Pinned Section at top of Left Panel
    local PinnedSection = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    PinnedSection:SetPoint("TOPLEFT", 0, 0)
    PinnedSection:SetPoint("TOPRIGHT", 0, 0)
    PinnedSection:SetHeight(155)
    PinnedSection:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    PinnedSection:SetBackdropColor(0.2, 0.2, 0.2, 0.4)
    PinnedSection:SetBackdropBorderColor(1, 1, 0, 0.3) -- Yellow border for pinned

    CreateActionBtn(PinnedSection, "|cffffff00Run All Tests|r", -10, function() System.RunAllTests() end)
    CreateActionBtn(PinnedSection, "Simulate This Instance", -45, function()
        System.Log("SIMULATION START: Finding current instance data...", "INFO")
        NS.BeginInstanceSession()
    end)
    CreateActionBtn(PinnedSection, "Simulate speedrun", -80, function()
        if NS.SimulateSpeedrun then NS.SimulateSpeedrun() end
    end)
    CreateActionBtn(PinnedSection, "Clear Logs", -115, function()
        System.Logs = {}
        UI.UpdateTerminal()
    end)

    -- Dynamic Suites Section
    local suiteScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    suiteScroll:SetPoint("TOPLEFT", 0, -165)
    suiteScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local suiteContent = CreateFrame("Frame", nil, suiteScroll)
    suiteContent:SetSize(175, 500) -- Set proper width for centering
    suiteScroll:SetScrollChild(suiteContent)

    local suiteY = -10
    local suites = { "UI", "Discovery", "Logic", "PB", "History", "UX" }
    for _, s in ipairs(suites) do
        local btn = CreateFrame("Button", nil, suiteContent, "UIPanelButtonTemplate")
        btn:SetSize(160, 32)
        btn:SetPoint("TOP", suiteContent, "TOP", 10, suiteY)
        btn:SetText(s .. " Suite")
        btn:SetScript("OnClick", function()
            System.Log("Running Suite: " .. s, "INFO")
            for i, t in ipairs(System.Tests) do
                if t.suite == s then System.RunTest(i) end
            end
        end)
        suiteY = suiteY - 35
    end

    -- Right Panel: Terminal & Status
    local rightPanel = CreateFrame("Frame", nil, f)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", -15, 15)

    -- Status Widget (Top of right panel)
    local statusFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    statusFrame:SetPoint("TOPLEFT", 0, 0)
    statusFrame:SetPoint("TOPRIGHT", 0, 0)
    statusFrame:SetHeight(180) -- Slightly taller for 2 columns
    statusFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    statusFrame:SetBackdropColor(0, 0, 0, 0.3)
    statusFrame:SetBackdropBorderColor(1, 1, 1, 0.1)
    UI.statusFrame = statusFrame

    local statusScroll = CreateFrame("ScrollFrame", "SpeedSplitsTestStatusScroll", statusFrame,
        "UIPanelScrollFrameTemplate")
    statusScroll:SetPoint("TOPLEFT", 5, -5)
    statusScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local statusContent = CreateFrame("Frame", nil, statusScroll)
    statusContent:SetSize(1, 1)
    statusScroll:SetScrollChild(statusContent)
    UI.statusContent = statusContent

    -- Latest Result Widget (Single line between status and terminal)
    local lastResultFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    lastResultFrame:SetPoint("TOPLEFT", statusFrame, "BOTTOMLEFT", 0, -5)
    lastResultFrame:SetPoint("TOPRIGHT", statusFrame, "BOTTOMRIGHT", 0, -5)
    lastResultFrame:SetHeight(24)
    lastResultFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    lastResultFrame:SetBackdropColor(0.2, 0.2, 0.2, 0.6)
    lastResultFrame:SetBackdropBorderColor(1, 1, 1, 0.2)
    UI.lastResultFrame = lastResultFrame

    local lastResultText = lastResultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lastResultText:SetPoint("LEFT", 10, 0)
    lastResultText:SetText("|cff888888Latest Result:|r None")
    UI.lastResultText = lastResultText

    local dropdownLabel = lastResultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdownLabel:SetPoint("RIGHT", -80, 0)
    dropdownLabel:SetText("Filter:")

    local cycleFilterBtn = CreateFrame("Button", nil, lastResultFrame, "UIPanelButtonTemplate")
    cycleFilterBtn:SetSize(60, 18)
    cycleFilterBtn:SetPoint("RIGHT", dropdownLabel, "RIGHT", 65, 0)
    cycleFilterBtn:SetText("ALL")
    
    local filters = { "ALL", "PASS", "FAIL", "INFO" }
    cycleFilterBtn:SetScript("OnClick", function()
        local current = System.LogFilter
        local nextIdx = 1
        for i, f in ipairs(filters) do
            if f == current then nextIdx = (i % 4) + 1 break end
        end
        System.LogFilter = filters[nextIdx]
        cycleFilterBtn:SetText(System.LogFilter)
        UI.UpdateTerminal()
    end)

    -- Terminal (Bottom of right panel)
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

    -- Divide the remaining space into two columns
    local leftTermFrame = CreateFrame("Frame", nil, termFrame)
    leftTermFrame:SetPoint("TOPLEFT", 0, 0)
    leftTermFrame:SetPoint("BOTTOMLEFT", 0, 0)
    leftTermFrame:SetWidth(280)

    local rightTermFrame = CreateFrame("Frame", nil, termFrame)
    rightTermFrame:SetPoint("TOPLEFT", leftTermFrame, "TOPRIGHT", 0, 0)
    rightTermFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    
    -- Left Scroll (High-level logs)
    local leftTermScroll = CreateFrame("ScrollFrame", "SpeedSplitsTestTermLeftScroll", leftTermFrame, "UIPanelScrollFrameTemplate")
    leftTermScroll:SetPoint("TOPLEFT", 8, -8)
    leftTermScroll:SetPoint("BOTTOMRIGHT", -28, 25)

    local leftTermContent = CreateFrame("Frame", nil, leftTermScroll)
    leftTermContent:SetSize(250, 10)
    leftTermScroll:SetScrollChild(leftTermContent)
    UI.leftTermContent = leftTermContent

    -- Right Scroll (Low-level details)
    local rightTermScroll = CreateFrame("ScrollFrame", "SpeedSplitsTestTermRightScroll", rightTermFrame, "UIPanelScrollFrameTemplate")
    rightTermScroll:SetPoint("TOPLEFT", 8, -8)
    rightTermScroll:SetPoint("BOTTOMRIGHT", -28, 25)

    local termHelp = termFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    termHelp:SetPoint("BOTTOMLEFT", 10, 5)
    termHelp:SetText("|cff888888Hover over a section on the left to see low-level test assertions here.|r")

    local rightTermContent = CreateFrame("Frame", nil, rightTermScroll)
    rightTermContent:SetSize(280, 10)
    rightTermScroll:SetScrollChild(rightTermContent)

    local rightTermText = rightTermContent:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    rightTermText:SetPoint("TOPLEFT", 10, -10)
    rightTermText:SetWidth(260)
    rightTermText:SetJustifyH("LEFT")
    rightTermText:SetJustifyV("TOP")
    UI.rightTermText = rightTermText
    UI.rightTermContent = rightTermContent

    UI.RefreshStatusList()
    UI.UpdateTerminal()
end

function UI.RefreshStatusList()
    if not UI.statusContent then return end

    -- Clear old children
    local children = { UI.statusContent:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Sort tests so FAILs are first
    local sortedTests = {}
    for i, t in ipairs(System.Tests) do sortedTests[i] = t end
    table.sort(sortedTests, function(a, b)
        local resA = System.Results[a.name] or "PENDING"
        local resB = System.Results[b.name] or "PENDING"
        if resA == "FAIL" and resB ~= "FAIL" then return true end
        if resB == "FAIL" and resA ~= "FAIL" then return false end
        return false -- Stable-ish
    end)

    local colWidth = 280
    local rowHeight = 22
    for i, test in ipairs(sortedTests) do
        local col = (i - 1) % 2
        local rowIdx = math.floor((i - 1) / 2)

        local row = CreateFrame("Frame", nil, UI.statusContent)
        row:SetSize(colWidth, rowHeight)
        row:SetPoint("TOPLEFT", col * colWidth, -(rowIdx * rowHeight))

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("LEFT", 5, 0)
        name:SetWidth(colWidth - 80)
        name:SetJustifyH("LEFT")
        name:SetText(string.format("|cff999999[%s]|r %s", test.suite:sub(1, 1), test.name))

        local status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("RIGHT", -5, 0)

        local res = System.Results[test.name] or "PENDING"
        local color = "|cff888888"
        if res == "PASS" then
            color = "|cff00ff00"
        elseif res == "FAIL" then
            color = "|cffff0000"
        end
        status:SetText(color .. res .. "|r")
    end

    local totalRows = math.ceil(#System.Tests / 2)
    UI.statusContent:SetHeight(totalRows * rowHeight + 10)

    -- Update Latest Result Widget
    if System.LastResult and UI.lastResultText then
        local color = (System.LastResult.status == "PASS") and "|cff00ff00" or "|cffff0000"
        UI.lastResultText:SetText(string.format("|cffbbbbbbLatest Result:|r %s (%s%s|r)", 
            System.LastResult.name, color, System.LastResult.status))
    end
end

function UI.HighlightSelectedLogBtn()
    if not UI.leftLogPool then return end
    for _, btn in ipairs(UI.leftLogPool) do
        if btn:IsShown() and btn.testName and btn.testName == UI.SelectedDetailTest then
            btn:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
            btn:SetBackdropColor(1,1,1,0.1)
        else
            btn:SetBackdrop(nil)
        end
    end
end

function UI.GetLeftLogBtn(index)
    UI.leftLogPool = UI.leftLogPool or {}
    if not UI.leftLogPool[index] then
        local btn = CreateFrame("Button", nil, UI.leftTermContent, "BackdropTemplate")
        btn.text = btn:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
        btn.text:SetPoint("LEFT", 5, 0)
        UI.leftLogPool[index] = btn
    end
    return UI.leftLogPool[index]
end

function UI.UpdateTerminal()
    if not UI.leftTermContent then return end
    
    -- Hide all pooled buttons
    if UI.leftLogPool then
        for _, btn in ipairs(UI.leftLogPool) do
            btn:Hide()
        end
    end

    local drawnCount = 0
    local lastValidTestName = nil

    for _, log in ipairs(System.Logs) do
        if System.LogFilter == "ALL" or log.status == System.LogFilter or log.status == "NONE" then
            local color = "|cffffffff"
            if log.status == "PASS" then color = "|cff00ff00"
            elseif log.status == "FAIL" then color = "|cffff0000"
            elseif log.status == "INFO" then color = "|cff00ccff"
            end

            drawnCount = drawnCount + 1
            local btn = UI.GetLeftLogBtn(drawnCount)
            btn:Show()
            btn:SetSize(250, 20)
            btn:SetPoint("TOPLEFT", 0, -((drawnCount - 1) * 22))
            
            btn.text:SetText(string.format("%s%s|r", color, log.msg))
            btn.testName = log.testName
            
            btn:SetScript("OnEnter", function(self)
                if self.testName then
                    UI.SelectedDetailTest = self.testName
                    UI.UpdateDetails()
                    UI.HighlightSelectedLogBtn()
                end
            end)
            btn:SetScript("OnLeave", nil)
            
            if log.testName then lastValidTestName = log.testName end
        end
    end

    UI.leftTermContent:SetHeight(drawnCount * 22 + 10)
    
    if lastValidTestName then
        UI.SelectedDetailTest = lastValidTestName
        UI.UpdateDetails()
        UI.HighlightSelectedLogBtn()
    end

    -- Auto scroll to bottom
    local scroll = _G["SpeedSplitsTestTermLeftScroll"]
    if scroll then
        C_Timer.After(0.1, function()
            scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
        end)
    end
end

function UI.UpdateDetails()
    if not UI.rightTermText then return end
    local currentTest = UI.SelectedDetailTest
    if not currentTest or not System.TestLogs[currentTest] then
        UI.rightTermText:SetText("|cff888888No details available for this log.|r")
        if UI.rightTermContent then UI.rightTermContent:SetHeight(UI.rightTermText:GetStringHeight() + 20) end
        return
    end

    local lines = { "|cffffff00" .. currentTest .. " Details:|r" }
    for _, log in ipairs(System.TestLogs[currentTest]) do
        local color = "|cffffffff"
        if log.status == "PASS" then color = "|cff00ff00"
        elseif log.status == "FAIL" then color = "|cffff0000"
        elseif log.status == "INFO" then color = "|cff00ccff"
        end
        table.insert(lines, string.format("  - %s%s|r", color, log.msg))
    end
    
    local content = table.concat(lines, "\n")
    local old = UI.rightTermText:GetText()
    if content ~= old then UI.rightTermText:SetText(content) end
    if UI.rightTermContent then UI.rightTermContent:SetHeight(UI.rightTermText:GetStringHeight() + 20) end
end

