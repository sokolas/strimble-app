is_wx_app = true -- for testing purposes

local iconsHelper = require("src/gui/icons")
local wxTimers = require("src/stuff/wxtimers")
local dialogHelper = require("src/gui/dialog_helper")
local triggersHelper = require("src/gui/triggers")
local actionsHelper = require("src/gui/actions")
local Ctx = require("src/stuff/action_context")
local audio = require("src/stuff/audio")

local ThingsToKeep = {} -- variable to store references to various stuff that needs to be kept
local accelTable = {}
local accelMenu = {}
local logger = Logger.create("main")

local integrations = {
    {src = "src/integrations/vts"},
    {src = "src/integrations/obs"}
}

local function loadIntegration(int)
    local moduleDescriptor, err = io.open(int.src .. "/module.json", "r")
    if not moduleDescriptor then
        return false, err
    end
    local descriptorString = moduleDescriptor:read("*a")
    moduleDescriptor:close()
    local ok, result = pcall(Json.decode, descriptorString)
    if not ok then
        return ok, result
    end
    if not result.init then
        return false, "\"init\" required"
    end
    --[[local module = {}
    module.name = result.name
    module.author = result.author
    module.description = result.description]]
    int.name = result.name
    int.author = result.author
    int.description = result.description
    local m = require(int.src .. "/" .. result.init)
    -- module.m = m
    int.m = m
    logger.log("loaded module from", int.src, int)
    -- TODO validate init functions
    return int
end

ACTION_DISPATCH = wx.wxID_HIGHEST + 1   -- the wx id for "dispatch actions" message command
TIMER_ADD       = wx.wxID_HIGHEST + 2   -- the wx id for "add timer" message command

Gui = {
    tools = {},
    transient = {},
    dialogs = {},
    menus = {},
    insert = function(gui, e, name, group)
        if name then
            if group then
                if not gui[group] then
                    gui[group] = {}
                end
                gui[group][name] = e
            else
                gui[name] = e
            end
        end
    end
}

local twitchWnd = require("src/gui/twitch_gui") -- don't forget to init

local function updateTwitchInfo(ok, data, token)
    if token then
        Gui.twitch.token:SetValue(token)
        Twitch.setToken(token)
    end
    
    if not ok then
        if data.status or data.message then
            twitchWnd.appendTwitchMessage("*** Auth unsuccessful; status: " .. tostring(data.status) .. "(" .. tostring(data.message) .. "). Please authenticate again")
        else
            twitchWnd.appendTwitchMessage("*** Auth unsuccessful - unknown error. Please authenticate again")
        end
    elseif data.login and data.login ~= "" then
        Gui.twitch.username:SetValue(data.login)
        Twitch.username = data.login
        local chan = Gui.twitch.channel:GetValue()
        if not chan or chan == "" then
            Gui.twitch.channel:SetValue(data.login)
            Twitch.channel = data.login
        else
            Twitch.channel = chan
        end
    else
        twitchWnd.appendTwitchMessage("*** Auth unsuccessful - unknown error. Please authenticate again")
    end
end

local function createAuthSock()
    
    local tw = assert(io.open("src/http_resp/tw.html", "r"))
    local twitch_auth_resp_body = tw:read("*a")
    tw:close()

    local favicon = assert(io.open("images/svg/bug.svg", "r"))
    local favicon_resp_body = favicon:read("*a")
    favicon:close()

    local responses = {
        GET = {
            ["/tw_user"] = {
                status = "200",
                headers = {
                    ['content-type'] = "text/html"
                },
                body = twitch_auth_resp_body,
                handler = function(res)
                    local query = (res.query or {})[1]
                    logger.log("twitch auth request", res.path, query)
                    local p = Twitch.parseAuth(res.path .. "?" .. query)
                    if p then
                        for i, v in pairs(p) do
                            logger.log(i, v)
                        end
                        if p.access_token then
                            local auth = coroutine.wrap(function()
                                twitchWnd.appendTwitchMessage("twitch auth success")
                                Gui.twitch.token:SetValue(p.access_token)
                                Twitch.setToken(p.access_token)
            
                                local ok, data = Twitch.validateToken()
                                updateTwitchInfo(ok, data)
                            end)
                            auth()
                        else
                            twitchWnd.appendTwitchMessage("twitch auth error: " .. tostring(p.error or '').. " - " .. tostring(p.error_description or ''))
                        end
                    end
                end
            },
            ["/favicon.ico"] = {
                status = "200",
                headers = {
                    ['content-type'] = "image/svg+xml"
                  },
                body = favicon_resp_body
            }
        }
    }

    NetworkManager.creareServer("0.0.0.0:10115", responses, true)
end

local function findWindow(name, type, guiName, group, transient)
    local wnd = Gui.frame:FindWindow(name)
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
        Gui:insert(res, guiName, group)
        -- print("found window", name, type, guiName, group)
    else
        logger.err("can't find/cast window", name)
    end
    if transient then
        Gui.transient[group .. "." .. guiName] = true
    end
    return res
end

Gui.findWindow = findWindow

local function insertInto(name, type, constructor, guiName, group)
    local wnd = Gui.frame:FindWindow(name)
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
        local e = constructor(wnd)
        if e then
            local sizer = wnd:GetSizer() or wx.wxBoxSizer(wx.wxHORIZONTAL); -- TODO parameterize
            sizer:Add(e, 1, wx.wxEXPAND + wx.wxALL, 0);
            wnd:SetSizer(sizer);
            -- wnd:GetSizer():SetSizeHints(wnd);
            Gui:insert(e, guiName, group)
            -- print("found window", name, type, guiName, group)
            return e
        else
            logger.err("error creating element", guiName)
        end
    else
        logger.err("can't find/cast window", name)
    end
end    

local function findTool(name, guiName)
    local rcid = Gui.xmlResource.GetXRCID(name)
    if not rcid then logger.err("can't find rc id", name); return nil end
    local wnd = Gui.frame:GetToolBar():FindById(rcid)
    if not wnd then logger.err("can't find tool", rcid); return nil end
    local ok, res = xpcall(
        wnd.DynamicCast,
        function(err) logger.err("error searching for tool '" .. name .. "': ", debug.traceback(err)) end,
        wnd, "wxToolBarToolBase"
    )
    if ok then
        Gui.tools[guiName] = res
        -- print("found window", name, type, guiName, group)
    else
        logger.err("can't find/cast window", name)
    end
    return res
end

function EvtHandler(f)
    return function(event)
        local co = coroutine.wrap(f)
        -- table.insert(coros, co)
        local ok, res = co(event)
        -- if not ok then
            -- print("handler error", res)
        -- end
    end
end

local evtHandler = EvtHandler   -- TODO rename

local function isIncludedInConfig(group)
    return group ~= "menus" and group ~= "dialogs"and group ~= "tools" and group ~= "transient"
end

local function saveConfig()
    -- db
    SaveDb()

    -- gui part
    for group, g in pairs(Gui) do
        if isIncludedInConfig(group) and type(g) == "table" then
            local d = {}
            for name, value in pairs(g) do
                -- logger.log(group, name, value:GetClassInfo():GetClassName())
                if not Gui.transient[group .. "." .. name] then -- value:GetName()
                    local class = value:GetClassInfo():GetClassName()
                    if class == "wxTextCtrl" or class == "wxCheckBox" then
                        d[name] = value:GetValue()
                    end
                end
                SaveToCfg(group, d)
            end
        end
    end

    -- save logging settings
    local logging = {}
    for k, v in pairs(Logger.loggers) do
        logging[k] = v.enabled
    end
    SaveToCfg("logging", logging)

    -- non-gui part
    SaveToCfg("twitch", {
        userId = Twitch.userId,
    })
    
    for i, v in ipairs(integrations) do
        if v.m.saveConfig then
            v.m.saveConfig()
        end
    end
    
    
    Gui.statusbar:SetStatusText("Config saved", 0)
end

local function loadConfig()
    -- load and fill gui values
    for group, g in pairs(Gui) do
        if isIncludedInConfig(group) and type(g) == "table" then
            for name, value in pairs(g) do
                if not Gui.transient[group .. "." .. name] then --value:GetName()
                    -- logger.log(group, name, value:GetClassInfo():GetClassName())
                    local class = value:GetClassInfo():GetClassName()
                    if class == "wxTextCtrl" then
                        local v = ReadFromCfg(group, name, "")
                        value:SetValue(v)
                    elseif class == "wxCheckBox" then
                        local v = ReadFromCfg(group, name, false)
                        value:SetValue(v)
                    end
                end
            end
        end
    end

    -- load logging settings
    for k, v in pairs(Logger.loggers) do
        local p = Gui.logging.grid:GetPropertyByName(k)
        local enabled = ReadFromCfg("logging", k, false)
        p:SetValueFromString(tostring(enabled == 1))
    end

    -- set up twitch
    Twitch.userId = ReadFromCfg("twitch", "userId", "")
    Twitch.token = Gui.twitch.token:GetValue()
    Twitch.username = Gui.twitch.username:GetValue()
    Twitch.channel = Gui.twitch.channel:GetValue()

    -- set up vts
    for i, v in ipairs(integrations) do
        if v.m.loadConfig then
            v.m.loadConfig()
        end
    end

    LoadDb()
    
    actionsHelper.load()
    triggersHelper.load()
    Gui.statusbar:SetStatusText("Config loaded", 0)
end

local function setLoggingLevels()
    for k, v in pairs(Logger.loggers) do
        local p = Gui.logging.grid:GetPropertyByName(k)
        v.enabled = p:GetValue():GetBool()
    end
end


local function restart(id)
    if jit.os == 'Windows' then
        local pid = wx.wxExecute(mainarg[1], wx.wxEXEC_ASYNC)
        if pid then
            wx.wxPostEvent(Gui.frame, wx.wxCloseEvent(wx.wxEVT_CLOSE_WINDOW, id))
        end
    else
        Gui.statusbar:SetStatusText("Can't restart when running on " .. jit.os)
    end
end

function main()
    logger.log(DataDir)
    -- HideConsole()
    -- NetworkManager.addSocket(createAuthSock()) -- no handler
    createAuthSock()

    local xmlResource, frame = dialogHelper.loadMainWindow()
    if not xmlResource or not frame then return end
    Gui.frame = frame
    Gui.xmlResource = xmlResource

    local toolbar = Gui.frame:GetToolBar()
    toolbar:InsertStretchableSpace(4)
    toolbar:Realize()

    -- setup the toolbar
    findTool("toolConsole", "console")
    findTool("toolSave", "save")
    findTool("toolLoad", "load")
    findTool("toolRestart", "restart")
    findTool("toolHelp", "help")
    -- gui.frame:GetToolBar():InsertStretchableSpace(2)

    -- setup status bar
    Gui.statusbar = frame:GetStatusBar()

    frame:Connect(wx.wxEVT_TOOL, function(event)
        local id = event:GetId()
        if id == Gui.tools.console:GetId() then
            -- showConsole = event:GetInt() == 1
            showConsole = not showConsole
            if showConsole then
                ShowConsole()
            else
                HideConsole()
            end
        elseif id == Gui.tools.save:GetId() then
            saveConfig()
        elseif id == Gui.tools.load:GetId() then
            local m = dialogHelper.showOkCancel(Gui.frame, "Discard unsaved changes?", "Strimble")
            if m == wx.wxID_OK then
                loadConfig()
            end
        elseif id == Gui.tools.restart:GetId() then
            restart(id)
        elseif id == Gui.tools.help:GetId() then
            wx.wxLaunchDefaultBrowser("https://github.com/sokolas/strimble-app/wiki")
        end
    end)

    accelMenu = wx.wxMenu()
    local consoleMenuItem = accelMenu:Append(wx.wxID_ANY, "Console")
    local saveMenuItem = accelMenu:Append(wx.wxID_ANY, "Save config")
    local restartMenuItem = accelMenu:Append(wx.wxID_ANY, "Restart")

    accelTable = wx.wxAcceleratorTable({
        { wx.wxACCEL_NORMAL, wx.WXK_F12, consoleMenuItem:GetId() },
        { wx.wxACCEL_CTRL, string.byte('s'), saveMenuItem:GetId() },
        { wx.wxACCEL_CTRL, string.byte('r'), restartMenuItem:GetId() }
    })
    frame:SetAcceleratorTable(accelTable)

    frame:Connect(consoleMenuItem:GetId(), wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
        showConsole = not showConsole
        if showConsole then
            ShowConsole()
        else
            HideConsole()
        end
    end)

    frame:Connect(saveMenuItem:GetId(), wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
        saveConfig()
    end)

    frame:Connect(restartMenuItem:GetId(), wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
        restart(event:GetId())
    end)

    -- set up "custom listbook" - splitter, list sontrol and simplebook
    findWindow("listbookSplitter", "wxSplitterWindow", "splitter", "listbook")
    -- findWindow("pagesListCtrl", "wxListCtrl", "list", "listbook")
    actionsListCtrl = dialogHelper.replaceElement(Gui, "pagesListCtrlPlaceholder", function(parent)
        return wx.wxListView(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxLC_REPORT + wx.wxLC_NO_HEADER + wx.wxLC_SINGLE_SEL)
    end, "list", "listbook")
    findWindow("pagesSimpleBook", "wxSimplebook", "book", "listbook")
    
    local lblc = Gui.listbook.list

    -- for integration in integrations: require()
    for i, v in ipairs(integrations) do
        --v.m = require(v.src)
        local ok, res = loadIntegration(v)
        if ok then
            iconsHelper.registerPage(v.m.page, v.m.icon, v.m.displayName)
            if v.m.initializeUi then
                local r = v.m.initializeUi()
                if not r then
                    logger.err("Error initializing UI for", v.name, v.m.displayName, v.m.src)
                    return  -- quit the program
                end
            end
        else
            logger.err("error loading integration", res)
        end
    end

    local lbW = iconsHelper.initializeListbook(lblc)
    Gui.listbook.splitter:SetSashPosition(lbW + 15)
    Gui.listbook.splitter:SetMinimumPaneSize(lbW + 15)
    logger.log("listbook initialized")


    -- set up "main loop" (network and audio dispatchers)
    local function event_loop(event)
        -- network
        xpcall(
            function(event)
                NetworkManager.dispatch()
            end,
            function(err)
                -- timer:Stop()
                logger.log("network dispatch loop error", debug.traceback(err))
            end,
            event
        )
        -- audio
        xpcall(
            function(event)
                audio.dispatch()
            end,
            function(err)
                -- timer:Stop()
                logger.log("audio dispatch loop error", debug.traceback(err))
            end,
            event
        )
    end
    wxTimers.addTimer(50, event_loop, true)

    -- "async" handlers that must be run in the main thread
    frame:Connect(ACTION_DISPATCH, wx.wxEVT_COMMAND_BUTTON_CLICKED, Ctx.dispatchActions)
    frame:Connect(TIMER_ADD, wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        for id, v in pairs(wxTimers.handlers) do
            logger.log("connecting timer", id)
            frame:Connect(id, wx.wxEVT_TIMER, v)
            wxTimers.handlers[id] = nil
            logger.log("timer connected", id)
        end
    end)

    -- twitch
    findWindow("twitchLog", "wxTextCtrl", "log", "twitch", true)
    findWindow("twitchToken", "wxTextCtrl", "token", "twitch")
    findWindow("twitchUsername", "wxTextCtrl", "username", "twitch")
    findWindow("twitchChannel", "wxTextCtrl", "channel", "twitch")
    findWindow("twitchAuthBtn", "wxButton", "authBtn", "twitch")
    findWindow("twitchConnectBtn", "wxButton", "connectBtn", "twitch")
    findWindow("twitchShowChatLogs", "wxCheckBox", "showChat", "twitch")
    findWindow("twitchAutoconnect", "wxCheckBox", "autoconnect", "twitch")
    findWindow("twitchAutoscroll", "wxCheckBox", "autoscroll", "twitch")
    findWindow("twitchEsStatus", "wxStaticText", "esStatus", "twitch", true)
    findWindow("twitchStatusPanel", "wxPanel", "statusPanel", "twitch")
    twitchWnd.init(Gui.twitch.log)
    
    frame:Connect(Gui.twitch.authBtn:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local url = Twitch.getAuthUrl();
        --[[createAuthFrame()
        if authFrame and webview then
            authFrame:Show(true)
            webview:LoadURL(url)
        end]]
        wx.wxLaunchDefaultBrowser(url);
    end)
    
    local function twitchChatMessageListener(message)
        if Gui.twitch.showChat:GetValue() then
            twitchWnd.appendTwitchMessage(string.format("%s/%s: %s", message.channel, message.user, message.text))
        end
    end
    
    local function twitchStateListener(esState, esIcon, additional)
        Gui.twitch.esStatus:SetLabel("Status: " .. (esState or "unknown") .. (additional or ""))
        Gui.twitch.statusPanel:Layout();
        -- twitchWnd.appendTwitchMessage("*** status: " .. newState)
        
        if not esIcon then -- empty - set empty icon
            iconsHelper.setStatus("twitch", nil)
        elseif esIcon == "error" then    -- any error
            iconsHelper.setStatus("twitch", "fail")
        elseif esIcon == "retry" then    -- any reconnecting, but no errors
            iconsHelper.setStatus("twitch", "retry")
        else
            iconsHelper.setStatus("twitch", "ok")
        end
    end

    Twitch.init(twitchStateListener, twitchChatMessageListener, nil)

    local function twitchConnectWithValidation(event)
        logger.log("connecting to twitch with validation")
        -- Twitch.setupTimer()

        twitchWnd.appendTwitchMessage("*** checking token")
        local ok, data = Twitch.validateToken()
        updateTwitchInfo(ok, data)
        if ok then
            twitchWnd.appendTwitchMessage("*** token is OK, connecting to twitch:" .. Twitch.channel)
            Twitch.connect()
        else
            iconsHelper.setStatus("twitch", false)
        end
    end

    frame:Connect(Gui.twitch.connectBtn:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        local chan = Gui.twitch.channel:GetValue()
        if chan and chan ~= "" and chan ~= Twitch.channel then
            Twitch.channel = chan
        end
        iconsHelper.setStatus("twitch", nil)
        twitchConnectWithValidation(event)
    end))

    frame:Connect(Gui.twitch.autoconnect:GetId(), wx.wxEVT_CHECKBOX, evtHandler(function(event)
        Twitch.setAutoReconnect(event:IsChecked())
    end))

    -- VTube Studio, etc
    for i, v in ipairs(integrations) do
        if v.m.initializeIntegration then
            v.m.initializeIntegration()
        end
    end

    -- actions
    actionsHelper.init(integrations)

    -- triggers
    triggersHelper.init(integrations)

    -- scripts/integrations
    findWindow("integrationsPlaceholderPanel", "wxPanel", "panel", "scripts")
    local ilpg = wx.wxPropertyGrid(Gui.scripts.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxPG_SPLITTER_AUTO_CENTER + wx.wxPG_BOLD_MODIFIED)
    ilpg:Append(wx.wxPropertyCategory("Built-in", wx.wxPG_LABEL))
    for i, v in ipairs(integrations) do
        local prop = wx.wxBoolProperty(v.m.displayName, wx.wxPG_LABEL)
        prop:SetValueFromString("true")
        ilpg:Append(prop)
    end
    local ilpg_sizer = wx.wxBoxSizer(wx.wxVERTICAL)
    ilpg_sizer:Add(ilpg:GetPanel(), 1, wx.wxALL + wx.wxEXPAND, 5)
    Gui.scripts.panel:SetSizer(ilpg_sizer)
    Gui.scripts.panel:Layout()
    Gui.scripts.grid = ilpg
    Gui.transient["scripts.grid"] = true

    -- misc buttons for debugging
    findWindow("m_button3", "wxButton", "button3", "misc")
    findWindow("m_button4", "wxButton", "button4", "misc")
    findWindow("m_button5", "wxButton", "button5", "misc")
    findWindow("m_button6", "wxButton", "button6", "misc")
    findWindow("m_button7", "wxButton", "button7", "misc")
    findWindow("aboutPanel", "wxPanel", "aboutPanel", "misc")
    
    findWindow("loggingSetupPanel", "wxPanel", "panel", "logging")
    
    local loggers = {}
    for k, v in pairs(Logger.loggers) do
        table.insert(loggers, k)
    end
    table.sort(loggers)

    local fgSizer = wx.wxBoxSizer(wx.wxVERTICAL)

    local lpg = wx.wxPropertyGrid(Gui.logging.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxPG_SPLITTER_AUTO_CENTER + wx.wxPG_BOLD_MODIFIED)
    lpg:Append(wx.wxPropertyCategory("Logging",wx.wxPG_LABEL))

    fgSizer:Add(lpg:GetPanel(), 1, wx.wxALL + wx.wxEXPAND, 5)

    for i, name in ipairs(loggers) do
        local prop = wx.wxBoolProperty(name, wx.wxPG_LABEL)
        prop:SetValueFromString(tostring(Logger.loggers[name].enabled))
        lpg:Append(prop)
    end
    
    Gui.logging.panel:SetSizer(fgSizer)
    Gui.logging.panel:Layout()
    Gui.logging.grid = lpg
    Gui.transient["logging.grid"] = true

    -- hack: we can't GetId of the property grid for some reason so we connect it to the containing panel
    Gui.logging.panel:Connect(wx.wxID_ANY, wx.wxEVT_PG_CHANGED, function(event)
        local p = event:GetProperty()
        Logger.loggers[p:GetName()].enabled = p:GetValue():GetBool()
    end)

    local twitchDebug = false
    Gui.misc.button3:SetLabel("twitch debug")
    frame:Connect(Gui.misc.button3:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        if Twitch.chat_socket.id then
            twitchDebug = not twitchDebug
            NetworkManager.setDebug(Twitch.chat_socket.id, twitchDebug)
        end
    end)

    findWindow("m_button8", "wxButton", "gc", "misc")
    Gui.misc.gc:SetLabel("GC")
    frame:Connect(Gui.misc.gc:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(e)
        logger.log(collectgarbage("count"))
        collectgarbage("collect")
        logger.log(collectgarbage("count"))
    end)

    Gui.misc.button4:SetLabel("transient gui")
    frame:Connect(Gui.misc.button4:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        for k, v in pairs(Gui.transient) do
            logger.log(k, v)
        end
    end)

    
    Gui.misc.button5:SetLabel("list scripts")
    frame:Connect(Gui.misc.button5:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        local dir = wx.wxDir("src/integrations")
        if dir:IsOpened() then
            logger.log(dir:GetName())
            local i, v = dir:GetFirst("", wx.wxDIR_DIRS)
            while i do
                logger.log(i, v)
                i, v = dir:GetNext()
            end
        else
            logger.err("can't open dir")
        end
    end))
    
    Gui.misc.button6:SetLabel("dialog")
    local function createCollapsibleDlg()
        local dlg = wx.wxDialog(frame, wx.wxID_ANY, "sample dialog", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER, "wxDialog")
        local topLevelSizer = wx.wxBoxSizer(wx.wxVERTICAL);
        local bgPanel = wx.wxPanel(dlg, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize)
        local outerSizer = wx.wxFlexGridSizer(2, 1, 0, 5)

        bgPanel:SetSizer(outerSizer)

        local p1 = wx.wxCollapsiblePane(bgPanel, wx.wxID_ANY, "panel 1")
        local sizer1 = wx.wxBoxSizer(wx.wxVERTICAL)
        local t1 = wx.wxStaticText(p1:GetPane(), wx.wxID_ANY, "text1")
        sizer1:Add(t1, 0, wx.wxGROW + wx.wxALL, 2)
        local t2 = wx.wxTextCtrl(p1:GetPane(), wx.wxID_ANY, "very very long text can't fit into single row dskldsa d asds a", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE + wx.wxTE_BESTWRAP)
        sizer1:Add(t2, 1, wx.wxGROW + wx.wxALL, 2)
        p1:GetPane():SetSizer(sizer1)
        sizer1:SetSizeHints(p1:GetPane())

        outerSizer:Add(p1, 1, wx.wxGROW + wx.wxALL, 5)

        local p2 = wx.wxCollapsiblePane(bgPanel, wx.wxID_ANY, "panel 2")
        outerSizer:Add(p2, 0, wx.wxGROW + wx.wxALL, 5)

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

        return dlg
    end
    local collapsibleDlg = createCollapsibleDlg()

    frame:Connect(Gui.misc.button6:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        collapsibleDlg:ShowModal()
    end))

    Gui.misc.button7:SetLabel("DB total changes")
    frame:Connect(Gui.misc.button7:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local c = Db:total_changes()
        logger.log(Sqlite.version())
        Gui.statusbar:SetStatusText("Total changes: " .. tostring(c), 0)
        logger.log("Total changes: ", c)
    end)
    -- frame:Connect(wx.wxID_ANY, wx.wxEVT_HOTKEY, function(event)
        -- local keycode = event:GetKeyCode()
        
        -- logger.log("hotkey 1", keycode)
    -- end)
    -- frame:Connect(2, wx.wxEVT_HOTKEY, function(event)
        -- local this, main_thread = coroutine.running()
        -- logger.log("hotkey 2", main_thread)
    -- end)

    -- actions
    -- local actionList = replaceElement("actionsPlaceholder", function(parent)
        -- return wx.wxDataViewCtrl(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDV_SINGLE + wx.wxDV_HORIZ_RULES)
    -- end, "actionList", "actions")

    -- rest of init
    frame:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
        local page = Gui.listbook.list:GetFirstSelected()
        local rect = frame:GetRect()
        -- TODO sash position
        SaveToCfg("window", {x = rect:GetLeft(), y = rect:GetTop(), w = rect:GetWidth(), h = rect:GetHeight(), page = page})
        logger.log("closing")
        xpcall(NetworkManager.closeAll, function(err) print(err) end)
        wxTimers.stopAll()
        -- if authFrame then authFrame:Destroy() end
        event:Skip()
    end)
    
    Gui.listbook.list:Connect(wx.wxEVT_LIST_ITEM_SELECTED, function(event)
        -- logger.log("item selected")
        logger.log(event:GetIndex())
        Gui.listbook.book:SetSelection(event:GetIndex())
    end)

    -- when done
    -- wx.wxPostEvent(frame, wx.wxCommandEvent(wx.wxEVT_TOOL, gui.tools.load:GetId()))
    loadConfig()
    setLoggingLevels()
    local page = ReadFromCfg("window", "page", 0)
    if page < Gui.listbook.list:GetItemCount() then
        Gui.listbook.list:Select(page)
    else
        Gui.listbook.list:Select(0)
    end

    if Gui.twitch.autoconnect:GetValue() then
        wx.wxPostEvent(frame, wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, Gui.twitch.connectBtn:GetId()))
    end

    for i, v in ipairs(integrations) do
        if v.m.postProcess then
            v.m.postProcess()
        end
    end

    -- collectgarbage("collect")
    
    frame:Show(true)

    -- wx.wxLog.SetVerbose(true)
    -- local logWindow = wx.wxLogWindow(frame, "logger.log Messages", false)
    -- local pos = frame:GetPosition()
    -- local size = frame:GetSize()
    -- logWindow:GetFrame():Move(pos:GetX() + size:GetWidth() + 10, pos:GetY())
    -- logWindow:Show()
    -- wx.wxLogVerbose("OnPropertyGridChange(NULL)")
end
