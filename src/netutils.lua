-- http response reader meant to be wrapped in a coroutine; reads all the parts and returns them to the suspended caller
local function _resp_reader(caller)
    local res = {}
    local ok, msg = coroutine.yield()
    -- print(ok, status)
    if not ok then
        res.error = msg
        return coroutine.resume(caller, ok, res)
    end
    res.status = msg
    local ok, msg = coroutine.yield()
    -- print(ok, headers)
    if not ok then
        res.error = msg
        return coroutine.resume(caller, ok, res)
    end
    res.headers = msg
    local ok, msg = coroutine.yield()
    -- print(ok, body)
    if not ok then
        res.error = msg
        return coroutine.resume(caller, ok, res)
    end
    res.body = msg
    return coroutine.resume(caller, ok, res)
end

-- exports

local _M = {
    sockets = {}
}

_M.setDebug = function(id, on)
    if _M.sockets[id] then
        _M.sockets[id].debug = on
    end
end

-- close all the sockets without any processing; usable when the program ends
local function closeAll()
    for k, v in pairs(_M.sockets) do
        if v.sock then
            v.sock:close()
            _M[k] = nil
        end
    end
end

-- add an open socket to the table for dispatching
local function addSocket(sock, handler, statusHandler, debug)
    local id = pollnet.nanoid()
    if debug then Log("added socket " .. id) end
    _M.sockets[id] = {
        sock = sock,
        handler = handler,
        statusHandler = statusHandler,
        debug = debug
    }
    return id
end

-- does not call the status handler because this function is supposed to be calle dmanually
local function delSocket(id)
    Log("deleting and closing " .. id)
    if _M.sockets[id] then
        if _M.sockets[id].sock then
            _M.sockets[id].sock:close()
            _M.sockets[id] = nil
        end
    end
end

-- poll and handle all the sockets;
-- first call statusHandler if it's defined, then message handler. Message handler can receive errors if poll returns false
-- when the handler is finished or the error occured the socket is closed and removed
local function dispatch()
    for id, v in pairs(_M.sockets) do
        if v.sock then
            -- repeat
                -- print("polling", id)
                local ok, msg = v.sock:poll()
                local status = v.sock:status()
                if v.debug then Log(id, ok, status, msg) end
                if status ~= v.status and v.statusHandler then
                    v.statusHandler(ok, v.status, status)
                end
                v.status = status
                
                local finished = false
                if v.handler and msg then
                    -- print("handling " .. id)
                    -- Log(id, "handling")
                    finished = v.handler(ok, msg)  -- msg can contain an error if not ok
                    -- Log(id, "finished", finished)
                end
                -- TODO check if the socket is still there in case it was closed in the handler???
                if not ok or finished then
                    -- if v.debug then
                        Log("closing " .. id)
                    -- end
                    
                    v.sock:close()
                    _M.sockets[id] = nil
                end
                finished = _M.sockets[id] == nil   -- if the socket was deleted don't poll it again
            -- until not ok or not msg or finished
        end
    end
end

-- suspendable; perporf a GET request
local function doGet(url, headers)
    local this, main_thread = coroutine.running()
    if main_thread then
        Log("Can't use suspendable 'doGet' from non-coroutine", debug.traceback())
        return false
    end
    local sock = pollnet.http_get(url, headers)
    local resp_reader = coroutine.create(_resp_reader)
    local ok, resp = coroutine.resume(resp_reader, this)   -- init
    if not ok then
        Log("http get error (init)", resp)  -- shouldn't be here, but still
        sock:close()
        return false
    end
    addSocket(sock, function(ok, msg)
        -- print("inside reader", ok, msg)
        local ok, caller_ok, resp = coroutine.resume(resp_reader, ok, msg)
        -- print("reader resume result", ok, caller_ok, resp)
        if not ok then
            Log("http get error (read)", resp)
        end
        if caller_ok == false then
            Log("Error in caller", resp)
        end
        return coroutine.status(resp_reader) == "dead" -- processing ended, we won't be able to handle further data anyway
    end)
    local ok, full_resp = coroutine.yield()
    return ok, full_resp
end

_M.addSocket = addSocket
_M.delSocket = delSocket
_M.closeAll = closeAll
_M.dispatch = dispatch
_M.get = doGet

return _M