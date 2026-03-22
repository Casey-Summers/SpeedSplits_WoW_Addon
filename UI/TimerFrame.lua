local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Colors = NS.Colors

local function IsTimerWarningActive()
    return UI.timerWarningText and UI.timerWarningText:IsShown() or false
end

local function ClearTimerWarning()
    if not UI.timerWarningText then
        return
    end

    UI.timerWarningText:SetText("")
    UI.timerWarningText:Hide()

    if UI.timerTextMin then UI.timerTextMin:Show() end
    if UI.timerTextSec then UI.timerTextSec:Show() end
    if UI.timerTextMs then UI.timerTextMs:Show() end
    if UI.timerDeltaText then UI.timerDeltaText:Show() end
end

local function SetTimerWarning(message)
    if not UI.timerWarningText then
        return
    end

    local timerFont = NS.DB and NS.DB.Settings and NS.DB.Settings.fonts and NS.DB.Settings.fonts.timer
    local fontPath = timerFont and timerFont.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = math.max(10, math.floor((timerFont and timerFont.size or 24) * 0.52))
    local fontFlags = timerFont and timerFont.flags or "OUTLINE"
    UI.timerWarningText:SetFont(fontPath, fontSize, fontFlags)
    UI.timerWarningText:SetTextColor(Colors.deepGreen.r, Colors.deepGreen.g, Colors.deepGreen.b, 1)
    UI.timerWarningText:SetText(message or "")
    UI.timerWarningText:Show()

    if UI.timerTextMin then UI.timerTextMin:Hide() end
    if UI.timerTextSec then UI.timerTextSec:Hide() end
    if UI.timerTextMs then UI.timerTextMs:Hide() end
    if UI.timerDeltaText then UI.timerDeltaText:Hide() end
end

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

    ClearTimerWarning()

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

local function SetTimerDelta(delta, colorState)
    if not UI.timerDeltaText then
        return
    end
    if IsTimerWarningActive() then
        return
    end
    if delta == nil then
        UI.timerDeltaText:SetText("")
        if UI.timerToastBg then
            UI.timerToastBg:SetAlpha(0)
        end
        return
    end

    local hex = (colorState and colorState.hex) or NS.Run.lastColorHex or Colors.white.hex
    UI.timerDeltaText:SetText(hex .. Util.FormatDelta(delta) .. "|r")
    UI.timerDeltaText:SetTextColor(1, 1, 1, 1)

    if UI.timerToastBg then
        local tex = NS.GetPaceToastTexture(delta, false)
        Util.ApplyBackgroundTexture(UI.timerToastBg, tex)
    end
end

UI.UpdateTimerFrameBounds = UpdateTimerFrameBounds
UI.SetTimerText = SetTimerText
UI.SetTimerDelta = SetTimerDelta
UI.SetTimerWarning = SetTimerWarning
UI.ClearTimerWarning = ClearTimerWarning
UI.IsTimerWarningActive = IsTimerWarningActive
