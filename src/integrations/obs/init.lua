local logger = Logger.create("obs")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local obs = require("src/integrations/obs/obs")
local obsSteps = require("src/integrations/obs/obs_steps")

local displayName = "OBS"

local function initializeUi()
    local panelResource, tmpPanel = dialogHelper.loadPanel("src/integrations/obs/obs.xrc", "obsPanel", displayName)
    logger.log(tmpPanel)
    if not tmpPanel then
        return false
    end
    Gui.findWindow("obsConnect", "wxButton", "connect", "obs")
    Gui.findWindow("obsAddress", "wxTextCtrl", "address", "obs")
    Gui.findWindow("obsPassword", "wxTextCtrl", "password", "obs")
    Gui.findWindow("obsStatusLabel", "wxStaticText", "status", "obs")
    Gui.findWindow("obsAutoconnect", "wxCheckBox", "autoconnect", "obs")
    return true
end

local function initializeIntegration()
    local function obsStateListener(state, icon)
        Gui.obs.status:SetLabel("Status: " .. (state or "unknown"))
        
        if not icon then
            iconsHelper.setStatus("obs", nil)
        elseif icon == "error" then
            iconsHelper.setStatus("obs", "fail")
        elseif icon == "retry" then
            iconsHelper.setStatus("obs", "retry")
        else
            iconsHelper.setStatus("obs", "ok")
        end
    end
    obs.init(Gui.obs.address:GetValue(), nil, obsStateListener, nil)    -- default url for now
    Gui.frame:Connect(Gui.obs.connect:GetId(), wx.wxEVT_COMMAND_BUTTON_CLICKED, EvtHandler(function(event)
        local url = Gui.obs.address:GetValue()
        if url and url ~= "" then
            obs.setUrl(url)
        end
        local pass = Gui.obs.password:GetValue()
        obs.setPasword(pass)
        obs.connect()
    end))
    Gui.frame:Connect(Gui.obs.autoconnect:GetId(), wx.wxEVT_CHECKBOX, EvtHandler(function(event)
        obs.setUrl(Gui.obs.address:GetValue())
        obs.setPasword(Gui.obs.password:GetValue())
        obs.setAutoReconnect(event:IsChecked())
    end))
end

local function postProcess()
    if Gui.obs.autoconnect:GetValue() then
        wx.wxPostEvent(Gui.frame, wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, Gui.obs.connect:GetId()))
    end
end

local function loadConfig()
    -- TODO set password and url properly
    obs.setAutoReconnect(Gui.obs.autoconnect:GetValue())
end

local function saveConfig()
    -- everything is saved as GUI values
end

local _M = {}

_M.icon = "src/integrations/obs/icons/obs.png"
_M.page = "obs"
_M.displayName = displayName
_M.initializeUi = initializeUi
_M.initializeIntegration = initializeIntegration
_M.registerStepIcons = obsSteps.registerStepIcons
_M.initializeSteps = obsSteps.init
_M.postProcess = postProcess
_M.loadConfig = loadConfig
_M.saveConfig = saveConfig

return _M
