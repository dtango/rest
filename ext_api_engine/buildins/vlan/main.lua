--
-- Created by IntelliJ IDEA.
-- User: jasonxu
-- Date: 7/4/13
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
vlanExist = flase
local flags = {}

sc.startElement =  function (en)
    if en == "ROW_vlanbrief" then
        flags.newInstance = true
    elseif en == "ROW_vlanbriefid" then
        flags.newInstance = true
    elseif en == "vlanshowbr-vlanid" and flags.newInstance then
        flags.id = true
    elseif en == "vlanshowbr-vlanname" and flags.newInstance then
        flags.name = true
    elseif en == "vlanshowbr-vlanstate" and flags.newInstance then
        flags.state = true
    elseif en == "vlanshowbr-shutstate" and flags.newInstance then
        flags.shutdown = true
    end
end

sc.endElement =  function (en)
    if en == "ROW_vlanbrief" then
        flags.newInstance = nil
    elseif en == "ROW_vlanbriefid" then
        flags.newInstance = nil
    elseif en == "vlanshowbr-vlanid" and flags.newInstance then
        flags.id = nil
    elseif en == "vlanshowbr-vlanname" and flags.newInstance then
        flags.name = nil
    elseif en == "vlanshowbr-vlanstate" and flags.newInstance then
        flags.state = nil
    elseif en == "vlanshowbr-shutstate" and flags.newInstance then
        flags.shutdown = nil
    end
end

sc.characters =  function (v)
    if flags.id then
        if flags.newInstance then
            flags.key = v
            insts[v] = {}
            insts[v].properties= {id=tonumber(v)}
        end
    end
    if flags.name and flags.newInstance then
        insts[flags.key].properties.name = v
    end
    if flags.state and flags.newInstance then
        insts[flags.key].properties.state = v
    end
    if flags.shutdown and flags.newInstance then
        if v == "shutdown" then
            insts[flags.key].properties.shutdown = true
        else 
            insts[flags.key].properties.shutdown = false
        end
    end

end

v.enum = function()
    local xml = vsh.run("show vlan | xml")
    sax.parse(xml,sc)
    return {instances=insts}
end

v.get = function(index)
    local xml = vsh.run("show vlan id "..index.. " | xml")
    sax.parse(xml,sc)
    if next(insts)==nil then
       error({code =404, msg="Not Found", detail='Vlan "'..index..'" does not exist'}) 
    else
       return {instances=insts}
    end
end

v.has_instance = function(index)
    local status, result = pcall(v.get, index)
    if status then
        for k,v in pairs(result) do
            return true
        end
    end
    return false
end

v.delete = function(index)
    if not v.has_instance(index) then error({code =404, msg="Not Found", detail='Vlan "'..index..'" does not exist'}) end
    vsh.run("config t ; no vlan "..index)
end

v.create = function(index)
    if not (tonumber(index) >= 1 and tonumber(index) <= 4093) then
        error({code =404, msg="Invalid", detail='Vlan id-> "'..index..'" out of range Vlan->id should be <1-3967,4048-4093>'})
    end
    if v.has_instance(index) then error('Vlan "'..index..'" already exists') end
    v.set(index)
end 

v.serialize = function(t)
  local serializedValues = {}
  local value, serializedValue
  for i=1,#t do
    value = t[i]
    serializedValue = type(value)=='table' and serialize(value) or value
    table.insert(serializedValues, serializedValue)
  end
  return string.format("{ %s }", table.concat(serializedValues, ', ') )
end

v.set = function(index)
    if v.has_instance(index) then 
        vlanExist=true 
    else 
        vlanExist=false 
    end
    local cmd = 'config t ; '
    cmd = cmd .. 'vlan '..index..' '..' ;'
    logger(cmd)
    local status, err = pcall(vsh.run, cmd)
    if not status then
       logger("Failed to configure vlan "..index.."\n"..err.stdout.."")
       error({code =404, msg="Invalid", detail='Failed to configure Vlan "'..index..'"'})
    end

    if request.name then
        if request.name == NULL then
            cmd = cmd .. 'no name ;'
        else
            cmd = cmd .. 'name '..request.name..' ;'
        end
    end
    local status, err = pcall(vsh.run, cmd)
    if not status then
       if not vlanExist then
           v.delete(index)
       end
       logger("Failed to configure vlan name for vlan "..index.."\n"..err.stdout.."")
       error({code =404, msg="Invalid", detail='Failed to configure Vlan name for vlan "'..index..'"'})
    end

    if request.state then
        if  (request.state ~= "active" and  request.state ~= "suspend") then
            if not vlanExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid state "'..request.state..'"\nValid state can be "active" or "suspend"'})
        end
        if request.state == NULL then
            cmd = cmd .. 'no state ;'
        else
            cmd = cmd .. 'state '..request.state..' ;'
        end
    end
    if request.shutdown then
        cmd = cmd .. 'shutdown'..' ;'
    else
        cmd = cmd .. 'no shutdown'..' ;'
    end

    logger(cmd)
    local status, err = pcall(vsh.run, cmd)
    if not status then
       if not vlanExist then
           v.delete(index)
       end
       logger("Faiiled to configure\n"..cmd.."")
       error("Failed to configure\n"..cmd.."")
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

--if platform == "hyperv" then
--    return {vlan={enum=v.enum,get=v.get} }
--else
    return {vlan=v}
--end

