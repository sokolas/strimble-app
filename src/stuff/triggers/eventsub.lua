local logger = Logger.create("eventsub-trigger")

local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")

local es_helper = require("src/integrations/es_helper")

local event_names = es_helper.scope_names

local function createEventSubDlg()
    local esDlg = dialogHelper.createDataDialog(Gui, "EventSubDialog", 
        {
            ["Event properties"] = {
                {
                    name = "name",
                    label = "Name",
                    type = "text"
                },
                {
                    name = "type",
                    label = "Type",
                    type = "combo"
                },
                {
                    name = "action",
                    label = "Action",
                    type = "combo"
                },
                {
                    name = "enabled",
                    text = "Enabled",
                    type = "check",
                    value = true
                }
            }
        },
        -- validation
        function(data, context)
            if not data.name or data.name == "" then
                return false, "Name can't be empty"
            elseif not data.type or data.type == "" then
                return false, "Type can't be empty"
            else
                if context and context.id then
                    local duplicates = dataHelper.findTriggers(function(v)
                        return v.id ~= context.id and not v.isGroup and v.name == data.name
                    end)
                    if #duplicates > 0 then
                        return false, "Name must be unique"
                    end
                else
                    local duplicates = dataHelper.findTriggers(function(v)
                        return not v.isGroup and v.name == data.name
                    end)
                    if #duplicates > 0 then
                        return false, "Name must be unique"
                    end
                end
                return true
            end
        end
    )
    return esDlg
end

local function eventSubFilter(v)
    return v.type == "twitch_eventsub" and (not v.isGroup) and v.data and v.data.enabled
end

local function matchTrigger(data)
    local result = {}

    for i, v in ipairs(dataHelper.findTriggers(eventSubFilter)) do
        if v.data.type == data.payload.subscription.type then
            table.insert(result, {
                id = v.dbId,
                name = v.data.name,
                action = v.data.action
            })
        end
    end
    if #result then
        return result
    end
end

local function addOrEdit(title, mode)
    return function(id, data)
        local actionIds, actionNames = dataHelper.getActionData()
        local init = {
            action = function(c)
                c:Set(actionNames)
            end,
            type = function(c)
                c:Set(event_names)
            end
         }
        local dlgData = CopyTable(data)
        dlgData.action = nil
        for i = 1, #actionIds do
            if actionIds[i] == data.action then
                dlgData.action = actionNames[i]
                break
            end
        end
        local ctx = nil
        if mode == "edit" then
            ctx = { id = id }
        end
        local m, result = Gui.dialogs.EventSubDialog.executeModal(title, dlgData, init, ctx)
        if m == wx.wxID_OK then
            local actionName = result.action
            result.action = nil
            for i = 1, #actionNames do
                if actionNames[i] == actionName then
                    result.action = actionIds[i]
                    break
                end
            end
            return result
        end
    end
end

local function createEventSubFolder(triggerListCtrl, rootTriggerItem)
    local pages = iconsHelper.getPages()
    local eventSubEvents = triggerListCtrl:AppendItem(rootTriggerItem, "Twitch EventSub", pages.twitch, pages.twitch)
    
    local treeItem = {
        id = eventSubEvents:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "twitch_eventsub",
        persistChildren = true,
        icon = pages.scripts, -- for children
        getDescription = function(result)
            return result.type
        end,
        -- canDeleteChildren = true,
        add = addOrEdit("Add event", "add"),
        childEdit = addOrEdit("Edit event", "edit"),
        data = { -- default values for new children
            name = "Example event",
            type = "channel.follow",
            enabled = true
        }
    }
    triggerListCtrl:SetItemText(eventSubEvents, 1, "+") -- TODO make this dependent on canAddChildren
    return eventSubEvents, treeItem
end

local _M = {}

_M.createEventSubDlg = createEventSubDlg
_M.createEventSubFolder = createEventSubFolder
_M.matchTrigger = matchTrigger

return _M
