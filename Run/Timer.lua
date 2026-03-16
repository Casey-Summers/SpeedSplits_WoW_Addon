local _, NS = ...

local TimerUpdater = CreateFrame("Frame")

local function CancelTimerTicker()
    TimerUpdater:SetScript("OnUpdate", nil)
end

local function StartTimerTicker()
    CancelTimerTicker()
    TimerUpdater:SetScript("OnUpdate", function()
        if NS.Run.active and NS.Run.startGameTime > 0 then
            NS.UI.SetTimerText(NS.NowGameTime() - NS.Run.startGameTime, false)
        end
    end)
end

local function StopRun(success, endTime)
    if not NS.Run.active then
        return
    end
    NS.Run.active = false
    CancelTimerTicker()
    NS.Run.endGameTime = endTime or NS.NowGameTime()
    NS.Run.endedAt = NS.NowEpoch()
    local duration = NS.Run.endGameTime - NS.Run.startGameTime
    NS.UI.SetTimerText(duration, true)
    NS.RunLogic.SaveRunRecord(success)
    if success then
        NS.UI.RefreshTotals(true)
    end
end

local function StartRunTimer()
    if NS.Run.active then
        return
    end
    NS.Run.active = true
    NS.Run.waitingForMove = false
    NS.Run.startedAt = NS.NowEpoch()
    NS.Run.startGameTime = NS.NowGameTime()
    NS.Run.endGameTime = 0
    NS.Run.endedAt = 0
    NS.UI.SetTimerText(0, false)
    StartTimerTicker()
end

NS.RunLogic.CancelTimerTicker = CancelTimerTicker
NS.RunLogic.StartTimerTicker = StartTimerTicker
NS.RunLogic.StopRun = StopRun
NS.RunLogic.StartRunTimer = StartRunTimer
