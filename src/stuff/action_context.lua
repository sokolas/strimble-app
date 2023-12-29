local dataHelper = require("src/stuff/data_helper")
local logger = Logger.create("context")

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
                local target = asJson and Json.encode(value) or tostring(value)
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

Mt.execute = function(self)
    for i, f in ipairs(self.steps) do
        local res = f(self)
        if not res then
            return false
        end
    end
    return true
end

Mt.__index = Mt

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

_M.var_pattern = var_pattern

--[[
    for user access:

    data: set by a trigger; contains all the information it's willing to pass. Can be modified by the steps, so they should properly handle any errors.


    used internally (should not be called or modified by steps):

    action: action object
    steps: resolved steps with their params

    execute() - runs the steps
    interpolate() - uses data field as the source of values to substitube; all the indices are separated by dots (numbers, too). Example: $users.0.name
]]

return _M