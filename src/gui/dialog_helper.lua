-- if control is text or checkbox: set the value directly
-- if control is choice: set the selected as the value number
-- if control is combobox: set the value directly
local function setControlValue(control, value)
    if control:GetId() == wx.wxID_OK or control:GetId() == wx.wxID_CANCEL then
        return
    end 
    local c = control:GetClassInfo():GetClassName()
    if c == "wxTextCtrl" or c == "wxCheckBox" then
        control:SetValue(value)
    elseif c == "wxComboBox" then
        control:SetValue(value)
    elseif c == "wxChoice" then
        control:SetSelection(value)
    else
        Log("Error! can't set value to " .. c)
    end
end

local function getControlValue(control)
    if control:GetId() == wx.wxID_OK or control:GetId() == wx.wxID_CANCEL then
        return
    end
    local c = control:GetClassInfo():GetClassName()
    if c == "wxTextCtrl" or c == "wxCheckBox" or c == "wxComboBox" then
        return control:GetValue()
    elseif c == "wxChoice" then
        return control:GetSelection()
    else
        Log("Error! can't get value from " .. c)
    end
end

local function findInDlg(gui, dlg, name, type, guiName, group)
    local wnd = dlg:FindWindow(name)
    if not wnd then
        Log("can't find window", name);
        return nil
    end
    local ok, res = xpcall(
        wnd.DynamicCast,
        function(err) Log("error searching for window '" .. name .. "'/'" .. type .. "': ", debug.traceback(err)) end,
        wnd, type
    )
    if ok then
        gui:insert(res, guiName, group)
        -- print("found window", name, type, guiName, group)
    else
        Log("can't find/cast window", name)
    end
    
    gui.transient[name] = true
    return res
end

local function addToDlg(gui, widget, guiName, group)
    gui:insert(widget, guiName, group)
    gui.transient[widget:GetName()] = true
    return widget
end

local function createDlgItem(gui, dlg, validate, dlgName)
    local res = {
        dlg = dlg,
        validate = validate,
        returnData = {}
    }
    res.executeModal = function(title, data, init, context)
        res.returnData = {}
        res.context = context
        if title then dlg:SetTitle(title) end
        if init then
            for k, v in pairs(init) do
                if gui[dlgName][k] then
                    v(gui[dlgName][k])
                end
            end
        end
        for k, v in pairs(data) do
            -- Log(k, v, gui[name], gui[name][k])
            if gui[dlgName][k] and v ~= nil then
                setControlValue(gui[dlgName][k], v)
            end
        end
        -- collectgarbage("collect")
        local m = dlg:ShowModal()
        return m, res.returnData
    end
    return res
end

local function connectOkBtn(gui, dlg, validate, dlgName)
    dlg:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function(e)
        local data = {}
        for k, v in pairs(gui[dlgName]) do
            data[k] = getControlValue(v)
        end
        if validate then
            local ok, error = validate(data, gui.dialogs[dlgName].context)
            if ok then
                gui.dialogs[dlgName].returnData = data
                e:Skip()
            else
                wx.wxMessageBox("Error in data:\n" .. (error or ""), "Strimble Error", wx.wxOK + wx.wxICON_EXCLAMATION,
                    wx.NULL)
                return
            end
        else
            gui.dialogs[dlgName].returnData = data
            e:Skip()
        end
        -- validate before saving
        e:Skip()
    end)
end

local function loadDialog(gui, dlgName, controls, validate)
    local frame = gui.frame
    local xmlResource = gui.xmlResource

    local dlg = wx.wxDialog(frame, wx.wxID_ANY, "sample dialog", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDEFAULT_DIALOG_STYLE, "wxDialog")
    if not xmlResource:LoadDialog(dlg, wx.NULL, dlgName) then
        wx.wxMessageBox("Error loading xrc resources!",
            "Strimble Error",
            wx.wxOK + wx.wxICON_EXCLAMATION,
            wx.NULL)
        return false -- quit program
    end

    gui.dialogs[dlgName] = createDlgItem(gui, dlg, validate, dlgName)
    
    for k, v in pairs(controls) do
        local c = findInDlg(gui, dlg, v.name, v.type, k, dlgName)
        -- Log(k, c)
        if v.init then
            v.init(c)
        end
    end
    local okBtn = findInDlg(gui, dlg, wx.wxID_OK, "wxButton", "okBtn", dlgName)
    if okBtn then
        okBtn:SetDefault()
    end

    connectOkBtn(gui, dlg, validate, dlgName)
    return dlg
end

local function createDataDialog(gui, dlgName, controlsName, controls, validate)
    local frame = gui.frame
    
    local dlg = wx.wxDialog(frame, wx.wxID_ANY, "sample dialog", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDEFAULT_DIALOG_STYLE, "wxDialog")
    local topLevelSizer = wx.wxBoxSizer(wx.wxVERTICAL);
    local bgPanel = wx.wxPanel(dlg, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize)

    local controlsBox = wx.wxStaticBox(bgPanel, wx.wxID_ANY, controlsName)
    local listBoxStaticBoxSizer = wx.wxStaticBoxSizer(controlsBox, wx.wxVERTICAL);
    listBoxStaticBoxSizer:SetMinSize( wx.wxSize( 300,-1 ) )
    -- local fgSizer = wx.wxFlexGridSizer(#controls, 2)
    local fgSizer = wx.wxFlexGridSizer(0, 2)
    fgSizer:AddGrowableCol(0)
    fgSizer:AddGrowableCol(1, 1)
    fgSizer:SetFlexibleDirection( wx.wxHORIZONTAL )
	fgSizer:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_ALL )

    for i, v in ipairs(controls) do
        local label = wx.wxStaticText(controlsBox, wx.wxID_ANY, v.label or "")
        local widget = nil
        if v.type == "text" then
            widget = wx.wxTextCtrl(controlsBox, wx.wxID_ANY, v.value or "", wx.wxDefaultPosition, wx.wxDefaultSize)
        elseif v.type == "check" then
            widget = wx.wxCheckBox(controlsBox, wx.wxID_ANY, v.text or "check", wx.wxDefaultPosition, wx.wxDefaultSize, v.value or false)
        elseif v.type == "choice" then
            widget = wx.wxChoice(controlsBox, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, v.choices)
        elseif v.type == "combo" then
            widget = wx.wxComboBox(controlsBox, wx.wxID_ANY, v.value or "", wx.wxDefaultPosition, wx.wxDefaultSize, v.choices or {})
        else
            Log("Unknown widget type: " .. tostring(v.type))
            dlg:Destroy()
            return nil
        end
        if widget then
            if v.init then
                v.init(widget)
            end
            widget:SetName(dlgName .. "__" .. v.name)
            addToDlg(gui, widget, v.name, dlgName)
            fgSizer:Add(label, (i - 1) * 2, wx.wxALL, 5)
            fgSizer:Add(widget, (i - 1) * 2 + 1, wx.wxALL + wx.wxEXPAND, 5)
        end
    end


    listBoxStaticBoxSizer:Add(fgSizer, 1, wx.wxEXPAND, 5)

    bgPanel:SetSizer(listBoxStaticBoxSizer)
    bgPanel:Layout()
    listBoxStaticBoxSizer:Fit(bgPanel)

    topLevelSizer:Add(bgPanel, 1, wx.wxALL + wx.wxEXPAND, 5)

    local btnSizer = wx.wxStdDialogButtonSizer()
    local okBtn = wx.wxButton(dlg, wx.wxID_OK, "")
    okBtn:SetDefault()
    local cancelBtn = wx.wxButton(dlg, wx.wxID_CANCEL, "")
    -- btnSizer:SetMinSize( wx.wxSize( 300,-1 ) )
    btnSizer:SetAffirmativeButton(okBtn)
    btnSizer:SetCancelButton(cancelBtn)
    btnSizer:Realize()
    topLevelSizer:Add(btnSizer, 0, wx.wxALL + wx.wxEXPAND, 5)

    dlg:SetSizer(topLevelSizer)
    topLevelSizer:SetSizeHints(dlg)
    dlg:Layout()
    dlg:Centre()

    gui.dialogs[dlgName] = createDlgItem(gui, dlg, validate, dlgName)
    connectOkBtn(gui, dlg, validate, dlgName)
    
    return dlg
end

local function replaceElement(gui, name, constructor, guiName, group)
    local wnd = gui.frame:FindWindow(name)
    if not wnd then
        Log("can't find window", name);
        return nil
    end
    local parent = wnd:GetParent()
    if not parent then
        Log("Can't get parent of", name)
        return nil
    end
    local sizer = parent:GetSizer()
    if not sizer then
        Log("Can't get sizer of parent", parent:GetName())
    end
    local e = constructor(parent)

    local replaced = sizer:Replace(wnd, e, true)
    if not replaced then
        Log("Can't replace the item", name)
        e:Destroy()
    end
    wnd:Destroy()
    sizer:Show(e, true, true)
    gui:insert(e, guiName, group)
    return e
end

_M = {}

_M.loadMainWindow = function()
    local xmlResource = nil
    xmlResource = wx.wxXmlResource()
    xmlResource:InitAllHandlers()

    xmlResource:Load("src/StrimbleUI.xrc")
    local frame = wx.wxFrame()
    if not xmlResource:LoadFrame(frame, wx.NULL, "MainWindow") then
        wx.wxMessageBox("Error loading xrc resources!",
                        "Strimble Error",
                        wx.wxOK + wx.wxICON_EXCLAMATION,
                        wx.NULL)
        return -- quit program
    end
    local img = wx.wxBitmap("images/icons/bug.png", wx.wxBITMAP_TYPE_PNG)
    local icon = wx.wxIcon()
    icon:CopyFromBitmap(img)
    frame:SetIcon(icon)
    img:delete()
    icon:delete()

    frame:SetSizer(wx.NULL)
    return xmlResource, frame
end

_M.loadDialog = loadDialog
_M.createDataDialog = createDataDialog
_M.replaceElement = replaceElement
_M.getControlValue = getControlValue
_M.setControlValue = setControlValue

_M.showOkCancel = function(parent, message, caption)
    local dlg = wx.wxMessageDialog(parent, message, caption, wx.wxOK + wx.wxCANCEL + wx.wxICON_EXCLAMATION)
    local m = dlg:ShowModal()
    dlg:Destroy()
    return m
end

return _M