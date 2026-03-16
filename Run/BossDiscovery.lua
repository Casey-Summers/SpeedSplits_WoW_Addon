local _, NS = ...

local Const = NS.Const
local Util = NS.Util
local Discovery = NS.Discovery

local function ForEachEJInstance(callback)
    if not EJ_GetNumTiers or not EJ_SelectTier or not EJ_GetInstanceByIndex then
        return
    end
    local tierCount = EJ_GetNumTiers() or 0
    for tierIndex = 1, tierCount do
        EJ_SelectTier(tierIndex)
        for isRaid = 0, 1 do
            for instanceIndex = 1, Const.ENCOUNTER_JOURNAL.INSTANCE_INDEX_MAX do
                local instanceID, name = EJ_GetInstanceByIndex(instanceIndex, isRaid == 1)
                if not instanceID then
                    break
                end
                if callback(tierIndex, instanceID, name) then
                    return
                end
            end
        end
    end
end

local function FindJournalTierForInstanceID(targetID)
    targetID = tonumber(targetID)
    if not targetID then
        return nil
    end
    local found
    ForEachEJInstance(function(tierIndex, instanceID)
        if tonumber(instanceID) == targetID then
            found = tierIndex
            return true
        end
    end)
    return found
end

local function FindJournalTierAndInstanceIDByName(instanceName)
    local wanted = Util.NormalizeName(instanceName)
    if wanted == "" then
        return nil, nil
    end

    local foundTier, foundID
    ForEachEJInstance(function(tierIndex, instanceID, name)
        if Util.NormalizeName(name) == wanted then
            foundTier, foundID = tierIndex, instanceID
            return true
        end
    end)
    if foundID then
        return foundTier, foundID
    end

    local bestTier, bestID, bestLen = nil, nil, 999
    ForEachEJInstance(function(tierIndex, instanceID, name)
        local normalizedEJ = Util.NormalizeName(name)
        if normalizedEJ:find(wanted, 1, true) or wanted:find(normalizedEJ, 1, true) then
            local diff = math.abs(#normalizedEJ - #wanted)
            if diff < bestLen then
                bestLen = diff
                bestTier = tierIndex
                bestID = instanceID
            end
        end
    end)

    return bestTier, bestID
end

local function GetJournalTierAndInstanceIDForCurrentInstance()
    local instanceName, _, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    mapID = tonumber(mapID) or 0

    local journalID
    if EJ_GetInstanceForMap and C_Map and C_Map.GetBestMapForUnit then
        local bestMapID = C_Map.GetBestMapForUnit("player")
        if bestMapID then
            journalID = EJ_GetInstanceForMap(bestMapID)
        end
    end

    local tier
    if journalID then
        tier = FindJournalTierForInstanceID(journalID)
        return tier, journalID, mapID, tonumber(difficultyID) or 0, instanceName or ""
    end

    local foundTier, foundID = FindJournalTierAndInstanceIDByName(instanceName)
    return foundTier, foundID, mapID, tonumber(difficultyID) or 0, instanceName or ""
end

local function ExtractBossNameFromObjectiveText(desc)
    if type(desc) ~= "string" or desc == "" then
        return nil
    end

    local text = desc
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^%d+%s*/%s*%d+%s+", "")
    text = text:gsub("^Defeat:%s+", "")
    text = text:gsub("^Defeat%s+", "")
    text = text:gsub("^Kill%s+", "")
    text = text:gsub("^Slay%s+", "")
    text = text:gsub("%s+[Dd]efeated$", "")
    text = text:gsub("%s+[Ss]lain$", "")
    text = text:gsub("%s+[Kk]illed$", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
end

local function GetBossNamesFromObjectives()
    local names = {}

    if not C_ScenarioInfo or not C_ScenarioInfo.GetScenarioInfo or not C_ScenarioInfo.GetCriteriaInfo then
        return names, true
    end

    local inScenario = false
    if C_Scenario and C_Scenario.IsInScenario then
        inScenario = C_Scenario.IsInScenario() and true or false
    else
        local info = C_ScenarioInfo.GetScenarioInfo()
        inScenario = (info and info.currentStage and info.currentStage > 0) and true or false
    end
    if not inScenario then
        return names, true
    end

    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    if not scenarioInfo then
        return {}, false
    end

    local criteriaCount
    if C_ScenarioInfo.GetStepInfo then
        local _, _, numCriteria = C_ScenarioInfo.GetStepInfo()
        criteriaCount = tonumber(numCriteria)
    end

    local sawCriteria = false
    local sawStringDescription = false
    local maxCriteria = criteriaCount or Const.RUN_HISTORY.CRITERIA_MAX
    for criteriaIndex = 1, maxCriteria do
        local criteria = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
        if not criteria then
            break
        end
        sawCriteria = true

        local desc = criteria.description
        if type(desc) == "string" then
            sawStringDescription = true

            if NS.Debug and NS.Debug.objectiveTrace and NS.Print then
                NS.Print(("OBJ[%d] raw: %q"):format(criteriaIndex, desc))
            end

            local bossName = ExtractBossNameFromObjectiveText(desc)
            if NS.Debug and NS.Debug.objectiveTrace and NS.Print then
                NS.Print(("OBJ[%d] parsed: %s"):format(criteriaIndex, bossName and bossName or "<nil>"))
            end

            if bossName then
                names[#names + 1] = bossName
            end
        end
    end

    if not sawCriteria or not sawStringDescription then
        return {}, false
    end

    local out, seen = {}, {}
    for _, name in ipairs(names) do
        local key = Util.NormalizeName(name)
        if key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = name
        end
    end

    return out, true
end

local function GetEJBossesForInstance(journalInstanceID)
    local bosses = {}
    if not journalInstanceID or not EJ_SelectInstance or not EJ_GetEncounterInfoByIndex then
        return bosses
    end

    local ok = pcall(function()
        EJ_SelectInstance(journalInstanceID)
    end)
    if not ok then
        return bosses
    end

    for encounterIndex = 1, Const.ENCOUNTER_JOURNAL.ENCOUNTER_INDEX_MAX do
        local name, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, journalInstanceID)
        if not name then
            break
        end
        bosses[#bosses + 1] = {
            name = name,
            encounterID = tonumber(encounterID),
        }
    end

    return bosses
end

local function EJBossesToEntries(ejBosses)
    local entries = {}
    for _, boss in ipairs(ejBosses or {}) do
        local encounterID = tonumber(boss.encounterID)
        local key = encounterID and ("E:" .. encounterID) or ("N:" .. Util.NormalizeName(boss.name))
        entries[#entries + 1] = { key = key, name = boss.name, encounterID = encounterID }
    end
    return entries
end

local function BuildBossEntries()
    local tier, journalID = GetJournalTierAndInstanceIDForCurrentInstance()
    local objectiveNames, ready = GetBossNamesFromObjectives()
    if not ready then
        return {}, "none", tier, journalID, false
    end

    if #objectiveNames > 0 then
        local entries = {}
        for _, bossName in ipairs(objectiveNames) do
            local normalized = Util.NormalizeName(bossName)
            if normalized ~= "" then
                entries[#entries + 1] = { key = "N:" .. normalized, name = bossName }
            end
        end
        return entries, "objectives", tier, journalID, true
    end

    if journalID then
        local ejBosses = GetEJBossesForInstance(journalID)
        if #ejBosses > 0 then
            return EJBossesToEntries(ejBosses), "encounter_journal", tier, journalID, true
        end
    end
    return {}, "none", tier, journalID, true
end

Discovery.ForEachEJInstance = ForEachEJInstance
Discovery.FindJournalTierForInstanceID = FindJournalTierForInstanceID
Discovery.FindJournalTierAndInstanceIDByName = FindJournalTierAndInstanceIDByName
Discovery.GetJournalTierAndInstanceIDForCurrentInstance = GetJournalTierAndInstanceIDForCurrentInstance
Discovery.ExtractBossNameFromObjectiveText = ExtractBossNameFromObjectiveText
Discovery.GetBossNamesFromObjectives = GetBossNamesFromObjectives
Discovery.GetEJBossesForInstance = GetEJBossesForInstance
Discovery.EJBossesToEntries = EJBossesToEntries
Discovery.BuildBossEntries = BuildBossEntries

NS.GetEJBossesForInstance = GetEJBossesForInstance
NS.BuildBossEntries = BuildBossEntries
