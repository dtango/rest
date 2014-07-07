-- Created by IntelliJ IDEA.
-- User: skolar
-- Date: 6/20/13
-- Time: 1:41 PM
-- To change this template use File | Settings | File Templates.
--

local vsh = require("vsh")
local sax = require("sax")

local insts = {}
local inst
local props = {}


local v = {}

local sc = {}
vxlanExist = flase
local vxlanCount = false
local flags = {}

sc.startElement =  function (en)
    if en == "ROW_bd" then
        flags.newInstance = true
    elseif en == "segment_id" and flags.newInstance then
        vxlanCount = true
        flags.id = true
    elseif en == "bd_name" and flags.newInstance then
        flags.name = true
    elseif en == "mode" and flags.newInstance then
        flags.mode = true
    elseif en == "mac_dist" and flags.newInstance then
        flags.macDist = true
    elseif en == "group_ip" and flags.newInstance then
        flags.group = true
    elseif en == "mac_learning" and flags.newInstance then
        flags.macLearn = true
    elseif en == "state" and flags.newInstance then
        flags.state = true
    elseif en == "port_count" and flags.newInstance then
        flags.ports = true
    end
end



sc.endElement =  function (en)
    if en == "ROW_bd" then
        flags.newInstance = nil
    elseif en == "segment_id" and flags.newInstance then
        flags.id = nil
    elseif en == "bd_name" and flags.newInstance then
        flags.name = nil
    elseif en == "mode" and flags.newInstance then
        flags.mode = nil
    elseif en == "mac_dist" and flags.newInstance then
        flags.macDist = nil
    elseif en == "group_ip" and flags.newInstance then
        flags.group = nil
    elseif en == "mac_learning" and flags.newInstance then
        flags.macLearn = nil
    elseif en == "state" and flags.newInstance then
        flags.state = nil
    elseif en == "port_count" and flags.newInstance then
        flags.ports = nil
    end
end


sc.characters =  function (v)
    if flags.name then
        if flags.newInstance then
            flags.key = v
            insts[v] = {}
            insts[v].properties= {id=tonumber(v)}
        end
    end
    if flags.id and flags.newInstance then
        insts[flags.key].properties.id = tonumber(v)
    end
    if flags.mode and flags.newInstance then
        insts[flags.key].properties.mode = v
    end
    if flags.macDist and flags.newInstance then
        insts[flags.key].properties.macDist = v
    end
    if flags.group and flags.newInstance then
        insts[flags.key].properties.group = v
    end
    if flags.macLearn and flags.newInstance then
        insts[flags.key].properties.macLearn = v
    end
    if flags.state and flags.newInstance then
        insts[flags.key].properties.state = v
    end
    if flags.ports and flags.newInstance then
        insts[flags.key].properties.ports = v
    end
end

v.enum = function()
    local xml = vsh.run("show bridge-domain | xml")
    sax.parse(xml,sc)
    return {instances=insts}
end


v.get = function(index)
    local xml = vsh.run("show bridge-domain "..index.. " | xml")
    sax.parse(xml,sc)
    if not vxlanCount or next(insts)==nil then
       error({code =404, msg="Not Found", detail='Vxlan "'..index..'" does not exist'})
    else
       return {instances=insts}
    end
end

v.has_instance = function(index)
    local status, result = pcall(v.get, index)
    if status and vxlanCount then
        for k,v in pairs(result) do
            return true
        end
    end
    return false
end

v.delete = function(index)
    if not v.has_instance(index) then error({code =404, msg="Not Found", detail='Vxlan "'..index..'" does not exist'}) end
    vsh.run("config t ; no bridge-domain "..index)
end

v.create = function(index)
    if v.has_instance(index) then error('Vxlan "'..index..'" already exists') end
    v.set(index)
end


v.set = function(index)
    if v.has_instance(index) then
        vxlanExist=true
    else
        vxlanExist=false
    end
    local cmd = 'config t ; '
    cmd = cmd .. 'bridge-domain '..index..' '..' ;'
    local tmpCmd = cmd
    logger(cmd)
    local status, err = pcall(vsh.run, cmd)
    if not status then
       logger("Failed to configure vxlan "..index.."\n"..err.stdout.."")
       error({code =404, msg="Invalid", detail='Failed to configure Vxlan "'..index..'" \nProvide valid Vxlan Bridge-domain name'})
    end
    if request.group then
        if request.group == NULL then
            cmd = tmpCmd .. 'no group ;'
        else 
            cmd = tmpCmd .. 'group '..request.group..' ;'
        end
    end
    local status, err = pcall(vsh.run, cmd)
    if not status then
       if not vxlanExist then
           v.delete(index)
       end
       logger("Failed to configure vxlan group for vxlan "..index.."\n")
       error({code =404, msg="Invalid", detail='Failed to configure Vxlan group for vxlan "'..index..'" \nProvide valid multicast group A.B.C.D'})
    end

    if request.id then
        if request.id == NULL then
            cmd = tmpCmd .. 'no segment id ;'
        else 
            cmd = tmpCmd .. 'segment id '..request.id..' ;'
        end
    end
    local status, err = pcall(vsh.run, cmd)
    if not status then
       if not vxlanExist then
           v.delete(index)
       end
       logger("Failed to configure vxlan segment id for vxlan "..index.."\n")
       error({code =404, msg="Invalid", detail='Failed to configure Vxlan segment id for vxlan "'..index..'"\nProvide valid value <4096-16000000>'})
    end
     
    if request.mode then
       cmd = tmpCmd .. 'segment mode '..request.mode..' ;'
    end
    local status, err = pcall(vsh.run, cmd)
    if not status then
       if not vxlanExist then
           v.delete(index)
       end
       logger("Failed to configure vxlan segment mode for vxlan "..index.."\n")
       error({code =404, msg="Invalid", detail='Failed to configure Vxlan segment mode for vxlan "'..index..'"\nProvide valid value "unicast-only"'})
    end
--    cmd = ' copy r s'
--    local status, err = pcall(vsh.run, cmd)
--    if not status then
--       if not vExist then
--          v.delete(index)
--       end
--       logger("Failed to copy r s \n"..err.stdout.."")
--       error({code =404, msg="Invalid", detail='Failed to do copy r s'})
--    end
end

return {vxlan=v}


