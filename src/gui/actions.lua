local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local json = require("json")
local dataHelper = require("src/gui/data_helper")

local actionsListCtrl = nil
local stepsListCtrl = nil

local groupNames = {}

local _M = {
    actionsData = {},
    stepsData = {}
}

local function deleteItem(item, deleteFromDb)
    Log("Deleting " .. tostring(item:GetValue()))
    local treeItem = _M.actionsData[item:GetValue()]
    Log(treeItem.name)
    if treeItem.isGroup and actionsListCtrl:GetFirstChild(item):IsOk() then
        Log("Can't delete non-empty group item")
        return
    end
    local dbId = treeItem.dbId
    _M.actionsData[item:GetValue()] = nil

    -- update UI
    actionsListCtrl:DeleteItem(item)
    
    -- persist
    if deleteFromDb then
        local deleteStmt = Db:prepare("DELETE FROM actions WHERE id=:id;")
        deleteStmt:bind_names({
            id = dbId
        })
        local res = deleteStmt:step()
        if res ~= Sqlite.DONE then
            Log("Delete error", res, Db:errmsg())
        end
        deleteStmt:finalize()
    end
end

local function findItemById(ctrl, id)
    local item = ctrl:GetFirstItem()
    while item:IsOk() do
        if item:GetValue() == id then
            return item
        else
            local child = ctrl:GetFirstChild(item)
            while child:IsOk() do
                if child:GetValue() == id then
                    return child
                end
                child = ctrl:GetNextSibling(child)
            end
        end
    end
end

local function findGroup(name)
    for k, v in pairs(_M.actionsData) do
        if v.isGroup and v.name and v.name == name then
            Log(name, "found", k)
            return findItemById(actionsListCtrl, k), v
        end
    end
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
            Log(Db:errmsg())
        end
        insertStmt:bind_names({
            name = item.data.name,
            data = json.encode(item.data)
        })
        local res = insertStmt:step()
        if res ~= Sqlite.DONE then
            Log("Insert error", res, Db:errmsg())
        else
            local rowid = insertStmt:last_insert_rowid()
            Log("rowid", rowid)
            item.dbId = rowid
        end
        insertStmt:finalize()
    end

    -- update UI
    actionsListCtrl:SetItemText(guiItem, 0, data.name)
    actionsListCtrl:SetItemText(guiItem, 1, (data.enabled and "Yes" or "No"))
    actionsListCtrl:SetItemText(guiItem, 2, data.description or "")
    actionsListCtrl:SetItemText(guiItem, 3, data.queue or "")

    if not actionsListCtrl:IsExpanded(groupGuiItem) then
        actionsListCtrl:Expand(groupGuiItem)
    end
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
        Log("Update error", res, Db:errmsg())
    end
    updateStmt:finalize()
end

local function updateActionItem(item, result)
    local treeItem = _M.actionsData[item:GetValue()]
    treeItem.data = result
    treeItem.name = result.name

    -- update UI
    actionsListCtrl:SetItemText(item, 0, result.name)
    actionsListCtrl:SetItemText(item, 1, (result.enabled and "Yes" or "No"))
    actionsListCtrl:SetItemText(item, 2, result.description or "")
    actionsListCtrl:SetItemText(item, 3, result.queue or "")

    -- persist
    Log(treeItem.dbId, treeItem.data.name, "updating")
    updateActionItemInDb(treeItem)
end

function _M.addActionGroup(name, rootActionItem)
    local groupItem = actionsListCtrl:AppendItem(rootActionItem, name, iconsHelper.pages.folder, iconsHelper.pages.folder)
    local treeItem = {
        id = groupItem:GetValue(),
        name = name,
        isGroup = true,
        canEdit = true,
        canAddChildren = true,
        persistChildren = true,
        icon = iconsHelper.pages.actions, -- for children
        -- canDeleteChildren = true,
        add = function(id, data)
            local m, result = Gui.dialogs.ActionDialog.executeModal("Add action", data)
            if m == wx.wxID_OK then
                return result
            end
        end,
        childEdit = function(id, data)
            local m, result = Gui.dialogs.ActionDialog.executeModal("Edit action", data, nil, {id = id})
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

-- creates
--      gui.actions.actionsList
--      gui.actions.stepsList
--      gui.menus.actionMenu
--      gui.menus.stepMenu
--      gui.dialogs.ActionDialog
--      gui.ActionDialog.* fields
function _M.init()
    local actionDlg = dialogHelper.createDataDialog(Gui, "ActionDialog", "Action properties", {
            {
                name = "name",
                label = "Name",
                type = "text"
            },
            {
                name = "group",
                label = "Group",
                type = "combo"
            },
            {
                name = "description",
                label = "Description",
                type = "text"
            },
            {
                name = "queue",
                label = "Queue",
                type = "combo",
                choices = groupNames,
                value = "Default"
            },
            {
                name = "enabled",
                text = "Enabled",
                type = "check",
                value = true
            }
        },
        function(data, context)
            if not data.name or data.name == "" then
                return false, "Name can't be empty"
            else
                if context and context.id then
                    for i, v in pairs(_M.actionsData) do
                        if i ~= context.id and not v.isGroup and v.name == data.name then
                            return false, "Name mush be unique"
                        end
                    end
                else
                    for i, v in pairs(_M.actionsData) do
                        if not v.isGroup and v.name == data.name then
                            return false, "Name mush be unique"
                        end
                    end
                end
                return true
            end
        end)
    if not actionDlg then return end

    local actionGroupDlg = dialogHelper.createDataDialog(Gui, "ActionGroupDialog", "Group properties", {
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
    local actionDeleteItem = actionMenu:Append(wx.wxID_ANY, "Delete")
    Gui.menus.actionMenu = actionMenu

    local stepMenu = wx.wxMenu()
    -- triggerMenu:SetTitle("ololo")
    local stepAddItem = stepMenu:Append(wx.wxID_ANY, "Add...")
    local stepEditItem = stepMenu:Append(wx.wxID_ANY, "Edit...")
    local stepToggleItem = stepMenu:AppendCheckItem(wx.wxID_ANY, "Enabled")
    stepMenu:AppendSeparator()
    local stepDeleteItem = stepMenu:Append(wx.wxID_ANY, "Delete")
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
        Log(treeItem.name)

        Gui.menus.actionMenu:Enable(actionAddItem:GetId(), treeItem.canAddChildren == true)
        Gui.menus.actionMenu:Enable(actionEditItem:GetId(), treeItem.canEdit == true)
        Gui.menus.actionMenu:Enable(actionDeleteItem:GetId(), treeItem.canDelete == true)
        Gui.menus.actionMenu:Enable(actionToggleItem:GetId(), (not treeItem.isGroup))    -- disable toggling for whole groups for now
        Gui.menus.actionMenu:Check(actionToggleItem:GetId(), treeItem.data.enabled == true)

        local menuSelection = Gui.frame:GetPopupMenuSelectionFromUser(Gui.menus.actionMenu, wx.wxDefaultPosition)
        Log(menuSelection)
        if menuSelection == actionAddItem:GetId() then    -- add new item
            local result = treeItem.add(i, treeItem.childData)
            if not result then
                Log("'Add item' error")
            else
                _M.addAction(e:GetItem(), result)
            end
        elseif menuSelection == actionEditItem:GetId() then   -- edit item TODO move to a function
            local result = treeItem.edit(i, treeItem.data)
            if not result then
                Log("'Edit item' error")
            else
                Log("'Edit item' OK")
                updateActionItem(e:GetItem(), result)
            end
        elseif menuSelection == actionDeleteItem:GetId() then
            -- deleteItem(e:GetItem(), true)
        elseif menuSelection == actionToggleItem:GetId() then
            -- toggleItem(e:GetItem(), actionToggleItem:IsChecked())
        end
    end)

    actionsListCtrl:Connect(wx.wxEVT_TREELIST_ITEM_ACTIVATED, function(e) -- double click
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
                    Log("'Edit item' cancelled or error")
                else
                    updateActionItem(e:GetItem(), result)
                end
            end
        end
    end)


    -- steps
    stepsListCtrl = dialogHelper.replaceElement(Gui, "stepsPlaceholder", function(parent)
        return wx.wxTreeListCtrl(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTL_DEFAULT_STYLE)
    end, "stepsList", "steps")
    
    -- actionListCtr:AppendColumn("")
    stepsListCtrl:AppendColumn("Name")
    stepsListCtrl:AppendColumn("Order")
    stepsListCtrl:AppendColumn("Enabled")
    stepsListCtrl:AppendColumn("Description")

    imageList = iconsHelper.createImageList()   -- despite the docs, imagelist is not transferred to the tree control, so we use SetImageList and keep the ref
    stepsListCtrl:SetImageList(imageList)

    local rootStepItem = stepsListCtrl:GetRootItem()
    
    -- predefined items
    _M.stepsData[rootStepItem:GetValue()] = {
        id = rootStepItem:GetValue(),
        isGroup = true,
        name = "root",
        data = {
        }
    }
end

function _M.load()
    local rootActionItem = actionsListCtrl:GetRootItem()
    local item = actionsListCtrl:GetFirstItem()
    while item:IsOk() do
        -- Log("item", item:GetValue())
        local treeItem = _M.actionsData[item:GetValue()]
        if treeItem then
            -- Log(treeItem.name)
            local children = {}
            local child = actionsListCtrl:GetFirstChild(item)
            while child:IsOk() do
                table.insert(children, child)
                child = actionsListCtrl:GetNextSibling(child)
            end
            for i, v in ipairs(children) do
                deleteItem(v, false)
            end
            children = nil
            deleteItem(item, false)
        else
            Log("invalid treeitem")
        end
        item = actionsListCtrl:GetNextSibling(item)
    end

    for row in Db:nrows("SELECT * FROM actions") do
        local result = json.decode(row.data)
        result.dbId = row.id
        local group = result.group
        if not group or group == "" then
            group = "Default"
        end
        local groupItem, groupTreeItem = findGroup(group)
        Log("group find result for", group, groupItem, groupTreeItem)
        if not groupItem then
            groupItem, groupTreeItem = _M.addActionGroup(group, rootActionItem)
            Log("group create result for", group, groupItem, groupTreeItem)
        end
        _M.addAction(groupItem, result)
        -- if not actionsListCtrl:IsExpanded(groupItem) then
            -- actionsListCtrl:Expand(groupItem)
        -- end
    end

    dataHelper.setActions(_M.actionsData)
    -- TODO refresh triggers?
    Log("Triggers load OK")
end

_M.groupNames = groupNames

return _M