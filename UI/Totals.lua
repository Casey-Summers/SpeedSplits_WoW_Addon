local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local SECTION_TOTAL_PLACEHOLDER = "--:--.--"

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

local function SetSummaryText(target, value, color)
    if not target then
        return
    end

    target._text = tostring(value or "")
    target._color = color or target._color or NS.Colors.white

    if UI.SetDecimalAlignedText then
        UI.SetDecimalAlignedText(
            target,
            "summary",
            target._text,
            "num",
            target._color,
            target._pivotX or math.floor((target:GetWidth() or 0) / 2 + 0.5),
            0,
            0
        )
    end
end

local function SetTotals(pbTotal, splitTotal, diffTotal, splitColor, diffColor)
    if not UI.totalPB or not UI.totalSplit or not UI.totalDelta then
        return
    end

    if pbTotal == nil then
        SetSummaryText(UI.totalPB, SECTION_TOTAL_PLACEHOLDER, NS.Colors.gold)
    else
        SetSummaryText(UI.totalPB, Util.FormatTime(pbTotal), NS.Colors.gold)
    end
    SetTextColor(UI.totalPB, NS.Colors.gold, NS.Colors.gold)

    if splitTotal == nil then
        SetSummaryText(UI.totalSplit, SECTION_TOTAL_PLACEHOLDER, NS.Colors.white)
        SetTextColor(UI.totalSplit, nil, NS.Colors.white)
    else
        SetSummaryText(UI.totalSplit, Util.FormatTime(splitTotal), splitColor or NS.Colors.white)
        SetTextColor(UI.totalSplit, splitColor, NS.Colors.white)
    end

    if diffTotal == nil then
        SetSummaryText(UI.totalDelta, SECTION_TOTAL_PLACEHOLDER, diffColor or NS.Colors.white)
    else
        SetSummaryText(UI.totalDelta, Util.FormatDelta(diffTotal), diffColor or NS.Colors.white)
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
UI.SetTotalSummaryText = SetSummaryText
NS.SetTotals = SetTotals
