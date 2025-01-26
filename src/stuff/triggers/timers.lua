local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local wxtimers = require("src/stuff/wxtimers")
local ctxHelper = require("src/stuff/action_context")

local logger = Logger.create("timer_triggers")

local _M = {}

local triggerIcons = {}

local triggerIconPaths = {
    {path = "images/icons/timer_black.png", name = "timer"},
}

local function registerTriggerIcons()
    triggerIcons = iconsHelper.registerTriggerIcons(triggerIconPaths)
end

local function createTimerDialog()
    local commandDlg = dialogHelper.createTriggerDialog(Gui, "TimerDialog", {
        {
            name = "Trigger properties",
            controls = {
                {
                    name = "name",
                    label = "Name",
                    type = "text"
                },
                {
                    name = "time",
                    label = "Time(ms)",
                    type = "text"
                }
            }
        }
    },
    -- validation
    function(data, context)
        if not data.time or data.time == "" then
            return false, "Time can't be empty"
        elseif string.match(data.time, "%d+") ~= data.time then
            return false, "Time must be a number"
        else
            return true
        end
    end)
    return commandDlg
end

local function matchTimer(trigger, context)
    return trigger.dbId == context.timerTriggerId
end

local function createTimersFolder(triggerListCtrl, onTrigger)
    local rootTriggerItem = triggerListCtrl:GetRootItem()

    local timersFolder = triggerListCtrl:AppendItem(rootTriggerItem, "Timers", triggerIcons.timer, triggerIcons.timer)

    local function createTimerHandler(item, guiItem)
        -- local function buildContext()
            -- return ctxHelper.create({}, item.data.action)
        -- end

        return function(event)
            -- logger.log("timer triggering")
            -- onTrigger("timer", {action = item.data.action, name = item.name}, buildContext)
            onTrigger("timer", {action = item.data.action, name = item.name, timerTriggerId = item.dbId})
        end
    end

    local treeItem = {
        id = timersFolder:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "timer",
        persistChildren = true,
        icon = triggerIcons.active, -- for children
        getDescription = function(result)
            return result.time .. "ms"
        end,
        dialog = Gui.dialogs.TimerDialog,
        preProcess = function(data)
            data.time = tostring(data.time)
        end,
        postProcess = function(result)
            if result.time and result.time ~= "" then
                result.time = tonumber(result.time)
            end
        end,
        add = "Add timer",
        childEdit = "Edit timer",
        data = { -- default values for new children
            name = "Example timer",
            time = 60000,
            enabled = true
        },
        matches = matchTimer,
        onEnable = function(item, guiItem)
            logger.log("onEnable", item.name)
            if item.timer then
                wxtimers.resetTimer(item.timer, item.data.time)
            else
                local timer = wxtimers.addTimer(item.data.time, createTimerHandler(item, guiItem), true)
                item.timer = timer
            end
            return true
        end,
        onDisable = function(item, guiItem)
            logger.log("onDisable", item.name)
            if item.timer then
                wxtimers.delTimer(item.timer)
                item.timer = nil
            end
        end,
        onDelete = function(item, guiItem)
            logger.log("onDelete", item.name)
            if item.timer then
                wxtimers.delTimer(item.timer)
                item.timer = nil
            end
        end,
        onUpdate = function(item, guiItem, result)
            local prevState = item.data.enabled
            local prevTime = item.data.time

            if prevTime ~= result.time and result.enabled then
                logger.log("updated time", result.time)
                if item.timer then
                    wxtimers.resetTimer(item.timer, result.time)
                else
                    local timer = wxtimers.addTimer(result.time, createTimerHandler(item, guiItem), true)
                    item.timer = timer
                end
                return true
            end
            
            if result.enabled and not prevState then
                item.onEnable(item, guiItem)
                return true
            end
            
            if not result.enabled and prevState then
                item.onDisable(item, guiItem)
            end
            return true
        end
    }
    return timersFolder, treeItem
end

_M.createTimerDialog = createTimerDialog
_M.getTriggerTypes = function() return {"timer"} end
_M.registerTriggerIcons = registerTriggerIcons
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createTimersFolder(triggerListCtrl, onTrigger)
end
return _M