local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Const = NS.Const
local ResizeGrip = UI.Templates.ResizeGrip

local function GetUISaved()
    if not NS.DB then
        return nil
    end
    NS.DB.ui = NS.DB.ui or {}
    NS.DB.ui.frames = NS.DB.ui.frames or {}
    NS.DB.ui.cols = NS.DB.ui.cols or {}
    NS.DB.ui.preview = NS.DB.ui.preview or false
    return NS.DB.ui
end

local function SaveFrameGeom(frameKey, frame)
    local ui = GetUISaved()
    if not ui then
        return
    end

    local point, _, relPoint, xOfs, yOfs = frame:GetPoint(1)
    ui.frames[frameKey] = ui.frames[frameKey] or {}
    ui.frames[frameKey].w = frame:GetWidth()
    ui.frames[frameKey].h = frame:GetHeight()
    ui.frames[frameKey].point = point
    ui.frames[frameKey].relPoint = relPoint
    ui.frames[frameKey].x = xOfs
    ui.frames[frameKey].y = yOfs
end

local function RestoreFrameGeom(frameKey, frame, defaultW, defaultH)
    local ui = GetUISaved()
    local saved = ui and ui.frames and ui.frames[frameKey]
    if saved and saved.point and saved.relPoint then
        frame:ClearAllPoints()
        frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x or 0, saved.y or 0)
        frame:SetSize(saved.w or defaultW, saved.h or defaultH)
        return true
    end
    frame:SetSize(defaultW, defaultH)
    return false
end

local function SaveColWidths()
    local ui = GetUISaved()
    if not ui then
        return
    end
    ui.cols.pb = UI._pbWidth
    ui.cols.split = UI._splitWidth
    ui.cols.delta = UI._deltaWidth
end

local function GetModelColumnWidth()
    local showModels = NS.DB and NS.DB.Settings and NS.DB.Settings.showNPCViewModels ~= false
    return showModels and 40 or 0
end

local function RestoreColWidths()
    local ui = GetUISaved()
    if not ui then
        return
    end
    UI._pbWidth = tonumber(ui.cols.pb) or UI._pbWidth
    UI._splitWidth = tonumber(ui.cols.split) or UI._splitWidth
    UI._deltaWidth = tonumber(ui.cols.delta) or UI._deltaWidth
end

local function GetScrollBarInset(st)
    if not st or not st.frame then
        return UI._rightInset
    end
    local sb = (st.scrollframe and st.scrollframe.ScrollBar) or st.frame.ScrollBar or st.scrollbar
    local width = (sb and sb.GetWidth and sb:GetWidth()) or UI._rightInset
    return math.max(16, math.floor(width + 8))
end

local function ApplyTableLayout()
    if not UI.bossFrame or not UI.st or not UI.cols then
        return
    end

    UI._topInset = Const.TOP_BAR_H + 2
    UI._bottomInset = 24 + 2

    UI.st.frame:ClearAllPoints()
    UI.st.frame:SetPoint("TOPLEFT", UI.bossFrame, "TOPLEFT", 0, -UI._topInset)
    UI.st.frame:SetPoint("BOTTOMRIGHT", UI.bossFrame, "BOTTOMRIGHT", 0, UI._bottomInset)

    if UI.titleTab then
        UI.titleTab:ClearAllPoints()
        UI.titleTab:SetPoint("TOPLEFT", UI.bossFrame, "TOPLEFT", 0, 0)
        UI.titleTab:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPRIGHT", 0, 0)
    end

    if UI.totalFrame then
        UI.totalFrame:ClearAllPoints()
        UI.totalFrame:SetPoint("TOPLEFT", UI.st.frame, "BOTTOMLEFT", 0, 0)
        UI.totalFrame:SetPoint("BOTTOMRIGHT", UI.bossFrame, "BOTTOMRIGHT", 0, 0)
    end

    UI._rightInset = GetScrollBarInset(UI.st)
    UI._modelWidth = GetModelColumnWidth()
    local width = UI.st.frame:GetWidth() or 1
    local available = math.max(width - UI._rightInset, 1)
    local splitMin = Const.SPLITS_COL_MIN

    local minDelta = splitMin.NUM
    UI._pbWidth = Util.Clamp(UI._pbWidth, splitMin.NUM,
        math.max(available - (UI._modelWidth + splitMin.BOSS + UI._splitWidth + minDelta), splitMin.NUM))
    UI._splitWidth = Util.Clamp(UI._splitWidth, splitMin.NUM,
        math.max(available - (UI._modelWidth + splitMin.BOSS + UI._pbWidth + minDelta), splitMin.NUM))
    UI._deltaWidth = Util.Clamp(UI._deltaWidth, minDelta,
        math.max(available - (UI._modelWidth + splitMin.BOSS + UI._pbWidth + UI._splitWidth), minDelta))
    local bossWidth = math.max(available - (UI._modelWidth + UI._pbWidth + UI._splitWidth + UI._deltaWidth),
        splitMin.BOSS)

    if UI.killCountCounterText and UI.killCountText then
        local counterWidth = math.max(UI.killCountCounterText:GetStringWidth() or 0, 36)
        UI.killCountCounterText:SetWidth(counterWidth)
        UI.killCountText:SetWidth(math.max(bossWidth - counterWidth - 6, 1))
    end

    UI.cols[1].width = bossWidth
    UI.cols[2].width = UI._pbWidth
    UI.cols[3].width = UI._splitWidth
    UI.cols[4].width = UI._deltaWidth

    if UI.st.SetDisplayCols then
        UI.st:SetDisplayCols(UI.cols)
    else
        UI.st.cols = UI.cols
    end

    local height = UI.st.frame:GetHeight() or 1
    local rowHeight = 24
    local displayRows = math.floor(height / rowHeight)
    if displayRows < 1 then
        displayRows = 1
    end

    if UI.st.SetDisplayRows then
        UI.st:SetDisplayRows(displayRows, rowHeight)
    end
    if UI.st.Refresh then
        UI.st:Refresh()
    end

    local totalFrame = UI.totalFrame
    if totalFrame then
        local rightInset = UI._rightInset + 4

        UI.totalDelta:ClearAllPoints()
        UI.totalDelta:SetPoint("RIGHT", totalFrame, "RIGHT", -rightInset, 0)
        UI.totalDelta:SetWidth(UI._deltaWidth)
        UI.totalDelta:SetJustifyH("RIGHT")

        UI.totalSplit:ClearAllPoints()
        UI.totalSplit:SetPoint("RIGHT", UI.totalDelta, "LEFT", 0, 0)
        UI.totalSplit:SetWidth(UI._splitWidth)
        UI.totalSplit:SetJustifyH("RIGHT")

        UI.totalPB:ClearAllPoints()
        UI.totalPB:SetPoint("RIGHT", UI.totalSplit, "LEFT", 0, 0)
        UI.totalPB:SetWidth(UI._pbWidth)
        UI.totalPB:SetJustifyH("RIGHT")
    end

    if UI._colGrips then
        local xBossRight = bossWidth
        local xPBRight = bossWidth + UI._pbWidth
        local xSplitRight = bossWidth + UI._pbWidth + UI._splitWidth
        local bottom = -Const.HEADER_H

        UI._colGrips[1]:ClearAllPoints()
        UI._colGrips[1]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xBossRight - Const.GRIP_HALFWIDTH, 0)
        UI._colGrips[1]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xBossRight + Const.GRIP_HALFWIDTH, bottom)

        UI._colGrips[2]:ClearAllPoints()
        UI._colGrips[2]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xPBRight - Const.GRIP_HALFWIDTH, 0)
        UI._colGrips[2]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xPBRight + Const.GRIP_HALFWIDTH, bottom)

        UI._colGrips[3]:ClearAllPoints()
        UI._colGrips[3]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xSplitRight - Const.GRIP_HALFWIDTH, 0)
        UI._colGrips[3]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xSplitRight + Const.GRIP_HALFWIDTH, bottom)
    end
end

local function SetupSizeGrip(ownerFrame, onChanged)
    return ResizeGrip.CreateFrameGrip(ownerFrame, onChanged)
end

local function BeginColDrag(which, startX)
    UI._colDrag = {
        which = which,
        startX = startX,
        pb = UI._pbWidth,
        split = UI._splitWidth,
        delta = UI._deltaWidth,
    }
end

local function EndColDrag()
    UI._colDrag = nil
    SaveColWidths()
end

local function UpdateColDrag()
    if not UI._colDrag or not UI.st or not UI.st.frame then
        return
    end

    local curX = GetCursorPosition() / UI.st.frame:GetEffectiveScale()
    local dx = curX - UI._colDrag.startX
    local available = (UI.st.frame:GetWidth() or 0) - UI._rightInset
    local splitMin = Const.SPLITS_COL_MIN

    if UI._colDrag.which == 1 then
        local maxPB = math.max(splitMin.NUM,
            available - (UI._modelWidth + UI._splitWidth + UI._deltaWidth + splitMin.BOSS))
        UI._pbWidth = Util.Clamp(UI._colDrag.pb - dx, splitMin.NUM, math.min(Const.COL_MAX_PB_SPLIT, maxPB))
    elseif UI._colDrag.which == 2 then
        UI._pbWidth = Util.Clamp(UI._colDrag.pb + dx, splitMin.NUM, Const.COL_MAX_PB_SPLIT)
        UI._splitWidth = Util.Clamp(UI._colDrag.split - dx, splitMin.NUM, Const.COL_MAX_PB_SPLIT)
    elseif UI._colDrag.which == 3 then
        local minDelta = math.max(splitMin.NUM, splitMin.DELTA_TITLE)
        UI._splitWidth = Util.Clamp(UI._colDrag.split + dx, splitMin.NUM, Const.COL_MAX_PB_SPLIT)
        UI._deltaWidth = Util.Clamp(UI._colDrag.delta - dx, minDelta, Const.COL_MAX_DELTA)
    end

    ApplyTableLayout()
end

local function MakeGrip(parent, which)
    local grip = ResizeGrip.CreateColumnGrip(
        parent,
        10,
        14,
        function()
            local x = GetCursorPosition() / (UI.st.frame:GetEffectiveScale() or 1)
            BeginColDrag(which, x)
        end,
        UpdateColDrag,
        function()
            EndColDrag()
        end,
        function()
            SetCursor("UI_RESIZE_CURSOR")
        end,
        function()
            ResetCursor()
        end
    )
    grip:SetFrameStrata("HIGH")
    grip:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)

    UI.ApplyThinSeparator(grip)

    return grip
end

local function EnsureColGrips()
    if UI._colGrips or not UI.st or not UI.st.frame then
        return
    end
    UI._colGrips = {
        MakeGrip(UI.st.frame, 1),
        MakeGrip(UI.st.frame, 2),
        MakeGrip(UI.st.frame, 3),
    }
end

UI.GetUISaved = GetUISaved
UI.SaveFrameGeom = SaveFrameGeom
UI.RestoreFrameGeom = RestoreFrameGeom
UI.SaveColWidths = SaveColWidths
UI.RestoreColWidths = RestoreColWidths
UI.GetScrollBarInset = GetScrollBarInset
UI.GetModelColumnWidth = GetModelColumnWidth
UI.ApplyTableLayout = ApplyTableLayout
UI.SetupSizeGrip = SetupSizeGrip
UI.BeginColDrag = BeginColDrag
UI.EndColDrag = EndColDrag
UI.UpdateColDrag = UpdateColDrag
UI.MakeGrip = MakeGrip
UI.EnsureColGrips = EnsureColGrips
