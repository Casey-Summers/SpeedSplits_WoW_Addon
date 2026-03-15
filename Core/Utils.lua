local _, NS = ...

local Util = NS.Util

NS.NowEpoch = NS.NowEpoch or time
NS.NowGameTime = NS.NowGameTime or GetTime

function Util.Clamp(value, minV, maxV)
    return math.max(minV, math.min(maxV, value))
end

function Util.CopyTable(src)
    local dest = {}
    for k, v in pairs(src or {}) do
        if type(v) == "table" then
            dest[k] = Util.CopyTable(v)
        else
            dest[k] = v
        end
    end
    return dest
end

function Util.ApplyResizeBounds(frame, minW, minH, maxW, maxH)
    if not frame then
        return
    end
    if frame.SetResizable then
        frame:SetResizable(true)
    end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW or 2500, maxH or 1600)
        return
    end
    if frame.SetMinResize then
        frame:SetMinResize(minW, minH)
    end
end

function Util.NormalizeName(text)
    if text == nil then
        return ""
    end
    return tostring(text):lower():gsub("[%-â€“â€”:,%s%p]", "")
end

function Util.FormatTime(seconds)
    if seconds == nil then
        return "--:--.---"
    end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    local ms = math.floor((s - math.floor(s)) * 1000 + 0.5)
    if ms >= 1000 then
        ms = 999
    end

    if h > 0 then
        return string.format("%d:%02d:%02d.%03d", h, m, math.floor(s), ms)
    elseif m > 0 then
        return string.format("%d:%02d.%03d", m, math.floor(s), ms)
    end
    return string.format("%d.%03d", math.floor(s), ms)
end

function Util.FormatDelta(delta)
    if delta == nil then
        return ""
    end
    return (delta >= 0 and "+" or "-") .. Util.FormatTime(math.abs(delta))
end

function Util.GetDungeonKey(mapID, difficultyID)
    return ("%d:%d"):format(tonumber(mapID) or 0, tonumber(difficultyID) or 0)
end

function Util.HistoryFilterDefaults()
    return {
        search = "",
        sortMode = "date",
        tier = 0,
        result = "Any",
    }
end

function Util.PackColorCode(a, r, g, b)
    local function Convert(v)
        return math.floor(Util.Clamp(v, 0, 1) * 255 + 0.5)
    end
    return string.format("|c%02x%02x%02x%02x", Convert(a), Convert(r), Convert(g), Convert(b))
end

function Util.HexToColor(hex)
    hex = tostring(hex or "ffffffff"):gsub("#", ""):lower()
    if #hex == 6 then
        hex = "ff" .. hex
    end
    if #hex ~= 8 then
        return { a = 1, r = 1, g = 1, b = 1, argb = "ffffffff", hex = "|cffffffff" }
    end

    local a = tonumber("0x" .. hex:sub(1, 2)) / 255
    local r = tonumber("0x" .. hex:sub(3, 4)) / 255
    local g = tonumber("0x" .. hex:sub(5, 6)) / 255
    local b = tonumber("0x" .. hex:sub(7, 8)) / 255
    return { a = a, r = r, g = g, b = b, argb = hex, hex = "|c" .. hex }
end

function Util.InterpolateColor(c1, c2, t)
    t = Util.Clamp(t, 0, 1)
    local a = (c1.a or 1) + ((c2.a or 1) - (c1.a or 1)) * t
    local r = c1.r + (c2.r - c1.r) * t
    local g = c1.g + (c2.g - c1.g) * t
    local b = c1.b + (c2.b - c1.b) * t
    return r, g, b, Util.PackColorCode(a, r, g, b)
end

function Util.ApplyBackgroundTexture(tex, name)
    if not tex or not name then
        return
    end
    tex:SetTexCoord(0, 1, 0, 1)
    local lowerName = name:lower()
    if lowerName:find("[\\/]") then
        local path = name
        if not path:lower():find("%.blp$") and not path:lower():find("%.tga$") then
            path = path .. ".blp"
        end
        tex:SetTexture(path)
    else
        tex:SetAtlas(name)
    end
    if lowerName:find("slate") then
        tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
end

local ScrollingTable

function Util.ResolveScrollingTable()
    if ScrollingTable and type(ScrollingTable.CreateST) == "function" then
        return ScrollingTable
    end

    local candidates = { _G["lib-st-v4.1.3"], _G["lib-st"], _G.LibScrollingTable, _G.ScrollingTable }
    local lib
    for _, candidate in ipairs(candidates) do
        if candidate and type(candidate.CreateST) == "function" then
            lib = candidate
            break
        end
    end

    if not lib and LibStub then
        for _, id in ipairs({ "lib-st", "LibScrollingTable-1.1", "LibScrollingTable-1.0", "LibScrollingTable", "ScrollingTable" }) do
            local ok, found = pcall(LibStub, id, true)
            if ok and found and type(found.CreateST) == "function" then
                lib = found
                break
            end
        end
    end

    if lib and not lib._isSpeedSplitsPatched then
        local oldSetDisplayCols = lib.SetDisplayCols
        lib.SetDisplayCols = function(self, cols)
            oldSetDisplayCols(self, cols)
            if self.head and self.head.cols and NS.UI and NS.UI.StyleHeaderCell then
                for i = 1, #self.head.cols do
                    NS.UI.StyleHeaderCell(self.head.cols[i], cols[i].align, 1.0, cols[i].name, "turquoise")
                end
            end
        end
        lib._isSpeedSplitsPatched = true
    end

    ScrollingTable = lib
    return ScrollingTable
end
