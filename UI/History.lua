local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Const = NS.Const
local DropDown = UI.Templates.DropDown
local FrameFactory = UI.Templates.FrameFactory
local ResizeGrip = UI.Templates.ResizeGrip
local ScrollBarSkin = UI.Templates.ScrollBarSkin
local HeaderCell = UI.Templates.HeaderCell
local HistoryRowTemplate = UI.Templates.HistoryRow

local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local function FormatEpochShort(epoch)
    return (not epoch or epoch <= 0) and "â€”" or date("%H:%M %d/%m/%Y", epoch)
end

local function GetTierNameSafe(tierIndex)
    tierIndex = tonumber(tierIndex)
    if not tierIndex or tierIndex <= 0 then
        return "Unknown"
    end
    if EJ_GetTierInfo then
        local name = EJ_GetTierInfo(tierIndex)
        if type(name) == "string" and name ~= "" and name ~= tostring(tierIndex) then
            return name
        end
    end

    local fallback = {
        [1] = "Classic",
        [2] = "The Burning Crusade",
        [3] = "Wrath of the Lich King",
        [4] = "Cataclysm",
        [5] = "Mists of Pandaria",
        [6] = "Warlords of Draenor",
        [7] = "Legion",
        [8] = "Battle for Azeroth",
        [9] = "Shadowlands",
        [10] = "Dragonflight",
        [11] = "The War Within",
    }
    return fallback[tierIndex] or ("Tier " .. tostring(tierIndex))
end

local function IsRunPB(record)
    if type(record) ~= "table" or not record.success or not record.duration or not record.instanceName then
        return false
    end
    local node = NS.Database.GetHistoryPBNode(record)
    local pb = node and node.FullRun
    if type(pb) ~= "table" or not pb.duration then
        return false
    end
    return math.abs(record.duration - pb.duration) < 0.001
end

local function History_GetRow(parent)
    UI.history.rowPool = UI.history.rowPool or {}
    local row = table.remove(UI.history.rowPool)
    if not row then
        row = HistoryRowTemplate.Create(parent, NS.Database.DeleteRunRecord)

        row.UpdateLayout = function(self)
            local widths = UI.history.colWidths
            local avail = UI.history.listFrame:GetWidth() - 20
            local used = widths.date + widths.expansion + widths.time + widths.result + widths.mode + widths.diff +
                widths.delete
            local dungeonWidth = math.max(avail - used, 100)

            local x = 0
            local msOff = 0
            local function SetCol(i, width, align, pivot)
                local col = self.cols[i]
                col:ClearAllPoints()
                if pivot then
                    if msOff == 0 then
                        local t = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        t:SetText(".000")
                        msOff = t:GetStringWidth()
                        t:Hide()
                    end
                    col:SetPoint("RIGHT", self, "LEFT", x + (width / 2) + msOff, 0)
                    col:SetPoint("LEFT", self, "LEFT", x, 0)
                    col:SetJustifyH("RIGHT")
                else
                    col:SetPoint("LEFT", self, "LEFT", x, 0)
                    col:SetWidth(width)
                    col:SetJustifyH(align)
                end
                x = x + width
            end

            SetCol(1, widths.date, "CENTER")
            SetCol(2, dungeonWidth, "LEFT")
            SetCol(3, widths.expansion, "CENTER")
            SetCol(4, widths.result, "CENTER")
            SetCol(5, widths.mode, "CENTER")
            SetCol(6, widths.time, "CENTER", true)
            SetCol(7, widths.diff, "CENTER", true)
            SetCol(8, widths.delete, "CENTER")
        end
    end

    row:SetParent(parent)
    return row
end

function UI.RefreshHistoryTable()
    if not UI.history or not UI.history.frame or not UI.history.frame:IsShown() then
        return
    end

    local filters = UI.history.filters or Util.HistoryFilterDefaults()
    local search = Util.NormalizeName(filters.search or "")
    local filterResult = filters.result or "Any"
    local filterTier = tonumber(filters.tier) or 0

    local filtered = {}
    local history = NS.DB and NS.DB.RunHistory
    if type(history) == "table" then
        for i = 1, #history do
            local record = history[i]
            if record.instanceName then
                local nameNorm = Util.NormalizeName(record.instanceName)
                local matchesSearch = (search == "" or nameNorm:find(search, 1, true))
                local matchesTier = (filterTier == 0 or tonumber(record.tier) == filterTier)
                local isPB = IsRunPB(record)

                local matchesResult = true
                if filterResult == "PB" then
                    matchesResult = isPB
                elseif filterResult == "Completed" then
                    matchesResult = (record.success and not isPB)
                elseif filterResult == "Incomplete" then
                    matchesResult = (not record.success)
                end

                if matchesSearch and matchesTier and matchesResult then
                    table.insert(filtered, record)
                end
            end
        end
    end

    local sortCol = UI.history.sort_col or 1
    local sortAsc = UI.history.sort_asc ~= false

    table.sort(filtered, function(a, b)
        local valA, valB
        if sortCol == 1 then
            valA, valB = tonumber(a.startedAt or 0), tonumber(b.startedAt or 0)
        elseif sortCol == 2 then
            valA, valB = Util.NormalizeName(a.instanceName), Util.NormalizeName(b.instanceName)
        elseif sortCol == 3 then
            valA, valB = tonumber(a.tier or 0), tonumber(b.tier or 0)
        elseif sortCol == 4 then
            local function ResultOrder(x)
                return IsRunPB(x) and 1 or (x.success and 2 or 3)
            end
            valA, valB = ResultOrder(a), ResultOrder(b)
        elseif sortCol == 5 then
            valA, valB = a.speedrunMode or "all", b.speedrunMode or "all"
        elseif sortCol == 6 then
            valA, valB = tonumber(a.duration) or 999999, tonumber(b.duration) or 999999
        elseif sortCol == 7 then
            local function GetDiff(x)
                local node = NS.Database.GetHistoryPBNode(x)
                local pb = node and node.FullRun and node.FullRun.duration
                return (pb and x.duration) and (x.duration - pb) or 999999
            end
            valA, valB = GetDiff(a), GetDiff(b)
        end

        if valA ~= valB then
            if sortAsc then
                return valA < valB
            end
            return valA > valB
        end
        return tonumber(a.startedAt or 0) > tonumber(b.startedAt or 0)
    end)

    UI.history.filteredData = filtered
    UI.history.UpdateScroll()
end

local function BuildHistoryTierItems()
    local items = { { text = "Any", value = 0 } }
    if not NS.DB or not NS.DB.RunHistory then
        return items
    end

    local seen = {}
    for _, record in ipairs(NS.DB.RunHistory) do
        local tier = tonumber(record.tier)
        if tier and tier > 0 then
            seen[tier] = true
        end
    end

    local tiers = {}
    for tier in pairs(seen) do
        tiers[#tiers + 1] = tier
    end
    table.sort(tiers)

    for _, tier in ipairs(tiers) do
        items[#items + 1] = { text = GetTierNameSafe(tier), value = tier }
    end
    return items
end

local function BuildHistoryResultItems()
    return {
        { text = "Any Result", value = "Any" },
        { text = "PB",         value = "PB" },
        { text = "Completed",  value = "Completed" },
        { text = "Incomplete", value = "Incomplete" },
    }
end

local function InitHistoryDropDown(dropdown, buildItems, getValue, setValue)
    DropDown.Initialize(dropdown, buildItems, getValue, setValue, function()
        UI.RefreshHistoryTable()
    end)
end

local function History_RestoreColWidths()
    UI.history.colWidths = {}
    local ui = UI.GetUISaved()
    local saved = ui and ui.historyCols
    local defaults = NS.FactoryDefaults.ui and NS.FactoryDefaults.ui.historyCols or {}
    for key, def in pairs(defaults) do
        UI.history.colWidths[key] = (saved and saved[key]) and tonumber(saved[key]) or def
    end
end

local function History_ApplyTableLayout()
    local history = UI.history
    if not history or not history.frame or not history.listFrame or not history.colWidths then
        return
    end

    local scrollFrame = history.scrollFrame
    local scrollbar = scrollFrame and _G[scrollFrame:GetName() .. "ScrollBar"]
    local isShown = scrollbar and scrollbar:IsShown()
    local scrollWidth = isShown and 20 or 4

    local widths = history.colWidths
    local avail = history.listFrame:GetWidth() - scrollWidth
    local used = widths.date + widths.expansion + widths.time + widths.result + widths.mode + widths.diff + widths
        .delete
    local dungeonWidth = math.max(avail - used, 100)

    if history.rows then
        for _, row in ipairs(history.rows) do
            row:UpdateLayout()
        end
    end

    local x = 0
    local function SetHeader(i, width)
        history.headerCells[i]:ClearAllPoints()
        history.headerCells[i]:SetPoint("LEFT", history.header, "LEFT", x, 0)
        history.headerCells[i]:SetWidth(width)
        x = x + width
    end

    SetHeader(1, widths.date)
    SetHeader(2, dungeonWidth)
    SetHeader(3, widths.expansion)
    SetHeader(4, widths.result)
    SetHeader(5, widths.mode)
    SetHeader(6, widths.time)
    SetHeader(7, widths.diff)
    SetHeader(8, widths.delete)

    if history.grips then
        local gripHeight = 24
        x = 0
        local function SetGrip(i, width)
            x = x + width
            history.grips[i]:ClearAllPoints()
            history.grips[i]:SetPoint("TOPLEFT", history.header, "TOPLEFT", x - 5, 0)
            history.grips[i]:SetPoint("BOTTOMRIGHT", history.header, "TOPLEFT", x + 5, -gripHeight)
        end
        SetGrip(1, widths.date)
        SetGrip(2, dungeonWidth)
        SetGrip(3, widths.expansion)
        SetGrip(4, widths.result)
        SetGrip(5, widths.mode)
        SetGrip(6, widths.time)
        SetGrip(7, widths.diff)
    end
end

local function History_BeginColDrag(idx, startX)
    local widths = UI.history.colWidths
    UI.history.drag = {
        idx = idx,
        startX = startX,
        date = widths.date,
        expansion = widths.expansion,
        time = widths.time,
        result = widths.result,
        mode = widths.mode,
        diff = widths.diff,
        delete = widths.delete,
    }
end

local function History_EndColDrag()
    UI.history.drag = nil
    if UI.CaptureCurrentLayout then
        UI.CaptureCurrentLayout()
    end
end

local function History_UpdateColDrag()
    local history = UI.history
    if not history or not history.drag or not history.listFrame then
        return
    end
    local curX = GetCursorPosition() / (history.frame:GetEffectiveScale() or 1)
    local dx = curX - history.drag.startX
    local drag = history.drag
    local widths = history.colWidths
    local avail = history.listFrame:GetWidth() - 20
    local minDungeon = 100

    local function GetUsedExcept(idx)
        local sum = widths.date + widths.expansion + widths.time + widths.result + widths.mode + widths.diff +
            widths.delete
        if idx == 1 then
            sum = sum - widths.date
        elseif idx == 3 then
            sum = sum - widths.expansion
        elseif idx == 4 then
            sum = sum - widths.result
        elseif idx == 5 then
            sum = sum - widths.mode
        elseif idx == 6 then
            sum = sum - widths.time
        elseif idx == 7 then
            sum = sum - widths.diff
        end
        return sum
    end

    if drag.idx == 1 then
        widths.date = Util.Clamp(drag.date + dx, 50, avail - GetUsedExcept(1) - minDungeon)
    elseif drag.idx == 2 then
        widths.expansion = Util.Clamp(drag.expansion - dx, 50, 400)
    elseif drag.idx == 3 then
        widths.expansion = Util.Clamp(drag.expansion + dx, 50, avail - GetUsedExcept(3) - minDungeon)
    elseif drag.idx == 4 then
        widths.result = Util.Clamp(drag.result + dx, 50, avail - GetUsedExcept(4) - minDungeon)
    elseif drag.idx == 5 then
        widths.mode = Util.Clamp(drag.mode + dx, 50, avail - GetUsedExcept(5) - minDungeon)
    elseif drag.idx == 6 then
        widths.time = Util.Clamp(drag.time + dx, 50, avail - GetUsedExcept(6) - minDungeon)
    elseif drag.idx == 7 then
        widths.diff = Util.Clamp(drag.diff + dx, 50, avail - GetUsedExcept(7) - minDungeon)
    end
    History_ApplyTableLayout()
end

local function History_MakeGrip(parent, i)
    local grip = ResizeGrip.CreateColumnGrip(
        parent,
        10,
        24,
        function()
            local x = GetCursorPosition() / (UI.history.frame:GetEffectiveScale() or 1)
            History_BeginColDrag(i, x)
        end,
        History_UpdateColDrag,
        function()
            History_EndColDrag()
        end
    )
    grip:SetFrameLevel(parent:GetFrameLevel() + 10)

    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetSize(1, 16)
    tex:SetPoint("CENTER")
    tex:SetColorTexture(1, 1, 1, 0.2)

    grip:SetScript("OnEnter", function()
        SetCursor("UI_RESIZE_CURSOR")
        tex:SetColorTexture(1, 1, 1, 0.8)
    end)
    grip:SetScript("OnLeave", function()
        ResetCursor()
        tex:SetColorTexture(1, 1, 1, 0.2)
    end)

    return grip
end

local function History_EnsureColGrips()
    if UI.history.grips then
        return
    end
    UI.history.grips = {}
    for i = 1, 7 do
        UI.history.grips[i] = History_MakeGrip(UI.history.header, i)
    end
end

local function EnsureHistoryUI()
    if UI.history.frame then
        return
    end
    UI.history.filters = UI.history.filters or Util.HistoryFilterDefaults()
    History_RestoreColWidths()

    local historyFrame = FrameFactory.CreateDialogFrame("SpeedSplitsHistoryFrame", 850, 500)
    UI.history.frame = historyFrame
    historyFrame:EnableMouse(true)
    historyFrame:SetMovable(true)
    historyFrame:SetResizable(true)
    historyFrame:RegisterForDrag("LeftButton")

    Util.ApplyResizeBounds(historyFrame, 850, 200)

    historyFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    historyFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if UI.CaptureCurrentLayout then
            UI.CaptureCurrentLayout()
        end
    end)

    if not UI.RestoreFrameGeom("history", historyFrame, 850, 500) then
        historyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local controls = CreateFrame("Frame", nil, historyFrame)
    controls:SetPoint("TOPLEFT", 10, -10)
    controls:SetPoint("TOPRIGHT", -10, -10)
    controls:SetHeight(30)

    local title = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 0, 0)
    title:SetText("Run History")
    title:SetTextColor(1, 1, 1, 1)

    local close = CreateFrame("Button", nil, historyFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", historyFrame, "TOPRIGHT", -2, -2)

    local searchLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("LEFT", title, "RIGHT", 16, 0)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetSize(140, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        if UI.history.filters then
            UI.history.filters.search = self:GetText() or ""
        end
        UI.RefreshHistoryTable()
    end)
    UI.history.searchBox = searchBox

    local tierDropDown = CreateFrame("Frame", nil, controls, "UIDropDownMenuTemplate")
    tierDropDown:SetPoint("LEFT", searchBox, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(tierDropDown, 100)
    InitHistoryDropDown(tierDropDown, BuildHistoryTierItems, function()
        return UI.history.filters and UI.history.filters.tier or 0
    end, function(v)
        if UI.history.filters then
            UI.history.filters.tier = tonumber(v) or 0
        end
    end)
    DropDown.Refresh(tierDropDown, BuildHistoryTierItems, function()
        return UI.history.filters and UI.history.filters.tier or 0
    end, "Expansion")
    UI.history.tierDropDown = tierDropDown

    local resultDropDown = CreateFrame("Frame", nil, controls, "UIDropDownMenuTemplate")
    resultDropDown:SetPoint("LEFT", tierDropDown, "RIGHT", -24, 0)
    UIDropDownMenu_SetWidth(resultDropDown, 90)
    InitHistoryDropDown(resultDropDown, BuildHistoryResultItems, function()
        return UI.history.filters and UI.history.filters.result or "Any"
    end, function(v)
        if UI.history.filters then
            UI.history.filters.result = v
        end
    end)
    DropDown.Refresh(resultDropDown, BuildHistoryResultItems, function()
        return UI.history.filters and UI.history.filters.result or "Any"
    end, "Result")

    local listFrame = FrameFactory.CreateBorderedFrame(historyFrame, 0.4, NS.Colors.turquoise)
    listFrame:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -34)
    listFrame:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -12, 10)
    listFrame:SetClipsChildren(true)
    UI.history.listFrame = listFrame

    local scrollFrame = CreateFrame("ScrollFrame", "SpeedSplitsHistoryScroll", listFrame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT")
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT")
    UI.history.scrollFrame = scrollFrame

    local scrollbar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollbar then
        ScrollBarSkin.Apply(scrollbar, 10)
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -2, -1)
        scrollbar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -2, 1)
    end
    UI.history.scrollBar = scrollbar

    local header = CreateFrame("Frame", nil, historyFrame)
    header:SetHeight(24)
    header:SetPoint("BOTTOMLEFT", listFrame, "TOPLEFT", 0, 2)
    header:SetPoint("BOTTOMRIGHT", listFrame, "TOPRIGHT", 0, 2)
    UI.history.header = header

    local headerCols = { "Date", "Dungeon", "Expansion", "Result", "Mode", "Time", "Difference", "" }
    UI.history.headerCells = {}
    for i = 1, 8 do
        local btn = HeaderCell.Create(header, headerCols[i], "CENTER", function()
            if i == 8 then
                return
            end
            if UI.history.sort_col == i then
                UI.history.sort_asc = not UI.history.sort_asc
            else
                UI.history.sort_col = i
                UI.history.sort_asc = (i == 6 or i == 7)
            end
            UI.RefreshHistoryTable()
        end)
        UI.history.headerCells[i] = btn
    end

    UI.history.rows = {}
    local function UpdateHistoryRows()
        local availH = listFrame:GetHeight()
        local rowH = 24
        local count = math.floor(availH / rowH)
        UI.history.visibleCount = count
        for i = 1, math.max(count, #UI.history.rows) do
            if i <= count then
                if not UI.history.rows[i] then
                    UI.history.rows[i] = History_GetRow(listFrame)
                    UI.history.rows[i]:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -(i - 1) * rowH)
                    UI.history.rows[i]:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, -(i - 1) * rowH)
                end
                UI.history.rows[i]:Show()
                UI.history.rows[i]:UpdateLayout()
            elseif UI.history.rows[i] then
                UI.history.rows[i]:Hide()
            end
        end
    end

    UI.history.UpdateScroll = function()
        local data = UI.history.filteredData or {}
        local rowH = 24
        local numRows = UI.history.visibleCount or 0
        FauxScrollFrame_Update(UI.history.scrollFrame, #data, numRows, rowH)
        local offset = FauxScrollFrame_GetOffset(UI.history.scrollFrame)

        for i = 1, #UI.history.rows do
            local row = UI.history.rows[i]
            if i <= numRows then
                local idx = i + offset
                local record = data[idx]
                if record then
                    local isPB = IsRunPB(record)
                    local resultText, resultColor = "Incomplete", NS.Colors.darkRed
                    if isPB then
                        resultText, resultColor = "PB", NS.Colors.gold
                    elseif record.success then
                        resultText, resultColor = "Completed", NS.Colors.deepGreen
                    end

                    local node = NS.Database.GetHistoryPBNode(record)
                    local pb = node and node.FullRun and node.FullRun.duration
                    local diff = (pb and record.duration) and (record.duration - pb) or nil
                    local textColor = NS.Colors.white
                    local modeLabel = "All Bosses"
                    if record.pbMode == "ignored" then
                        modeLabel = "Ignored"
                    elseif record.speedrunMode == "last" or record.pbMode == "last" then
                        modeLabel = "Last Boss"
                    end

                    row.cols[1]:SetText(FormatEpochShort(record.startedAt))
                    row.cols[1]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                    row.cols[2]:SetText(record.instanceName or "â€”")
                    row.cols[3]:SetText(GetTierNameSafe(record.tier))
                    row.cols[3]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                    row.cols[4]:SetText(resultText)
                    row.cols[4]:SetTextColor(resultColor.r, resultColor.g, resultColor.b)
                    row.cols[5]:SetText(modeLabel)
                    row.cols[5]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                    row.cols[6]:SetText(record.duration and Util.FormatTime(record.duration) or "--:--.---")
                    row.cols[6]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)

                    if diff then
                        local _, _, _, hex = NS.GetPaceColor(diff, isPB)
                        row.cols[7]:SetText(hex .. Util.FormatDelta(diff) .. "|r")
                    else
                        row.cols[7]:SetText("â€”")
                    end

                    row.delBtn.record = record
                    row.bg:SetShown(idx % 2 == 0)
                    row:Show()
                else
                    row:Hide()
                end
            else
                row:Hide()
            end
        end
        History_ApplyTableLayout()
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 24, UI.history.UpdateScroll)
    end)
    historyFrame:SetScript("OnSizeChanged", function()
        UpdateHistoryRows()
        UI.history.UpdateScroll()
        History_ApplyTableLayout()
    end)

    local grip = UI.SetupSizeGrip(historyFrame, function()
        if UI.CaptureCurrentLayout then
            UI.CaptureCurrentLayout()
        end
        History_ApplyTableLayout()
    end)
    UI.history.resizeGrip = grip
    UI.history.sort_col = 1
    UI.history.sort_asc = false

    C_Timer.After(0.1, function()
        UpdateHistoryRows()
        History_EnsureColGrips()
        History_ApplyTableLayout()
        UI.RefreshHistoryTable()
    end)

    historyFrame:Hide()
end

function UI.ToggleHistoryFrame()
    local ok, err = pcall(function()
        if NS.Database.EnsureDB then
            NS.Database.EnsureDB()
        end
        EnsureHistoryUI()
        local history = UI.history
        if not history or not history.frame then
            return
        end

        if history.frame:IsShown() then
            history.frame:Hide()
        else
            history.frame:Show()
            if history.UpdateLayout then
                history.UpdateLayout()
            end
            if NS.UpdateHistoryLayout then
                NS.UpdateHistoryLayout()
            end
            UI.RefreshHistoryTable()
        end
    end)
    if not ok and NS.Print then
        NS.Print("Error opening history: " .. tostring(err))
    end
end

NS.UpdateHistoryLayout = History_ApplyTableLayout
UI.FormatEpochShort = FormatEpochShort
UI.GetTierNameSafe = GetTierNameSafe
UI.IsRunPB = IsRunPB
UI.History_RestoreColWidths = History_RestoreColWidths
UI.History_ApplyTableLayout = History_ApplyTableLayout
UI.History_EnsureColGrips = History_EnsureColGrips
UI.EnsureHistoryUI = EnsureHistoryUI
