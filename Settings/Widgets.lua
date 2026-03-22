local _, NS = ...

local Widgets = {}
NS.Settings = NS.Settings or {}
NS.Settings.Widgets = Widgets

local DropDown = NS.UI.Templates.DropDown

Widgets.Registry = {}

function Widgets.CopyTable(src)
    return NS.Util.CopyTable(src)
end

function Widgets.CreateSlider(parent, label, minV, maxV, typeKey, field, width, callback)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(0.05)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(width or 160)
    s:SetScale(0.9)

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
        if callback then
            callback(value)
        end
    end)

    table.insert(Widgets.Registry, function()
        local current = (typeKey == "settings") and NS.DB.Settings[field] or NS.DB.Settings.fonts[typeKey][field]
        s:SetValue(current)
        text:SetText(label .. ": " .. (typeKey == "settings" and string.format("%.2f", current) or math.floor(current)))
    end)

    return s
end

function Widgets.VisualScalingSection(parent, label, typeKey)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(320, 50)

    local sub = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sub:SetPoint("TOPLEFT", 0, 0)
    sub:SetText(label)
    sub:SetTextColor(0.4, 0.8, 1)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 10, -14)
    slider:SetWidth(120)
    slider:SetScale(0.85)
    slider:SetMinMaxValues(8, 48)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    local sText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
    local val = NS.DB.Settings.fonts[typeKey].size
    slider:SetValue(val)
    sText:SetText("Size: " .. val)
    slider:SetScript("OnValueChanged", function(self, v)
        NS.DB.Settings.fonts[typeKey].size = math.floor(v)
        sText:SetText("Size: " .. math.floor(v))
        if NS.UpdateFontsOnly then
            NS.UpdateFontsOnly()
        end
    end)

    local dd = DropDown.Create(container, 80, 0.95)
    dd:SetPoint("LEFT", slider, "RIGHT", -15, -2)
    local fonts = {
        { text = "Friz", value = "Fonts\\FRIZQT__.TTF" },
        { text = "Arial", value = "Fonts\\ARIALN.TTF" },
        { text = "Skurri", value = "Fonts\\skurri.ttf" },
        { text = "Morph", value = "Fonts\\MORPHEUS.ttf" },
    }
    DropDown.Bind(dd, {
        buildItems = function()
            return fonts
        end,
        getValue = function()
            return NS.DB.Settings.fonts[typeKey].font
        end,
        setValue = function(value)
            NS.DB.Settings.fonts[typeKey].font = value
        end,
        onChanged = function()
            NS.RefreshAllUI()
        end,
    })

    local name = (NS.DB.Settings.fonts[typeKey].font:find("FRIZQT") and "Friz" or (NS.DB.Settings.fonts[typeKey].font:find("ARIAL") and "Arial" or (NS.DB.Settings.fonts[typeKey].font:find("skurri") and "Skurri" or "Morph")))
    DropDown.SetSelection(dd, NS.DB.Settings.fonts[typeKey].font, name)

    local bold = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    bold:SetPoint("LEFT", dd, "RIGHT", -5, 2)
    bold:SetScale(0.9)
    bold.Text:SetText("Bold")
    bold:SetChecked(NS.DB.Settings.fonts[typeKey].flags:find("THICKOUTLINE") ~= nil)
    bold:SetScript("OnClick", function(self)
        local font = NS.DB.Settings.fonts[typeKey]
        if self:GetChecked() then
            font.flags = "THICKOUTLINE"
        else
            font.flags = "OUTLINE"
        end
        NS.RefreshAllUI()
    end)

    table.insert(Widgets.Registry, function()
        local font = NS.DB.Settings.fonts[typeKey]
        slider:SetValue(font.size)
        sText:SetText("Size: " .. font.size)
        local fontName = (font.font:find("FRIZQT") and "Friz" or (font.font:find("ARIAL") and "Arial" or (font.font:find("skurri") and "Skurri" or "Morph")))
        DropDown.SetSelection(dd, font.font, fontName)
        bold:SetChecked(font.flags:find("THICKOUTLINE") ~= nil)
    end)

    return container
end

function Widgets.VisibilityRow(parent, label, field)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(320, 32)

    local sub = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("LEFT", 0, 0)
    sub:SetText(label)
    sub:SetWidth(120)
    sub:SetJustifyH("LEFT")

    local dd = DropDown.Create(container, 120, 0.95)
    dd:SetPoint("LEFT", sub, "RIGHT", 10, -2)
    local opts = {
        { text = "Instance Only", value = "instance" },
        { text = "Outdoor Only", value = "outdoor" },
        { text = "Both", value = "both" },
    }
    DropDown.Bind(dd, {
        buildItems = function()
            return opts
        end,
        getValue = function()
            return NS.DB.Settings.visibility[field] or "instance"
        end,
        setValue = function(value)
            NS.DB.Settings.visibility[field] = value
        end,
        onChanged = function()
            if NS.RefreshVisibility then
                NS.RefreshVisibility()
            end
        end,
    })

    local val = NS.DB.Settings.visibility[field] or "instance"
    DropDown.SetSelection(dd, val,
        (val == "instance" and "Instance Only" or (val == "outdoor" and "Outdoor Only" or "Both")))
    return container
end

function Widgets.SettingsDropDown(parent, label, field, opts, width)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(320, 32)

    local sub = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("LEFT", 0, 0)
    sub:SetText(label)
    sub:SetWidth(120)
    sub:SetJustifyH("LEFT")

    local dd = DropDown.Create(container, width or 120, 0.95)
    dd:SetPoint("LEFT", sub, "RIGHT", 10, -2)

    local normalizedOpts = {}
    for _, info in ipairs(opts or {}) do
        normalizedOpts[#normalizedOpts + 1] = {
            text = info.text or info.name,
            value = info.value,
        }
    end

    DropDown.Bind(dd, {
        buildItems = function()
            return normalizedOpts
        end,
        getValue = function()
            return NS.DB.Settings[field]
        end,
        setValue = function(value)
            NS.DB.Settings[field] = value
            if field == "speedrunMode" then
                NS.Run.speedrunMode = value
            end
        end,
        onChanged = function()
            if field == "speedrunMode" then
                if NS.RunLogic and NS.RunLogic.SyncAutoIgnoredBosses then
                    NS.RunLogic.SyncAutoIgnoredBosses()
                end
                if NS.RunLogic and NS.RunLogic.HandleIgnoreStateChange then
                    NS.RunLogic.HandleIgnoreStateChange()
                end
            end
            NS.RefreshAllUI()
        end,
    })

    local function Refresh()
        local val = NS.DB.Settings[field]
        DropDown.SetSelection(dd, val, DropDown.ResolveSelectedText(normalizedOpts, val))
    end

    Refresh()
    table.insert(Widgets.Registry, Refresh)
    return container
end

function Widgets.Header(parent, text)
    local headerGroup = CreateFrame("Frame", nil, parent)
    headerGroup:SetSize(280, 25)

    local h = headerGroup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetText(text)
    h:SetTextColor(1, 0.82, 0)

    local line = headerGroup:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
    line:SetSize(280, 1)
    line:SetColorTexture(1, 1, 1, 0.1)

    headerGroup.text = h
    headerGroup.line = line
    return headerGroup
end

function Widgets.ColorPicker(parent, label, key)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(22, 22)
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropBorderColor(0.5, 0.5, 0.5)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(1, 1, 1)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", f, "RIGHT", 8, 0)
    text:SetText(label)

    local function UpdateSwatch()
        if NS.Colors[key] then
            bg:SetVertexColor(NS.Colors[key].r, NS.Colors[key].g, NS.Colors[key].b, NS.Colors[key].a or 1)
        end
    end

    f:SetScript("OnClick", function()
        local c = NS.Colors[key]
        local originalHex = NS.DB.Settings.colors[key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            opacity = c.a or 1,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                NS.DB.Settings.colors[key] = string.format("%02x%02x%02x%02x", math.floor(a * 255), math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
                NS.UpdateColorsFromSettings()
                UpdateSwatch()
                NS.RefreshAllUI()
            end,
            cancelFunc = function()
                NS.DB.Settings.colors[key] = originalHex
                NS.UpdateColorsFromSettings()
                UpdateSwatch()
                NS.RefreshAllUI()
            end,
        })
    end)

    table.insert(Widgets.Registry, UpdateSwatch)
    UpdateSwatch()
    return f
end
