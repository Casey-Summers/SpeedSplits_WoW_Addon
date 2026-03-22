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

local function BuildHistoryModeLabel(record)
    if record.pbMode == "ignored" then
        return "Ignored"
    end
    if record.speedrunMode == "last" or record.pbMode == "last" then
        return "Last Boss"
    end
    return "All Bosses"
end

local function BuildHistoryViewRecord(record)
    local duration = tonumber(record and record.duration)
    local pbNode = record and NS.Database.GetHistoryPBNode(record) or nil
    local pbDuration = tonumber(pbNode and pbNode.FullRun and pbNode.FullRun.duration)
    local isPB = type(record) == "table" and record.success and duration and pbDuration and
        math.abs(duration - pbDuration) < 0.001 or false
    local diff = (pbDuration and duration) and (duration - pbDuration) or nil
    local resultText, resultColor = "Incomplete", NS.Colors.darkRed
    if isPB then
        resultText, resultColor = "PB", NS.Colors.gold
    elseif record and record.success then
        resultText, resultColor = "Completed", NS.Colors.deepGreen
    end

    return {
        record = record,
        startedAt = tonumber(record and record.startedAt) or 0,
        instanceNameNorm = Util.NormalizeName(record and record.instanceName),
        tier = tonumber(record and record.tier) or 0,
        duration = duration,
        diff = diff,
        isPB = isPB and true or false,
        resultText = resultText,
        resultColor = resultColor,
        modeLabel = BuildHistoryModeLabel(record or {}),
        formattedDate = FormatEpochShort(record and record.startedAt),
        tierName = GetTierNameSafe(record and record.tier),
        formattedDuration = duration and Util.FormatTime(duration) or "--:--.---",
    }
end

local function History_GetRow(parent)
    UI.history.rowPool = UI.history.rowPool or {}
    local row = table.remove(UI.history.rowPool)
    if not row then
        row = HistoryRowTemplate.Create(parent, NS.Database.DeleteRunRecord)

        row.UpdateLayout = function(self)
            local widths = UI.history.resolvedColWidths or UI.history.colWidths

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
            SetCol(2, widths.dungeon, "LEFT")
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
                local view = BuildHistoryViewRecord(record)
                local matchesSearch = (search == "" or view.instanceNameNorm:find(search, 1, true))
                local matchesTier = (filterTier == 0 or view.tier == filterTier)

                local matchesResult = true
                if filterResult == "PB" then
                    matchesResult = view.isPB
                elseif filterResult == "Completed" then
                    matchesResult = (record.success and not view.isPB)
                elseif filterResult == "Incomplete" then
                    matchesResult = (not record.success)
                end

                if matchesSearch and matchesTier and matchesResult then
                    filtered[#filtered + 1] = view
                end
            end
        end
    end

    local sortCol = UI.history.sort_col or 1
    local sortAsc = UI.history.sort_asc ~= false

    table.sort(filtered, function(a, b)
        local valA, valB
        if sortCol == 1 then
            valA, valB = a.startedAt, b.startedAt
        elseif sortCol == 2 then
            valA, valB = a.instanceNameNorm, b.instanceNameNorm
        elseif sortCol == 3 then
            valA, valB = a.tier, b.tier
        elseif sortCol == 4 then
            valA, valB = a.isPB and 1 or (a.record.success and 2 or 3), b.isPB and 1 or (b.record.success and 2 or 3)
        elseif sortCol == 5 then
            valA, valB = a.modeLabel, b.modeLabel
        elseif sortCol == 6 then
            valA, valB = a.duration or 999999, b.duration or 999999
        elseif sortCol == 7 then
            valA, valB = a.diff or 999999, b.diff or 999999
        end

        if valA ~= valB then
            if sortAsc then
                return valA < valB
            end
            return valA > valB
        end
        return a.startedAt > b.startedAt
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

local function History_RestoreColWidths()
    local ui = UI.GetUISaved()
    local layout = ui and ui.frames and ui.frames.history or nil
    UI.history.colWidths = Util.CopyTable((layout and layout.columns) or UI.NormalizeHistoryColumns())
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

    local widths = UI.NormalizeHistoryColumns(history.colWidths, history.colWidths)
    local resolved = Util.CopyTable(widths)
    local avail = math.max(200, history.listFrame:GetWidth() - scrollWidth)
    local total = resolved.date + resolved.dungeon + resolved.expansion + resolved.result + resolved.mode + resolved.time +
        resolved.diff + resolved.delete

    if total < avail then
        resolved.dungeon = resolved.dungeon + (avail - total)
    elseif total > avail then
        local overflow = total - avail
        local shrinkOrder = {
            { key = "dungeon", min = 100 },
            { key = "diff", min = 50 },
            { key = "time", min = 50 },
            { key = "mode", min = 50 },
            { key = "result", min = 50 },
            { key = "expansion", min = 50 },
            { key = "date", min = 50 },
        }

        for _, item in ipairs(shrinkOrder) do
            if overflow <= 0 then
                break
            end

            local current = resolved[item.key]
            local shrink = math.min(overflow, math.max(0, current - item.min))
            resolved[item.key] = current - shrink
            overflow = overflow - shrink
        end
    end

    history.colWidths = widths
    history.resolvedColWidths = resolved

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

    SetHeader(1, resolved.date)
    SetHeader(2, resolved.dungeon)
    SetHeader(3, resolved.expansion)
    SetHeader(4, resolved.result)
    SetHeader(5, resolved.mode)
    SetHeader(6, resolved.time)
    SetHeader(7, resolved.diff)
    SetHeader(8, resolved.delete)

    if history.grips then
        local gripHeight = 24
        x = 0
        local function SetGrip(i, width)
            x = x + width
            history.grips[i]:ClearAllPoints()
            history.grips[i]:SetPoint("TOPLEFT", history.header, "TOPLEFT", x - 5, 0)
            history.grips[i]:SetPoint("BOTTOMRIGHT", history.header, "TOPLEFT", x + 5, -gripHeight)
        end
        SetGrip(1, resolved.date)
        SetGrip(2, resolved.dungeon)
        SetGrip(3, resolved.expansion)
        SetGrip(4, resolved.result)
        SetGrip(5, resolved.mode)
        SetGrip(6, resolved.time)
        SetGrip(7, resolved.diff)
    end
end

local function History_BeginColDrag(idx, startX)
    local widths = UI.history.colWidths
    UI.history.drag = {
        idx = idx,
        startX = startX,
        date = widths.date,
        dungeon = widths.dungeon,
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
    if UI.SaveColumnWidths then
        UI.SaveColumnWidths("history", UI.history.colWidths)
    end
    if UI.SaveFrameLayout and UI.history and UI.history.frame then
        UI.SaveFrameLayout("history", UI.history.frame)
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
    local boundaries = {
        [1] = { left = "date", right = "dungeon", leftMin = 50, rightMin = 100 },
        [2] = { left = "dungeon", right = "expansion", leftMin = 100, rightMin = 50 },
        [3] = { left = "expansion", right = "result", leftMin = 50, rightMin = 50 },
        [4] = { left = "result", right = "mode", leftMin = 50, rightMin = 50 },
        [5] = { left = "mode", right = "time", leftMin = 50, rightMin = 50 },
        [6] = { left = "time", right = "diff", leftMin = 50, rightMin = 50 },
        [7] = { left = "diff", right = "delete", leftMin = 50, rightMin = 30 },
    }
    local boundary = boundaries[drag.idx]

    if boundary then
        local leftStart = drag[boundary.left]
        local rightStart = drag[boundary.right]
        local applied = dx

        if leftStart + applied < boundary.leftMin then
            applied = boundary.leftMin - leftStart
        end
        if rightStart - applied < boundary.rightMin then
            applied = rightStart - boundary.rightMin
        end

        widths[boundary.left] = leftStart + applied
        widths[boundary.right] = rightStart - applied
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
    historyFrame:SetClampedToScreen(true)
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
        if UI.SaveFrameLayout then
            UI.SaveFrameLayout("history", self)
        end
    end)
    historyFrame:SetScript("OnShow", function()
        if UI.SaveFrameShown then
            UI.SaveFrameShown("history", true)
        end
    end)
    historyFrame:SetScript("OnHide", function()
        if UI.SaveFrameShown then
            UI.SaveFrameShown("history", false)
        end
    end)

    local controls = CreateFrame("Frame", nil, historyFrame)
    controls:SetPoint("TOPLEFT", 10, -10)
    controls:SetPoint("TOPRIGHT", -10, -10)
    controls:SetHeight(30)

    local title = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 0, 0)
    title:SetText("Run History")
    title:SetTextColor(1, 1, 1, 1)

    local close = FrameFactory.CreateCloseButton(historyFrame, "TOPRIGHT", historyFrame, "TOPRIGHT", -2, -2)

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

    local tierDropDown = DropDown.Create(controls, 100, 1)
    tierDropDown:SetPoint("LEFT", searchBox, "RIGHT", -12, -2)
    DropDown.Bind(tierDropDown, {
        buildItems = BuildHistoryTierItems,
        getValue = function()
            return UI.history.filters and UI.history.filters.tier or 0
        end,
        setValue = function(v)
            if UI.history.filters then
                UI.history.filters.tier = tonumber(v) or 0
            end
        end,
        onChanged = function()
            UI.RefreshHistoryTable()
        end,
        fallbackText = "Expansion",
    })
    UI.history.tierDropDown = tierDropDown

    local resultDropDown = DropDown.Create(controls, 90, 1)
    resultDropDown:SetPoint("LEFT", tierDropDown, "RIGHT", -24, 0)
    DropDown.Bind(resultDropDown, {
        buildItems = BuildHistoryResultItems,
        getValue = function()
            return UI.history.filters and UI.history.filters.result or "Any"
        end,
        setValue = function(v)
            if UI.history.filters then
                UI.history.filters.result = v
            end
        end,
        onChanged = function()
            UI.RefreshHistoryTable()
        end,
        fallbackText = "Result",
    })

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
                local view = data[idx]
                if view then
                    local record = view.record
                    local textColor = NS.Colors.white

                    row.cols[1]:SetText(view.formattedDate)
                    row.cols[1]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                    row.cols[2]:SetText(record.instanceName or "â€”")
                    row.cols[3]:SetText(view.tierName)
                    row.cols[3]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                    row.cols[4]:SetText(view.resultText)
                    row.cols[4]:SetTextColor(view.resultColor.r, view.resultColor.g, view.resultColor.b)
                    row.cols[5]:SetText(view.modeLabel)
                    row.cols[5]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                    row.cols[6]:SetText(view.formattedDuration)
                    row.cols[6]:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)

                    if view.diff then
                        local _, _, _, hex = NS.GetPaceColor(view.diff, view.isPB)
                        row.cols[7]:SetText(hex .. Util.FormatDelta(view.diff) .. "|r")
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
        if UI.SaveFrameLayout then
            UI.SaveFrameLayout("history", historyFrame)
        end
        History_ApplyTableLayout()
    end)
    UI.history.resizeGrip = grip
    UI.history.sort_col = 1
    UI.history.sort_asc = false
    if UI.RegisterManagedFrame then
        UI.RegisterManagedFrame("history", historyFrame)
    end
    if UI.ApplyAllLayouts then
        UI.ApplyAllLayouts()
    end

    C_Timer.After(0.1, function()
        UpdateHistoryRows()
        History_EnsureColGrips()
        if UI.ApplyAllLayouts then
            UI.ApplyAllLayouts()
        else
            History_ApplyTableLayout()
        end
        UI.RefreshHistoryTable()
    end)
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
