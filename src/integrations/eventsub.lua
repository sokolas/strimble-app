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


local function setToken(tkn)
    token = tkn
end

local function setBroadcasterId(id)
    broadcaster_id = id
end


--[[
    additional states:

    subscribing
    subscribed

]]

local onMessage = nil

local function setOnMessage(f)
    onMessage = f
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
        websocket:setState("subscribed")
    end
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
    logger.log("changing state", oldState, "->", newState)
end

local function connect()
    websocket:connect()
end

local function init(f)
    setOnMessage(f)
    websocket = Websocket:create("eventsub-ws", ws_url, reconnect_interval, auto_reconnect, 
        {"subscribing", "subscribed"}, handleWsMessage, handleWsStatus, es_ws_logger, false);
end

local _M = {}

_M.setToken = setToken
_M.setBroadcasterId = setBroadcasterId
_M.connect = connect
_M.init = init

return _M
