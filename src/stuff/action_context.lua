local dataHelper = require("src/stuff/data_helper")

local _M = {}

local Mt = {}

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