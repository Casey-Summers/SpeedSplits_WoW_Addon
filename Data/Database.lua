local _, NS = ...

local Util = NS.Util

local function NormalizeBestSplitsNode(db, instanceName)
    db.InstancePersonalBests = db.InstancePersonalBests or {}

    if db.InstancePersonalBests[instanceName] and not db.InstancePersonalBests[instanceName].Segments then
        local oldInstance = db.InstancePersonalBests[instanceName]
        local firstDiff
        for _, val in pairs(oldInstance) do
            if type(val) == "table" and val.pbBoss then
                firstDiff = val
                break
            end
        end

        if firstDiff then
            db.InstancePersonalBests[instanceName] = {
                Segments = firstDiff.pbBoss or {},
                FullRun = firstDiff.pbRun or {},
            }
        else
            db.InstancePersonalBests[instanceName] = {
                Segments = {},
                FullRun = {},
            }
        end
    end

    db.InstancePersonalBests[instanceName] = db.InstancePersonalBests[instanceName] or {
        Segments = {},
        FullRun = {},
    }
    return db.InstancePersonalBests[instanceName]
end

local function ApplySavedVariablesMigrations(db)
    db.InstancePersonalBests = db.InstancePersonalBests or {}

    for instanceName in pairs(db.InstancePersonalBests) do
        NormalizeBestSplitsNode(db, instanceName)
    end
end

local function EnsureDB()
    if SpeedSplitsDB == nil then
        SpeedSplitsDB = {}
    end

    SpeedSplitsDB.RunHistory = SpeedSplitsDB.RunHistory or SpeedSplitsDB.runs or {}
    SpeedSplitsDB.InstancePersonalBests = SpeedSplitsDB.InstancePersonalBests or SpeedSplitsDB.PersonalBests or SpeedSplitsDB.bestSplits or {}
    SpeedSplitsDB.Settings = SpeedSplitsDB.Settings or SpeedSplitsDB.settings or {}

    SpeedSplitsDB.runs = nil
    SpeedSplitsDB.bestSplits = nil
    SpeedSplitsDB.PersonalBests = nil
    SpeedSplitsDB.settings = nil
    SpeedSplitsDB.pbBoss = nil
    SpeedSplitsDB.pbRun = nil

    ApplySavedVariablesMigrations(SpeedSplitsDB)

    local fallbacks = NS.FactoryDefaults.Settings
    local settings = SpeedSplitsDB.Settings
    settings.colors = settings.colors or Util.CopyTable(fallbacks.colors)
    settings.fonts = settings.fonts or Util.CopyTable(fallbacks.fonts)
    settings.fonts.boss = settings.fonts.boss or Util.CopyTable(fallbacks.fonts.boss)
    settings.fonts.num = settings.fonts.num or Util.CopyTable(fallbacks.fonts.num)
    settings.fonts.timer = settings.fonts.timer or Util.CopyTable(fallbacks.fonts.timer)
    settings.fonts.header = settings.fonts.header or Util.CopyTable(fallbacks.fonts.header)
    settings.fonts.counter = settings.fonts.counter or Util.CopyTable(fallbacks.fonts.counter)
    settings.fonts.history = settings.fonts.history or Util.CopyTable(fallbacks.fonts.history)
    settings.history = settings.history or Util.CopyTable(fallbacks.history)
    settings.historyScale = settings.historyScale or fallbacks.historyScale
    settings.titleTexture = settings.titleTexture or fallbacks.titleTexture
    settings.timerToastTexture = settings.timerToastTexture or fallbacks.timerToastTexture
    settings.timerToastScale = settings.timerToastScale or fallbacks.timerToastScale
    settings.paceThreshold1 = settings.paceThreshold1 or fallbacks.paceThreshold1
    settings.paceThreshold2 = settings.paceThreshold2 or fallbacks.paceThreshold2
    if settings.showTimerToast == nil then
        settings.showTimerToast = fallbacks.showTimerToast
    end
    if settings.toastAllBosses == nil then
        settings.toastAllBosses = fallbacks.toastAllBosses
    end
    settings.toastSoundID = settings.toastSoundID or fallbacks.toastSoundID
    settings.toastSoundName = settings.toastSoundName or fallbacks.toastSoundName
    settings.toastVolume = settings.toastVolume or fallbacks.toastVolume
    settings.visibility = settings.visibility or Util.CopyTable(fallbacks.visibility)
    settings.speedrunMode = settings.speedrunMode or fallbacks.speedrunMode
    settings.ignoredBosses = settings.ignoredBosses or {}
    settings.autoIgnoredBosses = settings.autoIgnoredBosses or {}

    if not SpeedSplitsDB.DefaultStyle then
        SpeedSplitsDB.DefaultStyle = Util.CopyTable(NS.FactoryDefaults.Settings)
    end

    NS.DB = SpeedSplitsDB

    if NS.UI and NS.UI.history then
        NS.UI.history.filters = NS.UI.history.filters or Util.HistoryFilterDefaults()
    end

    return NS.DB
end

local function GetBestSplitsSubtable(instanceName)
    EnsureDB()
    instanceName = instanceName or (NS.Run and NS.Run.instanceName)
    if not instanceName or instanceName == "" then
        return nil
    end
    return NormalizeBestSplitsNode(NS.DB, instanceName)
end

local function ResetToFactorySettings()
    if SpeedSplitsDB then
        SpeedSplitsDB.Settings = Util.CopyTable(NS.FactoryDefaults.Settings)
        SpeedSplitsDB.DefaultStyle = Util.CopyTable(NS.FactoryDefaults.Settings)
        SpeedSplitsDB.ui = Util.CopyTable(NS.FactoryDefaults.ui)
        SpeedSplitsDB.DefaultLayout = { ui = Util.CopyTable(NS.FactoryDefaults.ui) }
        ReloadUI()
    end
end

local function WipeDatabase()
    EnsureDB()
    SpeedSplitsDB.InstancePersonalBests = {}
    SpeedSplitsDB.RunHistory = {}
    EnsureDB()
    if NS.UpdateColorsFromSettings then
        NS.UpdateColorsFromSettings()
    end
    if NS.RefreshAllUI then
        NS.RefreshAllUI()
    end
    if NS.Print then
        NS.Print("Records wiped. Reloading UI...")
    end
    ReloadUI()
end

local function ResetLayout()
    if SpeedSplitsDB then
        SpeedSplitsDB.ui = nil
        if NS.RefreshAllUI then
            NS.RefreshAllUI()
        end
        ReloadUI()
    end
end

local function DeleteRunRecord(record)
    EnsureDB()
    if not NS.DB or not NS.DB.RunHistory then
        return
    end
    for i, runRecord in ipairs(NS.DB.RunHistory) do
        if runRecord == record then
            table.remove(NS.DB.RunHistory, i)
            if NS.UI and NS.UI.RefreshHistoryTable then
                NS.UI.RefreshHistoryTable()
            end
            return
        end
    end
end

NS.Database.EnsureDB = EnsureDB
NS.Database.GetBestSplitsSubtable = GetBestSplitsSubtable
NS.Database.DeleteRunRecord = DeleteRunRecord
NS.ResetToFactorySettings = ResetToFactorySettings
NS.WipeDatabase = WipeDatabase
NS.ResetLayout = ResetLayout
NS.GetBestSplitsSubtable = GetBestSplitsSubtable
