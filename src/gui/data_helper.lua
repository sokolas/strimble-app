_M = {}

local triggersData = {}
local actionsData = {}
local stepsData = {}

function _M.setTriggers(triggers)
    triggersData = triggers
end

function _M.setActions(actions)
    actionsData = actions
end

function _M.setSteps(steps)
    stepsData = steps
end

function _M.findAction(predicate)
    local result = {}
    for k, v in pairs(actionsData) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

function _M.getActionData()
    local names = {}
    local ids = {}
    for k, v in pairs(actionsData) do
        if not v.isGroup then
            table.insert(names, v.name)
            table.insert(ids, v.dbId)
        end
    end
    return ids, names
end

return _M