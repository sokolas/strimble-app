local url = require("socket.url")

local scopes = {
    "bits:read",
    "channel:edit:commercial",
    "channel:manage:broadcast",
    "channel:manage:polls",
    "channel:manage:predictions",
    "channel:manage:redemptions",
    "channel:manage:moderators",
    --   "channel:manage:videos",
    "channel:read:goals",
    "channel:read:hype_train",
    "channel:read:polls",
    "channel:read:predictions",
    "channel:read:redemptions",
    "channel:read:subscriptions",
    "moderation:read",
    "moderator:manage:banned_users",
    "moderator:read:blocked_terms",
    "moderator:manage:blocked_terms",
    "moderator:manage:automod",
    "moderator:read:automod_settings",
    "moderator:manage:automod_settings",
    "moderator:read:chat_settings",
    "moderator:manage:chat_settings",
    "moderator:read:chatters",
    "user:manage:blocked_users",
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

_M.state = "offline"
_M.token = nil
_M.username = nil
_M.channel = nil
_M.userId = nil
_M.redirect_url = redirect_url

_M.setState = function(newState)
    local oldState = _M.state
    _M.state = newState
    if _M.userStateListener then
        _M.userStateListener(oldState, newState)
    end
end

function _M.parseMessage(data)
    local result = {}
    local position = 1
    local nextspace = 1

    -- The first thing we check for is IRCv3.2 message tags.
    -- print("parsing tags")
    if Lutf8.sub(data, 1,1) == '@' then
        nextspace = Lutf8.find(data, ' ', 1, true);

        --malformed
        if not nextspace then
            return false, result
        end
        local rawTagsStr = Lutf8.sub(data, 2, nextspace-1)
        --print("raw tags str: '" .. rawTagsStr .. "'")
        local rawTags = SplitMessage(rawTagsStr, ";")

        result.tags = {}
        for i, rawTag in ipairs(rawTags) do
            local tagKV = SplitMessage(rawTag, "=")
            --print(tagKV[1], tagKV[2])
            result.tags[tagKV[1]] = tagKV[2]
        end
        position = nextspace + 1
    end
    
    -- Skip any trailing whitespace..
    while Lutf8.sub(data, position, position) == ' ' do
        position = position + 1
    end

    -- print("parsing prefix")
    -- Extract the message's prefix if present. Prefixes are prepended with a colon..
    if Lutf8.sub(data, position, position) == ':' then
        nextspace = Lutf8.find(data, ' ', position, true);
        
        -- If there's nothing after the prefix, deem this message to be malformed.
        if not nextspace then
            return false, result;
        end

        result.prefix = Lutf8.sub(data, position + 1, nextspace - 1);
        position = nextspace + 1;

        -- Skip any trailing whitespace..
        while Lutf8.sub(data, position, position) == ' ' do
            position = position + 1;
        end
        -- print("prefix is '" .. result.prefix .. "'")
    end
    nextspace = Lutf8.find(data, ' ', position, true);

    -- print("parsing command")
    -- print(lutf8.len(data), position, nextspace)
    -- If there's no more whitespace left, extract everything from the
    -- current position to the end of the string as the command..
    if not nextspace then
        if Lutf8.len(data) > position then
            result.command = Lutf8.sub(data, position);
            -- print("command is '" .. result.command .. "'")
            return true, result;
        end
        return false, result
    end

    -- Else, the command is the current position up to the next space. After
    -- that, we expect some parameters.
    result.command = Lutf8.sub(data, position, nextspace - 1);
    -- print("command is '" .. result.command .. "'")

    position = nextspace + 1;
    -- Skip any trailing whitespace..
    while Lutf8.sub(data, position, position) == ' ' do
        position = position + 1
    end

    -- print("parsing params");
    
    result.params = {}
    while position < Lutf8.len(data) do
        -- print("parsing param")
        nextspace = Lutf8.find(data, ' ', position)
        -- If the character is a colon, we've got a trailing parameter.
        -- At this point, there are no extra params, so we push everything
        -- from after the colon to the end of the string, to the params array
        -- and break out of the loop.
        if Lutf8.sub(data, position, position) == ':' then
            -- print("colon param")
            local p = Lutf8.sub(data, position + 1)
            -- print(p)
            table.insert(result.params, p)
            break
        end

        -- If we still have some whitespace...
        if nextspace then
            -- Push whatever's between the current position and the next space to the params array.
            table.insert(result.params, Lutf8.sub(data, position, nextspace - 1))
            position = nextspace + 1;

            -- Skip any trailing whitespace..
            while Lutf8.sub(data, position, position) == ' ' do
                position = position + 1
            end
            -- continue;
        else
            -- If we don't have any more whitespace and the param isn't trailing,
            -- push everything remaining to the params array.
            table.insert(result.params, Lutf8.sub(data, position))
            break;
        end
    end

    return true, result
end

_M.setToken = function(token)
    _M.token = token
    _M.setState("token_set")
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

_M.apiGet = function(url)
    if not _M.token then
        return false, "token is not set"
    end
    return NetworkManager.get(url, {["Authorization"] = "Bearer " .. _M.token, ["Client-Id"] = client_id})
end

_M.getUserInfo = function(callback)
    if not _M.token then
        return false, "token is not set"
    end
    local ok, res = NetworkManager.get("https://api.twitch.tv/helix/users", {["Authorization"] = "Bearer " .. _M.token, ["Client-Id"] = client_id})
    if ok then
        callback(res)
    end
end

_M.validateToken = function()
    if not _M.token then
        return false, "token is not set"
    end
    local ok, res = NetworkManager.get("https://id.twitch.tv/oauth2/validate", {["Authorization"] = "OAuth " .. _M.token, ["Client-Id"] = client_id})
    if ok then
        local text = res.body
        local ok, data = pcall(Json.decode, text)
        if not ok then
            Log("Error validating twitch token", data)
            return false, data
        else
            -- Log(text)
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
        Log("Error validating token", (res or {}).status, (res or {}).body)
        return false, {status = (res or {}).status, message = (res or {}).body}
    end
end

local function getChannel(params)
    if params and #params >= 1 then
        return toChannel(params[1])
    end
end

local function getMsg(params)
    if params and #params >= 2 then
        return params[2]
    end
end

local function sendRaw(cmd)
    if _M.chatSock and (_M.state == "connected" or _M.state == "joined") then
        Log("sending [" .. (cmd or '') .. "]")
        _M.chatSock:send(cmd)
        return true
    else
        return false
    end
end

local sockStatus

local function handleWsStatus(ok, oldStatus, newStatus)
    Log("*** " .. newStatus)
    sockStatus = newStatus
    if not _M.token or not _M.username then
        Log("token or username is not set")
        return
    end
    local sock = _M.chatSock
    if newStatus == "open" then
        _M.setState("connected")
        sock:send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands")
        -- print("PASS " .. _M.token)
        sock:send("PASS oauth:" .. _M.token)
        -- local anon_user_name = "justinfan" .. math.random(1, 100000)
        -- print("NICK " .. _M.username)
        sock:send("NICK " .. _M.username)
        -- sock:send("JOIN " .. toChannel(_M.channel or _M.username))
    elseif newStatus == "error" then
        Log("twitch connection error")
        _M.setState("error")
        -- sock:close()
    end
end

local userCount = 0

local function handleWsMessage(ok, msg)
    if ok then
        local messages = SplitMessage(msg, "\r\n")
        for i, line in ipairs(messages) do
            if line and line ~= "" then
                -- Log(line)
                local ok, message = _M.parseMessage(line)
                if ok then
                    local channel = getChannel(message.params)
                    local text = getMsg(message.params)
                    local msgId = (message.params or {})["msg-id"]
                    
                    if message.command ~= "JOIN" then   -- extend the list of ignored commands?
                        Log("prefix", message.prefix, "command", message.command, "channel", channel, "msgId", msgId)
                        Log("text: " , text)
                    end

                    if not message.prefix then
                        if message.command == "PING" then
                            sendRaw("PONG :tmi.twitch.tv")
                        elseif message.command == "PONG" then
                            -- do nothing
                        else
                            Log("unknown command without prefix")
                        end
                    elseif message.prefix == "tmi.twitch.tv" then
                        if message.command == "376" then    -- connected
                            sendRaw("JOIN " .. toChannel(_M.channel or _M.username))
                        elseif message.command == "ROOMSTATE" then
                            if _M.state ~= "joined" then
                                _M.setState("joined")
                                -- emit status change
                            end
                        end
                    else
                        if message.command == "PRIVMSG" then
                            -- Log(line)
                            -- Log(Lutf8.escape("%x{0001}ACTION"))
                            -- TODO additional checks: bits, action, etc https://github.com/tmijs/tmi.js/blob/main/lib/ClientBase.js#L1034
                            if _M.userMessageListener then
                                _M.userMessageListener({
                                    channel = channel,
                                    user = Lutf8.sub(message.prefix, 1, Lutf8.find(message.prefix, "!", 1, true) - 1),
                                    text = text,
                                    tags = message.tags
                                })
                            end
                            -- if text == "!reconnect" then
                                -- _M.reconnect()
                            -- end
                        elseif message.command == "RECONNECT" or message == "SERVERCHANGE" then
                            _M.reconnect()
                        
                        --[[elseif message.command == "353" then    -- names
                            _M.userMessageHandler({
                                channel = "***",
                                user = "***",
                                text = table.concat(message.params, ":")
                            })
                            -- names?
                            -- Log(message.params[4])
                        elseif message.command == "JOIN" then
                            userCount = userCount + 1
                            _M.userMessageHandler({
                                channel = "***",
                                user = "***",
                                text = "users: " .. tostring(userCount)
                            })]]
                        end
                    end

                else
                    Log("can't parse line:", line)
                end
            end
        end
    else
        -- check for manual disconnect
    end
end

_M.setMessageListener = function(f)
    _M.userMessageListener = f
end

_M.setStateListener = function(f)
    _M.userStateListener = f
end

local function connect()
    Log("connecting to twitch")
    if not _M.token then
        return false, "token is not set"
    end
    if not _M.username or _M.username == '' then
        return false, "username is not set"
        --[[local ok, result = _M.apiGet("https://api.twitch.tv/helix/users")
        if ok and result then
            -- print(result.status)
            local status = string.sub(result.status, 1, 3)
                if status == "200" then
                    -- print(result.status, result.body)
                    local data = (Json.decode(result.body)).data
                    -- print(data[1].display_name)
                elseif status == "401" then
                    Log("Token is invalid")
                else
                    Log("unknown status", result.status)
                end
        end]]
    end
    _M.channel = _M.channel or _M.username
    if not _M.channel or _M.channel == '' then
        return false, "channel is not set"
    end
    local sock = pollnet.open_ws("wss://irc-ws.chat.twitch.tv:443")
    
    if sock then
        _M.chatSock = sock
        local id = NetworkManager.addSocket(_M.chatSock, handleWsMessage, handleWsStatus)
        _M.chatSockId = id
    else
        handleWsStatus(false, nil, "error")
    end
    -- print("ws is", id)
end

_M.sendToChannel = function(text, channel)
    if not channel and not _M.channel then
        Log("No channel specified")
        return
    end
    if _M.state ~= "joined" then Log("Not joined to any channel") end
    local c = channel or _M.channel
    sendRaw("PRIVMSG " .. toChannel(c) .. " :" .. text)   -- todo: escape
end

_M.reconnect = function()
    _M.setState("reconnecting") -- do we need it? not sure
    if _M.chatSock then
        if _M.chatSockId then
            NetworkManager.delSocket(_M.chatSockId)
            _M.chatSockId = nil
        else
            _M.chatSock:close()
        end
        _M.chatSock = nil
    end
    connect()
end

_M.toUsername = toUsername
_M.toChannel = toChannel

return _M