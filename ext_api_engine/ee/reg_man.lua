--
-- Author: jasonxu
-- Date: 7/23/12
-- Time: 1:39 PM
-- Lua file to load register file and related manifest files
--

local wait_linda = lanes.linda()
local debugger = debugger

local urlec = {[' ']='%20', ['<']='%3C', ['>']='%3E', ['#']='%23', ['%']='%25', ['{']='%7B', ['}']='%7D',
    ['|']='%7C', ['\\']='%5C',['^']='%5E', ['~']='%7E', ['[']='%5B', [']']='%5D', ['`']='%60', [';']='%3B', ['/']='%2F',
    ['?']='%3F', [':']='%3A', ['@']='%40', ['=']='%3D', ['&']='%26', ['$']='%24'}
local function url_esc(s)
    local tmp = tostring(s)
    return string.gsub(tmp, "[ <>#%%{}|\\%^~%[%]`;/%?:@=&%$]", function(w)return urlec[w] end)
end

local reg_manager = function(linda)
    require("lfs")
    CFG = require("ee_conf")
    logger = function (msg)
        debugger.linda:send(1,"debug", {op="log",text='reg_man: '..tostring(msg)})
    end

    set_finalizer(function (err)
        if err then
            logger(tostring(err))
            local pid = require("pid")
            io.flush()
            pid.kill()
        end
    end)

    local threads = {}

    local renderers = {}
    local contents = {}
    local reg
    local function loadreg()
        renderers = {}
        contents = {}
        local b = assert(loadfile(CFG.BUILDIN_REG_FILE), "load regfile \""..CFG.BUILDIN_REG_FILE.."\" failed")
        reg = assert(b())
        logger("Successfully loaded registry file "..CFG.BUILDIN_REG_FILE)
        --[[b = loadfile(CFG.ADDON_REG_FILE)
        if b == nil then
            logger("No addon registry file found.  Skipping ...")
        else
            local addons = assert(b())
        end--]]

        for k,v in pairs(reg) do
            v.origin = CFG.BUILDINS_DIR
        end

        --[[if addons then
            for k,v in pairs(addons) do
                if reg[k] then
                    if CFG.ADDON_OVERLOAD_BUILDIN then
                        reg[k] = v
                        reg[k].origin = CFG.ADDONS_DIR
                        logger("Addon "..k.." overloaded buildin")
                    else
                        logger("Ignored addon "..k..", using the buildin "..k)
                    end
                else
                    reg[k] = v
                    reg[k].origin = CFG.ADDONS_DIR
                end
            end
        end--]]

        local function pattern_escape(str)
            return (string.gsub(str, '([%(%)%.%%%+%-%*%?%[%^%$])', function(a) return("%"..a) end))
        end

        for kk,vv in pairs(reg) do
             reg[kk].children = {}
            for k, v in pairs(reg) do
                string.gsub(k, pattern_escape(kk)..'/([^/]+)$', function (a) reg[kk].children[a]=a end, 1)
            end
        end

        local mf
        local manifests = {}
        for k, v in pairs(reg) do
            local mfn = v.origin..'/'..v.addon..'/'..'manifest.lua'
            if not manifests[mfn] then
                mf = assert(loadfile(mfn))
                manifests[mfn] = mf()
            end
            v.manifest = manifests[mfn]
        end

        function load_from_dir(dir, overload)
            for file in lfs.dir(dir) do
                if file ~= '.' and file ~= '..' then
                    local attr = lfs.attributes(dir..'/'..file)
                    assert(type(attr) == 'table')
                    if attr.mode == "directory" then
                        local mfn = dir..'/'..file..'/'..'manifest.lua'
                        if not manifests[mfn] then
                            mf = assert(loadfile(mfn))
                            local m = mf()
                            if m.addon_type == 'RENDERER' then
                                for k, v in pairs(m.accepted_types) do
                                    if renderers[k] == nil or (renderers[k] ~= nil and overload and renderers[k].origin ~= dir) then
                                        renderers[k] = {}
                                        renderers[k].origin = dir
                                        renderers[k].addon = file
                                        renderers[k].mime = k
                                        logger("renderer "..k.." loaded")
                                        --renderers[k].manifest = m
                                    end
                                end
                            elseif m.addon_type == 'CONTENT' then
                                for k, v in pairs(m.content_types) do
                                    if contents[k] == nil or (contents[k] ~= nil and overload and contents[k].origin ~= dir) then
                                        contents[k] = {}
                                        contents[k].origin = dir
                                        contents[k].addon = file
                                        contents[k].mime = k
                                        logger("content parser "..k.." loaded")
                                        --contents[k].manifest = m
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        load_from_dir(CFG.BUILDINS_DIR, false)
        --load_from_dir(CFG.ADDONS_DIR, ADDON_OVERLOAD_BUILDIN)

        --for k,v in pairs(renderers) do for kk,vv in pairs(v) do print(k,v,kk,vv) end end
    end

    local function url_decode(s)
        if s==nil then return nil end
        s = string.gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
        return s
    end

    local function pattern_escape(str)
        return (string.gsub(str, '([%(%)%.%%%+%-%*%?%[%^%$])', function(a) return("%"..a) end))
    end

    local function tokenlize_url(url)
        url = string.gsub(url, "/+", "/")
        if string.find(url, '/+$') then return nil, nil end
        local occ
        url, occ = string.gsub(url, '^'..pattern_escape(CFG.REST_ROOTPATH)..'/', "", 1)
        if occ == 0 then
            return nil,nil
        else
            url = '/'..url
        end

        local tokens = {}
        string.gsub(url, '/([^/]+)', function(a) table.insert(tokens, a)  end)

        local v,q
        _,_,v,q = string.find(tokens[#tokens],"([^%?]+)%??(.*)")
        if string.len(q) == 0 then
            q = nil
        end
        tokens[#tokens] = v
        for i = 1, #tokens do
            tokens[i]=url_decode(tokens[i])
        end
        return tokens,url_decode(q)
    end

    loadreg()
    local threads = {}
    while true do
        while true do
            local value, key = linda:receive("http", "thread")
            if key == "thread" then
                if value.op == "setfree" then
                    threads[value.id] = {status="free", linda=value.linda}
                elseif value.op == "getfree" then
                    local id = -1
                    for k,v in pairs(threads) do
                        if v then
                            if v.status == "free" then
                                v.status = "busy"
                                id = k
                                break
                            end
                        end
                    end
                    --wait_linda:receive(0.01, "waitwaitwait")
                    value.linda:send("thread", {op="freethread", id=id})
                end
            elseif key == "http" then
                local rv = {}
                rv.classpath = {}
                local http = value
                local tokens, query = tokenlize_url(http.url)
                if tokens == nil then
                    http.linda:send(http.thread_id, {op = "message", data={code=404, msg="Resource not found"}})
                    break
                end

                rv.renderer = renderers[CFG.DEFAULT_RENDERER_TYPE]
                if http.accept ~= nil then
                    for i = 1,#http.accept do
                        if renderers[http.accept[i]] ~= nil then
                            rv.renderer = renderers[http.accept[i]]
                            break
                        end
                    end
                end
                if http.method == "POST" then
                    rv.content_type = contents[CFG.DEFAULT_CONTENT_TYPE]
                    if http.content_type ~= nil then
                        if contents[http.content_type] ~= nil then
                            rv.content_type = contents[http.content_type]
                        end
                    end
                end

                local tmp = ''
                local url = ''
                local i = 1
                while tokens[i] ~= nil do
                    tmp = tmp..'/'..tokens[i]
                    url = url..'/'..url_esc(tokens[i])
                    if http.method == "GET" then
                        if reg[tmp] == nil then http.linda:send(http.thread_id, {op = "message", data={code=404, msg="Resource not found"}}) rv = nil  break end
                        if reg[tmp].manifest.classes[reg[tmp].class].key then --multiple instance
                            if i < #tokens - 1 then
                                url = url..'/'..url_esc(tokens[i+1])
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, index=tokens[i+1], op="has_instance", reg=reg[tmp]})
                                i = i + 2
                            elseif i == #tokens - 1 then
                                if query then
                                    http.linda:send(http.thread_id, {op = "message", data={code=501, msg="Query is not supported"}})
                                    rv = nil
                                    break
                                end
                                url = url..'/'..url_esc(tokens[i+1])
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, index=tokens[i+1], op="get", reg=reg[tmp]})
                                i = i + 2
                            elseif i == #tokens then
                                if query then
                                    table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="query", reg=reg[tmp], query=query})
                                else
                                    table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="enum", reg=reg[tmp]})
                                end
                                i = i + 1
                            end
                        else  --singleton
                            if i < #tokens then
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="has_instance", reg=reg[tmp]})
                                i = i + 1
                            elseif i == #tokens then
                                if query then
                                    --http.linda:send(http.thread_id, {op = "message", data={code=501, msg="Query is not supported"}})
                                    --rv = nil
                                    --break
                                    table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="query", reg=reg[tmp], query=query})
                                else
                                    table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="enum", reg=reg[tmp]})
                                end
                                i = i + 1
                            end
                        end
                    elseif http.method == "POST" then
                        if query then
                            http.linda:send(http.thread_id, {op = "message", data={code=501, msg="Query is not supported for HTTP POST"}})
                            rv = nil
                            break
                        end
                        if reg[tmp] == nil then
                            if i == #tokens then
                                local p = string.gsub(tmp, "/[^/]-$", "")
                                if p ~= nil and reg[p] ~= nil then
                                    --print("p=", p)
                                    if type(reg[p].manifest.classes[reg[p].class].methods) == "table" then
                                        if type(reg[p].manifest.classes[reg[p].class].methods[tokens[i]]) == "table" then
                                            if reg[p].manifest.classes[reg[p].class].key then
                                               table.insert(rv.classpath,{token=tokens[i], regpath=p, url = url, classname=reg[p].class, index=tokens[i-1], op="invoke", reg=reg[p]})
                                            else
                                                table.insert(rv.classpath,{token=tokens[i], regpath=p, url = url, classname=reg[p].class, op="invoke", reg=reg[p]})
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                            http.linda:send(http.thread_id, {op = "message", data={code=404, msg="Resource not found"}})
                            rv = nil
                            break
                        end
                        if reg[tmp].manifest.classes[reg[tmp].class].key then --multiple instance
                            if i < #tokens - 1 then
                                url = url..'/'..url_esc(tokens[i+1])
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, index=tokens[i+1], op="has_instance", reg=reg[tmp]})
                                i = i + 2
                            elseif i == #tokens - 1 then
                                url = url..'/'..url_esc(tokens[i+1])
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, index=tokens[i+1], op="set", reg=reg[tmp]})
                                i = i + 2
                            elseif i == #tokens then
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="create", reg=reg[tmp]})
                                i = i + 1
                            end
                        else  --singleton
                            if i < #tokens then
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="has_instance", reg=reg[tmp]})
                                i = i + 1
                            elseif i == #tokens then
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, op="set", reg=reg[tmp]})
                                i = i + 1
                            end
                        end
                    elseif http.method == "DELETE" then
                        if reg[tmp] == nil then http.linda:send(http.thread_id, {op = "message", data={code=404, msg="Resource not found"}}) rv = nil  break end
                        if reg[tmp].manifest.classes[reg[tmp].class].key then --multiple instance
                            if i < #tokens - 1 then
                                url = url..'/'..url_esc(tokens[i+1])
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, index=tokens[i+1], op="has_instance", reg=reg[tmp]})
                                i = i + 2
                            elseif i == #tokens - 1 then
                                url = url..'/'..url_esc(tokens[i+1])
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, url = url, classname=reg[tmp].class, index=tokens[i+1], op="delete", reg=reg[tmp]})
                                i = i + 2
                            elseif i == #tokens then
                                http.linda:send(http.thread_id, {op = "message", data={code=405, msg="Not Allowed", detail='Deletion is not allowed for URL "'..http.url..'"\n'}})
                                rv = nil
                                break
                            end
                        else  --singleton
                            if i < #tokens then
                                table.insert(rv.classpath,{token=tokens[i], regpath=tmp, classname=reg[tmp].class, op="has_instance", reg=reg[tmp]})
                                i = i + 1
                            elseif i == #tokens then
                                http.linda:send(http.thread_id, {op = "message", data={code=405, msg="Not Allowed", detail='Deletion is not allowed for URL "'..http.url..'"\n'}})
                                rv = nil
                                break
                            end
                        end
                    end
                end
                if rv then
                    --logger("======>" .. http.thread_id)
                    http.linda:send(http.thread_id, {op = "rest", data=rv})
                end
                rv = nil
            end
            collectgarbage("collect")
        end
    end
end

local reg_linda = lanes.linda()
local reg_manager_thread = lanes.gen("*", reg_manager)(reg_linda)


return { linda = reg_linda}
