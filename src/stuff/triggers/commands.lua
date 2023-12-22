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
    local commandDlg = dialogHelper.createDataDialog(Gui, "CommandDialog", {
        ["Trigger properties"] = {
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
            {
                name = "action",
                label = "Action",
                type = "combo"
            },
            {
                name = "enabled",
                text = "Enabled",
                type = "check",
                value = true
            }
        }
    },
    -- validation
    function(data, context)
        if not data.name or data.name == "" then
            return false, "Name can't be empty"
        elseif data.where == -1 then
            return false, "'Where' should be specified"
        elseif not data.text or data.text == "" then
            return false, "Text can't be empty"
        else
            if context and context.id then
                local duplicates = dataHelper.findTriggers(function(v)
                    return v.id ~= context.id and not v.isGroup and v.name == data.name
                end)
                if #duplicates > 0 then
                    return false, "Name must be unique"
                end
            else
                local duplicates = dataHelper.findTriggers(function(v)
                    return not v.isGroup and v.name == data.name
                end)
                if #duplicates > 0 then
                    return false, "Name must be unique"
                end
            end
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

local function addOrEdit(title, mode)
    return function(id, data)
        local actionIds, actionNames = dataHelper.getActionData()
        local init = { action = function(c) c:Set(actionNames) end }
        local dlgData = CopyTable(data)
        dlgData.action = nil
        for i = 1, #actionIds do
            if actionIds[i] == data.action then
                dlgData.action = actionNames[i]
                break
            end
        end
        local ctx = nil
        if mode == "edit" then
            ctx = { id = id }
        end
        local m, result = Gui.dialogs.CommandDialog.executeModal(title, dlgData, init, ctx)
        if m == wx.wxID_OK then
            local actionName = result.action
            result.action = nil
            for i = 1, #actionNames do
                if actionNames[i] == actionName then
                    result.action = actionIds[i]
                    break
                end
            end
            return result
        end
    end
end

local function createTwitchCmdsFolder(triggerListCtrl, rootTriggerItem)
    local twitchCmds = triggerListCtrl:AppendItem(rootTriggerItem, "Twitch commands", iconsHelper.pages.twitch,
        iconsHelper.pages.twitch)
    
    local treeItem = {
        id = twitchCmds:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "twitch_command",
        persistChildren = true,
        icon = iconsHelper.pages.scripts, -- for children
        getDescription = function(result)
            return result.text .. " (" .. commandWhere[result.where + 1] ..")"
        end,
        -- canDeleteChildren = true,
        add = addOrEdit("Add command", "add"),
        childEdit = addOrEdit("Edit command", "edit"),
        data = { -- default values for new children
            name = "Example command",
            text = "!hello",
            where = 0,
            enabled = true
        }
    }
    triggerListCtrl:SetItemText(twitchCmds, 1, "+") -- TODO make this dependent on canAddChildren
    return twitchCmds, treeItem
end

_M.commandsWhere = commandWhere
_M.createCommandDlg = createCommandDlg
_M.createTwitchCmdsFolder = createTwitchCmdsFolder
_M.matchCommands = matchCommands

return _M