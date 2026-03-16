local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Colors = NS.Colors

local function UpdateTimerFrameBounds()
    if not UI.timerFrame or not UI.timerTextSec then
        return
    end

    local oldMin = UI.timerTextMin:GetText()
    local oldSec = UI.timerTextSec:GetText()
    local oldMs = UI.timerTextMs:GetText()

    UI.timerTextMin:SetText("00:")
    UI.timerTextSec:SetText("00")
    UI.timerTextMs:SetText(".000")

    local wL = UI.timerTextMin:GetStringWidth() + UI.timerTextSec:GetStringWidth()
    local wR = UI.timerTextMs:GetStringWidth()
    UI._timerPivotOffset = (wL - wR) / 2
    UI.timerTextSec:ClearAllPoints()
    UI.timerTextSec:SetPoint("RIGHT", UI.timerFrame, "CENTER", 0, 0)
    UI.timerTextSec:SetWidth(0)

    local totalW = wL + wR
    local height = UI.timerTextSec:GetStringHeight()
    local minW = math.ceil(totalW + 80)
    local minH = math.ceil(height + 48)

    Util.ApplyResizeBounds(UI.timerFrame, minW, minH, 900, 300)

    UI.timerTextMin:SetText(oldMin)
    UI.timerTextSec:SetText(oldSec)
    UI.timerTextMs:SetText(oldMs)
end

local function SetTimerText(seconds, finished)
    if not UI.timerTextMin or not UI.timerTextSec or not UI.timerTextMs then
        return
    end

    local full = Util.FormatTime(seconds)
    local min, sec, ms = "", "", ""
    if full:find(":") then
        min, sec, ms = full:match("^(.*:)(%d%d)(%.%d+)$")
    else
        sec, ms = full:match("^(%d+)(%.%d+)$")
        min = ""
    end
    if not sec then
        min, sec, ms = full, "", ""
    end

    UI.timerTextMin:SetText(min)
    UI.timerTextSec:SetText(sec)
    UI.timerTextMs:SetText(ms)

    local color = Colors.white
    if finished then
        if NS.Run.lastColorR then
            color = { r = NS.Run.lastColorR, g = NS.Run.lastColorG, b = NS.Run.lastColorB, a = 1 }
        else
            color = Colors.deepGreen
        end
    end

    UI.timerTextMin:SetTextColor(color.r, color.g, color.b, color.a or 1)
    UI.timerTextSec:SetTextColor(color.r, color.g, color.b, color.a or 1)
    UI.timerTextMs:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

local function SetTimerDelta(delta, isPB)
    if not UI.timerDeltaText then
        return
    end
    if delta == nil then
        UI.timerDeltaText:SetText("")
        if UI.timerToastBg then
            UI.timerToastBg:SetAlpha(0)
        end
        return
    end

    local hex = NS.Run.lastColorHex or Colors.white.hex
    UI.timerDeltaText:SetText(hex .. Util.FormatDelta(delta) .. "|r")
    UI.timerDeltaText:SetTextColor(1, 1, 1, 1)

    if UI.timerToastBg then
        local tex = NS.GetPaceToastTexture(delta, isPB)
        Util.ApplyBackgroundTexture(UI.timerToastBg, tex)
    end
end

UI.UpdateTimerFrameBounds = UpdateTimerFrameBounds
UI.SetTimerText = SetTimerText
UI.SetTimerDelta = SetTimerDelta
