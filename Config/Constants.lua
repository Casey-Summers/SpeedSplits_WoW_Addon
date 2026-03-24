local _, NS = ...

local Const = NS.Const

Const.SPLITS_COL_MIN = {
    GLOBAL = 20,
    BOSS = 110,
    PB = 95,
    SPLIT = 95,
    DIFFERENCE = 115,
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
    TOTALS_X_OFFSET = 5,
}

Const.SPLITS_DEFAULTS = {
    BOSS_COLUMNS = {
        pb = 95,
        split = 100,
        diff = 115,
    },
    HISTORY_COLUMNS = {
        date = 140,
        dungeon = 220,
        expansion = 140,
        result = 130,
        mode = 80,
        time = 80,
        diff = 120,
        delete = 30,
    },
}

Const.UI_TEXT = {
    SECTION_TOTAL_PLACEHOLDER = "--:--.--",
    RELOAD_INVALID_WARNING = "Cannot Reload during a Speedrun.\n|cffff2020This run is invalid.|r",
    BOSS_HEADER_LABELS = { "", "PB", "Split", "Diff" },
    DEVTOOLS_BOSS_COLUMN_LABELS = { "Boss", "PB", "Split", "Diff" },
}

Const.ALIGNED_TIME = {
    SYMBOL_PAD = -2.75,
    SIGN_PAD = -2.75,
}

Const.UI_POPUPS = {
    WIPE_CONFIRM_ID = "SPEEDSPLITS_WIPE_CONFIRM",
    FACTORY_RESET_ID = "SPEEDSPLITS_FACTORY_RESET",
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
