local logger = Logger.create("data_helper")

_M = {}

local twitch_steps = require("src.stuff.steps.twitch_steps")

local triggersData = {}
local actionsData = {}
local stepsData = {}
local actionQueues = {}

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

local function setSteps(steps)
    stepsData = steps
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
    logger.log(action)
    local actions = findAction(byDbId(action))
    if actions and #actions > 0 then
        for i, v in ipairs(actions) do
            table.insert(r, {name = v.name or "", id = i, f = twitch_steps.sendMessage, params = {message = (v.data.description or "") .. " triggered"}})
        end
    end
    -- table.insert(r, {name = "example action 1", id = 1, f = function(ctx, params) local ok, res = NetworkManager.get("https://sokolas.org"); Log(ok, res.body); return true end})
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

_M.byDbId = byDbId
_M.enabledByDbId = enabledByDbId

_M.setTriggers = setTriggers
_M.setActions = setActions
_M.setSteps = setSteps

_M.findAction = findAction
_M.findStepsForAction = findStepsForAction
_M.findTriggers = findTriggers

_M.getActionData = getActionData

_M.getActionQueue = getActionQueue
_M.getActionQueues = getActionQueues

return _M