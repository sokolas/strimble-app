local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local json = require("json")
local commands = require("src/stuff/triggers/commands")
local timers = require("src/stuff/triggers/timers")
local defaultTrigger = require("src/stuff/triggers/default_trigger")
local eventsub = require("src/stuff/triggers/eventsub")
local dataHelper = require("src/stuff/data_helper")
local ctxHelper = require("src/stuff/action_context")

local builtInTriggers = {
    commands, eventsub, timers
}

local triggerListCtrl = nil

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
        dialog = parentTreeItem.dialog,
        init = parentTreeItem.init,
        preProcess = parentTreeItem.preProcess,
        postProcess = parentTreeItem.postProcess,
        edit = parentTreeItem.childEdit,
        getDescription = parentTreeItem.getDescription,
        canDelete = true,
        onCreate = parentTreeItem.onCreate,
        onDelete = parentTreeItem.onDelete,
        onEnable = parentTreeItem.onEnable,
        onDisable = parentTreeItem.onDisable,
        onUpdate = parentTreeItem.onUpdate,
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
        res = insertStmt:finalize()
        if res ~= Sqlite.OK then
            logger.err("Finalize error", res, Db:errmsg())
        end
    end

    -- update UI
    local action = dataHelper.findAction(function(a) return a.dbId and a.dbId == item.data.action end)
    triggerListCtrl:SetItemText(cmd1, 0, result.name)
    triggerListCtrl:SetItemText(cmd1, 1, (result.enabled and "Yes" or "No"))
    triggerListCtrl:SetItemText(cmd1, 2, item.getDescription(result))
    if #action > 0 then
        triggerListCtrl:SetItemText(cmd1, 3, (action[1].name or ""))
    else
        triggerListCtrl:SetItemText(cmd1, 3, "")
    end

    if not triggerListCtrl:IsExpanded(parentItem) then
        triggerListCtrl:Expand(parentItem)
    end

    if item.onCreate then
        item.onCreate(item, cmd1)
    end

    if result.enabled and item.onEnable then
        item.onEnable(item, cmd1)
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
    res = updateStmt:finalize()
    if res ~= Sqlite.OK then
        logger.err("Finalize error", res, Db:errmsg())
    end
end

local function updateItem(item, result, getDescription)
    local treeItem = _M.treedata[item:GetValue()]

    logger.log("onUpdate is", treeItem.onUpdate)
    if treeItem.onUpdate then
        treeItem.onUpdate(treeItem, item, result)
    end

    treeItem.data = result
    treeItem.name = result.name

    -- update UI
    local action = dataHelper.findAction(function(a) return a.dbId and a.dbId == result.action end)
    triggerListCtrl:SetItemText(item, 0, result.name)
    triggerListCtrl:SetItemText(item, 1, (result.enabled and "Yes" or "No"))
    triggerListCtrl:SetItemText(item, 2, getDescription(result))
    if #action > 0 then
        triggerListCtrl:SetItemText(item, 3, (action[1].name or ""))
    else
        triggerListCtrl:SetItemText(item, 3, "")
    end

    -- persist
    logger.log(treeItem.dbId, treeItem.data.name, "updating")
    updateItemInDb(treeItem)
end

local function deleteItem(item, deleteFromDb)
    logger.log("Deleting " .. tostring(item:GetValue()))
    local treeItem = _M.treedata[item:GetValue()]

    if treeItem.onDisable then
        treeItem.onDisable(treeItem, item)
    end

    if treeItem.onDelete then
        treeItem.onDelete(treeItem, item)
    end

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
        res = deleteStmt:finalize()
        if res ~= Sqlite.OK then
            logger.err("Finalize error", res, Db:errmsg())
        end
    end
end

local function toggleItem(item, enabled)
    logger.log("Toggling " .. tostring(item:GetValue()) .. " to " .. tostring(enabled))
    local treeItem = _M.treedata[item:GetValue()]
    treeItem.data.enabled = enabled

    -- update UI
    triggerListCtrl:SetItemText(item, 1, (enabled and "Yes" or "No"))
    
    -- persist
    logger.log(treeItem.dbId, treeItem.data.name, "updating")
    updateItemInDb(treeItem)

    if enabled and treeItem.onEnable then
        treeItem.onEnable(treeItem, item)
    end

    if not enabled and treeItem.onDisable then
        treeItem.onDisable(treeItem, item)
    end
end

local function actionsUpdated()
    logger.log("updating actions in triggers gui")
    local actionMap = {}

    for k, v in pairs(dataHelper.getActions()) do
        if not v.isGroup then
            actionMap[v.dbId] = v
        end
    end

    local item = triggerListCtrl:GetFirstItem()
    while item:IsOk() do
        local treeItem = _M.treedata[item:GetValue()]
        if treeItem and not treeItem.isGroup and treeItem.data.action then
            if not actionMap[treeItem.data.action] then
                treeItem.data.action = nil
                triggerListCtrl:SetItemText(item, 3, "")
            else
                triggerListCtrl:SetItemText(item, 3, (actionMap[treeItem.data.action].name or ""))
            end
        end
        item = triggerListCtrl:GetNextItem(item)
    end
end

local function onTrigger(type, data)
    if type == "twitch_privmsg" then    -- assume data has a text field
        if data and data.text then
            local matchedCommands = commands.matchCommands(data.text)
            if matchedCommands then
                for i, cmd in ipairs(matchedCommands) do
                    if cmd.action then
                        local actions = dataHelper.findAction(dataHelper.enabledByDbId(cmd.action))
                        local action = actions[1]
                        if action then
                            local queue = dataHelper.getActionQueue(action.data.queue)
                            logger.log("action found:", action.data.name, action.data.description, "queue:", action.data.queue, #queue)
                            local ctx = ctxHelper.create({
                                user = data.user,
                                value = data.text, -- TODO parse into command and params
                                channel = data.channel
                            }, cmd.action)
                            table.insert(queue, ctx)
                            logger.log("context created")
                            Gui.frame:QueueEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ACTION_DISPATCH))
                        else
                            logger.log("action mapped but not found for command", cmd.name)
                        end
                    else
                        logger.log("no action mapped for ", cmd.name)
                    end
                end
            end
        end
    elseif type == "timer" then
        if data.action then
            local actions = dataHelper.findAction(dataHelper.enabledByDbId(data.action))
            local action = actions[1]
            if action then
                local queue = dataHelper.getActionQueue(action.data.queue)
                logger.log("action found:", action.data.name, action.data.description, "queue:", action.data.queue, #queue)
                local ctx = ctxHelper.create({}, data.action)
                table.insert(queue, ctx)
                logger.log("context created")
                Gui.frame:QueueEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ACTION_DISPATCH))
            else
                logger.log("action mapped but not found for timer", data.name)
            end
        end
    elseif type == "twitch_eventsub" then
        if data.payload and data.payload.subscription and data.payload.subscription.type then
            local matchedEvents = eventsub.matchTrigger(data)
            if matchedEvents then
                for i, event in ipairs(matchedEvents) do
                    if event.action then
                        local actions = dataHelper.findAction(dataHelper.enabledByDbId(event.action))
                        local action = actions[1]
                        if action then
                            local queue = dataHelper.getActionQueue(action.data.queue)
                            logger.log("action found:", action.data.name, action.data.description, "queue:", action.data.queue, #queue)
                            local ctx = ctxHelper.create({
                                payload = data.payload
                            }, event.action)
                            table.insert(queue, ctx)
                            logger.log("context created")
                            Gui.frame:QueueEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ACTION_DISPATCH))
                        else
                            logger.log("action mapped but not found for event", event.name)
                        end
                    end
                end
            end
        end
    end
end

-- creates
--      gui.triggers.triggersList
--      gui.dialogs.CommandDialog
--      gui.menus.triggerMenu
--      gui.CommandDialog.* fields
local function init()
    local commandDlg = commands.createCommandDlg()
    if not commandDlg then return end

    local timerDlg = timers.createTimerDialog()
    if not timerDlg then return end

    local esDlg = eventsub.createEventSubDlg()
    if not esDlg then return end

    local defaultDlg = defaultTrigger.createTriggerDialog()
    if not defaultDlg then return end
    
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
        
        local addOrEdit = dialogHelper.addOrEditTrigger(treeItem.dialog, treeItem.init, treeItem.preProcess, treeItem.postProcess)
        if menuSelection == menuAddItem:GetId() then    -- add new item
            local result = addOrEdit(i, treeItem.add, "add", treeItem.data)
            if not result then
                logger.err("'Add item' error")
            else
                addChild(e:GetItem(), result)
            end
        elseif menuSelection == menuEditItem:GetId() then   -- edit item TODO move to a function
            local result = addOrEdit(i, treeItem.edit, "edit", treeItem.data)
            if not result then
                logger.err("'Edit item' error")
            else
                updateItem(e:GetItem(), result, treeItem.getDescription)
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
                local addOrEdit = dialogHelper.addOrEditTrigger(treeItem.dialog, treeItem.init, treeItem.preProcess, treeItem.postProcess)
                local result = addOrEdit(i, treeItem.edit, "edit", treeItem.data)
                if not result then
                    logger.log("'Edit item' cancelled or error")
                else
                    updateItem(e:GetItem(), result, treeItem.getDescription)
                end
            end
        end
    end)

    dataHelper.setActionsUpdate(actionsUpdated)
end

_M.init = init

local function load()
    logger.log("starting loading triggers")
    local item = triggerListCtrl:GetFirstItem()
    while item:IsOk() do
        -- logger.log("item", item:GetValue())
        local i = _M.treedata[item:GetValue()]
        if i and i.onDisable and not i.isGroup then
            i.onDisable(i, item)
        end
        if i and i.onDelete and not i.isGroup then
            i.onDelete(i, item)
        end
        _M.treedata[item:GetValue()] = nil
        item = triggerListCtrl:GetNextItem(item)
    end

    local size = 0
    for k, v in pairs(_M.treedata) do
        size = size + 1
    end
    logger.log("triggers treedata size", size)

    triggerListCtrl:DeleteAllItems()

    
    -- create built-in folders
    local knownTriggers = {}
    for j, integration in ipairs(builtInTriggers) do
        for i, triggerType in ipairs(integration.getTriggerTypes()) do
            local guiItem, treeItem = integration.createTriggerFolder(triggerType, triggerListCtrl, onTrigger)
            _M.treedata[treeItem.id] = treeItem
            knownTriggers[triggerType] = {
                guiItem = guiItem,
                treeItem = treeItem
            }
        end
    end

    for row in Db:nrows("SELECT * FROM triggers") do
        local result = json.decode(row.data)
        result.dbId = row.id
        -- logger.log(row.type)
        local trigger = knownTriggers[row.type]
        -- logger.log(trigger.guiItem)
        if trigger then
            addChild(trigger.guiItem, result)
            if not triggerListCtrl:IsExpanded(trigger.guiItem) then
                triggerListCtrl:Expand(trigger.guiItem)
            end
        else
            logger.err("Unknown trigger type: " .. tostring(row.type))
            local guiItem, treeItem = defaultTrigger.createTriggerFolder(row.type, triggerListCtrl)
            _M.treedata[treeItem.id] = treeItem
            knownTriggers[row.type] = {
                guiItem = guiItem,
                treeItem = treeItem
            }
            addChild(guiItem, result)
        end
    end

    dataHelper.setTriggers(_M.treedata)
    logger.log("Triggers load OK")
end

_M.load = load
_M.export = function()  -- to json
end

_M.onTrigger = onTrigger

return _M