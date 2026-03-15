local _, NS = ...

local Const = NS.Const

Const.COL_MAX_PB_SPLIT = 260
Const.COL_MAX_DELTA = 200
Const.COL_MIN_BOSS = 20
Const.COL_MIN_NUM = 85
Const.COL_MIN_DELTA_TITLE = 85
Const.GRIP_HALFWIDTH = 5
Const.HEADER_H = 18
Const.RIGHT_INSET_DEFAULT = 26
Const.TOP_BAR_H = 28
Const.TOP_BAR_GAP = 4
Const.BOSS_LOAD_MAX_TRIES = 40
Const.BOSS_LOAD_RETRY_DELAY = 0.25
Const.EJ_INSTANCE_INDEX_MAX = 600
Const.EJ_ENCOUNTER_INDEX_MAX = 80
Const.RUNS_MAX = 200
Const.CRITERIA_MAX = 80
Const.HISTORY_ICON_SCALE = 0.75
Const.BOSS_MODEL_ZOOM = 0.75
Const.PB_SHINE_WIDTH = 150
Const.PB_SHINE_HEIGHT = 50

Const.HISTORY_COL_DEFAULTS = {
    date = 130,
    dungeon = 220,
    expansion = 140,
    time = 80,
    result = 130,
    mode = 80,
    diff = 120,
    delete = 30,
}

local function Clamp(value, minV, maxV)
    if value < minV then
        return minV
    end
    if value > maxV then
        return maxV
    end
    return value
end

local function HexToColor(hex)
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

    return {
        a = Clamp(a, 0, 1),
        r = Clamp(r, 0, 1),
        g = Clamp(g, 0, 1),
        b = Clamp(b, 0, 1),
        argb = hex,
        hex = "|c" .. hex,
    }
end

NS.Colors = {
    gold = HexToColor("ffffd100"),
    white = HexToColor("ffffffff"),
    turquoise = HexToColor("ff00bec3"),
    deepGreen = HexToColor("ff10ff00"),
    lightGreen = HexToColor("ffff5b67"),
    redFade = HexToColor("ffcc2232"),
    darkRed = HexToColor("ffcc0005"),
}
