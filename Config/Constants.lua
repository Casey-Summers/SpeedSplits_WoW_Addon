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
