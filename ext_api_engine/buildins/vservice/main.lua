local vsh = require("vsh")
local node, path = {}, {}

local function readnode(cmd)
    local insts = {}
    local doc = vsh.ptyrun(cmd)
    local c,b,e, bb, be, bbb, bbe= 1,1,1,1,1,1,1
    local body, nodename, nodetype, ipaddr,failmode, adjacency
    while c<string.len(doc) do
        b,e,nodename, nodetype = string.find(doc,"\nvservice node ([^%s]+) type ([^%s]+).-\n", c)
        if e then
            insts[nodename] = {properties={name=nodename, type=nodetype}}
            c=e+1
        else
            break
        end

        while bb do
            bb,be, body = string.find(doc,"  (.-)\n", c)
            if bb == e + 1 then
                e =  be
                c = be + 1
                bbb, bbe, ipaddr = string.find(body, "ip address ([%d%.]*)")
                if bbb then
                    insts[nodename].properties.ipAddr = ipaddr
                else
                    bbb, bbe, failmode = string.find(body, "fail%-mode ([^%c]+)")
                    if bbb then
                        insts[nodename].properties.failmode = failmode
                    else
                        bbb, bbe, adjacency = string.find(body, "adjacency ([^%c]+)")
                        if bbb then
                            print(adjacency)
                            adjacency = adjacency:gsub("l2%sv","l2-v")
                            insts[nodename].properties.adjacency = adjacency
                        end
                    end

                end
            else
                c = e
                break
            end
        end
    end
    return {instances=insts}
end

node.enum = function()
    return readnode("show running-config vservice node | no-more")
end

node.get = function(index)
    local a = readnode("show running-config vservice node " ..index.." | no-more")
    for k,v in pairs(a.instances) do
        return a
    end
    error({code =404, msg="Not Found"})
end

node.has_instance = function(index)
    for k,v in pairs(readnode("show running-config vservice node " ..index.." | no-more").instances) do
        return true
    end
    return false
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
    if request.ipAddr then
        if  request.ipAddr == NULL then
            table.insert(node_create_seq, {cmd = "no ip address"})
        else
            table.insert(node_create_seq, {cmd = "ip address "..request.ipAddr})
        end
    end
    if request.failmode then
        if request.failmode == NULL then
            table.insert(node_create_seq, {cmd = "no fail-mode"})
        else
            table.insert(node_create_seq, {cmd = "fail-mode "..request.failmode})
        end
    else
    end
    if request.adjacency then
        if  request.adjacency == NULL then
            table.insert(node_create_seq, {cmd = "no adjacency"})
        else
            local b,e, mode, vlan, vid = request.adjacency:find("^%s*(l2)-(v.*lan)%s+(.+)")
            if b then
                if vlan == "vxlan" then
                    table.insert(node_create_seq, {cmd = "adjacency "..mode..' '..vlan..' '.."bridge-domain "..vid})
                else
                    table.insert(node_create_seq, {cmd = "adjacency "..mode..' '..vlan..' '..vid})
                end
            else
                table.insert(node_create_seq, {cmd = "adjacency "..request.adjacency})
            end
        end
    end
    --table.insert(node_create_seq, {cmd = "copy running-config startup-config"})
    table.insert(node_create_seq, {cmd = "end"})
    vsh.ptyconfig(node_create_seq)
end

node.set = node.create

local function readpath(cmd)
    local insts = {}
    local doc = vsh.ptyrun(cmd)
    local c,b,e, bb, be, bbb, bbe= 1,1,1,1,1,1,1
    local body, pathname
    while c<string.len(doc) do
        b,e,pathname= string.find(doc,"\nvservice path ([^%s]+).-\n", c)
        --print(b, e, pathname)
        if e then
            insts[pathname] = {properties={name=pathname, nodes={}}}
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
                    table.insert(insts[pathname].properties.nodes,{node=n,profileName=p,order=o})
                else
                    bbb, bbe, n,o=
                    string.find(body, "node ([^%c^%s]+) order ([^%c^%s]+)")
                    table.insert(insts[pathname].properties.nodes,{node=n,order=o})
                end
            else
                c = e
                break
            end
        end
    end
    return {instances=insts}
end


path.enum = function()
    return readpath("show running-config vservice path | no-more")
end

path.get = function(index)
    local a = readpath("show running-config vservice path " ..index.." | no-more")
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
    if request.nodes ~= nil then
        if status and val.instances[index].properties.nodes then
            for k,v in ipairs(val.instances[index].properties.nodes) do
                local tobe = v.node
                if request.nodes ~= NULL then
                    for kk,vv in ipairs(request.nodes) do
                        if v.node == vv.node then
                            tobe = nil
                            break
                        end
                    end
                end
                if tobe then table.insert(path_create_seq, {cmd = "no node "..tobe}) end
            end
        end

        if request.nodes~= NULL then
            for k,v in ipairs(request.nodes) do
                if not v.node or not v.order then
                    error({code = 400, msg="Bad Request", detail='Please provide the arguments "node" and "order"'})
                end
                local function e(err,cmdleft) --if trying to modify an existing node, remove the node first, then modify
                    if string.find(err.detail, "from this path and add it again with new order") then
                        table.insert(cmdleft, 1, {cmd = "no node "..v.node})
                        if v.profileName then
                            table.insert(cmdleft, 2, {cmd = "node "..v.node.." profile "..v.profileName.." order "..v.order})
                        else
                            table.insert(cmdleft, 2, {cmd = "node "..v.node.." order "..v.order})
                        end
                    else
                        error(err)
                    end
                end
                if v.profileName then
                    table.insert(path_create_seq, {cmd = "node "..v.node.." profile "..v.profileName.." order "..v.order, error = e})
                else
                    table.insert(path_create_seq, {cmd = "node "..v.node.." order "..v.order, error = e})
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
    for k,v in pairs(readpath("show running-config vservice path " ..index.." | no-more").instances) do
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

return {node=node, path=path}