local pollnet = pollnet or require("pollnet")

local function _try_reading(context, mode, value)
    if mode == "seq" then
        repeat
            print("reading seq")
            local done = false
            local start, finish = string.find(context.data, value, 1, true)
            if start then
                print("seq found at ", start)
                done = true
                local result = string.sub(context.data, 1, start-1)
                context.data = string.sub(context.data, finish+1)
                return true, result
            elseif context.done then
                print("context done")
                return false, context.data
            else
                print("waiting for more")
                coroutine.yield()   -- wait for more data
            end
        until done
    elseif mode == "len" then
        print("reading length", value)
        repeat
            local done = false
            if string.len(context.data) >= value then
                local result = string.sub(context.data, 1, value)
                context.data = string.sub(context.data, value+1)
                return true, result
            elseif context.done then
                print("context done")
                return false, context.data
            else
                print("waiting for more")
                coroutine.yield()   -- wait for more data
            end
        until done
    end
end

local function _handle_http(context)
    local headers = {}
    local ok, req_line = _try_reading(context, "seq", "\r\n")
    print("http handler req", ok, req_line)
    if ok then
        repeat
            local headers_done = false
            local ok, header_line = _try_reading(context, "seq", "\r\n")
            print("header_line", ok, header_line)
            if ok and header_line and header_line ~= "" then
                local colon_pos = string.find(header_line, ": ", 1, true)
                print(colon_pos)
                if colon_pos then
                    headers[string.lower(string.sub(header_line, 1, colon_pos-1))] = string.sub(header_line, colon_pos+2)
                end
            else
                headers_done = true
            end
        until headers_done
    else
        return nil
    end
    -- print("request line", req_line)
    -- print("headers")
    --[[for k, v in pairs(headers) do
        print(k, v)
    end]]
end

local function _on_update(context)
    repeat
        print(context.id .. " waiting for data")
        local ok, msg = coroutine.yield()
        if ok and msg then
            print ("new message", msg)
            context.data = context.data .. msg
            context.ready = true
        end
    until not ok
    print(context.id .. " done")
end

return {
    addr = nil,
    port = 9696,
    master_socket = nil,
    clients = {},
    mappings = {},


    on_request = function(self, sock, request)
        local request = request or {}

        if request.query and self.mappings[request.query] then
            -- call mapping
        end
        
    end,

    on_connection = function(self, client_sock, client_addr)
        print("Connection from " .. client_addr)
        local id = pollnet:nanoid()
        local context = {
            id = id,
            data = "",
            sock = client_sock,
            done = false,
            ready = false
        }
        local read_co = coroutine.create(function(context)
            _on_update(context)
        end)
        context.read_handler = read_co

        local handle_co = coroutine.create(function(context)
            _handle_http(context)
        end)
        context.http_handler = handle_co

        self.clients[id] = context
        coroutine.resume(read_co, context)    -- initial start
        coroutine.resume(handle_co, context)
        print("client started"--[[, coroutine.status(read_co), coroutine.status(handle_co)]])
    end,

    start = function(self)
        self.master_socket = pollnet.listen_tcp((self.addr or '0.0.0.0:') .. self.port)
        self.master_socket:on_connection(function(client_sock, client_addr)
            self.on_connection(self, client_sock, client_addr)
        end)
        print("listening on " .. self.port)
    end,

    dispatch = function(self)
        repeat
            local happy, msg = self.master_socket:poll()
            -- print(happy)
            -- print(msg)
            if not happy then
                return false
            end
        until not happy or not msg
        
        -- print("processing sockets")
        
        for k, v in pairs(self.clients) do
            repeat
                local happy, msg = v.sock:poll()
                -- print(k, happy)
                if happy then
                    if msg then
                        local stat = coroutine.resume(self.clients[k].read_handler, happy, msg)
                        print("reader", stat, coroutine.status(self.clients[k].read_handler))
                        local stat = coroutine.resume(self.clients[k].http_handler)
                        print("http_handler", stat, coroutine.status(self.clients[k].http_handler))
                        end
                else
                    local stat = coroutine.resume(self.clients[k].read_handler, happy, "")
                    print("closing")
                    self.clients[k].sock:close()
                    self.clients[k] = nil
                    print("closed")
                end
            until not happy or not msg
        end
        return true
    end,

    read = _try_reading
}