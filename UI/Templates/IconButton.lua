local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local IconButton = {}
NS.UI.Templates.IconButton = IconButton

function IconButton.Create(parent, width, height, atlas, tooltipText, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:SetNormalAtlas(atlas)
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    if tooltipText then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button
end
