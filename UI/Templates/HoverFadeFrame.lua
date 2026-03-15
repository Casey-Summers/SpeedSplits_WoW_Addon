local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local HoverFadeFrame = {}
NS.UI.Templates.HoverFadeFrame = HoverFadeFrame

function HoverFadeFrame.Attach(frame, alpha, onAlphaChanged)
    local fadeTarget = 0
    local fadeCurrent = 0
    local fadeSpeed = 5

    frame:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then
            fadeTarget = 1
        else
            fadeTarget = 0
        end

        if math.abs(fadeCurrent - fadeTarget) > 0.01 then
            local dir = (fadeTarget > fadeCurrent) and 1 or -1
            fadeCurrent = NS.Util.Clamp(fadeCurrent + (dir * fadeSpeed * elapsed), 0, 1)
            self:SetBackdropColor(0, 0, 0, (alpha or 0.60) * fadeCurrent)
            self:SetBackdropBorderColor(1, 1, 1, 0.10 * fadeCurrent)
            if onAlphaChanged then
                onAlphaChanged(fadeCurrent)
            end
        end
    end)
end
