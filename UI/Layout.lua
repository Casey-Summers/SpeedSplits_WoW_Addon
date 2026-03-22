local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Const = NS.Const
local ResizeGrip = UI.Templates.ResizeGrip

local Layout = {}
local ApplyFrameLayout
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
local FRAME_RULES = {
    timer = {
        minWidth = 120,
        minHeight = 40,
        maxWidth = 900,
        maxHeight = 300,
        applyShown = false,
    },
    boss = {
        minWidth = 450,
        minHeight = Const.SPLITS_LAYOUT.MIN_HEIGHT,
        maxWidth = 1400,
        maxHeight = 1000,
        applyShown = false,
        hasColumns = true,
    },
    history = {
        minWidth = 850,
        minHeight = 200,
        maxWidth = 2500,
        maxHeight = 1600,
        applyShown = true,
        hasColumns = true,
    },
}
local FRAME_ORDER = { "timer", "boss", "history" }

local function RoundNumber(value)
    value = tonumber(value)
    if value == nil then
        return nil
    end
    return Util.RoundNumber(value, 3)
end

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end

    local result = {}
    for key, value in pairs(source) do
        result[key] = DeepCopy(value)
    end
    return result
end

local function MergeDefaults(target, defaults)
    target = type(target) == "table" and target or {}
    defaults = type(defaults) == "table" and defaults or {}

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = DeepCopy(value)
            else
                MergeDefaults(target[key], value)
            end
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function GetFactoryLayout()
    return DeepCopy((NS.FactoryDefaults and NS.FactoryDefaults.ui) or { frames = {} })
end

local function SanitizePoint(value, fallback)
    value = tostring(value or "")
    if VALID_POINTS[value] then
        return value
    end
    return VALID_POINTS[fallback] and fallback or "CENTER"
end

local function GetFrameDefaults(frameKey)
    local defaults = GetFactoryLayout()
    return (defaults.frames and defaults.frames[frameKey]) or {}
end

local function GetFrameRules(frameKey)
    return FRAME_RULES[frameKey] or {
        minWidth = 100,
        minHeight = 40,
        maxWidth = 2500,
        maxHeight = 1600,
        applyShown = true,
    }
end

local function NormalizeBossColumns(source, fallback)
    source = type(source) == "table" and source or {}
    fallback = type(fallback) == "table" and fallback or {}

    local defaults = Const.SPLITS_DEFAULTS and Const.SPLITS_DEFAULTS.BOSS_COLUMNS or {}
    local pb = RoundNumber(source.pb) or RoundNumber(fallback.pb) or defaults.pb
    local split = RoundNumber(source.split) or RoundNumber(fallback.split) or defaults.split
    local diff = RoundNumber(source.diff or source.delta) or RoundNumber(fallback.diff or fallback.delta) or
        defaults.diff

    return {
        pb = math.max(Const.SPLITS_COL_MIN.PB or 1, pb),
        split = math.max(Const.SPLITS_COL_MIN.SPLIT or 1, split),
        diff = math.max(Const.SPLITS_COL_MIN.DIFFERENCE or 1, diff),
    }
end

local function NormalizeHistoryColumns(source, fallback)
    source = type(source) == "table" and source or {}
    fallback = type(fallback) == "table" and fallback or {}

    local defaults = Const.SPLITS_DEFAULTS and Const.SPLITS_DEFAULTS.HISTORY_COLUMNS or {}
    return {
        date = math.max(50, RoundNumber(source.date) or RoundNumber(fallback.date) or defaults.date),
        dungeon = math.max(100,
            RoundNumber(source.dungeon) or RoundNumber(fallback.dungeon) or defaults.dungeon),
        expansion = math.max(50,
            RoundNumber(source.expansion) or RoundNumber(fallback.expansion) or defaults.expansion),
        result = math.max(50,
            RoundNumber(source.result) or RoundNumber(fallback.result) or defaults.result),
        mode = math.max(50, RoundNumber(source.mode) or RoundNumber(fallback.mode) or defaults.mode),
        time = math.max(50, RoundNumber(source.time) or RoundNumber(fallback.time) or defaults.time),
        diff = math.max(50, RoundNumber(source.diff) or RoundNumber(fallback.diff) or defaults.diff),
        delete = math.max(30,
            RoundNumber(source.delete) or RoundNumber(fallback.delete) or defaults.delete),
    }
end

local function NormalizeFrameNode(frameKey, source, legacyColumns)
    local defaults = GetFrameDefaults(frameKey)
    local rules = GetFrameRules(frameKey)

    source = type(source) == "table" and source or {}

    local width = RoundNumber(source.width or source.w) or RoundNumber(defaults.width or defaults.w) or rules.minWidth
    local height = RoundNumber(source.height or source.h) or RoundNumber(defaults.height or defaults.h) or rules.minHeight

    local node = {
        point = SanitizePoint(source.point, defaults.point or "CENTER"),
        relativePoint = SanitizePoint(source.relativePoint or source.relPoint, defaults.relativePoint or defaults.relPoint or "CENTER"),
        x = RoundNumber(source.x) or RoundNumber(defaults.x) or 0,
        y = RoundNumber(source.y) or RoundNumber(defaults.y) or 0,
        width = Util.Clamp(width, rules.minWidth, rules.maxWidth),
        height = Util.Clamp(height, rules.minHeight, rules.maxHeight),
        scale = math.max(0.1, RoundNumber(source.scale) or RoundNumber(defaults.scale) or 1),
        shown = source.shown,
    }

    if node.shown == nil then
        node.shown = defaults.shown ~= false
    end

    if frameKey == "boss" then
        node.columns = NormalizeBossColumns(source.columns, legacyColumns or defaults.columns)
    elseif frameKey == "history" then
        node.columns = NormalizeHistoryColumns(source.columns, legacyColumns or defaults.columns)
    end

    return node
end

local function NormalizeLayoutState(source)
    local defaults = GetFactoryLayout()
    local normalized = {
        preview = type(source) == "table" and source.preview == true or defaults.preview == true,
        frames = {},
    }
    local frames = type(source) == "table" and source.frames or nil
    local legacyBossColumns = type(source) == "table" and source.cols or nil
    local legacyHistoryColumns = type(source) == "table" and source.historyCols or nil

    for _, frameKey in ipairs(FRAME_ORDER) do
        local legacyColumns
        if frameKey == "boss" then
            legacyColumns = legacyBossColumns
        elseif frameKey == "history" then
            legacyColumns = legacyHistoryColumns
        end
        normalized.frames[frameKey] = NormalizeFrameNode(frameKey, frames and frames[frameKey], legacyColumns)
    end

    MergeDefaults(normalized, defaults)
    return normalized
end

local function GetRegistry(frameKey)
    UI._managedFrames = UI._managedFrames or {}
    if not UI._managedFrames[frameKey] then
        UI._managedFrames[frameKey] = { key = frameKey }
    end
    return UI._managedFrames[frameKey]
end

local function ResolveFrameForKey(frameKey)
    local registry = UI._managedFrames and UI._managedFrames[frameKey]
    if registry and registry.frame then
        return registry.frame
    end

    if frameKey == "timer" then
        return UI.timerFrame
    elseif frameKey == "boss" then
        return UI.bossFrame
    elseif frameKey == "history" then
        return UI.history and UI.history.frame or nil
    end

    return nil
end

local function InitializeDefaults()
    if not NS.DB then
        return nil
    end

    NS.DB.ui = NormalizeLayoutState(NS.DB.ui)
    NS.DB.DefaultLayout = NS.DB.DefaultLayout or {}
    if NS.DB.DefaultLayout.ui then
        NS.DB.DefaultLayout.ui = NormalizeLayoutState(NS.DB.DefaultLayout.ui)
    else
        NS.DB.DefaultLayout.ui = DeepCopy(GetFactoryLayout())
    end
    return NS.DB.ui
end

local function GetUISaved()
    return InitializeDefaults()
end

local function GetSavedFrameLayout(frameKey)
    local ui = GetUISaved()
    return ui and ui.frames and ui.frames[frameKey] or nil
end

local function SaveColumnWidths(frameKey, columns)
    local layout = GetSavedFrameLayout(frameKey)
    if not layout then
        return
    end

    if frameKey == "boss" then
        layout.columns = NormalizeBossColumns(columns, layout.columns)
    elseif frameKey == "history" then
        layout.columns = NormalizeHistoryColumns(columns, layout.columns)
    end
end

local function RestoreColWidths()
    local layout = GetSavedFrameLayout("boss")
    local columns = (layout and layout.columns) or NormalizeBossColumns()
    UI._pbWidth = columns.pb
    UI._splitWidth = columns.split
    UI._deltaWidth = columns.diff
end

local function GetEffectiveFrameGeometry(frameKey)
    local frame = ResolveFrameForKey(frameKey)
    if not frame then
        return nil
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    return {
        point = SanitizePoint(point, "CENTER"),
        relativePoint = SanitizePoint(relativePoint, "CENTER"),
        x = RoundNumber(x) or 0,
        y = RoundNumber(y) or 0,
        width = RoundNumber(frame:GetWidth()) or 0,
        height = RoundNumber(frame:GetHeight()) or 0,
        scale = RoundNumber(frame:GetScale()) or 1,
        shown = frame:IsShown(),
    }
end

local function SaveFrameLayout(frameKey, frame)
    frame = frame or ResolveFrameForKey(frameKey)
    local layout = GetSavedFrameLayout(frameKey)
    if not frame or not layout then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    layout.point = SanitizePoint(point, layout.point)
    layout.relativePoint = SanitizePoint(relativePoint, layout.relativePoint)
    layout.x = RoundNumber(x) or 0
    layout.y = RoundNumber(y) or 0
    layout.width = RoundNumber(frame:GetWidth()) or layout.width
    layout.height = RoundNumber(frame:GetHeight()) or layout.height
    layout.scale = math.max(0.1, RoundNumber(frame:GetScale()) or layout.scale or 1)
    layout.shown = frame:IsShown()

    if frameKey == "boss" then
        SaveColumnWidths(frameKey, {
            pb = UI._pbWidth,
            split = UI._splitWidth,
            diff = UI._deltaWidth,
        })
    elseif frameKey == "history" and UI.history and UI.history.colWidths then
        SaveColumnWidths(frameKey, UI.history.colWidths)
    end
end

local function RestoreFrameGeom(frameKey, frame)
    local rawSaved = NS.DB and NS.DB.ui and NS.DB.ui.frames and NS.DB.ui.frames[frameKey]
    local hasSaved = type(rawSaved) == "table" and next(rawSaved) ~= nil
    local layout = GetSavedFrameLayout(frameKey)
    if not layout then
        return false
    end

    ApplyFrameLayout(frame, layout, frameKey)
    return hasSaved
end

local function ApplyColumnWidths(frameKey, frame, layout)
    if frameKey == "boss" then
        local columns = NormalizeBossColumns(layout.columns, GetFrameDefaults("boss").columns)
        layout.columns = columns
        UI._pbWidth = columns.pb
        UI._splitWidth = columns.split
        UI._deltaWidth = columns.diff
        if UI.ApplyTableLayout and UI.st and frame == UI.bossFrame then
            UI.ApplyTableLayout()
        end
    elseif frameKey == "history" then
        local columns = NormalizeHistoryColumns(layout.columns, GetFrameDefaults("history").columns)
        layout.columns = columns
        UI.history = UI.history or {}
        UI.history.colWidths = DeepCopy(columns)
        UI.history.resolvedColWidths = DeepCopy(columns)
        if UI.History_ApplyTableLayout and UI.history and UI.history.frame and frame == UI.history.frame then
            UI.History_ApplyTableLayout()
        end
    end
end

ApplyFrameLayout = function(frame, layout, frameKey)
    if not frame or not layout then
        return
    end

    local rules = GetFrameRules(frameKey)

    frame:SetClampedToScreen(true)
    frame:SetScale(layout.scale or 1)
    frame:SetSize(layout.width, layout.height)
    frame:ClearAllPoints()
    frame:SetPoint(layout.point, UIParent, layout.relativePoint, layout.x, layout.y)
    Util.ApplyResizeBounds(frame, rules.minWidth, rules.minHeight, rules.maxWidth, rules.maxHeight)

    ApplyColumnWidths(frameKey, frame, layout)

    if rules.applyShown then
        if layout.shown == false then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

local function ApplyAllLayouts()
    local ui = GetUISaved()
    if not ui then
        return
    end

    for _, frameKey in ipairs(FRAME_ORDER) do
        local frame = ResolveFrameForKey(frameKey)
        if frame then
            ApplyFrameLayout(frame, ui.frames[frameKey], frameKey)
        end
    end
end

local function CaptureCurrentLayout()
    for _, frameKey in ipairs(FRAME_ORDER) do
        SaveFrameLayout(frameKey)
    end
end

local function ResetFrameToDefaults(frameKey)
    local ui = GetUISaved()
    if not ui or not ui.frames or not ui.frames[frameKey] then
        return
    end

    ui.frames[frameKey] = DeepCopy(GetFrameDefaults(frameKey))
    ApplyAllLayouts()
end

local function ResetAllFramesToDefaults()
    local ui = GetUISaved()
    if not ui then
        return
    end

    local factory = GetFactoryLayout()
    ui.frames = DeepCopy(factory.frames or {})
    ApplyAllLayouts()
end

local function RegisterManagedFrame(frameKey, frame)
    local registry = GetRegistry(frameKey)
    registry.frame = frame
    return registry
end

local function SetFrameShown(frameKey, shown, applyNow)
    local layout = GetSavedFrameLayout(frameKey)
    if not layout then
        return
    end

    layout.shown = shown and true or false

    if applyNow then
        local registry = UI._managedFrames and UI._managedFrames[frameKey]
        if registry and registry.frame then
            if shown then
                registry.frame:Show()
            else
                registry.frame:Hide()
            end
        end
    end
end

local function SaveFrameShown(frameKey, shown)
    local layout = GetSavedFrameLayout(frameKey)
    if not layout then
        return
    end
    layout.shown = shown and true or false
end

local function GetBossTableDataCount()
    if UI.st and UI.st.filtered then
        return #UI.st.filtered
    end
    return #(UI.data or {})
end

local function GetBossScrollBarWidth()
    local sb = (UI.st and UI.st.scrollframe and UI.st.scrollframe.ScrollBar) or
        (UI.st and UI.st.frame and UI.st.frame.ScrollBar) or
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

local function GetModelColumnWidth()
    local showModels = NS.DB and NS.DB.Settings and NS.DB.Settings.showNPCViewModels ~= false
    return showModels and 40 or 0
end

local function GetScrollBarInset()
    return UI._rightInset or 2
end

local function GetNumericMeasureFontString()
    UI._numericMeasureFrame = UI._numericMeasureFrame or CreateFrame("Frame", nil, UIParent)
    if not UI._numericMeasureFrame.fs then
        UI._numericMeasureFrame.fs = UI._numericMeasureFrame:CreateFontString(nil, "OVERLAY")
    end
    return UI._numericMeasureFrame.fs
end

local function MeasureNumericTextWidth(text)
    local fs = GetNumericMeasureFontString()
    NS.ApplyFontToFS(fs, "num")
    fs:SetText(text or "")
    return math.ceil((fs.GetStringWidth and fs:GetStringWidth()) or 0)
end

local function GetAlignedTimeMetrics()
    local metrics = {
        minuteWidth = MeasureNumericTextWidth("88"),
        secondWidth = MeasureNumericTextWidth("88"),
        millisWidth = MeasureNumericTextWidth("888"),
        signWidth = MeasureNumericTextWidth("+"),
        colonWidth = MeasureNumericTextWidth(":"),
        decimalWidth = MeasureNumericTextWidth("."),
        digitWidth = MeasureNumericTextWidth("8"),
    }
    metrics.digitWidth = math.max(1, metrics.digitWidth)
    metrics.symbolPad = (Const.ALIGNED_TIME and Const.ALIGNED_TIME.SYMBOL_PAD) or 1
    metrics.signPad = (Const.ALIGNED_TIME and Const.ALIGNED_TIME.SIGN_PAD) or 2
    return metrics
end

local function BuildAlignedTimeSpec(width, metrics, groupType)
    width = tonumber(width) or 0
    metrics = metrics or GetAlignedTimeMetrics()
    local isDelta = groupType == "delta"
    local signWidth = isDelta and metrics.signWidth or 0
    local minuteWidth = metrics.minuteWidth
    local colonWidth = metrics.colonWidth
    local secondWidth = metrics.secondWidth
    local decimalWidth = metrics.decimalWidth
    local millisWidth = metrics.millisWidth
    local symbolPad = metrics.symbolPad
    local signPad = metrics.signPad
    local decimalCenterX = math.floor((width / 2) + 0.5)
    local decimalLeft = decimalCenterX - (decimalWidth / 2)
    local secondLeft = decimalLeft - symbolPad - secondWidth
    local colonLeft = secondLeft - symbolPad - colonWidth
    local minuteLeft = colonLeft - symbolPad - minuteWidth
    local minuteSignLeft = minuteLeft - signPad - signWidth
    local secondSignLeft = secondLeft - signPad - signWidth
    local millisLeft = decimalLeft + decimalWidth + symbolPad
    local groupLeft = isDelta and math.min(minuteSignLeft, secondSignLeft) or minuteLeft
    local groupWidth = (millisLeft + millisWidth) - groupLeft

    return {
        groupType = isDelta and "delta" or "time",
        hostWidth = width,
        groupWidth = groupWidth,
        groupLeft = groupLeft,
        signMinuteLeft = minuteSignLeft,
        signSecondLeft = secondSignLeft,
        signWidth = signWidth,
        signPad = signPad,
        minuteLeft = minuteLeft,
        minuteBaseWidth = minuteWidth,
        minuteRight = minuteLeft + minuteWidth,
        colonLeft = colonLeft,
        colonWidth = colonWidth,
        secondLeft = secondLeft,
        secondWidth = secondWidth,
        decimalLeft = decimalLeft,
        decimalWidth = decimalWidth,
        decimalCenterX = decimalCenterX,
        millisLeft = millisLeft,
        millisWidth = millisWidth,
        symbolPad = symbolPad,
        digitWidth = metrics.digitWidth,
        rightGutter = UI._rightInset or 0,
        overflowPolicy = "grow_left",
    }
end

local function GetAlignedTimeSpec(key)
    return UI._alignedTimeSpecs and UI._alignedTimeSpecs[key] or nil
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
    UI._bossScrollLaneWidth = laneWidth
    UI._rightInset = laneWidth

    if UI.st.scrollframe then
        UI.st.scrollframe:ClearAllPoints()
        UI.st.scrollframe:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", 0, -4)
        UI.st.scrollframe:SetPoint("BOTTOMRIGHT", UI.st.frame, "BOTTOMRIGHT", -laneWidth, 3)
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
    local available = math.max(width - UI._rightInset, 1)
    local splitMin = Const.SPLITS_COL_MIN
    local globalMin = splitMin.GLOBAL or 1
    local bossMin = math.max(globalMin, splitMin.BOSS or globalMin)
    local pbMin = math.max(globalMin, splitMin.PB or globalMin)
    local splitColMin = math.max(globalMin, splitMin.SPLIT or globalMin)
    local diffMin = math.max(globalMin, splitMin.DIFFERENCE or globalMin)

    UI._pbWidth = Util.Clamp(UI._pbWidth or pbMin, pbMin,
        math.max(available - (UI._modelWidth + bossMin + (UI._splitWidth or splitColMin) + (UI._deltaWidth or diffMin)),
            pbMin))
    UI._splitWidth = Util.Clamp(UI._splitWidth or splitColMin, splitColMin,
        math.max(available - (UI._modelWidth + bossMin + UI._pbWidth + (UI._deltaWidth or diffMin)), splitColMin))
    UI._deltaWidth = Util.Clamp(UI._deltaWidth or diffMin, diffMin,
        math.max(available - (UI._modelWidth + bossMin + UI._pbWidth + UI._splitWidth), diffMin))

    local bossWidth = math.max(available - (UI._modelWidth + UI._pbWidth + UI._splitWidth + UI._deltaWidth), bossMin)

    if UI.killCountCounterText and UI.killCountText then
        local counterWidth = math.max(UI.killCountCounterText:GetStringWidth() or 0, 36)
        UI.killCountCounterText:SetWidth(counterWidth)
        UI.killCountText:SetWidth(math.max(bossWidth - counterWidth - 6, 1))
    end

    UI.cols[1].width = bossWidth
    UI.cols[2].width = UI._pbWidth
    UI.cols[3].width = UI._splitWidth
    UI.cols[4].width = UI._deltaWidth
    local metrics = GetAlignedTimeMetrics()
    UI._alignedTimeMetrics = metrics
    UI._alignedTimeSpecs = {
        pb = BuildAlignedTimeSpec(UI._pbWidth, metrics, "time"),
        split = BuildAlignedTimeSpec(UI._splitWidth, metrics, "time"),
        diff = BuildAlignedTimeSpec(UI._deltaWidth, metrics, "delta"),
        footerPB = BuildAlignedTimeSpec(UI._pbWidth, metrics, "time"),
        footerSplit = BuildAlignedTimeSpec(UI._splitWidth, metrics, "time"),
        footerDiff = BuildAlignedTimeSpec(UI._deltaWidth, metrics, "delta"),
    }

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

    if UI.totalFrame then
        local totalsXOffset = (Const.SPLITS_LAYOUT and Const.SPLITS_LAYOUT.TOTALS_X_OFFSET) or 0
        local xBossRight = bossWidth
        local xPBLeft = xBossRight + totalsXOffset
        local xPBRight = xPBLeft + UI._pbWidth
        local xSplitLeft = xPBLeft + UI._pbWidth
        local xSplitRight = xSplitLeft + UI._splitWidth
        local xDiffLeft = xSplitLeft + UI._splitWidth
        local xDiffRight = xDiffLeft + UI._deltaWidth
        UI.totalDelta:ClearAllPoints()
        UI.totalDelta:SetPoint("TOPLEFT", UI.totalFrame, "TOPLEFT", xDiffLeft, 0)
        UI.totalDelta:SetPoint("BOTTOMRIGHT", UI.totalFrame, "BOTTOMLEFT", xDiffRight, 0)
        if UI.ApplyAlignedTimeGroupLayout then
            UI.ApplyAlignedTimeGroupLayout(UI.totalDelta, "summary", UI._alignedTimeSpecs.footerDiff)
        end
        if UI.SetTotalSummaryText then
            UI.SetTotalSummaryText(UI.totalDelta, UI.totalDelta:GetText(), UI.totalDelta._color)
        end

        UI.totalSplit:ClearAllPoints()
        UI.totalSplit:SetPoint("TOPLEFT", UI.totalFrame, "TOPLEFT", xSplitLeft, 0)
        UI.totalSplit:SetPoint("BOTTOMRIGHT", UI.totalFrame, "BOTTOMLEFT", xSplitRight, 0)
        if UI.ApplyAlignedTimeGroupLayout then
            UI.ApplyAlignedTimeGroupLayout(UI.totalSplit, "summary", UI._alignedTimeSpecs.footerSplit)
        end
        if UI.SetTotalSummaryText then
            UI.SetTotalSummaryText(UI.totalSplit, UI.totalSplit:GetText(), UI.totalSplit._color)
        end

        UI.totalPB:ClearAllPoints()
        UI.totalPB:SetPoint("TOPLEFT", UI.totalFrame, "TOPLEFT", xPBLeft, 0)
        UI.totalPB:SetPoint("BOTTOMRIGHT", UI.totalFrame, "BOTTOMLEFT", xPBRight, 0)
        if UI.ApplyAlignedTimeGroupLayout then
            UI.ApplyAlignedTimeGroupLayout(UI.totalPB, "summary", UI._alignedTimeSpecs.footerPB)
        end
        if UI.SetTotalSummaryText then
            UI.SetTotalSummaryText(UI.totalPB, UI.totalPB:GetText(), UI.totalPB._color)
        end
    end

    if UI._colGrips then
        local xBossRight = bossWidth
        local xPBRight = bossWidth + UI._pbWidth
        local xSplitRight = bossWidth + UI._pbWidth + UI._splitWidth
        local bottom = -Const.SPLITS_LAYOUT.HEADER_H

        UI._colGrips[1]:ClearAllPoints()
        UI._colGrips[1]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xBossRight - Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, 0)
        UI._colGrips[1]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT",
            xBossRight + Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, bottom)

        UI._colGrips[2]:ClearAllPoints()
        UI._colGrips[2]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xPBRight - Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, 0)
        UI._colGrips[2]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT",
            xPBRight + Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, bottom)

        UI._colGrips[3]:ClearAllPoints()
        UI._colGrips[3]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xSplitRight - Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, 0)
        UI._colGrips[3]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT",
            xSplitRight + Const.SPLITS_LAYOUT.GRIP_HALFWIDTH, bottom)
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
        diff = UI._deltaWidth,
    }
end

local function EndColDrag()
    UI._colDrag = nil
    SaveColumnWidths("boss", {
        pb = UI._pbWidth,
        split = UI._splitWidth,
        diff = UI._deltaWidth,
    })
end

local function UpdateColDrag()
    if not UI._colDrag or not UI.st or not UI.st.frame then
        return
    end

    local curX = GetCursorPosition() / UI.st.frame:GetEffectiveScale()
    local dx = curX - UI._colDrag.startX
    local available = math.max((UI.st.frame:GetWidth() or 0) - (UI._rightInset or 0), 0)
    local splitMin = Const.SPLITS_COL_MIN
    local globalMin = splitMin.GLOBAL or 1
    local bossMin = math.max(globalMin, splitMin.BOSS or globalMin)
    local pbMin = math.max(globalMin, splitMin.PB or globalMin)
    local splitColMin = math.max(globalMin, splitMin.SPLIT or globalMin)
    local diffMin = math.max(globalMin, splitMin.DIFFERENCE or globalMin)

    if UI._colDrag.which == 1 then
        local maxPB = math.max(pbMin, available - (UI._modelWidth + UI._splitWidth + UI._deltaWidth + bossMin))
        UI._pbWidth = Util.Clamp(UI._colDrag.pb - dx, pbMin, math.min(Const.SPLITS_COL_MAX.PB_SPLIT, maxPB))
    elseif UI._colDrag.which == 2 then
        UI._pbWidth = Util.Clamp(UI._colDrag.pb + dx, pbMin, Const.SPLITS_COL_MAX.PB_SPLIT)
        UI._splitWidth = Util.Clamp(UI._colDrag.split - dx, splitColMin, Const.SPLITS_COL_MAX.PB_SPLIT)
    elseif UI._colDrag.which == 3 then
        UI._splitWidth = Util.Clamp(UI._colDrag.split + dx, splitColMin, Const.SPLITS_COL_MAX.PB_SPLIT)
        UI._deltaWidth = Util.Clamp(UI._colDrag.diff - dx, diffMin, Const.SPLITS_COL_MAX.DELTA)
    end

    SaveColumnWidths("boss", {
        pb = UI._pbWidth,
        split = UI._splitWidth,
        diff = UI._deltaWidth,
    })
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

UI.LayoutManager = Layout
UI.DeepCopy = DeepCopy
UI.MergeDefaults = MergeDefaults
UI.InitializeDefaults = InitializeDefaults
UI.GetUISaved = GetUISaved
UI.GetFrameLayout = GetSavedFrameLayout
UI.GetSavedFrameLayout = GetSavedFrameLayout
UI.NormalizeUILayoutSnapshot = NormalizeLayoutState
UI.GetNormalizedUILayoutSnapshot = function(source)
    return NormalizeLayoutState(source or GetUISaved() or {})
end
UI.GetEffectiveFrameGeometry = GetEffectiveFrameGeometry
UI.RegisterManagedFrame = RegisterManagedFrame
UI.ApplyFrameLayout = function(frame, layout, frameKey)
    ApplyFrameLayout(frame, layout, frameKey)
end
UI.ApplyColumnWidths = ApplyColumnWidths
UI.ApplyAllLayouts = ApplyAllLayouts
UI.SaveFrameLayout = SaveFrameLayout
UI.SaveFrameGeom = SaveFrameLayout
UI.RestoreFrameGeom = RestoreFrameGeom
UI.SaveFrameShown = SaveFrameShown
UI.SetFrameShown = SetFrameShown
UI.SaveColumnWidths = SaveColumnWidths
UI.RestoreColWidths = RestoreColWidths
UI.CaptureCurrentLayout = CaptureCurrentLayout
UI.ResetFrameToDefaults = ResetFrameToDefaults
UI.ResetAllFramesToDefaults = ResetAllFramesToDefaults
UI.NormalizeFrameSnapshot = function(frameKey, source)
    return NormalizeFrameNode(frameKey, source)
end
UI.GetScrollBarInset = GetScrollBarInset
UI.GetAlignedTimeSpec = GetAlignedTimeSpec
UI.GetModelColumnWidth = GetModelColumnWidth
UI.ApplyTableLayout = ApplyTableLayout
UI.SetupSizeGrip = SetupSizeGrip
UI.BeginColDrag = BeginColDrag
UI.EndColDrag = EndColDrag
UI.UpdateColDrag = UpdateColDrag
UI.MakeGrip = MakeGrip
UI.EnsureColGrips = EnsureColGrips

Layout.DeepCopy = DeepCopy
Layout.MergeDefaults = MergeDefaults
Layout.InitializeDefaults = InitializeDefaults
Layout.ApplyFrameLayout = ApplyFrameLayout
Layout.SaveFrameLayout = SaveFrameLayout
Layout.RestoreFrameGeom = RestoreFrameGeom
Layout.ApplyColumnWidths = ApplyColumnWidths
Layout.ApplyAllLayouts = ApplyAllLayouts
Layout.ResetFrameToDefaults = ResetFrameToDefaults
Layout.ResetAllFramesToDefaults = ResetAllFramesToDefaults
