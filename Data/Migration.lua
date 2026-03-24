local _, NS = ...

NS.Migrations = NS.Migrations or {}

local Util = NS.Util

local WipeDatabaseOnFirstLogin = true
local CURRENT_SCHEMA_VERSION = 3
local FIRST_LOGIN_WIPE_FLAG = "FirstLoginSchemaWipeCompleted"

local function GetFirstLoginWipeFlag()
    return FIRST_LOGIN_WIPE_FLAG
end

local function ShouldWipeDataOnFirstLogin(db)
    return WipeDatabaseOnFirstLogin and type(db) == "table" and db[FIRST_LOGIN_WIPE_FLAG] ~= true
end

local function BuildFreshDatabase()
    return {}
end

local function EnsurePBTables(db)
    db.InstanceRoutes = type(db.InstanceRoutes) == "table" and db.InstanceRoutes or {}
    db.InstanceBestRoute = type(db.InstanceBestRoute) == "table" and db.InstanceBestRoute or {}
    db.InstanceBestLastBoss = type(db.InstanceBestLastBoss) == "table" and db.InstanceBestLastBoss or {}
    db.InstanceBestIgnored = type(db.InstanceBestIgnored) == "table" and db.InstanceBestIgnored or {}
end

local function NormalizePBNodeShape(node)
    node = node or {}
    if node.Segments and node.Segments ~= node.Splits then
        node.Splits = node.Segments
    end
    node.Splits = node.Splits or {}
    node.Segments = nil
    node.FullRun = node.FullRun or {}
    return node
end

local function NormalizeBossIndexTable(bossIndex)
    if type(bossIndex) ~= "table" then
        return {}
    end

    local converted = {}
    local hasLegacyPairs = false
    for key, value in pairs(bossIndex) do
        if type(key) == "string" and type(value) == "number" then
            converted[value] = key
            hasLegacyPairs = true
        elseif type(key) == "number" and type(value) == "string" then
            converted[key] = value
        elseif type(key) == "string" and type(value) == "string" then
            local numericKey = tonumber(key)
            if numericKey then
                converted[numericKey] = value
            end
        end
    end

    if hasLegacyPairs or next(converted) ~= nil then
        return converted
    end
    return {}
end

local function MigrateLegacyPersonalBests(db)
    local legacy = db.InstancePersonalBests or db.PersonalBests or db.bestSplits
    if type(legacy) ~= "table" then
        return
    end

    EnsurePBTables(db)

    for instanceName, oldNode in pairs(legacy) do
        if type(instanceName) == "string" and type(oldNode) == "table" and db.InstanceBestRoute[instanceName] == nil then
            local migrated = {
                Splits = Util.CopyTable(oldNode.Splits or oldNode.Segments or {}),
                FullRun = Util.CopyTable(oldNode.FullRun or oldNode.pbRun or {}),
            }
            NormalizePBNodeShape(migrated)
            db.InstanceBestRoute[instanceName] = migrated
        end
    end

    db.InstancePersonalBests = nil
    db.PersonalBests = nil
    db.bestSplits = nil
    db.pbBoss = nil
    db.pbRun = nil
end

local function MigrateRouteStorage(db)
    EnsurePBTables(db)

    for _, routes in pairs(db.InstanceRoutes) do
        if type(routes) == "table" then
            routes.BossIndex = NormalizeBossIndexTable(routes.BossIndex)
            for routeKey, node in pairs(routes) do
                if routeKey ~= "BossIndex" and type(node) == "table" then
                    NormalizePBNodeShape(node)
                end
            end
        end
    end

    for _, container in ipairs({
        db.InstanceBestRoute,
        db.InstanceBestLastBoss,
        db.InstanceBestIgnored,
    }) do
        for _, node in pairs(container) do
            if type(node) == "table" then
                NormalizePBNodeShape(node)
            end
        end
    end
end

local MIGRATIONS = {
    [1] = function(db)
        EnsurePBTables(db)
    end,
    [2] = function(db)
        MigrateLegacyPersonalBests(db)
        MigrateRouteStorage(db)
    end,
    [3] = function(db)
        MigrateRouteStorage(db)
    end,
}

local function ApplySavedVariablesMigrations(db)
    local version = tonumber(db and db.SchemaVersion or 0) or 0
    if version > CURRENT_SCHEMA_VERSION then
        version = CURRENT_SCHEMA_VERSION
    end

    EnsurePBTables(db)

    for nextVersion = version + 1, CURRENT_SCHEMA_VERSION do
        local migrate = MIGRATIONS[nextVersion]
        if migrate then
            migrate(db)
        end
        db.SchemaVersion = nextVersion
    end

    EnsurePBTables(db)
    MigrateRouteStorage(db)
    db.SchemaVersion = CURRENT_SCHEMA_VERSION
end

NS.Migrations.CurrentSchemaVersion = CURRENT_SCHEMA_VERSION
NS.Migrations.ApplySavedVariablesMigrations = ApplySavedVariablesMigrations
NS.Migrations.NormalizeBossIndexTable = NormalizeBossIndexTable
NS.Migrations.WipeDatabaseOnFirstLogin = WipeDatabaseOnFirstLogin
NS.Migrations.GetFirstLoginWipeFlag = GetFirstLoginWipeFlag
NS.Migrations.ShouldWipeDataOnFirstLogin = ShouldWipeDataOnFirstLogin
NS.Migrations.BuildFreshDatabase = BuildFreshDatabase
