local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Const = NS.Const
local ResizeGrip = UI.Templates.ResizeGrip
local GetUISaved
local LAYOUT_SCHEMA_VERSION = 1
local VALID_POINTS = {
    TOP = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOM = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function NormalizeLayoutNumber(value)
    value = tonumber(value)
    if not value then
        return nil
    end
    return Util.RoundNumber(value, 3)
end

local function GetParentSize()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 1080
    return tonumber(width) or 1920, tonumber(height) or 1080
end

local function GetFrameLayoutRules(frameKey)
    if frameKey == "boss" then
        return {
            defaultW = 520,
            defaultH = 320,
            minW = 450,
            minH = Const.SPLITS_LAYOUT.MIN_HEIGHT,
            maxW = 1400,
            maxH = 1000,
        }
    elseif frameKey == "history" then
        return {
            defaultW = 850,
            defaultH = 500,
            minW = 850,
            minH = 200,
            maxW = 2500,
            maxH = 1600,
        }
    elseif frameKey == "timer" then
        return {
            defaultW = 140,
            defaultH = 50,
            minW = 120,
            minH = 40,
            maxW = 900,
            maxH = 300,
        }
    end

    return {
        defaultW = 200,
        defaultH = 100,
        minW = 100,
        minH = 40,
        maxW = 2500,
        maxH = 1600,
    }
end

local function BuildFrameSnapshot(frameKey, frame)
    local rules = GetFrameLayoutRules(frameKey)
    local point, _, relPoint, xOfs, yOfs = frame:GetPoint(1)
    return {
        schemaVersion = LAYOUT_SCHEMA_VERSION,
        point = VALID_POINTS[point] and point or "CENTER",
        relPoint = VALID_POINTS[relPoint] and relPoint or "CENTER",
        x = NormalizeLayoutNumber(xOfs) or 0,
        y = NormalizeLayoutNumber(yOfs) or 0,
        w = NormalizeLayoutNumber(frame:GetWidth()) or rules.defaultW,
        h = NormalizeLayoutNumber(frame:GetHeight()) or rules.defaultH,
        clampedToScreen = frame.IsClampedToScreen and frame:IsClampedToScreen() or false,
        minW = NormalizeLayoutNumber(rules.minW),
        minH = NormalizeLayoutNumber(rules.minH),
        maxW = NormalizeLayoutNumber(rules.maxW),
        maxH = NormalizeLayoutNumber(rules.maxH),
    }
end

local function NormalizeFrameSnapshot(frameKey, snapshot, fallback)
    local rules = GetFrameLayoutRules(frameKey)
    snapshot = type(snapshot) == "table" and Util.CopyTable(snapshot) or {}
    fallback = type(fallback) == "table" and fallback or {}

    local function pick(key, default)
        local value = snapshot[key]
        if value == nil then
            value = fallback[key]
        end
        if value == nil then
            value = default
        end
        return value
    end

    local normalized = {
        schemaVersion = LAYOUT_SCHEMA_VERSION,
        point = VALID_POINTS[pick("point", "CENTER")] and pick("point", "CENTER") or "CENTER",
        relPoint = VALID_POINTS[pick("relPoint", "CENTER")] and pick("relPoint", "CENTER") or "CENTER",
        clampedToScreen = pick("clampedToScreen", true) and true or false,
        minW = NormalizeLayoutNumber(pick("minW", rules.minW)) or rules.minW,
        minH = NormalizeLayoutNumber(pick("minH", rules.minH)) or rules.minH,
        maxW = NormalizeLayoutNumber(pick("maxW", rules.maxW)) or rules.maxW,
        maxH = NormalizeLayoutNumber(pick("maxH", rules.maxH)) or rules.maxH,
    }

    local width = NormalizeLayoutNumber(pick("w", rules.defaultW)) or rules.defaultW
    local height = NormalizeLayoutNumber(pick("h", rules.defaultH)) or rules.defaultH
    normalized.w = Util.Clamp(width, normalized.minW, normalized.maxW)
    normalized.h = Util.Clamp(height, normalized.minH, normalized.maxH)

    local parentW, parentH = GetParentSize()
    local x = NormalizeLayoutNumber(pick("x", 0)) or 0
    local y = NormalizeLayoutNumber(pick("y", 0)) or 0
    local maxX = math.max(0, (parentW - normalized.w) / 2)
    local maxY = math.max(0, (parentH - normalized.h) / 2)
    normalized.x = Util.Clamp(x, -maxX, maxX)
    normalized.y = Util.Clamp(y, -maxY, maxY)

    return normalized
end

local function NormalizeUILayoutSnapshot(ui)
    ui = type(ui) == "table" and ui or {}
    ui.frames = ui.frames or {}
    ui.cols = ui.cols or {}
    ui.historyCols = ui.historyCols or {}
    ui.preview = ui.preview or false
    ui.layoutSchemaVersion = LAYOUT_SCHEMA_VERSION

    local defaults = NS.FactoryDefaults and NS.FactoryDefaults.ui and NS.FactoryDefaults.ui.frames or {}
    ui.frames.boss = NormalizeFrameSnapshot("boss", ui.frames.boss, defaults.boss)
    ui.frames.history = NormalizeFrameSnapshot("history", ui.frames.history, defaults.history)
    if ui.frames.timer or defaults.timer then
        ui.frames.timer = NormalizeFrameSnapshot("timer", ui.frames.timer, defaults.timer)
    end

    return ui
end

local function GetNormalizedUILayoutSnapshot(source)
    return NormalizeUILayoutSnapshot(Util.CopyTable(source or GetUISaved() or {}))
end

local function GetEffectiveFrameGeometry(frameKey)
    local frame
    if frameKey == "boss" then
        frame = UI.bossFrame
    elseif frameKey == "history" then
        frame = UI.history and UI.history.frame
    elseif frameKey == "timer" then
        frame = UI.timerFrame
    end

    if not frame then
        return nil
    end

    return BuildFrameSnapshot(frameKey, frame)
end

GetUISaved = function()
    if not NS.DB then
        return nil
    end
    NS.DB.ui = NS.DB.ui or {}
    NormalizeUILayoutSnapshot(NS.DB.ui)
    return NS.DB.ui
end

local function SaveFrameGeom(frameKey, frame)
    local ui = GetUISaved()
    if not ui then
        return
    end

    ui.frames[frameKey] = BuildFrameSnapshot(frameKey, frame)
end

local function RestoreFrameGeom(frameKey, frame, defaultW, defaultH)
    local ui = GetUISaved()
    local fallback = (NS.FactoryDefaults and NS.FactoryDefaults.ui and NS.FactoryDefaults.ui.frames and
        NS.FactoryDefaults.ui.frames[frameKey]) or { w = defaultW, h = defaultH, point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
    local saved = ui and ui.frames and ui.frames[frameKey] or nil
    local hasSaved = type(saved) == "table" and next(saved) ~= nil
    local normalized = NormalizeFrameSnapshot(frameKey, saved, fallback)
    frame:ClearAllPoints()
    frame:SetSize(normalized.w or defaultW, normalized.h or defaultH)
    frame:SetPoint(normalized.point, UIParent, normalized.relPoint, normalized.x or 0, normalized.y or 0)
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(normalized.clampedToScreen)
    end
    Util.ApplyResizeBounds(frame, normalized.minW, normalized.minH, normalized.maxW, normalized.maxH)
    if ui and ui.frames then
        ui.frames[frameKey] = normalized
    end
    return hasSaved
end

local function SaveColWidths()
    local ui = GetUISaved()
    if not ui then
        return
    end
    ui.cols.pb = NormalizeLayoutNumber(UI._pbWidth)
    ui.cols.split = NormalizeLayoutNumber(UI._splitWidth)
    ui.cols.delta = NormalizeLayoutNumber(UI._deltaWidth)
end

local function SaveHistoryColWidths()
    local ui = GetUISaved()
    if not ui or not UI.history or not UI.history.colWidths then
        return
    end
    ui.historyCols = ui.historyCols or {}
    for key, value in pairs(UI.history.colWidths) do
        ui.historyCols[key] = NormalizeLayoutNumber(value)
    end
end

local function CaptureCurrentLayout()
    GetUISaved()
    if UI.timerFrame then
        SaveFrameGeom("timer", UI.timerFrame)
    end
    if UI.bossFrame then
        SaveFrameGeom("boss", UI.bossFrame)
    end
    if UI.history and UI.history.frame then
        SaveFrameGeom("history", UI.history.frame)
    end
    SaveColWidths()
    SaveHistoryColWidths()
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
    return UI._rightInset or 2
end

local function GetBossTableDataCount()
    if UI.st and UI.st.filtered then
        return #UI.st.filtered
    end
    return #(UI.data or {})
end

local function GetBossScrollBarWidth()
    local sb = (UI.st and UI.st.scrollframe and UI.st.scrollframe.ScrollBar) or (UI.st and UI.st.frame and UI.st.frame.ScrollBar) or
        (UI.st and UI.st.scrollbar)
    local width = (sb and sb.GetWidth and sb:GetWidth()) or 10
    return math.max(10, math.floor(width))
end

local function SetBossScrollLaneVisible(visible, laneWidth)
    local lane = UI.scrollLane
    local scrollbar = UI.st and UI.st.scrollframe and _G[UI.st.scrollframe:GetName() .. "ScrollBar"]
    local trough = scrollbar and scrollbar._ssTrough
    local troughBorder = scrollbar and scrollbar._ssTroughBorder

    if lane then
        lane:ClearAllPoints()
        if visible then
            lane:SetPoint("TOPRIGHT", UI.st.frame, "TOPRIGHT", 0, 0)
            lane:SetPoint("BOTTOMRIGHT", UI.st.frame, "BOTTOMRIGHT", 0, 0)
            lane:SetWidth(laneWidth)
            lane:Show()
        else
            lane:Hide()
        end
    end

    if scrollbar then
        if visible then
            scrollbar:Show()
        else
            scrollbar:Hide()
        end
    end
    if trough then
        if visible then
            trough:Show()
        else
            trough:Hide()
        end
    end
    if troughBorder then
        if visible then
            troughBorder:Show()
        else
            troughBorder:Hide()
        end
    end
end

local function ApplyTableLayout()
    if not UI.bossFrame or not UI.st or not UI.cols then
        return
    end

    UI._topInset = Const.SPLITS_LAYOUT.TOP_BAR_H + 2
    UI._bottomInset = 24 + 2

    UI.st.frame:ClearAllPoints()
    UI.st.frame:SetPoint("TOPLEFT", UI.bossFrame, "TOPLEFT", 0, -UI._topInset)
    UI.st.frame:SetPoint("BOTTOMRIGHT", UI.bossFrame, "BOTTOMRIGHT", 0, UI._bottomInset)

    local height = UI.st.frame:GetHeight() or 1
    local rowHeight = 24
    local displayRows = math.max(1, math.floor(height / rowHeight))
    local laneWidth = GetBossScrollBarWidth() + 6
    local needsScroll = GetBossTableDataCount() > displayRows
    UI._bossScrollLaneVisible = needsScroll
    UI._bossScrollLaneWidth = needsScroll and laneWidth or 0
    UI._rightInset = 0

    if UI.st.scrollframe then
        UI.st.scrollframe:ClearAllPoints()
        UI.st.scrollframe:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", 0, -4)
        UI.st.scrollframe:SetPoint("BOTTOMRIGHT", UI.st.frame, "BOTTOMRIGHT", -(needsScroll and laneWidth or 0), 3)
    end

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

    UI._modelWidth = GetModelColumnWidth()
    local width = UI.st.frame:GetWidth() or 1
    local available = math.max(width, 1)
    local splitMin = Const.SPLITS_COL_MIN
    local globalMin = splitMin.GLOBAL or 1
    local bossMin = math.max(globalMin, splitMin.BOSS or globalMin)
    local pbMin = math.max(globalMin, splitMin.PB or globalMin)
    local splitColMin = math.max(globalMin, splitMin.SPLIT or globalMin)
    local deltaMin = math.max(globalMin, splitMin.DIFFERENCE or globalMin)

    UI._pbWidth = Util.Clamp(UI._pbWidth, pbMin,
        math.max(available - (UI._modelWidth + bossMin + UI._splitWidth + deltaMin), pbMin))
    UI._splitWidth = Util.Clamp(UI._splitWidth, splitColMin,
        math.max(available - (UI._modelWidth + bossMin + UI._pbWidth + deltaMin), splitColMin))
    UI._deltaWidth = Util.Clamp(UI._deltaWidth, deltaMin,
        math.max(available - (UI._modelWidth + bossMin + UI._pbWidth + UI._splitWidth), deltaMin))
    local bossWidth = math.max(available - (UI._modelWidth + UI._pbWidth + UI._splitWidth + UI._deltaWidth),
        bossMin)

    if UI.killCountCounterText and UI.killCountText then
        local counterWidth = math.max(UI.killCountCounterText:GetStringWidth() or 0, 36)
        UI.killCountCounterText:SetWidth(counterWidth)
        UI.killCountText:SetWidth(math.max(bossWidth - counterWidth - 6, 1))
    end

    UI.cols[1].width = bossWidth
    UI.cols[2].width = UI._pbWidth
    UI.cols[3].width = UI._splitWidth
    UI.cols[4].width = UI._deltaWidth

    if UI.customBossHeaders then
        local headerLeft = 0
        for i = 1, #UI.customBossHeaders do
            local header = UI.customBossHeaders[i]
            local colWidth = (UI.cols[i] and UI.cols[i].width) or 0
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", UI.titleTab, "TOPLEFT", headerLeft, 0)
            header:SetPoint("BOTTOMLEFT", UI.titleTab, "BOTTOMLEFT", headerLeft, 0)
            header:SetWidth(colWidth)
            headerLeft = headerLeft + colWidth
        end
    end

    if UI.st.SetDisplayCols then
        UI.st:SetDisplayCols(UI.cols)
    else
        UI.st.cols = UI.cols
    end

    if UI.st.SetDisplayRows then
        UI.st:SetDisplayRows(displayRows, rowHeight)
    end
    if UI.st.Refresh then
        UI.st:Refresh()
    end

    SetBossScrollLaneVisible(needsScroll, laneWidth)

    local totalFrame = UI.totalFrame
    if totalFrame then
        local xBossRight = bossWidth
        local xPBLeft = xBossRight
        local xSplitLeft = xPBLeft + UI._pbWidth
        local xDeltaLeft = xSplitLeft + UI._splitWidth

        UI.totalDelta:ClearAllPoints()
        UI.totalDelta:SetPoint("CENTER", totalFrame, "LEFT", xDeltaLeft + (UI._deltaWidth / 2), 0)
        UI.totalDelta:SetWidth(UI._deltaWidth)
        UI.totalDelta:SetJustifyH("CENTER")

        UI.totalSplit:ClearAllPoints()
        UI.totalSplit:SetPoint("CENTER", totalFrame, "LEFT", xSplitLeft + (UI._splitWidth / 2), 0)
        UI.totalSplit:SetWidth(UI._splitWidth)
        UI.totalSplit:SetJustifyH("CENTER")

        UI.totalPB:ClearAllPoints()
        UI.totalPB:SetPoint("CENTER", totalFrame, "LEFT", xPBLeft + (UI._pbWidth / 2), 0)
        UI.totalPB:SetWidth(UI._pbWidth)
        UI.totalPB:SetJustifyH("CENTER")
    end

    if UI._colGrips then
        local xBossRight = bossWidth
        local xPBRight = bossWidth + UI._pbWidth
        local xSplitRight = bossWidth + UI._pbWidth + UI._splitWidth
        local bottom = -Const.SPLITS_LAYOUT.HEADER_H

        UI._colGrips[1]:ClearAllPoints()
        UI._colGrips[1]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xBossRight - Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, 0)
        UI._colGrips[1]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xBossRight + Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, bottom)

        UI._colGrips[2]:ClearAllPoints()
        UI._colGrips[2]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xPBRight - Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, 0)
        UI._colGrips[2]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xPBRight + Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, bottom)

        UI._colGrips[3]:ClearAllPoints()
        UI._colGrips[3]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xSplitRight - Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, 0)
        UI._colGrips[3]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xSplitRight + Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, bottom)
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
    local available = UI.st.frame:GetWidth() or 0
    local splitMin = Const.SPLITS_COL_MIN
    local globalMin = splitMin.GLOBAL or 1
    local bossMin = math.max(globalMin, splitMin.BOSS or globalMin)
    local pbMin = math.max(globalMin, splitMin.PB or globalMin)
    local splitColMin = math.max(globalMin, splitMin.SPLIT or globalMin)
    local deltaMin = math.max(globalMin, splitMin.DIFFERENCE or globalMin)

    if UI._colDrag.which == 1 then
        local maxPB = math.max(pbMin,
            available - (UI._modelWidth + UI._splitWidth + UI._deltaWidth + bossMin))
        UI._pbWidth = Util.Clamp(UI._colDrag.pb - dx, pbMin, math.min(Const.SPLITS_COL_MAX.PB_SPLIT, maxPB))
    elseif UI._colDrag.which == 2 then
        UI._pbWidth = Util.Clamp(UI._colDrag.pb + dx, pbMin, Const.SPLITS_COL_MAX.PB_SPLIT)
        UI._splitWidth = Util.Clamp(UI._colDrag.split - dx, splitColMin, Const.SPLITS_COL_MAX.PB_SPLIT)
    elseif UI._colDrag.which == 3 then
        UI._splitWidth = Util.Clamp(UI._colDrag.split + dx, splitColMin, Const.SPLITS_COL_MAX.PB_SPLIT)
        UI._deltaWidth = Util.Clamp(UI._colDrag.delta - dx, deltaMin, Const.SPLITS_COL_MAX.DELTA)
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
UI.NormalizeFrameSnapshot = NormalizeFrameSnapshot
UI.NormalizeUILayoutSnapshot = NormalizeUILayoutSnapshot
UI.GetNormalizedUILayoutSnapshot = GetNormalizedUILayoutSnapshot
UI.GetEffectiveFrameGeometry = GetEffectiveFrameGeometry
UI.GetScrollBarInset = GetScrollBarInset
UI.GetModelColumnWidth = GetModelColumnWidth
UI.ApplyTableLayout = ApplyTableLayout
UI.CaptureCurrentLayout = CaptureCurrentLayout
UI.SetupSizeGrip = SetupSizeGrip
UI.BeginColDrag = BeginColDrag
UI.EndColDrag = EndColDrag
UI.UpdateColDrag = UpdateColDrag
UI.MakeGrip = MakeGrip
UI.EnsureColGrips = EnsureColGrips
