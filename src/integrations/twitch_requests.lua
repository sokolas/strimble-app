local logger = Logger.create("twitch")

local client_id = ""
local broadcaster_id = ""
local token = ""

local function setToken(tkn)
    token = tkn
end

local function setBroadcasterId(id)
    broadcaster_id = id
end

local function setClientId(id)
    client_id = id
end

local function apiGet(url)
    if not token then
        return false, "token is not set"
    end
    return NetworkManager.get(url, {["Authorization"] = "Bearer " .. token, ["Client-Id"] = client_id})
end

local function apiPost(url, body)
    if not token then
        return false, "token is not set"
    end
    local bodyJson = Json.encode(body)
    local ok, res = NetworkManager.post(url, {["Authorization"] = "Bearer " .. token, ["Client-Id"] = client_id, ["Content-Type"] = "application/json"}, bodyJson)
    -- logger.log(ok, res)
    return ok, res
end

local function firstDataItem(ok, res)
    if ok then
        if res.status == "200 OK" then
            local valid, d = pcall(Json.decode, res.body)
            if d and d.data then
                return valid, d.data[1]
            end
            return valid, d
        else
            return false, res
        end
    else
        return false, res
    end
end

-- Users

local function getUserInfo(id, type)
    if (not id) or id == "" then
        return false, "empty id or login"
    end
    local ok, res
    if type == 0 then   -- by id
        local url = "https://api.twitch.tv/helix/users?id=" .. id
        -- logger.log(url)
        ok, res = apiGet(url)
    else -- by login
        local url = "https://api.twitch.tv/helix/users?login=" .. id
        -- logger.log(url)
        ok, res = apiGet(url)
    end
    return firstDataItem(ok, res)
end

-- Chat

local function sendMessage(message)
    local body = {
        broadcaster_id = broadcaster_id,
        sender_id = broadcaster_id,
        message = message
    }
    return apiPost("https://api.twitch.tv/helix/chat/messages", body)
end

-- export
local _M = {
    setBroadcasterId = setBroadcasterId,
    setToken = setToken,
    setClientId = setClientId,

    apiGet = apiGet,
    apiPost = apiPost,
    firstDataItem = firstDataItem,

    -- users
    getUserInfo = getUserInfo,

    -- chat
    sendMessage = sendMessage
}

return _M
