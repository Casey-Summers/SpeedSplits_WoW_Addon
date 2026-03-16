local _, NS = ...

local Util = NS.Util

local function BuildColors(colorSettings)
    local defaults = {
        gold = "ffffd100",
        white = "ffffffff",
        turquoise = "ff00bec3",
        deepGreen = "ff10ff00",
        lightGreen = "ffff5b67",
        redFade = "ffcc2232",
        darkRed = "ffcc0005",
    }

    local colors = {}
    for key, fallback in pairs(defaults) do
        colors[key] = Util.HexToColor((colorSettings and colorSettings[key]) or fallback)
    end

    return colors
end

local function EnsureColors()
    NS.Colors = NS.Colors or BuildColors()
    return NS.Colors
end

local function UpdateColorsFromSettings()
    EnsureColors()
    if not NS.DB or not NS.DB.Settings or not NS.DB.Settings.colors then
        return
    end

    for key, hex in pairs(NS.DB.Settings.colors) do
        local newColor = Util.HexToColor(hex)
        if NS.Colors[key] then
            local color = NS.Colors[key]
            color.r, color.g, color.b, color.a = newColor.r, newColor.g, newColor.b, newColor.a
            color.argb, color.hex = newColor.argb, newColor.hex
        else
            NS.Colors[key] = newColor
        end
    end
end

NS.EnsureColors = EnsureColors
NS.UpdateColorsFromSettings = UpdateColorsFromSettings

EnsureColors()
