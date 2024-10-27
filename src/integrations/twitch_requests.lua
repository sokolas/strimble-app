local logger = Logger.create("twitch")

local client_id = ""
local broadcaster_id = ""
local token = ""

local helix = "https://api.twitch.tv/helix"

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
        local url = helix .. "/users?id=" .. id
        -- logger.log(url)
        ok, res = apiGet(url)
    else -- by login
        local url = helix .. "/users?login=" .. id
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
    return apiPost(helix .. "/chat/messages", body)
end

-- Channel

local function getChannelInfo(id)
    local bId = broadcaster_id
    logger.log("bId", bId)
    if id and id ~= "" then
        bId = id
    end
    if (not bId) or bId == "" then
        return false, "empty id and broadcaster_id"
    end

    local ok, res = apiGet(helix .. "/channels?broadcaster_id=" .. bId)
    return firstDataItem(ok, res)
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
    sendMessage = sendMessage,

    -- vhannel
    getChannelInfo = getChannelInfo,
}

return _M
