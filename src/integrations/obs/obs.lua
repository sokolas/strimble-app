local base64 = require("base64")
local sha2 = require("sha2")
local Websocket = require("src/stuff/websocket")
local timers = require("src/stuff/wxtimers")

local logger = Logger.create("obs")
local ws_logger = Logger.create("obs-ws")

local url = nil
local password = nil
local socket = nil
local reconnect_interval = 15000
local auto_reconnect = false

local state = "offline"

local userStateListener = nil
local userMessageListener = nil
local dataChangeListener = nil

local req_id = 0
local requests = {}
local requestsTimer = nil
local timeout = 5000

local stopwatch = wx.wxStopWatch()  -- we need a strictly monotonous source of milliseconds

local function getIcon(state)
    if state == "ready" then
        return "ok"
    elseif state == "connecting" or state == "reconnecting" or state == "connected" then
        return "retry"
    elseif state == "error" or state == "offline" or state == "closed" then
        return "error"
    end
end

local function setState(newState)
    local oldState = state
    logger.log("changing state: ", oldState, "->", newState)
    state = newState
    -- if state == "connected" then
        -- socket:send(apiStateRequest())
    -- end

    if userStateListener then
        userStateListener(state, getIcon(state))
    end
end

local function send(message)
    if state == "connected" and socket then
        socket:send(message)
    end
end

local function onRequest()
    local ok, res = coroutine.yield()
    return ok, res
end

local function nextRequest(type, data)
    req_id = req_id + 1
    local id = tostring(req_id)
    return id, {
        op = 6,
        d = {
            requestType = type,
            requestId = id,
            requestData = data
        }
    }
end

local function request(type, data)
    local this, main_thread = coroutine.running()
    if main_thread then
        logger.err("Can't call suspendable 'request' from non-coroutine", debug.traceback())
        return false
    end
    if state == "connected" or state == "ready" and socket then
        local id, msg = nextRequest(type, data)
        logger.log(id, msg)
        socket:send(Json.encode(msg))
        requests[id] = {
            co = this,
            time = stopwatch:Time()
        }
        logger.log("suspending")
        local ok, res = coroutine.yield()
        logger.log("got", ok, res)
        return ok, res
    else
        return false, "OBS is not ready"
    end
end

local function identify(auth)
    local msg = {
        op = 1,
        d = {
            rpcVersion = 1,
            -- eventSubscriptions = 0
        }
    }
    if auth then
        local hash = sha2.hash256(password .. auth.salt, true)
        local secret = base64.encode(hash)
        local authChallenge = secret .. auth.challenge
        local authStr = base64.encode(sha2.hash256(authChallenge, true))
        -- logger.log(authStr)
        msg.d.authentication = authStr
    end
    local m = Json.encode(msg)
    -- logger.log(m)
    return m
end

local function wsMessageListener(msg)
    logger.log(msg)
    local m = Json.decode(msg)
    if m.op == 0 then       -- HELLO
            send(identify(m.d.authentication))
    elseif m.op == 2 then   -- IDENTIFIED
        setState("ready")
    elseif m.op == 7 then   -- RESPONSE
        local req = requests[m.d.requestId]
        logger.log(req)
        if req then
            logger.log("resuming")
            requests[m.d.requestId] = nil
            coroutine.resume(req.co, true, m.d)
        end
    end
end

local function wsStateListener(oldState, newState)
    setState(newState)
    if oldState == "ready" then
        -- invalidate cache
    end
end

local function connect()
    if socket then
        socket:connect()
    end
end

local function setUrl(a)
    url = a
    if socket then
        socket.url = a
    end
end

local function getUrl()
    return url
end

local function setPasword(t)
    password = t
end

local function getPassword()
    return password
end

local function setUserStateListener(f)
    userStateListener = f
end

local function setUserMessageListener(f)
    userMessageListener = f
end

local function setDataChangeListener(f)
    dataChangeListener = f
end

local function setAutoReconnect(a)
    auto_reconnect = a
    logger.log("setting auto reconnect to", auto_reconnect)
    if socket then
        socket:setAutoReconnect(auto_reconnect)
        logger.log("connected state:", socket:isInConnectedState(), socket:getState())
        if auto_reconnect and (not socket:isInConnectedState()) and url and url ~= "" then
            connect()
        end
    else
        logger.log("websocket is nil")
    end
end

local function handleRequestTimer(event)
    local time = stopwatch:Time()
    for k, v in pairs(requests) do
        if time - v.time >= timeout then
            local co = v.co
            requests[k] = nil
            logger.err("request timeout", k)
            coroutine.resume(co, false, {})
        end
    end
end

local function init(a, messageListener, stateListener, dataChangeListener)
    setUrl(a)
    setUserMessageListener(messageListener)
    setUserStateListener(stateListener)
    setDataChangeListener(dataChangeListener)
    socket = Websocket:create("obs-ws", url, reconnect_interval, auto_reconnect, nil, wsMessageListener, wsStateListener, ws_logger, false)
    requestsTimer = timers.addTimer(1000, handleRequestTimer, true)
    stopwatch:Start(0)
end

local _M = {
    init = init,
    setAutoReconnect = setAutoReconnect,
    setDataChangeListener = setDataChangeListener,
    setUserMessageListener = setUserMessageListener,
    setUserStateListener = setUserStateListener,
    getPassword = getPassword,
    setPasword = setPasword,
    getUrl = getUrl,
    setUrl = setUrl,
    connect = connect,
    send = send,
    request = request
}

return _M
