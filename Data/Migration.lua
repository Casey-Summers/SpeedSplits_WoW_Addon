local _, NS = ...

local Migration = {}
NS.Database.Migration = Migration

function Migration.NormalizeBestSplitsNode(db, instanceName)
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
