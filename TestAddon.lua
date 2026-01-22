-- Debugging message to ensure Addon loaded
print("MyAddon successfully loaded!")

-- Ensures Database exists and creates it if not
if not MyAddonDB then
    MyAddonDB = {}
end

-- Creates the mainFrame
local mainFrame = CreateFrame("Frame", "MyAddonMainFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(500, 350)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Creates Title for mainFrame
mainFrame.TitleBg:SetHeight(30)
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("TOPLEFT", mainFrame.TitleBg, "TOPLEFT", 5, -3)
mainFrame.title:SetText("TestAddon")
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

-- Initialise bossKills at first read
mainFrame.totalBossKills:SetText("Total boss kills: " .. (MyAddonDB.bossKills))

-- Allows addon to be exited with ESC
table.insert(UISpecialFrames, "MyAddonMainFrame")

-- Creates an invisible event listener frame
local eventListenerFrame = CreateFrame("Frame", "TestAddonEventListenerFrame", UIParent)

-- Store the most recently killed boss name
local lastKilledBossName

-- Stores every boss kill line we add (so we can stack them)
local bossKillLines = {}
local nextLineNumber = 1

local function addBossKill(encounterID, encounterName)
    -- Defines a template and stackable new line 
    local newLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    if not MyAddonDB.bossKills then
        MyAddonDB.bossKills = 1
    else
        MyAddonDB.bossKills = MyAddonDB.bossKills + 1
    end

    -- Sets the point for the new line dynamically based on -35 pixels below the top, and -14 pixesl from the previous entry
    newLine:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -35 - ((nextLineNumber - 1) * 14))

    -- Defines the text to add as a new entry
    newLine:SetText("BOSS_KILL: " .. encounterName .. " (ID: " .. encounterID .. ")")

    -- Iterates for every entry
    bossKillLines[nextLineNumber] = newLine
    nextLineNumber = nextLineNumber + 1
end

-- when event condition is met, call this funciton
local function eventHandler(self, event, ...)
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

-- Commands to show addon
SLASH_TESTADDON1 = "/testaddon"
SLASH_TESTADDON2 = "/ta"
SlashCmdList["TESTADDON"] = function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

mainFrame:SetScript("OnShow", function()
    PlaySound(808)
    mainFrame.totalBossKills:SetText("Total boss kills: " .. (MyAddonDB.bossKills))
end)
