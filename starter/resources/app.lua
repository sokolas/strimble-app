return {
  postinit = function ()
    local bundle = wx.wxIconBundle()
    local files = FileSysGetRecursive("/res", false, "*.ico")
    local icons = 0
    for i,file in ipairs(files) do
      icons = icons + 1
      bundle:AddIcon(file, wx.wxBITMAP_TYPE_ICO)
    end
    if icons > 0 then ide.frame:SetIcons(bundle) end
  end,
  
  stringtable = {
    logo = "res/bug-256.png",
  },
}
