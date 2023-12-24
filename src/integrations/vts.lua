local Websocket = require("src/stuff/websocket")
local timers = require("src/stuff/wxtimers")
local image_str = require("src/integrations/bug_image")
local logger = Logger.create("vts")
local ws_logger = Logger.create("vts-ws")
local Socket = require("winsocket")
local ffi = require("ffi")

local client = "StrimbleApp"
local author = "Sokolas"
local address = "ws://127.0.0.1:8001"
local reconnect_interval = 15000
local auto_reconnect = true
local token = nil
local socket = nil
local state = "offline"
local userStateListener = nil
local userMessageListener = nil
local paramKeepTimer = nil
local udp = nil
local udp_timer = nil
local vts_addresses = {}

local msg_id = 0

local function setAddress(a)
    address = a
    if socket then
        socket.url = a
    end
end

local function setToken(t)
    token = t
end

local function setUserStateListener(f)
    userStateListener = f
end

local function setUserMessageListener(f)
    userMessageListener = f
end

local function nextMessage(type)
    msg_id = msg_id + 1
    return {
        apiName = "VTubeStudioPublicAPI",
        apiVersion = "1.0",
        requestID = tostring(msg_id),
        messageType = type
    }
end

local function apiStateRequest()
    return Json.encode(nextMessage("APIStateRequest"))
end

local function authTokenRequest()
    local msg = nextMessage("AuthenticationTokenRequest")
    msg.data = {
        pluginName = client,
        pluginDeveloper = author,
        pluginIcon = image_str
    }
    return Json.encode(msg)
end

local function authRequest()
    local msg = nextMessage("AuthenticationRequest")
    msg.data = {
        pluginName = client,
        pluginDeveloper = author,
        authenticationToken = token
    }
    return Json.encode(msg)
end

local function setState(newState)
    local oldState = state
    logger.log("changing state: ", oldState, "->", newState)
    state = newState
    if state == "connected" then
        socket:send(apiStateRequest())
    end

    if userStateListener then
        userStateListener(oldState, state)
    end
end

local function wsMessageListener(msg)
    logger.log(msg)
    local message = Json.decode(msg)
    if message.messageType == "APIError" then
        logger.err("api error", message.data.errorID, message.data.message)
        if state ~= "ready" then
            -- reconnect
        end
    elseif message.messageType == "APIStateResponse" then
        if message.data.currentSessionAuthenticated then
            setState("ready")
        elseif not token then
            socket:send(authTokenRequest())
        else
            socket:send(authRequest())
        end
    elseif message.messageType == "AuthenticationTokenResponse" then
        setToken(message.data.authenticationToken)
        socket:send(authRequest())
    elseif message.messageType == "AuthenticationResponse" then
        if message.data.authenticated then
            setState("ready")
        else
            logger.err("auth error", message.data.errorID, message.data.message)
            -- reconnect
        end
    end
end

local function wsStateListener(oldState, newState)
    setState(newState)
end

local function keepParams()
    if state == "ready" then
        -- socket:send("")
    end
end

local function connect()
    if socket then
        socket:connect()
    end
end

local function checkUdp()
    if not udp then return end

    local size = udp:available()
    if size > 0 then
        -- logger.log('Bytes available '..size)
        local ok, result, addr = pcall(udp.recvfrom, udp, size, nil)
        if ok then
            -- do stuff with the data
            logger.log(#result, addr, result)
        else
            logger.err("Error text: " .. result)
        end
    elseif size < 0 then
        logger.err('Error reading: ' .. Winsock.WSAGetLastError())
    end
end

local function init(a)
    setAddress(a)
    socket = Websocket:create("vts-ws", address, reconnect_interval, auto_reconnect, nil, wsMessageListener, wsStateListener, ws_logger, false)
    paramKeepTimer = timers.addTimer(900, keepParams, true)
    
    -- init udp
    --[[
    local SB_HOST_ADDRESS = "0.0.0.0"
    local SB_HOST_PORT = 47779

    udp = Socket:new(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    udp:bind(SB_HOST_ADDRESS, SB_HOST_PORT)
    local one = ffi.new("long[1]", 1)
    if Winsock.ioctlsocket(udp.descriptor, FIONBIO, one) < 0 then logger.err('Error setting async: '..winsock.WSAGetLastError()) end
    udp_timer = timers.addTimer(50, checkUdp, true)
    logger.log("init done")
    ]]
end

local function sendParamValue()

end

_M = {}

_M.setAddress = setAddress
_M.setToken = setToken
_M.setUserStateListener = setUserStateListener
_M.setUserMessageListener = setUserMessageListener
_M.setState = setState
_M.connect = connect
_M.init = init
_M.vts_addresses = function() return vts_addresses end

return _M
