local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local json = require("json")
local dataHelper = require("src/stuff/data_helper")

-- steps helpers
local twitchSteps = require("src/stuff/steps/twitch_steps")
local generalSteps = require("src/stuff/steps/general_steps")
local vtsSteps = require("src/stuff/steps/vts_steps")
local obsSteps = require("src/stuff/steps/obs_steps")

local actionsListCtrl = nil
local stepsListCtrl = nil

local groupNames = {}
local currentAction = {}

local logger = Logger.create("actions_gui")

local stepsHandlers = {}

local _M = {
    actionsData = {}
}

local function findStepByName(name)
    for k, v in pairs(stepsHandlers) do
        if v.name == name then
            return v
        end
    end
end

local function deleteItem(item, deleteFromDb)
    logger.log("Deleting " .. tostring(item:GetValue()))
    local treeItem = _M.actionsData[item:GetValue()]
    logger.log(treeItem.name)
    if treeItem.isGroup and actionsListCtrl:GetFirstChild(item):IsOk() then
        logger.err("Can't delete non-empty group item")
        return
    end
    local dbId = treeItem.dbId
    _M.actionsData[item:GetValue()] = nil

    -- update UI
    actionsListCtrl:DeleteItem(item)
    if not actionsListCtrl:GetSelection():IsOk() then
        logger.log("selection is invalid, cleaning up")
        currentAction = {}
        stepsListCtrl:DeleteAllItems()
    end

    -- persist
    if deleteFromDb then
        local deleteStmt = Db:prepare("DELETE FROM actions WHERE id=:id;")
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

        dataHelper.updateActions()  -- if we don't delete from db, then the action was not really deleted
    end
end

local function findItemById(ctrl, id)
    local item = ctrl:GetFirstItem()
    while item:IsOk() do
        if item:GetValue() == id then
            return item
        else
            item = ctrl:GetNextItem(item)
        end
    end
end

local function findGroup(name)
    for k, v in pairs(_M.actionsData) do
        if v.isGroup and v.name and v.name == name then
            logger.log(name, "found", k)
            local item = findItemById(actionsListCtrl, k)
            logger.log("item found", item)
            return item, v
        end
    end
end

local function findOrCreateGroup(group, rootActionItem)
    if not group or group == "" then
        group = "Default"
    end
    local groupItem, groupTreeItem = findGroup(group)
    logger.log("group find result for", group, groupItem, groupTreeItem)
    if not groupItem then
        groupItem, groupTreeItem = _M.addActionGroup(group, rootActionItem)
        logger.log("group create result for", group, groupItem, groupTreeItem)
    end
    return groupItem, groupTreeItem
end

function _M.addAction(groupGuiItem, data)
    local parentTreeItem = _M.actionsData[groupGuiItem:GetValue()]
    data.group = parentTreeItem.name    -- forcibly set the group to the one that was used during creation

    local guiItem = actionsListCtrl:AppendItem(groupGuiItem, data.name, iconsHelper.pages.actions, iconsHelper.pages.actions)
    local item = {
        id = guiItem:GetValue(),
        dbId = data.dbId,   -- only present if loaded from DB
        name = data.name,
        canEdit = true,
        edit = parentTreeItem.childEdit,
        canDelete = true,
        persist = parentTreeItem.persistChildren,
        data = data
    }
    _M.actionsData[guiItem:GetValue()] = item

    -- persist
    if not data.dbId then
        local insertStmt = Db:prepare("INSERT INTO actions VALUES (NULL, :name, :data);")
        if not insertStmt then
            logger.err(Db:errmsg())
        end
        insertStmt:bind_names({
            name = item.data.name,
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
    actionsListCtrl:SetItemText(guiItem, 0, data.name)
    actionsListCtrl:SetItemText(guiItem, 1, (data.enabled and "Yes" or "No"))
    actionsListCtrl:SetItemText(guiItem, 2, data.description or "")
    actionsListCtrl:SetItemText(guiItem, 3, data.queue or "")

    if not actionsListCtrl:IsExpanded(groupGuiItem) then
        actionsListCtrl:Expand(groupGuiItem)
    end

    dataHelper.updateActions()
    return item
end

local function updateActionItemInDb(treeItem)
    local updateStmt = Db:prepare("UPDATE actions SET name=:name, data=:data WHERE id = :id;")
    updateStmt:bind_names({
        id = treeItem.dbId,
        name = treeItem.data.name,
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

local function updateStepInDb(i, actionId, step)
    logger.log("updating step", i, step.dbId, actionId, step.prototype.name, step.description)
    local updateStmt = Db:prepare("UPDATE steps SET name=:name, action=:actionId, step_order=:step_order, description=:description, data=:data WHERE id=:id;")
    updateStmt:bind_names({
        id = step.dbId,
        actionId = actionId,
        name = step.prototype.name,
        step_order = i,
        description = step.description,
        data = json.encode(step.params)
    })
    local res = updateStmt:step()
    if res ~= Sqlite.DONE then
        logger.err("Update step error", res, updateStmt:errmsg())
    end
    res = updateStmt:finalize()
    if res ~= Sqlite.OK then
        logger.err("Finalize error", res, Db:errmsg())
    end
end

local function deleteStepFromDb(step)
    logger.log("deleting step", step.dbId, step.prototype.name, step.description)
    local updateStmt = Db:prepare("DELETE FROM steps WHERE id=:id;")
    updateStmt:bind_names({
        id = step.dbId,
    })
    local res = updateStmt:step()
    if res ~= Sqlite.DONE then
        logger.err("Delete step error", res, updateStmt:errmsg())
    end
    res = updateStmt:finalize()
    if res ~= Sqlite.OK then
        logger.err("Finalize error", res, Db:errmsg())
    end
end

local function updateStepsOrder(action)
    logger.log("updating steps order", action.dbId, action.name)
    for i, step in ipairs(action.steps) do
        local updateStmt = Db:prepare("UPDATE steps SET step_order=:step_order WHERE id=:id;")
        updateStmt:bind_names({
            id = step.dbId,
            step_order = i
        })
        local res = updateStmt:step()
        if res ~= Sqlite.DONE then
            logger.err("Update steps order error", res, updateStmt:errmsg())
        end
        res = updateStmt:finalize()
        if res ~= Sqlite.OK then
            logger.err("Finalize error", res, Db:errmsg())
        end            
    end
end

local function updateActionItem(item, result)
    local treeItem = _M.actionsData[item:GetValue()]
    treeItem.data = result
    treeItem.name = result.name

    local parent = actionsListCtrl:GetItemParent(item)
    local groupItem, _ = findOrCreateGroup(result.group, actionsListCtrl:GetRootItem())

    if parent:GetValue() == groupItem:GetValue() then
        -- update UI
        actionsListCtrl:SetItemText(item, 0, result.name)
        actionsListCtrl:SetItemText(item, 1, (result.enabled and "Yes" or "No"))
        actionsListCtrl:SetItemText(item, 2, result.description or "")
        actionsListCtrl:SetItemText(item, 3, result.queue or "")
    else
        local newItem = actionsListCtrl:AppendItem(groupItem, result.name, iconsHelper.pages.actions, iconsHelper.pages.actions)
        -- update UI
        actionsListCtrl:SetItemText(newItem, 0, result.name)
        actionsListCtrl:SetItemText(newItem, 1, (result.enabled and "Yes" or "No"))
        actionsListCtrl:SetItemText(newItem, 2, result.description or "")
        actionsListCtrl:SetItemText(newItem, 3, result.queue or "")

        _M.actionsData[newItem:GetValue()] = treeItem
        _M.actionsData[item:GetValue()] = nil
        actionsListCtrl:DeleteItem(item)
        
        actionsListCtrl:Select(newItem)
    end

    -- persist
    logger.log(treeItem.dbId, treeItem.data.name, "updating")
    updateActionItemInDb(treeItem)
    dataHelper.updateActions()
end

local function toggleItem(item, state)
    logger.log("Toggling " .. tostring(item:GetValue()))
    local treeItem = _M.actionsData[item:GetValue()]
    if treeItem.isGroup then
        return
    end
    
    treeItem.data.enabled = state

    -- update UI
    actionsListCtrl:SetItemText(item, 1, (treeItem.data.enabled and "Yes" or "No"))
    
    -- persist
    updateActionItemInDb(treeItem)
end

local function getNextGroupItem(item)
    local i = nil
    if item then
        i = actionsListCtrl:GetNextItem(item)
    else
        i = actionsListCtrl:GetFirstItem()
    end

    while i:IsOk() do
        logger.log(_M.actionsData[i:GetValue()])
        if _M.actionsData[i:GetValue()] and _M.actionsData[i:GetValue()].isGroup then
            return i
        end
        i = actionsListCtrl:GetNextItem(i)
    end
    return nil
end

local function placeAction(group, name)
    local r = {}
    for i, v in pairs(_M.actionsData) do
        if not v.isGroup and v.data and v.data.group == group then
            table.insert(r, v)
        end
    end
    table.insert(r, {new = true, data = { name = name }})
    table.sort(r, function(a, b)
        return a.data.name < b.data.name
    end)
    
    if r[#r].new then
        return "append"
    elseif r[1].new then
        return "prepend"
    else
        local i = 1
        while not r[i+1].new do
            i = i + 1
        end
        return "insert", r[i]
    end
end

function _M.addActionGroup(name, rootActionItem)
    local currentGroup = getNextGroupItem()
    local groupItem = nil
    if not currentGroup then
        groupItem = actionsListCtrl:AppendItem(rootActionItem, name, iconsHelper.pages.folder, iconsHelper.pages.folder)
    else
        if _M.actionsData[currentGroup:GetValue()].name >= name then
            groupItem = actionsListCtrl:PrependItem(rootActionItem, name, iconsHelper.pages.folder, iconsHelper.pages.folder)
        else
            local lastGroup = currentGroup
            while _M.actionsData[currentGroup:GetValue()].name < name do
                lastGroup = currentGroup
                currentGroup = getNextGroupItem(currentGroup)
                if currentGroup == nil then
                    break;
                end
            end
            groupItem = actionsListCtrl:InsertItem(rootActionItem, lastGroup, name, iconsHelper.pages.folder, iconsHelper.pages.folder)
        end
    end
    
    local treeItem = {
        id = groupItem:GetValue(),
        name = name,
        isGroup = true,
        canEdit = false,
        canAddChildren = true,
        persistChildren = true,
        icon = iconsHelper.pages.actions, -- for children
        -- canDeleteChildren = true,
        add = function(id, data)
            local groups = {}
            for k, v in pairs(_M.actionsData) do
                if v.isGroup then
                    table.insert(groups, v.name)
                end
            end
            local m, result = Gui.dialogs.ActionDialog.executeModal("Add action", data, {group = function(c) c:Set(groups) end})
            if m == wx.wxID_OK then
                return result
            end
        end,
        childEdit = function(id, data)
            local groups = {}
            for k, v in pairs(_M.actionsData) do
                if v.isGroup then
                    table.insert(groups, v.name)
                end
            end
            local m, result = Gui.dialogs.ActionDialog.executeModal("Edit action", data, {group = function(c) c:Set(groups) end}, {id = id})
            if m == wx.wxID_OK then
                return result
            end
        end,
        data = {
            enabled = true
        },
        childData = {
             -- default values for new children
            name = "Example action",
            queue = "Default",
            group = name,
            description = "",
            enabled = true
        }
    }
    _M.actionsData[groupItem:GetValue()] = treeItem
    return groupItem, treeItem
end

local function addStep(dbId, actionData, stepData)
    if not actionData.steps then
        actionData.steps = {}
    end
    table.insert(actionData.steps, stepData)

    local index = #actionData.steps
    if not dbId then
        local insertStmt = Db:prepare("INSERT INTO steps VALUES(NULL, :action, :step_order, :name, :description, :data)")
        if not insertStmt then
            logger.err(Db:errmsg())
        end
        insertStmt:bind_names({
            action = actionData.dbId,
            step_order = index,
            name = stepData.prototype.name,
            description = stepData.description,
            data = json.encode(stepData.params)
        })
        local res = insertStmt:step()
        if res ~= Sqlite.DONE then
            logger.err("Insert step error", res, Db:errmsg())
        else
            local rowid = insertStmt:last_insert_rowid()
            logger.log("step rowid", rowid)
            stepData.dbId = rowid
        end
        res = insertStmt:finalize()
        if res ~= Sqlite.OK then
            logger.err("Finalize step error", res, Db:errmsg())
        end
    end
end

local function editStep(m, selected, stepHandler, result, step, actionData, stepIndex)
    if m == wx.wxID_OK then
        stepsListCtrl:SetItemText(selected, 1, stepHandler.getDescription(result))
        local params = result
        logger.log(stepHandler.postProcess)
        if stepHandler.postProcess then
            params = stepHandler.postProcess(result)
        end
        local stepData = {
            dbId = step.dbId,
            prototype = stepHandler,
            description = stepHandler.getDescription(result),
            params = params
        }
        actionData.steps[stepIndex] = stepData
        updateStepInDb(stepIndex, actionData.dbId, stepData)
        return true
    end
end

local function callEditStepDialog(actionData, stepIndex, selected)
    local step = actionData.steps[stepIndex]
    local stepHandler = step.prototype
    if not stepHandler then return end

    local data = step.params
    if stepHandler.preProcess then
        data = stepHandler.preProcess(step.params)
    end
    local m, result = stepHandler.dialogItem.executeModal("Edit " .. stepHandler.name, data, stepHandler.init)
    editStep(m, selected, stepHandler, result, step, actionData, stepIndex)
end


-- creates
--      gui.actions.actionsList
--      gui.actions.stepsList
--      gui.menus.actionMenu
--      gui.menus.stepMenu
--      gui.dialogs.ActionDialog
--      gui.ActionDialog.* fields
function _M.init()
    local actionDlg = dialogHelper.createDataDialog(Gui, "ActionDialog", {
            ["Action properties"] = {
                {
                    name = "name",
                    label = "Name",
                    type = "text"
                },
                {
                    name = "group",
                    label = "Group",
                    type = "combo",
                    value = "Default"
                },
                {
                    name = "description",
                    label = "Description",
                    type = "multiline"
                },
                {
                    name = "queue",
                    label = "Queue",
                    type = "combo",
                    value = "Default"
                },
                {
                    name = "enabled",
                    text = "Enabled",
                    type = "check",
                    value = true
                }
            }
        },

        -- validate
        function(data, context)
            if not data.name or data.name == "" then
                return false, "Name can't be empty"
            else
                if context and context.id then
                    for i, v in pairs(_M.actionsData) do
                        if i ~= context.id and not v.isGroup and v.name == data.name then
                            return false, "Name must be unique"
                        end
                    end
                else
                    for i, v in pairs(_M.actionsData) do
                        if not v.isGroup and v.name == data.name then
                            return false, "Name must be unique"
                        end
                    end
                end
                return true
            end
        end)
    if not actionDlg then return end

    local actionGroupDlg = dialogHelper.createDataDialog(Gui, "ActionGroupDialog", {
        ["Group properties"] = {
            {
                name = "name",
                label = "Name",
                type = "text"
            },
            {
                name = "description",
                label = "Description",
                type = "text"
            }
        }
    },
    function(data, context) -- validate
        --[[if not data.name or data.name == "" then
            return false, "Name can't be empty"
        else
            if context and context.id then
                for i, v in pairs(_M.treedata) do
                    if i ~= context.id and not v.isGroup and v.name == data.name then
                        return false, "Name mush be unique"
                    end
                end
            else
                for i, v in pairs(_M.treedata) do
                    if not v.isGroup and v.name == data.name then
                        return false, "Name mush be unique"
                    end
                end
            end
            return true
        end]]
        return true
    end)
    if not actionGroupDlg then return end

    local actionMenu = wx.wxMenu()
    -- triggerMenu:SetTitle("ololo")
    local actionAddItem = actionMenu:Append(wx.wxID_ANY, "Add...")
    local actionEditItem = actionMenu:Append(wx.wxID_ANY, "Edit...")
    local actionToggleItem = actionMenu:AppendCheckItem(wx.wxID_ANY, "Enabled")
    actionMenu:AppendSeparator()
    local triggeredByMenu = wx.wxMenu()
    -- triggeredByMenu:SetTitle("Go to...")
    local triggeredByItem = actionMenu:AppendSubMenu(triggeredByMenu, "Triggered by")
    Gui.menus.triggeredByMenu = triggeredByMenu
    actionMenu:AppendSeparator()
    local actionDeleteItem = actionMenu:Append(wx.wxID_ANY, "Delete")
    Gui.menus.actionMenu = actionMenu

    local stepMenu = wx.wxMenu()
    -- triggerMenu:SetTitle("ololo")
    -- local stepAddItem = stepMenu:Append(wx.wxID_ANY, "Add...")
    local stepEditItem = stepMenu:Append(wx.wxID_ANY, "Edit...")
    stepMenu:AppendSeparator()
    local stepDeleteItem = stepMenu:Append(wx.wxID_ANY, "Delete")
    stepMenu:AppendSeparator()
    Gui.menus.stepMenu = stepMenu

    -- actions
    actionsListCtrl = dialogHelper.replaceElement(Gui, "actionsPlaceholder", function(parent)
        return wx.wxTreeListCtrl(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTL_DEFAULT_STYLE)
    end, "actionsList", "actions")
    
    -- actionListCtrl:AppendColumn("")
    actionsListCtrl:AppendColumn("Name")
    actionsListCtrl:AppendColumn("Enabled")
    actionsListCtrl:AppendColumn("Description")
    actionsListCtrl:AppendColumn("Queue")

    _M.imageList = iconsHelper.createImageList()   -- despite the docs, imagelist is not transferred to the tree control, so we use SetImageList and keep the ref
    actionsListCtrl:SetImageList(_M.imageList)

    local rootActionItem = actionsListCtrl:GetRootItem()
    
    -- predefined items
    _M.actionsData[rootActionItem:GetValue()] = {
        id = rootActionItem:GetValue(),
        isRoot = true,
        isGroup = true,
        data = {}
    }
    _M.addActionGroup("Default", rootActionItem)
    
    -- adding and editing actions
    actionsListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_CONTEXT_MENU, function(e) -- right click
        local i = e:GetItem():GetValue()
        local treeItem = _M.actionsData[i]
        -- logger.log(treeItem.name)

        Gui.menus.actionMenu:Enable(actionAddItem:GetId(), treeItem.canAddChildren == true)
        Gui.menus.actionMenu:Enable(actionEditItem:GetId(), treeItem.canEdit == true)
        Gui.menus.actionMenu:Enable(actionDeleteItem:GetId(), treeItem.canDelete == true)
        Gui.menus.actionMenu:Enable(actionToggleItem:GetId(), (not treeItem.isGroup))    -- disable toggling for whole groups for now
        Gui.menus.actionMenu:Enable(triggeredByItem:GetId(), (not treeItem.isGroup))
        Gui.menus.actionMenu:Check(actionToggleItem:GetId(), treeItem.data.enabled == true)

        local triggerItems = {}
        while Gui.menus.triggeredByMenu:GetMenuItemCount() > 0 do
            local it = Gui.menus.triggeredByMenu:FindItemByPosition(0);
            Gui.menus.triggeredByMenu:Destroy(it)
        end
        if not treeItem.isGroup then
            local triggeredBy = dataHelper.findTriggers(function(t) return t.data.action == treeItem.dbId end)
            for k, v in ipairs(triggeredBy) do
                local item = Gui.menus.triggeredByMenu:Append(wx.wxID_ANY, v.name)
                triggerItems[item:GetId()] = v.id
            end
        end

        local menuSelection = Gui.frame:GetPopupMenuSelectionFromUser(Gui.menus.actionMenu, wx.wxDefaultPosition)
        -- logger.log(menuSelection)
        if menuSelection == actionAddItem:GetId() then    -- add new item
            local result = treeItem.add(i, treeItem.childData)
            if not result then
                logger.err("'Add item' error")
            else
                local groupGuiItem, groupTreeItem = findOrCreateGroup(result.group, rootActionItem)
                _M.addAction(groupGuiItem, result)
            end
        elseif menuSelection == actionEditItem:GetId() then   -- edit item TODO move to a function
            local result = treeItem.edit(i, treeItem.data)
            if not result then
                logger.err("'Edit item' error")
            else
                logger.log("'Edit item' OK")
                updateActionItem(e:GetItem(), result)
            end
        elseif menuSelection == actionDeleteItem:GetId() then
            deleteItem(e:GetItem(), true)
        elseif menuSelection == actionToggleItem:GetId() then
            toggleItem(e:GetItem(), actionToggleItem:IsChecked())
        elseif triggerItems[menuSelection] then
            logger.log("goto trigger")
            local lblv = Gui.listbook:GetListView()
            local itemFound = Gui.triggers.triggersList:GetRootItem()
            while itemFound:GetValue() ~= triggerItems[menuSelection] do
                itemFound = Gui.triggers.triggersList:GetNextItem(itemFound)
            end
            lblv:Select(4)
            Gui.triggers.triggersList:Select(itemFound)
            -- wx.wxPostEvent(Gui.frame, wx.wxListbookEvent(wx.wxEVT_LISTBOOK_PAGE_CHANGED, 1))
        end
    end)

    actionsListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_ACTIVATED, function(e) -- double click on action
        local i = e:GetItem():GetValue()
        local treeItem = _M.actionsData[i]

        if treeItem.isGroup then
            if not actionsListCtrl:IsExpanded(e:GetItem()) then
                actionsListCtrl:Expand(e:GetItem())
            else
                actionsListCtrl:Collapse(e:GetItem())
            end
        else
            if treeItem.canEdit then  -- edit item TODO move to a function
                local result = treeItem.edit(i, treeItem.data)
                if not result then
                    logger.log("'Edit item' cancelled or error")
                else
                    updateActionItem(e:GetItem(), result)
                end
            end
        end
    end)

    actionsListCtrl:Connect(wx.wxEVT_TREELIST_SELECTION_CHANGED, function(e)
        logger.log("selection changed")
        stepsListCtrl:DeleteAllItems()

        local i = e:GetItem()
        if not i:IsOk() then
            logger.log("invalid item selected")
            return
        end
        local v = i:GetValue()
        currentAction = _M.actionsData[v]
        logger.log("selection item name", currentAction.name)
        local steps = currentAction.steps
        if steps and #steps > 0 then
            local stepRoot = stepsListCtrl:GetRootItem()
            for j, step in ipairs(steps) do
                local stepItem = stepsListCtrl:AppendItem(stepRoot, step.prototype.name, step.prototype.icon or iconsHelper.pages.actions, step.prototype.icon or iconsHelper.pages.actions)
                stepsListCtrl:SetItemText(stepItem, 1, step.description)
            end
        end
    end)

    -- steps
    stepsListCtrl = dialogHelper.replaceElement(Gui, "stepsPlaceholder", function(parent)
        return wx.wxTreeListCtrl(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTL_DEFAULT_STYLE)
    end, "stepsList", "steps")
    
    stepsListCtrl:AppendColumn("Type")
    stepsListCtrl:AppendColumn("Description")

    imageList = iconsHelper.createImageList()   -- despite the docs, imagelist is not transferred to the tree control, so we use SetImageList and keep the ref
    stepsListCtrl:SetImageList(imageList)

    local rootStepItem = stepsListCtrl:GetRootItem()

    stepsListCtrl:Connect(wx.wxEVT_TREELIST_SELECTION_CHANGED, function(e)
        logger.log("steps selection changed", stepsListCtrl:GetItemText(stepsListCtrl:GetSelection(), 1))
    end)

    twitchSteps.init(stepMenu, stepsHandlers)
    generalSteps.init(stepMenu, stepsHandlers)
    vtsSteps.init(stepMenu, stepsHandlers)
    obsSteps.init(stepMenu, stepsHandlers)

    stepsListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_CONTEXT_MENU, function(e) -- right click on a step
        if not actionsListCtrl:GetSelection():IsOk() then
            logger.log("no action selected")
            return
        end
        local actionData = _M.actionsData[actionsListCtrl:GetSelection():GetValue()]
        if actionData and actionData.isGroup then
            logger.log("no action selected")
            return
        end

        local stepIndex = 0
        local selected = stepsListCtrl:GetSelection()
        if selected:IsOk() then
            stepIndex = 1
            local item = stepsListCtrl:GetFirstItem()
            while item:IsOk() and item:GetValue() ~= selected:GetValue() do
                item = stepsListCtrl:GetNextItem(item)
                stepIndex = stepIndex + 1
            end
        end
        logger.log("step index", stepIndex)

        Gui.menus.stepMenu:Enable(stepEditItem:GetId(), stepIndex > 0)
        Gui.menus.stepMenu:Enable(stepDeleteItem:GetId(), stepIndex > 0)

        local menuSelection = Gui.frame:GetPopupMenuSelectionFromUser(Gui.menus.stepMenu, wx.wxDefaultPosition)

        if menuSelection == stepEditItem:GetId() then
            callEditStepDialog(actionData, stepIndex, selected)
            return
        end

        if menuSelection == stepDeleteItem:GetId() then
            local step = actionData.steps[stepIndex]
            table.remove(actionData.steps, stepIndex)
            stepsListCtrl:DeleteItem(selected)
            deleteStepFromDb(step)
            updateStepsOrder(actionData)
        end

        -- add something was selected
        local stepHandler = stepsHandlers[menuSelection]
        if not stepHandler then return end
        -- add step
        local m, result = stepHandler.dialogItem.executeModal("Add " .. stepHandler.name, stepHandler.data, stepHandler.init)
        if m == wx.wxID_OK then
            local item = stepsListCtrl:AppendItem(rootStepItem, stepHandler.name, stepHandler.icon or iconsHelper.pages.actions, stepHandler.icon or iconsHelper.pages.actions)
            stepsListCtrl:SetItemText(item, 1, stepHandler.getDescription(result))
            local params = result
            if stepHandler.postProcess then
                params = stepHandler.postProcess(result)
            end
            local stepData = {
                prototype = stepHandler,
                description = stepHandler.getDescription(result),
                params = params
            }
            addStep(nil, actionData, stepData)
        end
    end)

    stepsListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_ACTIVATED, function(e) -- double click on step
        if not actionsListCtrl:GetSelection():IsOk() then
            logger.log("no action selected")
            return
        end
        local actionData = _M.actionsData[actionsListCtrl:GetSelection():GetValue()]
        if actionData and actionData.isGroup then
            logger.log("no action selected")
            return
        end

        local stepIndex = 0
        local selected = stepsListCtrl:GetSelection()
        if selected:IsOk() then
            stepIndex = 1
            local item = stepsListCtrl:GetFirstItem()
            while item:IsOk() and item:GetValue() ~= selected:GetValue() do
                item = stepsListCtrl:GetNextItem(item)
                stepIndex = stepIndex + 1
            end
        end
        logger.log("step index", stepIndex)

        callEditStepDialog(actionData, stepIndex, selected)
    end)

    local upBtn = Gui.findWindow("stepMoveUp", "wxButton", "stepMoveUp", "actions", true)
    local downBtn = Gui.findWindow("stepMoveDown", "wxButton", "stepMoveDown", "actions", true)

    Gui.frame:Connect(upBtn:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        if not actionsListCtrl:GetSelection():IsOk() then
            logger.log("no action selected")
            return
        end
        local actionData = _M.actionsData[actionsListCtrl:GetSelection():GetValue()]
        if actionData and actionData.isGroup then
            logger.log("no action selected")
            return
        end

        local stepIndex = 0
        local selected = stepsListCtrl:GetSelection()
        if selected:IsOk() then
            stepIndex = 1
            local item = stepsListCtrl:GetFirstItem()
            while item:IsOk() and item:GetValue() ~= selected:GetValue() do
                item = stepsListCtrl:GetNextItem(item)
                stepIndex = stepIndex + 1
            end
        end
        logger.log("step index", stepIndex)
        if stepIndex <= 1 then
            return
        end

        local step = actionData.steps[stepIndex]
        table.remove(actionData.steps, stepIndex)
        table.insert(actionData.steps, stepIndex - 1, step)

        stepsListCtrl:DeleteAllItems()
        for i, v in ipairs(actionData.steps) do
            local item = stepsListCtrl:AppendItem(rootStepItem, v.prototype.name, v.prototype.icon or iconsHelper.pages.actions, v.prototype.icon or iconsHelper.pages.actions)
            stepsListCtrl:SetItemText(item, 1, v.description)
            if i == stepIndex - 1 then
                stepsListCtrl:Select(item)
            end
        end
        updateStepsOrder(actionData)
    end)

    Gui.frame:Connect(downBtn:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        if not actionsListCtrl:GetSelection():IsOk() then
            logger.log("no action selected")
            return
        end
        local actionData = _M.actionsData[actionsListCtrl:GetSelection():GetValue()]
        if actionData and actionData.isGroup then
            logger.log("no action selected")
            return
        end

        local stepIndex = 0
        local selected = stepsListCtrl:GetSelection()
        if selected:IsOk() then
            stepIndex = 1
            local item = stepsListCtrl:GetFirstItem()
            while item:IsOk() and item:GetValue() ~= selected:GetValue() do
                item = stepsListCtrl:GetNextItem(item)
                stepIndex = stepIndex + 1
            end
        end
        logger.log("step index", stepIndex)
        if stepIndex >= #actionData.steps then
            return
        end

        local step = actionData.steps[stepIndex]
        table.remove(actionData.steps, stepIndex)
        table.insert(actionData.steps, stepIndex + 1, step)

        stepsListCtrl:DeleteAllItems()
        for i, v in ipairs(actionData.steps) do
            local item = stepsListCtrl:AppendItem(rootStepItem, v.prototype.name, v.prototype.icon or iconsHelper.pages.actions, v.prototype.icon or iconsHelper.pages.actions)
            stepsListCtrl:SetItemText(item, 1, v.description)
            if i == stepIndex + 1 then
                stepsListCtrl:Select(item)
            end
        end
        updateStepsOrder(actionData)
    end)
end

function _M.load()
    local rootActionItem = actionsListCtrl:GetRootItem()
    local item = actionsListCtrl:GetFirstItem()
    while item:IsOk() do
        -- logger.log("item", item:GetValue())
        _M.actionsData[item:GetValue()] = nil
        item = actionsListCtrl:GetNextItem(item)
    end
    actionsListCtrl:DeleteAllItems()

    local size = 0
    for k, v in pairs(_M.actionsData) do
        size = size + 1
    end
    logger.log("actions treedata size", size)

    currentAction = {}
    stepsListCtrl:DeleteAllItems()

    local rows = {}

    findOrCreateGroup("Default", rootActionItem)

    for row in Db:nrows("SELECT * FROM actions ORDER BY json_extract(json(data), '$.group'), name;") do
        row.result = json.decode(row.data)
        table.insert(rows, row)
    end

    for i, row in pairs(rows) do
        row.result.dbId = row.id
        local group = row.result.group
        local groupItem = findOrCreateGroup(group, rootActionItem)
        local actionItem = _M.addAction(groupItem, row.result)
        -- if not actionsListCtrl:IsExpanded(groupItem) then
            -- actionsListCtrl:Expand(groupItem)
        -- end

        local stmt = Db:prepare("SELECT * FROM steps WHERE action=:action ORDER BY step_order;")
        stmt:bind_names({
            action = row.id
        })
        for row in stmt:nrows() do
            local prototype = findStepByName(row.name)
            if prototype then
                local data = json.decode(row.data)
                if prototype.postProcess then
                    data = prototype.postProcess(data)
                end
                local stepData = {
                    dbId = row.id,
                    prototype = prototype,
                    description = row.description,
                    params = data
                }
                addStep(row.id, actionItem, stepData)
            else
                logger.err("unknown step name", row.name)
            end
        end

        local res = stmt:finalize()
        if res ~= Sqlite.OK then
            logger.err("steps select error", res, Db:errmsg())
        end
    end

    dataHelper.setActions(_M.actionsData)
    -- TODO refresh triggers?
    logger.log("Actions load OK")
end

_M.groupNames = groupNames

return _M