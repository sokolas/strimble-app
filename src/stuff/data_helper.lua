local logger = Logger.create("data_helper")

local _M = {}

local triggersData = {}
local actionsData = {}
local actionQueues = {}

local function _updateActions() end

local function byDbId(id)
    return function(v)
        return not v.isGroup and v.dbId == id
    end
end

local function enabledByDbId(id)
    return function(v)
        return not v.isGroup and v.data.enabled and v.dbId == id
    end
end

local function setTriggers(triggers)
    triggersData = triggers
end

local function setActions(actions)
    actionsData = actions
end

local function findAction(predicate)
    local result = {}
    for k, v in pairs(actionsData) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

local function findStepsForAction(action)  -- TODO actual steps implementation
    local r = {}
    local actions = findAction(byDbId(action))
    if actions and #actions > 0 then
        logger.log("triggered action found")
        if actions[1].steps then
            for i, v in ipairs(actions[1].steps) do
                logger.log("adding step", v.prototype.name, v.description)
                table.insert(r, {name = v.prototype.name or "", id = i, f = v.prototype.code, params = v.params})
            end
        else
            logger.log("steps empty")
        end
    end
    return r
end

local function findTriggers(predicate)
    local result = {}
    for k, v in pairs(triggersData) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

local function getActionData()
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

local function getActions()
    return actionsData
end

local function getActionQueue(name)
    if not actionQueues[name] then
        actionQueues[name] = {
            queue = {}
        }
    end
    return actionQueues[name]
end

local function getActionQueues()
    return actionQueues
end

local function setActionsUpdate(f)
    _updateActions = f
end

_M.byDbId = byDbId
_M.enabledByDbId = enabledByDbId

_M.setTriggers = setTriggers
_M.setActions = setActions

_M.setActionsUpdate = setActionsUpdate

_M.updateActions = function()
    _updateActions()
end

_M.findAction = findAction
_M.findStepsForAction = findStepsForAction
_M.findTriggers = findTriggers

_M.getActionData = getActionData
_M.getActions = getActions

_M.getActionQueue = getActionQueue
_M.getActionQueues = getActionQueues

return _M