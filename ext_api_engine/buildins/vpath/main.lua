local vsh = require("vsh")
local node, path, pool, vrf, vrfmap, idletime, port = {}, {}, {}, {}, {}, {}, {}

local function check(txt, pattern)
  local ib, ie, il = string.find(txt,pattern)
    if ib then
      return true
    else
      return false
    end
end

local function readnode(cmd)
  local doc = vsh.ptyrun(cmd)
--logger(cmd)
--logger(doc)
c = 1

  local insts = {}

  local nodetype, ipaddr,failmode
  local opernMode, overlay, adminState, isAgentless, forwarderIP
  local currentId, currentName
  local inside_node = 0

  while c<string.len(doc) do

    bb, be, line = string.find(doc,"(.-)\n", c)
    if bb then
        -- Already reached end of current line with this increment
        c = be + 1

        -- For node body
        if check(line,"^Node ID.*$") then
          -- capture id
          local b, e
          b,e,currentId = string.find(line,"Node ID%s*:[%s]+([%d]+)")
        end

        if check(line,"^Attribute.*$") then
          inside_node = 1
        end


        if inside_node == 1 then
          bbb, bbe, ipaddr = string.find(line, "Ip Address%s+([%d%.]*)")
          if bbb then
              temp.properties.ipAddress = ipaddr
          else
              bbb, bbe, failmode = string.find(line, "Fail Mode%s+(%w+)")
              if bbb then
                  temp.properties.failMode = failmode
              else
                  bbb, bbe, enc,segT,segV = string.find(line, "Overlay%s+{(%w+),%s*(%w+),%s*(%w+)}")         
                  if bbb then
                      temp.properties.overlay.encapType = enc 
                      temp.properties.overlay.segmentType = segT
                      temp.properties.overlay.segmentValue = segV
                  else
                      bbb, bbe, adminS = string.find(line, "Admin State%s+([%w]+)")
                      if bbb then
                          temp.properties.adminState = adminS
                      else
                          bbb, bbe, opernMode = string.find(line, "Operation Mode%s+([%w]+)")
                          if bbb then
                                  temp.properties.operationMode = opernMode
                          else                      
                              bbb, bbe, isagent = string.find(line, "Agentless%s+([%w]+)")
                              if bbb then
                                  temp.properties.isAgentless = isagent  
                              else
                                bbb, bbe, nodename = string.find(line, "Name%s+([%w]+)")
                                if bbb then
                                  temp = {properties={id=currentId, overlay ={}, isAgentless = "false" }}
                                  temp.properties.name = nodename
                                  currentName = nodename
                                else
                                bbb, bbe, fw = string.find(line, "Forwarder Address%s+([%d%.]*)")  
                                  if bbb then
                                    temp.properties.forwarderIP = fw
                                  else
                                    bbb, bbe, ty = string.find(line, "Type%s+([%w]+)")  
                                    if bbb then
                                      temp.properties.type = ty
                                    else
                                      bbb, bbe, mod = string.find(line, "Module%s+([%w]+)")  
                                      if bbb then
                                        temp.properties.module = mod
                                        insts[currentName] = temp
                                        inside_node = 0
                                      end
                                    end
                                  end
                                end
                              end

                          end
                      end
                  end
              end
          end
        end -- inside_node



      else
        insts[currentName] = temp
        c = c + 1

    end  -- if bb
end -- while c <

   return {instances = insts }
end


node.enum = function()
    return readnode("show vpath service-node detail | no-more")
end

node.get = function(index)
    local a = readnode("show vpath service-node name "..index.." | no-more")
    for k,v in pairs(a.instances) do
        return a
    end
    error({code =404, msg="Not Found"})
end


node.delete =  function(index)
    local node_del_seq = {
        {cmd = "no vservice node "..index, prompt_suffix = "(config)"},
        --{cmd = "copy running-config startup-config"},
        {cmd = "end", prompt_suffix = ""},
    }
    vsh.ptyconfig(node_del_seq)
end

node.create = function(index)
    local node_create_seq = {}

    if type(request.type) == "string" then
        table.insert(node_create_seq, {cmd = "vservice node "..index..' type '..request.type})
    else
        table.insert(node_create_seq, {cmd = "vservice node "..index})
    end
    if request.ipAddress then
        if  request.ipAddress == NULL then
            table.insert(node_create_seq, {cmd = "no ip address"})
        else
            table.insert(node_create_seq, {cmd = "ip address "..request.ipAddress})
        end
    end
    if request.failMode then
        table.insert(node_create_seq, {cmd = "fail-mode "..request.failMode})
    end

    if request.forwarderIP then
        table.insert(node_create_seq, {cmd = "forwarderIP "..request.forwarderIP})
    end

    if request.module then
        table.insert(node_create_seq, {cmd = "module "..request.module})
    end
    if request.overlay then
        if request.overlay.encapType then
            if request.overlay.encapType == "UDP" then
                table.insert(node_create_seq, {cmd = "adjacency l3"})
            end
            if request.overlay.encapType == "LLCSNAP" then
                if request.overlay.segmentType == "vlan" or request.overlay.segmentType == "VLAN" then
                    local adjac = "adjacency l2 vlan "..request.overlay.segmentValue 
                    table.insert(node_create_seq, {cmd = adjac})
                elseif request.overlay.segmentType == "vxlan" or request.overlay.segmentType == "VXLAN" then
                    local adjac = "adjacency l2 vxlan".." bridge-domain "..request.overlay.segmentValue 
                    table.insert(node_create_seq, {cmd = adjac})
                else
                    local adjac = "adjacency l2 "..request.overlay.segmentType.." "..request.overlay.segmentValue 
                    table.insert(node_create_seq, {cmd = adjac})
                end
            end
        end
    end


    if request.isTransparent then
        if request.isTransparent == "false" then
            table.insert(node_create_seq, {cmd = "opern-mode terminated"})
        end
    end
    if request.adminState then
        if request.adminState == "up" then
            table.insert(node_create_seq, {cmd = "admin-state up"})
        end
        if request.adminState == "down" then
            table.insert(node_create_seq, {cmd = "admin-state down"})
        end
    end
    if request.isAgentless then
        if request.isAgentless == "true" then
            table.insert(node_create_seq, {cmd = "agentless"})
        end
        if request.isAgentless == "false" then
            table.insert(node_create_seq, {cmd = "no agentless"})
        end
    end
    --table.insert(node_create_seq, {cmd = "copy running-config startup-config"})
    table.insert(node_create_seq, {cmd = "end"})
    vsh.ptyconfig(node_create_seq)
end

node.set = node.create

-- end node methods



-- Start path methods
local function readpath(cmd)
    local insts = {}
    local doc = vsh.ptyrun(cmd)
    local c,b,e, bb, be, bbb, bbe= 1,1,1,1,1,1,1
    local body, pathname
    while c<string.len(doc) do
        b,e,pathname= string.find(doc,"\nvservice path ([^%s]+).-\n", c)
        --print(b, e, pathname)
        if e then
            insts[pathname] = {properties={name=pathname, serviceNodes={}}}
            c=e+1
        else
            break
        end

        while bb do
            bb,be, body = string.find(doc,"  (.-)\n", c)
            if bb == e + 1 then
                e =  be
                c = be + 1
                local n,p,o
                bbb, bbe, n,p,o=
                string.find(body, "node ([^%c^%s]+) profile ([^%c^%s]+) order ([^%c^%s]+)")
                --print(bbb, bbe, n,p,o)
                if bbb then
                    table.insert(insts[pathname].properties.serviceNodes,{name=n,profileName=p,order=o})
                else
                    bbb, bbe, n,o=
                    string.find(body, "node ([^%c^%s]+) order ([^%c^%s]+)")
                    table.insert(insts[pathname].properties.serviceNodes,{name=n,order=o})
                end
            else
                c = e
                break
            end
        end
    end
    return {instances=insts}
end


local function readspath(cmd, index)
    local insts = {}
    local doc = vsh.ptyrun(cmd)
--    logger(cmd)
--    logger(index)
--    logger(doc)
    c = 1
    pname = index
    local inside_body = 0
    while c<string.len(doc) do

        bb, be, line = string.find(doc,"(.-)\n", c)
       -- print(line)
        if bb then
            -- Already reached end of current line with this increment
            c = be + 1  

            -- Get Path ID
            if check(line,"^Path ID.*$") then
                local b ,e
                b, e, path_id, raw_path_id = string.find(line, "Path ID%s*:%s*(%w+)%s*%(raw:(%w+)%)")
             --  print(path_id)
                inside_body = 0
            end

            -- Get Path Name
            if check(line,"^Path Name.*$") then
                local b ,e
                b, e, path_name = string.find(line, "Path Name%s*:%s*(%w+)")
               -- print(path_name)
                --print(path_id)
                inside_body = 0
                pname = path_name
            end

            --if check(line,"^Raw Path.*$") then
            --    local b ,e
            --    b, e, raw_path_id = string.find(line, "Raw Path ID:(%w+)")
                --print(raw_path_id)
            --end

            if check(line,"^Node%-Name.*$") then
              inside_body = 1
              
              insts[pname] = { properties = {serviceNodes={}, id = path_id, rawId = raw_path_id, name = pname} }
            end

            p = ""
            if inside_body == 1 then
                if check(line,"AG - .*") then
                    break
                end
                if check(line,"TR - .*") then
                    break
                end
                if check(line,"UP - .*") then
                    break
                end
                      
                if not check(line,"^Node%-Name.*$") then
                  bb, be, n, o= string.find(line, "(%w+)%s+(%w+)%s+")
                  if bb then
                    table.insert(insts[pname].properties.serviceNodes,{name=n,order=o})
                  end
                end 
            end
        else
        
        c = c + 1
        end  -- if bb
    end -- while c <
    --print("name : "..insts["p2"].properties.name)
   return {instances = insts }
end


path.enum = function()
    return readspath("show vpath service-path detail | no-more","")
end

path.get = function(index)
    local a = readspath("show vpath service-path name "..index.." | no-more", index)
    for k,v in pairs(a.instances) do
        return a
    end
    error({code =404, msg="Not Found"})
end

path.create = function(index)
    local path_create_seq = {
        {cmd = "vservice path "..index},
    }
    local status, val = pcall(path.get, index)
    if request.serviceNodes ~= nil then
        if status and val.instances[index].properties.serviceNodes then
            for k,v in ipairs(val.instances[index].properties.serviceNodes) do
                local tobe = v.name
                if request.serviceNodes ~= NULL then
                    for kk,vv in ipairs(request.serviceNodes) do
                        if v.name == vv.name then
                            tobe = nil
                            break
                        end
                    end
                end
                if tobe then table.insert(path_create_seq, {cmd = "no node "..tobe}) end
            end
        end

        if request.serviceNodes~= NULL then
            for k,v in ipairs(request.serviceNodes) do
                if not v.name or not v.order then
                    error({code = 400, msg="Bad Request", detail='Please provide the arguments "node" and "order"'})
                end
                local function e(err,cmdleft) --if trying to modify an existing node, remove the node first, then modify
                    if string.find(err.detail, "from this path and add it again with new order") then
                        table.insert(cmdleft, 1, {cmd = "no node "..v.name})
                        if v.profileName then
                            table.insert(cmdleft, 2, {cmd = "node "..v.name.." profile "..v.profileName.." order "..v.order})
                        else
                            table.insert(cmdleft, 2, {cmd = "node "..v.name.." order "..v.order})
                        end
                    else
                        error(err)
                    end
                end
                if v.profileName then
                    table.insert(path_create_seq, {cmd = "node "..v.name.." profile "..v.profileName.." order "..v.order, error = e})
                else
                    table.insert(path_create_seq, {cmd = "node "..v.name.." order "..v.order, error = e})
                end
            end
        end
    end
    --table.insert(path_create_seq, {cmd = "copy running-config startup-config"})
    table.insert(path_create_seq, {cmd = "end"})

    vsh.ptyconfig(path_create_seq)
end

path.set = path.create

path.has_instance = function(index)
    for k,v in pairs(readpath("show vpath service-path name "..index.." | no-more").instances) do
        return true
    end
    return false
end

path.delete = function(index)
    local path_del_seq = {
        {cmd = "no vservice path "..index},
        --{cmd = "copy running-config startup-config"},
        {cmd = "end", prompt_suffix = ""},
    }
    vsh.ptyconfig(path_del_seq)
end

-- end path methods


-- Start pool methods ----------------------------------

pool.get = function(index)
    return true

end

pool.create = function(index)
    return true

end

pool.enum = function(index)
    return true

end




pool.set = pool.create

pool.delete = function(index)
    return true

end

pool.has_instance = function(index)
    return true

end


-- end pool methods --------------------------------------


-- Start vrf methods ----------------------------------

vrf.get = function(index)
    return true

end

vrf.create = function(index)
    return true

end

vrf.enum = function(index)
    return true

end




vrf.set = vrf.create

vrf.delete = function(index)
    return true

end

vrf.has_instance = function(index)
    return true

end


-- end vrf methods --------------------------------------



-- Start vrfmap methods ----------------------------------

vrfmap.get = function(index)
    return true

end

vrfmap.create = function(index)
    return true

end

vrfmap.enum = function(index)
    return true

end




vrfmap.set = vrfmap.create

vrfmap.delete = function(index)
    return true

end

vrfmap.has_instance = function(index)
    return true

end


-- end vrfmap methods --------------------------------------




-- Start idletime methods ----------------------------------

idletime.get = function(index)
    return true

end

idletime.create = function(index)
    return true

end

idletime.enum = function(index)
    return true

end




idletime.set = idletime.create

idletime.delete = function(index)
    return true

end

idletime.has_instance = function(index)
    return true

end


-- end idletime methods --------------------------------------




-- Start port methods ----------------------------------

port.get = function(index)
    return true

end

port.create = function(index)
    return true

end

port.enum = function(index)
    return true

end




port.set = port.create

port.delete = function(index)
    return true

end

port.has_instance = function(index)
    return true

end


-- end port methods --------------------------------------




local _blank = {
        has_instance = function() return true end,
    enum = function() return { instances = { [""] = { properties = {} } } } end,
}

return {
    vpath = _blank,
    v1 = _blank,
    node = node, 
    path = path,
    pool = pool,
    vrf = vrf,
    vrfmap = vrfmap,
    idletime = idletime,
    port = port,
}

