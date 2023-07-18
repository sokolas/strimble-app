local logger = Logger.create("timers")

local _M = {}

local timers = {}

local function addTimer(interval, parent, handler, continous)
    local timer = wx.wxTimer(parent)
    local id = timer:GetId()
    logger.log("adding timer" .. tostring(id))
    parent:Connect(id, wx.wxEVT_TIMER, function(event)
        handler(event)
        if not continous then
            logger.log("deleting timer " .. tostring(id))
            timers[id] = nil
            timer:Stop()
            timer:delete()
        end
    end)
    timers[id] = timer
    local mode = (continous and wx.wxTIMER_CONTINUOUS) or wx.wxTIMER_ONE_SHOT
    -- print("mode", mode)
    timer:Start(interval, mode)
    return id
end

local function addWxTimerRaw(id, timer)
    timers[id] = timer
end

local function delTimer(id)
    local timer = timers[id]
    if timer then
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
_M.addTimer = addTimer
_M.delTimer = delTimer
_M.stopAll = stopAll

return _M