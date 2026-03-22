local _, NS = ...

local UI = NS.UI
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

local function GetAlignedTimeGroupStore(host)
    if not host then
        return nil
    end

    host._ssAlignedTimeGroups = host._ssAlignedTimeGroups or {}
    host._ssNumericCellParts = host._ssAlignedTimeGroups
    host._ssDecimalText = host._ssAlignedTimeGroups
    return host._ssAlignedTimeGroups
end

local function SetPartColor(entry, color)
    local active = color or Colors.white
    local r = active.r or 1
    local g = active.g or 1
    local b = active.b or 1
    local a = active.a or 1

    entry.sign:SetTextColor(r, g, b, a)
    entry.minute:SetTextColor(r, g, b, a)
    entry.colon:SetTextColor(r, g, b, a)
    entry.second:SetTextColor(r, g, b, a)
    entry.decimal:SetTextColor(r, g, b, a)
    entry.millis:SetTextColor(r, g, b, a)
end

local function ClearAlignedTimeGroup(entry)
    entry.sign:SetText("")
    entry.minute:SetText("")
    entry.colon:SetText("")
    entry.second:SetText("")
    entry.decimal:SetText("")
    entry.millis:SetText("")
    entry.sign:Hide()
    entry.minute:Hide()
    entry.colon:Hide()
    entry.second:Hide()
    entry.decimal:Hide()
    entry.millis:Hide()
end

local function ApplyAlignedTimeAnchors(host, entry)
    if not host or not entry then
        return
    end

    local spec = entry.layoutSpec or {}
    local signWidth = tonumber(spec.signWidth) or 0
    local minuteRight = tonumber(spec.minuteRight) or 0
    local minuteBaseWidth = tonumber(spec.minuteBaseWidth) or 0
    local overflowWidth = tonumber(entry.minuteOverflowWidth) or 0
    local minuteWidth = minuteBaseWidth + overflowWidth
    local colonLeft = tonumber(spec.colonLeft) or 0
    local colonWidth = tonumber(spec.colonWidth) or 0
    local secondLeft = tonumber(spec.secondLeft) or 0
    local secondWidth = tonumber(spec.secondWidth) or 0
    local decimalLeft = tonumber(spec.decimalLeft) or 0
    local decimalWidth = tonumber(spec.decimalWidth) or 0
    local millisLeft = tonumber(spec.millisLeft) or 0
    local millisWidth = tonumber(spec.millisWidth) or 0
    local groupType = spec.groupType or "time"
    local firstVisibleSection = entry.firstVisibleSection or "second"
    local signPad = tonumber(spec.signPad) or 0
    local minuteLeft = minuteRight - minuteWidth

    entry.sign:ClearAllPoints()
    entry.minute:ClearAllPoints()
    entry.colon:ClearAllPoints()
    entry.second:ClearAllPoints()
    entry.decimal:ClearAllPoints()
    entry.millis:ClearAllPoints()

    if signWidth > 0 then
        entry.sign:SetJustifyH("RIGHT")
        entry.sign:SetWidth(signWidth)
        if groupType == "delta" then
            local signTarget = firstVisibleSection == "minute" and entry.minute or entry.second
            entry.sign:SetPoint("TOPRIGHT", signTarget, "TOPLEFT", -signPad, 0)
            entry.sign:SetPoint("BOTTOMRIGHT", signTarget, "BOTTOMLEFT", -signPad, 0)
        else
            local signLeft = tonumber(spec.signMinuteLeft) or 0
            entry.sign:SetPoint("TOPLEFT", host, "TOPLEFT", signLeft, -1)
            entry.sign:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", signLeft, 1)
        end
    else
        entry.sign:SetWidth(0.1)
    end

    entry.minute:SetJustifyH("RIGHT")
    entry.minute:SetPoint("TOPLEFT", host, "TOPLEFT", minuteLeft, -1)
    entry.minute:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", minuteLeft, 1)
    entry.minute:SetWidth(minuteWidth)

    entry.colon:SetJustifyH("CENTER")
    entry.colon:SetPoint("TOPLEFT", host, "TOPLEFT", colonLeft, -1)
    entry.colon:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", colonLeft, 1)
    entry.colon:SetWidth(colonWidth)

    entry.second:SetJustifyH("RIGHT")
    entry.second:SetPoint("TOPLEFT", host, "TOPLEFT", secondLeft, -1)
    entry.second:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", secondLeft, 1)
    entry.second:SetWidth(secondWidth)

    entry.decimal:SetJustifyH("CENTER")
    entry.decimal:SetPoint("TOPLEFT", host, "TOPLEFT", decimalLeft, -1)
    entry.decimal:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", decimalLeft, 1)
    entry.decimal:SetWidth(decimalWidth)

    entry.millis:SetJustifyH("LEFT")
    entry.millis:SetPoint("TOPLEFT", host, "TOPLEFT", millisLeft, -1)
    entry.millis:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", millisLeft, 1)
    entry.millis:SetWidth(millisWidth)
end

function UI.EnsureAlignedTimeGroup(host, key)
    if not host then
        return nil
    end

    local store = GetAlignedTimeGroupStore(host)
    local entry = store[key]
    if entry then
        return entry
    end

    local sign = host:CreateFontString(nil, "OVERLAY")
    sign:SetJustifyV("MIDDLE")
    sign:SetWordWrap(false)

    local minute = host:CreateFontString(nil, "OVERLAY")
    minute:SetJustifyV("MIDDLE")
    minute:SetWordWrap(false)

    local colon = host:CreateFontString(nil, "OVERLAY")
    colon:SetJustifyV("MIDDLE")
    colon:SetWordWrap(false)

    local second = host:CreateFontString(nil, "OVERLAY")
    second:SetJustifyV("MIDDLE")
    second:SetWordWrap(false)

    local decimal = host:CreateFontString(nil, "OVERLAY")
    decimal:SetJustifyV("MIDDLE")
    decimal:SetWordWrap(false)

    local millis = host:CreateFontString(nil, "OVERLAY")
    millis:SetJustifyV("MIDDLE")
    millis:SetWordWrap(false)

    entry = {
        sign = sign,
        minute = minute,
        colon = colon,
        second = second,
        decimal = decimal,
        millis = millis,
        layoutSpec = nil,
        minuteOverflowWidth = 0,
        firstVisibleSection = "second",
        prefix = minute,
        suffix = millis,
    }
    store[key] = entry
    return entry
end

function UI.HideAlignedTimeGroup(host, key)
    local store = host and host._ssAlignedTimeGroups
    local entry = store and store[key]
    if not entry then
        return
    end
    ClearAlignedTimeGroup(entry)
end

function UI.ApplyAlignedTimeGroupLayout(host, key, spec)
    local entry = UI.EnsureAlignedTimeGroup(host, key)
    if not entry then
        return nil
    end

    entry.layoutSpec = spec or entry.layoutSpec or {}
    ApplyAlignedTimeAnchors(host, entry)
    return entry
end

UI.HideNumericCellParts = UI.HideAlignedTimeGroup
UI.ApplyNumericCellLayout = UI.ApplyAlignedTimeGroupLayout

function UI.SetAlignedTimeGroupValue(host, key, parts, fontType, color)
    local entry = UI.EnsureAlignedTimeGroup(host, key)
    if not entry then
        return nil
    end

    parts = type(parts) == "table" and parts or {}

    NS.ApplyFontToFS(entry.sign, fontType)
    NS.ApplyFontToFS(entry.minute, fontType)
    NS.ApplyFontToFS(entry.colon, fontType)
    NS.ApplyFontToFS(entry.second, fontType)
    NS.ApplyFontToFS(entry.decimal, fontType)
    NS.ApplyFontToFS(entry.millis, fontType)
    SetPartColor(entry, color)

    if parts.showGroup == false then
        entry.minuteOverflowWidth = 0
        ApplyAlignedTimeAnchors(host, entry)
        ClearAlignedTimeGroup(entry)
        return entry
    end

    local spec = entry.layoutSpec or {}
    local extraMinuteDigits = math.max((tonumber(parts.minuteDigits) or 2) - 2, 0)
    entry.minuteOverflowWidth = extraMinuteDigits * (tonumber(spec.digitWidth) or 0)
    entry.firstVisibleSection = parts.firstVisibleSection or (parts.showMinute and "minute" or "second")

    ApplyAlignedTimeAnchors(host, entry)

    entry.sign:SetText(parts.signText or "")
    entry.minute:SetText(parts.minuteText or "")
    entry.colon:SetText(parts.colonText or ":")
    entry.second:SetText(parts.secondText or "")
    entry.decimal:SetText(parts.decimalText or ".")
    entry.millis:SetText(parts.millisText or "")

    if entry.sign:GetText() == "" then
        entry.sign:Hide()
    else
        entry.sign:Show()
    end

    if parts.showMinute and entry.minute:GetText() ~= "" then
        entry.minute:Show()
    else
        entry.minute:Hide()
    end

    if parts.showColon then
        entry.colon:Show()
    else
        entry.colon:Hide()
    end

    if entry.second:GetText() == "" then
        entry.second:Hide()
    else
        entry.second:Show()
    end

    if entry.decimal:GetText() == "" then
        entry.decimal:Hide()
    else
        entry.decimal:Show()
    end

    if entry.millis:GetText() == "" then
        entry.millis:Hide()
    else
        entry.millis:Show()
    end

    return entry
end

UI.SetNumericCellValue = UI.SetAlignedTimeGroupValue

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
