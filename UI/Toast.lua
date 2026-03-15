local _, NS = ...

local UI = NS.UI
local Util = NS.Util

function NS.ShowToast(tex, isNewPB)
    if not UI.timerToastBg or not UI.timerToastAG then
        return
    end

    UI.timerToastAG:Stop()
    if UI.pbShineAG then
        UI.pbShineAG:Stop()
    end

    Util.ApplyBackgroundTexture(UI.timerToastBg, tex)

    if isNewPB then
        if NS.DB and NS.DB.Settings and NS.DB.Settings.toastSoundID and NS.DB.Settings.toastSoundID > 0 then
            PlaySoundFile(NS.DB.Settings.toastSoundID, "SFX")
        end
        if UI.pbShineAG and tex == NS.TimerToastTextures[1] then
            UI.pbShineAG:Play()
        end
    end

    UI.timerToastAG:Play()
end

function NS.TestPBToast(manualTex)
    local tex = manualTex or NS.TimerToastTextures[1]
    NS.ShowToast(tex, tex == NS.TimerToastTextures[1])
end

function NS.UpdateToastLayout()
    if not UI.timerToastBg then
        return
    end
    local scale = (NS.DB and NS.DB.Settings and NS.DB.Settings.timerToastScale) or 1.0
    UI.timerToastBg:ClearAllPoints()
    local parent = UI.timerToastBg:GetParent()
    local w, h = parent:GetSize()
    UI.timerToastBg:SetSize(w * scale, h * scale)
    UI.timerToastBg:SetPoint("CENTER", parent, "CENTER", 0, 0)

    if UI.pbShine then
        UI.pbShine:SetSize(NS.Const.PB_SHINE_WIDTH * scale, NS.Const.PB_SHINE_HEIGHT * scale)
    end
end
