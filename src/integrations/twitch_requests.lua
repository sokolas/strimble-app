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

local function checkError(ok, res)
    -- logger.log("checking response for error", ok, res)
    if not ok then
        return ok, res
    end

    if res.body then
        local ok, result = pcall(Json.decode, res.body)
        if ok then
            if result.status then
                if result.status < 400 then
                    return true, result
                else
                    return false, string.format("%s: \"%s\"", result.error or res.status, result.message or "")
                end
            else
                return true, result -- successful responses don't have status
            end
        else
            return false, result
        end
    else
        if string.startsWith(res.status, "2") then
            return true -- body = nil
        else
            return false, res.status
        end
    end
end

local function apiGet(url)
    if not token then
        return false, "token is not set"
    end
    local ok, res = checkError(NetworkManager.get(url, {["Authorization"] = "Bearer " .. token, ["Client-Id"] = client_id}))
    -- logger.log("get result", ok, res)
    return ok, res
end

local function apiPost(url, body)
    if not token then
        return false, "token is not set"
    end
    local bodyJson = Json.encode(body)
    local ok, res = checkError(NetworkManager.post(url, {["Authorization"] = "Bearer " .. token, ["Client-Id"] = client_id, ["Content-Type"] = "application/json"}, bodyJson))
    logger.log("post result", ok, res)
    return ok, res
end

local function firstDataItem(ok, res)
    if ok and res and res.data then
        return ok, res.data[1]
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

local function sendAnnouncement(message)
    local body = {
        message = message
    }
    return apiPost(helix .. "/chat/announcements?broadcaster_id=" .. broadcaster_id .. "&moderator_id=" .. broadcaster_id, body)
end

-- Channel

local function getChannelInfo(id)
    local bId = broadcaster_id
    -- logger.log("bId", bId)
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
    sendAnnouncement = sendAnnouncement,

    -- vhannel
    getChannelInfo = getChannelInfo,
}

return _M
