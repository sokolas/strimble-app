local _M = {
    selecting = false,
    buffer = '',
    lines = 0,
    maxLines = 500
}

_M.init = function(log)
    _M.log = log
    _M.log:Connect(wx.wxEVT_LEFT_DOWN, _M.onSelectStart)
    _M.log:Connect(wx.wxEVT_LEFT_UP, _M.onSelectStop)
end

_M.onSelectStart = function(evt)
    _M.selecting = true
    -- print("down")
    evt:Skip()
end

_M.onSelectStop = function(evt)
    _M.selecting = false
    local selection = _M.log:GetStringSelection()
    if selection and selection ~= "" then
        _M.log:Copy()
    end
    -- print("up")
    if _M.buffer ~= '' then
        _M.log:AppendText(_M.buffer)
        _M.buffer = ''
    end
    evt:Skip()
end

_M.appendTwitchMessage = function(text)
    Log(text)
    if _M.selecting then
        _M.buffer = _M.buffer .. text
        return
    end
    _M.log:Freeze()
    _M.log:AppendText((text or '') .. "\n")
    _M.lines = _M.lines + 1
    if _M.lines > _M.maxLines then
        local r = _M.lines - _M.maxLines
        for i = 1, r do
            local t = _M.log:GetValue()
            local pos = Lutf8.find(t, "\n", 1, true)
            if pos and pos > 0 then
                local line = Lutf8.sub(t, 1, pos)
                local l = Lutf8.len(line)
                _M.log:Remove(0, l + 1)
                _M.lines = _M.lines - 1
            end
        end
    end
    _M.log:Thaw()
end

return _M