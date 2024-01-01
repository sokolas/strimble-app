local logger = Logger.create("default-trigger")

local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local function createDefaultTriggerDlg()
    local esDlg = dialogHelper.createTriggerDialog(Gui, "DefaultTriggerDialog",
        {
            {
                name = "Trigger properties",
                controls = {
                    {
                        name = "name",
                        label = "Name",
                        type = "text"
                    },
                    {
                        name = "params",
                        label = "Params",
                        type = "multiline"
                    },
                }
            }
        },
        -- validation
        function(data, context)
            return false, "can't edit unknown triggers"
        end
    )
    return esDlg
end

local function createDefaultTriggerFolder(name, triggerListCtrl)
    local rootTriggerItem = triggerListCtrl:GetRootItem()
    local pages = iconsHelper.getPages()
    local defaultTriggersItem = triggerListCtrl:AppendItem(rootTriggerItem, name or "Unknown", pages.question, pages.question)
    
    local treeItem = {
        id = defaultTriggersItem:GetValue(),
        isGroup = true,
        canAddChildren = false,
        childrenType = "",
        persistChildren = false,
        icon = pages.question, -- for children
        getDescription = function(result)
            return "unknown"
        end,
        dialog = Gui.dialogs.DefaultTriggerDialog,
        preProcess = function(result)
            local t = Json.encode(result)
            for k, v in pairs(result) do
                result[k] = nil
            end
            result.params = t
        end,
        add = "Add trigger",
        childEdit = "Edit event",
        data = { -- default values for new children
            name = "",
            params = "{}"
        }
    }
    return defaultTriggersItem, treeItem
end

local _M = {}

_M.getTriggerTypes = function() return {} end
_M.createTriggerDialog = createDefaultTriggerDlg
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createDefaultTriggerFolder(name, triggerListCtrl)
end

return _M
