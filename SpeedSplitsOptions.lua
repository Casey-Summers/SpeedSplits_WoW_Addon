local ADDON_NAME, NS = ...

-- Libraries / Globals
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo

local function SS_CopyTable(src)
    local dest = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = SS_CopyTable(v)
        else
            dest[k] = v
        end
    end
    return dest
end

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
    frame.Text = text

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

local function CreateSectionHeader(parent, text, xOfs, yOfs)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", xOfs, yOfs)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0, 1) -- Gold

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetSize(280, 1)
    line:SetColorTexture(1, 1, 1, 0.15)

    return header
end



function NS.CreateOptionsPanel()
    local panel = CreateFrame("Frame", "SpeedSplitsOptionsPanel", UIParent)
    panel.name = "SpeedSplits"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SpeedSplits | Advanced Configuration")
    title:SetScale(1.2)

    -- Theme Column (Left)
    local appearanceHeader = CreateSectionHeader(panel, "Theme & Accents", 16, -60)

    -- Colors Section
    local colorsSub = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorsSub:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 4, -18)
    colorsSub:SetText("Theme Colors")
    colorsSub:SetTextColor(0.4, 0.8, 1, 1) -- Light Blue

    local colorConfigs = {
        { "Pace: Ahead (PB/Gold)",  "gold" },
        { "Pace: Even/Fast",        "deepGreen" },
        { "Pace: Slightly Behind",  "lightGreen" },
        { "Pace: Way Behind",       "darkRed" },
        { "UI Accents (Turquoise)", "turquoise" },
        { "Standard Text",          "white" },
    }

    local lastColorFrame
    local swatches = {}
    for i, cfg in ipairs(colorConfigs) do
        local cp = CreateColorPicker(panel, cfg[1], cfg[2])
        if i == 1 then
            cp:SetPoint("TOPLEFT", colorsSub, "BOTTOMLEFT", 8, -12)
        else
            cp:SetPoint("TOPLEFT", lastColorFrame, "BOTTOMLEFT", 0, -8)
        end
        lastColorFrame = cp
        table.insert(swatches, cp)
    end

    -- Header Texture Section
    local textureSub = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    textureSub:SetPoint("TOPLEFT", lastColorFrame, "BOTTOMLEFT", -8, -25)
    textureSub:SetText("Header Background Texture")
    textureSub:SetTextColor(0.4, 0.8, 1, 1)

    -- Anchor texture previews further down if they were overlapping
    local texButtons = {}
    local function UpdateSelection()
        for _, b in ipairs(texButtons) do
            if b.texName == NS.DB.Settings.titleTexture then
                b.border:Show()
            else
                b.border:Hide()
            end
        end
    end

    for i, texName in ipairs(NS.TitleTextures) do
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(60, 30)
        btn:SetPoint("TOPLEFT", textureSub, "BOTTOMLEFT", 8 + ((i - 1) % 4) * 65, -12 - math.floor((i - 1) / 4) * 35)
        btn.texName = texName

        local t = btn:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetAtlas(texName)

        local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        border:SetBackdropBorderColor(1, 1, 0, 1)
        btn.border = border

        btn:SetScript("OnClick", function()
            NS.DB.Settings.titleTexture = texName
            UpdateSelection()
            NS.RefreshAllUI()
        end)
        texButtons[#texButtons + 1] = btn
    end
    UpdateSelection()

    -- Typography Column (Right)
    local typographyHeader = CreateSectionHeader(panel, "Visual Scaling & Fonts", 340, -60)

    local function CreateSlider(parent, label, minV, maxV, typeKey, field)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(1)
        s:SetObeyStepOnDrag(true)
        s:SetWidth(160)
        s:SetScale(0.9)

        local text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)

        local val = NS.DB.Settings.fonts[typeKey][field]
        s:SetValue(val)
        text:SetText(label .. ": " .. val)

        s:SetScript("OnValueChanged", function(self, value)
            NS.DB.Settings.fonts[typeKey][field] = math.floor(value)
            text:SetText(label .. ": " .. math.floor(value))
            NS.RefreshAllUI()
        end)
        return s
    end

    local function CreateCheckbox(parent, label, typeKey, flag)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetScale(0.85)

        local text = cb.Text or _G[cb:GetName() .. "Text"]
        if text then text:SetText(label) end
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
        UIDropDownMenu_SetWidth(f, 120)
        f:SetScale(0.9)

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

    -- Grouped Font Settings (Row by Row)
    local function CreateTypeRow(parent, label, typeKey, yOfs)
        local sub = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sub:SetPoint("TOPLEFT", typographyHeader, "BOTTOMLEFT", 4, yOfs)
        sub:SetText(label)
        sub:SetTextColor(0.4, 0.8, 1, 1)

        local slider = CreateSlider(parent, "Size", 8, 48, typeKey, "size")
        slider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 12, -22)

        local bold = CreateCheckbox(parent, "Bold", typeKey, "THICKOUTLINE")
        bold:SetPoint("LEFT", slider, "RIGHT", 15, 0)

        local dd = CreateFontDropdown(parent, "Font", typeKey)
        dd:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -15, -10)

        return slider, bold, dd, sub
    end

    local bSize, bBold, bFont = CreateTypeRow(panel, "Boss Names", "boss", -14)
    local nSize, nBold, nFont = CreateTypeRow(panel, "Table Splits", "num", -101)
    local cSize, cBold, cFont = CreateTypeRow(panel, "Boss Counter", "counter", -188)
    local tSize, tBold, tFont = CreateTypeRow(panel, "Main Timer", "timer", -275)
    local hSize, hBold, hFont = CreateTypeRow(panel, "Table Headers", "header", -362)

    -- Profile & Layout Management (Bottom Area)
    local managementHeader = CreateSectionHeader(panel, "Profile & Layout", 16, -420)

    -- Style Profile buttons
    local setDefaultsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    setDefaultsBtn:SetSize(140, 24)
    setDefaultsBtn:SetPoint("TOPLEFT", managementHeader, "BOTTOMLEFT", 8, -18)
    setDefaultsBtn:SetText("Set Current as Default")
    setDefaultsBtn:SetScript("OnClick", function()
        if NS.DB and NS.DB.Settings then
            NS.DB.DefaultStyle = {
                colors = SS_CopyTable(NS.DB.Settings.colors),
                fonts = SS_CopyTable(NS.DB.Settings.fonts),
                titleTexture = NS.DB.Settings.titleTexture
            }
            if _G.SS_Print then
                _G.SS_Print(
                    "Current style (colors, fonts, texture) has been set as your default profile.")
            end
        end
    end)
    setDefaultsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sets your current appearance as the baseline used by the 'Reset Styles' button.")
        GameTooltip:Show()
    end)
    setDefaultsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 24)
    resetBtn:SetPoint("LEFT", setDefaultsBtn, "RIGHT", 10, 0)
    resetBtn:SetText("Reset Styles")
    resetBtn:SetScript("OnClick", function()
        if NS.DB and NS.DB.DefaultStyle then
            local d = NS.DB.DefaultStyle
            NS.DB.Settings.colors = SS_CopyTable(d.colors)
            NS.DB.Settings.fonts = SS_CopyTable(d.fonts)
            NS.DB.Settings.titleTexture = d.titleTexture

            NS.UpdateColorsFromSettings()
            for _, s in ipairs(swatches) do s.UpdateSwatch() end

            bSize:SetValue(d.fonts.boss.size); bBold:SetChecked(d.fonts.boss.flags:find("THICKOUTLINE") ~= nil);
            nSize:SetValue(d.fonts.num.size); nBold:SetChecked(d.fonts.num.flags:find("THICKOUTLINE") ~= nil);
            cSize:SetValue(d.fonts.counter.size); cBold:SetChecked(d.fonts.counter.flags:find("THICKOUTLINE") ~= nil);
            tSize:SetValue(d.fonts.timer.size); tBold:SetChecked(d.fonts.timer.flags:find("THICKOUTLINE") ~= nil);
            hSize:SetValue(d.fonts.header.size); hBold:SetChecked(d.fonts.header.flags:find("THICKOUTLINE") ~= nil);

            UpdateSelection()
            NS.RefreshAllUI()
            if _G.SS_Print then _G.SS_Print("Styles reset to your default profile.") end
        end
    end)

    -- Layout buttons
    local setLayoutBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    setLayoutBtn:SetSize(140, 24)
    setLayoutBtn:SetPoint("TOPLEFT", setDefaultsBtn, "BOTTOMLEFT", 0, -10)
    setLayoutBtn:SetText("Set/Save Layout")
    setLayoutBtn:SetScript("OnClick", function()
        if _G.SS_Print then _G.SS_Print("Current window positions and column widths have been saved.") end
    end)
    setLayoutBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Confirms the current positioning and size of all frames.")
        GameTooltip:Show()
    end)
    setLayoutBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local resetLayoutBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetLayoutBtn:SetSize(140, 24)
    resetLayoutBtn:SetPoint("LEFT", setLayoutBtn, "RIGHT", 10, 0)
    resetLayoutBtn:SetText("Reset Layout")
    resetLayoutBtn:SetScript("OnClick", function()
        StaticPopup_Show("SPEEDSPLITS_RESET_LAYOUT")
    end)

    StaticPopupDialogs["SPEEDSPLITS_RESET_LAYOUT"] = {
        text = "Are you sure you want to RESET the layout (positions, sizes)? This will Reload UI.",
        button1 = "Reset Layout",
        button2 = "Cancel",
        OnAccept = function() NS.ResetLayout() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    local wipeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    wipeBtn:SetSize(160, 24)
    wipeBtn:SetPoint("TOPLEFT", setLayoutBtn, "BOTTOMLEFT", 0, -20)
    wipeBtn:SetText("Wipe All Records")
    wipeBtn:SetScript("OnClick", function() StaticPopup_Show("SPEEDSPLITS_WIPE_CONFIRM") end)

    StaticPopupDialogs["SPEEDSPLITS_WIPE_CONFIRM"] = {
        text = "Are you sure you want to WIPE all SpeedSplits data? This cannot be undone.",
        button1 = "WIPE DATA",
        button2 = "Cancel",
        OnAccept = function()
            NS.WipeDatabase(); NS.RefreshAllUI(); ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
    }

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end
