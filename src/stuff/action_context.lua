local dataHelper = require("src/stuff/data_helper")
local logger = Logger.create("context")
local actionLogger = Logger.create("actions")

local _M = {}

local Mt = {}

local var_pattern = "%$+[%w%._]+"
local integer_pattern = "^%d+$"

Mt.interpolate = function(self, message, asJson)
    if not message or message == '' then
        return message
    end

    local output = message
    local start, finish = Lutf8.find(output, var_pattern)
    while start do
        local sub = Lutf8.sub(output, start, finish)
        if not string.startsWith(sub, '$$') then
            local var_expr = Lutf8.sub(sub, 2, finish)
            local paths = SplitMessage(var_expr, ".")
            local value = self.data
            local valid = true
            for i, v in ipairs(paths) do
                if v and v ~= '' then
                    if value then
                        if Lutf8.find(v, integer_pattern) then
                            value = value[tonumber(v)]
                        else
                            value = value[v]
                        end
                    end
                else
                    valid = false
                    break
                end
            end
            if valid then
                local target = value
                if asJson then
                    target = Json.encode(value)
                else
                    if value == nil then
                        target = ""
                    else
                        target = Serpent.simple(value)
                    end
                end
                output = Lutf8.sub(output, 1, start-1) .. target .. Lutf8.sub(output, finish+1)
                finish = finish - Lutf8.len(var_expr) + Lutf8.len(target)
            else
                logger.err("invalid variable", var_expr)
            end
        end
        start, finish = Lutf8.find(output, var_pattern, finish)
    end
    return output
end

local function validateJson(message)
    if not message or message == '' then
        return false, "can't be empty"
    end

    local output = message
    local start, finish = Lutf8.find(output, var_pattern)
    while start do
        local sub = Lutf8.sub(output, start, finish)
        if not string.startsWith(sub, '$$') then
            local var_expr = Lutf8.sub(sub, 2, finish)
            local paths = SplitMessage(var_expr, ".")
            local valid = true
            for i, v in ipairs(paths) do
                if (not v) or v == "" then
                    valid = false
                    break
                end
            end
            if valid then
                local target = "0"  -- some dummy value to satisfy the parser
                output = Lutf8.sub(output, 1, start-1) .. target .. Lutf8.sub(output, finish+1)
                finish = finish - Lutf8.len(var_expr) + Lutf8.len(target)
            else
                logger.err("invalid variable", var_expr)
            end
        end
        start, finish = Lutf8.find(output, var_pattern, finish)
    end
    local ok, err = pcall(Json.decode, output)
    if ok then
        return true
    else
        return false, "invalid JSON: " .. err
    end
end

Mt.__index = Mt

local function exec(ctx)
    for i, step in ipairs(ctx.steps) do
        actionLogger.log("step", i, step.name)
        local ok, stepResult = step.f(ctx, step.params)
        actionLogger.log("step", i, "result", ok, stepResult)
        if not ok then
            actionLogger.log("step returned false, aborting action")
            return  -- TODO false?
        else
            if step.params.saveVar and step.params.saveVar ~= "" then
                actionLogger.log("saving to", step.params.saveVar)
                ctx.data[step.params.saveVar] = stepResult
            end
        end
    end
end

local function exec_wrapper(queue, ctx)
    -- try
    xpcall(exec,
        function(err)
            actionLogger.err("Action execution failed", debug.traceback(err))
        end,
    ctx)
    -- finally
    actionLogger.log("action co finished", ctx.action)
    queue.running = false
    queue.co = nil
    table.remove(queue, 1)
    if #queue > 0 then
        Gui.frame:QueueEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ACTION_DISPATCH))
    else
        actionLogger.log(queue.name, "is empty")
    end
end

local function dispatchActions()
    local queues = dataHelper.getActionQueues()
    for k, queue in pairs(queues) do
        if #queue > 0 then
            if not queue.running then
                actionLogger.log("Processing queue", k, #queue)
                queue.running = true
                local ctx = queue[1]
                actionLogger.log("action", ctx.action)
                
                queue.co = coroutine.create(exec_wrapper)
                -- logger.log(coroutine.status(queue.co))
                actionLogger.log("executing steps for", ctx.action)
                local ok, res = coroutine.resume(queue.co, queue, ctx)
                actionLogger.log("co result", ok, res, queue.co)
                if queue.co then
                    actionLogger.log(coroutine.status(queue.co))
                end
            else
                actionLogger.log(k, "is still running")
            end
        else
            actionLogger.log(k, "is empty")
        end
    end
end

_M.create = function(data, action)
    local ctx = {}
    ctx.data = data
    ctx.action = action
    local steps = dataHelper.findStepsForAction(action)
    ctx.steps = {}
    for i, s in ipairs(steps) do
        table.insert(ctx.steps, {name = s.name, id = s.id, f = s.f, params = s.params})    -- resolve steps functions so the changes to them won't affect the execution
    end
    setmetatable(ctx, Mt)
    return ctx
end

_M.validateJson = validateJson
_M.dispatchActions = dispatchActions

_M.var_pattern = var_pattern

--[[
    for user access:

    data: set by a trigger; contains all the information it's willing to pass. Can be modified by the steps, so they should properly handle any errors.


    used internally (should not be called or modified by steps):

    action: action object
    steps: resolved steps with their params

    interpolate() - uses data field as the source of values to substitube; all the indices are separated by dots (numbers, too). Example: $users.0.name
]]

return _M