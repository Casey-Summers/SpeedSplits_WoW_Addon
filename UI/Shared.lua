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

local function GetDecimalAlignedParts(value)
    value = tostring(value or "")
    if value == "" then
        return "", "", ""
    end

    local decimalIndex = string.find(value, "%.")
    if not decimalIndex then
        return value, "", ""
    end

    return string.sub(value, 1, decimalIndex - 1), ".", string.sub(value, decimalIndex + 1)
end

function UI.EnsureDecimalAlignedText(host, key)
    if not host then
        return nil
    end

    host._ssDecimalText = host._ssDecimalText or {}
    local entry = host._ssDecimalText[key]
    if entry then
        return entry
    end

    local prefix = host:CreateFontString(nil, "OVERLAY")
    prefix:SetJustifyH("RIGHT")
    prefix:SetJustifyV("MIDDLE")
    prefix:SetWordWrap(false)

    local decimal = host:CreateFontString(nil, "OVERLAY")
    decimal:SetJustifyH("CENTER")
    decimal:SetJustifyV("MIDDLE")
    decimal:SetWordWrap(false)

    local suffix = host:CreateFontString(nil, "OVERLAY")
    suffix:SetJustifyH("LEFT")
    suffix:SetJustifyV("MIDDLE")
    suffix:SetWordWrap(false)

    entry = {
        prefix = prefix,
        decimal = decimal,
        suffix = suffix,
        pivotX = 0,
        boundsLeft = 0,
        boundsRight = 0,
    }
    host._ssDecimalText[key] = entry
    return entry
end

function UI.HideDecimalAlignedText(host, key)
    local entry = host and host._ssDecimalText and host._ssDecimalText[key]
    if not entry then
        return
    end

    entry.prefix:SetText("")
    entry.decimal:SetText("")
    entry.suffix:SetText("")
    entry.prefix:Hide()
    entry.decimal:Hide()
    entry.suffix:Hide()
end

function UI.SetDecimalAlignedText(host, key, value, fontType, color, pivotX, boundsLeft, boundsRight)
    local entry = UI.EnsureDecimalAlignedText(host, key)
    if not entry then
        return nil
    end

    local prefixText, decimalText, suffixText = GetDecimalAlignedParts(value)
    local left = tonumber(boundsLeft) or 0
    local right = tonumber(boundsRight) or 0
    local pivot = tonumber(pivotX) or 0

    entry.pivotX = pivot
    entry.boundsLeft = left
    entry.boundsRight = right

    local prefix = entry.prefix
    local decimal = entry.decimal
    local suffix = entry.suffix

    NS.ApplyFontToFS(prefix, fontType)
    NS.ApplyFontToFS(decimal, fontType)
    NS.ApplyFontToFS(suffix, fontType)

    local active = color or Colors.white
    prefix:SetTextColor(active.r or 1, active.g or 1, active.b or 1, active.a or 1)
    decimal:SetTextColor(active.r or 1, active.g or 1, active.b or 1, active.a or 1)
    suffix:SetTextColor(active.r or 1, active.g or 1, active.b or 1, active.a or 1)

    decimal:ClearAllPoints()
    decimal:SetPoint("CENTER", host, "LEFT", pivot, 0)
    decimal:SetText(decimalText or "")

    prefix:ClearAllPoints()
    prefix:SetPoint("TOPLEFT", host, "TOPLEFT", left, -1)
    if decimalText ~= "" then
        prefix:SetPoint("BOTTOMRIGHT", decimal, "BOTTOMLEFT", 0, 0)
    else
        prefix:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, 1)
    end
    prefix:SetText(prefixText or "")

    suffix:ClearAllPoints()
    if decimalText ~= "" then
        suffix:SetPoint("TOPLEFT", decimal, "TOPRIGHT", 0, 0)
    else
        suffix:SetPoint("TOPLEFT", host, "TOPLEFT", pivot, -1)
    end
    suffix:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, 1)
    suffix:SetText(suffixText or "")

    if prefixText == "" then
        prefix:Hide()
    else
        prefix:Show()
    end

    if decimalText == "" then
        decimal:Hide()
    else
        decimal:Show()
    end

    if suffixText == "" then
        suffix:Hide()
    else
        suffix:Show()
    end

    return entry
end

function UI.GetDecimalAlignedParts(value)
    return GetDecimalAlignedParts(value)
end

function UI.ApplyThinSeparator(grip)
    if grip._line then
        return
    end
    local line = grip:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER", grip, "CENTER", 0, 0)
    line:SetSize(1, NS.Const.SPLITS_LAYOUT.HEADER_H)
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
