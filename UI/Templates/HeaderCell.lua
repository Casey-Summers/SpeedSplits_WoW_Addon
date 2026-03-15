local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local HeaderCell = {}
NS.UI.Templates.HeaderCell = HeaderCell

function HeaderCell.Create(parent, text, align, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(24)

    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(text or "")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    button:SetFontString(fs)

    if NS.UI.StyleHeaderCell then
        NS.UI.StyleHeaderCell(button, align or "CENTER")
    end

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button
end
