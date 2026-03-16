local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Colors = NS.Colors
local ScrollBarSkin = UI.Templates.ScrollBarSkin


local function GetDisplayDataIndex(column)
    if column >= 1 and column <= 4 then
        return column
    end
    return nil
end

local function GetVisibleRowModel(rowFrame)
    if not rowFrame then
        return nil
    end

    if not rowFrame._ssModel then
        local model = CreateFrame("PlayerModel", nil, rowFrame)
        model:SetFrameLevel((rowFrame:GetFrameLevel() or 0) + 1)
        rowFrame._ssModel = model
    end

    return rowFrame._ssModel
end

local function UpdateVisibleRowModel(rowFrame, entry, realrow, fShow)
    local model = GetVisibleRowModel(rowFrame)
    if not model then
        return
    end

    local showModels = NS.DB and NS.DB.Settings and NS.DB.Settings.showNPCViewModels ~= false
    if not fShow or not realrow or not showModels or UI._modelWidth <= 0 or not entry then
        model:Hide()
        return
    end

    local bossCell = rowFrame.cols and rowFrame.cols[1]
    if not bossCell then
        model:Hide()
        return
    end

    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", bossCell, "TOPLEFT", 1, -1)
    model:SetPoint("BOTTOMLEFT", bossCell, "BOTTOMLEFT", 1, 1)
    model:SetWidth(math.max(UI._modelWidth - 2, 0))

    local displayID = NS.Const.BOSS_MODEL_ID
    if displayID and not NS.IsBossIgnored(entry.cols[1].value) then
        model:SetDisplayInfo(displayID)
        model:SetKeepModelOnHide(true)
        model:Show()
        model:SetPortraitZoom(NS.Const.BOSS_MODEL_ZOOM)
    else
        model:Hide()
    end
end

local function Boss_DoCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow or not realrow then
        if rowFrame and rowFrame._ssModel then
            rowFrame._ssModel:Hide()
        end
        if cellFrame and cellFrame.text then
            cellFrame.text:SetText("")
        end
        return
    end

    cellFrame:SetClipsChildren(true)
    local entry = data[realrow]
    local cell = entry and entry.cols and entry.cols[1]
    if not cell then
        return
    end

    UpdateVisibleRowModel(rowFrame, entry, realrow, fShow)

    cellFrame.text:SetText(cell.value or "")
    NS.ApplyFontToFS(cellFrame.text, "boss")
    cellFrame.text:SetJustifyH("LEFT")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:SetWordWrap(true)
    if cellFrame.text.SetMaxLines then
        cellFrame.text:SetMaxLines(2)
    end
    cellFrame.text:ClearAllPoints()
    cellFrame.text:SetPoint("TOPLEFT", cellFrame, "TOPLEFT", UI._modelWidth + 4, -1)
    cellFrame.text:SetPoint("BOTTOMRIGHT", cellFrame, "BOTTOMRIGHT", -2, 1)

    if NS.IsBossIgnored(cell.value) then
        cellFrame.text:SetTextColor(0.5, 0.5, 0.5, 1)
    else
        cellFrame.text:SetTextColor(Colors.white.r, Colors.white.g, Colors.white.b, Colors.white.a or 1)
    end
end

local function Num_DoCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, stable)
    if not fShow or not realrow then
        if cellFrame and cellFrame.text then
            cellFrame.text:SetText("")
        end
        return
    end

    local entry = data[realrow]
    local dataIndex = GetDisplayDataIndex(column)
    local cell = entry and entry.cols and entry.cols[dataIndex]
    if not cell then
        return
    end

    cellFrame.text:SetText(cell.value or "")
    NS.ApplyFontToFS(cellFrame.text, "num")
    cellFrame.text:SetJustifyH("RIGHT")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:ClearAllPoints()
    if dataIndex == 4 then
        cellFrame.text:SetPoint("RIGHT", cellFrame, "RIGHT", -10, 0)
    else
        cellFrame.text:SetPoint("RIGHT", cellFrame, "CENTER", 34, 0)
    end
    cellFrame.text:SetWidth(0)

    local color = (cols[column].color and cols[column].color(data, cols, realrow, column, stable)) or cell.color
    if NS.IsBossIgnored(entry.cols[1].value) then
        cellFrame.text:SetTextColor(0.4, 0.4, 0.4, 1)
    elseif color then
        cellFrame.text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    else
        cellFrame.text:SetTextColor(1, 1, 1, 1)
    end
end

local function PBColor()
    return Colors.gold
end

local function DeltaColor(data, cols, realrow, column)
    local entry = data[realrow]
    local cell = entry and entry.cols and entry.cols[GetDisplayDataIndex(column)]
    return cell and cell.color or nil
end

local function SplitColor(data, cols, realrow, column)
    local entry = data[realrow]
    local cell = entry and entry.cols and entry.cols[GetDisplayDataIndex(column)]
    return cell and cell.color or nil
end

local function ClearBossRows()
    UI.data = UI.data or {}
    UI.rowByBossKey = UI.rowByBossKey or {}
    wipe(UI.data)
    wipe(UI.rowByBossKey)

    if UI.st and UI.st.rows then
        for _, row in ipairs(UI.st.rows) do
            if row and row._ssModel then
                row._ssModel:Hide()
            end
        end
    end

    if UI.st and UI.st.SetData then
        UI.st:SetData(UI.data, true)
    elseif UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end
end

local function RefreshBossTablePresentation()
    if UI.st and UI.st.scrollframe then
        local scrollbar = _G[UI.st.scrollframe:GetName() .. "ScrollBar"]
        if scrollbar then
            ScrollBarSkin.Apply(scrollbar, 10)
        end
    end

    if UI.ApplyTableLayout then
        UI.ApplyTableLayout()
    end

    if UI.RestyleBossTableHeaders then
        UI.RestyleBossTableHeaders(1.0)
    end
end

local function BuildBossTableOrder(entries)
    local visible = {}
    local ignored = {}

    for _, entry in ipairs(entries or {}) do
        if NS.IsBossIgnored(entry.name) then
            ignored[#ignored + 1] = entry
        else
            visible[#visible + 1] = entry
        end
    end

    local ordered = {}
    for _, entry in ipairs(visible) do
        ordered[#ordered + 1] = entry
    end
    for _, entry in ipairs(ignored) do
        ordered[#ordered + 1] = entry
    end

    return ordered
end

local function BuildBossPBCumulativeMap(entries, pbSegments)
    local cumulativeByKey = {}
    local cumulativePB = 0

    for _, entry in ipairs(entries or {}) do
        if not NS.IsBossIgnored(entry.name) then
            cumulativePB = cumulativePB + (pbSegments[entry.name] or 0)
        end
        cumulativeByKey[entry.key] = cumulativePB
    end

    return cumulativeByKey
end

local function RefreshBossTableData(entries, pbSegments)
    entries = entries or {}
    pbSegments = pbSegments or {}

    ClearBossRows()

    if #entries == 0 then
        RefreshBossTablePresentation()
        return
    end

    local orderedEntries = BuildBossTableOrder(entries)
    local cumulativePBByKey = BuildBossPBCumulativeMap(entries, pbSegments)
    local data = UI.data
    local map = UI.rowByBossKey
    local function AddToData(entry, isIgnored)
        local cumulativePB = cumulativePBByKey[entry.key] or 0

        data[#data + 1] = {
            key = entry.key,
            cols = {
                { value = entry.name or "Unknown" },
                {
                    value = (cumulativePB > 0) and Util.FormatTime(cumulativePB) or "--:--.---",
                    color = isIgnored and { r = 0.4, g = 0.4, b = 0.4, a = 1 } or Colors.gold,
                },
                { value = "" },
                { value = "" },
            },
        }
        map[entry.key] = #data
    end

    for _, entry in ipairs(orderedEntries) do
        AddToData(entry, NS.IsBossIgnored(entry.name))
    end

    if UI.st and UI.st.SetData then
        UI.st:SetData(data, true)
    end

    RefreshBossTablePresentation()
end

local function GetPreviousKilledCumulativeInTableOrder(run, bossKey)
    local previous
    for _, entry in ipairs(run.entries or {}) do
        if entry.key == bossKey then
            break
        end
        local t = run.kills and run.kills[entry.key]
        if t ~= nil then
            previous = t
        end
    end
    return previous
end

local function SetRowKilled(bossKey, splitCumulative, cumulativePB, deltaSeconds, r, g, b, hex, isGold)
    local realrow = UI.rowByBossKey and UI.rowByBossKey[bossKey]
    local row = realrow and UI.data and UI.data[realrow]
    if not row then
        return
    end

    local bossName = row.cols[1].value
    local isIgnored = NS.IsBossIgnored(bossName)

    row.cols[2].value = (cumulativePB and cumulativePB > 0) and Util.FormatTime(cumulativePB) or "--:--.---"
    row.cols[2].color = isIgnored and { r = 0.4, g = 0.4, b = 0.4, a = 1 } or Colors.gold
    row.cols[3].value = Util.FormatTime(splitCumulative)
    row.cols[3].color = isIgnored and { r = 0.4, g = 0.4, b = 0.4, a = 1 } or
        (isGold and Colors.gold or { r = r, g = g, b = b, a = 1 })

    if deltaSeconds == nil then
        row.cols[4].value = ""
        row.cols[4].color = nil
    else
        row.cols[4].value = Util.FormatDelta(deltaSeconds)
        row.cols[4].color = isIgnored and { r = 0.4, g = 0.4, b = 0.4, a = 1 } or
            (isGold and Colors.gold or { r = r, g = g, b = b, a = 1 })
    end

    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end
    RefreshBossTablePresentation()
end

UI.Boss_DoCellUpdate = Boss_DoCellUpdate
UI.Num_DoCellUpdate = Num_DoCellUpdate
UI.PBColor = PBColor
UI.DeltaColor = DeltaColor
UI.SplitColor = SplitColor
UI.ClearBossRows = ClearBossRows
UI.RefreshBossTablePresentation = RefreshBossTablePresentation
UI.RefreshBossTableData = RefreshBossTableData
UI.GetPreviousKilledCumulativeInTableOrder = GetPreviousKilledCumulativeInTableOrder
UI.SetRowKilled = SetRowKilled
