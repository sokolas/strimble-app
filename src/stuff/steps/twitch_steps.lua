local _M = {}

_M.sendMessage = function(ctx, params)
    Twitch.sendToChannel(params.message, ctx.data.channel)
    return true
end

return _M