local _, NS = ...

NS.Settings = NS.Settings or {}

local Widgets = NS.Settings.Widgets
local DropDown = NS.UI.Templates.DropDown

function NS.CreateSettingsPanel()
    if _G.SpeedSplitsOptionsPanel then
        return _G.SpeedSplitsOptionsPanel
    end

    local panel = CreateFrame("Frame", "SpeedSplitsOptionsPanel", UIParent)
    panel.name = "SpeedSplits"
    panel._buttons = panel._buttons or {}

    local themesHeader = Widgets.Header(panel, "Themes & Colors")
    themesHeader:SetPoint("TOPLEFT", 16, -16)

    local colors = {
        { "Personal Best", "gold" },
        { "On Pace",       "deepGreen",  "paceThreshold1" },
        { "Behind Pace",   "lightGreen", "paceThreshold2" },
        { "Slow",          "darkRed" },
        { "UI Accents",    "turquoise" },
        { "Text",          "white" },
    }

    local lastColorElem = themesHeader
    local bottomThemeAnchor
    for i, color in ipairs(colors) do
        local cp = Widgets.ColorPicker(panel, color[1], color[2])
        cp:SetPoint("TOPLEFT", themesHeader, "BOTTOMLEFT", 8, -6 - (i - 1) * 26)

        if color[3] then
            local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            eb:SetSize(45, 22)
            eb:SetPoint("LEFT", cp, "RIGHT", 160, 0)
            eb:SetAutoFocus(false)
            eb:SetNumeric(true)
            eb:SetFontObject("GameFontHighlightSmall")

            local bg = eb:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0.5)

            local currentVal = NS.DB.Settings[color[3]]
            if currentVal == nil then
                currentVal = (color[3] == "paceThreshold1" and 4 or 12)
                NS.DB.Settings[color[3]] = currentVal
            end
            eb:SetText(tostring(currentVal))
            eb:SetTextColor(1, 1, 1, 1)
            eb:SetCursorPosition(0)

            local function SaveValue(self)
                local val = tonumber(self:GetText()) or 0
                NS.DB.Settings[color[3]] = val
                NS.RefreshAllUI()
            end

            eb:SetScript("OnEnterPressed", function(self)
                SaveValue(self)
                self:ClearFocus()
            end)
            eb:SetScript("OnEditFocusLost", SaveValue)
            eb:SetScript("OnEscapePressed", function(self)
                self:SetText(tostring(NS.DB.Settings[color[3]] or (color[3] == "paceThreshold1" and 4 or 12)))
                self:ClearFocus()
            end)

            local lab = eb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            lab:SetPoint("RIGHT", eb, "LEFT", -5, 0)
            lab:SetText("Cut-off:")
            local suf = eb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            suf:SetPoint("LEFT", eb, "RIGHT", 5, 0)
            suf:SetText("seconds")

            table.insert(Widgets.Registry, function()
                eb:SetText(tostring(NS.DB.Settings[color[3]] or (color[3] == "paceThreshold1" and 4 or 12)))
            end)
        end
        lastColorElem = cp
        bottomThemeAnchor = cp
    end

    local npcModelsCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    npcModelsCB.Text:SetText("Show NPC View Models (BETA)")
    npcModelsCB.Text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    if bottomThemeAnchor then
        npcModelsCB:SetPoint("TOPLEFT", bottomThemeAnchor, "BOTTOMLEFT", -4, -10)
    else
        npcModelsCB:SetPoint("TOPLEFT", themesHeader, "BOTTOMLEFT", 8, -90)
    end
    npcModelsCB:SetChecked(NS.DB.Settings.showNPCViewModels ~= false)
    npcModelsCB:SetScript("OnClick", function(self)
        NS.DB.Settings.showNPCViewModels = self:GetChecked() and true or false
        if NS.UI and NS.UI.ApplyTableLayout then
            NS.UI.ApplyTableLayout()
        end
        if NS.RefreshAllUI then
            NS.RefreshAllUI()
        end
    end)

    table.insert(Widgets.Registry, function()
        npcModelsCB:SetChecked(NS.DB.Settings.showNPCViewModels ~= false)
    end)

    local textureHeader = Widgets.Header(panel, "Header Texture")
    textureHeader:SetPoint("TOPLEFT", npcModelsCB, "BOTTOMLEFT", 0, -12)

    local texButtons = {}
    for i, name in ipairs(NS.TitleTextures) do
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(60, 30)
        btn:SetPoint("TOPLEFT", textureHeader, "BOTTOMLEFT", 4 + ((i - 1) % 4) * 65, -10 - math.floor((i - 1) / 4) * 35)
        local t = btn:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        if name:find("[\\/]") then
            t:SetTexture(name)
            t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        else
            t:SetAtlas(name)
        end
        local b = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        b:SetAllPoints()
        b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropBorderColor(1, 1, 0)
        btn.border = b
        b:SetShown(name == NS.DB.Settings.titleTexture)
        btn:SetScript("OnClick", function()
            NS.DB.Settings.titleTexture = name
            for _, x in ipairs(texButtons) do
                x.border:SetShown(x.texName == name)
            end
            NS.RefreshAllUI()
        end)
        btn.texName = name
        table.insert(texButtons, btn)
    end

    local toastHeader = Widgets.Header(panel, "PB Reward Toast")
    toastHeader:SetPoint("TOPLEFT", textureHeader, "BOTTOMLEFT", 0, -95)

    local rewardRow = CreateFrame("Frame", nil, panel)
    rewardRow:SetPoint("TOPLEFT", toastHeader, "BOTTOMLEFT", 0, -10)
    rewardRow:SetSize(300, 110)

    local cb = CreateFrame("CheckButton", nil, rewardRow, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText("Enable Toast Effect")
    cb.Text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    cb:SetChecked(NS.DB.Settings.showTimerToast)
    cb:SetPoint("TOPLEFT", rewardRow, "TOPLEFT", 8, -4)
    cb:SetScript("OnClick", function(self)
        NS.DB.Settings.showTimerToast = self:GetChecked()
        NS.RefreshAllUI()
    end)

    local cbAll = CreateFrame("CheckButton", nil, rewardRow, "InterfaceOptionsCheckButtonTemplate")
    cbAll.Text:SetText("Toast All Boss Kills")
    cbAll.Text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    cbAll:SetChecked(NS.DB.Settings.toastAllBosses)
    cbAll:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
    cbAll:SetScript("OnClick", function(self)
        NS.DB.Settings.toastAllBosses = self:GetChecked()
        NS.RefreshAllUI()
    end)

    table.insert(Widgets.Registry, function()
        cb:SetChecked(NS.DB.Settings.showTimerToast)
        cbAll:SetChecked(NS.DB.Settings.toastAllBosses)
    end)

    local testBtn = CreateFrame("Button", nil, rewardRow, "UIPanelButtonTemplate")
    testBtn:SetSize(110, 24)
    testBtn:SetPoint("TOPLEFT", cbAll, "BOTTOMLEFT", 4, -12)
    testBtn:SetText("Test Toast")
    testBtn:SetScript("OnClick", function()
        if NS.TestPBToast then
            NS.TestPBToast()
        end
    end)

    local soundLabel = rewardRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", rewardRow, "TOPLEFT", 150, 0)
    soundLabel:SetText("PB Toast Sound")
    soundLabel:SetTextColor(0.4, 0.8, 1)

    local soundDD = CreateFrame("Frame", nil, rewardRow, "UIDropDownMenuTemplate")
    soundDD:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -15, -4)
    UIDropDownMenu_SetWidth(soundDD, 130)
    soundDD:SetScale(0.85)

    local function GetSoundNameByID(id)
        for _, info in ipairs(NS.SoundOptions or {}) do
            if info.id == id then
                return info.name
            end
        end
    end

    local function UpdateSoundDD()
        local id = NS.DB.Settings.toastSoundID or 0
        local name = GetSoundNameByID(id) or NS.DB.Settings.toastSoundName or "None"
        NS.DB.Settings.toastSoundName = name
        DropDown.SetSelection(soundDD, id, name)
    end

    table.insert(Widgets.Registry, UpdateSoundDD)

    UIDropDownMenu_Initialize(soundDD, function()
        local current = NS.DB.Settings.toastSoundID or 0
        for _, info in ipairs(NS.SoundOptions or {}) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = info.name
            item.value = info.id
            item.func = function(self)
                local id = self.value or 0
                local name = (self.GetText and self:GetText()) or self.text or GetSoundNameByID(id) or "None"
                NS.DB.Settings.toastSoundID = id
                NS.DB.Settings.toastSoundName = name
                UpdateSoundDD()
                if id > 0 then
                    local played = PlaySound(id, "SFX")
                    if not played then
                        PlaySoundFile(id, "SFX")
                    end
                end
            end
            item.checked = (info.id == current)
            UIDropDownMenu_AddButton(item)
        end
    end)
    UpdateSoundDD()

    local scaleLabel = rewardRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", soundDD, "BOTTOMLEFT", 15, -4)
    scaleLabel:SetText("Toast Scale")
    scaleLabel:SetTextColor(0.4, 0.8, 1)

    local toastScaleSlider = Widgets.CreateSlider(rewardRow, "Scale", 0.5, 3.0, "settings", "timerToastScale", 130,
        function()
            if NS.UpdateToastLayout then
                NS.UpdateToastLayout()
            end
        end)
    toastScaleSlider:SetScale(0.85)
    toastScaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -18)

    local texLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    texLabel:SetPoint("TOPLEFT", rewardRow, "BOTTOMLEFT", 0, -10)
    texLabel:SetText("Toast Textures")
    texLabel:SetTextColor(0.4, 0.8, 1)

    local texFrame = CreateFrame("Frame", nil, panel)
    texFrame:SetPoint("TOPLEFT", texLabel, "BOTTOMLEFT", 0, -8)
    texFrame:SetSize(280, 1)

    local toastBtns = {}
    local toastLabels = { "PB", "On Pace", "Behind Pace", "Slow" }
    for index, name in ipairs(NS.TimerToastTextures or {}) do
        local btn = CreateFrame("Button", nil, texFrame, "BackdropTemplate")
        btn:SetSize(70, 40)
        local col = (index - 1) % 4
        local rowIndex = math.floor((index - 1) / 4)
        btn:SetPoint("TOPLEFT", texFrame, "TOPLEFT", col * 75, -rowIndex * 45)

        local t = btn:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        if name:find("[\\/]") then
            t:SetTexture(name)
        else
            t:SetAtlas(name)
        end

        local b = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        b:SetAllPoints()
        b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropBorderColor(1, 1, 0)
        btn.border = b
        b:Hide()
        btn.texName = name
        table.insert(toastBtns, btn)

        local tl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tl:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        tl:SetText(toastLabels[index] or "")
        tl:SetScale(0.8)

        btn:SetScript("OnClick", function()
            for _, x in ipairs(toastBtns) do
                x.border:Hide()
            end
            btn.border:Show()
            if NS.TestPBToast then
                NS.TestPBToast(name)
            end
        end)
    end

    local fontsHeader = Widgets.Header(panel, "Visual Scaling & Fonts")
    fontsHeader:SetPoint("TOPLEFT", 340, -16)

    local bossRow = Widgets.VisualScalingSection(panel, "Boss Names", "boss")
    bossRow:SetPoint("TOPLEFT", fontsHeader, "BOTTOMLEFT", 10, -10)
    local numRow = Widgets.VisualScalingSection(panel, "Splits / Numbers", "num")
    numRow:SetPoint("TOPLEFT", bossRow, "BOTTOMLEFT", 0, -5)
    local headerRow = Widgets.VisualScalingSection(panel, "Counter / Headers", "header")
    headerRow:SetPoint("TOPLEFT", numRow, "BOTTOMLEFT", 0, -5)
    local timerRow = Widgets.VisualScalingSection(panel, "Main Timer", "timer")
    timerRow:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -5)

    local visibilityHeader = Widgets.Header(panel, "UI Visibility")
    visibilityHeader:SetPoint("TOPLEFT", timerRow, "BOTTOMLEFT", -10, -15)
    local vTimer = Widgets.VisibilityRow(panel, "Timer Frame", "timer")
    vTimer:SetPoint("TOPLEFT", visibilityHeader, "BOTTOMLEFT", 10, -10)
    local vSplits = Widgets.VisibilityRow(panel, "Splits Table", "splits")
    vSplits:SetPoint("TOPLEFT", vTimer, "BOTTOMLEFT", 0, -5)

    local speedrunOpts = {
        { name = "All-bosses", value = "all" },
        { name = "Last Boss",  value = "last" },
    }
    local vMode = Widgets.SettingsDropDown(panel, "Speedrun Mode", "speedrunMode", speedrunOpts)
    vMode:SetPoint("TOPLEFT", vSplits, "BOTTOMLEFT", 0, -5)

    local managementHeader = Widgets.Header(panel, "Management")
    managementHeader:SetPoint("TOPLEFT", vMode, "BOTTOMLEFT", -10, -12)

    local function Q(label, func)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(140, 26)
        btn:SetText(label)
        btn:SetScript("OnClick", func)
        return btn
    end

    local defBtn = Q("Save Current Styles", function()
        NS.DB.DefaultStyle = {
            colors = Widgets.CopyTable(NS.DB.Settings.colors),
            fonts = Widgets.CopyTable(NS.DB.Settings.fonts),
            titleTexture = NS.DB.Settings.titleTexture,
            timerToastScale = NS.DB.Settings.timerToastScale,
            showTimerToast = NS.DB.Settings.showTimerToast,
            toastAllBosses = NS.DB.Settings.toastAllBosses,
            toastSoundID = NS.DB.Settings.toastSoundID,
            toastSoundName = NS.DB.Settings.toastSoundName,
            toastVolume = NS.DB.Settings.toastVolume,
            paceThreshold1 = NS.DB.Settings.paceThreshold1,
            paceThreshold2 = NS.DB.Settings.paceThreshold2,
            showNPCViewModels = NS.DB.Settings.showNPCViewModels,
            visibility = Widgets.CopyTable(NS.DB.Settings.visibility),
        }
        if NS.Print then
            NS.Print("Current styles saved.")
        end
    end)
    defBtn:SetPoint("TOPLEFT", managementHeader, "BOTTOMLEFT", 10, -10)

    local resetBtn = Q("Restore Styles", function()
        if NS.DB.DefaultStyle then
            local d = NS.DB.DefaultStyle
            NS.DB.Settings.colors = Widgets.CopyTable(d.colors)
            NS.DB.Settings.fonts = Widgets.CopyTable(d.fonts)
            NS.DB.Settings.titleTexture = d.titleTexture
            NS.DB.Settings.timerToastScale = d.timerToastScale
            NS.DB.Settings.showTimerToast = d.showTimerToast
            NS.DB.Settings.toastAllBosses = d.toastAllBosses
            NS.DB.Settings.toastSoundID = d.toastSoundID
            NS.DB.Settings.toastSoundName = d.toastSoundName
            NS.DB.Settings.toastVolume = d.toastVolume or 0.8
            NS.DB.Settings.paceThreshold1 = d.paceThreshold1
            NS.DB.Settings.paceThreshold2 = d.paceThreshold2
            if d.showNPCViewModels == nil then
                NS.DB.Settings.showNPCViewModels = true
            else
                NS.DB.Settings.showNPCViewModels = d.showNPCViewModels
            end
            NS.DB.Settings.visibility = Widgets.CopyTable(d.visibility or {})
            NS.UpdateColorsFromSettings()
            for _, refresh in ipairs(Widgets.Registry) do
                refresh()
            end
            NS.RefreshAllUI()
            if NS.Print then
                NS.Print("Styles reset to defaults.")
            end
        end
    end)
    resetBtn:SetPoint("LEFT", defBtn, "RIGHT", 15, 0)

    local layoutBtn = Q("Save Current Layout", function()
        if NS.SaveDefaultLayout then
            NS.SaveDefaultLayout()
        end
        if NS.Print then
            NS.Print("Current layout saved.")
        end
    end)
    layoutBtn:SetPoint("TOPLEFT", defBtn, "BOTTOMLEFT", 0, -6)
    panel._buttons.saveDefaultLayout = layoutBtn

    local resetLayoutBtn = Q("Restore Layout", function()
        if NS.ResetLayout then
            NS.ResetLayout()
        end
    end)
    resetLayoutBtn:SetPoint("LEFT", layoutBtn, "RIGHT", 15, 0)
    panel._buttons.resetLayout = resetLayoutBtn

    local wipeBtn = Q("Wipe All Records", function()
        if NS.UI and NS.UI.Popups and NS.UI.Popups.ShowWipeConfirm then
            NS.UI.Popups.ShowWipeConfirm()
        end
    end)
    wipeBtn:SetSize(295, 26)
    wipeBtn:SetPoint("TOPLEFT", layoutBtn, "BOTTOMLEFT", 0, -6)
    panel._buttons.wipeAllRecords = wipeBtn

    local factoryBtn = Q("Reset to Factory Settings", function()
        if NS.UI and NS.UI.Popups and NS.UI.Popups.ShowFactoryReset then
            NS.UI.Popups.ShowFactoryReset()
        end
    end)
    factoryBtn:SetSize(295, 26)
    factoryBtn:SetPoint("TOPLEFT", wipeBtn, "BOTTOMLEFT", 0, -6)
    panel._buttons.resetFactory = factoryBtn

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        NS.SettingsCategoryID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

function NS.OpenSettings()
    if Settings and Settings.OpenToCategory then
        if NS.SettingsCategoryID then
            Settings.OpenToCategory(NS.SettingsCategoryID)
        else
            Settings.OpenToCategory("SpeedSplits")
        end
    else
        InterfaceOptionsFrame_OpenToCategory("SpeedSplits")
    end
end

NS.CreateOptionsPanel = NS.CreateSettingsPanel
NS.OpenOptions = NS.OpenSettings
