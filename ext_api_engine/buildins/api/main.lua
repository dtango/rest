local function chunk(p, str)
    local a = {}
    p(string.format("%X",string.len(str)).."\r\n"..str.."\r\n")
end

local bashesc = function(cmd)
    local result = {}
    local quotopen = false
    string.gsub(cmd, ".", function(c)
       if c == "'" then
           if quotopen then
               table.insert(result, "'")
               quotopen = false
           end
           table.insert(result, "\'")
       else
           if quotopen then
               table.insert(result, c)
           else
               table.insert(result, "'"..c)
               quotopen = true
           end
       end
    end)
    if quotopen then table.insert(result, "'") end
    return table.concat(result)
end

local function run(cmd)
    local stderrf = os.tmpname()
    local rtn = os.tmpname()
    local authtoken
    if ee_auth_token then authtoken = ' -p '..tostring(ee_auth_token)..' ' else authtoken = '' end
    local vshcmd = "/isan/bin/vsh "..authtoken.."-c "..bashesc(cmd)..' 2>'..stderrf..' ; echo -n $? > '..rtn
    logger("before popen execute:\n"..vshcmd)
    local f = assert(io.popen(vshcmd), "Cannot open vsh")
    local rv = f:read('*a')
    f:close()
    f = io.open(rtn,"r")
    local s = f:read("*all")
    f:close()
    os.execute("rm -rf "..rtn.." "..stderrf)
    if tonumber(s) ~= 0 then
            error({code=500, msg='ERROR CODE '..tostring(s), detail=rv})
    end

    return rv
end



local function save_config(filename)
    local tmpfile = os.tmpname()

    local authtoken
    if ee_auth_token then authtoken = ' -p '..tostring(ee_auth_token)..' ' else authtoken = ' ' end

    local cmd = "expect /isan/ext_api_engine/buildins/api/save_config_expect '"..filename.."' > "..tmpfile
    logger("Execute SCP: expect /isan/ext_api_engine/buildins/api/save_config_expect '"..filename.."' > "..tmpfile)
    local rv = os.execute(cmd)
    local f = io.open(tmpfile)
    if f ~= nil then
        local s = f:read("*all")
        f:close()
        os.execute("rm -rf "..tmpfile)
        if rv ~= 0 then
            error({code=500, msg="Internal Error", detail=s})
        else
            return s
        end
    else
        error({code=500, msg='Internal Error'})
    end
end

local function api_enum_instances()
   return {instances = 
             {[""]={properties = {}}}
          }
end

local function scp(user, pass, addr, path)
    local tmpfile = os.tmpname()

    local authtoken
    if ee_auth_token then authtoken = ' -p '..tostring(ee_auth_token)..' ' else authtoken = ' ' end

    local cmd = "expect /isan/ext_api_engine/buildins/api/scp_expect '"..user.."' '"..pass.."' '"..addr.."' '"..path.."' '"..authtoken.."' > "..tmpfile
    logger("Execute SCP: expect /isan/ext_api_engine/buildins/api/scp_expect '"..user.."' '"..'$pass'.."' '"..addr.."' '"..path.."' '"..authtoken.."' > "..tmpfile)
    local rv = os.execute(cmd)
    local f = io.open(tmpfile)
    if f ~= nil then
        local s = f:read("*all")
        f:close()
        os.execute("rm -rf "..tmpfile)
        if rv ~= 0 then
            error({code=500, msg="Internal Error", detail=s})
        else
            return s
        end
    else
        error({code=500, msg='Internal Error'})
    end
end

local function load_plugin(name)

end

local function api_invoke(method)
    if method == 'cli' then
        return run(request.cmd)
    elseif method == 'scp' then
        return scp(request.username, request.password, request.address, request.path)
    elseif method == 'save_config' then
        return save_config(request.filename)
    elseif method == 'load_plugin' then
        return load_plugin(request.plugin)
    end
end

local function api_query()
    local p = _G.print_func
    if _G.query_string == "log" then
        p("HTTP/1.1 200 OK\r\n")
        p("Content-Type: text/plain; charset=utf-8\r\n")
        p("Transfer-Encoding: chunked\r\n")
        p("\r\n")
        local openlog = function(name)
        local f = io.open(name)
        if f then
        chunk(p,f:read("*all"))
        f:close()
        end
        end
        for i =  _G.configure.LOG_FILE_ROTATION,1 do
        openlog(_G.configure.LOG_FILE..'.'..tostring(i))
        end
        openlog(_G.configure.LOG_FILE)
        chunk(p, "")

        return nil
    else
        error({code=501, msg='Not Supported', detail='Query "'.._G.query_string..'" is not supported.'})
    end

end

return {
   api = {
      enum = api_enum_instances,
      invoke = api_invoke,
      has_instance = function ()      
         return true 
      end,
      query = api_query,
   },
}
