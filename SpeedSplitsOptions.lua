local ADDON_NAME, NS = ...

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
        local hex = NS.DB.settings.colors[key]
        local c = NS.Colors[key]
        if c then
            bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        end
    end

    frame:SetScript("OnClick", function()
        local c = NS.Colors[key]

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
                    NS.DB.settings.colors[key] = hex
                    NS.UpdateColorsFromSettings()
                    UpdateSwatch()
                    NS.RefreshAllUI()
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    local hex = string.format("%02x%02x%02x%02x", math.floor(a * 255 + 0.5), math.floor(r * 255 + 0.5),
                        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
                    NS.DB.settings.colors[key] = hex
                    NS.UpdateColorsFromSettings()
                    UpdateSwatch()
                    NS.RefreshAllUI()
                end,
                cancelFunc = function()
                    -- Could restore previous value if desired
                end
            })
        else
            -- Classic fallback
            ColorPickerFrame.func = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                local hex = string.format("%02x%02x%02x%02x", math.floor(a * 255), math.floor(r * 255), math.floor(g *
                    255), math.floor(b * 255))
                NS.DB.settings.colors[key] = hex
                NS.UpdateColorsFromSettings()
                UpdateSwatch()
                NS.RefreshAllUI()
            end
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacityFunc = ColorPickerFrame.func
            ColorPickerFrame.cancelFunc = nil
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
        { "Pace: Behind",           "lightRed" },
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

        local val = NS.DB.settings.fonts[typeKey][field]
        s:SetValue(val)
        text:SetText(string.format("%s: %d", label, val))

        s:SetScript("OnValueChanged", function(self, value)
            NS.DB.settings.fonts[typeKey][field] = math.floor(value)
            text:SetText(string.format("%s: %d", label, value))
            NS.RefreshAllUI()
        end)
        return s
    end

    local function CreateCheckbox(parent, label, typeKey, flag)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb.Text:SetText(label)
        local cur = NS.DB.settings.fonts[typeKey].flags
        cb:SetChecked(cur:find(flag) ~= nil)
        cb:SetScript("OnClick", function(self)
            local f = NS.DB.settings.fonts[typeKey]
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
            NS.DB.settings.fonts[typeKey].font = self.value
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
        local cur = NS.DB.settings.fonts[typeKey].font
        UIDropDownMenu_SetSelectedValue(f, cur)
        for _, info in ipairs(fonts) do
            if info.path == cur then UIDropDownMenu_SetText(f, info.name) end
        end
        return f
    end

    local bossSize = CreateSlider(panel, "Boss Text Size", 8, 24, "boss", "size")
    bossSize:SetPoint("TOPLEFT", typeTitle, "BOTTOMLEFT", 8, -24)

    local bossFont = CreateFontDropdown(panel, "Boss Font", "boss")
    bossFont:SetPoint("TOPLEFT", bossSize, "BOTTOMLEFT", -16, -24)

    local numSize = CreateSlider(panel, "Splits Text Size", 8, 24, "num", "size")
    numSize:SetPoint("TOPLEFT", bossFont, "BOTTOMLEFT", 16, -32)

    local numFont = CreateFontDropdown(panel, "Splits Font", "num")
    numFont:SetPoint("TOPLEFT", numSize, "BOTTOMLEFT", -16, -24)

    local bossBold = CreateCheckbox(panel, "Bold Boss Names", "boss", "THICKOUTLINE")
    bossBold:SetPoint("TOPLEFT", numFont, "BOTTOMLEFT", 12, -8)

    local numBold = CreateCheckbox(panel, "Bold Splits", "num", "THICKOUTLINE")
    numBold:SetPoint("TOPLEFT", bossBold, "BOTTOMLEFT", 0, -4)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 16, 16)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        NS.DB.settings.colors = {
            gold       = "ffffd100",
            white      = "ffffffff",
            turquoise  = "ff00cccc",
            deepGreen  = "ff00cc36",
            lightGreen = "ff52cc73",
            lightRed   = "ffff7777",
            darkRed    = "ffcc1200",
        }
        NS.DB.settings.fonts = {
            boss = { size = 12, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            num  = { size = 11, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
        }
        NS.UpdateColorsFromSettings()
        for _, s in ipairs(swatches) do s.UpdateSwatch() end
        bossSize:SetValue(12)
        numSize:SetValue(11)
        bossBold:SetChecked(false)
        numBold:SetChecked(false)
        UIDropDownMenu_SetText(bossFont, "Friz Quadrata")
        UIDropDownMenu_SetText(numFont, "Friz Quadrata")
        NS.RefreshAllUI()
    end)

    -- Register in Blizzard options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end
