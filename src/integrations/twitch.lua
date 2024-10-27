local url = require("socket.url")
local logger = Logger.create("twitch")
local eventsub = require("src/integrations/eventsub")
local esTrigger = require("src/stuff/triggers/eventsub")
local triggersHelper = require("src/gui/triggers")
local ctxHelper = require("src/stuff/action_context")
local commands = require("src/stuff/triggers/commands")

local requests = require("src/integrations/twitch_requests")

local scopes = {
    "bits:read",
    "channel:edit:commercial",
    "channel:manage:broadcast",
    "channel:manage:polls",
    "channel:manage:predictions",
    "channel:manage:redemptions",
    "channel:manage:moderators",
    --   "channel:manage:videos",
    "channel:read:ads",
    "channel:read:goals",
    "channel:read:hype_train",
    "channel:read:polls",
    "channel:read:predictions",
    "channel:read:redemptions",
    "channel:read:subscriptions",
    "moderation:read",
    "moderator:manage:announcements",
    "moderator:manage:banned_users",
    "moderator:read:blocked_terms",
    "moderator:read:followers",
    "moderator:manage:blocked_terms",
    "moderator:manage:automod",
    "moderator:read:automod_settings",
    "moderator:manage:automod_settings",
    "moderator:read:chat_settings",
    "moderator:manage:chat_settings",
    "moderator:read:chatters",
    "moderator:manage:shoutouts",
    "user:manage:blocked_users",
    "user:read:chat",
    "user:write:chat",
    "user:read:follows",
    "user:read:subscriptions",
    "channel:moderate",
    "chat:edit",
    "chat:read",
    "whispers:read",
    "whispers:edit"
}
table.sort(scopes)

local auth_url = "https://id.twitch.tv/oauth2/authorize"
local client_id = "yoe4w8ei1vm5q5b0w4ndqqzpvrs7dy"
local redirect_url = "http://localhost:10115/tw_user"

requests.setClientId(client_id)

local function toChannel(str)
    local username = Lutf8.lower(str or '')
    if string.sub(username, 1, 1) == '#' then
        return username
    else
        return "#"..username
    end
end

local function toUsername(str)
    local username = Lutf8.lower(str or '')
    if string.sub(username, 1, 1) == '#' then
        return string.sub(username, 2)
    else
        return username
    end
end


-- module definition

local _M = {}

_M.es_state = "offline"
_M.token = nil
_M.username = nil
_M.channel = nil
_M.userId = nil
_M.redirect_url = redirect_url
_M.reconnect_interval = 15000
_M.auto_reconnect = true
_M.userEsMessageListener = nil


local function getEsIcon(state)
    if state == "ready" then
        return "ok"
    elseif state == "connecting" or state == "reconnecting" or state == "connected" or state == "subscribing" then
        return "retry"
    elseif state == "error" or state == "offline" or state == "closed" then
        return "error"
    end
end

_M.setState = function(newState, additional)
    logger.log("state", newState)
    _M.es_state = newState
    if _M.userStateListener then
        _M.userStateListener(newState, getEsIcon(newState), additional)
    end
end

_M.setToken = function(token)
    _M.token = token
    requests.setToken(token)
end

_M.getAuthUrl = function()
    local params = {
        response_type = "token",
        client_id = client_id,
        redirect_uri = redirect_url,
        scope = table.concat(scopes, " "),
        force_verify = "true"
    }
    local paramStrs = {}
    for k, v in pairs(params) do
        table.insert(paramStrs, string.format("%s=%s", k, url.escape(v)))
    end
    
    local query = auth_url .. "?" .. table.concat(paramStrs, "&")
    return query
end

_M.parseAuth = function(response_url)
    local parts = url.parse(response_url)
    if not parts then return {} end
    local str = parts.fragment or parts.query
    if str then
        local str = url.unescape(str)
        local paramStrs = SplitMessage(str, "&")
        local params = {}
        for i, v in ipairs(paramStrs) do
            local p = SplitMessage(v, "=")
            params[p[1]] = Lutf8.gsub(p[2], "+", " ")
        end
        return params
    else
        return {}
    end
end

_M.validateToken = function()
    if not _M.token then
        return false, "token is not set"
    end
    local ok, res = NetworkManager.get("https://id.twitch.tv/oauth2/validate", {["Authorization"] = "OAuth " .. _M.token, ["Client-Id"] = client_id})
    if ok then
        local text = (res or {}).body
        local ok, data = pcall(Json.decode, text)
        if not ok then
            logger.err("Error validating twitch token", data)
            return false, data
        else
            -- logger.log(text)
            _M.userId = data.user_id
            if not data.scopes then
                return false, data
            else
                table.sort(data.scopes)
                if #(data.scopes) ~= #scopes then
                    data.status = "200"
                    data.message = "Scopes are outdated"
                    return false, data
                end
                for i, v in ipairs(scopes) do
                    if data.scopes[i] ~= v then
                        data.status = "200"
                        data.message = "Scopes are outdated"
                        return false, data
                    end
                end
                return true, data
            end
        end
    else
        logger.err("Error validating token", (res or {}).status, (res or {}).body)
        return false, {status = (res or {}).status, message = (res or {}).body}
    end
end

--[[
                            -- logger.log(Lutf8.escape("%x{0001}ACTION"))
                        -- TODO additional checks: bits, action, etc https://github.com/tmijs/tmi.js/blob/main/lib/ClientBase.js#L1034
                        if _M.userMessageListener then
                            _M.userMessageListener({
                                channel = channel,
                                user = Lutf8.sub(message.prefix, 1, Lutf8.find(message.prefix, "!", 1, true) - 1),
                                text = text,
                                tags = message.tags
                            })
                        end

]]

_M.setMessageListener = function(f)
    _M.userMessageListener = f
end

_M.setStateListener = function(f)
    _M.userStateListener = f
end

_M.connect = function()
    logger.log("connecting to twitch")
    --[[if _M.chat_socket.state == "connecting" then
        logger.err("state: connecting, skipping")
        return
    end]]
    -- _M.setState("connecting")

    if not _M.token then
        eventsub.reconnect("error")
        return false, "token is not set"
    end
    if (not _M.username) or (_M.username == '') then
        eventsub.reconnect("error")
        return false, "username is not set"
    end
    _M.channel = _M.channel or _M.username
    if (not _M.channel) or (_M.channel == '') then
        eventsub.reconnect("error")
        return false, "channel is not set"
    end

    requests.setToken(_M.token)
    requests.setBroadcasterId(_M.userId)

    eventsub.setToken(_M.token)
    eventsub.setBroadcasterId(_M.userId)
    eventsub.connect()
end

_M.sendToChannel = function(text, channel)
    local c = channel or _M.channel
    if not c then
        logger.err("No channel specified")
        return
    end
    --[[if _M.chat_socket.state ~= "ready" then
        logger.err("Not joined any channel")
        return
    end]]
    
    if Lutf8.len(text) > 500 then
        local t = text
        while Lutf8.len(t) > 500 do
            local s = Lutf8.sub(t, 1, 500)
            t = Lutf8.sub(t, 501)
            requests.sendMessage(s)
        end
        if t ~= "" then
            requests.sendMessage(t)
        end
    else
        requests.sendMessage(text) -- TODO set channel
    end
end

_M.esStateListener = function(oldState, newState, additional)
    _M.setState(newState, additional)
end

_M.esMessageListener = function(esEvent)
    if _M.userEsMessageListener then
        _M.userEsMessageListener(esEvent)
    end
    
    --local triggered = triggersHelper.onTrigger("twitch_eventsub", esEvent)
    if esEvent.payload and esEvent.payload.subscription and esEvent.payload.subscription.type then
        local matchedEvents = esTrigger.matchTrigger(esEvent)
        if matchedEvents then
            for i, event in ipairs(matchedEvents) do
                local function buildContext()
                    return ctxHelper.create({
                        payload = esEvent.payload
                    }, event.action)
                end
                triggersHelper.onTrigger("twitch_eventsub", event, buildContext)
            end
        end
    end

    if esEvent.metadata.subscription_type == "channel.chat.message" then
        logger.log("new channel message")
        local e = esEvent.payload.event
        local user = {
            id = e.chatter_user_id,
            displayName = e.chatter_user_name,
            name = e.chatter_user_login,
            subscriber = nil,
            mod = nil -- badges[].set_id == "moderator" || "broadcaster"
        }
        local message = {
            text = e.message.text,
            user = user.displayName,
            channel = e.broadcaster_user_login
        }
        if _M.userMessageListener then
            _M.userMessageListener(message)
        end

        if e.chatter_user_id == _M.userId then
            logger.log("ignoring self message")
            -- ignore self messages
            return
        end
        
        --local triggered_chat = triggersHelper.onTrigger("twitch_privmsg", {channel = message.channel, user = user, text = message.text})
        local matchedCommands = commands.matchCommands(message.text)
        if matchedCommands then
            for i, cmd in ipairs(matchedCommands) do
                local function buildContext()
                    return ctxHelper.create({
                        user = user,
                        value = message.text, -- TODO parse into command and params
                        channel = message.channel
                    }, cmd.action)
                end
                triggersHelper.onTrigger("twitch_privmsg", cmd, buildContext)
            end
        end
    end
end

_M.init = function(stateListener, chatMessageListener, esMessageListener)
    _M.userMessageListener = chatMessageListener
    _M.userStateListener = stateListener
    _M.userEsMessageListener = esMessageListener

    eventsub.init(_M.esMessageListener, _M.esStateListener)
end

_M.setEventSubListener = function(f)
    eventsub.setOnMessage(f)
end

_M.setAutoReconnect = function(auto_reconnect)
    _M.auto_reconnect = auto_reconnect
    if auto_reconnect then
        requests.setToken(Twitch.token)
        requests.setBroadcasterId(Twitch.userId)
        eventsub.setToken(Twitch.token)
        eventsub.setBroadcasterId(Twitch.userId)
    end
    eventsub.setAutoReconnect(auto_reconnect)
end

_M.toUsername = toUsername
_M.toChannel = toChannel

return _M