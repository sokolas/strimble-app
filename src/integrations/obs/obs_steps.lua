local logger = Logger.create("obs_steps")

local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local obs = require("src/integrations/obs/obs")
local Ctx = require("src/stuff/action_context")
local obs_requests = require("src/integrations/obs/requests")

local _M = {}

local submenu = wx.wxMenu()

local stepIconPaths = {
    {path = "src/integrations/obs/icons/obs.png", name = "obs"},
}

local stepIcons = {}

local function registerStepIcons()
    stepIcons = iconsHelper.registerStepIcons(stepIconPaths)
end

local function sendRequest(ctx, params)
    local d = Json.decode(ctx:interpolate(params.requestData))
    local ok, res = obs.request(params.requestType, d)
    logger.log("send request result", res)
    return ok, res
end

local function setSourceVisibility(ctx, params)
    local sceneName = ctx:interpolate(params.scene)
    local sourceName = ctx:interpolate(params.source)

    local itemId = ""
    local ok, res = obs.request(obs_requests.getSceneItemId(sceneName, sourceName))
    if ok and res and res.requestStatus and res.requestStatus.code == 100 then
        itemId = res.responseData.sceneItemId
        -- itemId = res.
    else
        if res and res.requestStatus then
            logger.err(res.requestStatus.code, res.requestStatus.comment)
            return false, tostring(res.requestStatus.code) .. ": " .. res.requestStatus.comment
        else
            return false, "OBS error"
        end
    end
    ok, res = obs.request(obs_requests.setSceneItemEnabled(sceneName, itemId, params.visible))
    if ok and res and res.requestStatus and res.requestStatus.code == 100 then
        return ok, params.visible
    else
        if res and res.requestStatus then
            logger.err(res.requestStatus.code, res.requestStatus.comment)
            return false, tostring(res.requestStatus.code) .. ": " .. res.requestStatus.comment
        else
            return false, "OBS error"
        end
    end
end

local function getCachedScenesWithItems()
    local res = {}
    for i, scene in ipairs(obs.getScenesCache()) do
        -- logger.log(i, scene.sceneName)
        local items = {}
        if scene.items then
            for j, item in ipairs(scene.items) do
                -- logger.log(j, item.sourceName)
                table.insert(items, item.sourceName)
            end
        end
        res[scene.sceneName] = items
    end
    return res
end



local function init(menu, stepHandlers)
    -- set source visibility
    local setSourceVisibilityMenu = submenu:Append(wx.wxID_ANY, "Set source visibility")

    local setSourceVisibilityDialog = dialogHelper.createStepDialog(Gui, "SetObsSourceVisibilityDlg", {
        {
            name = "Set Source Visibility",
            controls = {
                {
                    name = "scene",
                    label = "Scene",
                    type = "combo"
                },
                {
                    name = "source",
                    label = "Source",
                    type = "combo",
                    watch = "scene",
                    watchHandler = "sceneWatch"
                },
                {
                    name = "visible",
                    text = "Visible",
                    type = "check"
                }
            }
        }
    },
    function(data, context)
        if (not data.scene) or data.scene == "" then
            return false, "Scene name can't be empty"
        elseif (not data.source) or data.source == "" then
            return false, "Source name can't be empty"
        else
            return true
        end
    end)
    
    stepHandlers[setSourceVisibilityMenu:GetId()] = {
        name = "Set OBS source visibility",
        dialogItem = setSourceVisibilityDialog,
        icon = stepIcons.obs,
        getDescription = function(result)
                local onoff = result.visible and "on" or "off"
                return (result.scene or "") .. " / " .. (result.source or "") .. ": " .. onoff
            end,
        code = setSourceVisibility,
        data = {
            requestData = "{}"
            -- hotkey = ""
        },
        init = {
            scene = function(c)
                local scenes = {}
                local scenesWithItems = getCachedScenesWithItems()
                logger.log(scenesWithItems)
                for k, v in pairs(scenesWithItems) do
                    table.insert(scenes, k)
                end
                -- logger.log(#scenes)
                c:Set(scenes)
            end
        },
        ctxBuilder = function()
            local scenesWithItems = getCachedScenesWithItems()
            logger.log(scenesWithItems)
            return {
                scenes = scenesWithItems,
                sceneWatch = function(items, scene, context)
                    local lines = {}
                    if context.scenes and context.scenes[scene] then
                        lines = context.scenes[scene]
                    end
                    items:Set(lines)
                end
            }
        end
    }

    -- send custom request
    local sendRequestMenu = submenu:Append(wx.wxID_ANY, "send custom request")

    local sendRequestDialog = dialogHelper.createStepDialog(Gui, "SendObsRequestDlg", {
        {
            name = "Send Hotkey",
            controls = {
                {
                    name = "requestType",
                    label = "Request type",
                    type = "text"
                },
                {
                    name = "requestData",
                    label = "Request data",
                    type = "multiline"
                },
                {
                    name = "comment",
                    label = "Comment",
                    type = "text"
                }
            }
        }
    },
    function(data, context)
        if (not data.requestType) or data.requestType == "" then
            return false, "Request type can't be empty"
        elseif (not data.requestData) or data.requestData == "" then
            return false, "Request data can't be empty"
        else
            local ok, d = Ctx.validateJson(data.requestData)
            if not ok then
                return false, "Request: " .. d
            end
            return true
        end
    end)
    
    stepHandlers[sendRequestMenu:GetId()] = {
        name = "Send custom OBS request",
        dialogItem = sendRequestDialog,
        icon = stepIcons.obs,
        getDescription = function(result) return (result.requestType or "") .. " / " .. (result.comment or "") end,
        code = sendRequest,
        data = {
            requestData = "{}"
            -- hotkey = ""
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "OBS")
end

_M.sendHotkey = sendRequest
_M.registerStepIcons = registerStepIcons
_M.init = init

return _M