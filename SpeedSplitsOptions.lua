local ADDON_NAME, NS = ...

-- Libraries / Globals
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo

-- Helper to create a color picker row
local function CreateColorPicker(parent, label, key)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(22, 22)

    frame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(1, 1, 1, 1)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", frame, "RIGHT", 10, 0)
    text:SetText(label)

    local function UpdateSwatch()
        local hex = NS.DB.Settings.colors[key]
        local c = NS.Colors[key]
        if c then
            bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        end
    end

    frame:SetScript("OnClick", function()
        local c = NS.Colors[key]
        local originalHex = NS.DB.Settings.colors[key]

        -- Support for both classic ColorPicker and the newer setup (Dragonflight)
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r,
                g = c.g,
                b = c.b,
                opacity = c.a or 1,
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    local hex = string.format("%02x%02x%02x%02x", math.floor(a * 255 + 0.5), math.floor(r * 255 + 0.5),
                        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
                    NS.DB.Settings.colors[key] = hex
                    NS.UpdateColorsFromSettings()
                    UpdateSwatch()
                    NS.RefreshAllUI()
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    local hex = string.format("%02x%02x%02x%02x", math.floor(a * 255 + 0.5), math.floor(r * 255 + 0.5),
                        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
                    NS.DB.Settings.colors[key] = hex
                    NS.UpdateColorsFromSettings()
                    UpdateSwatch()
                    NS.RefreshAllUI()
                end,
                cancelFunc = function()
                    NS.DB.Settings.colors[key] = originalHex
                    NS.UpdateColorsFromSettings()
                    UpdateSwatch()
                    NS.RefreshAllUI()
                end
            })
        else
            -- Classic fallback
            ColorPickerFrame.func = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                local hex = string.format("%02x%02x%02x%02x", math.floor(a * 255), math.floor(r * 255), math.floor(g *
                    255), math.floor(b * 255))
                NS.DB.Settings.colors[key] = hex
                NS.UpdateColorsFromSettings()
                UpdateSwatch()
                NS.RefreshAllUI()
            end
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacityFunc = ColorPickerFrame.func
            ColorPickerFrame.cancelFunc = function()
                NS.DB.Settings.colors[key] = originalHex
                NS.UpdateColorsFromSettings()
                UpdateSwatch()
                NS.RefreshAllUI()
            end
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame:Show()
        end
    end)

    UpdateSwatch()
    frame.UpdateSwatch = UpdateSwatch
    return frame
end

function NS.CreateOptionsPanel()
    local panel = CreateFrame("Frame", "SpeedSplitsOptionsPanel", UIParent)
    panel.name = "SpeedSplits"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SpeedSplits Options")

    local subText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subText:SetText("Configure the look and behavior of your splits.")

    local colorsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorsTitle:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -20)
    colorsTitle:SetText("Theme Colors")

    local colorConfigs = {
        { "Pace: Ahead (PB/Gold)",  "gold" },
        { "Pace: Even/Fast",        "deepGreen" },
        { "Pace: Slightly Behind",  "lightGreen" },
        { "Pace: Way Behind",       "darkRed" },
        { "UI Accents (Turquoise)", "turquoise" },
        { "Standard Text",          "white" },
    }

    local lastFrame
    local swatches = {}
    for i, cfg in ipairs(colorConfigs) do
        local cp = CreateColorPicker(panel, cfg[1], cfg[2])
        if i == 1 then
            cp:SetPoint("TOPLEFT", colorsTitle, "BOTTOMLEFT", 8, -12)
        else
            cp:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -10)
        end
        lastFrame = cp
        table.insert(swatches, cp)
    end

    -- Typography section
    local typeTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    typeTitle:SetPoint("TOPLEFT", colorsTitle, "TOPLEFT", 260, 0)
    typeTitle:SetText("Typography")

    local function CreateSlider(parent, label, minV, maxV, typeKey, field)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(1)
        s:SetObeyStepOnDrag(true)
        s:SetWidth(180)

        local text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("BOTTOM", s, "TOP", 0, 4)

        local val = NS.DB.Settings.fonts[typeKey][field]
        s:SetValue(val)
        text:SetText(string.format("%s: %d", label, val))

        s:SetScript("OnValueChanged", function(self, value)
            NS.DB.Settings.fonts[typeKey][field] = math.floor(value)
            text:SetText(string.format("%s: %d", label, value))
            NS.RefreshAllUI()
        end)
        return s
    end

    local function CreateCheckbox(parent, label, typeKey, flag)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb.Text:SetText(label)
        local cur = NS.DB.Settings.fonts[typeKey].flags
        cb:SetChecked(cur:find(flag) ~= nil)
        cb:SetScript("OnClick", function(self)
            local f = NS.DB.Settings.fonts[typeKey]
            if self:GetChecked() then
                if not f.flags:find(flag) then
                    f.flags = f.flags == "" and flag or (f.flags .. ", " .. flag)
                end
            else
                f.flags = f.flags:gsub(",%s*" .. flag, ""):gsub(flag .. ",%s*", ""):gsub(flag, "")
            end
            NS.RefreshAllUI()
        end)
        return cb
    end

    local fonts = {
        { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",        path = "Fonts\\skurri.ttf" },
        { name = "Morpheus",      path = "Fonts\\MORPHEUS.ttf" },
    }

    local function CreateFontDropdown(parent, label, typeKey)
        local f = CreateFrame("Frame", "SSFontDD" .. typeKey, parent, "UIDropDownMenuTemplate")
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 16, 2)
        t:SetText(label)
        UIDropDownMenu_SetWidth(f, 140)

        local function OnClick(self)
            UIDropDownMenu_SetSelectedValue(f, self.value)
            UIDropDownMenu_SetText(f, self.text)
            NS.DB.Settings.fonts[typeKey].font = self.value
            NS.RefreshAllUI()
        end
        UIDropDownMenu_Initialize(f, function()
            for _, info in ipairs(fonts) do
                local item = UIDropDownMenu_CreateInfo()
                item.text = info.name
                item.value = info.path
                item.func = OnClick
                UIDropDownMenu_AddButton(item)
            end
        end)
        local cur = NS.DB.Settings.fonts[typeKey].font
        UIDropDownMenu_SetSelectedValue(f, cur)
        for _, info in ipairs(fonts) do
            if info.path == cur then UIDropDownMenu_SetText(f, info.name) end
        end
        return f
    end

    local bossSize = CreateSlider(panel, "Boss Size", 8, 24, "boss", "size")
    bossSize:SetPoint("TOPLEFT", typeTitle, "BOTTOMLEFT", 8, -24)
    local bossFont = CreateFontDropdown(panel, "Boss Font", "boss")
    bossFont:SetPoint("TOPLEFT", bossSize, "BOTTOMLEFT", -16, -24)

    local numSize = CreateSlider(panel, "Splits Size", 8, 24, "num", "size")
    numSize:SetPoint("TOPLEFT", bossFont, "BOTTOMLEFT", 16, -32)
    local numFont = CreateFontDropdown(panel, "Splits Font", "num")
    numFont:SetPoint("TOPLEFT", numSize, "BOTTOMLEFT", -16, -24)

    local timerSize = CreateSlider(panel, "Timer Size", 8, 48, "timer", "size")
    timerSize:SetPoint("TOPLEFT", numFont, "BOTTOMLEFT", 16, -32)
    local timerFont = CreateFontDropdown(panel, "Timer Font", "timer")
    timerFont:SetPoint("TOPLEFT", timerSize, "BOTTOMLEFT", -16, -24)

    local headerSize = CreateSlider(panel, "Header Size", 8, 24, "header", "size")
    headerSize:SetPoint("TOPLEFT", timerFont, "BOTTOMLEFT", 16, -32)
    local headerFont = CreateFontDropdown(panel, "Header Font", "header")
    headerFont:SetPoint("TOPLEFT", headerSize, "BOTTOMLEFT", -16, -24)

    local bossBold = CreateCheckbox(panel, "Bold Boss Names", "boss", "THICKOUTLINE")
    bossBold:SetPoint("TOPLEFT", typeTitle, "TOPLEFT", 210, -24)
    local numBold = CreateCheckbox(panel, "Bold Splits", "num", "THICKOUTLINE")
    numBold:SetPoint("TOPLEFT", bossBold, "BOTTOMLEFT", 0, -4)
    local timerBold = CreateCheckbox(panel, "Bold Timer", "timer", "THICKOUTLINE")
    timerBold:SetPoint("TOPLEFT", numBold, "BOTTOMLEFT", 0, -4)
    local headerBold = CreateCheckbox(panel, "Bold Headers", "header", "THICKOUTLINE")
    headerBold:SetPoint("TOPLEFT", timerBold, "BOTTOMLEFT", 0, -4)

    -- History specific
    local function CreateHistorySlider(parent, label, minV, maxV)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(0.05)
        s:SetObeyStepOnDrag(true)
        s:SetWidth(180)

        local text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("BOTTOM", s, "TOP", 0, 4)

        local val = NS.DB.Settings.historyScale or 1.0
        s:SetValue(val)
        text:SetText(string.format("%s: %.2f", label, val))

        s:SetScript("OnValueChanged", function(self, value)
            NS.DB.Settings.historyScale = tonumber(string.format("%.2f", value))
            text:SetText(string.format("%s: %.2f", label, value))
            NS.RefreshAllUI()
        end)
        return s
    end

    local historyScale = CreateHistorySlider(panel, "History Panel Scale", 0.5, 2.0)
    historyScale:SetPoint("TOPLEFT", headerFont, "BOTTOMLEFT", 16, -32)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 16, 16)
    resetBtn:SetText("Reset Styles Only")
    resetBtn:SetScript("OnClick", function()
        NS.DB.Settings.colors = {
            gold       = "ffffd100",
            white      = "ffffffff",
            turquoise  = "ff00bec3",
            deepGreen  = "ff10ff00",
            lightGreen = "ffcc2232",
            darkRed    = "ffcc0005",
        }
        NS.DB.Settings.fonts = {
            boss   = { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            num    = { size = 17, font = "Fonts\\ARIALN.TTF", flags = "OUTLINE" },
            timer  = { size = 30, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            header = { size = 12, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
        }
        NS.DB.Settings.historyScale = 1.0
        NS.UpdateColorsFromSettings()
        for _, s in ipairs(swatches) do s.UpdateSwatch() end

        bossSize:SetValue(14)
        numSize:SetValue(17)
        timerSize:SetValue(30)

        bossBold:SetChecked(false)
        numBold:SetChecked(false)
        timerBold:SetChecked(false)

        _G.UIDropDownMenu_SetText(bossFont, "Friz Quadrata")
        _G.UIDropDownMenu_SetSelectedValue(bossFont, "Fonts\\FRIZQT__.TTF")

        _G.UIDropDownMenu_SetText(numFont, "Arial Narrow")
        _G.UIDropDownMenu_SetSelectedValue(numFont, "Fonts\\ARIALN.TTF")

        _G.UIDropDownMenu_SetText(timerFont, "Friz Quadrata")
        _G.UIDropDownMenu_SetSelectedValue(timerFont, "Fonts\\FRIZQT__.TTF")

        headerSize:SetValue(12)
        headerBold:SetChecked(false)
        _G.UIDropDownMenu_SetText(headerFont, "Friz Quadrata")
        _G.UIDropDownMenu_SetSelectedValue(headerFont, "Fonts\\FRIZQT__.TTF")

        historyScale:SetValue(1.0)

        NS.RefreshAllUI()
    end)

    local wipeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    wipeBtn:SetSize(160, 22)
    wipeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    wipeBtn:SetText("Wipe All Records & Data")
    wipeBtn:SetScript("OnClick", function()
        StaticPopup_Show("SPEEDSPLITS_WIPE_CONFIRM")
    end)

    StaticPopupDialogs["SPEEDSPLITS_WIPE_CONFIRM"] = {
        text =
        "Are you sure you want to WIPE all SpeedSplits data? This will clear all Personal Bests and Run History. This cannot be undone.",
        button1 = "WIPE DATA",
        button2 = "Cancel",
        OnAccept = function()
            NS.WipeDatabase()
            -- Force UI update for options panel if visible
            NS.RefreshAllUI()
            ReloadUI() -- Force full reset to be safe
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
    }

    -- Register in Blizzard options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end
