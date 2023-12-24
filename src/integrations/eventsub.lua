local es_helper = require("src/integrations/es_helper")
local Websocket = require("src/stuff/websocket")
local logger = Logger.create("twitch-eventsub")
local es_ws_logger = Logger.create("twitch-eventsub-ws")

local ws_url = "wss://eventsub.wss.twitch.tv/ws"
local sub_url = "https://api.twitch.tv/helix/eventsub/subscriptions"
local client_id = "yoe4w8ei1vm5q5b0w4ndqqzpvrs7dy"

local token = nil
local broadcaster_id = nil
local session_id = nil

local reconnect_interval = 15000
local auto_reconnect = true
local websocket = nil

local onMessage = nil
local onStateChange = nil

local function setToken(tkn)
    token = tkn
end

local function setBroadcasterId(id)
    broadcaster_id = id
end


local function connect()
    websocket:connect()
end

local function setAutoReconnect(a)
    auto_reconnect = a
    logger.log("setting auto reconnect to", auto_reconnect)
    if websocket then
        websocket:setAutoReconnect(auto_reconnect)
        logger.log("connected state:", websocket:isInConnectedState(), websocket:getState())
        if auto_reconnect and (not websocket:isInConnectedState()) then
            connect()
        end
    else
        logger.log("websocket is nil")
    end
end


--[[
    additional states:

    subscribing
    ready

]]

local function setOnMessage(f)
    onMessage = f
end

local function setOnStateChange(f)
    onStateChange = f
end

local function getSubHeaders()
    return {
        ["Authorization"] = "Bearer " .. token,
        ["Client-Id"] = client_id,
        ["Content-Type"] = "application/json"
    }
end

local function subscribe()
    local err = false
    local scopes = es_helper.scopes(session_id, broadcaster_id)
    for i = 1, #scopes do
        logger.log("Subscribing to ", scopes[i].type)
        local body = Json.encode(scopes[i])
        -- logger.log(body)
        local ok, res = NetworkManager.post(sub_url, getSubHeaders(), body)
        res = res or {}
        logger.log(scopes[i].type, ok, res.status, res.body)
        
        if websocket:getState() ~= "subscribing" or (not ok) or res.status ~= "202 Accepted" then -- the state may have changed, the subscription may have not worked, etc. Abort the subscriptions process
            err = true
            break
        end
    end
    if err then
        websocket:reconnect("error")
    else
        websocket:setState("ready")
    end
end

local function reconnect(newState)
    websocket:reconnect(newState)
end

local function handleWsMessage(msg)
    local message = Json.decode(msg)
    if message.metadata then
        if message.metadata.message_type ~= "session_keepalive" then
            logger.log(msg)
            if onMessage then
                onMessage(message)
            end
        end

        if message.metadata.message_type == "session_welcome" then
            session_id = message.payload.session.id
            websocket:setState("subscribing")
            local h = coroutine.wrap(subscribe)
            h() -- we return here, and the coroutine continues to run in the network dispatcher
        end
    end
end

local function handleWsStatus(oldState, newState)
    if onStateChange then
        onStateChange(oldState, newState)
    end
end

local function init(f, s)
    if f then
        setOnMessage(f)
    end
    if s then
        setOnStateChange(s)
    end
    websocket = Websocket:create("eventsub-ws", ws_url, reconnect_interval, auto_reconnect,
        {"subscribing", "ready"}, handleWsMessage, handleWsStatus, es_ws_logger, false);
    websocket:setupTimer()
end

local _M = {}

_M.setToken = setToken
_M.setBroadcasterId = setBroadcasterId
_M.setAutoReconnect = setAutoReconnect
_M.connect = connect
_M.reconnect = reconnect
_M.setOnMessage = setOnMessage
_M.setOnStateChange = setOnStateChange
_M.init = init

return _M
