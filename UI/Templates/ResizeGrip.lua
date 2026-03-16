local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local ResizeGrip = {}
NS.UI.Templates.ResizeGrip = ResizeGrip

function ResizeGrip.CreateFrameGrip(ownerFrame, onChanged)
    local grip = CreateFrame("Button", nil, ownerFrame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", ownerFrame, "BOTTOMRIGHT", -2, 2)
    grip:EnableMouse(true)

    local tex = grip:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip._tex = tex

    grip:SetScript("OnEnter", function(self)
        self._tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    grip:SetScript("OnLeave", function(self)
        self._tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        ownerFrame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        ownerFrame:StopMovingOrSizing()
        if onChanged then
            onChanged()
        end
    end)

    return grip
end

function ResizeGrip.CreateColumnGrip(parent, width, height, onStart, onUpdate, onStop, onEnter, onLeave)
    local grip = CreateFrame("Button", nil, parent)
    grip:SetSize(width or 10, height or 14)
    grip:EnableMouse(true)
    grip:RegisterForClicks("AnyUp", "AnyDown")

    if onEnter then
        grip:SetScript("OnEnter", onEnter)
    end
    if onLeave then
        grip:SetScript("OnLeave", onLeave)
    end

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        if onStart then
            onStart(self)
        end
        if onUpdate then
            self:SetScript("OnUpdate", onUpdate)
        end
    end)

    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        if onStop then
            onStop(self)
        end
    end)

    return grip
end
