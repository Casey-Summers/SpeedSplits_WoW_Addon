local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Colors = NS.Colors

function NS.ApplyFontToFS(fs, typeKey, multiplier)
    if not fs then
        return
    end

    local fonts = NS.DB and NS.DB.Settings and NS.DB.Settings.fonts
    local fontSettings = (fonts and fonts[typeKey]) or (fonts and fonts.num)

    local fontPath = fontSettings and fontSettings.font or "Fonts\\FRIZQT__.TTF"
    local fontSize = fontSettings and fontSettings.size or 12
    local fontFlags = fontSettings and fontSettings.flags or "OUTLINE"

    multiplier = multiplier or 1
    local finalSize = math.max(1, math.floor(fontSize * multiplier + 0.5))
    local success = fs:SetFont(fontPath, finalSize, fontFlags)
    if not success then
        fs:SetFont("Fonts\\FRIZQT__.TTF", finalSize, fontFlags)
    end
    if not fs:GetFont() then
        fs:SetFontObject("GameFontHighlight")
    end
end

function UI.ApplyThinSeparator(grip)
    if grip._line then
        return
    end
    local line = grip:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER", grip, "CENTER", 0, 0)
    line:SetSize(1, NS.Const.HEADER_H)
    line:SetColorTexture(1, 1, 1, 0.18)
    grip._line = line
end

function UI.SetHoverBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, alpha or 0.75)
    frame:SetBackdropBorderColor(1, 1, 1, 0.10)
end

function UI.StyleHeaderCell(cell, align, multiplier, text, colorKey)
    if not cell then
        return
    end

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
    if not fs then
        return
    end

    if text then
        fs:SetText(text)
    end
    fs:SetJustifyH(align or "CENTER")
    fs:SetJustifyV("MIDDLE")
    NS.ApplyFontToFS(fs, "header", multiplier)

    local colorName = colorKey or "turquoise"
    local color = (Colors and Colors[colorName]) or { r = 0, g = 0.74, b = 0.76 }
    fs:SetTextColor(color.r, color.g, color.b, 1)
    cell.turquoiseSet = (colorName == "turquoise")
    fs:SetDrawLayer("OVERLAY", 7)
    fs:ClearAllPoints()

    local justify = align or "CENTER"
    if justify == "LEFT" then
        fs:SetPoint("LEFT", cell, "LEFT", 4, 0)
        fs:SetPoint("RIGHT", cell, "RIGHT", -2, 0)
    elseif justify == "RIGHT" then
        fs:SetPoint("LEFT", cell, "LEFT", 2, 0)
        fs:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
    else
        fs:SetPoint("CENTER", cell, "CENTER", 0, 0)
    end
end
