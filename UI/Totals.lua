local _, NS = ...

local UI = NS.UI
local Util = NS.Util

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
            for _, region in ipairs(regions) do
                if region and region.IsObjectType and region:IsObjectType("FontString") then
                    fs = region
                    break
                end
            end
        end
        if fs then
            fs:SetText("")
        end
    end
end

local function SetTotals(pbTotal, splitTotal, deltaTotal, r, g, b)
    if not UI.totalPB or not UI.totalSplit or not UI.totalDelta then
        return
    end

    UI.totalPB:SetText(Util.FormatTime(pbTotal))
    UI.totalPB:SetTextColor(NS.Colors.gold.r, NS.Colors.gold.g, NS.Colors.gold.b, 1)

    if splitTotal then
        UI.totalSplit:SetText(Util.FormatTime(splitTotal))
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
        UI.totalDelta:SetText(Util.FormatDelta(deltaTotal))
        if r and g and b then
            UI.totalDelta:SetTextColor(r, g, b, 1)
        else
            UI.totalDelta:SetTextColor(1, 1, 1, 1)
        end
    end
end

local function RefreshTotals(isFinal)
    local node = NS.GetBestSplitsSubtable and NS.GetBestSplitsSubtable()
    local pbTable = node and node.Segments or nil
    local pbTotal = pbTable and NS.RunLogic.ComputeSumOfBest(pbTable, NS.Run.entries) or nil

    if isFinal then
        local duration = (NS.Run.endGameTime > 0 and NS.Run.startGameTime > 0) and (NS.Run.endGameTime - NS.Run.startGameTime) or nil
        local deltaTotal = (duration and pbTotal) and (duration - pbTotal) or nil

        local existingPB = node and node.FullRun
        local isPB = false
        if duration and duration > 0 then
            isPB = (not existingPB or not existingPB.duration or duration <= (existingPB.duration + 0.001))
        end

        local r, g, b, hex = NS.GetPaceColor(deltaTotal, isPB)
        NS.Run.lastColorR, NS.Run.lastColorG, NS.Run.lastColorB, NS.Run.lastColorHex = r, g, b, hex
        NS.Run.lastIsPB = isPB
        SetTotals(pbTotal, duration, deltaTotal, r, g, b, hex)
        UI.SetTimerDelta(deltaTotal, isPB)
        UI.SetTimerText(duration, true)
        return
    end

    local lastBossKey
    for _, entry in ipairs(NS.Run.entries) do
        if NS.Run.kills[entry.key] then
            lastBossKey = entry.key
        end
    end

    if lastBossKey then
        local r = NS.Run.lastColorR or 1
        local g = NS.Run.lastColorG or 1
        local b = NS.Run.lastColorB or 1
        SetTotals(NS.Run.lastPBTotal, NS.Run.lastSplitCumulative, NS.Run.lastDelta, r, g, b, NS.Run.lastColorHex or "|cffffffff")
        UI.SetTimerDelta(NS.Run.lastDelta, NS.Run.lastIsPB)
    else
        SetTotals(pbTotal, nil, nil)
        UI.SetTimerDelta(nil, false)
    end
end

UI.SetKillCount = SetKillCount
UI.RefreshTotals = RefreshTotals
NS.SetTotals = SetTotals
