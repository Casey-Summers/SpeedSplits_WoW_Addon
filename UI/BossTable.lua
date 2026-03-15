local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Colors = NS.Colors

local function Model_DoCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    local showModels = NS.DB and NS.DB.Settings and NS.DB.Settings.showNPCViewModels ~= false
    if not fShow or not realrow or not showModels then
        if cellFrame and cellFrame.model then
            cellFrame.model:Hide()
        end
        return
    end

    if not cellFrame.model then
        local model = CreateFrame("PlayerModel", nil, cellFrame)
        model:SetAllPoints()
        model:SetPoint("TOPLEFT", cellFrame, "TOPLEFT", 1, -1)
        model:SetPoint("BOTTOMRIGHT", cellFrame, "BOTTOMRIGHT", -1, 1)
        cellFrame.model = model
    end

    local displayIDs = { 52047, 6110, 52515, 52595, 31042 }
    local displayID = displayIDs[realrow]
    if displayID and not NS.IsBossIgnored(data[realrow].cols[1].value) then
        cellFrame.model:SetDisplayInfo(displayID)
        cellFrame.model:SetKeepModelOnHide(true)
        cellFrame.model:Show()
        cellFrame.model:SetPortraitZoom(NS.Const.BOSS_MODEL_ZOOM)
    else
        cellFrame.model:Hide()
    end
end

local function Boss_DoCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow)
    if not fShow or not realrow then
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

    cellFrame.text:SetText(cell.value or "")
    NS.ApplyFontToFS(cellFrame.text, "boss", 0.85)
    cellFrame.text:SetJustifyH("LEFT")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:SetWordWrap(true)
    if cellFrame.text.SetMaxLines then
        cellFrame.text:SetMaxLines(2)
    end
    cellFrame.text:ClearAllPoints()
    cellFrame.text:SetPoint("TOPLEFT", cellFrame, "TOPLEFT", 0, -1)
    cellFrame.text:SetPoint("BOTTOMRIGHT", cellFrame, "BOTTOMRIGHT", 0, 1)

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
    local dataIndex = column - 1
    local cell = entry and entry.cols and entry.cols[dataIndex]
    if not cell then
        return
    end

    cellFrame.text:SetText(cell.value or "")
    NS.ApplyFontToFS(cellFrame.text, "num")
    cellFrame.text:SetJustifyH("RIGHT")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:ClearAllPoints()
    cellFrame.text:SetPoint("RIGHT", cellFrame, "CENTER", 34, 0)
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
    local cell = entry and entry.cols and entry.cols[column - 1]
    return cell and cell.color or nil
end

local function SplitColor(data, cols, realrow, column)
    local entry = data[realrow]
    local cell = entry and entry.cols and entry.cols[column - 1]
    return cell and cell.color or nil
end

local function ClearBossRows()
    UI.data = UI.data or {}
    UI.rowByBossKey = UI.rowByBossKey or {}
    wipe(UI.data)
    wipe(UI.rowByBossKey)

    if UI.st and UI.st.SetData then
        UI.st:SetData(UI.data, true)
    elseif UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end
end

local function RenderBossTable(entries, pbSegments)
    ClearBossRows()

    entries = entries or {}
    pbSegments = pbSegments or {}

    local data = UI.data
    local map = UI.rowByBossKey

    local cumulativePB = 0
    local function AddToData(entry, isIgnored)
        local pbSegment = pbSegments[entry.name] or 0
        cumulativePB = cumulativePB + pbSegment

        data[#data + 1] = {
            key = entry.key,
            cols = {
                { value = entry.name or "Unknown" },
                {
                    value = (pbSegment > 0 and (not isIgnored) and cumulativePB > 0) and Util.FormatTime(cumulativePB)
                        or (isIgnored and (pbSegment > 0 and Util.FormatTime(pbSegment) or "â€”") or "--:--.---"),
                    color = isIgnored and { r = 0.4, g = 0.4, b = 0.4, a = 1 } or Colors.gold,
                },
                { value = "" },
                { value = "" },
            },
        }
        data[#data].cols[2].value = (pbSegment > 0 and cumulativePB > 0) and Util.FormatTime(cumulativePB) or "--:--.---"
        map[entry.key] = #data
    end

    for _, entry in ipairs(entries) do
        AddToData(entry, NS.IsBossIgnored(entry.name))
    end

    if UI.st and UI.st.SetData then
        UI.st:SetData(data, true)
    end
    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end

    UI.ApplyTableLayout()
    
    if NS.UpdateColorsOnly then
        NS.UpdateColorsOnly()
    end
    if NS.UpdateFontsOnly then
        NS.UpdateFontsOnly()
    end
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
end

UI.Model_DoCellUpdate = Model_DoCellUpdate
UI.Boss_DoCellUpdate = Boss_DoCellUpdate
UI.Num_DoCellUpdate = Num_DoCellUpdate
UI.PBColor = PBColor
UI.DeltaColor = DeltaColor
UI.SplitColor = SplitColor
UI.ClearBossRows = ClearBossRows
UI.RenderBossTable = RenderBossTable
UI.GetPreviousKilledCumulativeInTableOrder = GetPreviousKilledCumulativeInTableOrder
UI.SetRowKilled = SetRowKilled
