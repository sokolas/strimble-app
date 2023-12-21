local logger = Logger.create("timers")

local _M = {}

local timers = {}
local handlers = {}
local options = {}

local function addTimer(interval, handler, continous)
    local timer = wx.wxTimer(Gui.frame)
    local id = timer:GetId()
    logger.log("adding timer", id, tostring(interval) .. "ms")

    handlers[id] = function(event)
        if not continous then
            logger.log("deleting timer " .. tostring(id))
            local r = Gui.frame:Disconnect(id, wx.wxEVT_TIMER)
            logger.log("disconnect result", r)
            timers[id] = nil
            timer:Stop()
            timer:delete()
        end
        -- logger.log(id, "handling timer event")
        handler(event)
        -- logger.log(id, "timer event handled")
    end

    wx.wxPostEvent(Gui.frame, wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, TIMER_ADD))    -- frame will make the connection in the main thread

    timers[id] = timer
    local mode = (continous and wx.wxTIMER_CONTINUOUS) or wx.wxTIMER_ONE_SHOT
    -- print("mode", mode)
    timer:Start(interval, mode)
    options[id] = {
        interval = interval,
        mode = mode
    }
    return id
end

local function resetTimer(id)
    local option = options[id]
    logger.log("Resetting timer", id, option)
    timers[id]:Start(option.interval, option.mode)
end

local function addWxTimerRaw(id, timer)
    timers[id] = timer
end

local function delTimer(id)
    local timer = timers[id]
    if timer then
        local r = Gui.frame:Disconnect(id, wx.wxEVT_TIMER)
        logger.log("disconnect result", r)
        timer:Stop()
        timer:delete()
        logger.log("timer deleted", id)
        timers[id] = nil
    end
end

local function stopAll()
    for id, timer in pairs(timers) do
        -- logger.log("stopping", id)
        if timer then
            timer:Stop()
            timer:delete()
            timers[id] = nil
        end
    end
end

_M.timers = timers
_M.handlers = handlers

_M.addTimer = addTimer
_M.delTimer = delTimer
_M.resetTimer = resetTimer
_M.stopAll = stopAll

return _M