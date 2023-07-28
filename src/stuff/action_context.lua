local dataHelper = require("src/stuff/data_helper")
local logger = Logger.create("context")

local _M = {}

local Mt = {}

local var_pattern = "%$+[%w%.]+"

Mt.interpolate = function(self, message)
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
                        value = value[v]
                    end
                else
                    valid = false
                    break
                end
            end
            if valid then
                local target = tostring(value)
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

return _M