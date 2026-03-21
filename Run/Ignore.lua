local _, NS = ...

local function GetIgnoreTables(instanceName)
    local settings = NS.DB and NS.DB.Settings
    if not settings or not instanceName or instanceName == "" then
        return nil, nil
    end

    settings.ignoredBosses = settings.ignoredBosses or {}
    settings.autoIgnoredBosses = settings.autoIgnoredBosses or {}
    settings.ignoredBosses[instanceName] = settings.ignoredBosses[instanceName] or {}
    settings.autoIgnoredBosses[instanceName] = settings.autoIgnoredBosses[instanceName] or {}

    return settings.ignoredBosses[instanceName], settings.autoIgnoredBosses[instanceName]
end

local function SyncAutoIgnoredBosses()
    local instanceName = NS.Run and NS.Run.instanceName
    if not instanceName or instanceName == "" then
        return
    end

    local manualIgnored, autoIgnored = GetIgnoreTables(instanceName)
    if not manualIgnored or not autoIgnored then
        return
    end

    wipe(autoIgnored)
end

NS.RunLogic.GetIgnoreTables = GetIgnoreTables
NS.RunLogic.SyncAutoIgnoredBosses = SyncAutoIgnoredBosses
