local dataHelper = require("src.stuff.data_helper")
local commandWhere = {
    "At the start",
    "Anywhere",
    "Exact match"
}

_M = {}

local twitchCommandFilter = function(v)
    return v.type == "twitch_command" and not v.isGroup and v.data and v.data.enabled
end

_M.matchCommands = function(message)
    local result = {}
    local lmessage = Lutf8.lower(message)

    for i, v in ipairs(dataHelper.findTriggers(twitchCommandFilter)) do
        -- if v.data.ignoreCase then   -- no use for now
        -- else
        -- Log("checking ", v.name, v.data.text, v.data.where, commandWhere[v.data.where + 1])
        local res = { id = v.dbId, text = v.data.text, name = v.data.name, action = v.data.action }
        if v.data.where == 0 then
            if string.startsWith(message, v.data.text) then
                table.insert(result, res)
            end
        elseif v.data.where == 1 then
            if Lutf8.find(message, v.data.text, 1, true) then
                table.insert(result, res)
            end
        else
            if message == v.data.text then
                table.insert(result, res)
            end
        end
        -- end
    end
    if #result then
        return result
    else
        return nil
    end
end

_M.commandsWhere = commandWhere

return _M