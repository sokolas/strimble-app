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

local function init(menu, dialogs)
    -- delay
    steps.delayItem = submenu:Append(wx.wxID_ANY, "delay")

    steps.sendMessageDialog = dialogHelper.createDataDialog(Gui, "DelayStepDialog", "Delay", {
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
        dialog = steps.sendMessageDialog,
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

    -- finalize
    menu:AppendSubMenu(submenu, "General")
end

_M.delay = delay
_M.init = init

return _M