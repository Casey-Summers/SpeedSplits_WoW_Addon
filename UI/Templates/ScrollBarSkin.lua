local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local Skin = {}
NS.UI.Templates.ScrollBarSkin = Skin

function Skin.Apply(scrollbar, width)
    if not scrollbar then
        return
    end

    scrollbar:SetWidth(width or 10)

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
        thumb:SetWidth((width or 10) - 2)
    end

    if not scrollbar._ssBackground then
        local bg = scrollbar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
        scrollbar._ssBackground = bg
    end
end
