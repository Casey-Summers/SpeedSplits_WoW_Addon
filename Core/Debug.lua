local _, NS = ...

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccccSpeedSplits|r: " .. tostring(msg))
    else
        print("SpeedSplits: " .. tostring(msg))
    end
end

NS.Print = Print
SS_Print = Print

SpeedSplits_DebugObjectives = SpeedSplits_DebugObjectives or false
