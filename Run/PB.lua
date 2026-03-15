local _, NS = ...

local Util = NS.Util
local Colors = NS.Colors

local function UpdateColorsFromSettings()
    if not NS.DB or not NS.DB.Settings or not NS.DB.Settings.colors then
        return
    end
    for key, hex in pairs(NS.DB.Settings.colors) do
        local newColor = Util.HexToColor(hex)
        if NS.Colors[key] then
            local color = NS.Colors[key]
            color.r, color.g, color.b, color.a = newColor.r, newColor.g, newColor.b, newColor.a
            color.argb, color.hex = newColor.argb, newColor.hex
        else
            NS.Colors[key] = newColor
        end
    end
end

local function GetPaceToastTexture(delta, isPB)
    if isPB then
        return NS.TimerToastTextures[1]
    end
    if delta == nil or delta < 0 then
        return NS.TimerToastTextures[2]
    end
    local t1 = (NS.DB and NS.DB.Settings and NS.DB.Settings.paceThreshold1) or 4
    local t2 = (NS.DB and NS.DB.Settings and NS.DB.Settings.paceThreshold2) or 12
    if delta <= t1 then
        return NS.TimerToastTextures[2]
    elseif delta <= t2 then
        return NS.TimerToastTextures[3]
    end
    return NS.TimerToastTextures[4]
end

local function GetPaceColor(delta, isPB)
    if delta == nil then
        return 1, 1, 1, "|cffffffff"
    end
    if isPB or math.abs(delta) < 0.001 then
        return Colors.gold.r, Colors.gold.g, Colors.gold.b, Colors.gold.hex
    end
    if delta < 0 then
        return Colors.deepGreen.r, Colors.deepGreen.g, Colors.deepGreen.b, Colors.deepGreen.hex
    end

    local t1 = (NS.DB and NS.DB.Settings and NS.DB.Settings.paceThreshold1) or 4
    local t2 = (NS.DB and NS.DB.Settings and NS.DB.Settings.paceThreshold2) or 12

    if delta <= t1 then
        return Util.InterpolateColor(Colors.deepGreen, Colors.lightGreen, delta / t1)
    elseif delta <= t2 then
        return Util.InterpolateColor(Colors.lightGreen, Colors.darkRed, (delta - t1) / (t2 - t1))
    end
    return Colors.darkRed.r, Colors.darkRed.g, Colors.darkRed.b, Colors.darkRed.hex
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

local function UpdateBestRunIfNeeded(durationSeconds)
    local node = NS.GetBestSplitsSubtable and NS.GetBestSplitsSubtable()
    if not node then
        return
    end

    local existing = node.FullRun
    if not existing or not existing.duration or durationSeconds < existing.duration then
        node.FullRun = {
            duration = durationSeconds,
            endedAt = NS.Run.endedAt,
            instanceName = NS.Run.instanceName,
            tier = NS.Run.tier,
            difficultyID = NS.Run.difficultyID,
            difficultyName = NS.Run.difficultyName,
            mapID = NS.Run.mapID,
        }
    end
end

NS.UpdateColorsFromSettings = UpdateColorsFromSettings
NS.GetPaceToastTexture = GetPaceToastTexture
NS.GetPaceColor = GetPaceColor
NS.RunLogic.ComputeSumOfBest = ComputeSumOfBest
NS.RunLogic.UpdateBestRunIfNeeded = UpdateBestRunIfNeeded
