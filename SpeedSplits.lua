-- SpeedSplits.lua
-- Retail WoW addon: instance splits with objective-first boss discovery + EJ fallback.
-- Run starts on first movement; boss kills record splits, PB segments, and deltas.
-- SavedVariables: SpeedSplitsDB (auto-migrates from MyAddonDB if present).
local ADDON_NAME = ...
local App = CreateFrame("Frame")

-- Constants
local COL_MAX_PB_SPLIT = 260
local COL_MAX_DELTA = 200
local COL_MIN_BOSS = 180 -- Increased for "Boss (x/x)"
local COL_MIN_NUM = 75  -- Enough for "00:00.000"
local COL_MIN_DELTA_TITLE = 90 -- Enough for "Difference"
local GRIP_HALFWIDTH = 5
local HEADER_H = 18
local RIGHT_INSET_DEFAULT = 26
local TOP_BAR_H = 28
local TOP_BAR_GAP = 4
local LOGO_COLOR = "|cffffd100" -- Bold Gold
local BOSS_LOAD_MAX_TRIES = 40
local BOSS_LOAD_RETRY_DELAY = 0.25
local DELTA_GREEN_THRESH = 3
local DELTA_ORANGE_THRESH = 5
local RUNS_MAX = 200
local EJ_INSTANCE_INDEX_MAX = 600
local EJ_ENCOUNTER_INDEX_MAX = 80
local CRITERIA_MAX = 80

local Colors = {
    green = { r = 0.20, g = 1.00, b = 0.20, a = 1 },
    red = { r = 1.00, g = 0.25, b = 0.25, a = 1 },
    gold = { r = 1.00, g = 0.82, b = 0.00, a = 1 },
    goldLight = { r = 1.00, g = 0.92, b = 0.25, a = 1 },
    orange = { r = 1.00, g = 0.65, b = 0.00, a = 1 },
    white = { r = 1, g = 1, b = 1, a = 1 },
    turquoise = { r = 0.0, g = 0.8, b = 0.8, a = 1 },
}

-- =========================================================
-- SavedVariables
-- =========================================================
local DB

local function EnsureDB()
    if SpeedSplitsDB == nil then
        SpeedSplitsDB = MyAddonDB or {}
    end
    MyAddonDB = nil

    SpeedSplitsDB.runs = SpeedSplitsDB.runs or {}
    SpeedSplitsDB.pbBoss = SpeedSplitsDB.pbBoss or {}
    SpeedSplitsDB.pbRun = SpeedSplitsDB.pbRun or {}

    DB = SpeedSplitsDB
end

local ScrollingTable

local function ResolveScrollingTable()
    if ScrollingTable and type(ScrollingTable.CreateST) == "function" then
        return ScrollingTable
    end
    local candidates = { _G["lib-st-v4.1.3"], _G["lib-st"], _G.LibST, _G.libst, _G.LibScrollingTable, _G.ScrollingTable }
    for _, lib in ipairs(candidates) do
        if lib and type(lib.CreateST) == "function" then
            ScrollingTable = lib
            return lib
        end
    end
    if LibStub then
        for _, id in ipairs({ "lib-st", "LibScrollingTable-1.1", "LibScrollingTable-1.0", "LibScrollingTable", "ScrollingTable" }) do
            local ok, lib = pcall(LibStub, id, true)
            if ok and lib and type(lib.CreateST) == "function" then
                ScrollingTable = lib
                return lib
            end
        end
    end
    return nil
end

-- =========================================================
-- Small utilities
-- =========================================================
local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function ApplyResizeBounds(frame, minW, minH, maxW, maxH)
    if not frame then return end
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW or minW, maxH or minH)
        return
    end
    if frame.SetMinResize then frame:SetMinResize(minW, minH) end
end

local NowEpoch = time
local NowGameTime = GetTime

local function NormalizeName(text)
    if text == nil then
        return ""
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    if text == "" then
        return ""
    end
    text = text:lower()
    text = text:gsub("[%-–—:,%s%p]", "")
    return text
end

local function SS_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99SpeedSplits|r: " .. tostring(msg))
    else
        print("SpeedSplits: " .. tostring(msg))
    end
end

-- Debug toggle (off by default). Use /ssobj to toggle objective parsing prints.
SpeedSplits_DebugObjectives = SpeedSplits_DebugObjectives or false

SLASH_SPEEDSPLITSOBJ1 = "/ssobj"
SlashCmdList.SPEEDSPLITSOBJ = function()
    SpeedSplits_DebugObjectives = not SpeedSplits_DebugObjectives
    SS_Print("Objective debug: " .. (SpeedSplits_DebugObjectives and "ON" or "OFF"))
end

local function FormatTime(seconds)
    if seconds == nil then
        return "--:--.---"
    end
    if seconds < 0 then
        seconds = 0
    end
    local minutes = math.floor(seconds / 60)
    local remainder = seconds - (minutes * 60)
    local wholeSeconds = math.floor(remainder)
    local milliseconds = math.floor((remainder - wholeSeconds) * 1000 + 0.5)
    return string.format("%02d:%02d.%03d", minutes, wholeSeconds, milliseconds)
end

local function FormatDelta(deltaSeconds)
    if deltaSeconds == nil then
        return ""
    end
    local sign = deltaSeconds >= 0 and "+" or "-"
    return sign .. FormatTime(math.abs(deltaSeconds))
end

local function GetDungeonKey(mapID, difficultyID)
    return ("%d:%d"):format(tonumber(mapID) or 0, tonumber(difficultyID) or 0)
end

local function HistoryFilterDefaults()
    return {
        tier = 0,
        mapID = 0,
        dateMode = "any",
        sort = "recent",
        successOnly = false,
        pbOnly = false,
        search = "",
    }
end

--- Delta (seconds) -> r,g,b for display. nil-safe.
local function DeltaToRGB(delta, isImprovement)
    if delta == nil then return nil, nil, nil end
    if isImprovement then return Colors.gold.r, Colors.gold.g, Colors.gold.b end
    local a = math.abs(delta)
    if a <= DELTA_GREEN_THRESH then return Colors.green.r, Colors.green.g, Colors.green.b end
    if a <= DELTA_ORANGE_THRESH then return Colors.orange.r, Colors.orange.g, Colors.orange.b end
    return Colors.red.r, Colors.red.g, Colors.red.b
end

-- =========================================================
-- Encounter Journal
-- =========================================================
local function ForEachEJInstance(callback)
    if not EJ_GetNumTiers or not EJ_SelectTier or not EJ_GetInstanceByIndex then return end
    local tierCount = EJ_GetNumTiers() or 0
    for ti = 1, tierCount do
        EJ_SelectTier(ti)
        for isRaid = 0, 1 do
            for ii = 1, EJ_INSTANCE_INDEX_MAX do
                local instanceID, name = EJ_GetInstanceByIndex(ii, isRaid == 1)
                if not instanceID then break end
                if callback(ti, instanceID, name) then return end
            end
        end
    end
end

local function FindJournalTierForInstanceID(targetID)
    targetID = tonumber(targetID)
    if not targetID then return nil end
    local found
    ForEachEJInstance(function(ti, instanceID)
        if tonumber(instanceID) == targetID then found = ti; return true end
    end)
    return found
end

local function FindJournalTierAndInstanceIDByName(instanceName)
    local wanted = NormalizeName(instanceName)
    if wanted == "" then return nil, nil end
    local foundTier, foundID
    ForEachEJInstance(function(ti, instanceID, name)
        if NormalizeName(name) == wanted then foundTier, foundID = ti, instanceID; return true end
    end)
    return foundTier, foundID
end

local function GetJournalTierAndInstanceIDForCurrentInstance()
    local instanceName, _, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    mapID = tonumber(mapID) or 0

    local journalID
    if EJ_GetInstanceForMap and C_Map and C_Map.GetBestMapForUnit then
        local bestMapID = C_Map.GetBestMapForUnit("player")
        if bestMapID then
            journalID = EJ_GetInstanceForMap(bestMapID)
        end
    end

    local tier
    if journalID then
        tier = FindJournalTierForInstanceID(journalID)
        return tier, journalID, mapID, tonumber(difficultyID) or 0, instanceName or ""
    end

    local foundTier, foundID = FindJournalTierAndInstanceIDByName(instanceName)
    return foundTier, foundID, mapID, tonumber(difficultyID) or 0, instanceName or ""
end

-- =========================================================
-- Boss discovery (Objectives first, EJ fallback)
-- =========================================================
local function ExtractBossNameFromObjectiveText(desc)
    if type(desc) ~= "string" or desc == "" then
        return nil
    end

    local text = desc

    -- Strip common WoW formatting (colors/textures)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "")

    -- Trim + remove progress prefixes like "0/1 "
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^%d+%s*/%s*%d+%s+", "")

    -- Normalize common objective verbs/prefixes/suffixes
    text = text:gsub("^Defeat:%s+", "")
    text = text:gsub("^Defeat%s+", "")
    text = text:gsub("^Kill%s+", "")
    text = text:gsub("^Slay%s+", "")
    text = text:gsub("%s+[Dd]efeated$", "")
    text = text:gsub("%s+[Ss]lain$", "")
    text = text:gsub("%s+[Kk]illed$", "")

    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
end

local function GetBossNamesFromObjectives()
    -- Returns: names, ready
    local names = {}

    if not C_ScenarioInfo or not C_ScenarioInfo.GetScenarioInfo or not C_ScenarioInfo.GetCriteriaInfo then
        return names, true -- can't use objectives API here; allow EJ
    end

    -- If we're not actually in a scenario, objectives criteria may never exist (allow EJ immediately)
    local inScenario = false
    if C_Scenario and C_Scenario.IsInScenario then
        inScenario = C_Scenario.IsInScenario() and true or false
    else
        local info = C_ScenarioInfo.GetScenarioInfo()
        inScenario = (info and info.currentStage and info.currentStage > 0) and true or false
    end
    if not inScenario then
        return names, true
    end

    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    if not scenarioInfo then
        return {}, false -- scenario exists but data not ready yet
    end

    -- Prefer real criteria count if available
    local criteriaCount = nil
    if C_ScenarioInfo.GetStepInfo then
        local _, _, numCriteria = C_ScenarioInfo.GetStepInfo()
        criteriaCount = tonumber(numCriteria)
    end

    local sawCriteria = false
    local sawStringDescription = false

    local maxCriteria = criteriaCount or CRITERIA_MAX
    for criteriaIndex = 1, maxCriteria do
        local criteria = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
        if not criteria then
            break
        end
        sawCriteria = true

        local desc = criteria.description
        if type(desc) == "string" then
            sawStringDescription = true

            if SpeedSplits_DebugObjectives then
                SS_Print(("OBJ[%d] raw: %q"):format(criteriaIndex, desc))
            end

            local bossName = ExtractBossNameFromObjectiveText(desc)

            if SpeedSplits_DebugObjectives then
                SS_Print(("OBJ[%d] parsed: %s"):format(criteriaIndex, bossName and bossName or "<nil>"))
            end

            if bossName then
                names[#names + 1] = bossName
            end
        end
    end

    -- If we're in a scenario but criteria/strings aren't ready yet, force retry (don't fall back to EJ yet).
    if not sawCriteria or not sawStringDescription then
        return {}, false
    end

    local out, seen = {}, {}
    for _, n in ipairs(names) do
        local key = NormalizeName(n)
        if key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = n
        end
    end

    return out, true
end

local function GetEJBossesForInstance(journalInstanceID)
    local bosses = {}

    if not journalInstanceID or not EJ_SelectInstance or not EJ_GetEncounterInfoByIndex then
        return bosses
    end

    local ok = pcall(function()
        EJ_SelectInstance(journalInstanceID)
    end)
    if not ok then
        return bosses
    end

    for encounterIndex = 1, EJ_ENCOUNTER_INDEX_MAX do
        local name, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, journalInstanceID)
        if not name then
            break
        end
        bosses[#bosses + 1] = {
            name = name,
            encounterID = tonumber(encounterID)
        }
    end

    return bosses
end

local function EJBossesToEntries(ejBosses)
    local entries = {}
    for _, boss in ipairs(ejBosses or {}) do
        local encounterID = tonumber(boss.encounterID)
        local key = encounterID and ("E:" .. encounterID) or ("N:" .. NormalizeName(boss.name))
        entries[#entries + 1] = { key = key, name = boss.name, encounterID = encounterID }
    end
    return entries
end

local function BuildBossEntries()
    local tier, journalID = GetJournalTierAndInstanceIDForCurrentInstance()
    local objectiveNames, ready = GetBossNamesFromObjectives()
    if not ready then return {}, "none", tier, journalID, false end

    if #objectiveNames > 0 then
        local entries = {}
        for _, bossName in ipairs(objectiveNames) do
            local n = NormalizeName(bossName)
            if n ~= "" then entries[#entries + 1] = { key = "N:" .. n, name = bossName } end
        end
        return entries, "objectives", tier, journalID, true
    end

    if journalID then
        local ejBosses = GetEJBossesForInstance(journalID)
        if #ejBosses > 0 then
            return EJBossesToEntries(ejBosses), "encounter_journal", tier, journalID, true
        end
    end
    return {}, "none", tier, journalID, true
end

-- =========================================================
-- UI (Timer frame + Boss Table frame using lib-st + Totals + History)
-- =========================================================

-- Notes:
--  - lib-st handles row creation/scrolling. We only manage data + styling.
--  - Column resizing: thin draggable separators between columns (Excel-style).
--  - Frame resizing: bottom-right grip on both timer and table frames.

local UI = {
    timerFrame = nil,
    bossFrame = nil,

    timerText = nil,
    killCountText = nil,

    historyButton = nil,

    -- lib-st
    st = nil,
    cols = nil,
    data = nil, -- array of lib-st rows
    rowByBossKey = nil, -- bossKey -> realrow index in data

    -- Resizable widths (boss is computed as "fill remaining")
    _pbWidth = 80,
    _splitWidth = 80,
    _deltaWidth = 60,

    _rightInset = RIGHT_INSET_DEFAULT,
    _topInset = RIGHT_INSET_DEFAULT,
    _bottomInset = 34, -- Increased for Totals spacing

    _colGrips = nil, -- separator grips
    _colDrag = nil, -- active drag state

    totalFrame = nil,
    totalLabel = nil,
    totalPB = nil,
    totalSplit = nil,
    totalDelta = nil,
    timerDeltaText = nil,

    resizeGrip = nil,
    _timerResizeGrip = nil,

    history = {
        frame = nil,
        searchBox = nil,
        tierDropDown = nil,
        dateDropDown = nil,
    }
}

local function ApplyThinSeparator(grip)
    if grip._line then
        return
    end
    local line = grip:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER", grip, "CENTER", 0, 0)
    line:SetSize(1, HEADER_H)
    line:SetColorTexture(1, 1, 1, 0.18)
    grip._line = line
end

local function SetHoverBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1
    })
    frame:SetBackdropColor(0, 0, 0, alpha or 0.75)
    frame:SetBackdropBorderColor(1, 1, 1, 0.10)
end

local function GetUISaved()
    if not DB then
        return nil
    end
    DB.ui = DB.ui or {}
    DB.ui.frames = DB.ui.frames or {}
    DB.ui.cols = DB.ui.cols or {}
    DB.ui.preview = DB.ui.preview or false
    return DB.ui
end

local function SaveFrameGeom(frameKey, frame)
    local ui = GetUISaved()
    if not ui then
        return
    end

    local point, relTo, relPoint, xOfs, yOfs = frame:GetPoint(1)
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
    if not st or not st.frame then return UI._rightInset end
    local sb = (st.scrollframe and st.scrollframe.ScrollBar) or (st.frame.ScrollBar) or (st.scrollbar)
    local w = (sb and sb.GetWidth and sb:GetWidth()) or UI._rightInset
    return math.max(16, math.floor(w + 8))
end

local function ApplyTableLayout()
    if not UI.bossFrame or not UI.st or not UI.cols then
        return
    end

    UI._rightInset = GetScrollBarInset(UI.st)

    local w = UI.st.frame:GetWidth() or 1
    local available = math.max(w - UI._rightInset, 1)

    local minDelta = math.max(COL_MIN_NUM, COL_MIN_DELTA_TITLE)
    UI._pbWidth = Clamp(UI._pbWidth, COL_MIN_NUM, math.max(available - (COL_MIN_BOSS + UI._splitWidth + minDelta), COL_MIN_NUM))
    UI._splitWidth = Clamp(UI._splitWidth, COL_MIN_NUM, math.max(available - (COL_MIN_BOSS + UI._pbWidth + minDelta), COL_MIN_NUM))
    UI._deltaWidth = Clamp(UI._deltaWidth, minDelta, math.max(available - (COL_MIN_BOSS + UI._pbWidth + UI._splitWidth), minDelta))
    local bossWidth = math.max(available - (UI._pbWidth + UI._splitWidth + UI._deltaWidth), COL_MIN_BOSS)

    UI.cols[1].width = bossWidth
    UI.cols[2].width = UI._pbWidth
    UI.cols[3].width = UI._splitWidth
    UI.cols[4].width = UI._deltaWidth

    if UI.st.SetDisplayCols then
        UI.st:SetDisplayCols(UI.cols)
    else
        UI.st.cols = UI.cols
    end

    if UI.st.Refresh then
        UI.st:Refresh()
    end

    -- Totals row alignment (anchored to the scrolling table width, excluding scrollbar)
    local tf = UI.totalFrame
    if tf then
        local rightPad = UI._rightInset
        
        -- Center UI.totalDelta in Difference column
        local midDelta = rightPad + UI._deltaWidth / 2
        UI.totalDelta:ClearAllPoints()
        UI.totalDelta:SetPoint("CENTER", tf, "RIGHT", -midDelta, 0)
        UI.totalDelta:SetWidth(UI._deltaWidth)
        UI.totalDelta:SetJustifyH("CENTER")

        -- Center UI.totalSplit in Split column
        local midSplit = rightPad + UI._deltaWidth + UI._splitWidth / 2
        UI.totalSplit:ClearAllPoints()
        UI.totalSplit:SetPoint("CENTER", tf, "RIGHT", -midSplit, 0)
        UI.totalSplit:SetWidth(UI._splitWidth)
        UI.totalSplit:SetJustifyH("CENTER")

        -- Center UI.totalPB in PB column
        local midPB = rightPad + UI._deltaWidth + UI._splitWidth + UI._pbWidth / 2
        UI.totalPB:ClearAllPoints()
        UI.totalPB:SetPoint("CENTER", tf, "RIGHT", -midPB, 0)
        UI.totalPB:SetWidth(UI._pbWidth)
        UI.totalPB:SetJustifyH("CENTER")

        UI.totalLabel:ClearAllPoints()
        UI.totalLabel:SetPoint("RIGHT", UI.totalPB, "LEFT", -15, 0)
        UI.totalLabel:SetJustifyH("RIGHT")
        UI.totalLabel:SetWidth(100)
        UI.totalLabel:SetTextColor(Colors.turquoise.r, Colors.turquoise.g, Colors.turquoise.b, 1)
    end

    -- Position separator grips in the header area
    if UI._colGrips then
        local xBossRight = bossWidth
        local xPBRight = bossWidth + UI._pbWidth
        local xSplitRight = bossWidth + UI._pbWidth + UI._splitWidth

        local gv = -HEADER_H
        UI._colGrips[1]:ClearAllPoints()
        UI._colGrips[1]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xBossRight - GRIP_HALFWIDTH, 0)
        UI._colGrips[1]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xBossRight + GRIP_HALFWIDTH, gv)
        UI._colGrips[2]:ClearAllPoints()
        UI._colGrips[2]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xPBRight - GRIP_HALFWIDTH, 0)
        UI._colGrips[2]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xPBRight + GRIP_HALFWIDTH, gv)
        UI._colGrips[3]:ClearAllPoints()
        UI._colGrips[3]:SetPoint("TOPLEFT", UI.st.frame, "TOPLEFT", xSplitRight - GRIP_HALFWIDTH, 0)
        UI._colGrips[3]:SetPoint("BOTTOMRIGHT", UI.st.frame, "TOPLEFT", xSplitRight + GRIP_HALFWIDTH, gv)
    end
end

local function SetupSizeGrip(ownerFrame, onChanged)
    local grip = CreateFrame("Button", nil, ownerFrame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", ownerFrame, "BOTTOMRIGHT", -2, 2)
    grip:EnableMouse(true)

    local tex = grip:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip._tex = tex

    grip:SetScript("OnEnter", function(self)
        self._tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    grip:SetScript("OnLeave", function(self)
        self._tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        ownerFrame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function(self)
        ownerFrame:StopMovingOrSizing()
        if onChanged then
            onChanged()
        end
    end)

    return grip
end

local function BeginColDrag(which, startX)
    UI._colDrag = {
        which = which,
        startX = startX,
        pb = UI._pbWidth,
        split = UI._splitWidth,
        delta = UI._deltaWidth
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

    local curX = GetCursorPosition()
    local scale = UI.st.frame:GetEffectiveScale()
    curX = curX / scale

    local dx = curX - UI._colDrag.startX
    local available = (UI.st.frame:GetWidth() or 0) - UI._rightInset

    if UI._colDrag.which == 1 then
        -- Boundary between Boss and PB. 
        -- BossWidth = available - (PB + Split + Diff). Cannot be less than COL_MIN_BOSS.
        local maxPB = math.max(COL_MIN_NUM, available - (UI._splitWidth + UI._deltaWidth + COL_MIN_BOSS))
        UI._pbWidth = Clamp(UI._colDrag.pb - dx, COL_MIN_NUM, math.min(COL_MAX_PB_SPLIT, maxPB))
    elseif UI._colDrag.which == 2 then
        UI._pbWidth = Clamp(UI._colDrag.pb + dx, COL_MIN_NUM, COL_MAX_PB_SPLIT)
        UI._splitWidth = Clamp(UI._colDrag.split - dx, COL_MIN_NUM, COL_MAX_PB_SPLIT)
    elseif UI._colDrag.which == 3 then
        local minDelta = math.max(COL_MIN_NUM, COL_MIN_DELTA_TITLE)
        UI._splitWidth = Clamp(UI._colDrag.split + dx, COL_MIN_NUM, COL_MAX_PB_SPLIT)
        UI._deltaWidth = Clamp(UI._colDrag.delta - dx, minDelta, COL_MAX_DELTA)
    end

    ApplyTableLayout()
end

local function MakeGrip(parent, which)
    local grip = CreateFrame("Frame", nil, parent)
    grip:SetFrameStrata("HIGH")
    grip:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    grip:EnableMouse(true)
    grip:SetSize(10, 14)

    ApplyThinSeparator(grip)

    grip:SetScript("OnEnter", function()
        SetCursor("UI_RESIZE_CURSOR")
    end)
    grip:SetScript("OnLeave", function()
        ResetCursor()
    end)

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        local x = GetCursorPosition() / (UI.st.frame:GetEffectiveScale() or 1)
        BeginColDrag(which, x)
        self:SetScript("OnUpdate", UpdateColDrag)
    end)

    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        EndColDrag()
    end)

    return grip
end

local function EnsureColGrips()
    if UI._colGrips or not UI.st or not UI.st.frame then
        return
    end
    UI._colGrips = {MakeGrip(UI.st.frame, 1), MakeGrip(UI.st.frame, 2), MakeGrip(UI.st.frame, 3)}
end

local function StyleHeaderCell(cellFrame, align)
    if not cellFrame or not cellFrame.text then return end
    cellFrame.text:SetJustifyH(align or "CENTER")
    cellFrame.text:SetJustifyV("TOP")
    cellFrame.text:SetFontObject(GameFontNormalSmall)
    local f, s = cellFrame.text:GetFont()
    cellFrame.text:SetFont(f, s or 10, "OUTLINE, THICKOUTLINE")
    cellFrame.text:SetTextColor(1, 0.82, 0, 1) -- Golden titles
end

local function MakeCellUpdater(opts)
    opts = opts or {}
    return function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, stable)
        if not fShow or not realrow then
            if cellFrame and cellFrame.text then cellFrame.text:SetText("") end
            return
        end
        local e = data[realrow]
        local cell = e and e.cols and e.cols[column]
        if not cell then return end
        cellFrame.text:SetText(cell.value or "")
        cellFrame.text:SetFontObject(GameFontHighlightSmall)
        cellFrame.text:SetJustifyH(opts.justifyH or cols[column].align or "LEFT")
        cellFrame.text:SetJustifyV(opts.justifyV or "MIDDLE")
        if opts.wordWrap then cellFrame.text:SetWordWrap(true) end
        if opts.maxLines and cellFrame.text.SetMaxLines then cellFrame.text:SetMaxLines(opts.maxLines) end
        local c = (opts.useColColor and cols[column].color) and cols[column].color(data, cols, realrow, column, stable) or cell.color
        if c then
            cellFrame.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        else
            cellFrame.text:SetTextColor(1, 1, 1, 1)
        end
    end
end
local Boss_DoCellUpdate = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, stable)
    if not fShow or not realrow then
        if cellFrame and cellFrame.text then cellFrame.text:SetText("") end
        return
    end
    local e = data[realrow]
    local cell = e and e.cols and e.cols[column]
    if not cell then return end
    cellFrame.text:SetText(cell.value or "")
    cellFrame.text:SetFontObject(GameFontHighlight)
    cellFrame.text:SetJustifyH("LEFT")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:SetWordWrap(false)
    cellFrame.text:ClearAllPoints()
    cellFrame.text:SetPoint("LEFT", cellFrame, "LEFT", 0, 0)
    cellFrame.text:SetPoint("RIGHT", cellFrame, "RIGHT", 0, 0)
end

local Num_DoCellUpdate = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, stable)
    if not fShow or not realrow then
        if cellFrame and cellFrame.text then cellFrame.text:SetText("") end
        return
    end
    local e = data[realrow]
    local cell = e and e.cols and e.cols[column]
    if not cell then return end
    cellFrame.text:SetText(cell.value or "")
    cellFrame.text:SetFontObject(GameFontHighlightSmall)
    cellFrame.text:SetJustifyH("CENTER")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:ClearAllPoints()
    cellFrame.text:SetPoint("LEFT", cellFrame, "LEFT", 0, 0)
    cellFrame.text:SetPoint("RIGHT", cellFrame, "RIGHT", 0, 0)
    local c = (cols[column].color) and cols[column].color(data, cols, realrow, column, stable) or cell.color
    if c then
        cellFrame.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
    else
        cellFrame.text:SetTextColor(1, 1, 1, 1)
    end
end

local function DeltaColor(data, cols, realrow, column)
    local e = data[realrow]
    local cell = e and e.cols and e.cols[column]
    return cell and cell.color or nil
end

local function PBColor()
    return Colors.gold
end

local function SplitColor(data, cols, realrow, column)
    local e = data[realrow]
    local diffCell = e and e.cols and e.cols[4] -- Difference column
    return diffCell and diffCell.color or nil
end

-- =========================================================
-- Runs History UI
-- =========================================================
local function FormatEpochShort(epoch)
    if not epoch or epoch <= 0 then
        return "—"
    end
    return date("%Y-%m-%d %H:%M", epoch)
end

local function GetTierNameSafe(tierIndex)
    tierIndex = tonumber(tierIndex)
    if not tierIndex or tierIndex <= 0 or not EJ_GetTierInfo then
        return "Unknown"
    end
    local name = EJ_GetTierInfo(tierIndex)
    return name or ("Tier " .. tostring(tierIndex))
end

local function IsRunPB(record)
    if not record or not record.success or not record.duration or not record.dungeonKey then
        return false
    end
    local pb = DB and DB.pbRun and DB.pbRun[record.dungeonKey]
    if not pb or not pb.duration then
        return false
    end
    return math.abs((record.duration or 0) - (pb.duration or 0)) < 0.001
end

local function BuildHistoryTierItems()
    local items = {{
        text = "Any",
        value = 0
    }}
    if not DB or not DB.runs then
        return items
    end
    local seen = {}
    for _, r in ipairs(DB.runs) do
        local t = tonumber(r.tier)
        if t and t > 0 then
            seen[t] = true
        end
    end
    local tiers = {}
    for t in pairs(seen) do
        tiers[#tiers + 1] = t
    end
    table.sort(tiers)
    for _, t in ipairs(tiers) do
        items[#items + 1] = {
            text = GetTierNameSafe(t),
            value = t
        }
    end
    return items
end

local function BuildHistoryDungeonItems()
    local items = {{
        text = "Any",
        value = 0
    }}
    if not DB or not DB.runs then
        return items
    end
    local seen = {}
    for _, r in ipairs(DB.runs) do
        local mapID = tonumber(r.mapID) or 0
        local name = r.instanceName or ("Map " .. tostring(mapID))
        if mapID > 0 and not seen[mapID] then
            seen[mapID] = name
        end
    end
    local mapIDs = {}
    for mapID in pairs(seen) do
        mapIDs[#mapIDs + 1] = mapID
    end
    table.sort(mapIDs, function(a, b)
        return tostring(seen[a] or a) < tostring(seen[b] or b)
    end)
    for _, mapID in ipairs(mapIDs) do
        items[#items + 1] = {
            text = seen[mapID],
            value = mapID
        }
    end
    return items
end

local function DateRangeToMinEpoch(mode)
    mode = mode or "any"
    if mode == "today" then
        local now = time()
        local t = date("*t", now)
        t.hour, t.min, t.sec = 0, 0, 0
        return time(t)
    elseif mode == "7d" then
        return time() - (7 * 24 * 60 * 60)
    elseif mode == "30d" then
        return time() - (30 * 24 * 60 * 60)
    end
    return nil
end

local History_DoCellUpdate = MakeCellUpdater {} -- uses cols[column].align, cell.color

local function RefreshHistoryTable()
    if not UI or not UI.history or not UI.history.st then
        return
    end

    UI.history.filters = UI.history.filters or HistoryFilterDefaults()
    local f = UI.history.filters
    local search = NormalizeName(f.search or "")
    local minEpoch = DateRangeToMinEpoch(f.dateMode)

    local rows = {}
    for _, r in ipairs(DB.runs or {}) do
        if f.tier == 0 or tonumber(r.tier) == tonumber(f.tier) then
            if f.mapID == 0 or (tonumber(r.mapID) or 0) == tonumber(f.mapID) then
                if not minEpoch or ((r.startedAt or 0) >= minEpoch) then
                    if not f.successOnly or r.success then
                        if not f.pbOnly or IsRunPB(r) then
                            if search == "" or NormalizeName(r.instanceName or ""):find(search, 1, true) then
                                rows[#rows + 1] = r
                            end
                        end
                    end
                end
            end
        end
    end

    if f.sort == "fastest" then
        table.sort(rows, function(a, b)
            return (a.duration or 1e9) < (b.duration or 1e9)
        end)
    elseif f.sort == "slowest" then
        table.sort(rows, function(a, b)
            return (a.duration or 0) > (b.duration or 0)
        end)
    elseif f.sort == "oldest" then
        table.sort(rows, function(a, b)
            return (a.startedAt or 0) < (b.startedAt or 0)
        end)
    else -- recent
        table.sort(rows, function(a, b)
            return (a.startedAt or 0) > (b.startedAt or 0)
        end)
    end

    local data = {}
    for i, r in ipairs(rows) do
        local diffName = ""
        if GetDifficultyInfo then
            diffName = select(1, GetDifficultyInfo(tonumber(r.difficultyID) or 0)) or ""
        end
        if diffName == "" then
            diffName = tostring(tonumber(r.difficultyID) or "")
        end

        local pb = DB.pbRun and r.dungeonKey and DB.pbRun[r.dungeonKey]
        local deltaPB = (pb and pb.duration and r.duration) and (r.duration - pb.duration) or nil

        local resultColor = r.success and Colors.green or Colors.red
        local pbMark = IsRunPB(r) and "★" or ""
        local pbMarkColor = pbMark ~= "" and Colors.goldLight or nil
        local deltaText = deltaPB and FormatDelta(deltaPB) or "—"
        local deltaColor = deltaPB and (deltaPB <= 0 and Colors.green or Colors.red) or nil

        data[i] = {
            record = r,
            cols = {{
                value = FormatEpochShort(r.startedAt or r.endedAt or 0)
            }, {
                value = r.instanceName or "—"
            }, {
                value = diffName
            }, {
                value = r.duration and FormatTime(r.duration) or "--:--.---"
            }, {
                value = r.success and "OK" or "FAIL",
                color = resultColor
            }, {
                value = pbMark,
                color = pbMarkColor
            }, {
                value = deltaText,
                color = deltaColor
            }}
        }
    end

    UI.history.st:SetData(data, true)
    UI.history.st:Refresh()
end

local function InitHistoryDropDown(dropDown, buildItems, getValue, setValue)
    if not dropDown or not UIDropDownMenu_Initialize then
        return
    end

    UIDropDownMenu_Initialize(dropDown, function(self, level)
        local items = buildItems()
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = (getValue() == item.value)
            info.func = function()
                setValue(item.value)
                UIDropDownMenu_SetText(dropDown, item.text)
                RefreshHistoryTable()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

local function EnsureHistoryUI()
    EnsureDB()

    if UI.history.frame then
        return
    end

    local historyFrame = CreateFrame("Frame", "SpeedSplitsHistoryFrame", UIParent, "BackdropTemplate")
    historyFrame:SetFrameStrata("DIALOG")
    SetHoverBackdrop(historyFrame, 0.85)
    historyFrame:EnableMouse(true)
    historyFrame:SetMovable(true)
    historyFrame:RegisterForDrag("LeftButton")
    historyFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    historyFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFrameGeom("history", self)
    end)

    RestoreFrameGeom("history", historyFrame, 980, 460)

    local title = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 12, -10)
    title:SetText("Runs History")

    local close = CreateFrame("Button", nil, historyFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", historyFrame, "TOPRIGHT", -4, -4)

    local filterW = 230

    local listFrame = CreateFrame("Frame", nil, historyFrame)
    listFrame:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 10, -32)
    listFrame:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -(filterW + 10), 10)

    local filterFrame = CreateFrame("Frame", nil, historyFrame, "BackdropTemplate")
    filterFrame:SetPoint("TOPRIGHT", historyFrame, "TOPRIGHT", -10, -32)
    filterFrame:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -10, 10)
    filterFrame:SetWidth(filterW)
    SetHoverBackdrop(filterFrame, 0.60)

    local filterTitle = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterTitle:SetPoint("TOPLEFT", filterFrame, "TOPLEFT", 10, -10)
    filterTitle:SetText("Filters")

    local y = -28

    local function AddLabel(text)
        local fs = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", filterFrame, "TOPLEFT", 10, y)
        fs:SetText(text)
        y = y - 16
        return fs
    end

    local function AddSearchBox()
        AddLabel("Search dungeon")
        local box = CreateFrame("EditBox", nil, filterFrame, "InputBoxTemplate")
        box:SetAutoFocus(false)
        box:SetSize(filterW - 26, 20)
        box:SetPoint("TOPLEFT", filterFrame, "TOPLEFT", 10, y)
        box:SetScript("OnTextChanged", function(self)
            UI.history.filters.search = self:GetText() or ""
            RefreshHistoryTable()
        end)
        y = y - 30
        UI.history.searchBox = box
    end

    local function AddDropDown(labelText, width, buildItems, getValue, setValue, defaultText)
        AddLabel(labelText)
        local dd = CreateFrame("Frame", nil, filterFrame, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", filterFrame, "TOPLEFT", -6, y + 8)
        UIDropDownMenu_SetWidth(dd, width)
        UIDropDownMenu_SetText(dd, defaultText or "Any")
        InitHistoryDropDown(dd, buildItems, getValue, setValue)
        y = y - 36
        return dd
    end

    local function AddCheck(labelText, getter, setter)
        local cb = CreateFrame("CheckButton", nil, filterFrame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", filterFrame, "TOPLEFT", 8, y)
        cb.Text:SetText(labelText)
        cb:SetChecked(getter())
        cb:SetScript("OnClick", function(self)
            setter(self:GetChecked() and true or false)
            RefreshHistoryTable()
        end)
        y = y - 24
        return cb
    end

    UI.history.filters = UI.history.filters or HistoryFilterDefaults()
    AddSearchBox()

    UI.history.tierDropDown = AddDropDown("Expansion", filterW - 26, BuildHistoryTierItems, function()
        return UI.history.filters.tier
    end, function(v)
        UI.history.filters.tier = tonumber(v) or 0
    end, "Any")

    UI.history.dungeonDropDown = AddDropDown("Dungeon", filterW - 26, BuildHistoryDungeonItems, function()
        return UI.history.filters.mapID
    end, function(v)
        UI.history.filters.mapID = tonumber(v) or 0
    end, "Any")

    local dateItems = function()
        return {{
            text = "Any",
            value = "any"
        }, {
            text = "Today",
            value = "today"
        }, {
            text = "Last 7 days",
            value = "7d"
        }, {
            text = "Last 30 days",
            value = "30d"
        }}
    end

    UI.history.dateDropDown = AddDropDown("Date created", filterW - 26, dateItems, function()
        return UI.history.filters.dateMode
    end, function(v)
        UI.history.filters.dateMode = v or "any"
    end, "Any")

    local sortItems = function()
        return {{
            text = "Most recent",
            value = "recent"
        }, {
            text = "Oldest",
            value = "oldest"
        }, {
            text = "Fastest",
            value = "fastest"
        }, {
            text = "Slowest",
            value = "slowest"
        }}
    end

    UI.history.sortDropDown = AddDropDown("Sort", filterW - 26, sortItems, function()
        return UI.history.filters.sort
    end, function(v)
        UI.history.filters.sort = v or "recent"
    end, "Most recent")

    UI.history.successOnlyCheck = AddCheck("Success only", function()
        return UI.history.filters.successOnly
    end, function(v)
        UI.history.filters.successOnly = v
    end)

    UI.history.pbOnlyCheck = AddCheck("PB runs only", function()
        return UI.history.filters.pbOnly
    end, function(v)
        UI.history.filters.pbOnly = v
    end)

    local clearBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(filterW - 26, 22)
    clearBtn:SetPoint("BOTTOMLEFT", filterFrame, "BOTTOMLEFT", 10, 10)
    clearBtn:SetText("Clear filters")
    clearBtn:SetScript("OnClick", function()
        UI.history.filters = HistoryFilterDefaults()
        if UI.history.searchBox then
            UI.history.searchBox:SetText("")
        end
        UIDropDownMenu_SetText(UI.history.tierDropDown, "Any")
        UIDropDownMenu_SetText(UI.history.dungeonDropDown, "Any")
        UIDropDownMenu_SetText(UI.history.dateDropDown, "Any")
        UIDropDownMenu_SetText(UI.history.sortDropDown, "Most recent")
        if UI.history.successOnlyCheck then
            UI.history.successOnlyCheck:SetChecked(false)
        end
        if UI.history.pbOnlyCheck then
            UI.history.pbOnlyCheck:SetChecked(false)
        end
        RefreshHistoryTable()
    end)

    local ST = ResolveScrollingTable()
    if not ST then
        local warn = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -6)
        warn:SetText("Missing LibScrollingTable (lib-st).")
    else
        local cols = {{
            name = "Date",
            width = 130,
            align = "LEFT",
            DoCellUpdate = History_DoCellUpdate
        }, {
            name = "Dungeon",
            width = 260,
            align = "LEFT",
            DoCellUpdate = History_DoCellUpdate
        }, {
            name = "Diff",
            width = 70,
            align = "LEFT",
            DoCellUpdate = History_DoCellUpdate
        }, {
            name = "Time",
            width = 90,
            align = "RIGHT",
            DoCellUpdate = History_DoCellUpdate
        }, {
            name = "Result",
            width = 60,
            align = "LEFT",
            DoCellUpdate = History_DoCellUpdate
        }, {
            name = "PB",
            width = 40,
            align = "CENTER",
            DoCellUpdate = History_DoCellUpdate
        }, {
            name = "ΔPB",
            width = 80,
            align = "RIGHT",
            DoCellUpdate = History_DoCellUpdate
        }}

        local st = ST:CreateST(cols, 18, 18, nil, listFrame)
        if st and st.frame then
            st.frame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
            st.frame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", 0, 0)
            if st.head and st.head.cols then
                for i = 1, #cols do
                    StyleHeaderCell(st.head.cols[i], cols[i].align)
                end
            end
        end
        UI.history.st = st
    end

    local grip = SetupSizeGrip(historyFrame, function()
        SaveFrameGeom("history", historyFrame)
    end)
    UI.history.resizeGrip = grip
    UI.history.frame = historyFrame

    historyFrame:Hide()
    RefreshHistoryTable()
end

local function ToggleHistoryFrame()
    EnsureDB()
    EnsureHistoryUI()

    local frame = UI.history and UI.history.frame
    if not frame then
        return
    end

    if frame:IsShown() then
        frame:Hide()
        return
    end

    frame:Show()
    RefreshHistoryTable()
end

local function EnsureUI()
    if UI.bossFrame and UI.timerFrame then
        return
    end

    RestoreColWidths()

    -- Timer frame
    local timerFrame = CreateFrame("Frame", "SpeedSplitsTimerFrame", UIParent, "BackdropTemplate")
    timerFrame:SetFrameStrata("HIGH")
    timerFrame:SetClampedToScreen(true)
    timerFrame:SetMovable(true)
    timerFrame:EnableMouse(true)
    timerFrame:RegisterForDrag("LeftButton")
    ApplyResizeBounds(timerFrame, 180, 60, 900, 300)
    SetHoverBackdrop(timerFrame, 0.80)

    local timerRestored = RestoreFrameGeom("timer", timerFrame, 360, 80)
    if not timerRestored then
        timerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    timerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFrameGeom("timer", self)
    end)

    local timerText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerText:SetPoint("CENTER", timerFrame, "CENTER", 0, 0)
    timerText:SetText("00:00.000")

    local timerDeltaText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerDeltaText:SetPoint("TOP", timerText, "BOTTOM", 0, -2)
    timerDeltaText:SetText("")

    -- Boss frame
    local bossFrame = CreateFrame("Frame", "SpeedSplitsBossFrame", UIParent, "BackdropTemplate")
    bossFrame:SetFrameStrata("HIGH")
    bossFrame:SetClampedToScreen(true)
    bossFrame:SetMovable(true)
    bossFrame:EnableMouse(true)
    bossFrame:RegisterForDrag("LeftButton")
    bossFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    bossFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFrameGeom("boss", self)
    end)
    ApplyResizeBounds(bossFrame, 360, 180, 1400, 1000)
    SetHoverBackdrop(bossFrame, 0.80)

    local bossRestored = RestoreFrameGeom("boss", bossFrame, 520, 320)
    if not bossRestored then
        bossFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Title bar: drag handle only (avoids interfering with column resizers)
    UI._topInset = TOP_BAR_H + TOP_BAR_GAP
    local titleBar = CreateFrame("Frame", nil, bossFrame)
    titleBar:SetHeight(TOP_BAR_H)
    titleBar:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", bossFrame, "TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        bossFrame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        bossFrame:StopMovingOrSizing()
        SaveFrameGeom("boss", bossFrame)
    end)
    titleBar:Hide() -- Hide the old title bar handles as the whole frame is now draggable

    -- (killCountText and logoText in titleBar are now unused/hidden)

    -- Scrolling table (lib-st)
    local ST = ResolveScrollingTable()
    if not ST then
        SS_Print("Missing lib-st (ScrollingTable). Embed lib-st-v4.1.3/Core.lua and load before SpeedSplits.lua.")
    end

    local cols = {{
        name = "Boss",
        width = 220,
        align = "LEFT",
        DoCellUpdate = Boss_DoCellUpdate
    }, {
        name = "PB",
        width = UI._pbWidth,
        align = "CENTER",
        DoCellUpdate = Num_DoCellUpdate,
        color = PBColor
    }, {
        name = "Split",
        width = UI._splitWidth,
        align = "CENTER",
        DoCellUpdate = Num_DoCellUpdate,
        color = SplitColor
    }, {
        name = "Difference",
        width = UI._deltaWidth,
        align = "CENTER",
        DoCellUpdate = Num_DoCellUpdate,
        color = DeltaColor
    }}

    local st = ST and ST:CreateST(cols, 12, 24, nil, bossFrame)
    if st and st.frame then
        st.frame:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 6, -UI._topInset)
        st.frame:SetPoint("BOTTOMRIGHT", bossFrame, "BOTTOMRIGHT", -6, UI._bottomInset)

        if st.head and st.head.cols then
            for i = 1, #cols do
                StyleHeaderCell(st.head.cols[i], cols[i].align)
            end
        end
    end

    -- Totals row
    local totalFrame = CreateFrame("Frame", nil, bossFrame)
    totalFrame:SetHeight(20)
    totalFrame:SetPoint("BOTTOMLEFT", bossFrame, "BOTTOMLEFT", 6, 6)
    totalFrame:SetPoint("BOTTOMRIGHT", bossFrame, "BOTTOMRIGHT", -6, 6)
    totalFrame:EnableMouse(false)

    local totalLabel = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalLabel:SetJustifyH("RIGHT")
    totalLabel:SetText("Totals:")
    totalLabel:SetTextColor(Colors.turquoise.r, Colors.turquoise.g, Colors.turquoise.b, 1)

    local totalPB = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalPB:SetJustifyH("RIGHT")
    totalPB:SetText("--:--.---")

    local totalSplit = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalSplit:SetJustifyH("RIGHT")
    totalSplit:SetText("--:--.---")

    local totalDelta = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalDelta:SetJustifyH("RIGHT")
    totalDelta:SetText("--:--.---")

    -- History button
    local historyButton = CreateFrame("Button", nil, bossFrame)
    historyButton:SetSize(18, 18)

    local logoText = bossFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logoText:SetPoint("BOTTOMLEFT", bossFrame, "BOTTOMLEFT", 10, 8)
    logoText:SetText("SpeedSplits")
    logoText:SetTextColor(Colors.turquoise.r, Colors.turquoise.g, Colors.turquoise.b, 1)

    historyButton:SetPoint("LEFT", logoText, "RIGHT", 6, 0)

    local historyTex = historyButton:CreateTexture(nil, "ARTWORK")
    historyTex:SetAllPoints()
    historyTex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")

    historyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Runs History", 1, 1, 1)
        GameTooltip:Show()
        historyTex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    end)
    historyButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
        historyTex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    end)

    historyButton:SetScript("OnClick", ToggleHistoryFrame)

    -- Move totals beside history button
    totalFrame:ClearAllPoints()
    totalFrame:SetPoint("BOTTOMLEFT", historyButton, "BOTTOMRIGHT", 6, 2)
    totalFrame:SetPoint("BOTTOMRIGHT", bossFrame, "BOTTOMRIGHT", -6, 6)

    -- Resize grips
    local timerGrip = SetupSizeGrip(timerFrame, function()
        SaveFrameGeom("timer", timerFrame)
    end)

    local bossGrip = SetupSizeGrip(bossFrame, function()
        SaveFrameGeom("boss", bossFrame)
        ApplyTableLayout()
        SaveColWidths()
    end)

    bossFrame:SetScript("OnSizeChanged", function()
        ApplyTableLayout()
    end)

    -- Store UI refs
    UI.timerFrame = timerFrame
    UI.bossFrame = bossFrame
    UI.timerText = timerText
    UI.killCountText = killCountText
    UI.st = st
    UI.cols = cols
    UI.data = {}
    UI.rowByBossKey = {}
    UI.totalFrame = totalFrame
    UI.totalLabel = totalLabel
    UI.totalPB = totalPB
    UI.totalSplit = totalSplit
    UI.totalDelta = totalDelta
    UI.timerDeltaText = timerDeltaText
    UI.historyButton = historyButton
    UI.resizeGrip = bossGrip
    UI._timerResizeGrip = timerGrip

    EnsureColGrips()
    ApplyTableLayout()

    timerFrame:Hide()
    bossFrame:Hide()
end

local function SetTimerText(seconds, finished)
    if not UI.timerText then return end
    UI.timerText:SetText(FormatTime(seconds))
    local c = finished and Colors.green or Colors.white
    UI.timerText:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

local function SetTimerDelta(delta)
    if not UI.timerDeltaText then return end
    if delta == nil then
        UI.timerDeltaText:SetText("")
        return
    end
    UI.timerDeltaText:SetText(FormatDelta(delta))
    local r, g, b = DeltaToRGB(delta, delta < 0)
    UI.timerDeltaText:SetTextColor(r or 1, g or 1, b or 1, 1)
end


local function SetKillCount(killed, total)
    local text = string.format("Boss (%d/%d)", killed or 0, total or 0)
    
    -- Ensure persistence by updating the column definition
    if UI.cols and UI.cols[1] then
        UI.cols[1].name = text
    end

    if UI.st and UI.st.head and UI.st.head.cols and UI.st.head.cols[1] then
        local cell = UI.st.head.cols[1]
        local fs = cell.text or cell.label or (cell.GetFontString and cell:GetFontString())
        
        if not fs then
            local regions = { cell:GetRegions() }
            for _, r in ipairs(regions) do
                if r and r.IsObjectType and r:IsObjectType("FontString") then
                    fs = r
                    break
                end
            end
        end

        if fs and fs.SetText then
            fs:SetText(text)
        end
    end
end


local function SetTotals(pbTotal, splitTotal, deltaTotal, deltaR, deltaG, deltaB)
    if not UI.totalPB or not UI.totalSplit or not UI.totalDelta then
        return
    end

    UI.totalPB:SetText(FormatTime(pbTotal))
    UI.totalPB:SetTextColor(Colors.gold.r, Colors.gold.g, Colors.gold.b, 1)

    UI.totalSplit:SetText(FormatTime(splitTotal))
    if deltaR then
        UI.totalSplit:SetTextColor(deltaR, deltaG, deltaB, 1)
    else
        UI.totalSplit:SetTextColor(1, 1, 1, 1)
    end

    if deltaTotal == nil then
        UI.totalDelta:SetText("")
        UI.totalDelta:SetTextColor(1, 1, 1, 1)
        return
    end

    UI.totalDelta:SetText(FormatDelta(deltaTotal))
    if deltaR then
        UI.totalDelta:SetTextColor(deltaR, deltaG, deltaB, 1)
    else
        UI.totalDelta:SetTextColor(1, 1, 1, 1)
    end
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
    for _, entry in ipairs(entries) do
        local pbSegment = pbSegments[entry.key] or 0
        cumulativePB = cumulativePB + pbSegment
        data[#data + 1] = {
            key = entry.key,
            cols = {
                { value = entry.name or "Unknown" },
                { value = (cumulativePB > 0) and FormatTime(cumulativePB) or "--:--.---" },
                { value = "" },
                { value = "", color = nil }
            }
        }
        map[entry.key] = #data
    end

    if UI.st and UI.st.SetData then
        UI.st:SetData(data, true)
    end
    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end

    ApplyTableLayout()
end


local function GetPreviousKilledCumulativeInTableOrder(run, bossKey)
    local previous = nil
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

local function SetRowKilled(bossKey, splitCumulative, cumulativePB, deltaSeconds, deltaR, deltaG, deltaB, isGold)
    local realrow = UI.rowByBossKey and UI.rowByBossKey[bossKey]
    local row = realrow and UI.data and UI.data[realrow]
    if not row then
        return
    end

    row.cols[2].value = FormatTime(cumulativePB)
    row.cols[3].value = FormatTime(splitCumulative)
    
    if isGold then
        row.cols[3].color = Colors.gold
    else
        row.cols[3].color = { r = deltaR or 1, g = deltaG or 1, b = deltaB or 1, a = 1 }
    end

    if deltaSeconds == nil then
        row.cols[4].value = ""
        row.cols[4].color = nil
    else
        row.cols[4].value = FormatDelta(deltaSeconds)
        row.cols[4].color = { r = deltaR or 1, g = deltaG or 1, b = deltaB or 1, a = 1 }
    end

    if UI.st and UI.st.IsRowVisible and UI.st.Refresh and UI.st:IsRowVisible(realrow) then
        UI.st:Refresh()
        return
    end
    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end
end


-- =========================================================
-- Run state + PB update logic
-- =========================================================
local Run = {
    inInstance = false,

    active = false,
    waitingForMove = false,

    instanceName = "",
    instanceType = "",
    difficultyID = 0,
    mapID = 0,
    journalID = nil,
    tier = 0,

    dungeonKey = "",

    bossSource = "none",
    entries = {},
    remaining = {},
    remainingCount = 0,
    killedCount = 0,
    kills = {},

    startGameTime = 0,
    endGameTime = 0,
    startedAt = 0,
    endedAt = 0,

    _bossLoadTries = 0,
    _bossLoaded = false
}

-- =========================================================
-- Timer update (every frame, no throttling)
-- =========================================================
local TimerUpdater = CreateFrame("Frame")
local function CancelTimerTicker()
    TimerUpdater:SetScript("OnUpdate", nil)
end

local function StartTimerTicker()
    CancelTimerTicker()
    TimerUpdater:SetScript("OnUpdate", function()
        if Run.active and Run.startGameTime > 0 then
            SetTimerText(NowGameTime() - Run.startGameTime, false)
        end
    end)
end

-- =========================================================
-- Run state + PB update logic
-- =========================================================
local function ResetRun()
    Run.active = false
    Run.waitingForMove = false
    CancelTimerTicker()
    Run.entries = {}
    Run.remaining = {}
    Run.remainingCount = 0
    Run.killedCount = 0
    Run.kills = {}
    Run.startGameTime = 0
    Run.endGameTime = 0
    Run.startedAt = 0
    Run.endedAt = 0
    Run.bossSource = "none"
    Run.dungeonKey = ""
    Run._bossLoadTries = 0
    Run._bossLoaded = false
    SetTimerText(0, false)
    SetKillCount(0, 0)
    ClearBossRows()
    SetTotals(nil, nil, nil)
    SetTimerDelta(nil)
end

local function GetPBTableForDungeon(dungeonKey)
    DB.pbBoss = DB.pbBoss or {}
    DB.pbBoss[dungeonKey] = DB.pbBoss[dungeonKey] or {}
    return DB.pbBoss[dungeonKey]
end

local function ComputeSumOfBest(pbTable, entries)
    if not pbTable or not entries or #entries == 0 then
        return nil
    end
    local sum = 0
    for _, entry in ipairs(entries) do
        local segment = pbTable[entry.key]
        if segment == nil then
            return nil
        end
        sum = sum + segment
    end
    return sum
end

local function RefreshTotals(isFinal)
    local pbTable = (Run.dungeonKey ~= "") and (DB.pbBoss[Run.dungeonKey] or nil) or nil
    local pbTotal = pbTable and ComputeSumOfBest(pbTable, Run.entries) or nil

    if isFinal then
        local duration = (Run.endGameTime > 0 and Run.startGameTime > 0) and (Run.endGameTime - Run.startGameTime) or nil
        local deltaTotal = (duration and pbTotal) and (duration - pbTotal) or nil
        local r, g, b = DeltaToRGB(deltaTotal, deltaTotal and deltaTotal < 0)
        SetTotals(pbTotal, duration, deltaTotal, r, g, b)
        SetTimerDelta(deltaTotal)
        return
    end

    -- During run: show running total (sum of splits vs sum of PBs so far)
    local lastBossKey = nil
    for _, entry in ipairs(Run.entries) do
        if Run.kills[entry.key] then
            lastBossKey = entry.key
        else
            break
        end
    end

    if lastBossKey then
        local currentDuration = Run.kills[lastBossKey]
        local currentPB = 0
        for _, entry in ipairs(Run.entries) do
            currentPB = currentPB + (pbTable and pbTable[entry.key] or 0)
            if entry.key == lastBossKey then break end
        end
        local delta = currentDuration - currentPB
        local r, g, b = DeltaToRGB(delta, delta < 0)
        SetTotals(pbTotal, currentDuration, delta, r, g, b)
        SetTimerDelta(delta)
    else
        SetTotals(pbTotal, nil, nil)
        SetTimerDelta(nil)
    end
end

local function UpdateBestRunIfNeeded(durationSeconds)
    local key = Run.dungeonKey
    if not key or key == "" then
        return
    end

    local existing = DB.pbRun[key]
    if not existing or not existing.duration or durationSeconds < existing.duration then
        DB.pbRun[key] = {
            duration = durationSeconds,
            endedAt = Run.endedAt,
            instanceName = Run.instanceName,
            tier = Run.tier,
            difficultyID = Run.difficultyID,
            mapID = Run.mapID
        }
    end
end

local function SaveRunRecord(success)
    local duration = (Run.endGameTime > 0 and Run.startGameTime > 0) and (Run.endGameTime - Run.startGameTime) or nil

    local bosses = {}
    for _, entry in ipairs(Run.entries or {}) do
        bosses[#bosses + 1] = {
            key = entry.key,
            name = entry.name,
            encounterID = entry.encounterID
        }
    end

    local record = {
        success = success and true or false,
        instanceName = Run.instanceName,
        instanceType = Run.instanceType,
        difficultyID = Run.difficultyID,
        mapID = Run.mapID,
        dungeonKey = Run.dungeonKey,
        tier = Run.tier,
        bossSource = Run.bossSource,
        startedAt = Run.startedAt,
        endedAt = Run.endedAt,
        duration = duration,
        bosses = bosses,
        kills = Run.kills,
        gameBuild = select(4, GetBuildInfo())
    }

    table.insert(DB.runs, 1, record)
    while #DB.runs > RUNS_MAX do table.remove(DB.runs) end

    if success and duration then
        UpdateBestRunIfNeeded(duration)
    end
end

local function StopRun(success)
    if not Run.active then return end
    Run.active = false
    CancelTimerTicker()
    Run.endGameTime = NowGameTime()
    Run.endedAt = NowEpoch()
    local duration = Run.endGameTime - Run.startGameTime
    SetTimerText(duration, true)
    SaveRunRecord(success)
    if success then RefreshTotals(true) end
end

local function StartRunTimer()
    if Run.active then return end
    Run.active = true
    Run.waitingForMove = false
    Run.startedAt = NowEpoch()
    Run.startGameTime = NowGameTime()
    Run.endGameTime = 0
    Run.endedAt = 0
    SetTimerText(0, false)
    StartTimerTicker()
end

local function ResolveBossKey(encounterID, encounterName)
    if encounterID then
        local keyByID = "E:" .. tostring(tonumber(encounterID) or 0)
        if Run.remaining[keyByID] then
            return keyByID
        end
    end

    local normalized = NormalizeName(encounterName)
    if normalized ~= "" then
        local keyByName = "N:" .. normalized
        if Run.remaining[keyByName] then
            return keyByName
        end

        for _, entry in ipairs(Run.entries or {}) do
            if NormalizeName(entry.name) == normalized and Run.remaining[entry.key] then
                return entry.key
            end
        end
    end

    return nil
end

local function RecordBossKill(encounterID, encounterName)
    if not Run.active or Run.startGameTime <= 0 then
        return
    end

    local bossKey = ResolveBossKey(encounterID, encounterName)
    if not bossKey or Run.kills[bossKey] ~= nil then
        return
    end

    local splitCumulative = NowGameTime() - Run.startGameTime
    Run.kills[bossKey] = splitCumulative

    if Run.remaining[bossKey] then
        Run.remaining[bossKey] = nil
        Run.remainingCount = math.max(0, (Run.remainingCount or 0) - 1)
        Run.killedCount = math.min(#Run.entries, (Run.killedCount or 0) + 1)
    end

    local prevCumulative = GetPreviousKilledCumulativeInTableOrder(Run, bossKey)
    local splitSegment = prevCumulative and (splitCumulative - prevCumulative) or splitCumulative
    if splitSegment < 0 then
        splitSegment = 0
    end

    local pbTable = GetPBTableForDungeon(Run.dungeonKey)
    local oldSegmentPB = pbTable[bossKey]
    local isNewSegmentPB = (oldSegmentPB == nil) or (splitSegment < oldSegmentPB)

    -- Prepare cumulative comparison vs old PB sum
    local cumulativePB_Comparison = 0
    for _, entry in ipairs(Run.entries) do
        local seg = pbTable[entry.key] or 0
        cumulativePB_Comparison = cumulativePB_Comparison + seg
        if entry.key == bossKey then
            break
        end
    end

    -- Update the table with the new best segment
    if isNewSegmentPB then
        pbTable[bossKey] = splitSegment
    end

    -- Prepare cumulative display (sum of current best segments)
    local cumulativePB_Display = 0
    for _, entry in ipairs(Run.entries) do
        local seg = pbTable[entry.key] or 0
        cumulativePB_Display = cumulativePB_Display + seg
        if entry.key == bossKey then
            break
        end
    end

    local deltaOverall = splitCumulative - cumulativePB_Comparison
    local r, g, b = DeltaToRGB(deltaOverall, deltaOverall < 0)

    SetRowKilled(bossKey, splitCumulative, cumulativePB_Display, deltaOverall, r, g, b, isNewSegmentPB)

    SetKillCount(Run.killedCount, #Run.entries)
    RefreshTotals(false)

    if (Run.remainingCount or 0) == 0 and #Run.entries > 0 then
        StopRun(true)
    end
end

-- =========================================================
-- Boss list loading (Objectives first, EJ fallback)
-- =========================================================
local function ApplyBossEntries(entries, source, tier, journalID)
    Run.entries = entries or {}
    Run.bossSource = source or "none"
    Run.tier = tonumber(tier) or 0
    Run.journalID = journalID

    Run.remaining = {}
    Run.remainingCount = 0
    Run.killedCount = 0
    Run.kills = {}

    local seen = {}
    for _, entry in ipairs(Run.entries) do
        if entry.key and entry.key ~= "" and not seen[entry.key] then
            seen[entry.key] = true
            Run.remaining[entry.key] = true
            Run.remainingCount = Run.remainingCount + 1
        end
    end

    local pbSplits = (Run.dungeonKey ~= "") and (DB.pbBoss[Run.dungeonKey] or {}) or {}
    RenderBossTable(Run.entries, pbSplits)
    SetKillCount(0, #Run.entries)
    RefreshTotals(false)

    Run._bossLoaded = true
end

local function ForceLoadEJ()
    local tier, journalID = GetJournalTierAndInstanceIDForCurrentInstance()
    if journalID then
        local ejBosses = GetEJBossesForInstance(journalID)
        if #ejBosses > 0 then
            ApplyBossEntries(EJBossesToEntries(ejBosses), "encounter_journal", tier, journalID)
            return
        end
    end
    ApplyBossEntries({}, "none", tier, journalID)
end

local function TryLoadBossList()
    if Run._bossLoaded or not Run.inInstance then return end
    Run._bossLoadTries = (Run._bossLoadTries or 0) + 1
    local entries, source, tier, journalID, ready = BuildBossEntries()

    if not ready then
        if Run._bossLoadTries >= BOSS_LOAD_MAX_TRIES then
            ForceLoadEJ()
            return
        end
        C_Timer.After(BOSS_LOAD_RETRY_DELAY, function()
            if Run.inInstance and not Run._bossLoaded then TryLoadBossList() end
        end)
        return
    end
    ApplyBossEntries(entries, source, tier, journalID)
end


-- =========================================================
-- UI visibility / preview mode (show frames outside instances)
-- =========================================================
local function IsPreviewEnabled()
    local ui = DB and DB.ui
    return ui and ui.preview and true or false
end

local function SetPreviewEnabled(enabled)
    local ui = GetUISaved()
    if not ui then
        return
    end
    ui.preview = enabled and true or false
end

local function ShowAddonFrames()
    if UI.timerFrame then
        UI.timerFrame:Show()
    end
    if UI.bossFrame then
        UI.bossFrame:Show()
    end
end

local function HideAddonFrames()
    if UI.timerFrame then
        UI.timerFrame:Hide()
    end
    if UI.bossFrame then
        UI.bossFrame:Hide()
    end
end

-- =========================================================
-- Instance session begin
-- =========================================================
local function BeginInstanceSession()
    EnsureUI()

    local name, instanceType, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    local tier, journalID = GetJournalTierAndInstanceIDForCurrentInstance()

    Run.instanceName = name or ""
    Run.instanceType = instanceType or ""
    Run.difficultyID = tonumber(difficultyID) or 0
    Run.mapID = tonumber(mapID) or 0
    Run.journalID = journalID
    Run.tier = tonumber(tier) or 0
    Run.dungeonKey = GetDungeonKey(Run.mapID, Run.difficultyID)

    Run._bossLoadTries = 0
    Run._bossLoaded = false

    ShowAddonFrames()

    Run.waitingForMove = true
    SetTimerText(0, false)

    TryLoadBossList()
end

-- =========================================================
-- Event gating: only active in instances
-- =========================================================
local function EnableInstanceEvents()
    App:RegisterEvent("PLAYER_STARTED_MOVING")
    App:RegisterEvent("ENCOUNTER_END")
    App:RegisterEvent("BOSS_KILL")
    App:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    App:RegisterEvent("SCENARIO_UPDATE")
end

local function DisableInstanceEvents()
    App:UnregisterEvent("PLAYER_STARTED_MOVING")
    App:UnregisterEvent("ENCOUNTER_END")
    App:UnregisterEvent("BOSS_KILL")
    App:UnregisterEvent("SCENARIO_CRITERIA_UPDATE")
    App:UnregisterEvent("SCENARIO_UPDATE")
end

local function EnterOrUpdateWorld()
    Run.inInstance = IsInInstance() and true or false

    if not Run.inInstance then
        DisableInstanceEvents()

        if Run.active or Run.waitingForMove then
            StopRun(false)
        end

        ResetRun()

        if IsPreviewEnabled() then
            EnsureUI()
            ShowAddonFrames()
        else
            HideAddonFrames()
        end
        return
    end

    EnableInstanceEvents()
    ResetRun()
    BeginInstanceSession()

    if GetUnitSpeed("player") > 0 then
        StartRunTimer()
        App:UnregisterEvent("PLAYER_STARTED_MOVING")
    end
end

-- =========================================================
-- Main event handler
-- =========================================================
App:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= ADDON_NAME then
            return
        end
        EnsureDB()
        ResetRun()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        EnterOrUpdateWorld()
        return
    end

    if event == "PLAYER_LEAVING_WORLD" then
        if Run.active or Run.waitingForMove then
            StopRun(false)
        end
        DisableInstanceEvents()
        HideAddonFrames()
        ResetRun()
        return
    end

    if event == "SCENARIO_CRITERIA_UPDATE" or event == "SCENARIO_UPDATE" then
        if Run.inInstance and not Run._bossLoaded then
            TryLoadBossList()
        end
        return
    end

    if event == "PLAYER_STARTED_MOVING" then
        if Run.inInstance and Run.waitingForMove and not Run.active then
            StartRunTimer()
            App:UnregisterEvent("PLAYER_STARTED_MOVING")
        end
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        if success == 1 then
            RecordBossKill(encounterID, encounterName)
        end
        return
    end

    if event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        RecordBossKill(encounterID, encounterName)
        return
    end
end)


-- =========================================================
-- Slash commands
-- =========================================================
SLASH_SPEEDSPLITS1 = "/ss"
SlashCmdList.SPEEDSPLITS = function(msg)
    EnsureDB()
    msg = (msg or ""):match("^%s*(.-)%s*$") or ""
    local cmd = (msg:match("^(%S+)") or ""):lower()

    if cmd == "history" then
        ToggleHistoryFrame()
        return
    end

    if cmd == "" or cmd == "toggle" then
        local enabled = not IsPreviewEnabled()
        SetPreviewEnabled(enabled)
        EnsureUI()
        ResetRun()
        if enabled then
            ShowAddonFrames()
            SS_Print("Frames shown (preview mode).")
        else
            if not Run.inInstance then
                HideAddonFrames()
            end
            SS_Print("Frames hidden.")
        end
        return
    end

    if cmd == "show" or cmd == "on" then
        SetPreviewEnabled(true)
        EnsureUI()
        ResetRun()
        ShowAddonFrames()
        SS_Print("Frames shown (preview mode).")
        return
    end

    if cmd == "hide" or cmd == "off" then
        SetPreviewEnabled(false)
        if not Run.inInstance then
            HideAddonFrames()
        end
        SS_Print("Frames hidden.")
        return
    end

    SS_Print("Commands: /ss (toggle frames), /ss show, /ss hide, /ss history")
end

App:RegisterEvent("ADDON_LOADED")
App:RegisterEvent("PLAYER_ENTERING_WORLD")
App:RegisterEvent("PLAYER_LEAVING_WORLD")
