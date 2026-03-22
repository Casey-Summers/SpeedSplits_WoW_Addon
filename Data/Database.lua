local _, NS = ...

local Util = NS.Util
local FORCED_DB_RESET_TOKEN = "2.0.0-major-default-reset"

local function LayoutDeepCopy(source)
    if NS.UI and NS.UI.DeepCopy then
        return NS.UI.DeepCopy(source)
    end
    return Util.CopyTable(source or {})
end

local function InitializeLayoutState()
    if NS.UI and NS.UI.InitializeDefaults then
        return NS.UI.InitializeDefaults()
    end

    SpeedSplitsDB.ui = LayoutDeepCopy(NS.FactoryDefaults.ui)
    SpeedSplitsDB.DefaultLayout = SpeedSplitsDB.DefaultLayout or {}
    SpeedSplitsDB.DefaultLayout.ui = LayoutDeepCopy(NS.FactoryDefaults.ui)
    return SpeedSplitsDB.ui
end

local function EnsurePBNodeShape(node)
    node = node or {}
    if node.Segments and node.Segments ~= node.Splits then
        node.Splits = node.Segments
    end
    node.Splits = node.Splits or {}
    node.Segments = node.Splits
    node.FullRun = node.FullRun or {}
    return node
end

local function EnsureRouteContainerShape(node)
    node = node or {}
    local normalizeBossIndex = NS.Migrations and NS.Migrations.NormalizeBossIndexTable
    node.BossIndex = normalizeBossIndex and normalizeBossIndex(node.BossIndex) or (node.BossIndex or {})
    return node
end

local function EnsurePBTables(db)
    db.InstanceRoutes = db.InstanceRoutes or {}
    db.InstanceBestRoute = db.InstanceBestRoute or {}
    db.InstanceBestLastBoss = db.InstanceBestLastBoss or {}
    db.InstanceBestIgnored = db.InstanceBestIgnored or {}
end

local function ApplySavedVariablesMigrations(db)
    if NS.Migrations and NS.Migrations.ApplySavedVariablesMigrations then
        NS.Migrations.ApplySavedVariablesMigrations(db)
    else
        EnsurePBTables(db)
    end
end

local function IsTestRunRecord(record)
    if type(record) ~= "table" then
        return false
    end

    if record.isTest == true or record.testRun == true then
        return true
    end

    local instanceName = tostring(record.instanceName or ""):lower()
    local bossSource = tostring(record.bossSource or ""):lower()
    if bossSource == "simulation" then
        return true
    end
    if instanceName:find("mock", 1, true) or instanceName:find("test", 1, true) then
        return true
    end

    return false
end

local function PurgeTestRunHistory(db)
    local history = db and db.RunHistory
    if type(history) ~= "table" then
        return
    end

    for i = #history, 1, -1 do
        if IsTestRunRecord(history[i]) then
            table.remove(history, i)
        end
    end
end

local function ApplyForcedVersionResetIfNeeded()
    if SpeedSplitsDB.__forcedResetToken == FORCED_DB_RESET_TOKEN then
        return
    end

    -- One-time full wipe for the major defaults/layout reset in this release.
    SpeedSplitsDB = {
        __forcedResetToken = FORCED_DB_RESET_TOKEN,
    }
end

local function EnsureDB()
    if SpeedSplitsDB == nil then
        SpeedSplitsDB = {}
    end

    if NS.Migrations and NS.Migrations.ShouldWipeDataOnFirstLogin and
        NS.Migrations.ShouldWipeDataOnFirstLogin(SpeedSplitsDB) then
        SpeedSplitsDB = (NS.Migrations.BuildFreshDatabase and NS.Migrations.BuildFreshDatabase()) or {}
    end

    ApplyForcedVersionResetIfNeeded()

    SpeedSplitsDB.RunHistory = SpeedSplitsDB.RunHistory or SpeedSplitsDB.runs or {}
    SpeedSplitsDB.Settings = SpeedSplitsDB.Settings or SpeedSplitsDB.settings or {}

    SpeedSplitsDB.runs = nil
    SpeedSplitsDB.settings = nil

    ApplySavedVariablesMigrations(SpeedSplitsDB)
    PurgeTestRunHistory(SpeedSplitsDB)

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
    if settings.showNPCViewModels == nil then
        settings.showNPCViewModels = fallbacks.showNPCViewModels
    end
    settings.ignoredBosses = settings.ignoredBosses or {}
    settings.autoIgnoredBosses = settings.autoIgnoredBosses or {}

    if not SpeedSplitsDB.DefaultStyle then
        SpeedSplitsDB.DefaultStyle = Util.CopyTable(NS.FactoryDefaults.Settings)
    end

    if not SpeedSplitsDB.ui then
        SpeedSplitsDB.ui = LayoutDeepCopy(NS.FactoryDefaults.ui)
    end

    SpeedSplitsDB.__forcedResetToken = FORCED_DB_RESET_TOKEN

    NS.DB = SpeedSplitsDB
    InitializeLayoutState()

    if NS.UI and NS.UI.history then
        NS.UI.history.filters = NS.UI.history.filters or Util.HistoryFilterDefaults()
    end

    return NS.DB
end

local function ApplyFactoryReset()
    EnsureDB()
    SpeedSplitsDB.Settings = LayoutDeepCopy(NS.FactoryDefaults.Settings)
    SpeedSplitsDB.DefaultStyle = LayoutDeepCopy(NS.FactoryDefaults.Settings)
    SpeedSplitsDB.ui = LayoutDeepCopy(NS.FactoryDefaults.ui)
    SpeedSplitsDB.DefaultLayout = { ui = LayoutDeepCopy(NS.FactoryDefaults.ui) }
    InitializeLayoutState()
    if NS.UI and NS.UI.ApplyAllLayouts then
        NS.UI.ApplyAllLayouts()
    end
end

local function ApplyDatabaseWipe()
    EnsureDB()
    SpeedSplitsDB.RunHistory = {}
    SpeedSplitsDB.InstanceRoutes = {}
    SpeedSplitsDB.InstanceBestRoute = {}
    SpeedSplitsDB.InstanceBestLastBoss = {}
    SpeedSplitsDB.InstanceBestIgnored = {}
    SpeedSplitsDB.runs = nil
    SpeedSplitsDB.settings = nil
end

local function WipeAllRecordsAndRebuild(simulateOnly)
    ApplyDatabaseWipe()
    EnsurePBTables(SpeedSplitsDB)
    if NS.UpdateColorsFromSettings then
        NS.UpdateColorsFromSettings()
    end
    if NS.RefreshAllUI then
        NS.RefreshAllUI()
    end
    if simulateOnly then
        return
    end
    if NS.Print then
        NS.Print("All records wiped. Rebuilding tables and reloading UI...")
    end
    ReloadUI()
end

local function WipeDatabase(simulateOnly)
    WipeAllRecordsAndRebuild(simulateOnly)
end

local function SaveDefaultLayout()
    EnsureDB()
    if NS.UI and NS.UI.CaptureCurrentLayout then
        NS.UI.CaptureCurrentLayout()
    end
    SpeedSplitsDB.DefaultLayout = { ui = LayoutDeepCopy(SpeedSplitsDB.ui or {}) }
    InitializeLayoutState()
end

local function ApplyLayoutReset()
    EnsureDB()
    local defaultUI
    if SpeedSplitsDB.DefaultLayout and SpeedSplitsDB.DefaultLayout.ui then
        defaultUI = LayoutDeepCopy(SpeedSplitsDB.DefaultLayout.ui)
    else
        defaultUI = LayoutDeepCopy(NS.FactoryDefaults.ui)
    end
    SpeedSplitsDB.ui = defaultUI
    InitializeLayoutState()
    if NS.UI and NS.UI.ApplyAllLayouts then
        NS.UI.ApplyAllLayouts()
    end
end

local function ResetLayout(simulateOnly)
    if SpeedSplitsDB then
        ApplyLayoutReset()
        if NS.RefreshAllUI then
            NS.RefreshAllUI()
        end
        if simulateOnly then
            return
        end
        ReloadUI()
    end
end

local function ResetToFactorySettings(simulateOnly)
    if SpeedSplitsDB then
        ApplyFactoryReset()
        if simulateOnly then
            return
        end
        ReloadUI()
    end
end

local function GetInstanceRoutes(instanceName, create)
    EnsureDB()
    if not instanceName or instanceName == "" then
        return nil
    end

    local routes = NS.DB.InstanceRoutes[instanceName]
    if not routes and create ~= false then
        routes = { BossIndex = {} }
        NS.DB.InstanceRoutes[instanceName] = routes
    end

    if routes then
        EnsureRouteContainerShape(routes)
    end
    return routes
end

local function GetPBNode(container, instanceName, create)
    EnsureDB()
    if not instanceName or instanceName == "" then
        return nil
    end

    local node = container[instanceName]
    if not node and create ~= false then
        node = { Splits = {}, FullRun = {} }
        container[instanceName] = node
    end

    if node then
        EnsurePBNodeShape(node)
    end
    return node
end

local function GetBestRouteNode(instanceName, create)
    return GetPBNode(NS.DB.InstanceBestRoute, instanceName, create)
end

local function GetBestLastBossNode(instanceName, create)
    return GetPBNode(NS.DB.InstanceBestLastBoss, instanceName, create)
end

local function GetBestIgnoredNode(instanceName, create)
    return GetPBNode(NS.DB.InstanceBestIgnored, instanceName, create)
end

local function GetRouteNode(instanceName, routeKey, create)
    if not routeKey or routeKey == "" then
        return nil
    end

    local routes = GetInstanceRoutes(instanceName, create)
    if not routes then
        return nil
    end

    local node = routes[routeKey]
    if not node and create ~= false then
        node = { Splits = {}, FullRun = {} }
        routes[routeKey] = node
    end

    if node then
        EnsurePBNodeShape(node)
    end
    return node
end

local function EnsureBossIndex(instanceName, entries)
    local routes = GetInstanceRoutes(instanceName, true)
    if not routes then
        return nil
    end

    local bossIndex = routes.BossIndex
    local nextIndex = 0
    for key in pairs(bossIndex) do
        local routeIndex = tonumber(key)
        if routeIndex and routeIndex > nextIndex then
            nextIndex = routeIndex
        end
    end

    for _, entry in ipairs(entries or {}) do
        local bossName = entry and (entry.name or entry.bossName)
        if bossName and bossName ~= "" then
            local routeIndex = nil
            for existingIndex, existingBossName in pairs(bossIndex) do
                if existingBossName == bossName then
                    routeIndex = tonumber(existingIndex)
                    break
                end
            end
            if not routeIndex then
                nextIndex = nextIndex + 1
                routeIndex = nextIndex
                bossIndex[routeIndex] = bossName
            end
            entry.routeIndex = routeIndex
        end
    end

    return bossIndex
end

local function BuildRouteKeyFromEntries(entries)
    local indices = {}
    for _, entry in ipairs(entries or {}) do
        local routeIndex = tonumber(entry and entry.routeIndex)
        if routeIndex then
            indices[#indices + 1] = tostring(routeIndex)
        end
    end
    return table.concat(indices, ",")
end

local function EnsureDefaultRoute(instanceName, entries)
    EnsureBossIndex(instanceName, entries)
    local routeKey = BuildRouteKeyFromEntries(entries)
    if routeKey ~= "" then
        GetRouteNode(instanceName, routeKey, true)
    end
    return routeKey
end

local function CopyFullRunMeta(meta, duration)
    return {
        duration = duration,
        endedAt = meta.endedAt,
        instanceName = meta.instanceName,
        tier = meta.tier,
        difficultyID = meta.difficultyID,
        difficultyName = meta.difficultyName,
        mapID = meta.mapID,
    }
end

local function UpdateBestSplit(node, routeIndex, splitTime)
    if not node or type(routeIndex) ~= "number" or type(splitTime) ~= "number" then
        return
    end

    splitTime = Util.RoundTime(splitTime)
    local existing = tonumber(node.Splits[routeIndex])
    if not existing or existing <= 0 or splitTime < existing then
        node.Splits[routeIndex] = splitTime
    end
end

local function UpdateBestRun(node, meta, duration)
    if not node or type(duration) ~= "number" then
        return
    end

    duration = Util.RoundTime(duration)
    local current = node.FullRun
    if not current or not current.duration or duration < current.duration then
        node.FullRun = CopyFullRunMeta(meta, duration)
    end
end

local function ApplyBossIndexFromRecord(instanceName, record)
    local routes = GetInstanceRoutes(instanceName, true)
    if not routes then
        return
    end

    for _, boss in ipairs(record.bosses or {}) do
        local routeIndex = tonumber(boss and boss.routeIndex)
        local bossName = boss and boss.name
        if routeIndex and bossName and bossName ~= "" then
            routes.BossIndex[routeIndex] = bossName
        end
    end
end

local function PromoteBestRoute(instanceName)
    local routes = GetInstanceRoutes(instanceName, false)
    if not routes then
        NS.DB.InstanceBestRoute[instanceName] = nil
        return
    end

    local bestKey
    local bestNode
    local bestDuration

    for routeKey, node in pairs(routes) do
        if routeKey ~= "BossIndex" and type(node) == "table" then
            local duration = tonumber(node.FullRun and node.FullRun.duration)
            if duration and duration > 0 and (not bestDuration or duration < bestDuration) then
                bestDuration = duration
                bestKey = routeKey
                bestNode = node
            end
        end
    end

    if not bestKey or not bestNode then
        NS.DB.InstanceBestRoute[instanceName] = nil
        return
    end

    local promoted = EnsurePBNodeShape(Util.CopyTable(bestNode))
    promoted.RouteKey = bestKey
    NS.DB.InstanceBestRoute[instanceName] = promoted
end

local function ApplyRouteRecord(record)
    if type(record) ~= "table" or record.pbMode ~= "route" or record.success ~= true then
        return
    end

    local instanceName = record.instanceName
    local routeKey = tostring(record.routeKey or "")
    if instanceName == nil or instanceName == "" or routeKey == "" then
        return
    end

    ApplyBossIndexFromRecord(instanceName, record)

    local node = GetRouteNode(instanceName, routeKey, true)
    if not node then
        return
    end

    for _, boss in ipairs(record.bosses or {}) do
        local routeIndex = tonumber(boss and boss.routeIndex)
        local splitTime = routeIndex and record.kills and record.kills[boss.key] or nil
        if routeIndex and type(splitTime) == "number" then
            UpdateBestSplit(node, routeIndex, splitTime)
        end
    end

    if type(record.duration) == "number" then
        UpdateBestRun(node, record, record.duration)
    end

    PromoteBestRoute(instanceName)
end

local function ApplyIgnoredRecord(record)
    if type(record) ~= "table" or record.pbMode ~= "ignored" or record.hasIgnoredEntries ~= true then
        return
    end

    local instanceName = record.instanceName
    if not instanceName or instanceName == "" then
        return
    end

    local node = GetBestIgnoredNode(instanceName, true)
    if not node then
        return
    end

    for _, boss in ipairs(record.bosses or {}) do
        local routeIndex = tonumber(boss and boss.routeIndex)
        local splitTime = routeIndex and record.kills and record.kills[boss.key] or nil
        if routeIndex and type(splitTime) == "number" then
            UpdateBestSplit(node, routeIndex, splitTime)
        end
    end

    if record.success and type(record.duration) == "number" then
        UpdateBestRun(node, record, record.duration)
    end
end

local function ResolveLastBossRouteIndex(record)
    if type(record.lastBossIndex) == "number" then
        return record.lastBossIndex
    end

    local bestSplit = nil
    local bestIndex = nil
    for _, boss in ipairs(record.bosses or {}) do
        local routeIndex = tonumber(boss and boss.routeIndex)
        local splitTime = routeIndex and record.kills and record.kills[boss.key] or nil
        if routeIndex and type(splitTime) == "number" and (bestSplit == nil or splitTime > bestSplit) then
            bestSplit = splitTime
            bestIndex = routeIndex
        end
    end
    return bestIndex
end

local function ApplyLastBossRecord(record)
    if type(record) ~= "table" or record.pbMode ~= "last" or record.success ~= true then
        return
    end

    local instanceName = record.instanceName
    if not instanceName or instanceName == "" then
        return
    end

    local routeIndex = ResolveLastBossRouteIndex(record)
    local node = GetBestLastBossNode(instanceName, true)
    if not node or not routeIndex or type(record.duration) ~= "number" then
        return
    end

    UpdateBestSplit(node, routeIndex, record.duration)
    UpdateBestRun(node, record, record.duration)
end

local function RebuildPBDataFromHistory()
    EnsureDB()
    NS.DB.InstanceRoutes = {}
    NS.DB.InstanceBestRoute = {}
    NS.DB.InstanceBestLastBoss = {}
    NS.DB.InstanceBestIgnored = {}

    for _, record in ipairs(NS.DB.RunHistory or {}) do
        if record.pbMode == "route" then
            ApplyRouteRecord(record)
        elseif record.pbMode == "ignored" then
            ApplyIgnoredRecord(record)
        elseif record.pbMode == "last" then
            ApplyLastBossRecord(record)
        end
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
            RebuildPBDataFromHistory()
            if NS.UI and NS.UI.RefreshHistoryTable then
                NS.UI.RefreshHistoryTable()
            end
            return
        end
    end
end

local function GetHistoryPBNode(record)
    EnsureDB()
    if type(record) ~= "table" or not record.instanceName then
        return nil
    end

    local mode = tostring(record.pbMode or record.speedrunMode or "route")
    if mode == "last" then
        return GetBestLastBossNode(record.instanceName, false)
    elseif mode == "ignored" then
        return GetBestIgnoredNode(record.instanceName, false)
    end
    return GetBestRouteNode(record.instanceName, false)
end

NS.Database.EnsureDB = EnsureDB
NS.Database.DeleteRunRecord = DeleteRunRecord
NS.Database.IsTestRunRecord = IsTestRunRecord
NS.Database.PurgeTestRunHistory = PurgeTestRunHistory
NS.Database.ApplyFactoryReset = ApplyFactoryReset
NS.Database.ApplyDatabaseWipe = ApplyDatabaseWipe
NS.Database.WipeAllRecordsAndRebuild = WipeAllRecordsAndRebuild
NS.Database.ApplyLayoutReset = ApplyLayoutReset
NS.Database.ResetLayout = ResetLayout
NS.Database.ResetToFactorySettings = ResetToFactorySettings
NS.Database.GetInstanceRoutes = GetInstanceRoutes
NS.Database.GetRouteNode = GetRouteNode
NS.Database.GetBestRouteNode = GetBestRouteNode
NS.Database.GetBestLastBossNode = GetBestLastBossNode
NS.Database.GetBestIgnoredNode = GetBestIgnoredNode
NS.Database.EnsureBossIndex = EnsureBossIndex
NS.Database.BuildRouteKeyFromEntries = BuildRouteKeyFromEntries
NS.Database.EnsureDefaultRoute = EnsureDefaultRoute
NS.Database.UpdateBestSplit = UpdateBestSplit
NS.Database.UpdateBestRun = UpdateBestRun
NS.Database.PromoteBestRoute = PromoteBestRoute
NS.Database.ApplyRouteRecord = ApplyRouteRecord
NS.Database.ApplyIgnoredRecord = ApplyIgnoredRecord
NS.Database.ApplyLastBossRecord = ApplyLastBossRecord
NS.Database.RebuildPBDataFromHistory = RebuildPBDataFromHistory
NS.Database.GetHistoryPBNode = GetHistoryPBNode
NS.Database.GetBestSplitsSubtable = GetBestRouteNode
NS.ResetToFactorySettings = ResetToFactorySettings
NS.WipeDatabase = WipeDatabase
NS.WipeAllRecordsAndRebuild = WipeAllRecordsAndRebuild
NS.ResetLayout = ResetLayout
NS.SaveDefaultLayout = SaveDefaultLayout
NS.GetBestSplitsSubtable = GetBestRouteNode
