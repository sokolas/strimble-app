--[[
    An example of pluggable integration
    All the paths must be relative to the app directory (for example, "src/integrations/...") in this file and all the other related to this integration
    The app looks for init.lua file in the integration directory, `require`s it and then call several predefined functions you should expose:


    functions call order:

    (read page and icon properties to add to the UI pages)
    initializeUi (load controls)
    initializeIntegration (wire up UI events, set up listeners, create websockets, connect triggers, etc)
    registerStepIcons (add integration-specific icons to the steps list control imageset)
    initializeSteps (add custom steps for this integration, their dialogs, menu, etc)
    registerTriggerIcons (add integration-specific trigger icons (folder))
    initializeTriggers (TBD)
    (read config properties and set the corresponding UI values)
    loadConfig (read additional data from config)
    postProcess (call automatic actions that should be called on startup, when everything else is ready, like hitting the connect button)
    
    saveConfig (when the UI values are already saved, use this to store additional values)
]]
local logger = Logger.create("vts")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local vts = require("src/integrations/vts/vts")
local vtsSteps = require("src/integrations/vts/vts_steps")

local display_name = "VTube Studio"

local function initializeUi()
    local panelResource, tmpPanel = dialogHelper.loadPanel("src/integrations/vts/vtsUi.xrc", "vtsPanel", display_name)
    -- logger.log(tmpPanel)
    if not tmpPanel then
        return false
    end
    Gui.findWindow("vtsConnectBtn", "wxButton", "connect", "vts")
    Gui.findWindow("vtsRefresh", "wxButton", "refresh", "vts")
    Gui.findWindow("vtsAddress", "wxTextCtrl", "address", "vts")
    Gui.findWindow("vtsStatusText", "wxStaticText", "status", "vts")
    Gui.findWindow("vtsHotkeysLabel", "wxStaticText", "hotkeys", "vts")
    Gui.findWindow("vtsAutoconnect", "wxCheckBox", "autoconnect", "vts")
    return true
end

local function initializeIntegration()
    local function vtsStateListener(state, icon)
        Gui.vts.status:SetLabel("Status: " .. (state or "unknown"))
        -- twitchWnd.appendTwitchMessage("*** status: " .. newState)
        
        if not icon then
            iconsHelper.setStatus("vts", nil)
        elseif icon == "error" then
            iconsHelper.setStatus("vts", "fail")
        elseif icon == "retry" then
            iconsHelper.setStatus("vts", "retry")
        else
            iconsHelper.setStatus("vts", "ok")
        end
    end

    local function vtsDataChangeListener()
        local hotkeys = vts.getHotkeys()
        if not hotkeys then
            Gui.vts.hotkeys:SetLabel("Hotkeys: N/A")
        else
            Gui.vts.hotkeys:SetLabel("Hotkeys: " .. tostring(#hotkeys))
        end
    end
    
    vts.init(Gui.vts.address:GetValue(), nil, vtsStateListener, vtsDataChangeListener)    -- default url for now
    Gui.frame:Connect(Gui.vts.connect:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, EvtHandler(function(event)
        local url = Gui.vts.address:GetValue()
        if url and url ~= "" then
            vts.setAddress(url)
        end
        vts.connect()
    end))
    Gui.frame:Connect(Gui.vts.autoconnect:GetId(), wx.wxEVT_CHECKBOX, EvtHandler(function(event)
        vts.setAddress(Gui.vts.address:GetValue())
        vts.setAutoReconnect(event:IsChecked())
    end))
    Gui.frame:Connect(Gui.vts.refresh:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, EvtHandler(function(event)
        vts.refreshHotkeys()
    end))
end

local function postProcess()
    if Gui.vts.autoconnect:GetValue() then
        wx.wxPostEvent(Gui.frame, wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, Gui.vts.connect:GetId()))
    end
end

local function loadConfig()
    vts.setToken(ReadFromCfg("vts", "token", ""))
    vts.setAutoReconnect(Gui.vts.autoconnect:GetValue())
end

local function saveConfig()
    SaveToCfg("vts", {
        token = vts.getToken()
    })
end

local _M = {}

_M.icon = "src/integrations/vts/icons/vts.png"
_M.page = "vts"
_M.displayName = display_name
_M.initializeUi = initializeUi
_M.initializeIntegration = initializeIntegration
_M.registerStepIcons = vtsSteps.registerStepIcons
_M.initializeSteps = vtsSteps.init
_M.postProcess = postProcess
_M.loadConfig = loadConfig
_M.saveConfig = saveConfig

return _M
