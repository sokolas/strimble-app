local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local _M = {}

local submenu = wx.wxMenu()
local steps = {}

local function sendMessage(ctx, params)
    Twitch.sendToChannel(params.message, ctx.data.channel)
    return true
end

local function init(menu, dialogs)
    -- send message
    steps.sendMessageItem = submenu:Append(wx.wxID_ANY, "send message")

    steps.sendMessageDialog = dialogHelper.createDataDialog(Gui, "SendTwitchMessageStepDlg", "Send Twitch message", {
        {
            name = "message",
            label = "Message",
            type = "text"
        }
    },
    function(data, context)
        if not data.message or data.message == "" then
            return false, "Message can't be empty"
        else
            return true
        end
    end)
    
    dialogs[steps.sendMessageItem:GetId()] = {
        name = "Send Twitch Message",
        dialog = steps.sendMessageDialog,
        dialogItem = Gui.dialogs.SendTwitchMessageStepDlg,
        icon = iconsHelper.pages.twitch,
        getDescription = function(result) return '"' .. result.message .. '"' end,
        postProcess = function(result) return result end,
        code = sendMessage,
        data = {
            message = "hello world"
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "Twitch")
end

-- TODO:
-- create dialogs for everything
-- connect the listeners somewhere?

_M.sendMessage = sendMessage
_M.init = init

return _M