local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local requests = require("src/integrations/twitch_requests")

local _M = {}

local submenu = wx.wxMenu()
local steps = {}

local userQueryTypes = {
    "By ID",
    "By login"
}

local stepIcons = {
    {path = "images/icons/twitch.png", name = "twitch"},
}

local stepIconIndices = {}

local function registerIcons()
    stepIconIndices = iconsHelper.registerStepIcons(stepIcons)
end


-- chat

local function sendMessage(ctx, params)
    Twitch.sendToChannel(ctx:interpolate(params.message), ctx.data.channel)
    return true
end

local function sendMessageStep(stepHandlers)
    steps.sendMessageItem = submenu:Append(wx.wxID_ANY, "Send message")

    steps.sendMessageDialog = dialogHelper.createDataDialog(Gui, "SendTwitchMessageStepDlg", {
        {
            name = "Send Twitch message",
            controls = {
                {
                    name = "message",
                    label = "Message",
                    type = "text"
                }
            }
        }
    },
    function(data, context)
        if not data.message or data.message == "" then
            return false, "Message can't be empty"
        else
            return true
        end
    end)
    
    stepHandlers[steps.sendMessageItem:GetId()] = {
        name = "Send Twitch Message",
        dialogItem = Gui.dialogs.SendTwitchMessageStepDlg,
        icon = stepIconIndices.twitch,
        getDescription = function(result) return '"' .. result.message .. '"' end,
        postProcess = function(result) return result end,
        code = sendMessage,
        data = {
            message = "hello world"
        }
    }
end

local function sendAnnouncement(ctx, params)
    requests.sendAnnouncement(ctx:interpolate(params.message))
    return true
end

local function sendAnnouncementStep(stepHandlers)
    steps.sendAnnouncementItem = submenu:Append(wx.wxID_ANY, "Send announcement")

    steps.sendAnnouncementDialog = dialogHelper.createDataDialog(Gui, "SendTwitchAnnouncementStepDlg", {
        {
            name = "Send Twitch announcement",
            controls = {
                {
                    name = "message",
                    label = "Message",
                    type = "text"
                }
            }
        }
    },
    function(data, context)
        if not data.message or data.message == "" then
            return false, "Message can't be empty"
        else
            return true
        end
    end)
    
    stepHandlers[steps.sendAnnouncementItem:GetId()] = {
        name = "Send Twitch Announcement",
        dialogItem = Gui.dialogs.SendTwitchAnnouncementStepDlg,
        icon = stepIconIndices.twitch,
        getDescription = function(result) return '"' .. result.message .. '"' end,
        postProcess = function(result) return result end,
        code = sendAnnouncement,
        data = {
            message = "hello world"
        }
    }
end


-- users

local function getUser(ctx, params)
    -- if params.
    return requests.getUserInfo(ctx:interpolate(params.user_id), params.type)
end

local function getUserInfoStep(stepHandlers)
    steps.getUserItem = submenu:Append(wx.wxID_ANY, "Get user")

    steps.getUserDialog = dialogHelper.createStepDialog(Gui, "GetTwitchUserStepDlg", {
        {
            name = "Get user",
            controls = {
                {
                    name = "user_id",
                    label = "ID or login",
                    type = "text"
                },
                {
                    name = "type",
                    text = "Query type",
                    type = "choice",
                    choices = userQueryTypes
                }
            }
        }
    },
    function(data, context)
        if not data.user_id or data.user_id == "" then
            return false, "ID/login can't be empty"
        elseif data.type == -1 then
            return false, "Query type must be specified"
        else
            return true
        end
    end)

    stepHandlers[steps.getUserItem:GetId()] = {
        name = "Get user",
        dialogItem = Gui.dialogs.GetTwitchUserStepDlg,
        icon = stepIconIndices.twitch,
        getDescription = function(result) return string.format("%s: %s", userQueryTypes[result.type + 1], result.user_id) end,
        -- postProcess = function(result) return result end,
        code = getUser,
        data = {
            user_id = "1",
            type = 0
        }
    }
end


-- channel

local function getChannelInfo(ctx, params)
    -- if params.
    return requests.getChannelInfo(ctx:interpolate(params.user_id))
end

local function getChannelInfoStep(stepHandlers)
    steps.getChannelInfoItem = submenu:Append(wx.wxID_ANY, "Get channel info")

    steps.getTwitchChannelInfoStepDlg = dialogHelper.createStepDialog(Gui, "GetTwitchChannelInfoStepDlg", {
        {
            name = "Get channel info",
            controls = {
                {
                    name = "user_id",
                    label = "User ID",
                    type = "text"
                }
            }
        }
    },
    function(data, context)
        return true
    end)

    local function idOrSelf(userId)
        if (not userId) or userId == "" then
            return "<self>"
        else
            return userId
        end
    end

    stepHandlers[steps.getChannelInfoItem:GetId()] = {
        name = "Get channel info",
        dialogItem = Gui.dialogs.GetTwitchChannelInfoStepDlg,
        icon = stepIconIndices.twitch,
        getDescription = function(result) return idOrSelf(result.user_id) end,
        code = getChannelInfo,
        data = {
            user_id = ""
        }
    }
end

local function init(menu, stepHandlers)
    -- chat
    sendMessageStep(stepHandlers)
    sendAnnouncementStep(stepHandlers)

    -- users
    getUserInfoStep(stepHandlers)

    -- channel
    getChannelInfoStep(stepHandlers)

    -- finalize
    menu:AppendSubMenu(submenu, "Twitch")
end

_M.sendMessage = sendMessage
_M.init = init
_M.registerIcons = registerIcons

return _M