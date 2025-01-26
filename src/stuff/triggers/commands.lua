local logger = Logger.create("commands")

local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local commandWhere = {
    "At the start",
    "Anywhere",
    "Exact match"
}

local triggerIcons = {}

local triggerIconPaths = {
    {path = "images/icons/twitch.png", name = "twitch_commands"},
}

local function registerTriggerIcons()
    triggerIcons = iconsHelper.registerTriggerIcons(triggerIconPaths)
end

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

local function matchCommand(trigger, context)
    local message = context.message
    -- local lmessage = Lutf8.lower(message)
    -- Log("checking ", v.name, v.data.text, "in", message, v.data.where, commandWhere[v.data.where + 1])
    logger.log("matching command", trigger, message)
    -- local res = { id = trigger.dbId, text = trigger.data.text, name = trigger.data.name, action = trigger.data.action }
    if trigger.data.where == 0 then
        if string.startsWith(message, trigger.data.text) then
            return true
        end
    elseif trigger.data.where == 1 then
        local found = Lutf8.find(message, trigger.data.text, 1, true)
        if found then
            return true
        end
    else
        if message == trigger.data.text then
            return true
        end
    end
    return false
end

local function createTwitchCmdsFolder(triggerListCtrl)
    local rootTriggerItem = triggerListCtrl:GetRootItem()
    local twitchCmds = triggerListCtrl:AppendItem(rootTriggerItem, "Twitch commands", triggerIcons.twitch_commands, triggerIcons.twitch_commands)
    
    local treeItem = {
        id = twitchCmds:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "twitch_command",
        persistChildren = true,
        icon = triggerIcons.active, -- for children
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
        },
        matches = matchCommand
    }
    return twitchCmds, treeItem
end

_M.commandsWhere = commandWhere
_M.registerTriggerIcons = registerTriggerIcons
_M.getTriggerTypes = function() return {"twitch_command"} end
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createTwitchCmdsFolder(triggerListCtrl)
end
_M.createCommandDlg = createCommandDlg

return _M