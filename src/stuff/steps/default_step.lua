local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local _M = {}

local logger = Logger.create("default_step")

local submenu = wx.wxMenu()
local steps = {}

local function abort(ctx, params)
    logger.log("the step is for an unknown integration - aborting")
    return false
end

local function skip(ctx, params)
    logger.log("the step is for an unknown integration - skipping")
    return true
end

local function init(menu, stepHandlers)
    local pages = iconsHelper.getPages()

    steps.editDialog = dialogHelper.createDataDialog(Gui, "DefaultStepDialog", {
        {
            name = "Unknown step",
            controls = {
            {
                name = "info",
                label = "Info",
                type = "multiline"
            }
        }
        }
    },
    function(data, context)
        return false, "Can't edit this action"
    end)
    
    stepHandlers["default"] = {
        name = "<Unknown - Abort>",
        dialog = steps.editDialog,
        dialogItem = Gui.dialogs.DefaultStepDialog,
        icon = pages.question,
        -- getDescription = function(result) return result.description end,
        preProcess = function(params)
            return {
                info = Json.encode(params)
            }
        end,
        code = abort,
        data = {
            info = "{}"
        }
    }

    -- finalize
    -- menu:AppendSubMenu(submenu, "General")
end

_M.abort = abort
_M.init = init

return _M