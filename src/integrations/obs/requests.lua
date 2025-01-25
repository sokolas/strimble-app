local _M = {
    getScenesList = function()
        return "GetSceneList", nil
    end,

    getSceneItems = function(name, uuid)
        if uuid ~= nil and uuid ~= "" then
            return "GetSceneItemList", {sceneUuid = uuid}
        elseif name ~= nil and uuid ~= "" then
            return "GetSceneItemList", {sceneName = uuid}
        else
            return nil, nil
        end
    end,

    getSceneItemId = function (scene, source)
        return "GetSceneItemId", {sceneName = scene, sourceName = source}
    end,

    setSceneItemEnabled = function (scene, itemId, enabled)
        local e = enabled or false
        return "SetSceneItemEnabled", {sceneName = scene, sceneItemId = itemId, sceneItemEnabled = e}
    end
}

return _M
