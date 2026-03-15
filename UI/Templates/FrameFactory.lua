local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local Factory = {}
NS.UI.Templates.FrameFactory = Factory

function Factory.ApplyBorderedBackdrop(frame, edgeSize, bgAlpha, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = edgeSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(0, 0, 0, bgAlpha or 0.4)

    if borderColor then
        frame:SetBackdropBorderColor(borderColor.r or 1, borderColor.g or 1, borderColor.b or 1, borderColor.a or 1)
    end
end

function Factory.CreateBorderedFrame(parent, backdropAlpha, borderColor)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Factory.ApplyBorderedBackdrop(frame, 1, backdropAlpha, borderColor)
    return frame
end

function Factory.CreateHeaderStrip(parent, height, backdropAlpha)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(height)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    Factory.ApplyBorderedBackdrop(frame, 1, backdropAlpha or 0.4)
    return frame
end

function Factory.CreateFooterStrip(parent, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(height)
    frame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0)
    return frame
end

function Factory.CreateOverlayBorder(parent, levelOffset, borderColor)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + (levelOffset or 1))
    frame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:EnableMouse(false)

    if borderColor then
        frame:SetBackdropBorderColor(borderColor.r or 1, borderColor.g or 1, borderColor.b or 1, borderColor.a or 1)
    end

    return frame
end

function Factory.CreateDialogFrame(name, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    return frame
end
