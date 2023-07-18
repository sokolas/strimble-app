local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local json = require("json")
local commands = require("src/stuff/commands")
local dataHelper = require("src.stuff.data_helper")
local ctxHelper = require("src.stuff.action_context")

local triggerListCtrl = nil
local commandWhere = commands.commandsWhere

local logger = Logger.create("triggers_gui")

local _M = {
    treedata = {}
}

local function addChild(parentItem, result)
    local parentTreeItem = _M.treedata[parentItem:GetValue()]
    local cmd1 = triggerListCtrl:AppendItem(parentItem, result.name, parentTreeItem.icon or -1, parentTreeItem.icon or -1)
    local item = {
        id = cmd1:GetValue(),
        dbId = result.dbId,   -- only present if loaded from DB
        name = result.name,
        canEdit = true,
        edit = parentTreeItem.childEdit,
        canDelete = true,
        delete = function() end,
        type = parentTreeItem.childrenType,
        persist = parentTreeItem.persistChildren,
        data = result
    }
    _M.treedata[cmd1:GetValue()] = item

    -- persist
    if not result.dbId then
        local insertStmt = Db:prepare("INSERT INTO triggers VALUES (NULL, :name, :type, :data);")
        insertStmt:bind_names({
            name = item.data.name,
            type = item.type,
            data = json.encode(item.data)
        })
        local res = insertStmt:step()
        if res ~= Sqlite.DONE then
            logger.err("Insert error", res, Db:errmsg())
        else
            local rowid = insertStmt:last_insert_rowid()
            logger.log("rowid", rowid)
            item.dbId = rowid
        end
        insertStmt:finalize()
    end

    -- update UI
    local action = dataHelper.findAction(function(a) return a.dbId and a.dbId == item.data.action end)
    triggerListCtrl:SetItemText(cmd1, 0, result.name)
    triggerListCtrl:SetItemText(cmd1, 2, (result.enabled and "Yes" or "No"))
    triggerListCtrl:SetItemText(cmd1, 3, result.text .. " (" .. commandWhere[result.where + 1] ..")")   -- TODO calculate per item type
    if #action > 0 then
        triggerListCtrl:SetItemText(cmd1, 4, (action[1].name or ""))
    else
        triggerListCtrl:SetItemText(cmd1, 4, "")
    end

    if not triggerListCtrl:IsExpanded(parentItem) then
        triggerListCtrl:Expand(parentItem)
    end
end

local function updateItemInDb(treeItem)
    local updateStmt = Db:prepare("UPDATE triggers SET name=:name, type=:type, data=:data WHERE id = :id;")
    updateStmt:bind_names({
        id = treeItem.dbId,
        name = treeItem.data.name,
        type = treeItem.type,
        data = json.encode(treeItem.data)
    })
    local res = updateStmt:step()
    if res ~= Sqlite.DONE then
        logger.err("Update error", res, Db:errmsg())
    end
    updateStmt:finalize()
end

local function updateItem(item, result)
    local treeItem = _M.treedata[item:GetValue()]
    treeItem.data = result
    treeItem.name = result.name

    -- update UI
    local action = dataHelper.findAction(function(a) return a.dbId and a.dbId == result.action end)
    triggerListCtrl:SetItemText(item, 0, result.name)
    triggerListCtrl:SetItemText(item, 2, (result.enabled and "Yes" or "No"))
    triggerListCtrl:SetItemText(item, 3, result.text .. " (" .. commandWhere[result.where + 1] ..")")   -- TODO calculate per item type
    if #action > 0 then
        triggerListCtrl:SetItemText(item, 4, (action[1].name or ""))
    else
        triggerListCtrl:SetItemText(item, 4, "")
    end

    -- persist
    logger.log(treeItem.dbId, treeItem.data.name, "updating")
    updateItemInDb(treeItem)
end

local function deleteItem(item, deleteFromDb)
    logger.log("Deleting " .. tostring(item:GetValue()))
    local treeItem = _M.treedata[item:GetValue()]
    local dbId = treeItem.dbId
    _M.treedata[item:GetValue()] = nil

    -- update UI
    triggerListCtrl:DeleteItem(item)
    
    -- persist
    if deleteFromDb then
        local deleteStmt = Db:prepare("DELETE FROM triggers WHERE id=:id;")
        deleteStmt:bind_names({
            id = dbId
        })
        local res = deleteStmt:step()
        if res ~= Sqlite.DONE then
            logger.err("Delete error", res, Db:errmsg())
        end
        deleteStmt:finalize()
    end
end

local function toggleItem(item, enabled)
    logger.log("Toggling " .. tostring(item:GetValue()) .. " to " .. tostring(enabled))
    local treeItem = _M.treedata[item:GetValue()]
    _M.treedata[item:GetValue()].data.enabled = enabled

    -- update UI
    triggerListCtrl:SetItemText(item, 2, (enabled and "Yes" or "No"))
    
    -- persist
    logger.log(treeItem.dbId, treeItem.data.name, "updating")
    updateItemInDb(treeItem)
end

-- creates
--      gui.triggers.triggersList
--      gui.dialogs.CommandDialog
--      gui.menus.triggerMenu
--      gui.CommandDialog.* fields
local function init()
    local commandDlg = dialogHelper.createDataDialog(Gui, "CommandDialog", "Trigger properties", {
            {
                name = "name",
                label = "Name",
                type = "text"
            },
            {
                name = "text",
                label = "Text to activate",
                type = "text"
            },
            {
                name = "where",
                label = "Where",
                type = "choice",
                choices = commandWhere
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
        },
        -- validation
        function(data, context)
            if not data.name or data.name == "" then
                return false, "Name can't be empty"
            elseif data.where == -1 then
                return false, "'Where' should be specified"
            elseif not data.text or data.text == "" then
                return false, "Text can't be empty"
            else
                if context and context.id then
                    for i, v in pairs(_M.treedata) do
                        if i ~= context.id and not v.isGroup and v.name == data.name then
                            return false, "Name must be unique"
                        end
                    end
                else
                    for i, v in pairs(_M.treedata) do
                        if not v.isGroup and v.name == data.name then
                            return false, "Name must be unique"
                        end
                    end
                end
                return true
            end
        end)
    if not commandDlg then return end

    local triggerMenu = wx.wxMenu()
    -- triggerMenu:SetTitle("ololo")
    local menuAddItem = triggerMenu:Append(wx.wxID_ANY, "Add...")
    local menuEditItem = triggerMenu:Append(wx.wxID_ANY, "Edit...")
    local menuToggleItem = triggerMenu:AppendCheckItem(wx.wxID_ANY, "Enabled")
    triggerMenu:AppendSeparator()
    local menuDeleteItem = triggerMenu:Append(wx.wxID_ANY, "Delete")
    Gui.menus.triggerMenu = triggerMenu

    triggerListCtrl = dialogHelper.replaceElement(Gui, "triggersPlaceholder", function(parent)
        return wx.wxTreeListCtrl(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTL_DEFAULT_STYLE)
    end, "triggersList", "triggers")
    
    -- triggerListCtrl:AppendColumn("")
    triggerListCtrl:AppendColumn("Name")
    triggerListCtrl:AppendColumn("Can create")
    triggerListCtrl:AppendColumn("Enabled")
    triggerListCtrl:AppendColumn("Description")
    triggerListCtrl:AppendColumn("Action")

    _M.imageList = iconsHelper.createImageList()   -- despite the docs, imagelist is not transferred to the tree control, so we use SetImageList and keep the ref
    triggerListCtrl:SetImageList(_M.imageList)

    local rootTriggerItem = triggerListCtrl:GetRootItem()
    
    -- predefined items
    _M.treedata[rootTriggerItem:GetValue()] = {
        id = rootTriggerItem:GetValue(),
        isGroup = true,
        name = "root",
        data = {
        }
    }

    local twitchCmds = triggerListCtrl:AppendItem(rootTriggerItem, "Twitch commands", iconsHelper.pages.twitch,
        iconsHelper.pages.twitch)
    _M.treedata[twitchCmds:GetValue()] = {
        id = twitchCmds:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "twitch_command",
        persistChildren = true,
        icon = iconsHelper.pages.scripts,   -- for children
        -- canDeleteChildren = true,
        add = function(id, data)
            local actionIds, actionNames = dataHelper.getActionData()
            local init = {action = function(c) c:Set(actionNames) end}
            local dlgData = CopyTable(data)
            dlgData.action = nil
            for i = 1, #actionIds do
                if actionIds[i] == data.action then
                    dlgData.action = actionNames[i]
                    break
                end
            end
            local m, result = Gui.dialogs.CommandDialog.executeModal("Add command", dlgData, init)
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
        end,
        childEdit = function(id, data)
            local actionIds, actionNames = dataHelper.getActionData()
            local init = {action = function(c) c:Set(actionNames) end}
            local dlgData = CopyTable(data)
            dlgData.action = nil
            for i = 1, #actionIds do
                if actionIds[i] == data.action then
                    dlgData.action = actionNames[i]
                    break
                end
            end
            local m, result = Gui.dialogs.CommandDialog.executeModal("Edit command", dlgData, init, {id = id})
            if m == wx.wxID_OK then
                local actionName = result.action
                logger.log(actionName)
                result.action = nil
                for i = 1, #actionNames do
                    if actionNames[i] == actionName then
                        result.action = actionIds[i]
                        break
                    end
                end
                logger.log(result.action)
                return result
            end
        end,
        data = {    -- default values for new children
            name = "Example command",
            text = "!hello",
            where = 0,
            enabled = true
        }
    }
    triggerListCtrl:SetItemText(twitchCmds, 1, "+") -- TODO make this dependent on canAddChildren

    -- adding and editing events
    triggerListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_CONTEXT_MENU, function(e) -- right click
        local i = e:GetItem():GetValue()
        local treeItem = _M.treedata[i]
        logger.log(treeItem.name)

        Gui.menus.triggerMenu:Enable(menuAddItem:GetId(), treeItem.canAddChildren == true)
        Gui.menus.triggerMenu:Enable(menuEditItem:GetId(), treeItem.canEdit == true)
        Gui.menus.triggerMenu:Enable(menuDeleteItem:GetId(), treeItem.canDelete == true)
        Gui.menus.triggerMenu:Enable(menuToggleItem:GetId(), (not treeItem.isGroup))    -- disable toggling for whole groups for now
        Gui.menus.triggerMenu:Check(menuToggleItem:GetId(), treeItem.data.enabled == true)

        local menuSelection = Gui.frame:GetPopupMenuSelectionFromUser(Gui.menus.triggerMenu, wx.wxDefaultPosition)
        logger.log(menuSelection)
        
        if menuSelection == menuAddItem:GetId() then    -- add new item
            local result = treeItem.add(i, treeItem.data)
            if not result then
                logger.err("'Add item' error")
            else
                addChild(e:GetItem(), result)
            end
        elseif menuSelection == menuEditItem:GetId() then   -- edit item TODO move to a function
            local result = treeItem.edit(i, treeItem.data)
            if not result then
                logger.err("'Edit item' error")
            else
                updateItem(e:GetItem(), result)
            end
        elseif menuSelection == menuDeleteItem:GetId() then
            deleteItem(e:GetItem(), true)
        elseif menuSelection == menuToggleItem:GetId() then
            toggleItem(e:GetItem(), menuToggleItem:IsChecked())
        end
    end)

    triggerListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_ACTIVATED, function(e) -- double click
        local i = e:GetItem():GetValue()
        local treeItem = _M.treedata[i]

        if treeItem.isGroup then
            if not triggerListCtrl:IsExpanded(e:GetItem()) then
                triggerListCtrl:Expand(e:GetItem())
            else
                triggerListCtrl:Collapse(e:GetItem())
            end
        else
            if treeItem.canEdit then  -- edit item TODO move to a function
                local result = treeItem.edit(i, treeItem.data)
                if not result then
                    logger.log("'Edit item' cancelled or error")
                else
                    updateItem(e:GetItem(), result)
                end
            end
        end
    end)
end

_M.init = init

_M.load = function()
    local item = triggerListCtrl:GetFirstItem()
    while item:IsOk() do
        -- logger.log("item", item:GetValue())
        local treeItem = _M.treedata[item:GetValue()]
        if treeItem then
            -- logger.log(treeItem.name)
            if treeItem.childrenType == "twitch_command" and treeItem.isGroup then     -- hardcoded logic for twitch commands
                local children = {}
                local child = triggerListCtrl:GetFirstChild(item)
                while child:IsOk() do
                    table.insert(children, child)
                    child = triggerListCtrl:GetNextSibling(child)
                end
                for i, v in ipairs(children) do
                    deleteItem(v, false)
                end
                children = nil

                for row in Db:nrows("SELECT * FROM triggers WHERE type = 'twitch_command'") do
                    local result = json.decode(row.data)
                    result.dbId = row.id
                    addChild(item, result)
                    if not triggerListCtrl:IsExpanded(item) then
                        triggerListCtrl:Expand(item)
                    end
                end
            end
        else
            logger.err("treeitem not found")
        end
        item = triggerListCtrl:GetNextSibling(item)
    end
    dataHelper.setTriggers(_M.treedata)
    logger.log("Triggers load OK")
end

_M.export = function()  -- to json
end

_M.onTrigger = function(type, data)
    if type == "twitch_privmsg" then    -- assume data has a text field
        if data and data.text then
            -- return commands.matchCommands(data.text)
            local matchedCommands = commands.matchCommands(data.text)
            if matchedCommands then
                for i, cmd in ipairs(matchedCommands) do
                    if cmd.action then
                        local actions = dataHelper.findAction(dataHelper.enabledByDbId(cmd.action))
                        local action = actions[1]
                        if action then
                            local ctx = ctxHelper.create({
                                user = data.user,
                                value = data.text, -- TODO parse into command and params
                                channel = data.channel
                            }, cmd.action)
                            local queue = dataHelper.getActionQueue(action.data.queue)
                            table.insert(queue, ctx)
                            logger.log("action found:", action.data.name, action.data.description, "queue:", action.data.queue, #queue)
                            Gui.frame:QueueEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ACTION_DISPATCH))
                        end
                    else
                        logger.log("no action mapped for ", cmd.name)
                    end
                end
            end
        end
    end
end

return _M