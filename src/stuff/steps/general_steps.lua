local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local wxtimers = require("src/stuff/wxtimers")


local _M = {}

local logger = Logger.create("general_steps")

local submenu = wx.wxMenu()
local steps = {}

local function delay(ctx, params)
    logger.log("delaying", params.delay)
    local this, main_thread = coroutine.running()
    if main_thread then
        logger.err("Can't call suspendable 'delay' from non-coroutine", debug.traceback())
        return false
    end
    logger.log(this)

    wxtimers.addTimer(params.delay, function(event)
        logger.log("resuming", params.delay)
        local ok, res = coroutine.resume(this)
        logger.log(ok, res)
    end)
    coroutine.yield()
    logger.log("delay is over", params.delay)
    return true
end

local function log(ctx, params)
    local output = ctx:interpolate(params.message)
    logger.force(output)
    return true
end

local function init(menu, dialogs)
    -- delay
    steps.delayItem = submenu:Append(wx.wxID_ANY, "delay")

    steps.delayDialog = dialogHelper.createDataDialog(Gui, "DelayStepDialog", "Delay", {
        {
            name = "delay",
            label = "Delay (ms)",
            type = "text"
        }
    },
    function(data, context)
        if not data.delay or data.delay == "" then
            return false, "Delay can't be empty"
        else if data.delay ~= string.match(data.delay, "%d+") then
            return false, "Only digits are allowed"
        end
            return true
        end
    end)
    
    dialogs[steps.delayItem:GetId()] = {
        name = "Delay",
        dialog = steps.delayDialog,
        dialogItem = Gui.dialogs.DelayStepDialog,
        icon = iconsHelper.pages.timer,
        getDescription = function(result) return result.delay .. 'ms' end,
        preProcess = function(params)
            return {
                delay = tostring(params.delay)
            }
        end,
        postProcess = function(result)
            local delay = tonumber(result.delay)
            logger.log(type(delay))
            return {
                delay = delay
            }
        end,
        code = delay,
        data = {
            delay = "1000"
        }
    }

    -- log
    steps.logItem = submenu:Append(wx.wxID_ANY, "log")

    steps.logDialog = dialogHelper.createDataDialog(Gui, "LogStepDialog", "Log", {
        {
            name = "message",
            label = "Message",
            type = "text"
        }
    },
    function(data, context)
        if not data.message or data.message == "" then
            return false, "Message can't be empty"
        else
            local start, finish = Lutf8.find(data.message, var_pattern)
            while start do
                local var_expr = Lutf8.sub(data.message, start, finish)
                if not string.startsWith(var_expr, '$$') then
                    local var = Lutf8.sub(var_expr, 2)
                    logger.log("var", var)
                end
                start, finish = Lutf8.find(data.message, var_pattern, finish)
            end
            
            return true
        end
    end)
    
    dialogs[steps.logItem:GetId()] = {
        name = "Log",
        dialog = steps.logDialog,
        dialogItem = Gui.dialogs.LogStepDialog,
        icon = iconsHelper.pages.logs,
        getDescription = function(result) return result.message end,
        code = log,
        data = {
            message = "User: $user, channel: $channel"
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "General")
end

_M.delay = delay
_M.init = init

return _M