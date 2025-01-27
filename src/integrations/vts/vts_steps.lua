local logger = Logger.create("vts_steps")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local vts = require("src/integrations/vts/vts")

local _M = {}

local submenu = wx.wxMenu()

local stepIconPaths = {
    {path = "src/integrations/vts/icons/vts.png", name = "vts"},
}

local stepIcons = {}

local function registerStepIcons()
    stepIcons = iconsHelper.registerStepIcons(stepIconPaths)
end

local function sendHotkey(ctx, params)
    vts.sendHotkey(params.hotkey)
    return true
end

local function init(menu, stepHandlers)
    -- send message
    local sendHotkeyItem = submenu:Append(wx.wxID_ANY, "send hotkey")

    local sendHotkeyDialog = dialogHelper.createStepDialog(Gui, "SendVtsHotkeyDlg", {
        {
            name = "Send Hotkey",
            controls = {
                {
                    name = "hotkey",
                    label = "Name or ID",
                    type = "combo"
                },
                {
                    name = "comment",
                    label = "Comment",
                    type = "multiline"
                }
            }
        }
    },
    function(data, context)
        if not data.hotkey or data.hotkey == "" then
            return false, "Hotkey can't be empty"
        else
            return true
        end
    end)
    
    stepHandlers[sendHotkeyItem:GetId()] = {
        name = "Send VTube Studio Hotkey",
        dialogItem = sendHotkeyDialog,
        icon = stepIcons.vts,
        getDescription = function(result) return (result.comment or "") .. "(" .. result.hotkey .. ")" end,
        init = {
            hotkey = function(c)
                local hotkeys = {}
                for i, v in ipairs(vts.getHotkeys()) do
                    table.insert(hotkeys, v.name or v.hotkeyID)
                end
                logger.log(#hotkeys)
                c:Set(hotkeys)
            end
        },
        postProcess = function(result)
            local hotkeys = vts.getHotkeys()
            local comment = result.comment
            -- logger.log("user comment", comment)
            if hotkeys and #hotkeys > 0 then
                for i, v in ipairs(hotkeys) do
                    if result.hotkey == v.name or result.hotkey == v.hotkeyID then
                        -- logger.log("hotkey found")
                        if (not comment) or comment == "" then
                            -- logger.log("changing comment")
                            comment = v.name
                        end
                        return {
                            hotkey = v.hotkeyID,
                            comment = comment
                        }
                    end
                end
            end
            return result
        end,
        code = sendHotkey,
        data = {
            hotkey = ""
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "VTube Studio")
end

_M.sendHotkey = sendHotkey
_M.registerStepIcons = registerStepIcons
_M.init = init

return _M