local logger = Logger.create("eventsub-trigger")

local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local es_helper = require("src/integrations/es_helper")

local event_names = es_helper.scope_names

local triggerIcons = {}

local triggerIconPaths = {
    {path = "images/icons/twitch.png", name = "twitch_eventsub"},
}

local function registerTriggerIcons()
    triggerIcons = iconsHelper.registerTriggerIcons(triggerIconPaths)
end


local function createEventSubDlg()
    local esDlg = dialogHelper.createTriggerDialog(Gui, "EventSubDialog",
        {
            {
                name = "Event properties",
                controls = {
                    {
                        name = "name",
                        label = "Name",
                        type = "text"
                    },
                    {
                        name = "type",
                        label = "Type",
                        type = "combo"
                    }
                }
            }
        },
        -- validation
        function(data, context)
            if not data.type or data.type == "" then
                return false, "Type can't be empty"
            else
                return true
            end
        end
    )
    return esDlg
end

local function eventSubFilter(v)
    return v.type == "twitch_eventsub" and (not v.isGroup) and v.data and v.data.enabled
end

local function matchEvent(trigger, context)
    return trigger.data.type == context.payload.subscription.type
    --[[table.insert(result, {
        id = v.dbId,
        name = v.data.name,
        action = v.data.action
    })]]
end

local function createEventSubFolder(triggerListCtrl)
    local rootTriggerItem = triggerListCtrl:GetRootItem()
    local eventSubEvents = triggerListCtrl:AppendItem(rootTriggerItem, "Twitch Events", triggerIcons.twitch_eventsub, triggerIcons.twitch_eventsub)
    
    local treeItem = {
        id = eventSubEvents:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "twitch_eventsub",
        persistChildren = true,
        icon = triggerIcons.active, -- for children
        getDescription = function(result)
            return result.type
        end,
        dialog = Gui.dialogs.EventSubDialog,
        init = {
            type = function(c)
                c:Set(event_names)
            end
        },
        add = "Add event",
        childEdit = "Edit event",
        data = { -- default values for new children
            name = "Example event",
            type = "channel.follow",
            enabled = true
        },
        matches = matchEvent
    }
    return eventSubEvents, treeItem
end

local _M = {}

_M.getTriggerTypes = function() return {"twitch_eventsub"} end
_M.registerTriggerIcons = registerTriggerIcons
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createEventSubFolder(triggerListCtrl)
end
_M.createEventSubDlg = createEventSubDlg

return _M
