is_wx_app = true

local iconsHelper = require("src/gui/icons")
local wxTimers = require("src/stuff/wxtimers")
local dialogHelper = require("src/gui/dialog_helper")
local triggersHelper = require("src/gui/triggers")
local actionsHelper = require("src/gui/actions")
local dataHelper = require("src/stuff/data_helper")

local ThingsToKeep = {} -- variable to store references to various stuff that needs to be kept
local accelTable = {}
local accelMenu = {}
local logger = Logger.create("main")
local actionLogger = Logger.create("actions")

ACTION_DISPATCH = wx.wxID_HIGHEST + 1   -- the wx id for "dispatch actions" message command

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

local function createAuthSock()
    local pollnet_http_sock = pollnet.serve_http("0.0.0.0:10115")
    local tw = assert(io.open("src/http_resp/tw.html", "r"))
    local twitch_auth_resp = tw:read("*a")
    tw:close()
    pollnet_http_sock:add_virtual_file("/tw_user", twitch_auth_resp)
    return pollnet_http_sock
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

local twitchWnd = require("src.gui.twitch_gui") -- don't forget to init

local function evtHandler(f)
    return function(event)
        local co = coroutine.wrap(f)
        -- table.insert(coros, co)
        local ok, res = co(event)
        -- if not ok then
            -- print("handler error", res)
        -- end
    end
end

local function getData(ok, result)
    if ok then
        logger.log(result.status)
        logger.log(result.body)
        local status = string.sub(result.status, 1, 3)
        if status == "200" and result.body and result.body ~= "" then
            print(result.status, result.body)
            return (Json.decode(result.body)).data
            --print(data[1].display_name)
        elseif status == "401" then
            twitchWnd.appendTwitchMessage("Token is invalid, press Auth")
            if result.body then twitchWnd.appendTwitchMessage(result.body) end
        end
    else
        logger.err("error: ", result)
    end
end

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
        id = Twitch.id,
    })
    
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
    Twitch.id = ReadFromCfg("twitch", "id", "")
    Twitch.token = Gui.twitch.token:GetValue()
    Twitch.username = Gui.twitch.username:GetValue()
    Twitch.channel = Gui.twitch.channel:GetValue()

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

local authFrame = nil
local webview = nil

local function updateTwitchInfo(ok, data, token)
    if token then
        Gui.twitch.token:SetValue(token)
        Twitch.token = token
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

function createAuthFrame()
    if authFrame then
        return
    end
    authFrame = wx.wxFrame(Gui.frame,
        wx.wxID_ANY,
        "Web Auth",
        wx.wxDefaultPosition,
        wx.wxSize(800, 600),
        wx.wxDEFAULT_FRAME_STYLE)
    
    webview = wxwebview.wxWebView.New(authFrame, wx.wxID_ANY, "about:blank", wx.wxDefaultPosition, wx.wxDefaultSize, wxwebview.wxWebViewBackendEdge)
    webview:Connect(wxwebview.wxEVT_WEBVIEW_NAVIGATED, evtHandler(function(event)
        local u = event:GetURL()
        if string.find(u, Twitch.redirect_url, 1, true) then
            local p = Twitch.parseAuth(u)
            if p then
                if p.access_token then
                    twitchWnd.appendTwitchMessage("twitch auth success")
                    Gui.twitch.token:SetValue(p.access_token)
                    Twitch.setToken(p.access_token)

                    local ok, data = Twitch.validateToken()
                    updateTwitchInfo(ok, data)
                else
                    twitchWnd.appendTwitchMessage("twitch auth error: " .. tostring(p.error or '').. " - " .. tostring(p.error_description or ''))
                end
            end
        end
    end))
    authFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
        authFrame = nil
        webview = nil
        event:Skip()
    end)
end

function main()
    -- HideConsole()
    NetworkManager.addSocket(createAuthSock()) -- no handler
    local xmlResource, frame = dialogHelper.loadMainWindow()
    if not xmlResource or not frame then return end
    Gui.frame = frame
    Gui.xmlResource = xmlResource

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
            local pid = wx.wxExecute(mainarg[1], wx.wxEXEC_ASYNC)
            if pid then
                wx.wxPostEvent(frame, wx.wxCloseEvent(wx.wxEVT_CLOSE_WINDOW, id))
            end
        elseif id == Gui.tools.help:GetId() then
            wx.wxLaunchDefaultBrowser("https://github.com/sokolas/strimble-app/wiki")
        end
    end)

    accelMenu = wx.wxMenu()
    local consoleMenuItem = accelMenu:Append(wx.wxID_ANY, "Console")

    accelTable = wx.wxAcceleratorTable({
        { wx.wxACCEL_NORMAL, wx.WXK_F12, consoleMenuItem:GetId()},
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

    -- set up listbook
    findWindow("listbook", "wxListbook", "listbook")
    local lblv = Gui.listbook:GetListView()
    iconsHelper.initializeListbook(lblv)

    -- set up main loop
    local function event_loop(event)
        -- network
        xpcall(function(event)
            NetworkManager.dispatch()
        end,
        function(err)
            -- timer:Stop()
            logger.log("network dispatch loop error", debug.traceback(err))
        end,
        event
        )
    end
    wxTimers.addTimer(50, frame, event_loop, true)

    local function dispatchActions()
        local logger = actionLogger
        local queues = dataHelper.getActionQueues()
        for k, queue in pairs(queues) do
            if #queue > 0 then
                if not queue.running then
                    logger.log("Processing queue", k, #queue)
                    queue.running = true
                    local ctx = queue[1]
                    logger.log("action", ctx.action)
                    local exec = function()
                        for i, step in ipairs(ctx.steps) do
                            logger.log("step", i, step.name)
                            local ok = step.f(ctx, step.params)
                            if not ok then
                                logger.log("step returned false, aborting action")
                                return  -- TODO false?
                            end
                        end
                    end
                    queue.co = coroutine.create(function()
                        -- try
                        xpcall(exec,
                            function(err)
                                logger.err("Action execution failed", debug.traceback(err))
                            end)
                        -- finally
                        queue.running = false
                        queue.co = nil
                        table.remove(queue, 1)
                        if #queue > 0 then
                            Gui.frame:QueueEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ACTION_DISPATCH))
                        else
                            logger.log(k, "is empty")
                        end
                    end)
                    local res = coroutine.resume(queue.co)
                    logger.log("co result", res)
                    if queue.co then
                        logger.log(coroutine.status(queue.co))
                    end
                else
                    logger.log(k, "is still running")
                end
            else
                logger.log(k, "is empty")
            end
        end
    end

    frame:Connect(ACTION_DISPATCH, wx.wxEVT_COMMAND_BUTTON_CLICKED, dispatchActions)

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
    twitchWnd.init(Gui.twitch.log)
    
    frame:Connect(Gui.twitch.authBtn:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local url = Twitch.getAuthUrl();
        createAuthFrame()
        if authFrame and webview then
            authFrame:Show(true)
            webview:LoadURL(url)
        end
    end)

    -- twitch reconnection logic
    local twitchReconnectTimer = nil
    
    Twitch.setMessageListener(function(message)
        if Gui.twitch.showChat:GetValue() then
            --[[if message.tags and #message.tags then
                for k, v in pairs(message.tags) do
                    twitchWnd.appendTwitchMessage(string.format("%s=%s", k, v))
                end
            end]]
            twitchWnd.appendTwitchMessage(string.format("%s/%s: %s", message.channel, message.user, message.text))
        end
        local tags = message.tags or {}
        local user = {
            id = tags["user-id"],
            displayName = tags["display-name"],
            name = message.user,
            subscriber = tags["subscriber"] == "1",
            mod = tags["mod"] == "1"
        }
        local triggered = triggersHelper.onTrigger("twitch_privmsg", {channel = message.channel, user = user, text = message.text})
    end)
    
    Twitch.setStateListener(function(oldState, newState)
        twitchWnd.appendTwitchMessage("*** status: " .. newState)
        if newState == "error" then
            iconsHelper.setStatus("twitch", false)
            -- TODO stop the timer in some cases
            twitchWnd.appendTwitchMessage("*** twitch chat connection error; retrying in 15 seconds")
            twitchReconnectTimer = wxTimers.addTimer(15000, frame, evtHandler(function(event) Twitch.reconnect() end))
        elseif newState == "joined" then
            twitchWnd.appendTwitchMessage("*** joined " .. Twitch.channel)
            iconsHelper.setStatus("twitch", true)
        end
    end)

    local function twitchConnectWithValidation(event)
        logger.log("connecting to twitch with validation; timer is " .. tostring(twitchReconnectTimer))

        twitchWnd.appendTwitchMessage("*** checking token")
        local ok, data = Twitch.validateToken()
        updateTwitchInfo(ok, data)
        if ok then
            twitchWnd.appendTwitchMessage("*** token is OK, connecting to chat:" .. Twitch.channel)
            Twitch.reconnect()
        else
            iconsHelper.setStatus("twitch", false)
            twitchReconnectTimer = wxTimers.addTimer(15000, frame, evtHandler(twitchConnectWithValidation))
        end
    end
    frame:Connect(Gui.twitch.connectBtn:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        local chan = Gui.twitch.channel:GetValue()
        if chan and chan ~= "" and chan ~= Twitch.channel then
            Twitch.channel = chan
        end
        iconsHelper.setStatus("twitch", nil)
        if twitchReconnectTimer then
            wxTimers.delTimer(twitchReconnectTimer)
            twitchReconnectTimer = nil
        end
        twitchConnectWithValidation(event)
    end))

    -- actions
    actionsHelper.init()

    -- triggers
    triggersHelper.init()

    -- misc buttons for debugging
    findWindow("m_button3", "wxButton", "button3", "misc")
    findWindow("m_button4", "wxButton", "button4", "misc")
    findWindow("m_button5", "wxButton", "button5", "misc")
    findWindow("m_button6", "wxButton", "button6", "misc")
    findWindow("m_button7", "wxButton", "button7", "misc")
    
    findWindow("loggingSetupPanel", "wxPanel", "panel", "logging")
    
    local loggers = {}
    for k, v in pairs(Logger.loggers) do
        table.insert(loggers, k)
    end
    table.sort(loggers)

    local fgSizer = wx.wxBoxSizer(wx.wxVERTICAL)

    local lpg = wx.wxPropertyGrid(Gui.logging.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxPG_SPLITTER_AUTO_CENTER + wx.wxPG_BOLD_MODIFIED)
    lpg:Append(wx.wxPropertyCategory("Logging",wx.wxPG_LABEL))

    -- fgSizer:Add(wx.wxStaticText(Gui.logging.panel, wx.wxID_ANY, "Logging"), 0, wx.wxALL + wx.wxEXPAND, 5)
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

    frame:Connect(wx.wxID_ANY, wx.wxEVT_PG_CHANGED, function(event)
        local p = event:GetProperty()
        Logger.loggers[p:GetName()].enabled = p:GetValue():GetBool()
    end)

    --[[local fgSizer = wx.wxBoxSizer(wx.wxVERTICAL)
    local loggingLabel = wx.wxStaticText(Gui.logging.panel, wx.wxID_ANY, "Logging")
    fgSizer:Add(loggingLabel, 0, wx.wxALL + wx.wxEXPAND, 5)
    for i, name in ipairs(loggers) do
        local v = Logger.loggers[name]
        local widget = wx.wxCheckBox(Gui.logging.panel, wx.wxID_ANY, name, wx.wxDefaultPosition, wx.wxDefaultSize)
        widget:SetValue(v.enabled)
        fgSizer:Add(widget, 0, wx.wxALL + wx.wxEXPAND, 5)
        Gui:insert(widget, name, "logging")
        frame:Connect(widget:GetId(), wx.wxEVT_CHECKBOX, function(event)
            local enabled = widget:GetValue()
            Logger.loggers[name].enabled = enabled
        end)
    end
    Gui.logging.panel:SetSizer(fgSizer)
    Gui.logging.panel:Layout() ]]

    local twitchDebug = false
    Gui.misc.button3:SetLabel("twitch debug")
    frame:Connect(Gui.misc.button3:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        if Twitch.chatSockId then
            twitchDebug = not twitchDebug
            NetworkManager.setDebug(Twitch.chatSockId, twitchDebug)
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
    --[[Gui.misc.button5:SetLabel("DROP triggers")
    frame:Connect(Gui.misc.button5:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        local db = Sqlite.open("data/config.sqlite3")
        db:execute("DROP TABLE triggers;")
        db:close()
    end))]]
    --[[Gui.misc.button6:SetLabel("load triggers")
    frame:Connect(Gui.misc.button6:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        triggersHelper.load()
    end))]]
    -- Gui.misc.button7:SetLabel("persist db")
    -- frame:Connect(Gui.misc.button7:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, evtHandler(function(event)
        -- local m = dialogHelper.showOkCancel(Gui.frame, "text", "caption")
    -- end))

    -- actions
    -- local actionList = replaceElement("actionsPlaceholder", function(parent)
        -- return wx.wxDataViewCtrl(parent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDV_SINGLE + wx.wxDV_HORIZ_RULES)
    -- end, "actionList", "actions")

    -- rest of init
    frame:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
        local rect = frame:GetRect()
        SaveToCfg("window", {x = rect:GetLeft(), y = rect:GetTop(), w = rect:GetWidth(), h = rect:GetHeight()})
        logger.log("closing")
        xpcall(NetworkManager.closeAll, function(err) print(err) end)
        wxTimers.stopAll()
        if authFrame then authFrame:Destroy() end
        event:Skip()
    end)
  
    -- when done
    -- wx.wxPostEvent(frame, wx.wxCommandEvent(wx.wxEVT_TOOL, gui.tools.load:GetId()))
    loadConfig()
    setLoggingLevels()

    if Gui.twitch.autoconnect:GetValue() then
        wx.wxPostEvent(frame, wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, Gui.twitch.connectBtn:GetId()))
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
