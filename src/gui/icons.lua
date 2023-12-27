local logger = Logger.create("icons")
local icons = {
    {path = "images/icons/twitch.png", page = "twitch"},
    {path = "images/icons/obs.png", page = "obs"},
    {path = "images/icons/dollar-sign-solid.png", page = "da"},
    
    -- insert integrations here, at pos=4
    -- {path = "images/icons/vts.png", page = "vts"},

    {path = "images/icons/bolt-solid.png", page = "triggers"},
    {path = "images/icons/play-solid.png", page = "actions"},
    {path = "images/icons/code-solid.png", page = "scripts"},
    {path = "images/icons/settings.png", page = "misc"},
    {path = "images/icons/terminal-solid.png", page = "logs"},
    {path = "images/icons/bug_lines.png", page = "about"},
    
    {path = "images/icons/folder_black.png", page = "folder"},  -- not really a page
    {path = "images/icons/timer_black.png", page = "timer"},
    {path = "images/icons/folder_open_black_18dp.png", page = "folder_open"},  -- not really a page

    {path = "images/icons/check_reload.png"},
    {path = "images/icons/check_ok.png"},
    {path = "images/icons/warning.png"}
}
local int_pos = 4

local pages = {}

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

pages = getPages()

local function createImageList()
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
    return imageList
end

local lb = nil
local _M = {
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

    registerPage = function(name, icon)
        table.insert(icons, int_pos, {page = name, path = icon})
    end,
    int_pos = int_pos,

    createImageList = createImageList,
    initializeListbook = function(listbook)
        lb = listbook
        local imageList = createImageList()
        listbook:AssignImageList(imageList, wx.wxIMAGE_LIST_SMALL);
        listbook:InsertColumn(1, "status", wx.wxLIST_FORMAT_LEFT, -1)

        for i=1, listbook:GetItemCount() do -- add icons to the labels
            listbook:SetItem(i-1, 0, "  " .. listbook:GetItemText(i-1, 0), i-1)
        end
        listbook:SetColumnWidth(0, -1)
        listbook:SetColumnWidth(1, 18)
    end
}

return _M