-- SpeedSplits.lua
-- Retail WoW addon: instance splits with objective-first boss discovery + EJ fallback.
local ADDON_NAME, NS            = ...
local App                       = CreateFrame("Frame")
NS.App                          = App

-- Constants
local COL_MAX_PB_SPLIT          = 260
local COL_MAX_DELTA             = 200
local COL_MIN_MODEL             = 36
local COL_MIN_BOSS              = 20
local COL_MIN_NUM               = 85
local COL_MIN_DELTA_TITLE       = 85
local GRIP_HALFWIDTH            = 5
local HEADER_H                  = 18
local RIGHT_INSET_DEFAULT       = 26
local TOP_BAR_H                 = 28
local TOP_BAR_GAP               = 4
local BOSS_LOAD_MAX_TRIES       = 40
local BOSS_LOAD_RETRY_DELAY     = 0.25
local RUNS_MAX                  = 200
local EJ_INSTANCE_INDEX_MAX     = 600
local EJ_ENCOUNTER_INDEX_MAX    = 80
local CRITERIA_MAX              = 80
local HISTORY_ROW_PAD           = 4
local HISTORY_ENTRY_SCALE       = 1.03
local HISTORY_DELETE_ICON_SCALE = 1.35
local BOSS_MODEL_ZOOM           = 0.75

NS.TitleTextures                = {
    "dragonflight-landingpage-renownbutton-centaur-hover",
    "dragonflight-landingpage-renownbutton-expedition-hover",
    "dragonflight-landingpage-renownbutton-locked",
    "dragonflight-landingpage-renownbutton-tuskarr-hover",
    "dragonflight-landingpage-renownbutton-valdrakken-hover",
    "dragonflight-landingpage-renownbutton-dream-hover",
}

-- History Column Widths
local HISTORY_COL_DEFAULTS      = {
    date = 130,
    dungeon = 220, -- Elastic, but used for fallback
    expansion = 140,
    time = 80,
    result = 130,
    diff = 120,
    delete = 30
}

local HISTORY_MIN_COL           = 40
local HISTORY_MIN_ELASTIC       = 100

-- =========================================================
-- Small utilities
-- =========================================================
local function Clamp(value, minV, maxV)
    return math.max(minV, math.min(maxV, value))
end

local function ApplyResizeBounds(frame, minW, minH, maxW, maxH)
    if not frame then return end
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW or 2500, maxH or 1600)
        return
    end
    if frame.SetMinResize then frame:SetMinResize(minW, minH) end
end

local NowEpoch = time
local NowGameTime = GetTime

local function NormalizeName(text)
    if text == nil then return "" end
    text = tostring(text):lower():gsub("[%-–—:,%s%p]", "")
    return text
end

SS_Print = function(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccccSpeedSplits|r: " .. tostring(msg))
    else
        print("SpeedSplits: " .. tostring(msg))
    end
end
local SS_Print = SS_Print

-- Debug toggle
SpeedSplits_DebugObjectives = SpeedSplits_DebugObjectives or false

local function FormatTime(seconds)
    if seconds == nil then return "--:--.---" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    local ms = math.floor((s - math.floor(s)) * 1000 + 0.5)
    if ms >= 1000 then ms = 999 end

    if h > 0 then
        return string.format("%d:%02d:%02d.%03d", h, m, math.floor(s), ms)
    elseif m > 0 then
        return string.format("%d:%02d.%03d", m, math.floor(s), ms)
    else
        return string.format("%d.%03d", math.floor(s), ms)
    end
end

local function FormatDelta(delta)
    if delta == nil then return "" end
    return (delta >= 0 and "+" or "-") .. FormatTime(math.abs(delta))
end

local function GetDungeonKey(mapID, difficultyID)
    return ("%d:%d"):format(tonumber(mapID) or 0, tonumber(difficultyID) or 0)
end

local function HistoryFilterDefaults()
    return {
        search = "",
        sortMode = "date", -- "date" or "time"
        tier = 0,
        result = "Any"
    }
end

-- =========================================================
-- Hex color system
-- =========================================================
local function PackColorCode(a, r, g, b)
    return string.format("|c%02x%02x%02x%02x",
        math.floor(Clamp(a, 0, 1) * 255 + 0.5),
        math.floor(Clamp(r, 0, 1) * 255 + 0.5),
        math.floor(Clamp(g, 0, 1) * 255 + 0.5),
        math.floor(Clamp(b, 0, 1) * 255 + 0.5))
end

local function HexToColor(hex)
    hex = tostring(hex or "ffffffff"):gsub("#", ""):lower()
    if #hex == 6 then hex = "ff" .. hex end
    if #hex ~= 8 then return { a = 1, r = 1, g = 1, b = 1, argb = "ffffffff", hex = "|cffffffff" } end

    local a = tonumber("0x" .. hex:sub(1, 2)) / 255
    local r = tonumber("0x" .. hex:sub(3, 4)) / 255
    local g = tonumber("0x" .. hex:sub(5, 6)) / 255
    local b = tonumber("0x" .. hex:sub(7, 8)) / 255
    return { a = a, r = r, g = g, b = b, argb = hex, hex = "|c" .. hex }
end

local Colors = {
    gold       = HexToColor("ffffd100"),
    white      = HexToColor("ffffffff"),
    turquoise  = HexToColor("ff00bec3"),
    deepGreen  = HexToColor("ff10ff00"),
    lightGreen = HexToColor("ffcc2232"),
    darkRed    = HexToColor("ffcc0005"),
}
NS.Colors = Colors


local function InterpolateColor(c1, c2, t)
    t = Clamp(t, 0, 1)
    local a = (c1.a or 1) + ((c2.a or 1) - (c1.a or 1)) * t
    local r = c1.r + (c2.r - c1.r) * t
    local g = c1.g + (c2.g - c1.g) * t
    local b = c1.b + (c2.b - c1.b) * t
    return r, g, b, PackColorCode(a, r, g, b)
end

local function GetPaceColor(delta, isPB)
    if delta == nil then return 1, 1, 1, "|cffffffff" end
    -- Gold if new PB or a tie (+0.000)
    if isPB or math.abs(delta) < 0.001 then
        return Colors.gold.r, Colors.gold.g, Colors.gold.b, Colors.gold.hex
    end
    if delta < 0 then
        return Colors.deepGreen.r, Colors.deepGreen.g, Colors.deepGreen.b, Colors.deepGreen.hex
    end
    local t1, t2 = 4, 12
    if delta <= t1 then
        return InterpolateColor(Colors.deepGreen, Colors.lightGreen, delta / t1)
    elseif delta <= t2 then
        return InterpolateColor(Colors.lightGreen, Colors.darkRed, (delta - t1) / (t2 - t1))
    end
    return Colors.darkRed.r, Colors.darkRed.g, Colors.darkRed.b, Colors.darkRed.hex
end
NS.GetPaceColor = GetPaceColor

-- =========================================================
-- SavedVariables
-- =========================================================
local DB
local UI

local function EnsureDB()
    if SpeedSplitsDB == nil then
        SpeedSplitsDB = {}
    end

    -- Human-readable structure
    SpeedSplitsDB.RunHistory             = SpeedSplitsDB.RunHistory or SpeedSplitsDB.runs or {}
    SpeedSplitsDB.InstancePersonalBests  = SpeedSplitsDB.InstancePersonalBests or SpeedSplitsDB.PersonalBests or
        SpeedSplitsDB.bestSplits or {}
    SpeedSplitsDB.Settings               = SpeedSplitsDB.Settings or SpeedSplitsDB.settings or {}

    -- Clean up old keys
    SpeedSplitsDB.runs                   = nil
    SpeedSplitsDB.bestSplits             = nil
    SpeedSplitsDB.PersonalBests          = nil
    SpeedSplitsDB.settings               = nil
    SpeedSplitsDB.pbBoss                 = nil
    SpeedSplitsDB.pbRun                  = nil

    -- Defaults
    SpeedSplitsDB.Settings.colors        = SpeedSplitsDB.Settings.colors or {
        gold       = "ffffd100",
        white      = "ffffffff",
        turquoise  = "ff00bec3",
        deepGreen  = "ff10ff00",
        lightGreen = "ffcc2232",
        darkRed    = "ffcc0005",
    }
    SpeedSplitsDB.Settings.fonts         = SpeedSplitsDB.Settings.fonts or {}
    SpeedSplitsDB.Settings.fonts.boss    = SpeedSplitsDB.Settings.fonts.boss or
        { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.num     = SpeedSplitsDB.Settings.fonts.num or
        { size = 17, font = "Fonts\\ARIALN.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.timer   = SpeedSplitsDB.Settings.fonts.timer or
        { size = 30, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.header  = SpeedSplitsDB.Settings.fonts.header or
        { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.counter = SpeedSplitsDB.Settings.fonts.counter or
        { size = 16, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.historyScale  = SpeedSplitsDB.Settings.historyScale or 1.0
    SpeedSplitsDB.Settings.titleTexture  = SpeedSplitsDB.Settings.titleTexture or NS.TitleTextures[1]

    -- Profile for default styles (Reset Styles will use this)
    if not SpeedSplitsDB.DefaultStyle then
        SpeedSplitsDB.DefaultStyle = {
            colors = {
                gold       = "ffffd100",
                white      = "ffffffff",
                turquoise  = "ff00bec3",
                deepGreen  = "ff10ff00",
                lightGreen = "ffcc2232",
                darkRed    = "ffcc0005",
            },
            fonts = {
                boss    = { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
                num     = { size = 17, font = "Fonts\\ARIALN.TTF", flags = "OUTLINE" },
                timer   = { size = 30, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
                header  = { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
                counter = { size = 16, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            },
            titleTexture = NS.TitleTextures[1]
        }
    end

    DB    = SpeedSplitsDB
    NS.DB = DB

    -- Ensure History filters are ready
    if UI and UI.history then
        UI.history.filters = UI.history.filters or HistoryFilterDefaults()
    end
end

function NS.WipeDatabase()
    SpeedSplitsDB.InstancePersonalBests = {}
    SpeedSplitsDB.RunHistory = {}
    EnsureDB()
    NS.UpdateColorsFromSettings()
    NS.RefreshAllUI()
    SS_Print("Personal Best records and Run History have been wiped.")
end

function NS.ResetLayout()
    if SpeedSplitsDB then
        SpeedSplitsDB.ui = nil
        NS.RefreshAllUI()
        ReloadUI()
    end
end

local function GetBestSplitsSubtable(instanceName)
    instanceName = instanceName or (NS.Run and NS.Run.instanceName)
    if not instanceName or instanceName == "" then return nil end

    DB.InstancePersonalBests = DB.InstancePersonalBests or {}

    -- Migrate if old structure exists
    if DB.InstancePersonalBests[instanceName] and not DB.InstancePersonalBests[instanceName].Segments then
        local oldInstance = DB.InstancePersonalBests[instanceName]
        -- Check if it contains difficulty tables (old behavior)
        local firstDiff = nil
        for _, val in pairs(oldInstance) do
            if type(val) == "table" and val.pbBoss then
                firstDiff = val
                break
            end
        end

        if firstDiff then
            DB.InstancePersonalBests[instanceName] = {
                Segments = firstDiff.pbBoss or {},
                FullRun = firstDiff.pbRun or {}
            }
        else
            -- Check if old structure was just keys directly (unlikely but safe)
            DB.InstancePersonalBests[instanceName] = { Segments = {}, FullRun = {} }
        end
    end

    DB.InstancePersonalBests[instanceName] = DB.InstancePersonalBests[instanceName] or { Segments = {}, FullRun = {} }
    return DB.InstancePersonalBests[instanceName]
end

local function GetPBTableForDungeon(instanceName)
    local node = GetBestSplitsSubtable(instanceName)
    return node and node.Segments
end

function NS.UpdateColorsFromSettings()
    if not DB or not DB.Settings or not DB.Settings.colors then return end
    local s = DB.Settings.colors
    for k, hex in pairs(s) do
        local newC = HexToColor(hex)
        if NS.Colors[k] then
            local c = NS.Colors[k]
            c.r, c.g, c.b, c.a = newC.r, newC.g, newC.b, newC.a
            c.argb, c.hex = newC.argb, newC.hex
        else
            NS.Colors[k] = newC
        end
    end
end

function NS.ApplyFontToFS(fs, typeKey, multiplier)
    if not fs then return end
    local f = (NS.DB and NS.DB.Settings and NS.DB.Settings.fonts and NS.DB.Settings.fonts[typeKey])
        or (NS.DB and NS.DB.Settings and NS.DB.Settings.fonts and NS.DB.Settings.fonts.num)

    local fontPath = f and f.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = f and f.size or 12
    local fontFlags = f and f.flags or "OUTLINE"

    multiplier = multiplier or 1
    local finalSize = math.max(1, math.floor(fontSize * multiplier + 0.5))
    local success = fs:SetFont(fontPath, finalSize, fontFlags)
    if not success then
        fs:SetFont("Fonts\\FRIZQT__.TTF", finalSize, fontFlags)
    end
    if not fs:GetFont() then
        fs:SetFontObject("GameFontHighlight")
    end
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
        if tonumber(instanceID) == targetID then
            found = ti; return true
        end
    end)
    return found
end

local function FindJournalTierAndInstanceIDByName(instanceName)
    local wanted = NormalizeName(instanceName)
    if wanted == "" then return nil, nil end

    local foundTier, foundID
    -- Pass 1: Exact normalized match
    ForEachEJInstance(function(ti, instanceID, name)
        if NormalizeName(name) == wanted then
            foundTier, foundID = ti, instanceID
            return true
        end
    end)
    if foundID then return foundTier, foundID end

    -- Pass 2: Fuzzy matching (substrings)
    -- We want the "closest" match to avoid AQ20 vs AQ40 confusion.
    local bestTier, bestID, bestLen = nil, nil, 999
    ForEachEJInstance(function(ti, instanceID, name)
        local normalizedEJ = NormalizeName(name)
        if normalizedEJ:find(wanted, 1, true) or wanted:find(normalizedEJ, 1, true) then
            -- If multiple fuzzy matches exist, pick the one with the smallest length difference
            -- or prioritize keywords like "Temple" if they exist in the target.
            local diff = math.abs(#normalizedEJ - #wanted)
            if diff < bestLen then
                bestLen = diff
                bestTier = ti
                bestID = instanceID
            end
        end
    end)

    return bestTier, bestID
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

UI = {
    timerFrame = nil,
    bossFrame = nil,

    timerText = nil,
    killCountText = nil,

    historyButton = nil,

    -- lib-st
    st = nil,
    cols = nil,
    data = nil,         -- array of lib-st rows
    rowByBossKey = nil, -- bossKey -> realrow index in data

    -- Resizable widths (boss is computed as "fill remaining")
    _modelWidth = 40,
    _pbWidth = 80,
    _splitWidth = 80,
    _deltaWidth = 60,

    leftBorder = nil,
    rightBorder = nil,

    _rightInset = RIGHT_INSET_DEFAULT,
    _topInset = RIGHT_INSET_DEFAULT,
    _bottomInset = 34, -- Increased for Totals spacing

    _colGrips = nil,   -- separator grips
    _colDrag = nil,    -- active drag state

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

    -- Update stacking constants and positions
    UI._topInset = TOP_BAR_H + 2
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

    -- Table Column scaling logic
    UI._rightInset = GetScrollBarInset(UI.st)
    local w = UI.st.frame:GetWidth() or 1
    local available = math.max(w - UI._rightInset, 1)

    local minDelta = COL_MIN_NUM
    UI._pbWidth = Clamp(UI._pbWidth, COL_MIN_NUM,
        math.max(available - (UI._modelWidth + COL_MIN_BOSS + UI._splitWidth + minDelta), COL_MIN_NUM))
    UI._splitWidth = Clamp(UI._splitWidth, COL_MIN_NUM,
        math.max(available - (UI._modelWidth + COL_MIN_BOSS + UI._pbWidth + minDelta), COL_MIN_NUM))
    UI._deltaWidth = Clamp(UI._deltaWidth, minDelta,
        math.max(available - (UI._modelWidth + COL_MIN_BOSS + UI._pbWidth + UI._splitWidth), minDelta))
    local bossWidth = math.max(available - (UI._modelWidth + UI._pbWidth + UI._splitWidth + UI._deltaWidth), COL_MIN_BOSS)

    UI.cols[1].width = UI._modelWidth
    UI.cols[2].width = bossWidth
    UI.cols[3].width = UI._pbWidth
    UI.cols[4].width = UI._splitWidth
    UI.cols[5].width = UI._deltaWidth

    if UI.st.SetDisplayCols then
        UI.st:SetDisplayCols(UI.cols)
    else
        UI.st.cols = UI.cols
    end
    if UI.st.Refresh then
        UI.st:Refresh()
    end

    -- Totals row alignment (Right aligned to columns)
    local tf = UI.totalFrame
    if tf then
        local combinedBossWidth = UI._modelWidth + bossWidth
        local rInset = UI._rightInset + 4

        UI.totalDelta:ClearAllPoints()
        UI.totalDelta:SetPoint("RIGHT", tf, "RIGHT", -rInset, 0)
        UI.totalDelta:SetWidth(UI._deltaWidth)
        UI.totalDelta:SetJustifyH("RIGHT")

        UI.totalSplit:ClearAllPoints()
        UI.totalSplit:SetPoint("RIGHT", UI.totalDelta, "LEFT", -0, 0)
        UI.totalSplit:SetWidth(UI._splitWidth)
        UI.totalSplit:SetJustifyH("RIGHT")

        UI.totalPB:ClearAllPoints()
        UI.totalPB:SetPoint("RIGHT", UI.totalSplit, "LEFT", -0, 0)
        UI.totalPB:SetWidth(UI._pbWidth)
        UI.totalPB:SetJustifyH("RIGHT")
    end

    -- Position separator grips
    if UI._colGrips then
        local xBossRight = UI._modelWidth + bossWidth
        local xPBRight = UI._modelWidth + bossWidth + UI._pbWidth
        local xSplitRight = UI._modelWidth + bossWidth + UI._pbWidth + UI._splitWidth
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
        -- BossWidth = available - (Model + PB + Split + Diff). Cannot be less than COL_MIN_BOSS.
        local maxPB = math.max(COL_MIN_NUM, available - (UI._modelWidth + UI._splitWidth + UI._deltaWidth + COL_MIN_BOSS))
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
    grip:SetFrameLevel((parent:GetFrameLevel() or 0) + 50) -- Above the border overlay
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
    UI._colGrips = { MakeGrip(UI.st.frame, 1), MakeGrip(UI.st.frame, 2), MakeGrip(UI.st.frame, 3) }
end

local function StyleHeaderCell(cell, align, multiplier, text)
    if not cell then return end
    local fs = cell.text or cell.label or (cell.GetFontString and cell:GetFontString())
    if not fs then
        local regions = { cell:GetRegions() }
        for _, r in ipairs(regions) do
            if r and r.IsObjectType and r:IsObjectType("FontString") then
                fs = r; break
            end
        end
    end
    if not fs then return end

    if text then fs:SetText(text) end

    fs:SetJustifyH(align or "CENTER")
    fs:SetJustifyV("MIDDLE")

    -- Sync to header font settings + optional multiplier
    NS.ApplyFontToFS(fs, "header", multiplier)

    fs:SetTextColor(1, 0.82, 0, 1)
    fs:SetDrawLayer("OVERLAY", 7) -- Match Boss Counter's overlay priority
    fs:ClearAllPoints()
    fs:SetAllPoints(cell)
end

local function Model_DoCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, stable)
    if not fShow or not realrow then
        if cellFrame and cellFrame.model then cellFrame.model:Hide() end
        return
    end

    if not cellFrame.model then
        local m = CreateFrame("PlayerModel", nil, cellFrame)
        m:SetAllPoints()
        m:SetPoint("TOPLEFT", cellFrame, "TOPLEFT", 1, -1)
        m:SetPoint("BOTTOMRIGHT", cellFrame, "BOTTOMRIGHT", -1, 1)
        cellFrame.model = m
    end

    -- Testing IDs (first 5 bosses)
    local displayIDs = { 52047, 6110, 52515, 52595, 31042 }
    local id = displayIDs[realrow]

    if id then
        cellFrame.model:SetDisplayInfo(id)
        cellFrame.model:SetKeepModelOnHide(true)
        cellFrame.model:Show()
        cellFrame.model:SetPortraitZoom(BOSS_MODEL_ZOOM)
    else
        cellFrame.model:Hide()
    end
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

        local val = cell.display or cell.value or ""
        cellFrame.text:SetText(val)

        -- Apply font with scale (non-compounding)
        local hScale = (opts.fontScale or 1.0)
        NS.ApplyFontToFS(cellFrame.text, "num", hScale)

        cellFrame.text:SetJustifyH(opts.justifyH or cols[column].align or "LEFT")
        cellFrame.text:SetJustifyV(opts.justifyV or "MIDDLE")
        if opts.wordWrap then cellFrame.text:SetWordWrap(true) end
        if opts.maxLines and cellFrame.text.SetMaxLines then cellFrame.text:SetMaxLines(opts.maxLines) end
        local c = (opts.useColColor and cols[column].color) and cols[column].color(data, cols, realrow, column, stable) or
            cell.color
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
    cellFrame:SetClipsChildren(true)
    local e = data[realrow]
    local cell = e and e.cols and e.cols[1] -- Boss name is always first in data
    if not cell then return end
    cellFrame.text:SetText(cell.value or "")
    NS.ApplyFontToFS(cellFrame.text, "boss")
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
    local dataIndex = column - 1
    local cell = e and e.cols and e.cols[dataIndex]
    if not cell then return end

    local val = cell.value or ""
    cellFrame.text:SetText(val)
    NS.ApplyFontToFS(cellFrame.text, "num")

    -- Request 6: Perfect Alignment of : and .
    -- We use a right-aligned fontstring anchored to a fixed point relative to CENTER.
    -- This ensures that for a consistent font like Arial Narrow, the separators align.
    cellFrame.text:SetJustifyH("RIGHT")
    cellFrame.text:SetJustifyV("MIDDLE")
    cellFrame.text:ClearAllPoints()
    -- Request 3 & 6: Fixed point alignment for colons/dots with padding
    cellFrame.text:SetPoint("RIGHT", cellFrame, "CENTER", 34, 0)
    -- Remove horizontal padding constraints to allow the "Remove any padding" request
    cellFrame.text:SetWidth(0)

    local dataIndex = column - 1
    local c = (cols[column].color) and cols[column].color(data, cols, realrow, column, stable) or cell.color
    if c then
        cellFrame.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
    else
        cellFrame.text:SetTextColor(1, 1, 1, 1)
    end
end

local function DeltaColor(data, cols, realrow, column)
    local e = data[realrow]
    local dataIndex = column - 1
    local cell = e and e.cols and e.cols[dataIndex]
    return cell and cell.color or nil
end

local function PBColor()
    return Colors.gold
end

local function SplitColor(data, cols, realrow, column)
    local e = data[realrow]
    local dataIndex = column - 1
    local cell = e and e.cols and e.cols[dataIndex]
    return cell and cell.color or nil
end

local function DeleteRecord(record)
    if not DB or not DB.RunHistory then return end
    for i, r in ipairs(DB.RunHistory) do
        if r == record then
            table.remove(DB.RunHistory, i)
            if UI and UI.RefreshHistoryTable then UI.RefreshHistoryTable() end
            return
        end
    end
end

local Delete_DoCellUpdate = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, stable)
    if not fShow or not realrow then
        if cellFrame.delBtn then cellFrame.delBtn:Hide() end
        return
    end

    if not cellFrame.delBtn then
        local btn = CreateFrame("Button", nil, cellFrame)
        btn:SetSize(24, 24)
        btn:SetPoint("LEFT", cellFrame, "LEFT", 4, 0)


        local normal = btn:GetNormalTexture()
        if not normal then
            normal = btn:CreateTexture(nil, "ARTWORK")
            btn:SetNormalTexture(normal)
        end
        normal:SetAtlas("SCRAP-activated", true)

        local highlight = btn:GetHighlightTexture()
        if not highlight then
            highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            btn:SetHighlightTexture(highlight)
        end
        highlight:SetAtlas("SCRAP-activated", true)
        highlight:SetAlpha(0.35)
        btn:SetScript("OnClick", function(self)
            if self.record then
                DeleteRecord(self.record)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Delete entry", 1, 0, 0)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
        cellFrame.delBtn = btn
    end

    -- Update icon size and record reference every update
    local btn = cellFrame.delBtn
    local hScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
    local size = math.max(1, math.floor(16 * HISTORY_DELETE_ICON_SCALE * hScale + 0.5))

    local normal = btn:GetNormalTexture()
    normal:ClearAllPoints()
    normal:SetPoint("CENTER")
    normal:SetSize(size, size)

    local highlight = btn:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetPoint("CENTER")
    highlight:SetSize(size, size)

    btn.record = data[realrow]
    btn:Show()
end

-- =========================================================
-- Runs History UI
-- =========================================================
local function FormatEpochShort(epoch)
    if not epoch or epoch <= 0 then
        return "—"
    end
    return date("%H:%M %d/%m/%Y", epoch)
end

local function GetTierNameSafe(tierIndex)
    tierIndex = tonumber(tierIndex)
    if not tierIndex or tierIndex <= 0 then
        return "Unknown"
    end

    -- Prefer Encounter Journal data when available.
    if EJ_GetTierInfo then
        local name = EJ_GetTierInfo(tierIndex)
        if type(name) == "string" and name ~= "" and name ~= tostring(tierIndex) then
            return name
        end
    end

    -- Fallback mapping (keeps UI readable even if EJ isn't ready).
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

    local node = GetBestSplitsSubtable(record.instanceName)
    local pb = node and node.FullRun

    if type(pb) ~= "table" or not pb.duration then
        return false
    end
    -- Allow slight float margin
    return math.abs(record.duration - pb.duration) < 0.001
end

local function BuildHistoryTierItems()
    local items = { {
        text = "Any",
        value = 0
    } }
    if not DB or not DB.RunHistory then
        return items
    end
    local seen = {}
    for _, r in ipairs(DB.RunHistory) do
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
    local items = { {
        text = "Any",
        value = 0
    } }
    if not DB or not DB.RunHistory then
        return items
    end
    local seen = {}
    for _, r in ipairs(DB.RunHistory) do
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

local function BuildHistoryResultItems()
    return {
        { text = "Any Result", value = "Any" },
        { text = "PB",         value = "PB" },
        { text = "Completed",  value = "Completed" },
        { text = "Incomplete", value = "Incomplete" }
    }
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

local History_DoCellUpdate = function(...)
    local hScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
    local updater = MakeCellUpdater { fontScale = HISTORY_ENTRY_SCALE * hScale }
    updater(...)
end

-- NOTE:
-- LibScrollingTable typically handles DESC sorting by swapping rowA/rowB when invoking the sort.
-- Therefore our comparator must be a strict ASC comparator (stable + transitive). DESC will "just work".
local function History_NormalizeSortValue(v)
    if v == nil then return nil end
    local t = type(v)
    if t == "string" then return v:lower() end
    if t == "number" then return v end
    if t == "boolean" then return v and 1 or 0 end
    return tostring(v):lower()
end

local function HistoryColumnSort(st, rowA, rowB, sortCol)
    -- Primary sort (ASC)
    local cellA = rowA.cols and rowA.cols[sortCol]
    local cellB = rowB.cols and rowB.cols[sortCol]
    local valA = History_NormalizeSortValue(cellA and cellA.value)
    local valB = History_NormalizeSortValue(cellB and cellB.value)

    if valA ~= valB then
        if valA == nil then return false end -- nil always sorts last
        if valB == nil then return true end
        return valA < valB
    end

    -- Tie-breaker: run timestamp (ASC)
    local tA = tonumber(rowA.record and (rowA.record.startedAt or rowA.record.endedAt) or 0) or 0
    local tB = tonumber(rowB.record and (rowB.record.startedAt or rowB.record.endedAt) or 0) or 0
    if tA ~= tB then
        return tA < tB
    end

    -- Final stability: render index (ASC)
    local iA = tonumber(rowA.sortIndex) or 0
    local iB = tonumber(rowB.sortIndex) or 0
    return iA < iB
end

UI.RefreshHistoryTable = function()
    if not UI or not UI.history or not UI.history.st then return end

    -- Safe filter check
    if not UI.history.filters then
        UI.history.filters = HistoryFilterDefaults()
    end

    local f = UI.history.filters
    local search = NormalizeName(f.search or "")
    local filterResult = f.result or "Any"
    local filterTier = f.tier or 0

    local rows = {}
    local history = DB and DB.RunHistory
    if type(history) == "table" then
        for i = 1, #history do
            local r = history[i]
            if type(r) == "table" and r.instanceName then
                local matchesSearch = (search == "" or NormalizeName(r.instanceName):find(search, 1, true))
                local matchesTier = (filterTier == 0 or (tonumber(r.tier) == filterTier))

                -- Result filtering logic
                local isPB = IsRunPB(r)
                local matchesResult = true
                if filterResult == "PB" then
                    matchesResult = isPB
                elseif filterResult == "Completed" then
                    matchesResult = (r.success and not isPB)
                elseif filterResult == "Incomplete" then
                    matchesResult = (not r.success)
                end

                if matchesSearch and matchesTier and matchesResult then
                    rows[#rows + 1] = r
                end
            end
        end
    end

    -- Default ordering for refresh (header sorting can still override this)
    table.sort(rows, function(a, b)
        if f.sortMode == "time" then
            local durA = tonumber(a and a.duration) or math.huge
            local durB = tonumber(b and b.duration) or math.huge
            if durA ~= durB then
                return durA < durB
            end
        end

        local timeA = tonumber(a and (a.startedAt or a.endedAt) or 0) or 0
        local timeB = tonumber(b and (b.startedAt or b.endedAt) or 0) or 0
        return timeA < timeB
    end)

    local data = {}
    for i = 1, #rows do
        local r = rows[i]
        local isPB = IsRunPB(r)

        -- Determine Result Status
        local resultText = "Incomplete"
        local resultColor = NS.Colors.darkRed
        if isPB then
            resultText = "PB"
            resultColor = NS.Colors.gold
        elseif r.success then
            resultText = "Completed"
            resultColor = NS.Colors.deepGreen
        end

        local node = GetBestSplitsSubtable(r.instanceName)
        local pb = node and node.FullRun
        local duration = tonumber(r.duration)
        local pbDur = pb and tonumber(pb.duration)

        local deltaPB = (pbDur and duration) and (duration - pbDur) or nil
        local deltaText = "—"
        if deltaPB then
            local _, _, _, hex = NS.GetPaceColor(deltaPB, isPB)
            deltaText = (hex or "|cffffffff") .. FormatDelta(deltaPB) .. "|r"
        end

        local resultOrder = isPB and 1 or (r.success and 2 or 3)
        local startedEpoch = tonumber(r.startedAt or r.endedAt or 0) or 0
        local tierIndex = tonumber(r.tier) or 0
        local tierName = GetTierNameSafe(tierIndex)
        local rowColor = isPB and NS.Colors.gold or nil

        data[#data + 1] = {
            record = r,
            sortIndex = i,
            cols = {
                {
                    value = startedEpoch,
                    display = FormatEpochShort(startedEpoch),
                    color = rowColor
                },
                {
                    value = r.instanceName or "—",
                    color = rowColor
                },
                {
                    value = tierIndex,
                    display = tierName,
                    color = rowColor
                },
                {
                    value = resultOrder,
                    display = resultText,
                    color = resultColor
                },
                {
                    value = duration,
                    display = duration and FormatTime(duration) or "--:--.---",
                    color = rowColor
                },
                {
                    value = deltaPB,
                    display = deltaText
                },
                {
                    value = "" -- Delete col
                }
            }
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
                if UI.RefreshHistoryTable then UI.RefreshHistoryTable() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end



-- =========================================================
-- History Resizable Columns Logic
-- =========================================================

local function History_SaveColWidths()
    local ui = GetUISaved()
    if not ui or not UI.history or not UI.history.colWidths then return end
    ui.historyCols = ui.historyCols or {}
    for k, v in pairs(UI.history.colWidths) do
        ui.historyCols[k] = v
    end
end

local function History_RestoreColWidths()
    UI.history.colWidths = {}
    local ui = GetUISaved()
    local saved = ui and ui.historyCols
    for k, def in pairs(HISTORY_COL_DEFAULTS) do
        UI.history.colWidths[k] = (saved and saved[k]) and tonumber(saved[k]) or def
    end
end

local function History_ApplyTableLayout()
    local h = UI.history
    if not h.frame or not h.st or not h.st.frame or not h.colWidths then return end

    -- Calculation logic
    local frameW = h.st.frame:GetWidth() or 1
    local inset = GetScrollBarInset(h.st)
    local available = math.max(frameW - inset, 1)

    local w = h.colWidths

    -- Dungeon is elastic
    local used = w.date + w.expansion + w.time + w.result + w.diff + w.delete
    local dungeonW = math.max(available - used, HISTORY_MIN_ELASTIC)

    local cols = h.st.cols or h.st.head.cols
    -- Update column objects if possible (depends on lib-st version internals, but SetDisplayCols is standard)
    -- We need to reconstruct the "cols" definitions with new widths or update them in place?
    -- lib-st typically stores width in .width.
    -- However, we must ensure the `cols` table passed to CreateST is accessible.
    -- We can access h.st.cols usually.

    if not h.st.cols then return end

    h.st.cols[1].width = w.date
    h.st.cols[2].width = dungeonW
    h.st.cols[3].width = w.expansion
    h.st.cols[4].width = w.time
    h.st.cols[5].width = w.result
    h.st.cols[6].width = w.diff
    h.st.cols[7].width = w.delete

    if h.st.SetDisplayCols then
        h.st:SetDisplayCols(h.st.cols)
    end
    if h.st.Refresh then
        h.st:Refresh()
    end

    -- Update Grips
    if h.grips then
        local gv = -HEADER_H
        local x = 0

        -- Grip 1: Date | Dungeon
        x = x + w.date
        h.grips[1]:ClearAllPoints()
        h.grips[1]:SetPoint("TOPLEFT", h.st.frame, "TOPLEFT", x - GRIP_HALFWIDTH, 0)
        h.grips[1]:SetPoint("BOTTOMRIGHT", h.st.frame, "TOPLEFT", x + GRIP_HALFWIDTH, gv)

        -- Grip 2: Dungeon | Expansion
        x = x + dungeonW
        h.grips[2]:ClearAllPoints()
        h.grips[2]:SetPoint("TOPLEFT", h.st.frame, "TOPLEFT", x - GRIP_HALFWIDTH, 0)
        h.grips[2]:SetPoint("BOTTOMRIGHT", h.st.frame, "TOPLEFT", x + GRIP_HALFWIDTH, gv)

        -- Grip 3: Expansion | Time
        x = x + w.expansion
        h.grips[3]:ClearAllPoints()
        h.grips[3]:SetPoint("TOPLEFT", h.st.frame, "TOPLEFT", x - GRIP_HALFWIDTH, 0)
        h.grips[3]:SetPoint("BOTTOMRIGHT", h.st.frame, "TOPLEFT", x + GRIP_HALFWIDTH, gv)

        -- Grip 4: Time | Result
        x = x + w.time
        h.grips[4]:ClearAllPoints()
        h.grips[4]:SetPoint("TOPLEFT", h.st.frame, "TOPLEFT", x - GRIP_HALFWIDTH, 0)
        h.grips[4]:SetPoint("BOTTOMRIGHT", h.st.frame, "TOPLEFT", x + GRIP_HALFWIDTH, gv)

        -- Grip 5: Result | Diff
        x = x + w.result
        h.grips[5]:ClearAllPoints()
        h.grips[5]:SetPoint("TOPLEFT", h.st.frame, "TOPLEFT", x - GRIP_HALFWIDTH, 0)
        h.grips[5]:SetPoint("BOTTOMRIGHT", h.st.frame, "TOPLEFT", x + GRIP_HALFWIDTH, gv)

        -- Grip 6: Diff | Delete
        x = x + w.diff
        h.grips[6]:ClearAllPoints()
        h.grips[6]:SetPoint("TOPLEFT", h.st.frame, "TOPLEFT", x - GRIP_HALFWIDTH, 0)
        h.grips[6]:SetPoint("BOTTOMRIGHT", h.st.frame, "TOPLEFT", x + GRIP_HALFWIDTH, gv)
    end
end

local function History_BeginColDrag(which, startX)
    local w = UI.history.colWidths
    UI.history.drag = {
        which = which,
        startX = startX,
        -- Snapshot current widths
        date = w.date,
        expansion = w.expansion,
        time = w.time,
        result = w.result,
        diff = w.diff,
        delete = w.delete
    }
end

local function History_EndColDrag()
    UI.history.drag = nil
    History_SaveColWidths()
end

local function History_UpdateColDrag()
    local h = UI.history
    if not h.drag or not h.st or not h.st.frame then return end

    local curX = GetCursorPosition()
    local scale = h.st.frame:GetEffectiveScale()
    curX = curX / scale
    local dx = curX - h.drag.startX

    local d = h.drag
    local w = h.colWidths

    -- Apply changes based on which grip
    -- Remember: Dungeon (index 2) is elastic.

    if d.which == 1 then
        -- Date | Dungeon
        w.date = Clamp(d.date + dx, HISTORY_MIN_COL, 500)
    elseif d.which == 2 then
        -- Dungeon | Expansion
        -- Moving right decreases Expansion (to make room for elastic Dungeon)
        w.expansion = Clamp(d.expansion - dx, HISTORY_MIN_COL, 500)
    elseif d.which == 3 then
        -- Expansion | Time
        -- Standard trade-off
        w.expansion = Clamp(d.expansion + dx, HISTORY_MIN_COL, 500)
        w.time = Clamp(d.time - dx, HISTORY_MIN_COL, 500)
    elseif d.which == 4 then
        -- Time | Result
        w.time = Clamp(d.time + dx, HISTORY_MIN_COL, 500)
        w.result = Clamp(d.result - dx, HISTORY_MIN_COL, 500)
    elseif d.which == 5 then
        -- Result | Diff
        w.result = Clamp(d.result + dx, HISTORY_MIN_COL, 500)
        w.diff = Clamp(d.diff - dx, HISTORY_MIN_COL, 500)
    elseif d.which == 6 then
        -- Diff | Delete
        w.diff = Clamp(d.diff + dx, HISTORY_MIN_COL, 500)
        w.delete = Clamp(d.delete - dx, 10, 100)
    end

    History_ApplyTableLayout()
end

local function History_MakeGrip(parent, which)
    local grip = CreateFrame("Frame", nil, parent)
    grip:SetFrameStrata("HIGH")
    grip:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    grip:EnableMouse(true)
    grip:SetSize(10, 14)
    ApplyThinSeparator(grip)

    grip:SetScript("OnEnter", function() SetCursor("UI_RESIZE_CURSOR") end)
    grip:SetScript("OnLeave", function() ResetCursor() end)

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local x = GetCursorPosition() / (UI.history.st.frame:GetEffectiveScale() or 1)
        History_BeginColDrag(which, x)
        self:SetScript("OnUpdate", History_UpdateColDrag)
    end)

    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        History_EndColDrag()
    end)

    return grip
end

local function History_EnsureColGrips()
    if UI.history.grips or not UI.history.st or not UI.history.st.frame then return end
    UI.history.grips = {}
    for i = 1, 6 do
        UI.history.grips[i] = History_MakeGrip(UI.history.st.frame, i)
    end
end

local function EnsureHistoryUI()
    if UI.history.frame then
        -- Already created, just show it if hidden?
        return
    end
    UI.history.filters = UI.history.filters or HistoryFilterDefaults()

    History_RestoreColWidths()

    local historyFrame = CreateFrame("Frame", "SpeedSplitsHistoryFrame", UIParent, "BackdropTemplate")
    UI.history.frame = historyFrame -- Set early for safety

    historyFrame:SetFrameStrata("DIALOG")
    historyFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    historyFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    historyFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    historyFrame:EnableMouse(true)
    historyFrame:SetMovable(true)
    historyFrame:SetResizable(true)
    historyFrame:RegisterForDrag("LeftButton")

    ApplyResizeBounds(historyFrame, 850, 200)

    historyFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    historyFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFrameGeom("history", self)
    end)

    if not RestoreFrameGeom("history", historyFrame, 850, 500) then
        historyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Controls Bar (Moved up to top)
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

    -- Search Bar
    local searchLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("LEFT", title, "RIGHT", 16, 0)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetSize(140, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        if UI.history.filters then UI.history.filters.search = self:GetText() or "" end
        if UI.RefreshHistoryTable then UI.RefreshHistoryTable() end
    end)
    UI.history.searchBox = searchBox

    -- Expansion DropDown
    local tierDropDown = CreateFrame("Frame", nil, controls, "UIDropDownMenuTemplate")
    tierDropDown:SetPoint("LEFT", searchBox, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(tierDropDown, 100)
    UIDropDownMenu_SetText(tierDropDown, "Expansion")
    InitHistoryDropDown(tierDropDown, BuildHistoryTierItems, function()
        return UI.history.filters and UI.history.filters.tier or 0
    end, function(v)
        if UI.history.filters then UI.history.filters.tier = tonumber(v) or 0 end
    end)
    UI.history.tierDropDown = tierDropDown

    -- Result DropDown
    local resultDropDown = CreateFrame("Frame", nil, controls, "UIDropDownMenuTemplate")
    resultDropDown:SetPoint("LEFT", tierDropDown, "RIGHT", -24, 0)
    UIDropDownMenu_SetWidth(resultDropDown, 90)
    UIDropDownMenu_SetText(resultDropDown, "Result")
    InitHistoryDropDown(resultDropDown, BuildHistoryResultItems, function()
        return UI.history.filters and UI.history.filters.result or "Any"
    end, function(v)
        if UI.history.filters then UI.history.filters.result = v end
    end)

    -- Sort Toggle
    local sortBtn = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    sortBtn:SetSize(120, 22)
    sortBtn:SetPoint("LEFT", resultDropDown, "RIGHT", -12, 2)

    local function UpdateSortBtn()
        if not UI.history.filters then return end
        local mode = UI.history.filters.sortMode
        sortBtn:SetText("Sort by: " .. (mode == "date" and "Date" or "Time"))
    end

    sortBtn:SetScript("OnClick", function()
        if not UI.history.filters then return end
        UI.history.filters.sortMode = (UI.history.filters.sortMode == "date") and "time" or "date"
        UpdateSortBtn()
        if UI.RefreshHistoryTable then UI.RefreshHistoryTable() end
    end)
    UI.history.sortBtn = sortBtn
    UpdateSortBtn()

    local listFrame = CreateFrame("Frame", nil, historyFrame)
    listFrame:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -24)
    listFrame:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -10, 10)
    UI.history.listFrame = listFrame

    local ST = ResolveScrollingTable()
    if not ST then
        local warn = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -6)
        warn:SetText("Missing LibScrollingTable (lib-st).")
    else
        pcall(function()
            local w = UI.history.colWidths
            local cols = {
                { name = "Date",               width = w.date,      align = "LEFT",   DoCellUpdate = History_DoCellUpdate, sort = HistoryColumnSort },
                { name = "Dungeon",            width = w.dungeon,   align = "LEFT",   DoCellUpdate = History_DoCellUpdate, sort = HistoryColumnSort },
                { name = "Expansion",          width = w.expansion, align = "LEFT",   DoCellUpdate = History_DoCellUpdate, sort = HistoryColumnSort },
                { name = "Result",             width = w.result,    align = "CENTER", DoCellUpdate = History_DoCellUpdate, sort = HistoryColumnSort },
                { name = "Time",               width = w.time,      align = "CENTER", DoCellUpdate = History_DoCellUpdate, sort = HistoryColumnSort },
                { name = "Difference from PB", width = w.diff,      align = "RIGHT",  DoCellUpdate = History_DoCellUpdate, sort = HistoryColumnSort },
                { name = "",                   width = w.delete,    align = "CENTER", DoCellUpdate = Delete_DoCellUpdate }
            }

            local hScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
            local rowHeight = math.max(12, math.floor((18 + HISTORY_ROW_PAD) * HISTORY_ENTRY_SCALE * hScale + 0.5))
            UI.history.rowHeight = rowHeight

            local st = ST:CreateST(cols, 12, rowHeight, nil, listFrame)

            if st and st.frame then
                st.frame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
                st.frame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", 0, 0)
                if st.head and st.head.cols then
                    local hScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
                    for i = 1, #cols do
                        if st.head.cols[i] then StyleHeaderCell(st.head.cols[i], cols[i].align, hScale) end
                    end
                end
                UI.history.st = st

                -- Initialize grips and layout
                History_EnsureColGrips()
                History_ApplyTableLayout()
            end
        end)
    end

    local grip = SetupSizeGrip(historyFrame, function()
        SaveFrameGeom("history", historyFrame)
    end)
    UI.history.resizeGrip = grip

    function NS.UpdateHistoryLayout()
        if UI and UI.history and UI.history.st and UI.history.listFrame then
            local hScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
            local h = UI.history.listFrame:GetHeight()
            local rowHeight = math.max(12, math.floor((18 + HISTORY_ROW_PAD) * HISTORY_ENTRY_SCALE * hScale + 0.5))
            UI.history.rowHeight = rowHeight
            local displayRows = math.floor((h - 4) / rowHeight)
            if displayRows < 1 then displayRows = 1 end
            UI.history.st:SetDisplayRows(displayRows, rowHeight)
            UI.history.st:Refresh()
        end
    end

    UI.history.UpdateLayout = NS.UpdateHistoryLayout -- Expose for ToggleHistoryFrame

    historyFrame:SetScript("OnSizeChanged", function(self)
        NS.UpdateHistoryLayout()
        History_ApplyTableLayout()
    end)

    NS.UpdateHistoryLayout() -- Initial layout calculation
    UI.history.frame = historyFrame

    -- Delay ensure grips until frame is somewhat ready or just do it now if ST exists
    if UI.history.st then
        History_EnsureColGrips()
        History_ApplyTableLayout()
    end

    historyFrame:Hide()
    if UI.RefreshHistoryTable then UI.RefreshHistoryTable() end
end

local function ToggleHistoryFrame()
    local ok, err = pcall(function()
        EnsureDB()
        EnsureHistoryUI()

        local h = UI.history
        if not h or not h.frame then return end

        if h.frame:IsShown() then
            h.frame:Hide()
        else
            h.frame:Show()
            if h.UpdateLayout then h.UpdateLayout() end
            if NS.UpdateHistoryLayout then NS.UpdateHistoryLayout() end
            if UI.RefreshHistoryTable then UI.RefreshHistoryTable() end
        end
    end)
    if not ok then
        SS_Print("Error opening history: " .. tostring(err))
    end
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
    ApplyResizeBounds(timerFrame, 120, 40, 900, 300)
    SetHoverBackdrop(timerFrame, 0.60)
    timerFrame:SetBackdropColor(0, 0, 0, 0)
    timerFrame:SetBackdropBorderColor(1, 1, 1, 0)

    local timerRestored = RestoreFrameGeom("timer", timerFrame, 140, 50)
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

    local fadeTarget = 0
    local fadeCurrent = 0
    local fadeSpeed = 5 -- Alpha per second

    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then fadeTarget = 1 else fadeTarget = 0 end
        if math.abs(fadeCurrent - fadeTarget) > 0.01 then
            local dir = (fadeTarget > fadeCurrent) and 1 or -1
            fadeCurrent = Clamp(fadeCurrent + (dir * fadeSpeed * elapsed), 0, 1)
            self:SetBackdropColor(0, 0, 0, 0.60 * fadeCurrent)
            self:SetBackdropBorderColor(1, 1, 1, 0.10 * fadeCurrent)
            if UI._timerResizeGrip then UI._timerResizeGrip:SetAlpha(fadeCurrent) end
        end
    end)

    local timerTextSec = timerFrame:CreateFontString(nil, "OVERLAY")
    timerTextSec:SetJustifyH("RIGHT")
    NS.ApplyFontToFS(timerTextSec, "timer")
    timerTextSec:SetText("00")

    local timerTextMin = timerFrame:CreateFontString(nil, "OVERLAY")
    timerTextMin:SetPoint("RIGHT", timerTextSec, "LEFT", 0, 0)
    timerTextMin:SetJustifyH("RIGHT")
    NS.ApplyFontToFS(timerTextMin, "timer")
    timerTextMin:SetText("00:")

    local timerTextMs = timerFrame:CreateFontString(nil, "OVERLAY")
    timerTextMs:SetPoint("LEFT", timerTextSec, "RIGHT", 0, 0)
    timerTextMs:SetJustifyH("LEFT")
    NS.ApplyFontToFS(timerTextMs, "timer")
    timerTextMs:SetText(".000")

    local timerDeltaText = timerFrame:CreateFontString(nil, "OVERLAY")
    timerDeltaText:SetPoint("TOP", timerFrame, "CENTER", 0, -18)
    NS.ApplyFontToFS(timerDeltaText, "num")
    timerDeltaText:SetText("")

    -- Initial pivot anchor (will be refined in RefreshAllUI)
    timerTextSec:SetPoint("RIGHT", timerFrame, "CENTER", 0, 0)

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
    ApplyResizeBounds(bossFrame, 450, 200, 1400, 1000)

    -- Main backdrop for the entire boss frame
    bossFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    bossFrame:SetBackdropColor(0, 0, 0, 0.9)
    bossFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)

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

    local cols = { {
        name = "",
        width = UI._modelWidth,
        align = "CENTER",
        DoCellUpdate = Model_DoCellUpdate
    }, {
        name = "",
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
    } }

    -- 6 rows visible at a time to ensure scrolling works on small raids/resized frames.
    -- We pass a width and height so the scrollframe correctly clips rows.
    local st = ST and ST:CreateST(cols, 6, 24, nil, bossFrame)
    if st then
        st.frame:SetClipsChildren(true)
    end
    UI.st = st
    if st and st.frame then
        SetHoverBackdrop(st.frame, 0.85)
        if st.head then
            st.head:SetFrameStrata("HIGH") -- Absolute top-most strata for headers
            st.head:SetFrameLevel(100)     -- Extremely high frame level
            if st.head.cols then
                for i = 1, #cols do
                    StyleHeaderCell(st.head.cols[i], cols[i].align)
                end
            end
        end
    end

    -- Title bar 'tab' (Header portion)
    local bgFrame = CreateFrame("Frame", nil, bossFrame, "BackdropTemplate")
    bgFrame:SetHeight(TOP_BAR_H)
    bgFrame:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, 0)
    bgFrame:SetPoint("TOPRIGHT", bossFrame, "TOPRIGHT", 0, 0)
    bgFrame:SetFrameLevel(math.max(5, bossFrame:GetFrameLevel() + 2))
    bgFrame:SetClipsChildren(true)
    bgFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bgFrame:SetBackdropColor(0, 0, 0, 0.4) -- Translucent Frame (1)
    UI.titleTab = bgFrame

    local titleBg = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -8) -- Texture Background (2)
    titleBg:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", -200, 20)
    titleBg:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", 200, -20)
    UI.titleBg = titleBg

    -- Re-parent and align the table headers to the background frame
    if UI.st and UI.st.head then
        UI.st.head:SetParent(bgFrame)
        UI.st.head:SetAllPoints(bgFrame)
        UI.st.head:SetFrameLevel(bgFrame:GetFrameLevel() + 2) -- Ensure it is above the background
        if UI.st.head.cols then
            for i = 1, #cols do
                StyleHeaderCell(UI.st.head.cols[i], cols[i].align)
            end
        end
    end

    local killCountText = bgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    killCountText:SetDrawLayer("OVERLAY", 7) -- Headings (3)
    killCountText:SetPoint("LEFT", 10, 0)
    NS.ApplyFontToFS(killCountText, "header", 1.25)
    UI.killCountText = killCountText

    -- Totals 'tab' (Footer portion)
    local totalFrame = CreateFrame("Frame", nil, bossFrame, "BackdropTemplate")
    totalFrame:SetHeight(24)
    totalFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    totalFrame:SetBackdropColor(0, 0, 0, 0.95)
    UI.totalFrame = totalFrame

    local logoText = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logoText:SetPoint("LEFT", 10, 0)
    logoText:SetText("SpeedSplits")
    UI.logoText = logoText

    -- History button on Footer Tab
    local historyButton = CreateFrame("Button", nil, totalFrame)
    historyButton:SetSize(16, 16)
    historyButton:SetPoint("LEFT", logoText, "RIGHT", 6, 0)
    historyButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    historyButton:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    historyButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    UI.historyButton = historyButton

    historyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Runs History", 1, 1, 1)
        GameTooltip:Show()
    end)
    historyButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    historyButton:SetScript("OnClick", function()
        ToggleHistoryFrame()
    end)

    local totalPB = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalPB:SetJustifyH("RIGHT")
    totalPB:SetText("--:--.---")
    UI.totalPB = totalPB

    local totalSplit = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalSplit:SetJustifyH("RIGHT")
    totalSplit:SetText("--:--.---")
    UI.totalSplit = totalSplit

    local totalDelta = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalDelta:SetJustifyH("RIGHT")
    totalDelta:SetText("--:--.---")
    UI.totalDelta = totalDelta

    -- Resize grips
    local timerGrip = SetupSizeGrip(timerFrame, function()
        SaveFrameGeom("timer", timerFrame)
    end)
    timerGrip:SetAlpha(0)

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
    UI.timerTextMin = timerTextMin
    UI.timerTextSec = timerTextSec
    UI.timerTextMs = timerTextMs
    UI.killCountText = killCountText
    UI.st = st
    UI.cols = cols
    UI.data = {}
    UI.rowByBossKey = {}
    UI.totalFrame = totalFrame
    UI.totalPB = totalPB
    UI.totalSplit = totalSplit
    UI.totalDelta = totalDelta
    UI.timerDeltaText = timerDeltaText
    UI.historyButton = historyButton
    UI.resizeGrip = bossGrip
    UI._timerResizeGrip = timerGrip

    -- Wrap the whole boss frame in a high-level border frame (zero padding requested)
    local borderFrame = CreateFrame("Frame", nil, bossFrame, "BackdropTemplate")
    borderFrame:SetAllPoints(bossFrame)
    borderFrame:SetFrameLevel(bossFrame:GetFrameLevel() + 30)
    borderFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    borderFrame:EnableMouse(false)
    UI.borderFrame = borderFrame

    EnsureColGrips()
    ApplyTableLayout()
    NS.RefreshAllUI()

    timerFrame:Hide()
    bossFrame:Hide()
end

local function UpdateTimerFrameBounds()
    if not UI.timerFrame or not UI.timerTextSec then return end

    -- Use neutral text to calibrate visual center & constraints
    local oldMin = UI.timerTextMin:GetText()
    local oldSec = UI.timerTextSec:GetText()
    local oldMs  = UI.timerTextMs:GetText()

    UI.timerTextMin:SetText("00:")
    UI.timerTextSec:SetText("00")
    UI.timerTextMs:SetText(".000")

    local wL = UI.timerTextMin:GetStringWidth() + UI.timerTextSec:GetStringWidth()
    local wR = UI.timerTextMs:GetStringWidth()

    -- Centering logic: Calculate pivot offset to balance asymmetrical text MM:SS.mmm
    -- We do this dynamically in SetTimerText to ensure it's always centered regardless of content
    UI._timerPivotOffset = (wL - wR) / 2
    UI.timerTextSec:ClearAllPoints()
    UI.timerTextSec:SetPoint("RIGHT", UI.timerFrame, "CENTER", 0, 0)
    UI.timerTextSec:SetWidth(0)

    local totalW = wL + wR
    local h      = UI.timerTextSec:GetStringHeight()
    local padW   = 40 -- Increased padding to ensure look
    local padH   = 24
    local minW   = math.ceil(totalW + padW * 2)
    local minH   = math.ceil(h + padH * 2)

    ApplyResizeBounds(UI.timerFrame, minW, minH, 900, 300)

    -- Restore text
    UI.timerTextMin:SetText(oldMin)
    UI.timerTextSec:SetText(oldSec)
    UI.timerTextMs:SetText(oldMs)
end

local function SetTimerText(seconds, finished)
    if not UI.timerTextMin or not UI.timerTextSec or not UI.timerTextMs then return end
    local full = FormatTime(seconds)

    local min, sec, ms = "", "", ""
    if full:find(":") then
        -- Has minutes or hours
        min, sec, ms = full:match("^(.*:)(%d%d)(%.%d+)$")
    else
        -- Only seconds
        sec, ms = full:match("^(%d+)(%.%d+)$")
        min = ""
    end

    if not sec then min, sec, ms = full, "", "" end

    UI.timerTextMin:SetText(min)
    UI.timerTextSec:SetText(sec)
    UI.timerTextMs:SetText(ms)

    local c = finished and NS.Colors.deepGreen or NS.Colors.white
    UI.timerTextMin:SetTextColor(c.r, c.g, c.b, c.a or 1)
    UI.timerTextSec:SetTextColor(c.r, c.g, c.b, c.a or 1)
    UI.timerTextMs:SetTextColor(c.r, c.g, c.b, c.a or 1)

    -- Force dynamic centering for even padding
    local wL = (UI.timerTextMin:GetStringWidth() or 0) + (UI.timerTextSec:GetStringWidth() or 0)
    local wR = (UI.timerTextMs:GetStringWidth() or 0)
    local offset = (wL - wR) / 2
    UI.timerTextSec:ClearAllPoints()
    UI.timerTextSec:SetPoint("RIGHT", UI.timerFrame, "CENTER", offset, 0)
end

local function SetTimerDelta(delta)
    if not UI.timerDeltaText then return end
    if delta == nil then
        UI.timerDeltaText:SetText("")
        return
    end
    local _, _, _, hex = GetPaceColor(delta, false)
    UI.timerDeltaText:SetText(hex .. FormatDelta(delta) .. "|r")
    UI.timerDeltaText:SetTextColor(1, 1, 1, 1)
end


local function SetKillCount(killed, total)
    local displayName = (NS.Run and NS.Run.instanceName ~= "") and NS.Run.instanceName or "Boss"
    local text = string.format("%s (%d/%d)", displayName, killed or 0, total or 0)

    -- Ensure persistence by updating the column definition
    if UI.cols and UI.cols[1] then
        -- We no longer clear the name, but col 1 and 2 are usually empty anyway.
    end

    if UI.killCountText then
        UI.killCountText:SetText(text)
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

        if fs then
            -- We keep the first column header text empty because the Instance Name is in the titleTab
            fs:SetText("")
        end
    end
end


local function SetTotals(pbTotal, splitTotal, deltaTotal, r, g, b, hex)
    if not UI.totalPB or not UI.totalSplit or not UI.totalDelta then
        return
    end

    UI.totalPB:SetText(FormatTime(pbTotal))
    UI.totalPB:SetTextColor(NS.Colors.gold.r, NS.Colors.gold.g, NS.Colors.gold.b, 1)

    if splitTotal then
        UI.totalSplit:SetText(FormatTime(splitTotal))
        if r and g and b then
            UI.totalSplit:SetTextColor(r, g, b, 1)
        else
            UI.totalSplit:SetTextColor(1, 1, 1, 1)
        end
    else
        UI.totalSplit:SetText("--:--.---")
        UI.totalSplit:SetTextColor(1, 1, 1, 1)
    end

    if deltaTotal == nil then
        UI.totalDelta:SetText("")
    else
        UI.totalDelta:SetText(FormatDelta(deltaTotal))
        if r and g and b then
            UI.totalDelta:SetTextColor(r, g, b, 1)
        else
            UI.totalDelta:SetTextColor(1, 1, 1, 1)
        end
    end
end
NS.SetTotals = SetTotals


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
        local pbSegment = pbSegments[entry.name] or 0
        cumulativePB = cumulativePB + pbSegment
        data[#data + 1] = {
            key = entry.key,
            cols = {
                { value = entry.name or "Unknown" },
                {
                    value = (pbSegment > 0 and cumulativePB > 0) and FormatTime(cumulativePB) or "--:--.---",
                    color = NS.Colors.gold
                },
                { value = "" },
                { value = "" }
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

local function SetRowKilled(bossKey, splitCumulative, cumulativePB, deltaSeconds, r, g, b, hex, isGold,
                            pbSegmentForThisRow)
    local realrow = UI.rowByBossKey and UI.rowByBossKey[bossKey]
    local row = realrow and UI.data and UI.data[realrow]
    if not row then return end

    row.cols[2].value = (pbSegmentForThisRow and pbSegmentForThisRow > 0) and FormatTime(cumulativePB) or "--:--.---"
    row.cols[2].color = NS.Colors.gold
    row.cols[3].value = FormatTime(splitCumulative)
    row.cols[3].color = isGold and NS.Colors.gold or { r = r, g = g, b = b, a = 1 }

    if deltaSeconds == nil then
        row.cols[4].value = ""
        row.cols[4].color = nil
    else
        row.cols[4].value = FormatDelta(deltaSeconds)
        row.cols[4].color = { r = r, g = g, b = b, a = 1 }
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
-- Run state (Logic)
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


local function ComputeSumOfBest(pbTable, entries)
    if not pbTable or not entries or #entries == 0 then
        return nil
    end
    local sum = 0
    for _, entry in ipairs(entries) do
        local segment = pbTable[entry.name]
        if segment == nil then
            return nil
        end
        sum = sum + segment
    end
    return sum
end

local function RefreshTotals(isFinal)
    local node = GetBestSplitsSubtable()
    local pbTable = node and node.Segments or nil
    local pbTotal = pbTable and ComputeSumOfBest(pbTable, Run.entries) or nil

    if isFinal then
        local duration = (Run.endGameTime > 0 and Run.startGameTime > 0) and (Run.endGameTime - Run.startGameTime) or nil
        local deltaTotal = (duration and pbTotal) and (duration - pbTotal) or nil

        local existingPB = node and node.FullRun
        local isPB = false
        if duration and duration > 0 then
            isPB = (not existingPB or not existingPB.duration or duration <= (existingPB.duration + 0.001))
        end

        local r, g, b, hex = GetPaceColor(deltaTotal, isPB)
        SetTotals(pbTotal, duration, deltaTotal, r, g, b, hex)
        SetTimerDelta(deltaTotal)
        return
    end

    -- During run: show running total based on LAST KILLED BOSS in the sequence
    local lastBossKey = nil
    for _, entry in ipairs(Run.entries) do
        if Run.kills[entry.key] then
            lastBossKey = entry.key
        end
    end

    if lastBossKey then
        -- Synchronize with table: pull the state directly from the last calculated split
        SetTotals(Run.lastPBTotal, Run.lastSplitCumulative, Run.lastDelta, Run.lastColorR, Run.lastColorG, Run
            .lastColorB,
            Run.lastColorHex)
        SetTimerDelta(Run.lastDelta)
    else
        SetTotals(pbTotal, nil, nil)
        SetTimerDelta(nil)
    end
end
NS.Run = Run
NS.UI = UI

function NS.RefreshAllUI()
    if not UI.bossFrame then return end
    NS.UpdateColorsFromSettings()
    if UI.logoText then
        UI.logoText:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 1)
    end
    if UI.bossFrame then
        UI.bossFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    end
    if UI.borderFrame then
        UI.borderFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    end
    if UI.titleBg then
        local atlas = NS.DB.Settings.titleTexture or NS.TitleTextures[1]
        UI.titleBg:SetAtlas(atlas)
    end
    if UI.titleTab then
        UI.titleTab:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.5)
    end
    if UI.totalFrame then
        UI.totalFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.5)
    end
    if UI.killCountText then
        NS.ApplyFontToFS(UI.killCountText, "counter")
    end
    if UI.totalPB then NS.ApplyFontToFS(UI.totalPB, "num") end
    if UI.totalSplit then NS.ApplyFontToFS(UI.totalSplit, "num") end
    if UI.totalDelta then NS.ApplyFontToFS(UI.totalDelta, "num") end
    if UI.timerTextMin then NS.ApplyFontToFS(UI.timerTextMin, "timer") end
    if UI.timerTextSec then NS.ApplyFontToFS(UI.timerTextSec, "timer") end
    if UI.timerTextMs then NS.ApplyFontToFS(UI.timerTextMs, "timer") end
    if UI.timerDeltaText then
        local f = (NS.DB and NS.DB.Settings and NS.DB.Settings.fonts and NS.DB.Settings.fonts.timer)
        local fontPath = f and f.font or "Fonts\\FRIZQT__.TTF"
        local fontSize = math.max(8, math.floor((f and f.size or 24) * 0.55))
        local fontFlags = f and f.flags or "OUTLINE"
        UI.timerDeltaText:SetFont(fontPath, fontSize, fontFlags)
    end

    -- Explicitly verify font strings exist before applying
    if UI.totalPB then NS.ApplyFontToFS(UI.totalPB, "num") end
    if UI.totalSplit then NS.ApplyFontToFS(UI.totalSplit, "num") end
    if UI.totalDelta then NS.ApplyFontToFS(UI.totalDelta, "num") end
    if UI.timerTextMin then NS.ApplyFontToFS(UI.timerTextMin, "timer") end
    if UI.timerTextSec then NS.ApplyFontToFS(UI.timerTextSec, "timer") end
    if UI.timerTextMs then NS.ApplyFontToFS(UI.timerTextMs, "timer") end
    if UI.killCountText then NS.ApplyFontToFS(UI.killCountText, "counter") end

    -- Sync Header fonts and styles
    if UI.st and UI.st.head and UI.st.head.cols then
        for i = 1, #UI.st.head.cols do
            StyleHeaderCell(UI.st.head.cols[i], UI.cols[i].align, 1.0, UI.cols[i].name)
        end
    end

    -- Sync History Headers
    if UI.history and UI.history.st and UI.history.st.head and UI.history.st.head.cols then
        local hScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
        for i = 1, #UI.history.st.head.cols do
            local hCols = UI.history.st.cols
            if hCols and hCols[i] then
                StyleHeaderCell(UI.history.st.head.cols[i], hCols[i].align, hScale)
            end
        end
    end

    UpdateTimerFrameBounds()

    if NS.Run.entries and #NS.Run.entries > 0 then
        local node = GetBestSplitsSubtable()
        local pbTable = node and node.Segments or {}
        RenderBossTable(NS.Run.entries, pbTable)

        local runningPBTotal = 0
        for _, entry in ipairs(NS.Run.entries) do
            runningPBTotal = runningPBTotal + (pbTable[entry.name] or 0)
            local splitCumulative = NS.Run.kills[entry.key]
            if splitCumulative then
                local prevCumulative = GetPreviousKilledCumulativeInTableOrder(NS.Run, entry.key)
                local segTime = prevCumulative and (splitCumulative - prevCumulative) or splitCumulative
                local oldSegPB = pbTable[entry.name]
                local isGold = (not oldSegPB) or (segTime <= oldSegPB + 0.001)

                local delta = splitCumulative - runningPBTotal
                local r, g, b, hex = NS.GetPaceColor(delta, false)
                SetRowKilled(entry.key, splitCumulative, runningPBTotal, delta, r, g, b, hex, isGold)
            end
        end
        RefreshTotals(not NS.Run.active and NS.Run.endGameTime > 0)
    end
    if not NS.Run.active and NS.Run.endGameTime > 0 then
        SetTimerText(NS.Run.endGameTime - NS.Run.startGameTime, true)
    end
    if UI.st and UI.st.Refresh then UI.st:Refresh() end
    if NS.UpdateHistoryLayout then NS.UpdateHistoryLayout() end
end

local function UpdateBestRunIfNeeded(durationSeconds)
    local node = GetBestSplitsSubtable()
    if not node then return end

    local existing = node.FullRun
    if not existing or not existing.duration or durationSeconds < existing.duration then
        node.FullRun = {
            duration = durationSeconds,
            endedAt = Run.endedAt,
            instanceName = Run.instanceName,
            tier = Run.tier,
            difficultyID = Run.difficultyID,
            difficultyName = Run.difficultyName,
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

    table.insert(DB.RunHistory, 1, record)
    while #DB.RunHistory > RUNS_MAX do table.remove(DB.RunHistory) end

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

    local bossEntry = nil
    for _, entry in ipairs(Run.entries or {}) do
        if entry.key == bossKey then
            bossEntry = entry
            break
        end
    end
    if not bossEntry then return end
    local bossName = bossEntry.name

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

    local node = GetBestSplitsSubtable()
    local pbTable = node and node.Segments
    if not pbTable then return end

    -- Baseline for this segment
    local baseline = 0
    if prevCumulative then
        baseline = prevCumulative
    else
        -- If previous split was skipped, evaluate this segment relative to the sum of previous PBs
        for _, entry in ipairs(Run.entries) do
            if entry.key == bossKey then break end
            baseline = baseline + (pbTable[entry.name] or 0)
        end
    end

    local splitSegment = splitCumulative - baseline
    if splitSegment < 0 then splitSegment = 0 end

    local oldSegmentPB = pbTable[bossName]
    local isNewSegmentPB = (oldSegmentPB == nil or oldSegmentPB == 0) or (splitSegment <= oldSegmentPB + 0.001)

    -- Prepare cumulative comparison vs old PB sum
    local cumulativePB_Comparison = 0
    for _, entry in ipairs(Run.entries) do
        local seg = pbTable[entry.name] or 0
        cumulativePB_Comparison = cumulativePB_Comparison + seg
        if entry.key == bossKey then
            break
        end
    end

    -- Update the table with the new best segment
    if isNewSegmentPB then
        pbTable[bossName] = splitSegment
    end

    -- Prepare cumulative display (sum of current best segments)
    local cumulativePB_Display = 0
    for _, entry in ipairs(Run.entries) do
        local seg = pbTable[entry.name] or 0
        cumulativePB_Display = cumulativePB_Display + seg
        if entry.key == bossKey then
            break
        end
    end

    local pbTotalTableSum = ComputeSumOfBest(pbTable, Run.entries) or 0
    local deltaOverall = splitCumulative - cumulativePB_Comparison
    local r, g, b, hex = GetPaceColor(deltaOverall, false)

    -- Store for footer/timer synchronization
    Run.lastDelta = deltaOverall
    Run.lastPBTotal = pbTotalTableSum
    Run.lastSplitCumulative = splitCumulative
    Run.lastColorR, Run.lastColorG, Run.lastColorB, Run.lastColorHex = r, g, b, hex

    SetRowKilled(bossKey, splitCumulative, cumulativePB_Display, deltaOverall, r, g, b, hex, isNewSegmentPB,
        pbTable[bossName])

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

    local node = GetBestSplitsSubtable()
    local pbSplits = node and node.Segments or {}
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

    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    local tier, journalID = GetJournalTierAndInstanceIDForCurrentInstance()

    Run.instanceName = name or ""
    Run.instanceType = instanceType or ""
    Run.difficultyID = tonumber(difficultyID) or 0
    Run.difficultyName = difficultyName or ""
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
        NS.UpdateColorsFromSettings()
        ResetRun()
        if NS.CreateOptionsPanel then
            NS.CreateOptionsPanel()
        end
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
    local cmd, arg = strsplit(" ", msg or "", 2)
    cmd = (cmd or ""):lower()

    if cmd == "history" then
        ToggleHistoryFrame()
    elseif cmd == "options" or cmd == "config" then
        if NS.OpenOptions then NS.OpenOptions() end
    elseif cmd == "debugobj" then
        SpeedSplits_DebugObjectives = not SpeedSplits_DebugObjectives
        SS_Print("Objective debug: " .. (SpeedSplits_DebugObjectives and "ON" or "OFF"))
    elseif cmd == "" or cmd == "toggle" then
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
    elseif cmd == "show" or cmd == "on" then
        SetPreviewEnabled(true)
        EnsureUI()
        ResetRun()
        ShowAddonFrames()
        SS_Print("Frames shown (preview mode).")
    elseif cmd == "hide" or cmd == "off" then
        SetPreviewEnabled(false)
        if not Run.inInstance then
            HideAddonFrames()
        end
        SS_Print("Frames hidden.")
    else
        SS_Print("Commands: /ss (toggle frames), /ss show, /ss hide, /ss history, /ss options")
    end
end

App:RegisterEvent("ADDON_LOADED")
App:RegisterEvent("PLAYER_ENTERING_WORLD")
App:RegisterEvent("PLAYER_LEAVING_WORLD")
