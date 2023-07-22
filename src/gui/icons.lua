local icons = {
    {path = "images/icons/twitch.png", page = "twitch"},
    {path = "images/icons/obs.png", page = "obs"},
    {path = "images/icons/dollar-sign-solid.png", page = "da"},
    {path = "images/icons/vts.png", page = "vts"},
    {path = "images/icons/bolt-solid.png", page = "triggers"},
    {path = "images/icons/play-solid.png", page = "actions"},
    {path = "images/icons/code-solid.png", page = "scripts"},
    {path = "images/icons/settings.png", page = "misc"},
    {path = "images/icons/terminal-solid.png", page = "logs"},
    {path = "images/icons/bug_lines.png", page = "about"},
    
    {path = "images/icons/folder_black.png", page = "folder"},  -- not really a page
    {path = "images/icons/timer_black.png", page = "timer"},

    {path = "images/icons/check_ok.png"},
    {path = "images/icons/warning.png"}
}
local ok = #icons-2
local fail = #icons-1
local pages = {}
for i, v in ipairs(icons) do
    if v.page then
        pages[v.page] = i-1
    end
end

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
    setStatus = function(page, status)
        if pages[page] then
            if status == nil then
                lb:SetItem(pages[page], 1, "", -1)
            elseif status == true then
                lb:SetItem(pages[page], 1, "", ok)
            else
                lb:SetItem(pages[page], 1, "", fail)
            end
        end
    end,
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