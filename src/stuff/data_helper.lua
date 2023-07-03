_M = {}

local triggersData = {}
local actionsData = {}
local stepsData = {}
local actionQueues = {}

function _M.setTriggers(triggers)
    triggersData = triggers
end

function _M.setActions(actions)
    actionsData = actions
end

function _M.setSteps(steps)
    stepsData = steps
end

function _M.findStepsForAction(action)  -- TODO actual steps implementation
    local r = {}
    table.insert(r, {f = function(ctx) print(ctx.data.user.name) end})
    return r
end

function _M.byDbId(id)
    return function(v)
        return v.dbId == id
    end
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

function _M.findTriggers(predicate)
    local result = {}
    for k, v in pairs(triggersData) do
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

function _M.getActionQueue(name)
    if not actionQueues[name] then
        actionQueues[name] = {
            queue = {}
        }
    end
    return actionQueues[name]
end

return _M