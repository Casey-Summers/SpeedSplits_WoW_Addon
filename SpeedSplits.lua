-- SpeedSplits.lua
-- Retail WoW addon: instance splits with objective-first boss discovery + EJ fallback.
local ADDON_NAME, NS                                 = ...
local App                                            = CreateFrame("Frame")
NS.App                                               = App

-- Constants
local COL_MAX_PB_SPLIT, COL_MAX_DELTA                = 260, 200
local COL_MIN_BOSS, COL_MIN_NUM, COL_MIN_DELTA_TITLE = 20, 85, 85
local GRIP_HALFWIDTH, HEADER_H                       = 5, 18
local RIGHT_INSET_DEFAULT, TOP_BAR_H, TOP_BAR_GAP    = 26, 28, 4
local BOSS_LOAD_MAX_TRIES, BOSS_LOAD_RETRY_DELAY     = 40, 0.25
local EJ_INSTANCE_INDEX_MAX, EJ_ENCOUNTER_INDEX_MAX  = 600, 80
local RUNS_MAX, CRITERIA_MAX                         = 200, 80
local HISTORY_ICON_SCALE                             = 0.75
local BOSS_MODEL_ZOOM                                = 0.75
local PB_SHINE_WIDTH, PB_SHINE_HEIGHT                = 150, 50

NS.TitleTextures                                     = {
    "dragonflight-landingpage-renownbutton-centaur-hover",
    "dragonflight-landingpage-renownbutton-expedition-hover",
    "dragonflight-landingpage-renownbutton-locked",
    "dragonflight-landingpage-renownbutton-tuskarr-hover",
    "dragonflight-landingpage-renownbutton-dream-hover",
    "UI-Tuskarr-Reward-Slate",
    "ui-web-reward-slate",
    "UI-Valdrakken-Reward-Slate",
}

NS.TimerToastTextures                                = {
    "UI-Centaur-Highlight-Bottom",
    "UI-Dream-Highlight-Bottom",
    "UI-Valdrakken-Highlight-Bottom",
    "UI-Expedition-Highlight-Bottom",
}

NS.SoundOptions                                      = {
    { name = "None",            id = 0 },
    { name = "Achievement",     id = 569143 },
    { name = "Quest Complete",  id = 567439 },
    { name = "Level up",        id = 569593 },
    { name = "Reputation Gain", id = 568016 },
    { name = "Trading Post",    id = 4919212 },
}

-- History Column Widths
local HISTORY_COL_DEFAULTS                           = {
    date = 130, dungeon = 220, expansion = 140, time = 80, result = 130, diff = 120, delete = 30
}

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
    local function f(v) return math.floor(Clamp(v, 0, 1) * 255 + 0.5) end
    return string.format("|c%02x%02x%02x%02x", f(a), f(r), f(g), f(b))
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
    gold      = HexToColor("ffffd100"),
    white     = HexToColor("ffffffff"),
    turquoise = HexToColor("ff00bec3"),
    deepGreen = HexToColor("ff10ff00"),
    redFade   = HexToColor("ffcc2232"),
    darkRed   = HexToColor("ffcc0005"),
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

local function GetPaceToastTexture(delta, isPB)
    if isPB then return NS.TimerToastTextures[1] end
    if delta == nil or delta < 0 then return NS.TimerToastTextures[2] end
    local t1, t2 = (NS.DB.Settings.paceThreshold1 or 4), (NS.DB.Settings.paceThreshold2 or 12)
    if delta <= t1 then
        return NS.TimerToastTextures[2] -- On Pace (Green)
    elseif delta <= t2 then
        return NS.TimerToastTextures[3] -- Behind (Purple)
    else
        return NS.TimerToastTextures[4]
    end -- Slow (Red)
end
NS.GetPaceToastTexture = GetPaceToastTexture

local function GetPaceColor(delta, isPB)
    if delta == nil then return 1, 1, 1, "|cffffffff" end
    -- Gold if new PB or a tie (+0.000)
    if isPB or math.abs(delta) < 0.001 then
        return Colors.gold.r, Colors.gold.g, Colors.gold.b, Colors.gold.hex
    end
    if delta < 0 then
        return Colors.deepGreen.r, Colors.deepGreen.g, Colors.deepGreen.b, Colors.deepGreen.hex
    end

    local t1 = NS.DB.Settings.paceThreshold1 or 4
    local t2 = NS.DB.Settings.paceThreshold2 or 12

    if delta <= t1 then
        return InterpolateColor(Colors.deepGreen, Colors.lightGreen, delta / t1)
    elseif delta <= t2 then
        return InterpolateColor(Colors.lightGreen, Colors.darkRed, (delta - t1) / (t2 - t1))
    end
    return Colors.darkRed.r, Colors.darkRed.g, Colors.darkRed.b, Colors.darkRed.hex
end
NS.GetPaceColor = GetPaceColor

-- =========================================================
-- SavedVariables & State
-- =========================================================
local DB
local UI

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
NS.Run = Run

local function EnsureDB()
    if SpeedSplitsDB == nil then
        SpeedSplitsDB = {}
    end

    -- Human-readable structure
    SpeedSplitsDB.RunHistory                 = SpeedSplitsDB.RunHistory or SpeedSplitsDB.runs or {}
    SpeedSplitsDB.InstancePersonalBests      = SpeedSplitsDB.InstancePersonalBests or SpeedSplitsDB.PersonalBests or
        SpeedSplitsDB.bestSplits or {}
    SpeedSplitsDB.Settings                   = SpeedSplitsDB.Settings or SpeedSplitsDB.settings or {}

    -- Clean up old keys
    SpeedSplitsDB.runs                       = nil
    SpeedSplitsDB.bestSplits                 = nil
    SpeedSplitsDB.PersonalBests              = nil
    SpeedSplitsDB.settings                   = nil
    SpeedSplitsDB.pbBoss                     = nil
    SpeedSplitsDB.pbRun                      = nil

    -- Defaults
    SpeedSplitsDB.Settings.colors            = SpeedSplitsDB.Settings.colors or {
        gold       = "ffffd100",
        white      = "ffffffff",
        turquoise  = "ff00bec3",
        deepGreen  = "ff10ff00",
        lightGreen = "ffcc2232",
        darkRed    = "ffcc0005",
    }
    SpeedSplitsDB.Settings.fonts             = SpeedSplitsDB.Settings.fonts or {}
    SpeedSplitsDB.Settings.fonts.boss        = SpeedSplitsDB.Settings.fonts.boss or
        { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.num         = SpeedSplitsDB.Settings.fonts.num or
        { size = 17, font = "Fonts\\ARIALN.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.timer       = SpeedSplitsDB.Settings.fonts.timer or
        { size = 30, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.header      = SpeedSplitsDB.Settings.fonts.header or
        { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.fonts.counter     = SpeedSplitsDB.Settings.fonts.counter or
        { size = 16, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" }
    SpeedSplitsDB.Settings.historyScale      = SpeedSplitsDB.Settings.historyScale or 1.0
    SpeedSplitsDB.Settings.titleTexture      = SpeedSplitsDB.Settings.titleTexture or NS.TitleTextures[1]
    SpeedSplitsDB.Settings.timerToastTexture = SpeedSplitsDB.Settings.timerToastTexture or NS.TimerToastTextures[1]
    SpeedSplitsDB.Settings.timerToastScale   = SpeedSplitsDB.Settings.timerToastScale or 1.2
    SpeedSplitsDB.Settings.paceThreshold1    = SpeedSplitsDB.Settings.paceThreshold1 or 4
    SpeedSplitsDB.Settings.paceThreshold2    = SpeedSplitsDB.Settings.paceThreshold2 or 12
    SpeedSplitsDB.Settings.showTimerToast    = SpeedSplitsDB.Settings.showTimerToast == nil and true or
        SpeedSplitsDB.Settings.showTimerToast
    SpeedSplitsDB.Settings.toastAllBosses    = SpeedSplitsDB.Settings.toastAllBosses or false
    SpeedSplitsDB.Settings.toastSoundID      = SpeedSplitsDB.Settings.toastSoundID or 569143
    SpeedSplitsDB.Settings.toastSoundName    = SpeedSplitsDB.Settings.toastSoundName or "Achievement"
    SpeedSplitsDB.Settings.toastVolume       = SpeedSplitsDB.Settings.toastVolume or 0.8

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
            titleTexture = NS.TitleTextures[1],
            timerToastTexture = NS.TimerToastTextures[1],
            timerToastScale = 1.2,
            showTimerToast = true,
            paceThreshold1 = 4,
            paceThreshold2 = 12
        }
    end

    DB    = SpeedSplitsDB
    NS.DB = DB

    -- Ensure History filters are ready
    if UI and UI.history then
        UI.history.filters = UI.history.filters or HistoryFilterDefaults()
    end
end

StaticPopupDialogs["SPEEDSPLITS_WIPE_CONFIRM"] = {
    text = "Are you sure you want to wipe ALL Personal Bests and Run History? This cannot be undone.",
    button1 = "Wipe Records",
    button2 = "Cancel",
    OnAccept = function()
        NS.WipeDatabase()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SPEEDSPLITS_RESET_LAYOUT"] = {
    text =
    "No default layout found. Reset all frame positions and sizes to their original factory defaults? This will reload your UI.",
    button1 = "Reset & Reload",
    button2 = "Cancel",
    OnAccept = function()
        NS.ResetLayout()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function NS.WipeDatabase()
    SpeedSplitsDB.InstancePersonalBests = {}
    SpeedSplitsDB.RunHistory = {}
    EnsureDB()
    NS.UpdateColorsFromSettings()
    NS.RefreshAllUI()
    SS_Print("Records wiped. Reloading UI...")
    ReloadUI()
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

local function ApplyBackgroundTexture(tex, name)
    if not tex or not name then return end
    tex:SetTexCoord(0, 1, 0, 1)

    local lowerName = name:lower()
    if lowerName:find("[\\/]") then
        -- Try with/without .blp extension
        local path = name
        if not path:lower():find("%.blp$") and not path:lower():find("%.tga$") then
            path = path .. ".blp"
        end
        tex:SetTexture(path)
    else
        tex:SetAtlas(name)
    end

    if lowerName:find("slate") then
        -- Zoom in for slate textures
        tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
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
    local candidates = { _G["lib-st-v4.1.3"], _G["lib-st"], _G.LibScrollingTable, _G.ScrollingTable }
    for _, lib in ipairs(candidates) do
        if lib and type(lib.CreateST) == "function" then
            ScrollingTable = lib; return lib
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
    totalBg = nil,
    totalLabel = nil,
    totalPB = nil,
    totalSplit = nil,
    totalDelta = nil,
    timerDeltaText = nil,
    timerToastBg = nil,

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

    -- Update display rows based on current height to avoid empty area or static cropping
    local h = UI.st.frame:GetHeight() or 1
    local rowHeight = 24 -- Match initial row height from CreateST
    local displayRows = math.floor(h / rowHeight)
    if displayRows < 1 then displayRows = 1 end

    if UI.st.SetDisplayRows then
        UI.st:SetDisplayRows(displayRows, rowHeight)
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

    local c = (NS.Colors and NS.Colors.turquoise) or { r = 0, g = 0.74, b = 0.76 }
    fs:SetTextColor(c.r, c.g, c.b, 1)
    fs:GetParent().turquoiseSet = true -- Tag to prevent accidental revert

    fs:SetDrawLayer("OVERLAY", 7)
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

local function PBColor() return Colors.gold end
local function DeltaColor(data, cols, realrow, column)
    local e = data[realrow]
    local cell = e and e.cols and e.cols[column - 1]
    return cell and cell.color or nil
end
local function SplitColor(data, cols, realrow, column)
    local e = data[realrow]
    local cell = e and e.cols and e.cols[column - 1]
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

-- =========================================================
-- Run history UI
-- =========================================================
local function FormatEpochShort(epoch)
    return (not epoch or epoch <= 0) and "—" or date("%H:%M %d/%m/%Y", epoch)
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

local function History_GetRow(parent)
    UI.history.rowPool = UI.history.rowPool or {}
    local row = table.remove(UI.history.rowPool)
    if not row then
        row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row:SetHeight(24)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(0, 0, 0, 0)

        row.cols = {}
        for i = 1, 7 do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetHeight(24); row.cols[i] = fs
            if i == 7 then
                local btn = CreateFrame("Button", nil, row)
                btn:SetSize(20, 20); btn:SetPoint("CENTER", fs, "CENTER")
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetAtlas("common-icon-delete"); tex:SetVertexColor(0.8, 0.2, 0.2); tex:SetAllPoints()
                btn:SetNormalTexture(tex)
                btn:SetScript("OnClick", function(self) if self.record then DeleteRecord(self.record) end end)
                row.delBtn = btn
            else
                fs:SetWordWrap(false)
                if fs.SetTextTruncate then fs:SetTextTruncate("REPLACE") end
            end
        end

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.03)

        row.UpdateLayout = function(self)
            local w = UI.history.colWidths
            local avail = UI.history.listFrame:GetWidth() - 20
            local used = w.date + w.expansion + w.time + w.result + w.diff + w.delete
            local dungW = math.max(avail - used, 100)

            local x = 0
            local msOff = 0
            local function SetCol(i, width, align, pivot)
                local c = self.cols[i]
                c:ClearAllPoints()
                if pivot then
                    if msOff == 0 then
                        local t = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        t:SetText(".000")
                        msOff = t:GetStringWidth()
                        t:Hide()
                    end
                    -- Align thousands place but center on the seconds/period
                    -- By aligning the end of the string to (center + msWidth), the decimal point hits the center.
                    c:SetPoint("RIGHT", self, "LEFT", x + (width / 2) + msOff, 0)
                    c:SetPoint("LEFT", self, "LEFT", x, 0)
                    c:SetJustifyH("RIGHT")
                else
                    c:SetPoint("LEFT", self, "LEFT", x, 0)
                    c:SetWidth(width)
                    c:SetJustifyH(align)
                end
                x = x + width
            end
            SetCol(1, w.date, "CENTER")
            SetCol(2, dungW, "LEFT")
            SetCol(3, w.expansion, "CENTER")
            SetCol(4, w.result, "CENTER")
            SetCol(5, w.time, "CENTER", true)
            SetCol(6, w.diff, "CENTER", true)
            SetCol(7, w.delete, "CENTER")
        end
    end
    row:SetParent(parent)
    return row
end

local function History_ReleaseRow(row)
    row:Hide()
    table.insert(UI.history.rowPool, row)
end

UI.RefreshHistoryTable = function()
    if not UI.history or not UI.history.frame or not UI.history.frame:IsShown() then return end

    local f = UI.history.filters or HistoryFilterDefaults()
    local search = NormalizeName(f.search or "")
    local filterResult = f.result or "Any"
    local filterTier = tonumber(f.tier) or 0

    local filtered = {}
    local history = DB and DB.RunHistory
    if type(history) == "table" then
        for i = 1, #history do
            local r = history[i]
            if r.instanceName then
                local nameNorm = NormalizeName(r.instanceName)
                local matchesSearch = (search == "" or nameNorm:find(search, 1, true))
                local matchesTier = (filterTier == 0 or (tonumber(r.tier) == filterTier))

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
                    table.insert(filtered, r)
                end
            end
        end
    end

    -- Sorting
    local sortCol = UI.history.sort_col or 1
    local sortAsc = (UI.history.sort_asc ~= false)

    table.sort(filtered, function(a, b)
        local valA, valB
        if sortCol == 1 then
            valA, valB = tonumber(a.startedAt or 0), tonumber(b.startedAt or 0)
        elseif sortCol == 2 then
            valA, valB = NormalizeName(a.instanceName), NormalizeName(b.instanceName)
        elseif sortCol == 3 then
            valA, valB = tonumber(a.tier or 0), tonumber(b.tier or 0)
        elseif sortCol == 4 then
            local function gO(x) return IsRunPB(x) and 1 or (x.success and 2 or 3) end
            valA, valB = gO(a), gO(b)
        elseif sortCol == 5 then
            valA, valB = tonumber(a.duration) or 999999, tonumber(b.duration) or 999999
        elseif sortCol == 6 then
            local function gD(x)
                local node = GetBestSplitsSubtable(x.instanceName)
                local pb = node and node.FullRun and node.FullRun.duration
                return (pb and x.duration) and (x.duration - pb) or 999999
            end
            valA, valB = gD(a), gD(b)
        end

        if valA ~= valB then
            if sortAsc then return valA < valB else return valA > valB end
        end
        -- Tie breaker: Date DESC
        return tonumber(a.startedAt or 0) > tonumber(b.startedAt or 0)
    end)

    UI.history.filteredData = filtered
    UI.history.UpdateScroll()
end


local function BuildHistoryTierItems()
    local items = { { text = "Any", value = 0 } }
    if not DB or not DB.RunHistory then return items end
    local seen = {}
    for _, r in ipairs(DB.RunHistory) do
        local t = tonumber(r.tier)
        if t and t > 0 then seen[t] = true end
    end
    local tiers = {}
    for t in pairs(seen) do tiers[#tiers + 1] = t end
    table.sort(tiers)
    for _, t in ipairs(tiers) do
        items[#items + 1] = { text = GetTierNameSafe(t), value = t }
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

local function InitHistoryDropDown(dropdown, buildItems, getValue, setValue)
    if not dropdown or not UIDropDownMenu_Initialize then return end
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local items = buildItems()
        if not items then return end
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = item.text, item.value
            info.checked = (getValue() == item.value)
            info.func = function()
                setValue(item.value)
                UIDropDownMenu_SetText(dropdown, item.text)
                UI.RefreshHistoryTable()
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
    if not h or not h.frame or not h.listFrame or not h.colWidths then return end

    local w = h.colWidths
    local avail = h.listFrame:GetWidth() - 20
    local used = w.date + w.expansion + w.time + w.result + w.diff + w.delete
    local dungW = math.max(avail - used, 100)

    if h.rows then
        for _, row in ipairs(h.rows) do
            row:UpdateLayout()
        end
    end

    local x = 0
    local function SetH(i, width)
        h.headerCells[i]:ClearAllPoints()
        h.headerCells[i]:SetPoint("LEFT", h.header, "LEFT", x, 0)
        h.headerCells[i]:SetWidth(width)
        x = x + width
    end
    SetH(1, w.date); SetH(2, dungW); SetH(3, w.expansion); SetH(4, w.result); SetH(5, w.time); SetH(6, w.diff); SetH(7,
        w.delete)

    if h.grips then
        local gH = 24
        x = 0
        local function SetG(i, width)
            x = x + width
            h.grips[i]:ClearAllPoints()
            h.grips[i]:SetPoint("TOPLEFT", h.header, "TOPLEFT", x - 5, 0)
            h.grips[i]:SetPoint("BOTTOMRIGHT", h.header, "TOPLEFT", x + 5, -gH)
        end
        SetG(1, w.date)
        SetG(2, dungW)
        SetG(3, w.expansion)
        SetG(4, w.result)
        SetG(5, w.time)
        SetG(6, w.diff)
    end
end

local function History_BeginColDrag(idx, startX)
    local w = UI.history.colWidths
    UI.history.drag = {
        idx = idx,
        startX = startX,
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
    if not h or not h.drag or not h.listFrame then return end
    local curX = GetCursorPosition() / (h.frame:GetEffectiveScale() or 1)
    local dx = curX - h.drag.startX
    local d = h.drag
    local w = h.colWidths

    local avail = h.listFrame:GetWidth() - 20
    local minDungeon = 100

    local function GetUsedExcept(idx)
        local sum = w.date + w.expansion + w.time + w.result + w.diff + w.delete
        if idx == 1 then
            sum = sum - w.date
        elseif idx == 3 then
            sum = sum - w.expansion
        elseif idx == 4 then
            sum = sum - w.result
        elseif idx == 5 then
            sum = sum - w.time
        elseif idx == 6 then
            sum = sum - w.diff
        end
        return sum
    end

    if d.idx == 1 then
        local maxW = avail - GetUsedExcept(1) - minDungeon
        w.date = Clamp(d.date + dx, 50, maxW)
    elseif d.idx == 2 then
        -- Dragging Dungeon right boundary shrinks Expansion
        w.expansion = Clamp(d.expansion - dx, 50, 400)
    elseif d.idx == 3 then
        local maxW = avail - GetUsedExcept(3) - minDungeon
        w.expansion = Clamp(d.expansion + dx, 50, maxW)
    elseif d.idx == 4 then
        local maxW = avail - GetUsedExcept(4) - minDungeon
        w.result = Clamp(d.result + dx, 50, maxW)
    elseif d.idx == 5 then
        local maxW = avail - GetUsedExcept(5) - minDungeon
        w.time = Clamp(d.time + dx, 50, maxW)
    elseif d.idx == 6 then
        local maxW = avail - GetUsedExcept(6) - minDungeon
        w.diff = Clamp(d.diff + dx, 50, maxW)
    end
    History_ApplyTableLayout()
end

local function History_MakeGrip(parent, i)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(10, 24)
    g:EnableMouse(true)
    g:SetFrameLevel(parent:GetFrameLevel() + 10)
    local tex = g:CreateTexture(nil, "OVERLAY")
    tex:SetSize(1, 16); tex:SetPoint("CENTER"); tex:SetColorTexture(1, 1, 1, 0.2)
    g:SetScript("OnEnter", function()
        SetCursor("UI_RESIZE_CURSOR"); tex:SetColorTexture(1, 1, 1, 0.8)
    end)
    g:SetScript("OnLeave", function()
        ResetCursor(); tex:SetColorTexture(1, 1, 1, 0.2)
    end)
    g:SetScript("OnMouseDown", function()
        local x = GetCursorPosition() / (UI.history.frame:GetEffectiveScale() or 1)
        History_BeginColDrag(i, x)
        g:SetScript("OnUpdate", History_UpdateColDrag)
    end)
    g:SetScript("OnMouseUp", function()
        g:SetScript("OnUpdate", nil); History_EndColDrag()
    end)
    return g
end

local function History_EnsureColGrips()
    if UI.history.grips then return end
    UI.history.grips = {}
    for i = 1, 6 do UI.history.grips[i] = History_MakeGrip(UI.history.header, i) end
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

    -- Scroll List
    local listFrame = CreateFrame("Frame", nil, historyFrame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -34)
    listFrame:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -26, 10)
    listFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    listFrame:SetBackdropColor(0, 0, 0, 0.4)
    listFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    listFrame:SetClipsChildren(true)
    UI.history.listFrame = listFrame

    local scrollFrame = CreateFrame("ScrollFrame", "SpeedSplitsHistoryScroll", historyFrame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT")
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT")
    UI.history.scrollFrame = scrollFrame

    -- Header row
    local header = CreateFrame("Frame", nil, historyFrame)
    header:SetHeight(24)
    header:SetPoint("BOTTOMLEFT", listFrame, "TOPLEFT", 0, 2)
    header:SetPoint("BOTTOMRIGHT", listFrame, "TOPRIGHT", 0, 2)
    UI.history.header = header

    local hCols = { "Date", "Dungeon", "Expansion", "Result", "Time", "Difference", "" }
    UI.history.headerCells = {}
    for i = 1, 7 do
        local btn = CreateFrame("Button", nil, header)
        btn:SetHeight(24)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(hCols[i])
        fs:SetAllPoints()
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        btn:SetFontString(fs)
        StyleHeaderCell(btn, "CENTER")
        btn:SetScript("OnClick", function()
            if i == 7 then return end
            if UI.history.sort_col == i then
                UI.history.sort_asc = not UI.history.sort_asc
            else
                UI.history.sort_col = i
                UI.history.sort_asc = (i == 5 or i == 6) -- ASC for time/diff, DESC for others
            end
            UI.RefreshHistoryTable()
        end)
        UI.history.headerCells[i] = btn
    end

    UI.history.rows = {}
    local function UpdateHistoryRows()
        local h = UI.history
        local availH = listFrame:GetHeight()
        local rowH = 24
        local count = math.ceil(availH / rowH)
        for i = 1, math.max(count, #h.rows) do
            if i <= count then
                if not h.rows[i] then
                    h.rows[i] = History_GetRow(listFrame)
                    h.rows[i]:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -(i - 1) * rowH)
                    h.rows[i]:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, -(i - 1) * rowH)
                end
                h.rows[i]:Show()
                h.rows[i]:UpdateLayout()
            elseif h.rows[i] then
                h.rows[i]:Hide()
            end
        end
    end

    UI.history.UpdateScroll = function()
        local h = UI.history
        local data = h.filteredData or {}
        local rowH = 24
        local numRows = #h.rows
        FauxScrollFrame_Update(h.scrollFrame, #data, numRows, rowH)
        local offset = FauxScrollFrame_GetOffset(h.scrollFrame)
        for i = 1, numRows do
            local r = h.rows[i]
            local idx = i + offset
            local d = data[idx]
            if d then
                local isPB = IsRunPB(d)
                local resText, resColor = "Incomplete", NS.Colors.darkRed
                if isPB then
                    resText, resColor = "PB", NS.Colors.gold
                elseif d.success then
                    resText, resColor = "Completed", NS.Colors.deepGreen
                end

                local node = GetBestSplitsSubtable(d.instanceName)
                local pb = node and node.FullRun and node.FullRun.duration
                local diff = (pb and d.duration) and (d.duration - pb) or nil

                r.cols[1]:SetText(FormatEpochShort(d.startedAt))
                r.cols[2]:SetText(d.instanceName or "—")
                r.cols[3]:SetText(GetTierNameSafe(d.tier))
                r.cols[4]:SetText(resText)
                r.cols[4]:SetTextColor(resColor.r, resColor.g, resColor.b)
                r.cols[5]:SetText(d.duration and FormatTime(d.duration) or "--:--.---")

                if diff then
                    local _, _, _, hex = NS.GetPaceColor(diff, isPB)
                    r.cols[6]:SetText(hex .. FormatDelta(diff) .. "|r")
                else
                    r.cols[6]:SetText("—")
                end

                r.delBtn.record = d
                r.bg:SetShown(idx % 2 == 0)
                r:Show()
            else
                r:Hide()
            end
        end
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 24, UI.history.UpdateScroll)
    end)

    historyFrame:SetScript("OnSizeChanged", function()
        UpdateHistoryRows()
        History_ApplyTableLayout()
        UI.history.UpdateScroll()
    end)

    -- Resizer
    local grip = SetupSizeGrip(historyFrame, function()
        SaveFrameGeom("history", historyFrame)
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

    UI.history.frame = historyFrame
    historyFrame:Hide()
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
    UI.timerFrame = timerFrame

    local pbShine = timerFrame:CreateTexture(nil, "OVERLAY")
    pbShine:SetAtlas("challenges-bannershine")
    pbShine:SetPoint("BOTTOM", timerFrame, "TOP", 0, -20)
    pbShine:SetSize(PB_SHINE_WIDTH, PB_SHINE_HEIGHT)
    pbShine:SetAlpha(0)
    UI.pbShine = pbShine

    -- Keep these in sync with the toast background fade (TestPBToast uses 3.0 hold, 1.5 fade)
    local TOAST_HOLD = 3.0
    local TOAST_FADE = 1.5

    local SHINE_IN = 0.3
    local SHINE_HOLD = math.max(0, TOAST_HOLD - SHINE_IN)
    local SHINE_OUT = TOAST_FADE

    local shineAG = pbShine:CreateAnimationGroup()

    local shineIn = shineAG:CreateAnimation("Alpha")
    shineIn:SetFromAlpha(0)
    shineIn:SetToAlpha(1)
    shineIn:SetDuration(SHINE_IN)
    shineIn:SetOrder(1)

    local shineHold = shineAG:CreateAnimation("Alpha")
    shineHold:SetFromAlpha(1)
    shineHold:SetToAlpha(1)
    shineHold:SetDuration(SHINE_HOLD)
    shineHold:SetOrder(2)

    local shineOut = shineAG:CreateAnimation("Alpha")
    shineOut:SetFromAlpha(1)
    shineOut:SetToAlpha(0)
    shineOut:SetDuration(SHINE_OUT)
    shineOut:SetOrder(3)

    UI.pbShineAG = shineAG

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

    local timerToastBg = timerFrame:CreateTexture(nil, "BACKGROUND", nil, -5)
    timerToastBg:SetAllPoints(timerFrame)
    timerToastBg:SetAlpha(0)
    UI.timerToastBg = timerToastBg

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
        -- Ace3-styled Scrollbar implementation
        if st.scrollframe then
            local scrollbar = _G[st.scrollframe:GetName() .. "ScrollBar"]
            if scrollbar then
                scrollbar:SetWidth(10)
                local up = _G[scrollbar:GetName() .. "ScrollUpButton"]
                local down = _G[scrollbar:GetName() .. "ScrollDownButton"]
                if up then up:Hide() end
                if down then down:Hide() end

                local thumb = scrollbar:GetThumbTexture()
                if thumb then
                    thumb:SetColorTexture(0.4, 0.4, 0.4, 0.8)
                    thumb:SetWidth(8)
                end

                local bg = scrollbar:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, 0.5)
            end
        end
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
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    totalFrame:SetBackdropColor(0, 0, 0, 0) -- Translucent black background replaced by texture
    UI.totalFrame = totalFrame

    local totalBg = totalFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    totalBg:SetAllPoints(totalFrame)
    UI.totalBg = totalBg

    local logoText = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logoText:SetPoint("LEFT", 10, 0)
    logoText:SetText("SpeedSplits")
    UI.logoText = logoText

    local logoShimmer = totalFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    logoShimmer:SetAtlas("bonusobjectives-bar-shine")
    logoShimmer:SetSize(60, 24); logoShimmer:SetBlendMode("ADD"); logoShimmer:SetAlpha(0)
    logoShimmer:SetPoint("LEFT", totalFrame, "LEFT", -60, 0)
    UI.logoShimmer = logoShimmer

    local shimAG = logoShimmer:CreateAnimationGroup()
    local shimMove = shimAG:CreateAnimation("Translation")
    shimMove:SetOffset(400, 0); shimMove:SetDuration(1.0); shimMove:SetSmoothing("IN_OUT")
    local shimAlpha = shimAG:CreateAnimation("Alpha")
    shimAlpha:SetFromAlpha(0); shimAlpha:SetToAlpha(0.8); shimAlpha:SetDuration(0.15); shimAlpha:SetOrder(1)
    local shimAlphaOut = shimAG:CreateAnimation("Alpha")
    shimAlphaOut:SetFromAlpha(0.8); shimAlphaOut:SetToAlpha(0); shimAlphaOut:SetDuration(0.3); shimAlphaOut
        :SetStartDelay(0.7)
    shimAG:SetLooping("REPEAT")
    UI.logoShimmerAG = shimAG
    shimAG:Play()

    -- History button on Footer Tab
    local historyButton = CreateFrame("Button", nil, totalFrame)
    historyButton:SetSize(18 * HISTORY_ICON_SCALE, 18 * HISTORY_ICON_SCALE)
    historyButton:SetPoint("LEFT", logoText, "RIGHT", 8, 0)
    historyButton:SetNormalAtlas("perks-clock-large")
    historyButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    UI.historyButton = historyButton

    historyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Run history", 1, 1, 1)
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

    -- Delayed refresh to ensure LibScrollingTable is fully ready to be styled
    C_Timer.After(0.5, function()
        if NS.RefreshAllUI then NS.RefreshAllUI() end
    end)
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

    local c = NS.Colors.white
    if finished then
        if Run.lastColorR then
            c = { r = Run.lastColorR, g = Run.lastColorG, b = Run.lastColorB, a = 1 }
        else
            c = NS.Colors.deepGreen
        end
    end
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

local function SetTimerDelta(delta, isPB)
    if not UI.timerDeltaText then return end
    if delta == nil then
        UI.timerDeltaText:SetText("")
        if UI.timerToastBg then
            UI.timerToastBg:SetAlpha(0)
        end
        return
    end

    local _, _, _, hex = GetPaceColor(delta, isPB)
    UI.timerDeltaText:SetText(hex .. FormatDelta(delta) .. "|r")
    UI.timerDeltaText:SetTextColor(1, 1, 1, 1)

    -- Update mirror texture without forcing alpha
    if UI.timerToastBg then
        local tex = GetPaceToastTexture(delta, isPB)
        ApplyBackgroundTexture(UI.timerToastBg, tex)
    end
end


local function SetKillCount(killed, total)
    local displayName = (NS.Run and NS.Run.instanceName ~= "") and NS.Run.instanceName or "Boss"
    local text = string.format("%s (%d/%d)", displayName, killed or 0, total or 0)

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

    row.cols[2].value = (cumulativePB and cumulativePB > 0) and FormatTime(cumulativePB) or "--:--.---"
    row.cols[2].color = NS.Colors.gold
    row.cols[3].value = FormatTime(splitCumulative)
    row.cols[3].color = isGold and NS.Colors.gold or { r = r, g = g, b = b, a = 1 }

    if deltaSeconds == nil then
        row.cols[4].value = ""
        row.cols[4].color = nil
    else
        row.cols[4].value = FormatDelta(deltaSeconds)
        row.cols[4].color = isGold and NS.Colors.gold or { r = r, g = g, b = b, a = 1 }
    end

    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end
end


-- =========================================================
-- Run state + PB update logic
-- =========================================================

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
    Run.lastDelta = 0
    Run.lastColorR, Run.lastColorG, Run.lastColorB, Run.lastColorHex = nil, nil, nil, nil
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
        Run.lastColorR, Run.lastColorG, Run.lastColorB, Run.lastColorHex = r, g, b, hex
        Run.lastIsPB = isPB
        SetTotals(pbTotal, duration, deltaTotal, r, g, b, hex)
        SetTimerDelta(deltaTotal, isPB)
        SetTimerText(duration, true) -- Update timer color to match final pace
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
        local r, g, b, hex = Run.lastColorR or 1, Run.lastColorG or 1, Run.lastColorB or 1,
            Run.lastColorHex or "|cffffffff"
        SetTotals(Run.lastPBTotal, Run.lastSplitCumulative, Run.lastDelta, r, g, b, hex)
        SetTimerDelta(Run.lastDelta, Run.lastIsPB)
    else
        SetTotals(pbTotal, nil, nil)
        SetTimerDelta(nil, false)
    end
end
NS.Run = Run
local function TestPBToast(manualTex)
    if not UI.timerToastBg then return end
    local tex = manualTex or NS.TimerToastTextures[1] -- Use Gold by default for test if no manual tex
    ApplyBackgroundTexture(UI.timerToastBg, tex)

    -- Play the selected sound ONLY if it's the Gold texture (as per user request for test button)
    if tex == NS.TimerToastTextures[1] then
        if NS.DB.Settings.toastSoundID and NS.DB.Settings.toastSoundID > 0 then
            PlaySoundFile(NS.DB.Settings.toastSoundID, "SFX")
        end
    end

    -- Trigger the banner shine ONLY if using the gold texture (first index)
    if UI.pbShineAG and tex == NS.TimerToastTextures[1] then
        UI.pbShineAG:Stop(); UI.pbShineAG:Play()
    end

    UI.timerToastBg:SetAlpha(1)
    C_Timer.After(3.0, function()
        if UI.timerToastBg then
            local f = CreateFrame("Frame")
            f.elapsed = 0
            f:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                local alpha = 1 - (self.elapsed / 1.5)
                if alpha <= 0 then
                    UI.timerToastBg:SetAlpha(0)
                    if UI.pbShine then UI.pbShine:SetAlpha(0) end
                    self:SetScript("OnUpdate", nil)
                else
                    UI.timerToastBg:SetAlpha(alpha)
                    if UI.pbShine and tex == NS.TimerToastTextures[1] then
                        UI.pbShine:SetAlpha(alpha)
                    end
                end
            end)
        end
    end)
end
NS.TestPBToast = TestPBToast

function NS.UpdateToastLayout()
    if not UI.timerToastBg then return end
    local scale = NS.DB.Settings.timerToastScale or 1.0

    -- Apply scale relative to timerFrame size
    UI.timerToastBg:ClearAllPoints()
    local parent = UI.timerToastBg:GetParent()
    local w, h = parent:GetSize()
    UI.timerToastBg:SetSize(w * scale, h * scale)
    UI.timerToastBg:SetPoint("CENTER", parent, "CENTER", 0, 0)

    -- Sync PB shine if it exists
    if UI.pbShine then
        UI.pbShine:SetSize(PB_SHINE_WIDTH * scale, PB_SHINE_HEIGHT * scale)
    end
end

function NS.UpdateColorsOnly()
    if not UI.bossFrame then return end
    if UI.logoText then
        UI.logoText:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 1)
    end
    if UI.killCountText then
        UI.killCountText:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 1)
    end
    if UI.logoGlow then
        UI.logoGlow:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.6)
    end
    if UI.historyButton then
        local tex = UI.historyButton:GetNormalTexture()
        if tex then tex:SetVertexColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b) end
    end
    if UI.bossFrame then
        UI.bossFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    end
    if UI.borderFrame then
        UI.borderFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    end
    if UI.titleTab then
        UI.titleTab:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.5)
    end
    if UI.totalFrame then
        UI.totalFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.5)
    end
    if UI.totalBg then
        UI.totalBg:SetTexture(nil)
        UI.totalBg:SetColorTexture(0.2, 0.2, 0.2, 0.7) -- Greyish translucent background
    end
    if UI.titleBg then
        local texName = NS.DB.Settings.titleTexture or NS.TitleTextures[1]
        ApplyBackgroundTexture(UI.titleBg, texName)
    end

    -- Update header colors in tables
    if UI.st and UI.st.head and UI.st.head.cols then
        for i = 1, #UI.st.head.cols do
            StyleHeaderCell(UI.st.head.cols[i], UI.cols[i].align, 1.0, UI.cols[i].name)
        end
    end
end

function NS.UpdateFontsOnly()
    if not UI.bossFrame then return end
    if UI.killCountText then NS.ApplyFontToFS(UI.killCountText, "counter") end
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

    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end

    if UI.st and UI.st.head and UI.st.head.cols then
        for i = 1, #UI.st.head.cols do
            StyleHeaderCell(UI.st.head.cols[i], UI.cols[i].align, 1.0, UI.cols[i].name)
        end
    end
end

function NS.RefreshAllUI()
    if not UI.bossFrame then return end
    NS.UpdateColorsFromSettings()
    NS.UpdateColorsOnly()
    NS.UpdateFontsOnly()
    NS.UpdateToastLayout()

    if UI.timerToastBg then
        if Run.inInstance then
            UI.timerToastBg:SetAlpha(0.15)
        else
            UI.timerToastBg:SetAlpha(0)
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
    if NS.UpdateHistoryLayout then NS.UpdateHistoryLayout() end

    -- Handle table content rendering
    if NS.Run.entries and #NS.Run.entries > 0 then
        local node = GetBestSplitsSubtable()
        local pbTable = node and node.Segments or {}
        if #UI.data ~= #NS.Run.entries then
            RenderBossTable(NS.Run.entries, pbTable)
        end

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

    -- Prepare cumulative comparison vs old PB sum (DETERMINE PACE BEFORE PB UPDATE)
    local cumulativePB_Comparison = 0
    for _, entry in ipairs(Run.entries) do
        local seg = pbTable[entry.name] or 0
        cumulativePB_Comparison = cumulativePB_Comparison + seg
        if entry.key == bossKey then
            break
        end
    end
    local deltaOverallAtKill = splitCumulative - cumulativePB_Comparison

    -- Update the table with the new best segment
    if isNewSegmentPB then
        pbTable[bossName] = splitSegment
    end

    -- Timer Reward Toast
    if NS.DB.Settings.showTimerToast and UI.timerToastBg then
        local isLastBoss = (Run.remainingCount or 0) == 0 and #Run.entries > 0
        local shouldToast = NS.DB.Settings.toastAllBosses or isLastBoss

        if shouldToast then
            local tex = NS.GetPaceToastTexture(deltaOverallAtKill, isNewSegmentPB)
            ApplyBackgroundTexture(UI.timerToastBg, tex)

            if isNewSegmentPB then
                if NS.DB.Settings.toastSoundID and NS.DB.Settings.toastSoundID > 0 then
                    PlaySoundFile(NS.DB.Settings.toastSoundID, "SFX")
                end
                -- Only show shine if the texture is "Gold" (the first one)
                if UI.pbShineAG and NS.DB.Settings.timerToastTexture == NS.TimerToastTextures[1] then
                    UI.pbShineAG:Stop(); UI.pbShineAG:Play()
                end
            end

            UI.timerToastBg:SetAlpha(1)
            C_Timer.After(4.0, function()
                if UI.timerToastBg then
                    local f = CreateFrame("Frame")
                    f.elapsed = 0
                    f:SetScript("OnUpdate", function(self, elapsed)
                        self.elapsed = self.elapsed + elapsed
                        local alpha = 1 - (self.elapsed / 1.5)
                        if alpha <= 0 then
                            UI.timerToastBg:SetAlpha(0)
                            if UI.pbShine then UI.pbShine:SetAlpha(0) end
                            self:SetScript("OnUpdate", nil)
                        else
                            UI.timerToastBg:SetAlpha(alpha)
                            -- Sync PB shine with toast fade if it was active
                            if UI.pbShine and UI.pbShine:GetAlpha() > 0 then
                                UI.pbShine:SetAlpha(alpha)
                            end
                        end
                    end)
                end
            end)
        end
    end

    -- Toast sound (best-effort "per-addon volume" by temporarily setting SFX volume)
    local function PlayToastSoundOnce()
        local soundID = NS.DB and NS.DB.Settings and NS.DB.Settings.toastSoundID
        if not soundID or soundID <= 0 then return end

        local toastVol = (NS.DB.Settings.toastVolume ~= nil) and Clamp(NS.DB.Settings.toastVolume, 0, 1) or nil
        local oldSFX = tonumber(GetCVar("Sound_SFXVolume") or "1") or 1

        if toastVol ~= nil then
            SetCVar("Sound_SFXVolume", tostring(toastVol))
        end

        -- Some IDs are SoundKitIDs (PlaySound), some behave like FileIDs (PlaySoundFile).
        local ok = pcall(PlaySound, soundID, "SFX")
        if not ok then
            pcall(PlaySoundFile, soundID, "SFX")
        end

        if toastVol ~= nil then
            C_Timer.After(0.25, function()
                SetCVar("Sound_SFXVolume", tostring(oldSFX))
            end)
        end
    end

    NS.PlayToastSoundOnce = PlayToastSoundOnce

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
    local r, g, b, hex = GetPaceColor(deltaOverall, isNewSegmentPB)

    -- Store for footer/timer synchronization
    Run.lastDelta = deltaOverall
    Run.lastPBTotal = pbTotalTableSum
    Run.lastSplitCumulative = splitCumulative
    Run.lastColorR, Run.lastColorG, Run.lastColorB, Run.lastColorHex = r, g, b, hex
    Run.lastIsPB = isNewSegmentPB

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
