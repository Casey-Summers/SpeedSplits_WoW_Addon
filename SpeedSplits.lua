-- Debugging message to ensure Addon loaded
print("SpeedSplits successfully loaded!")

-- === Database ===
-- List of default values for variables
local DefaultDB = {
    bossKills = 0, -- tracks total boss kills
    bossKillHistory = {}, -- {{id, name, split}}
    runs = {} -- saves splits per instance, per run
}

local function ActivateDB()
    -- Ensures Database exists and creates it if not
    if not SpeedSplitsDB then
        SpeedSplitsDB = {}
    end

    -- Initialises DB variables to avoid NULL errors on first loaded
    for key, defaultValue in pairs(DefaultDB) do
        if SpeedSplitsDB[key] == nil then
            SpeedSplitsDB[key] = defaultValue
        end
    end
    return SpeedSplitsDB
end

local DB = ActivateDB()

-- === Main Frame ===
-- Creates the mainFrame
local mainFrame = CreateFrame("Frame", "SpeedSplitsMainFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(500, 350)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Creates Title for mainFrame
mainFrame.TitleBg:SetHeight(30)
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("TOPLEFT", mainFrame.TitleBg, "TOPLEFT", 5, -3)
mainFrame.title:SetText("SpeedSplits")
mainFrame:Show() -- Important !!!

-- Allows the frame to be dragged
mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Calls the WoW API and adds content to mainFrame
mainFrame.playerName = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mainFrame.playerName:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -35)
mainFrame.playerName:SetText("Character: " .. UnitName("player") .. " (Level: " .. UnitLevel("player") .. ")")

mainFrame.totalBossKills = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mainFrame.totalBossKills:SetPoint("TOPLEFT", mainFrame.playerName, "BOTTOMLEFT", 0, -50)
mainFrame.totalBossKills:SetText("Total boss kills: " .. (DB.bossKills))

-- Timer frame
local timerFrame = CreateFrame("Frame", "SpeedSplitsTimerFrame", UIParent, "BasicFrameTemplateWithInset")
timerFrame:SetSize(200, 80)
timerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
timerFrame:Show()

timerFrame.TitleBg:SetHeight(30)
timerFrame.title = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
timerFrame.title:SetPoint("TOPLEFT", timerFrame.TitleBg, "TOPLEFT", 5, -3)
timerFrame.title:SetText("Run Timer")

timerFrame.timeText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
timerFrame.timeText:SetPoint("CENTER", timerFrame, "CENTER", 0, -8)
timerFrame.timeText:SetText("0:00.000")

timerFrame:EnableMouse(true)
timerFrame:SetMovable(true)
timerFrame:RegisterForDrag("LeftButton")
timerFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
timerFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Creates an invisible event listener frame
local eventListenerFrame = CreateFrame("Frame", "SpeedSplitsEventListenerFrame", UIParent)

-- === Timer State ===
local pendingRunStart = false
local timerRunning = false
local runStartTime = nil

-- === Boss Kill Logic ===
-- Stores every boss kill line added (so they can be stacked)
local bossKillLines = {}
local nextLineNumber = 1
local lastKilledBossName -- Store the most recently killed boss name

local function addBossKill(encounterID, encounterName)
    DB.bossKills = DB.bossKills + 1
    mainFrame.totalBossKills:SetText("Total boss kills: " .. (DB.bossKills)) -- Initialise bossKills at first read

    table.insert(DB.bossKillHistory, {
        id = encounterID,
        name = encounterName,
        when = time()
    })

    -- Defines a template and stackable new line 
    local newLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    -- Sets the point for the new line dynamically based on -35 pixels below the top, and -14 pixesl from the previous entry
    local yOffset = -10 - ((nextLineNumber - 1) * 14)
    newLine:SetPoint("TOPLEFT", mainFrame.totalBossKills, "BOTTOMLEFT", 0, yOffset)

    -- Defines the text to add as a new entry
    newLine:SetText("BOSS_KILL: " .. encounterName .. " (ID: " .. encounterID .. ")")

    -- Iterates for every entry
    bossKillLines[nextLineNumber] = newLine
    nextLineNumber = nextLineNumber + 1
end

local function FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local remainder = seconds - (minutes * 60)
    return string.format("%d:%06.3f", minutes, remainder)
end

local function StartTimer()
    if timerRunning then
        return
    end

    runStartTime = GetTime()
    timerRunning = true

    timerFrame:SetScript("OnUpdate", function()
        timerFrame.timeText:SetText(FormatTime(GetTime() - runStartTime))
    end)
end

local function StopTimer()
    timerFrame:SetScript("OnUpdate", nil)
    pendingRunStart = false
    timerRunning = false
    runStartTime = nil
    timerFrame.timeText:SetText("0:00.000")
end

-- === Events ===
-- when event condition is met, call this funciton
local function eventHandler(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local inInstance = IsInInstance()

        if inInstance then
            pendingRunStart = true
            print("Entered instance: timer armed (waiting for movement).")

            -- edge case: if you reload while already moving, start immediately
            if GetUnitSpeed("player") > 0 then
                pendingRunStart = false
                StartTimer()
            end
        else
            StopTimer()
            print("left instance: timer cleared.")
        end
        return
    end

    if event == "PLAYER_STARTED_MOVING" then
        if pendingRunStart and IsInInstance() then
            pendingRunStart = false
            StartTimer()
            print("Moved in instance: timer started.")
        end
        return
    end

    if event == "BOSS_KILL" then
        -- BOSS_KILL args come from ... 
        local encounterID, encounterName = ...

        -- Stores the last boss killed based on the e-trace message
        lastKilledBossName = encounterName

        -- If it is true that there was a lastKilledBossName, then add the boss to the frame
        if lastKilledBossName then
            addBossKill(encounterID, encounterName)
        else
            print("No boss name found!")
        end
    end
end

-- Registers the event frame to the event, and what function should be called 
eventListenerFrame:SetScript("OnEvent", eventHandler)
eventListenerFrame:RegisterEvent("BOSS_KILL")
eventListenerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventListenerFrame:RegisterEvent("PLAYER_STARTED_MOVING")

-- === Slash Commands ===
-- Commands to show addon
SLASH_SPEEDSPLITS1 = "/speedsplits"
SLASH_SPEEDSPLITS2 = "/ss"
SlashCmdList["SPEEDSPLITS"] = function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        timerFrame:Hide()
    else
        mainFrame:Show()
        timerFrame:Show()
    end
end

-- Allows addon to be exited with ESC
-- table.insert(UISpecialFrames, "SpeedSplitsMainFrame")
-- table.insert(UISpecialFrames, "SpeedSplitsTimerFrame")
