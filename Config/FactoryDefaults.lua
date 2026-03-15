local _, NS = ...

NS.FactoryDefaults = {
    Settings = {
        colors = {
            darkRed = "ffcc0005",
            deepGreen = "ff10ff00",
            gold = "ffffd100",
            lightGreen = "ffff5b67",
            turquoise = "ff00e3d6",
            white = "ffffffff",
        },
        fonts = {
            boss = { size = 12, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            num = { size = 18, font = "Fonts\\ARIALN.TTF", flags = "OUTLINE" },
            timer = { size = 30, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            header = { size = 14, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            counter = { size = 15, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
            history = { size = 12, font = "Fonts\\FRIZQT__.TTF", flags = "OUTLINE" },
        },
        history = {
            entryScale = 1,
        },
        historyScale = 0.95,
        titleTexture = "dragonflight-landingpage-renownbutton-dream-hover",
        timerToastTexture = "UI-Centaur-Highlight-Bottom",
        timerToastScale = 1.6,
        paceThreshold1 = 5,
        paceThreshold2 = 10,
        showTimerToast = true,
        toastAllBosses = true,
        toastSoundID = 569143,
        toastSoundName = "Achievement",
        toastVolume = 0.8,
        visibility = {
            timer = "instance",
            splits = "instance",
        },
        speedrunMode = "all",
        showNPCViewModels = true,
    },
    ui = {
        cols = {
            pb = 85,
            split = 85,
            delta = 85,
        },
        frames = {
            boss = {
                w = 450,
                h = 200,
                point = "CENTER",
                relPoint = "CENTER",
                x = -7,
                y = -12,
            },
            history = {
                w = 850,
                h = 321,
                point = "CENTER",
                relPoint = "CENTER",
                x = 38,
                y = 4.5,
            },
            timer = {
                w = 245,
                h = 78,
                point = "CENTER",
                relPoint = "CENTER",
                x = -6.5,
                y = 131,
            },
        },
        historyCols = {
            date = 140,
            dungeon = 220,
            expansion = 114,
            result = 162,
            time = 74,
            diff = 107,
            delete = 30,
        },
    },
}
