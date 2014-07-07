--
-- Created by IntelliJ IDEA.
-- User: jasonxu
-- Date: 5/14/13
-- Time: 10:54 AM
-- To change this template use File | Settings | File Templates.
--
local lpty = require "lpty"
local lanes = require("lanes")
lanes.configure()
local sleep = function(timeout)
    timer = lanes.linda()
    timer:receive(timeout, "_something_")
end

local function run(cmd)
    local stderrf = os.tmpname()
    local rtn = os.tmpname()
    local authtoken
    if ee_auth_token then authtoken = ' -p '..tostring(ee_auth_token)..' ' else authtoken = '' end
    local vshcmd = "/isan/bin/vsh "..authtoken.."-c '"..cmd.."'"..' 2>'..stderrf..' ; echo -n $? > '..rtn
    local f = assert(io.popen(vshcmd), "Cannot open vsh")
    local rv = f:read('*a') .. '\n'
    f:close()
    f = io.open(rtn,"r")
    local s = f:read("*all")
    f:close()
    os.execute("rm -rf "..rtn.." "..stderrf)
    local stderr
    local f = io.open(stderrf)
    if f then
        stderr = f:read('*a')
        f:close()
    end
    os.execute('rm -rf '..stderrf..' '..rtn)
    if tonumber(s) ~= 0 then
        logger("vsh command failed: "..vshcmd .. " code"..s)
        if string.find(rv, "%% Permission denied for the role") ~= nil then
            error({code=550, msg="Permission Denied"})
        else
            error({code=500, msg='vsh command "'..vshcmd..'" failed with '..s, stderr=stderr, stdout=rv, vshcode=tonumber(s)})
        end
    end
    return rv
end

local function ptyrun(command)
    local p = lpty.new({no_local_echo=true})
    p:startproc("/isan/bin/vsh")
    local str = ""
    local prompt
    local result
    while p:hasproc() do
        local a,b
        b = ""
        if prompt == nil then
            a = p:read()
            if a ~= nil then str = str .. a end
            if string.sub(str, string.len(str)-1) == "# " then
                prompt = string.gsub(str, "^.*\n(.*#%s)$", "%1")
                str = ""
            end
        else
            --io.write(prompt)
            --local cmd = io.read()
            local cmd = command.."\n"
            p:send(cmd)
            local rv = {}
            local c,t, total
            total = 0
            while p:hasproc() do
                a = p:read(1)
                if not a then a = "" end
                total = total + string.len(a)
                b = a
                local tmp = #rv
                while string.len(b) < string.len(prompt)+1 and tmp > 0 do
                    b = rv[tmp]..b
                    tmp = tmp - 1
                end
                _,_,c,t = string.find(b, "(.*\n)(.*#%s-)$")
                if t == prompt then
                    table.insert(rv, a)
                      result = string.sub(table.concat(rv),string.len(cmd)+1, total-string.len(prompt))
                    break
                else
                    table.insert(rv,a)
                end
            end
            p:endproc()
            break
        end
    end
    if result == nil then result = "" end
    return result
end

local function ptyconfig(cmd)
    local cmdhistory = {}
    local function localerror(err)
        local errmsg =""
        for k,v in ipairs(cmdhistory) do
            if v.errmsg then
                errmsg = errmsg .. v.result .."   "..v.cmd.."  Error Message: "..v.errmsg.."\n"
            else
                errmsg = errmsg .. v.result .."   "..v.cmd.."\n"
            end
        end
        error({code = 207, msg="Partially succeeded", detail=errmsg})
    end

    local p = lpty.new({no_local_echo=true})
    local function wait_prompt(cmd, cprompt)
        table.insert(cmdhistory, {cmd=cmd})
        local a,buf = "",""
        local b,e, body, ppt, errstr
        p:send(cmd.."\n")
        while p:hasproc() do
            a = p:read(1)
            if not a then
                error({code = 501, msg="Timeout", detail='Configure timeout.'})
            end
            buf = buf..a
            b,e,body,ppt = string.find(buf, "(.*)\n(.*# )$")
            if b then break end
        end
        b,e, errstr = string.find(body,"ERROR: (.*)")
        if b then
            error({code = 501, msg="Internal Error", detail=errstr})
        end
        b,e, errstr = string.find(body,"% (Permission.*)")
        if b then
            error({code = 403, msg="Forbidden", detail=errstr})
        end
        _,_,ppt = string.find(string.gsub(ppt, "%c", ""), "(.*# )$")
        b,e, errstr = string.find(body,".*\n(%s-)%^.*%^.*marker.*")
        if b then
            error({code = 400, msg="Bad Request", detail="Syntax error at position "..tostring(string.len(errstr)-string.len(cprompt)+1)..' for command "'..cmd..'"'})
        end
        local result = string.gsub(string.sub(body, string.len(cmd)+1),"%c","")
        --print (result, ppt)
        cmdhistory[#cmdhistory].result = "[Succeeded]"
        return result, ppt
    end

    if ee_auth_token then
        -- print("===================================",ee_auth_token)
        p:startproc("/isan/bin/vsh", "-p", tostring(ee_auth_token))
    else
        p:startproc("/isan/bin/vsh")
    end
    local str = ""
    local prompt
    local result
    while p:hasproc() do
        local a,b
        b = ""
        if prompt == nil then
            a = p:read()
            if a ~= nil then str = str .. a end
            if string.sub(str, string.len(str)-1) == "# " then
                _, _, prompt = string.find(str, "^.*\n(.*)#%s$")
                str = nil
            end
        else
            local status, val1, val2 = pcall(wait_prompt, "config t", prompt.."# ")
            local lastprompt = val2
            while #cmd > 0 do
                local c = table.remove(cmd,1)
                status, val1, val2 = pcall(wait_prompt, c.cmd, val2)
                if not status then
                    cmdhistory[#cmdhistory].result = "[Failed]"
                    cmdhistory[#cmdhistory].errmsg = val1.detail
                    if c.error then
                        status, val1 = pcall(c.error, val1, cmd)
                        if status then
                           val2 =  lastprompt
                        else
                            cmdhistory[#cmdhistory].result = "[Failed]"
                            cmdhistory[#cmdhistory].errmsg = val1.detail
                            break
                        end
                    else
                        localerror(val1)
                    end
                end
                lastprompt = val2
            end
            p:endproc()
            if not status then
                localerror(val1)
            else
                break
            end
        end
    end
end

local function newvsh()
    local p = lpty.new({no_local_echo=true})
    p:startproc("/isan/bin/vsh")
    local str = ""
    local prompt
    while p:hasproc() do
        local a,b
        b = ""
        if prompt == nil then
            a = p:read()
            if a ~= nil then str = str .. a end
            if string.sub(str, string.len(str)-1) == "# " then
                prompt = string.gsub(str, "^.*\n(.*#%s)$", "%1")
                str = ""
            end
        else
            break
        end
    end
    return p,prompt
end

local function vshexec(p, prompt, command)
    local result
    if p:hasproc() then
        local cmd = command.."\n"
        p:send(cmd)
        local a,b
        b = ""
        local rv = {}
        local c,t, total
        total = 0
        while p:hasproc() do
            a = p:read(1)
            if not a then a = "" end
            io.write(a)
            total = total + string.len(a)
            b = a
            local tmp = #rv
            while string.len(b) < string.len(prompt)+1 and tmp > 0 do
                b = rv[tmp]..b
                tmp = tmp - 1
            end
            _,_,c,t = string.find(b, "(.*\n)(.*#%s-)$")
            if t == prompt then
                table.insert(rv, a)
                result = string.sub(table.concat(rv),string.len(cmd)+1, total-string.len(prompt))
                break
            else
                table.insert(rv,a)
            end
        end
    end
    return result
end

local function endvsh(p)
    if p:hasproc() then p:endproc() end
end

local vsh = {run=run, ptyrun=ptyrun, ptyconfig=ptyconfig, newvsh=newvsh, endvsh=endvsh, exec=vshexec}
return vsh

