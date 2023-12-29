local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local _M = {}

local submenu = wx.wxMenu()
local steps = {}

local userQueryTypes = {
    "By ID",
    "By login"
}

local function sendMessage(ctx, params)
    if params.interpolate then
        Twitch.sendToChannel(ctx:interpolate(params.message), ctx.data.channel)
    else
        Twitch.sendToChannel(params.message, ctx.data.channel)
    end
    return true
end

local function getUser(ctx, params)
    -- if params.
    local ok, res = Twitch.getUserInfo(ctx:interpolate(params.user_id), params.type)
    return ok, res
end

local function init(menu, stepHandlers)
    local pages = iconsHelper.getPages()
    
    -- send message
    steps.sendMessageItem = submenu:Append(wx.wxID_ANY, "send message")

    steps.sendMessageDialog = dialogHelper.createDataDialog(Gui, "SendTwitchMessageStepDlg", {
        {
            name = "Send Twitch message",
            controls = {
                {
                    name = "message",
                    label = "Message",
                    type = "text"
                },
                {
                    name = "interpolate",
                    text = "Use variables",
                    type = "check"
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
        dialog = steps.sendMessageDialog,
        dialogItem = Gui.dialogs.SendTwitchMessageStepDlg,
        icon = pages.twitch,
        getDescription = function(result) return '"' .. result.message .. '"' end,
        postProcess = function(result) return result end,
        code = sendMessage,
        data = {
            message = "hello world",
            interpolate = false
        }
    }

    -- get user info
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
        dialog = steps.getUserDialog,
        dialogItem = Gui.dialogs.GetTwitchUserStepDlg,
        icon = pages.twitch,
        getDescription = function(result) return string.format("%s: %s", userQueryTypes[result.type + 1], result.user_id) end,
        -- postProcess = function(result) return result end,
        code = getUser,
        data = {
            user_id = "1",
            type = 0
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "Twitch")
end

_M.sendMessage = sendMessage
_M.init = init

return _M