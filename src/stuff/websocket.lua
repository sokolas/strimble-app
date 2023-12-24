local timers = require("src/stuff/wxtimers")

local Websocket = {}
local Websocket_mt = { __index = Websocket}

function Websocket:setState(state)
    local oldState = self.state
    self.state = state
    if self.stateListener then
        self:stateListener(oldState, state)
    end
end

function Websocket:getState()
    return self.state
end

function Websocket:isInConnectedState()
    local result = self.state == "connected"
    if self.connected_states then
        for _, value in ipairs(self.connected_states) do
            result = result or (self.state == value)
        end
    end
    return result
end


function Websocket:setAutoReconnect(rec)
    self.auto_reconnect = rec
    if self.state == "reconnecting" and (not rec) then
        self:setState("offline")
    end
end

function Websocket:setReconnectInterval(interval)
    self.reconnect_interval = interval
end

function Websocket:setStateListener(f)  -- function f(oldState, newState)
    self.stateListener = function(websocket, oldState, newState)
        self.logger.log(self.id .. ": calling state listener")
        f(oldState, newState)
    end
end

function Websocket:setMessageListener(f)
    self.messageListener = function(websocket, ok, msg)
        if ok then
            if self.debug then self.logger.log(self.id .. ": handling message") end
            f(msg)
        else
            self.logger.err(self.id .. ": socket read error")
        end
    end
end
-- setmetatable(Websocket, Websocket)

function Websocket:handleDisconnection(newState)    -- internal
    if self.timer ~= nil then
        timers.resetTimer(self.timer)
    end
    if self.auto_reconnect then
        self.logger.log(self.id .. ": " .. (newState or "<nil>") .. ": need reconnect")
        self:setState("reconnecting")
    else
        self.logger.log(self.id .. ": " .. (newState or "<nil>") .. ": going offline")
        self:setState("offline")
    end
end

function Websocket:getWsMessageListener()
    return function(ok, msg)
        self:messageListener(ok, msg)
    end
end

function Websocket:getWsStatusHandler()
    return function(ok, oldStatus, newStatus)
        -- I don't handle "invalid" here because usually it means the socket was already closed
        if newStatus == "open" then
            self:setState("connected")
        elseif newStatus == "error" or newStatus == "closed" then
            self:handleDisconnection(newStatus)
        end
        if self.debug then self.logger.log(ok and "OK" or "NOT OK", newStatus) end
    end
end

function Websocket:handleReconnect()  -- actually handles the reconnection timer event, not reconnects. Use connect() instead
    if self.state == "reconnecting" then
        self:connect()
    end
    -- elseif not self:isInConnectedState() then
        -- self.logger.err(self.id .. ": invalid state: " .. (self.state or "<nil>"))
    -- else
        -- skipping reconnect
    -- end
end

function Websocket:setupTimer()
    if self.timer == nil then
        self.timer = timers.addTimer(self.reconnect_interval, function(event) self:handleReconnect() end, true)
        if self.debug then self.logger.log(self.id .. ": added reconnect timer " .. tostring(self.timer)) end
    end
end

function Websocket:connect()
    if self.state == "connecting" then
        self.logger.err(self.id .. ": state: connecting, skipping")
        return
    end
    if self.state ~= "offline" and self.state ~= "error" and self.state ~= "reconnecting" then
        -- or, rather, self:isInConnectedState()
        if self.socket.sock then
            if self.debug then self.logger.log(self.id .. ": closing previous socket " .. (self.socket.id or "<nil>")) end
            self.socket.sock:close()
            self.socket.sock = nil
            self.socket.id = nil
        end
    end
    self:setState("connecting")

    local sock = pollnet.open_ws(self.url)
    if sock then
        self.socket.sock = sock
        local id = NetworkManager.addSocket(sock,
            self:getWsMessageListener(),
            self:getWsStatusHandler(),
            self.debug
        )
        self.socket.id = id
    else
        self.logger.err(self.id .. ": couldn't open websocket")
        self:handleDisconnection("error")
    end
    if self.debug then self.logger.log(self.id .. ": opened websocket") end
    self:setupTimer()
end

function Websocket:reconnect(newState)
    if self.socket.sock then
        if self.debug then self.logger.log(self.id .. ": closing previous socket " .. (self.socket.id or "<nil>")) end
        self.socket.sock:close()
        self.socket.sock = nil
        self.socket.id = nil
    end
    self:handleDisconnection(newState or "reconnecting")
end

function Websocket:send(msg)
    if self:isInConnectedState() then
        self.socket.sock:send(msg)
    end
end

function Websocket:create(id, url, reconnect_interval, auto_reconnect, connected_states, messageListener, stateListener, logger, debug)
    local ws = {
        id = id,
        logger = logger,
        reconnect_interval = reconnect_interval,
        auto_reconnect = auto_reconnect,
        connected_states = connected_states,
        socket = {},
        url = url,
        debug = debug,
        state = "offline"
    }

    setmetatable(ws, Websocket_mt)
    ws:setMessageListener(messageListener)
    ws:setStateListener(stateListener)
    return ws
end

return Websocket
