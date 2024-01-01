local logger = Logger.create("commands")

local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local commandWhere = {
    "At the start",
    "Anywhere",
    "Exact match"
}

local _M = {}

local function createCommandDlg()
    local commandDlg = dialogHelper.createTriggerDialog(Gui, "CommandDialog", {
        {
            name = "Command properties",
            controls = {
                {
                    name = "name",
                    label = "Name",
                    type = "text"
                },
                {
                    name = "text",
                    label = "Text to activate",
                    type = "text"
                },
                {
                    name = "where",
                    label = "Where",
                    type = "choice",
                    choices = commandWhere
                },
            }
        }
    },
    -- validation
    function(data, context)
        if data.where == -1 then
            return false, "'Where' should be specified"
        elseif not data.text or data.text == "" then
            return false, "Text can't be empty"
        else
            return true
        end
    end)
    return commandDlg
end

local twitchCommandFilter = function(v)
    return v.type == "twitch_command" and (not v.isGroup) and v.data and v.data.enabled
end

local function matchCommands(message)
    local result = {}
    local lmessage = Lutf8.lower(message)

    for i, v in ipairs(dataHelper.findTriggers(twitchCommandFilter)) do
        -- if v.data.ignoreCase then   -- no use for now
        -- else
        -- Log("checking ", v.name, v.data.text, "in", message, v.data.where, commandWhere[v.data.where + 1])
        local res = { id = v.dbId, text = v.data.text, name = v.data.name, action = v.data.action }
        if v.data.where == 0 then
            if string.startsWith(message, v.data.text) then
                table.insert(result, res)
            end
        elseif v.data.where == 1 then
            local found = Lutf8.find(message, v.data.text, 1, true)
            if found then
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

local function createTwitchCmdsFolder(triggerListCtrl)
    local pages = iconsHelper.getPages()
    local rootTriggerItem = triggerListCtrl:GetRootItem()
    local twitchCmds = triggerListCtrl:AppendItem(rootTriggerItem, "Twitch commands", pages.twitch,
        pages.twitch)
    
    local treeItem = {
        id = twitchCmds:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "twitch_command",
        persistChildren = true,
        icon = pages.scripts, -- for children
        getDescription = function(result)
            return result.text .. " (" .. commandWhere[result.where + 1] ..")"
        end,
        dialog = Gui.dialogs.CommandDialog,
        add = "Add command",
        childEdit = "Edit command",
        data = { -- default values for new children
            name = "Example command",
            text = "!hello",
            where = 0,
            enabled = true
        }
    }
    return twitchCmds, treeItem
end

_M.commandsWhere = commandWhere
_M.getTriggerTypes = function() return {"twitch_command"} end
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createTwitchCmdsFolder(triggerListCtrl)
end
_M.createCommandDlg = createCommandDlg
_M.matchCommands = matchCommands

return _M