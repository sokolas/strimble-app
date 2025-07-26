local logger = Logger.create("commands")

local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local wxtimers = require("src/stuff/wxtimers")

local commandWhere = {
    "At the start",
    "Anywhere",
    "Exact match"
}

local triggerIcons = {}

local cooldownsTimer = nil
local cooldownsCounter = 0
local globalCooldowns = {}

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
                {
                    name = "globalCooldown",
                    label = "Global cooldown (s)",
                    type = "text"
                }
            }
        }
    },
    -- validation
    function(data, context)
        if data.where == -1 then
            return false, "'Where' should be specified"
        elseif not data.text or data.text == "" then
            return false, "Text can't be empty"
        elseif data.globalCooldown ~= string.match(data.globalCooldown, "%d+") then
            return false, "Only digits are allowed for cooldown"
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
    -- logger.log("matching command", trigger, message)
    logger.log("matching command", trigger.name, trigger.dbId, message)

    -- local res = { id = trigger.dbId, text = trigger.data.text, name = trigger.data.name, action = trigger.data.action }
    local matched = false
    if trigger.data.where == 0 then
        if string.startsWith(message, trigger.data.text) then
            matched = true
        end
    elseif trigger.data.where == 1 then
        local found = Lutf8.find(message, trigger.data.text, 1, true)
        if found then
            matched = true
        end
    else
        if message == trigger.data.text then
            matched = true
        end
    end

    local hasCooldown = trigger.data.globalCooldown ~= nil and trigger.data.globalCooldown ~= 0
    if hasCooldown then
        local lt = globalCooldowns[trigger.dbId]
        if lt ~= nil then
            local elapsed = cooldownsCounter - lt
            if elapsed < trigger.data.globalCooldown then
                matched = false
                logger.log("command " .. trigger.name .. " still on cooldown: ", elapsed)
            end
        end
    end

    if matched then
        globalCooldowns[trigger.dbId] = cooldownsCounter
    end

    return matched
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
            enabled = true,
            globalCooldown = 0
        },
        matches = matchCommand,
        preProcess = function(data)
            if data.globalCooldown == nil then
                data.globalCooldown = "0"
            else
                data.globalCooldown = tostring(data.globalCooldown)
            end
            -- logger.log("reading globalCooldown:", data.globalCooldown)
        end,
        postProcess = function(result)
            if result.globalCooldown and result.globalCooldown ~= "" then
                result.globalCooldown = tonumber(result.globalCooldown)
            else
                result.globalCooldown = 0
            end
        end,
        onEnable = function(item, guiItem)
            logger.log("resetting global cooldown for ", item.name)
            globalCooldowns[item.dbId] = nil
            return true
        end,
        onDisable = function(item, guiItem)
            logger.log("resetting global cooldown for ", item.name)
            globalCooldowns[item.dbId] = nil
            return true
        end,
        onDelete = function(item, guiItem)
            logger.log("resetting global cooldown for ", item.name)
            globalCooldowns[item.dbId] = nil
            return true
        end,
        onUpdate = function(item, guiItem, result)
            logger.log("resetting global cooldown for ", item.name)
            globalCooldowns[item.dbId] = nil
            return true
        end
    }
    return twitchCmds, treeItem
end

local function init()
    cooldownsTimer = wxtimers.addTimer(1000, function(event) cooldownsCounter = cooldownsCounter + 1 end, true)
end

_M.commandsWhere = commandWhere
_M.registerTriggerIcons = registerTriggerIcons
_M.getTriggerTypes = function() return {"twitch_command"} end
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createTwitchCmdsFolder(triggerListCtrl)
end
_M.createCommandDlg = createCommandDlg
_M.init = init

return _M