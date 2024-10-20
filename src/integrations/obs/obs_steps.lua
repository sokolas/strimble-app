local logger = Logger.create("obs_steps")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local obs = require("src/integrations/obs/obs")
local Ctx = require("src/stuff/action_context")

local _M = {}

local submenu = wx.wxMenu()
local steps = {}

local stepIconPaths = {
    {path = "src/integrations/obs/icons/obs.png", name = "obs"},
}

local stepIcons = {}

local function registerStepIcons()
    stepIcons = iconsHelper.registerStepIcons(stepIconPaths)
end

local function sendRequest(ctx, params)
    local d = Json.decode(ctx:interpolate(params.requestData))
    local ok, res = obs.request(params.requestType, d)
    logger.log("send request result", res)
    return ok, res
end

local function init(menu, stepHandlers)
    -- send message
    steps.sendRequest = submenu:Append(wx.wxID_ANY, "send custom request")

    steps.sendRequestDialog = dialogHelper.createStepDialog(Gui, "SendObsRequestDlg", {
        {
            name = "Send Hotkey",
            controls = {
                {
                    name = "requestType",
                    label = "Request type",
                    type = "text"
                },
                {
                    name = "requestData",
                    label = "Request data",
                    type = "multiline"
                },
                {
                    name = "comment",
                    label = "Comment",
                    type = "text"
                }
            }
        }
    },
    function(data, context)
        if (not data.requestType) or data.requestType == "" then
            return false, "Request type can't be empty"
        elseif (not data.requestData) or data.requestData == "" then
            return false, "Request data can't be empty"
        else
            local ok, d = Ctx.validateJson(data.requestData)
            if not ok then
                return false, "Request: " .. d
            end
            return true
        end
    end)
    
    stepHandlers[steps.sendRequest:GetId()] = {
        name = "Send custom OBS request",
        dialogItem = Gui.dialogs.SendObsRequestDlg,
        icon = stepIcons.obs,
        getDescription = function(result) return (result.requestType or "") .. " / " .. (result.comment or "") end,
        code = sendRequest,
        data = {
            requestData = "{}"
            -- hotkey = ""
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "OBS")
end

_M.sendHotkey = sendRequest
_M.registerStepIcons = registerStepIcons
_M.init = init

return _M