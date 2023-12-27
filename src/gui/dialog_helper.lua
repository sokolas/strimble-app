local logger = Logger.create("dialogs")
local iconsHelper = require("src/gui/icons")

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
        logger.err("Error! can't set value to " .. c)
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
        logger.err("Error! can't get value from " .. c)
    end
end

local function findInDlg(gui, dlg, name, type, guiName, group)
    local wnd = dlg:FindWindow(name)
    if not wnd then
        logger.err("can't find window", name);
        return nil
    end
    local ok, res = xpcall(
        wnd.DynamicCast,
        function(err) logger.err("error searching for window '" .. name .. "'/'" .. type .. "': ", debug.traceback(err)) end,
        wnd, type
    )
    if ok then
        gui:insert(res, guiName, group)
        -- print("found window", name, type, guiName, group)
    else
        logger.err("can't find/cast window", name)
    end
    
    gui.transient[group .. "." .. guiName] = true
    return res
end

local function addToDlg(gui, widget, guiName, group)
    gui:insert(widget, guiName, group)
    gui.transient[group .. "." .. guiName] = true
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
            -- logger.log(k, v, gui[name], gui[name][k])
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
        -- logger.log(k, c)
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

local function createDataDialog(gui, dlgName, controls, validate)
    local frame = gui.frame
    
    local dlg = wx.wxDialog(frame, wx.wxID_ANY, "sample dialog", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER, "wxDialog")
    local topLevelSizer = wx.wxBoxSizer(wx.wxVERTICAL);
    local bgPanel = wx.wxPanel(dlg, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize)

    local sizers = {}
    for groupName, controlGroup in pairs(controls) do
        local controlsBox = wx.wxStaticBox(bgPanel, wx.wxID_ANY, groupName)
        local listBoxStaticBoxSizer = wx.wxStaticBoxSizer(controlsBox, wx.wxVERTICAL);
        listBoxStaticBoxSizer:SetMinSize(wx.wxSize(400, -1))
        -- local fgSizer = wx.wxFlexGridSizer(#controls, 2)
        local fgSizer = wx.wxFlexGridSizer(0, 2)
        fgSizer:AddGrowableCol(1, 1)
        fgSizer:SetFlexibleDirection(wx.wxHORIZONTAL)   -- by default, grow only horizontally
        fgSizer:SetNonFlexibleGrowMode(wx.wxFLEX_GROWMODE_ALL)

        for i, v in ipairs(controlGroup) do
            local grow = nil
            local label = wx.wxStaticText(controlsBox, wx.wxID_ANY, v.label or "")
            local widget = nil
            if v.type == "text" then
                widget = wx.wxTextCtrl(controlsBox, wx.wxID_ANY, v.value or "", wx.wxDefaultPosition, wx.wxDefaultSize)
            elseif v.type == "multiline" then
                widget = wx.wxTextCtrl(controlsBox, wx.wxID_ANY, v.value or "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE + wx.wxTE_BESTWRAP)
                grow = true
                fgSizer:SetFlexibleDirection(wx.wxBOTH) -- grow the sizer inside static panel in both directions
            elseif v.type == "check" then
                widget = wx.wxCheckBox(controlsBox, wx.wxID_ANY, v.text or "check", wx.wxDefaultPosition,
                    wx.wxDefaultSize)
                widget:SetValue(v.value or false)
            elseif v.type == "choice" then
                widget = wx.wxChoice(controlsBox, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, v.choices)
            elseif v.type == "combo" then
                widget = wx.wxComboBox(controlsBox, wx.wxID_ANY, v.value or "", wx.wxDefaultPosition, wx.wxDefaultSize,
                    v.choices or {})
            elseif v.type == "file" then
                -- fields: value - button name and file dialog title; wildcard - file masks; ref - widget to set the filename to
                widget = wx.wxButton(controlsBox, wx.wxID_ANY, v.value or "Open file")
                dlg:Connect(widget:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
                    local fileDialog = wx.wxFileDialog(wx.NULL,
                        v.value or "Open file",
                        "",
                        "",
                        v.wildcard or "All files (*)|*",
                        wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST)

                    if fileDialog:ShowModal() == wx.wxID_OK then
                        local filename = fileDialog:GetPath()
                        setControlValue(gui[dlgName][v.ref], filename)
                    end
                end)
            else
                logger.err("Unknown widget type: " .. tostring(v.type))
                dlg:Destroy()
                return nil
            end
            if widget then
                if v.init then
                    v.init(widget)
                end
                widget:SetName(dlgName .. "__" .. v.name)
                addToDlg(gui, widget, v.name, dlgName)
                if grow then
                    fgSizer:AddGrowableRow(i-1, 1)  -- grow multiline vertically
                end
                fgSizer:Add(label, (i - 1) * 2, wx.wxALL, 5)
                fgSizer:Add(widget, (i - 1) * 2 + 1, wx.wxALL + wx.wxEXPAND, 5)
            end
        end

        listBoxStaticBoxSizer:Add(fgSizer, 1, wx.wxEXPAND, 5)
        table.insert(sizers, listBoxStaticBoxSizer)
    end

    local outerSizer = wx.wxFlexGridSizer(1, #sizers, 0, 5)
    outerSizer:SetFlexibleDirection(wx.wxBOTH)
    outerSizer:SetNonFlexibleGrowMode(wx.wxFLEX_GROWMODE_ALL)
    outerSizer:AddGrowableRow(0, 1) -- set the static boxes row growable
    for i = 1, #sizers do
        outerSizer:AddGrowableCol(i - 1, 1)
        outerSizer:Add(sizers[i], 1, wx.wxEXPAND, 0)
    end
    

    bgPanel:SetSizer(outerSizer)
    bgPanel:Layout()
    outerSizer:Fit(bgPanel)

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
        logger.err("can't find window", name);
        return nil
    end
    local parent = wnd:GetParent()
    if not parent then
        logger.err("Can't get parent of", name)
        return nil
    end
    local sizer = parent:GetSizer()
    if not sizer then
        logger.err("Can't get sizer of parent", parent:GetName())
    end
    local e = constructor(parent)

    local replaced = sizer:Replace(wnd, e, true)
    if not replaced then
        logger.err("Can't replace the item", name)
        e:Destroy()
    end
    wnd:Destroy()
    sizer:Show(e, true, true)
    gui:insert(e, guiName, group)
    return e
end

local _M = {}

_M.loadMainWindow = function()
    local xmlResource = nil
    xmlResource = wx.wxXmlResource()
    xmlResource:InitAllHandlers()
    local x = ReadFromCfg("window", "x", -1)
    local y = ReadFromCfg("window", "y", -1)
    local w = ReadFromCfg("window", "w", -1)
    local h = ReadFromCfg("window", "h", -1)
    local pos = wx.wxPoint(x, y)
    local size = wx.wxSize(w, h)

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

    -- frame:SetSizer(wx.NULL)
    frame:SetPosition(pos)
    frame:SetSize(size)

    return xmlResource, frame
end

_M.loadPanel = function(src, name, pageName)
    local xmlResource = nil
    xmlResource = wx.wxXmlResource()
    xmlResource:InitAllHandlers()

    xmlResource:Load(src)
    local panel = xmlResource:LoadPanel(Gui.listbook, name)
    if not panel then
        wx.wxMessageBox("Error loading xrc resources!",
                        "Strimble Error",
                        wx.wxOK + wx.wxICON_EXCLAMATION,
                        wx.NULL)
        return -- quit program
    else
        Gui.listbook:InsertPage(iconsHelper.int_pos - 1, panel, pageName)
    end

    return xmlResource, panel
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