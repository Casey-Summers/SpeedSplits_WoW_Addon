local _, NS = ...

local Const = NS.Const

Const.SPLITS_COL_MIN = {
    GLOBAL = 20,
    BOSS = 20,
    PB = 85,
    SPLIT = 85,
    DIFFERENCE = 20,
}

Const.SPLITS_COL_MAX = {
    PB_SPLIT = 260,
    DELTA = 200,
}

Const.SPLITS_LAYOUT = {
    GRIP_HALFWIDTH = 5,
    HEADER_H = 18,
    RIGHT_INSET_DEFAULT = 26,
    TOP_BAR_H = 28,
    TOP_BAR_GAP = 4,
    MIN_HEIGHT = 85,
}

Const.BOSS_MODEL = {
    LOAD_MAX_TRIES = 40,
    LOAD_RETRY_DELAY = 0.25,
    ZOOM = 0.75,
    PLACEHOLDER_ID = 10045,
}

Const.ENCOUNTER_JOURNAL = {
    INSTANCE_INDEX_MAX = 600,
    ENCOUNTER_INDEX_MAX = 80,
}

Const.RUN_HISTORY = {
    RUNS_MAX = 200,
    CRITERIA_MAX = 80,
    HISTORY_ICON_SCALE = 0.75,
}

Const.PB_TOAST = {
    SHINE_WIDTH = 150,
    SHINE_HEIGHT = 50,
}

Const.COL_MIN_BOSS = Const.SPLITS_COL_MIN.BOSS
Const.COL_MIN_NUM = Const.SPLITS_COL_MIN.PB
Const.COL_MIN_DELTA_TITLE = Const.SPLITS_COL_MIN.DIFFERENCE
Const.COL_MAX_PB_SPLIT = Const.SPLITS_COL_MAX.PB_SPLIT
Const.COL_MAX_DELTA = Const.SPLITS_COL_MAX.DELTA
Const.GRIP_HALFWIDTH = Const.SPLITS_LAYOUT.GRIP_HALFWIDTH
Const.HEADER_H = Const.SPLITS_LAYOUT.HEADER_H
Const.RIGHT_INSET_DEFAULT = Const.SPLITS_LAYOUT.RIGHT_INSET_DEFAULT
Const.TOP_BAR_H = Const.SPLITS_LAYOUT.TOP_BAR_H
Const.TOP_BAR_GAP = Const.SPLITS_LAYOUT.TOP_BAR_GAP
Const.SPLITS_TABLE_MIN_HEIGHT = Const.SPLITS_LAYOUT.MIN_HEIGHT
Const.BOSS_LOAD_MAX_TRIES = Const.BOSS_MODEL.LOAD_MAX_TRIES
Const.BOSS_LOAD_RETRY_DELAY = Const.BOSS_MODEL.LOAD_RETRY_DELAY
Const.BOSS_MODEL_ZOOM = Const.BOSS_MODEL.ZOOM
Const.EJ_INSTANCE_INDEX_MAX = Const.ENCOUNTER_JOURNAL.INSTANCE_INDEX_MAX
Const.EJ_ENCOUNTER_INDEX_MAX = Const.ENCOUNTER_JOURNAL.ENCOUNTER_INDEX_MAX
Const.RUNS_MAX = Const.RUN_HISTORY.RUNS_MAX
Const.CRITERIA_MAX = Const.RUN_HISTORY.CRITERIA_MAX
Const.HISTORY_ICON_SCALE = Const.RUN_HISTORY.HISTORY_ICON_SCALE
Const.PB_SHINE_WIDTH = Const.PB_TOAST.SHINE_WIDTH
Const.PB_SHINE_HEIGHT = Const.PB_TOAST.SHINE_HEIGHT
Const.BOSS_MODEL_ID = Const.BOSS_MODEL.PLACEHOLDER_ID

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
