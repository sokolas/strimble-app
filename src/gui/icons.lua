local logger = Logger.create("icons")

local imageLists = {}

local pageIcons = {

}

local triggerIcons = {
    {path = "images/icons/code.png", name = "active"},
    {path = "images/icons/code-off.png", name = "inactive"},
    {path = "images/icons/check_reload.png", name = "reload"},
    {path = "images/icons/check_ok.png", name = "ok"},
    {path = "images/icons/warning.png", name = "warning"}
}

local actionIcons = {
    {path = "images/icons/play-solid.png", name = "active"},
    {path = "images/icons/pause.png", name = "inactive"},
    {path = "images/icons/folder_black.png", name = "folder"},
    {path = "images/icons/check_reload.png", name = "reload"},
    {path = "images/icons/check_ok.png", name = "ok"},
    {path = "images/icons/warning.png", name = "warning"}
}

local defaultStepIcons = {
    "question"
}

local defaultTriggerIcons = {
    "question",
    "active",
    "inactive",
    "reload",
    "ok",
    "warning"
}

local stepIcons = {
    -- default icons: unknown, statuses
    -- integration icons
    -- when an integration adds its icons, return its icons + default ones, with indices
    {path = "images/icons/question_mark.png", name = "question"}
}

--[[
    1. pages list initialization
        1. load default icons for pages
        2. add integrations icons and pages
    2. actions initialization
        1. 
    3. triggers initialization
]]

local function namesToIcons(icons)
    local p = {}
    for i, v in ipairs(icons) do
        if v.name then
            p[v.name] = i-1
        end
    end
    return p
end

local function registerStepIcons(list) -- accepts a list of (path, name), returns a map of (name, index) of added icons and the default ones
    logger.log("registering step icons", list)
    local r = {}
    for i, v in ipairs(list) do
        table.insert(stepIcons, v)
        if v.name then
            r[v.name] = #stepIcons-1
        end
    end
    local indices = namesToIcons(stepIcons)
    for i, v in ipairs(defaultStepIcons) do
        r[v] = indices[v]
    end
    logger.log("returning registered step icons", r)
    return r
end

local function registerTriggerIcons(list) -- accepts a list of (path, name), returns a map of (name, index) of added icons and the default ones
    logger.log("registering trigger icons", list)
    local r = {}
    for i, v in ipairs(list) do
        table.insert(triggerIcons, v)
        if v.name then
            r[v.name] = #triggerIcons-1
        end
    end
    local indices = namesToIcons(triggerIcons)
    for i, v in ipairs(defaultTriggerIcons) do
        r[v] = indices[v]
    end
    logger.log("returning registered trigger icons", r)
    return r
end

local unknownIcon = {path = "images/icons/question_mark.png", name = "question"}

local icons = {
    {path = "images/icons/twitch.png", page = "twitch"},
    {path = "images/icons/dollar-sign-solid.png", page = "da"},
    
    -- insert integrations here, at pos=3
    -- {path = "images/icons/vts.png", page = "vts"},
    -- {path = "images/icons/obs.png", page = "obs"},

    {path = "images/icons/bolt-solid.png", page = "triggers"},
    {path = "images/icons/play-solid.png", page = "actions"},
    {path = "images/icons/code.png", page = "scripts"},
    {path = "images/icons/settings.png", page = "misc"},
    {path = "images/icons/terminal-solid.png", page = "logs"},
    {path = "images/icons/bug_lines.png", page = "about"},
    
    {path = "images/icons/folder_black.png", page = "folder"},  -- not really a page
    {path = "images/icons/timer_black.png", page = "timer"},
    {path = "images/icons/folder_open_black_18dp.png", page = "folder_open"},  -- not really a page
    {path = "images/icons/question_mark.png", page = "question"},   -- not really a page
    {path = "images/icons/keyboard.png", page = "hotkeys"},   -- not really a page
    {path = "images/icons/pause.png"},
    {path = "images/icons/code-off.png"},
    {path = "images/icons/check_reload.png"},
    {path = "images/icons/check_ok.png"},
    {path = "images/icons/warning.png"}
}
local int_pos = 3

local function getPages()
    local p = {}
    for i, v in ipairs(icons) do
        -- logger.log(i, v.page, v.path)
        if v.page then
            p[v.page] = i-1
        end
    end
    return p
end

local pages = getPages()

local function createImageList(name, icons)
    logger.log("creating image list with name", name, "and icons", icons)
    local imageList = wx.wxImageList(16, 16, true)
    for i, v in ipairs(icons) do
        -- Log(i, v)
        local img = wx.wxImage(v.path)
        img:Rescale(16, 16)
        local b = wx.wxBitmap(img)
        imageList:Add(b)
        img:delete()
        b:delete()
    end
    imageLists[name] = imageList
    return imageList
end

local lb = nil
local _M = {
    imageLists = imageLists,    -- to keep them loaded
    createImageList = createImageList,
    namesToIcons = namesToIcons,

    -- pages (main listbook)
    pages = pages,
    getPages = getPages,
    setStatus = function(page, status)
        local pages = getPages()
        local retry = #icons-3
        local ok = #icons-2
        local fail = #icons-1
        if pages[page] then
            if status == nil then
                lb:SetItem(pages[page], 1, "", -1)
            elseif status == "ok" then
                lb:SetItem(pages[page], 1, "", ok)
            elseif status == "retry" then
                lb:SetItem(pages[page], 1, "", retry)
            else
                lb:SetItem(pages[page], 1, "", fail)
            end
        end
    end,

    getTriggersPage = function() return pages.triggers end,

    registerPage = function(name, icon)
        table.insert(icons, int_pos, {page = name, path = icon})
    end,
    int_pos = int_pos,

    initializeListbook = function(listbook)
        lb = listbook
        local imageList = createImageList("pages", icons)
        listbook:AssignImageList(imageList, wx.wxIMAGE_LIST_SMALL);
        listbook:InsertColumn(1, "status", wx.wxLIST_FORMAT_LEFT, -1)

        for i=1, listbook:GetItemCount() do -- add icons to the labels
            listbook:SetItem(i-1, 0, "  " .. listbook:GetItemText(i-1, 0), i-1)
        end
        listbook:SetColumnWidth(0, -1)
        listbook:SetColumnWidth(1, 18)
    end,
    failIcon = function() return #icons-1 end,
    okIcon   = function() return #icons-2 end,
    retryIcon = function() return #icons-3 end,
    offIcon = function() return #icons-4 end,
    pauseIcon = function() return #icons-5 end,


    -- actions
    getActionIcons = function() return actionIcons end,
    getActionIconsIndices = function() return namesToIcons(actionIcons) end,

    -- steps
    getStepIcons = function() return stepIcons end,
    getStepIconsIndices = function() return namesToIcons(stepIcons) end,
    registerStepIcons = registerStepIcons,

    -- triggers
    getTriggerIcons = function() return triggerIcons end,
    getTriggerIconsIndices = function() return namesToIcons(triggerIcons) end,
    registerTriggerIcons = registerTriggerIcons,

}

return _M