local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local Skin = {}
NS.UI.Templates.ScrollBarSkin = Skin

function Skin.Apply(scrollbar, width)
    if not scrollbar then
        return
    end

    local appliedWidth = width or 10
    local parent = scrollbar:GetParent()
    local trough = scrollbar._ssTrough
    local troughBorder = scrollbar._ssTroughBorder
    scrollbar:SetWidth(appliedWidth)
    scrollbar:ClearAllPoints()
    if parent then
        scrollbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -3, -3)
        scrollbar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 3)
    end

    local up = _G[scrollbar:GetName() .. "ScrollUpButton"]
    local down = _G[scrollbar:GetName() .. "ScrollDownButton"]
    if up then
        up:Hide()
    end
    if down then
        down:Hide()
    end

    local thumb = scrollbar:GetThumbTexture()
    if thumb then
        thumb:SetColorTexture(0.4, 0.4, 0.4, 0.8)
        thumb:SetWidth(appliedWidth - 2)
    end

    if not scrollbar._ssBackground then
        local bg = scrollbar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
        scrollbar._ssBackground = bg
    end

    if trough then
        trough:ClearAllPoints()
        trough:SetWidth(appliedWidth)
        if parent then
            trough:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -3, -3)
            trough:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 3)
        end
    end

    if troughBorder and trough then
        troughBorder:ClearAllPoints()
        troughBorder:SetPoint("TOPRIGHT", trough, "TOPLEFT", 0, 0)
        troughBorder:SetPoint("BOTTOMRIGHT", trough, "BOTTOMLEFT", 0, 0)
    end
end
