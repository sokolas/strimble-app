local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local wxtimers = require("src/stuff/wxtimers")

local logger = Logger.create("timer_triggers")

local _M = {}

local function createTimerDialog()
    local commandDlg = dialogHelper.createDataDialog(Gui, "TimerDialog", {
        ["Trigger properties"] = {
            {
                name = "name",
                label = "Name",
                type = "text"
            },
            {
                name = "time",
                label = "Time(ms)",
                type = "text"
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
        elseif not data.time or data.time == "" then
            return false, "Time can't be empty"
        elseif string.match(data.time, "%d+") ~= data.time then
            return false, "Time must be a number"
        else
            if context and context.id then
                local duplicates = dataHelper.findTriggers(function(v)
                    return v.id ~= context.id and (not v.isGroup) and v.name == data.name
                end)
                if #duplicates > 0 then
                    return false, "Name must be unique"
                end
            else
                local duplicates = dataHelper.findTriggers(function(v)
                    return (not v.isGroup) and v.name == data.name
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

local function addOrEdit(title, mode)
    return function(id, data)
        local actionIds, actionNames = dataHelper.getActionData()
        local init = { action = function(c) c:Set(actionNames) end }
        local dlgData = CopyTable(data)
        dlgData.time = tostring(dlgData.time)

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
        local m, result = Gui.dialogs.TimerDialog.executeModal(title, dlgData, init, ctx)
        if m == wx.wxID_OK then
            local actionName = result.action
            result.action = nil
            for i = 1, #actionNames do
                if actionNames[i] == actionName then
                    result.action = actionIds[i]
                    break
                end
            end
            if result.time and result.time ~= "" then
                result.time = tonumber(result.time)
            end
            return result
        end
    end
end

local function createTimersFolder(triggerListCtrl, rootTriggerItem, onTrigger)
    local pages = iconsHelper.getPages()

    local timersFolder = triggerListCtrl:AppendItem(rootTriggerItem, "Timers", pages.timer, pages.timer)
    
    local function timerHandler(item, guiItem)
        return function(event)
            logger.log("timer triggering")
            onTrigger("timer", {action = item.data.action, name = item.name})
        end
    end

    local treeItem = {
        id = timersFolder:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "timer",
        persistChildren = true,
        icon = pages.scripts, -- for children
        getDescription = function(result)
            return result.time .. "ms"
        end,
        -- canDeleteChildren = true,
        add = addOrEdit("Add timer", "add"),
        childEdit = addOrEdit("Edit timer", "edit"),
        data = { -- default values for new children
            name = "Example timer",
            time = 60000,
            enabled = true
        },
        onEnable = function(item, guiItem)
            logger.log("onEnable", item.name)
            local timer = wxtimers.addTimer(item.data.time, timerHandler(item, guiItem), true)
            item.timer = timer
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
                logger.log("updated time")
                if item.timer then
                    wxtimers.delTimer(item.timer)
                end
                local timer = wxtimers.addTimer(result.time, timerHandler(item, guiItem), true)
                item.timer = timer
                return
            end
            
            if result.enabled and not prevState then
                item.onEnable(item, guiItem)
                return
            end
            
            if not result.enabled and prevState then
                item.onDisable(item, guiItem)
            end
        end
    }
    triggerListCtrl:SetItemText(timersFolder, 1, "+") -- TODO make this dependent on canAddChildren
    return timersFolder, treeItem
end

_M.createTimerDialog = createTimerDialog
_M.createTimersFolder = createTimersFolder


return _M