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

function T.CreateSlider(parent, label, minV, maxV, typeKey, field, x, y, width)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
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
            NS.DB.Settings.fonts[typeKey][field] = math
                .floor(value)
        end
        text:SetText(label .. ": " .. (typeKey == "settings" and string.format("%.2f", value) or math.floor(value)))
        NS.RefreshAllUI()
    end)
    return s
end

function T.FontRow(parent, label, typeKey, x, y)
    local sub = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sub:SetPoint("TOPLEFT", x, y); sub:SetText(label); sub:SetTextColor(0.4, 0.8, 1)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 10, -20); slider:SetWidth(120); slider:SetScale(0.9); slider
        :SetMinMaxValues(8, 48); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    local sText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); sText:SetPoint("BOTTOMLEFT", slider,
        "TOPLEFT", 0, 2)
    local val = NS.DB.Settings.fonts[typeKey].size; slider:SetValue(val); sText:SetText("Size: " .. val)
    slider:SetScript("OnValueChanged",
        function(self, v)
            NS.DB.Settings.fonts[typeKey].size = math.floor(v); sText:SetText("Size: " .. math.floor(v)); NS
                .RefreshAllUI()
        end)

    local dd = CreateFrame("Frame", "SSFontDD" .. typeKey, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", slider, "RIGHT", -5, -2); UIDropDownMenu_SetWidth(dd, 100); dd:SetScale(0.9)
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

    local bold = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    bold:SetPoint("LEFT", dd, "RIGHT", -5, 2); bold:SetScale(0.85); bold.Text:SetText("Bold")
    bold:SetChecked(NS.DB.Settings.fonts[typeKey].flags:find("THICKOUTLINE") ~= nil)
    bold:SetScript("OnClick", function(self)
        local f = NS.DB.Settings.fonts[typeKey]
        if self:GetChecked() then f.flags = "THICKOUTLINE" else f.flags = "OUTLINE" end
        NS.RefreshAllUI()
    end)
    return slider, bold, dd
end

function T.Header(parent, text, x, y)
    local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", x, y); h:SetText(text); h:SetTextColor(1, 0.82, 0)
    local l = parent:CreateTexture(nil, "ARTWORK"); l:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4); l:SetSize(280, 1); l
        :SetColorTexture(1, 1, 1, 0.1)
    return h
end

function T.ColorPicker(parent, label, key, x, y)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(22, 22); f:SetPoint("TOPLEFT", x, y); f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }); f
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
    UpdateSwatch(); return f
end

function NS.CreateOptionsPanel()
    local panel = CreateFrame("Frame", "SpeedSplitsOptionsPanel", UIParent); panel.name = "SpeedSplits"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 16, -16); title
        :SetText("SpeedSplits Configuration"); title:SetScale(1.1)

    -- THEMES & COLOURS (COLUMN 1)
    T.Header(panel, "Themes & Colors", 16, -60)
    local colors = {
        { "Personal Best", "gold" },
        { "On Pace",       "deepGreen",  "paceThreshold1" },
        { "Behind Pace",   "lightGreen", "paceThreshold2" },
        { "Slow",          "darkRed" },
        { "UI Accents",    "turquoise" },
        { "Text",          "white" }
    }
    for i, c in ipairs(colors) do
        local y = -75 - (i * 26)
        local cp = T.ColorPicker(panel, c[1], c[2], 24, y)
        if c[3] then
            local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            eb:SetSize(35, 20); eb:SetPoint("LEFT", cp, "RIGHT", 150, 0); eb:SetAutoFocus(false); eb:SetNumeric(true)
            eb:SetText(tostring(NS.DB.Settings[c[3]] or (c[3] == "paceThreshold1" and 4 or 12)))
            eb:SetScript("OnEnterPressed", function(s)
                NS.DB.Settings[c[3]] = tonumber(s:GetText()) or 0; s:ClearFocus(); NS.RefreshAllUI()
            end)
            eb:SetScript("OnEscapePressed", function(s)
                s:SetText(tostring(NS.DB.Settings[c[3]] or (c[3] == "paceThreshold1" and 4 or 12))); s:ClearFocus()
            end)
            local lab = eb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            lab:SetPoint("RIGHT", eb, "LEFT", -5, 0); lab:SetText("Cut-off:")
            local suf = eb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            suf:SetPoint("LEFT", eb, "RIGHT", 5, 0); suf:SetText("seconds")
        end
    end

    -- HEADER TEXTURE (COLUMN 1, BELOW COLOURS)
    T.Header(panel, "Header Texture", 16, -260)
    local texButtons = {}
    for i, name in ipairs(NS.TitleTextures) do
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(60, 30); btn:SetPoint("TOPLEFT", 20 + ((i - 1) % 4) * 65, -290 - math.floor((i - 1) / 4) * 35)
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
    local toastHeader = T.Header(panel, "PB Reward Toast", 16, -385)

    -- Toggle
    local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetScale(0.9)
    cb.Text:SetText("Enable Toast Effect")
    cb:SetChecked(NS.DB.Settings.showTimerToast)
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", toastHeader, "BOTTOMLEFT", 8, -10)
    cb:SetScript("OnClick", function(s)
        NS.DB.Settings.showTimerToast = s:GetChecked()
        NS.RefreshAllUI()
    end)

    local cbAll = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbAll:SetScale(0.9)
    cbAll.Text:SetText("Toast All Boss Kills")
    cbAll:SetChecked(NS.DB.Settings.toastAllBosses)
    cbAll:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
    cbAll:SetScript("OnClick", function(s)
        NS.DB.Settings.toastAllBosses = s:GetChecked()
        NS.RefreshAllUI()
    end)

    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(100, 22)
    testBtn:SetPoint("LEFT", cb.Text, "RIGHT", 15, 0)
    testBtn:SetText("Test Toast")
    testBtn:SetScript("OnClick", function()
        if NS.TestPBToast then NS.TestPBToast() end
    end)

    -- Slider (anchored under toggles)
    local toastScaleSlider = T.CreateSlider(panel, "Toast Pulse Scale", 0.5, 3.0, "settings", "timerToastScale", 0, 0,
        180)
    toastScaleSlider:ClearAllPoints()
    toastScaleSlider:SetPoint("TOPLEFT", cbAll, "BOTTOMLEFT", 0, -22)

    -- Texture selection label + container (anchored under slider)
    local texLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    texLabel:SetPoint("TOPLEFT", toastScaleSlider, "BOTTOMLEFT", 0, -14)
    texLabel:SetText("Toast Texture")
    texLabel:SetTextColor(0.4, 0.8, 1)

    local texFrame = CreateFrame("Frame", nil, panel)
    texFrame:SetPoint("TOPLEFT", texLabel, "BOTTOMLEFT", 0, -8)
    texFrame:SetSize(280, 1) -- width only; height is implicit from children

    local toastBtns = {}
    local toastLabels = { "Gold", "Green", "Purple", "Red" }
    for index, name in ipairs(NS.TimerToastTextures or {}) do
        local btn = CreateFrame("Button", nil, texFrame, "BackdropTemplate")
        btn:SetSize(60, 30)

        local col = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        btn:SetPoint("TOPLEFT", texFrame, "TOPLEFT", col * 65, -row * 35)

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

        b:SetShown(name == NS.DB.Settings.timerToastTexture)
        btn.texName = name
        table.insert(toastBtns, btn)

        btn:SetScript("OnClick", function()
            NS.DB.Settings.timerToastTexture = name
            for _, x in ipairs(toastBtns) do
                x.border:SetShown(x.texName == name)
            end
            NS.RefreshAllUI()
            if NS.TestPBToast then NS.TestPBToast() end -- Test the chosen one
        end)
    end

    -- VISUAL SCALING & FONTS (COLUMN 2)
    T.Header(panel, "Visual Scaling & Fonts", 340, -60)
    T.FontRow(panel, "Boss Names", "boss", 350, -85)
    T.FontRow(panel, "Splits / Numbers", "num", 350, -165)
    T.FontRow(panel, "Counter / Headers", "header", 350, -245)
    T.FontRow(panel, "Main Timer", "timer", 350, -325)

    -- MANAGEMENT (COLUMN 2, BOTTOM)
    T.Header(panel, "Management", 340, -410)
    local function Q(label, x, y, func)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate"); btn:SetSize(140, 26); btn:SetPoint(
            "TOPLEFT", 350 + x, -440 + y); btn:SetText(label); btn:SetScript("OnClick", func); return btn
    end
    Q("Set Default Styles", 0, 0,
        function()
            NS.DB.DefaultStyle = {
                colors = SS_CopyTable(NS.DB.Settings.colors),
                fonts = SS_CopyTable(NS.DB.Settings
                    .fonts),
                titleTexture = NS.DB.Settings.titleTexture,
                timerToastTexture = NS.DB.Settings.timerToastTexture,
                timerToastScale =
                    NS.DB.Settings.timerToastScale,
                showTimerToast = NS.DB.Settings.showTimerToast,
                paceThreshold1 = NS.DB.Settings
                    .paceThreshold1,
                paceThreshold2 = NS.DB.Settings.paceThreshold2,
                toastAllBosses = NS.DB.Settings.toastAllBosses
            }; if _G.SS_Print then
                _G
                    .SS_Print("Default profile updated.")
            end
        end)
    Q("Reset Styles", 155, 0,
        function()
            if NS.DB.DefaultStyle then
                local d = NS.DB.DefaultStyle; NS.DB.Settings.colors = SS_CopyTable(d.colors); NS.DB.Settings.fonts =
                    SS_CopyTable(d.fonts); NS.DB.Settings.titleTexture = d.titleTexture; NS.DB.Settings.timerToastTexture =
                    d
                    .timerToastTexture; NS.DB.Settings.timerToastScale = d.timerToastScale; NS.DB.Settings.showTimerToast =
                    d
                    .showTimerToast; NS.DB.Settings.paceThreshold1 = d.paceThreshold1; NS.DB.Settings.paceThreshold2 = d
                    .paceThreshold2; NS.DB.Settings.toastAllBosses = d.toastAllBosses; NS.UpdateColorsFromSettings(); NS
                    .RefreshAllUI()
            end
        end)
    Q("Save Default Layout", 0, -35, function() if _G.SS_Print then _G.SS_Print("Layout saved.") end end)
    Q("Reset Layout", 155, -35, function() StaticPopup_Show("SPEEDSPLITS_RESET_LAYOUT") end)
    Q("Wipe All Records", 0, -70, function() StaticPopup_Show("SPEEDSPLITS_WIPE_CONFIRM") end):SetWidth(295)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings
            .RegisterCanvasLayoutCategory(panel, panel.name))
    else
        InterfaceOptions_AddCategory(panel)
    end
end
