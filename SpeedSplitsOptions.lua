local ADDON_NAME, NS = ...

local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo

local function SS_CopyTable(src)
    local dest = {}
    for k, v in pairs(src) do
        if type(v) == "table" then dest[k] = SS_CopyTable(v) else dest[k] = v end
    end
    return dest
end

-- Template Library
local T = {}

-- Each section should anchor to the one above it or a column anchor point.
T.Registry = {}

function T.CreateSlider(parent, label, minV, maxV, typeKey, field, width, callback)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(0.05)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(width or 160); s:SetScale(0.9)

    local text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)

    local val = (typeKey == "settings") and NS.DB.Settings[field] or NS.DB.Settings.fonts[typeKey][field]
    s:SetValue(val)
    text:SetText(label .. ": " .. string.format("%.2f", val))

    s:SetScript("OnValueChanged", function(self, value)
        if typeKey == "settings" then
            NS.DB.Settings[field] = value
        else
            NS.DB.Settings.fonts[typeKey][field] = math.floor(value)
        end
        text:SetText(label .. ": " .. (typeKey == "settings" and string.format("%.2f", value) or math.floor(value)))
        if callback then callback(value) end
    end)

    table.insert(T.Registry, function()
        local val = (typeKey == "settings") and NS.DB.Settings[field] or NS.DB.Settings.fonts[typeKey][field]
        s:SetValue(val)
        text:SetText(label .. ": " .. (typeKey == "settings" and string.format("%.2f", val) or math.floor(val)))
    end)

    return s
end

function T.VisualScalingSection(parent, label, typeKey)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(320, 70)
    container:SetScale(1.05) -- Slightly increased overall scale

    local sub = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sub:SetPoint("TOPLEFT", 0, 0); sub:SetText(label); sub:SetTextColor(0.4, 0.8, 1)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 10, -20); slider:SetWidth(120); slider:SetScale(0.9); slider
        :SetMinMaxValues(8, 48); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    local sText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); sText:SetPoint("BOTTOMLEFT", slider,
        "TOPLEFT", 0, 2)
    local val = NS.DB.Settings.fonts[typeKey].size; slider:SetValue(val); sText:SetText("Size: " .. val)
    slider:SetScript("OnValueChanged",
        function(self, v)
            NS.DB.Settings.fonts[typeKey].size = math.floor(v); sText:SetText("Size: " .. math.floor(v));
            if NS.UpdateFontsOnly then NS.UpdateFontsOnly() end
        end)

    local dd = CreateFrame("Frame", "SSFontDD" .. typeKey, container, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", slider, "RIGHT", -15, -2); UIDropDownMenu_SetWidth(dd, 80); dd:SetScale(0.95) -- Reduced width, slightly larger scale
    local function OnClick(self)
        UIDropDownMenu_SetSelectedValue(dd, self.value); UIDropDownMenu_SetText(dd, self.text); NS.DB.Settings.fonts[typeKey].font =
            self.value; NS.RefreshAllUI()
    end
    UIDropDownMenu_Initialize(dd, function()
        local fonts = { { name = "Friz", path = "Fonts\\FRIZQT__.TTF" }, { name = "Arial", path = "Fonts\\ARIALN.TTF" }, { name = "Skurri", path = "Fonts\\skurri.ttf" }, { name = "Morph", path = "Fonts\\MORPHEUS.ttf" } }
        for _, info in ipairs(fonts) do
            local item = UIDropDownMenu_CreateInfo(); item.text = info.name; item.value = info.path; item.func = OnClick; UIDropDownMenu_AddButton(
                item)
        end
    end)
    UIDropDownMenu_SetSelectedValue(dd, NS.DB.Settings.fonts[typeKey].font)
    UIDropDownMenu_SetText(dd,
        (NS.DB.Settings.fonts[typeKey].font:find("FRIZQT") and "Friz" or (NS.DB.Settings.fonts[typeKey].font:find("ARIAL") and "Arial" or (NS.DB.Settings.fonts[typeKey].font:find("skurri") and "Skurri" or "Morph"))))

    local bold = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    bold:SetPoint("LEFT", dd, "RIGHT", -5, 2); bold:SetScale(0.9); bold.Text:SetText("Bold")
    bold:SetChecked(NS.DB.Settings.fonts[typeKey].flags:find("THICKOUTLINE") ~= nil)
    bold:SetScript("OnClick", function(self)
        local f = NS.DB.Settings.fonts[typeKey]
        if self:GetChecked() then f.flags = "THICKOUTLINE" else f.flags = "OUTLINE" end
        NS.RefreshAllUI()
    end)

    table.insert(T.Registry, function()
        local f = NS.DB.Settings.fonts[typeKey]
        slider:SetValue(f.size)
        sText:SetText("Size: " .. f.size)
        UIDropDownMenu_SetSelectedValue(dd, f.font)
        local name = (f.font:find("FRIZQT") and "Friz" or (f.font:find("ARIAL") and "Arial" or (f.font:find("skurri") and "Skurri" or "Morph")))
        UIDropDownMenu_SetText(dd, name)
        bold:SetChecked(f.flags:find("THICKOUTLINE") ~= nil)
    end)

    return container
end

function T.Header(parent, text)
    local headerGroup = CreateFrame("Frame", nil, parent)
    headerGroup:SetSize(280, 25)

    local h = headerGroup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", 0, 0); h:SetText(text); h:SetTextColor(1, 0.82, 0)
    local l = headerGroup:CreateTexture(nil, "ARTWORK"); l:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4); l:SetSize(280, 1); l
        :SetColorTexture(1, 1, 1, 0.1)

    headerGroup.text = h
    headerGroup.line = l
    return headerGroup
end

function T.ColorPicker(parent, label, key)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(22, 22); f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }); f
        :SetBackdropBorderColor(0.5, 0.5, 0.5)
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1); bg
        :SetColorTexture(1, 1, 1)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", f, "RIGHT", 8, 0); text:SetText(label)
    local function UpdateSwatch()
        if NS.Colors[key] then
            bg:SetVertexColor(NS.Colors[key].r, NS.Colors[key].g,
                NS.Colors[key].b, NS.Colors[key].a or 1)
        end
    end
    f:SetScript("OnClick", function()
        local c = NS.Colors[key]; local originalHex = NS.DB.Settings.colors[key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            opacity = c.a or 1,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB(); local a = ColorPickerFrame:GetColorAlpha()
                NS.DB.Settings.colors[key] = string.format("%02x%02x%02x%02x", math.floor(a * 255), math.floor(r * 255),
                    math.floor(g * 255), math.floor(b * 255))
                NS.UpdateColorsFromSettings(); UpdateSwatch(); NS.RefreshAllUI()
            end,
            cancelFunc = function()
                NS.DB.Settings.colors[key] = originalHex; NS.UpdateColorsFromSettings(); UpdateSwatch(); NS.RefreshAllUI()
            end
        })
    end)

    table.insert(T.Registry, UpdateSwatch)

    UpdateSwatch(); return f
end

function NS.CreateOptionsPanel()
    local panel = CreateFrame("Frame", "SpeedSplitsOptionsPanel", UIParent); panel.name = "SpeedSplits"

    -- =========================================================
    -- Never use absolute positioning for settings sections, only relative.
    -- =========================================================

    -- THEMES & COLOURS (COLUMN 1)
    local themesHeader = T.Header(panel, "Themes & Colors")
    themesHeader:SetPoint("TOPLEFT", 16, -16)

    local colors = {
        { "Personal Best", "gold" },
        { "On Pace",       "deepGreen",  "paceThreshold1" },
        { "Behind Pace",   "lightGreen", "paceThreshold2" },
        { "Slow",          "darkRed" },
        { "UI Accents",    "turquoise" },
        { "Text",          "white" }
    }

    local lastColorElem = themesHeader
    for i, c in ipairs(colors) do
        local cp = T.ColorPicker(panel, c[1], c[2])
        cp:SetPoint("TOPLEFT", themesHeader, "BOTTOMLEFT", 8, -6 - (i - 1) * 26)

        if c[3] then
            local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            eb:SetSize(45, 22)
            eb:SetPoint("LEFT", cp, "RIGHT", 160, 0)
            eb:SetAutoFocus(false)
            eb:SetNumeric(true)
            eb:SetFontObject("GameFontHighlightSmall")

            local bg = eb:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0.5)

            local currentVal = NS.DB.Settings[c[3]]
            if currentVal == nil then
                currentVal = (c[3] == "paceThreshold1" and 4 or 12)
                NS.DB.Settings[c[3]] = currentVal
            end
            eb:SetText(tostring(currentVal))
            eb:SetTextColor(1, 1, 1, 1)
            eb:SetCursorPosition(0)

            local function SaveValue(s)
                local val = tonumber(s:GetText()) or 0
                NS.DB.Settings[c[3]] = val
                NS.RefreshAllUI()
            end

            eb:SetScript("OnEnterPressed", function(s)
                SaveValue(s); s:ClearFocus()
            end)
            eb:SetScript("OnEditFocusLost", function(s)
                SaveValue(s)
            end)
            eb:SetScript("OnEscapePressed", function(s)
                s:SetText(tostring(NS.DB.Settings[c[3]] or (c[3] == "paceThreshold1" and 4 or 12))); s:ClearFocus()
            end)
            local lab = eb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            lab:SetPoint("RIGHT", eb, "LEFT", -5, 0); lab:SetText("Cut-off:")
            local suf = eb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            suf:SetPoint("LEFT", eb, "RIGHT", 5, 0); suf:SetText("seconds")

            table.insert(T.Registry, function()
                eb:SetText(tostring(NS.DB.Settings[c[3]] or (c[3] == "paceThreshold1" and 4 or 12)))
            end)
        end
        lastColorElem = cp
    end

    -- HEADER TEXTURE (COLUMN 1, BELOW COLOURS)
    local textureHeader = T.Header(panel, "Header Texture")
    textureHeader:SetPoint("TOPLEFT", themesHeader, "BOTTOMLEFT", 0, -170)

    local texButtons = {}
    for i, name in ipairs(NS.TitleTextures) do
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(60, 30); btn:SetPoint("TOPLEFT", textureHeader, "BOTTOMLEFT", 4 + ((i - 1) % 4) * 65,
            -10 - math.floor((i - 1) / 4) * 35)
        local t = btn:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints()
        if name:find("[\\/]") then
            t:SetTexture(name); t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        else
            t:SetAtlas(name)
        end
        local b = CreateFrame("Frame", nil, btn, "BackdropTemplate"); b:SetAllPoints(); b:SetBackdrop({
            edgeFile =
            "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1
        }); b:SetBackdropBorderColor(1, 1, 0); btn.border = b
        b:SetShown(name == NS.DB.Settings.titleTexture)
        btn:SetScript("OnClick",
            function()
                NS.DB.Settings.titleTexture = name; for _, x in ipairs(texButtons) do x.border:SetShown(x.texName == name) end; NS
                    .RefreshAllUI()
            end); btn.texName = name; table.insert(texButtons, btn)
    end

    -- PB REWARD TOAST (COLUMN 1, BOTTOM)
    local toastHeader = T.Header(panel, "PB Reward Toast")
    toastHeader:SetPoint("TOPLEFT", textureHeader, "BOTTOMLEFT", 0, -100)

    -- Dual column container for toggles/sound/scale
    local rewardRow = CreateFrame("Frame", nil, panel)
    rewardRow:SetPoint("TOPLEFT", toastHeader, "BOTTOMLEFT", 0, -10)
    rewardRow:SetSize(300, 150)

    local col1X = 8
    local col2X = 150

    -- Column 1: Toggles + Test Button
    local cb = CreateFrame("CheckButton", nil, rewardRow, "InterfaceOptionsCheckButtonTemplate")
    cb:SetScale(1.0) -- Reduced scale back to normal
    cb.Text:SetText("Enable Toast Effect")
    cb.Text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    cb:SetChecked(NS.DB.Settings.showTimerToast)
    cb:SetPoint("TOPLEFT", rewardRow, "TOPLEFT", col1X, -4)
    cb:SetScript("OnClick", function(s)
        NS.DB.Settings.showTimerToast = s:GetChecked()
        NS.RefreshAllUI()
    end)

    local cbAll = CreateFrame("CheckButton", nil, rewardRow, "InterfaceOptionsCheckButtonTemplate")
    cbAll:SetScale(1.0) -- Reduced scale back to normal
    cbAll.Text:SetText("Toast All Boss Kills")
    cbAll.Text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    cbAll:SetChecked(NS.DB.Settings.toastAllBosses)
    cbAll:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4) -- Reduced padding
    cbAll:SetScript("OnClick", function(s)
        NS.DB.Settings.toastAllBosses = s:GetChecked()
        NS.RefreshAllUI()
    end)

    table.insert(T.Registry, function()
        cb:SetChecked(NS.DB.Settings.showTimerToast)
        cbAll:SetChecked(NS.DB.Settings.toastAllBosses)
    end)

    local testBtn = CreateFrame("Button", nil, rewardRow, "UIPanelButtonTemplate")
    testBtn:SetSize(110, 24)
    testBtn:SetPoint("TOPLEFT", cbAll, "BOTTOMLEFT", 4, -12)
    testBtn:SetText("Test Toast")
    testBtn:SetScript("OnClick", function()
        if NS.TestPBToast then NS.TestPBToast() end
    end)

    -- Column 2: Sound dropdown + Volume + Scale
    local soundLabel = rewardRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", rewardRow, "TOPLEFT", col2X, 0)
    soundLabel:SetText("PB Toast Sound")
    soundLabel:SetTextColor(0.4, 0.8, 1)

    local soundDD = CreateFrame("Frame", "SSPBToastSoundDD", rewardRow, "UIDropDownMenuTemplate")
    soundDD:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -15, -4)
    UIDropDownMenu_SetWidth(soundDD, 130)
    soundDD:SetScale(0.85)

    local function GetSoundNameByID(id)
        for _, info in ipairs(NS.SoundOptions or {}) do
            if info.id == id then return info.name end
        end
    end

    local function UpdateSoundDD()
        local id = NS.DB.Settings.toastSoundID or 0
        local name = GetSoundNameByID(id) or NS.DB.Settings.toastSoundName or "None"
        NS.DB.Settings.toastSoundName = name

        UIDropDownMenu_SetSelectedValue(soundDD, id)
        UIDropDownMenu_SetText(soundDD, name)
    end

    table.insert(T.Registry, UpdateSoundDD)

    local function OnSoundClick(self)
        local id = self.value or 0
        local name = (self.GetText and self:GetText()) or self.text or GetSoundNameByID(id) or "None"

        NS.DB.Settings.toastSoundID = id
        NS.DB.Settings.toastSoundName = name
        UpdateSoundDD()

        if id > 0 then
            local played = PlaySound(id, "SFX") -- SoundKitID (preferred)
            if not played then
                PlaySoundFile(id, "SFX")        -- fallback if it’s actually a FileDataID
            end
        end
    end

    UIDropDownMenu_Initialize(soundDD, function()
        for _, info in ipairs(NS.SoundOptions or {}) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = info.name
            item.value = info.id
            item.func = OnSoundClick
            UIDropDownMenu_AddButton(item)
        end
    end)

    UpdateSoundDD()

    UIDropDownMenu_Initialize(soundDD, function()
        for _, info in ipairs(NS.SoundOptions or {}) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = info.name; item.value = info.id; item.func = OnSoundClick
            UIDropDownMenu_AddButton(item)
        end
    end)
    UpdateSoundDD()

    local volLabel = rewardRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    volLabel:SetPoint("TOPLEFT", soundDD, "BOTTOMLEFT", 15, -4)
    volLabel:SetText("Toast Volume")
    volLabel:SetTextColor(0.4, 0.8, 1)

    local volSlider = T.CreateSlider(rewardRow, "Vol", 0.0, 1.0, "settings", "toastVolume", 130)
    volSlider:SetScale(0.85)
    volSlider:SetPoint("TOPLEFT", volLabel, "BOTTOMLEFT", 0, -18)

    local scaleLabel = rewardRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", volSlider, "BOTTOMLEFT", 0, -10)
    scaleLabel:SetText("Toast Scale")
    scaleLabel:SetTextColor(0.4, 0.8, 1)

    local toastScaleSlider = T.CreateSlider(rewardRow, "Scale", 0.5, 3.0, "settings", "timerToastScale", 130, function()
        if NS.UpdateToastLayout then NS.UpdateToastLayout() end
    end)
    toastScaleSlider:SetScale(0.85)
    toastScaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -18)

    -- Toast Textures (below the columns)
    local texLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    texLabel:SetPoint("TOPLEFT", rewardRow, "BOTTOMLEFT", 0, -10)
    texLabel:SetText("Toast Textures")
    texLabel:SetTextColor(0.4, 0.8, 1)

    local texFrame = CreateFrame("Frame", nil, panel)
    texFrame:SetPoint("TOPLEFT", texLabel, "BOTTOMLEFT", 0, -8)
    texFrame:SetSize(280, 1) -- width only; height is implicit from children

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
        if name:find("[\\/]") then t:SetTexture(name) else t:SetAtlas(name) end

        local b = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        b:SetAllPoints()
        b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropBorderColor(1, 1, 0)
        btn.border = b

        local tl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tl:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        tl:SetText(toastLabels[index] or "")
        tl:SetScale(0.8)

        b:Hide() -- Hide by default, selection is just for testing
        btn.texName = name
        table.insert(toastBtns, btn)

        btn:SetScript("OnClick", function()
            -- Purely for testing: show border momentarily and trigger test toast
            for _, x in ipairs(toastBtns) do x.border:Hide() end
            btn.border:Show()
            if NS.TestPBToast then NS.TestPBToast(name) end
        end)
    end

    -- VISUAL SCALING & FONTS (COLUMN 2)
    local fontsHeader = T.Header(panel, "Visual Scaling & Fonts")
    fontsHeader:SetPoint("TOPLEFT", 340, -16)

    local bossRow = T.VisualScalingSection(panel, "Boss Names", "boss")
    bossRow:SetPoint("TOPLEFT", fontsHeader, "BOTTOMLEFT", 10, -10)

    local numRow = T.VisualScalingSection(panel, "Splits / Numbers", "num")
    numRow:SetPoint("TOPLEFT", bossRow, "BOTTOMLEFT", 0, -10)

    local headerRow = T.VisualScalingSection(panel, "Counter / Headers", "header")
    headerRow:SetPoint("TOPLEFT", numRow, "BOTTOMLEFT", 0, -10)

    local timerRow = T.VisualScalingSection(panel, "Main Timer", "timer")
    timerRow:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -10)

    -- MANAGEMENT (COLUMN 2, BOTTOM)
    local managementHeader = T.Header(panel, "Management")
    managementHeader:SetPoint("TOPLEFT", fontsHeader, "BOTTOMLEFT", 0, -360) -- Increased spacing

    local function Q(label, func)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate"); btn:SetSize(140, 26); btn:SetText(label); btn
            :SetScript("OnClick", func); return btn
    end

    local defBtn = Q("Set Default Styles", function()
        NS.DB.DefaultStyle = {
            colors = SS_CopyTable(NS.DB.Settings.colors),
            fonts = SS_CopyTable(NS.DB.Settings.fonts),
            titleTexture = NS.DB.Settings.titleTexture,
            timerToastScale = NS.DB.Settings.timerToastScale,
            showTimerToast = NS.DB.Settings.showTimerToast,
            paceThreshold1 = NS.DB.Settings.paceThreshold1,
            paceThreshold2 = NS.DB.Settings.paceThreshold2,
            toastAllBosses = NS.DB.Settings.toastAllBosses,
            toastSoundID = NS.DB.Settings.toastSoundID,
            toastSoundName = NS.DB.Settings.toastSoundName,
            toastVolume = NS.DB.Settings.toastVolume
        }
        if _G.SS_Print then _G.SS_Print("Default styles saved.") end
    end)
    defBtn:SetPoint("TOPLEFT", managementHeader, "BOTTOMLEFT", 10, -20)

    local resetBtn = Q("Reset Styles", function()
        if NS.DB.DefaultStyle then
            local d = NS.DB.DefaultStyle
            NS.DB.Settings.colors = SS_CopyTable(d.colors)
            NS.DB.Settings.fonts = SS_CopyTable(d.fonts)
            NS.DB.Settings.titleTexture = d.titleTexture
            NS.DB.Settings.timerToastScale = d.timerToastScale
            NS.DB.Settings.showTimerToast = d.showTimerToast
            NS.DB.Settings.paceThreshold1 = d.paceThreshold1
            NS.DB.Settings.paceThreshold2 = d.paceThreshold2
            NS.DB.Settings.toastAllBosses = d.toastAllBosses
            NS.DB.Settings.toastSoundID = d.toastSoundID
            NS.DB.Settings.toastSoundName = d.toastSoundName
            NS.DB.Settings.toastVolume = d.toastVolume or 0.8
            NS.UpdateColorsFromSettings()

            -- Refresh Options UI
            for _, refresh in ipairs(T.Registry) do refresh() end

            NS.RefreshAllUI()
            if _G.SS_Print then _G.SS_Print("Styles reset to defaults.") end
        end
    end)
    resetBtn:SetPoint("LEFT", defBtn, "RIGHT", 15, 0)

    local layoutBtn = Q("Save Default Layout", function()
        NS.DB.DefaultLayout = {
            ui = SS_CopyTable(NS.DB.ui or {})
        }
        if _G.SS_Print then _G.SS_Print("Default layout saved.") end
    end)
    layoutBtn:SetPoint("TOPLEFT", defBtn, "BOTTOMLEFT", 0, -10)

    local resetLayoutBtn = Q("Reset Layout", function()
        if NS.DB.DefaultLayout and NS.DB.DefaultLayout.ui then
            NS.DB.ui = SS_CopyTable(NS.DB.DefaultLayout.ui)
            ReloadUI() -- Reloading is safest to ensure all frames restore correctly
        else
            StaticPopup_Show("SPEEDSPLITS_RESET_LAYOUT")
        end
    end)
    resetLayoutBtn:SetPoint("LEFT", layoutBtn, "RIGHT", 15, 0)

    local wipeBtn = Q("Wipe All Records", function() StaticPopup_Show("SPEEDSPLITS_WIPE_CONFIRM") end)
    wipeBtn:SetSize(295, 26)
    wipeBtn:SetPoint("TOPLEFT", layoutBtn, "BOTTOMLEFT", 0, -10)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    else
        InterfaceOptions_AddCategory(panel)
    end
end
