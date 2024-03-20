local logger = Logger.create("network")

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

local _EXAMPLE_RESP = {
    status = "200",
    headers = {
        ['content-type'] = "text/plain"
    },
    body = [[hello world]],
    handler = function(req)
        -- method, path, query, headers, body
    end
}

local _FAVICON = {
    status = "200",
    headers = {
      ['content-type'] = "image/svg+xml"
    },
    -- Note! SVG documents must have *no whitespace* at front!
    body = [[]]
}

-- exports
local function handleServerRequest(sock, responses)
    -- TODO better error handling?
    
    local res = {}
    local ok, msg = coroutine.yield()
    -- logger.force(ok, msg)
    if not ok then
        res.error = msg
        return res
    end
    local method, path, query = pollnet.parse_method(msg)
    res.method = method
    res.path = path
    res.query = query

    local ok, msg = coroutine.yield()
    -- logger.force(ok, msg)
    if not ok then
        res.error = msg
        return res
    end
    res.headers = pollnet.parse_headers(msg)

    local ok, msg = coroutine.yield()
    -- logger.force(ok, msg)
    if not ok then
        res.error = msg
        return res
    end
    res.body = msg
    logger.force("request read finished")

    if responses then
        if responses[method] then
            if responses[method][path] then
                logger.force("handler found", method, path)
                sock:send(responses[method][path].status or "404")
                sock:send(pollnet.format_headers(responses[method][path].headers or {}))
                sock:send_binary(responses[method][path].body or "")
                if responses[method][path].handler then
                    responses[method][path].handler(res)
                end
            else
                logger.force("handler not found", method, path)
                sock:send("404")
                sock:send(pollnet.format_headers({}))
                sock:send_binary("no matching path")
            end
        else
            logger.force("method not found", method, path)
            sock:send("400")
            sock:send(pollnet.format_headers({}))
            sock:send({"no matching method"})
            sock:send_binary("")
        end
    else
        logger.force("nothing found", method, path)
        sock:send("404")
        sock:send(pollnet.format_headers({}))
        sock:send({"no responses specified"})
        sock:send_binary("")
    end
    -- req_sock:close()
end

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
    -- if debug then
        logger.force("added socket " .. id)
    -- end
    _M.sockets[id] = {
        sock = sock,
        handler = handler,
        statusHandler = statusHandler,
        debug = debug
    }
    return id
end

local function createServer(addr, responses, debug)
    local sock = pollnet.serve_dynamic_http(addr, false, function(req_sock, client_addr)
        -- if debug then
            logger.log("new client", client_addr)
        -- end
        local co = coroutine.create(handleServerRequest)
        coroutine.resume(co, req_sock, responses)
        addSocket(req_sock,
        function(ok, msg)
            -- if debug then
                logger.log("new client message", addr, ok, msg)
            -- end
            coroutine.resume(co, ok, msg)
        end,
        function(ok, oldState, newState)
            if debug then logger.log("server-client state change", ok, oldState, "->", newState) end
        end)
    end)
    local id = addSocket(sock)
    return id
end

-- does not call the status handler because this function is supposed to be called manually
local function delSocket(id)
    logger.force("deleting and closing " .. id)
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
                if v.debug then logger.force(id, ok, status, msg) end
                if status ~= v.status and v.statusHandler then
                    v.statusHandler(ok, v.status, status)
                end
                v.status = status
                
                local finished = false
                if v.handler and msg then
                    -- print("handling " .. id)
                    if v.debug then logger.force(id, "handling") end
                    finished = v.handler(ok, msg)  -- msg can contain an error if not ok
                    if v.debug then logger.force(id, "finished:", finished) end
                end
                -- TODO check if the socket is still there in case it was closed in the handler???
                if (not ok) or finished then
                    -- if v.debug then
                        logger.force("closing " .. id)
                    -- end
                    
                    v.sock:close()
                    _M.sockets[id] = nil
                end
                finished = _M.sockets[id] == nil   -- if the socket was deleted don't poll it again
                -- if v.debug then logger.force(id .. ": socket was deleted") end
            -- until not ok or not msg or finished
        end
    end
end

local function execute(this, url, method, headers, body, debug)
    local sock
    if method == "GET" then
        sock = pollnet.http_get(url, headers)
    elseif method == "POST" then
        sock = pollnet.http_post(url, headers, body)
    else
        return false, {error = "unsupported method"}
    end
    local resp_reader = coroutine.create(_resp_reader)
    local ok, resp = coroutine.resume(resp_reader, this)   -- init
    if not ok then
        logger.err("http request error (init)", resp)  -- shouldn't be here, but still
        sock:close()
        return false
    end
    addSocket(sock, function(ok, msg)
        -- print("inside reader", ok, msg)
        local ok, caller_ok, resp = coroutine.resume(resp_reader, ok, msg)
        -- print("reader resume result", ok, caller_ok, resp)
        if not ok then
            logger.err("http request error (read)", resp)
        end
        if caller_ok == false then
            logger.err("Error in caller", resp)
        end
        return coroutine.status(resp_reader) == "dead" -- processing ended, we won't be able to handle further data anyway
    end, nil, debug)
    local ok, full_resp = coroutine.yield()
    return ok, full_resp

end

-- suspendable; performs a GET request
local function doGet(url, headers)
    local this, main_thread = coroutine.running()
    if main_thread then
        logger.err("Can't use suspendable 'doGet' from non-coroutine", debug.traceback())
        return false
    end
    return execute(this, url, "GET", headers)
end

local function doPost(url, headers, body, debug)
    local this, main_thread = coroutine.running()
    if main_thread then
        logger.err("Can't use suspendable 'doPost' from non-coroutine", debug.traceback())
        return false
    end
    return execute(this, url, "POST", headers, body, debug)
end

_M.addSocket = addSocket
_M.delSocket = delSocket
_M.closeAll = closeAll
_M.dispatch = dispatch
_M.get = doGet
_M.post = doPost
_M.creareServer = createServer

return _M