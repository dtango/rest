CFG = require('ee_conf')
require('socket')
--local lanes = require('lanes')
--lanes.configure()

local wait_linda = lanes.linda()

local debugger = debugger
local reg =  reg
local function worker(thread_id, linda)
    local CFG = require('ee_conf')
    local lnull = require('luanull')
    logger = function (msg)
        debugger.linda:send(1,"debug", {op="log",text=thread_id..': '..tostring(msg)})
    end

    local old_error = _G.error
    _G.error = function(e)
        local err
        if type(e) ~= "table" then
           err = tostring(e)
        else
           err = tostring(e.code)..'  '..e.msg..' | '..tostring(e.detail)
        end
        if CFG.LOG_TRACE then
           logger(err..'\n'..debug.traceback())
        end
        old_error(e, -2)
    end

    _G.msg = function(e)
        old_error(e, -2)
    end

--    set_finalizer(function (err)
--        reg.linda:send("thread", {op = "setfree", linda = linda, id = thread_id})
--        if err then
--            logger(tostring(err))
--        end
--    end)

    local send_plain_message = function(sock, msg)
        if type(msg) ~=  "table" then
            code = "500"
            message = "Internal Error"
            detail = tostring(msg)
        else
            code = tostring(msg.code)
            message = msg.msg
            if msg.detail then detail = msg.detail else detail = msg.msg end
        end
        local rv = sock:send("HTTP/1.1 "..code..' '..message.."\r\n"..
                  "Content-Type: text/plain\r\n"..
                  "Content-Length: "..tostring(string.len(detail)+1).."\r\n\r\n"..detail..'\n')
        if not rv then
            logger("Connection lost, no status code sent.")
        end
    end
    rest = require("rest")

    --logger("Starting new worker ")
    package.path = CFG.LUALIB_PATH
    package.cpath = CFG.LUALIB_CPATH

    local http_parser = require('http')
    local socket = require('socket')

    local callcount = CFG.THREAD_LIFE
    if callcount == nil then callcount = 1 end
    while callcount > 0 do
        reg.linda:send("thread", {op = "setfree", linda = linda, id = thread_id})
        http_parser.init()

        collectgarbage("collect")
        callcount = callcount - 1
        local value,key = linda:receive(CFG.THREAD_TIMEOUT,thread_id)
        if not key then
            logger("Receive timeout, ending thread."..tostring(thread_id))
            break
        end;
        local fd
        if value.op == "fd" then
            fd = value.data
        else
            logger("Expecting fd, received "..tostring(value.op)..' '..tostring(value.data))
            fd = -1
        end

        if tonumber(fd) < 0 then
            logger("Received invalid fd "..tostring(fd).." ... Existing thread "..thread_id)
            break
        end

        local sock = socket.tcp(fd)
        local printfunc = function (a)
            local rv = sock:send(a)
            if not rv then
                error("Connection lost ...")
            end
        end

        local req, e
        while true do
            local line, err = sock:receive("*l")
            if line == nil then
                if err == "closed" then
                    logger("Remote peer hung up.")
                    break
                end
            else
                req, e = http_parser.addline(line)
                if e ~= nil then
                    send_plain_message(sock, e)
                elseif (req ~= nil) then
                    req.thread_id = thread_id
                    req.linda = linda
                    local reqmethod = string.upper(tostring(req.method))
                    if reqmethod ~= 'GET' and reqmethod ~= 'POST' and reqmethod ~= 'DELETE' then
                        send_plain_message(sock,{code=501, msg="Method Not Supported",
                            detail="Method \""..tostring(reqmethod).."\" is not supported"})
                        break
                    elseif reqmethod == 'POST' then
                        sock:settimeout(CFG.HTTP_TIMEOUT)
                        if tonumber(req.content_length) > 0 then
                            req.body = sock:receive(tonumber(req.content_length))
                        end
                    end
                    req.method=reqmethod
                    reg.linda:send("http", req)

                    local value, key = linda:receive(2, thread_id)
                    if key == nil then
                        send_plain_message(sock, {code=500, msg="Internal Error", detail="Time out resolving HTTP request.\n"})
                    elseif value.op == "rest" then
                        value.data.renderer.printfunc = printfunc
                        value.data.http_request = req
                        local status, result = pcall(rest.run, value.data)
                        if status then
                        else
                            send_plain_message(sock,result)
                        end
                    elseif value.op == "message" then
                        send_plain_message(sock,value.data)
                    else
                        local s = socket.tcp(fd)
                        s:close()
                        s = nil
                        sock:close()
                        sock = nil
                        error('fd='..tostring(fd).."  Expecting rest/message, received "..tostring(value.op)..' '..tostring(value.data))
                    end
                    --reg.linda:send("thread", {op = "setfree", linda = linda, id = thread_id})
                    break
                else
                end
            end
        end

        sock:close()
        sock = nil
    end

    return "done"
end

local workers = {}
local threads = {}
local wait_linda = lanes.linda()

local mt = {__mode='kv'}
mt.linda = lanes.linda()

for i = 1,CFG.MAX_THREADS,1 do
    local id = "thread"..tostring(i)
    threads[id] = {}
    threads[id].id = id
    reg.linda:send("thread", {op = "setfree", linda = mt.linda, id = id})
end

mt.get_free_worker = function()
    for i,v in pairs(threads) do
        if threads[i].thread ~= nil then
            local rv, err, stack = threads[i].thread:join(0)
            if rv == nil and err ~= nil then --error and not timeout
                threads[i].thread = nil
                if type(err) == 'string' then
                    logger("Thread "..threads[i].id.." ran into error: "..err)
                elseif type(err) == 'table' then
                    logger("Thread "..threads[i].id.." ran into error: "..err.code..' '..err.msg)
                end
                threads[i].thread = nil
                reg.linda:send("thread", {op = "setfree", linda = mt.linda, id = threads[i].id})
            else
                if rv == 'done' then
                    threads[i].thread = nil
                    reg.linda:send("thread", {op = "setfree", linda = mt.linda, id = threads[i].id})
                end
            end
        end
    end
    collectgarbage("collect")

    for i,v in pairs(threads) do
       if threads[i].thread ~= nil then
           local rv, err, stack = threads[i].thread:join(0)
           --print('---------------------------------',i, rv, err)
           if rv == nil and err ~= nil then --error and not timeout
               threads[i].thread = nil
              if type(err) == 'string' then
                 logger("Thread "..threads[i].id.." ran into error: "..err)
              elseif type(err) == 'table' then
                 logger("Thread "..threads[i].id.." ran into error: "..err.code..' '..err.msg)
              end
              threads[i].thread = nil
              reg.linda:send("thread", {op = "setfree", linda = mt.linda, id = threads[i].id})
              threads[i].thread = lanes.gen("*", worker)(v.id, mt.linda)
              return i
           else
               if rv == 'done' then
                   threads[i].thread = nil
                   reg.linda:send("thread", {op = "setfree", linda = mt.linda, id = threads[i].id})
                   threads[i].thread = lanes.gen("*", worker)(v.id, mt.linda)
                   return i
               end
           end
           --end of cleanup
       else
           threads[i].thread = lanes.gen("*", worker)(v.id, mt.linda)
           return i
       end
    end

    --   reg.linda:send("thread", {op = "getfree", linda = mt.linda})
--    local v, k = mt.linda:receive(2, "thread")
--    if k == "thread" then
--        if v.op == "freethread" then
--            if v.id == -1 then
--                return nil
--            elseif threads[v.id].thread == nil then
--                threads[v.id].thread = lanes.gen("*", worker)(v.id, mt.linda)
----                while threads[v.id].thread.status ~= "waiting" do
----                    print("threads[v.id].thread.status", threads[v.id].thread.status)
----                    print("waiting.............."..tostring(v.id))
----                    wait_linda:receive(0.1, "waitwaitwait")
----                    if threads[v.id].thread.status == "error" then
----                        print("i'm here", threads[v.id].thread.status)
----                        local rv, err, trace = threads[v.id].thread:join()
----                        print(err)
----                        threads[v.id].thread = nil
----                        return nil
----                    end
----                end
--                return v.id
--            else
--                return v.id
--            end
--        else
--            logger("Expecting thread management message, received "..tostring(value.op)..' '..tostring(value.data))
--        end
--    elseif k == nil then
--        logger("Finding free thread timeout")
--        return nil
--    end
    return nil
end

mt.__index = function (t,k)
    if k == "get_free_worker" or k == "linda" then
        return mt[k]
    end
    return threads[k]
end

mt.__newindex = function(t,k,v)
    error("can not modify read only talbe")
end

mt.__metatable = function(t)
    error("can not touch protected metatable")
end

setmetatable(workers, mt)
return workers