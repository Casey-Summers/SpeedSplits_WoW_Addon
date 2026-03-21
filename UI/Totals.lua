local _, NS = ...

local UI = NS.UI
local Util = NS.Util

local function SetKillCount(killed, total)
    local displayName = (NS.Run and NS.Run.instanceName ~= "") and NS.Run.instanceName or "Boss"
    local counterText = string.format("(%d/%d)", killed or 0, total or 0)

    if UI.killCountText then
        UI.killCountText:SetText(displayName)
    end
    if UI.killCountCounterText then
        UI.killCountCounterText:SetText(counterText)
    end

    if UI.RestyleBossTableHeaders then
        UI.RestyleBossTableHeaders(1.0)
    end
end

local function SetTextColor(target, color, fallback)
    local active = color or fallback or NS.Colors.white
    target:SetTextColor(active.r, active.g, active.b, active.a or 1)
end

local function SetTotals(pbTotal, splitTotal, diffTotal, splitColor, diffColor)
    if not UI.totalPB or not UI.totalSplit or not UI.totalDelta then
        return
    end

    if pbTotal == nil then
        UI.totalPB:SetText("--:--.---")
    else
        UI.totalPB:SetText(Util.FormatTime(pbTotal))
    end
    SetTextColor(UI.totalPB, NS.Colors.gold, NS.Colors.gold)

    if splitTotal == nil then
        UI.totalSplit:SetText("--:--.---")
        SetTextColor(UI.totalSplit, nil, NS.Colors.white)
    else
        UI.totalSplit:SetText(Util.FormatTime(splitTotal))
        SetTextColor(UI.totalSplit, splitColor, NS.Colors.white)
    end

    if diffTotal == nil then
        UI.totalDelta:SetText("")
    else
        UI.totalDelta:SetText(Util.FormatDelta(diffTotal))
        SetTextColor(UI.totalDelta, diffColor, NS.Colors.white)
    end
end

local function EnsurePresentation()
    if NS.Run.presentation and NS.Run.presentation.rowsByKey then
        return NS.Run.presentation
    end
    if NS.RunLogic and NS.RunLogic.BuildRunPresentation then
        NS.Run.presentation = NS.RunLogic.BuildRunPresentation(NS.Run, NS.Run.pbSegmentsSnapshot or {})
    end
    return NS.Run.presentation
end

local function RefreshTotals(isFinal)
    local presentation = EnsurePresentation()
    local summary = presentation and presentation.summary or nil
    if not summary then
        SetTotals(nil, nil, nil)
        UI.SetTimerDelta(nil)
        return
    end

    SetTotals(summary.pbTotal, summary.splitTotal, summary.diffTotal, summary.splitColor, summary.diffColor)
    UI.SetTimerDelta(summary.diffTotal, summary.diffColor)

    if isFinal then
        local duration = (NS.Run.endGameTime > 0 and NS.Run.startGameTime > 0) and
            (NS.Run.endGameTime - NS.Run.startGameTime) or nil
        if duration then
            UI.SetTimerText(duration, true)
        end
    end
end

UI.SetKillCount = SetKillCount
UI.RefreshTotals = RefreshTotals
NS.SetTotals = SetTotals
