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

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -24)
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
        NS.UpdateColorsFromSettings()
        for _, s in ipairs(swatches) do s.UpdateSwatch() end
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
