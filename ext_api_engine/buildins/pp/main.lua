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
local vExist = flase
local flags = {}
local capability = ""

sc.startElement =  function (en)
    capability = ""
    if en == "profile_name" then
        flags.newInstance = true
        flags.name = true
        capability = ""
    elseif en == "type" and flags.newInstance then
        flags.type = true
    elseif en == "desc" and flags.newInstance then
        flags.desc = true
    elseif en == "portgrp" and flags.newInstance then
        flags.portGroup = true
    elseif en == "min_ports" and flags.newInstance then
        flags.minPorts = true
    elseif en == "max_ports" and flags.newInstance then
        flags.maxPorts = true
    elseif en == "port_binding" and flags.newInstance then
        flags.portBinding = true
    elseif en == "status" and flags.newInstance then
        flags.state = true
    elseif en == "cap_l3" and flags.newInstance then
        flags.l3Control = true 
    elseif en == "cap_iscsi" and flags.newInstance then
        flags.iscsiMultipath = true 
    elseif en == "cap_vxlan" and flags.newInstance then
        flags.vxlan = true 
    elseif en == "cap_l3vnservice" and flags.newInstance then
        flags.l3vservice = true 
    elseif en == "profile_cfg" and flags.newInstance then
        flags.cfg = true
    elseif en == "inherit" and flags.newInstance then
        flags.inherit = true
    end
end



sc.endElement =  function (en)
    if en == "port_binding" then
        flags.newInstance = nil
    elseif en == "profile_name" and flags.newInstance then
        flags.name = nil
    elseif en == "type" and flags.newInstance then
        flags.type = nil
    elseif en == "desc" and flags.newInstance then
        flags.desc = nil
    elseif en == "portgrp" and flags.newInstance then
        flags.portGroup = nil
    elseif en == "min_ports" and flags.newInstance then
        flags.minPorts = nil
    elseif en == "max_ports" and flags.newInstance then
        flags.maxPorts = nil
    elseif en == "port_binding" and flags.newInstance then
        flags.portBinding = nil
    elseif en == "status" and flags.newInstance then
        flags.state = nil
    elseif en == "cap_l3" and flags.newInstance then
        flags.l3Control = nil 
    elseif en == "cap_iscsi" and flags.newInstance then
        flags.iscsiMultipath = nil 
    elseif en == "cap_vxlan" and flags.newInstance then
        flags.vxlan = nil 
    elseif en == "cap_l3vnservice" and flags.newInstance then
        flags.l3vservice = nil 
    elseif en == "profile_cfg" and flags.newInstance then
        flags.cfg = nil
    elseif en == "inherit" and flags.newInstance then
        flags.inherit = nil
    end

end



sc.characters =  function (v)
    if flags.name then
        if flags.newInstance then
            flags.key = v
            insts[v] = {}
            insts[v].properties= {name=v}
        end
    end
    if flags.type and flags.newInstance then
        insts[flags.key].properties.type = v
    end
    if flags.desc and flags.newInstance then
        insts[flags.key].properties.description = v
    end
    if flags.portGroup and flags.newInstance then
        insts[flags.key].properties.portGroupName = v
    end
    if flags.inherit and flags.newInstance then
        if v ~= "data_empty" then
            insts[flags.key].properties.inherit = v
        end
    end
    if flags.minPorts and flags.newInstance then
        insts[flags.key].properties.minPorts = tonumber(v)
    end
    if flags.maxPorts and flags.newInstance then
        insts[flags.key].properties.maxPorts = tonumber(v)
    end
    if flags.state and flags.newInstance then
        if v == "1" then
            insts[flags.key].properties.state = true
        else
            insts[flags.key].properties.state = false
        end
    end
    if flags.l3Control and flags.newInstance then
        if v == "yes" then
            capability = "l3control"
        end
    end
    if flags.iscsiMultipath and flags.newInstance then
        if v == "yes" then
            capability = "iscsi-multipath"
        end
    end
    if flags.vxlan and flags.newInstance then
        if v == "yes" then
            capability = "vxlan"
        end
    end
    if flags.l3vservice and flags.newInstance then
        if v == "yes" then
            capability = "l3-vservice"
        end
    end
    if flags.portBinding and flags.newInstance then
        insts[flags.key].properties.portBinding = v
    end
    if flags.cfg and flags.newInstance then
        if v == "shutdown" then
            insts[flags.key].properties.shutdown = true
        elseif v == "no shutdown" then
            insts[flags.key].properties.shutdown = false
        elseif string.match(v, "org ") then  
            insts[flags.key].properties.org = string.match(v, "org (%S+)")
        elseif string.match(v, "mtu ") then  
            insts[flags.key].properties.mtu = string.match(v, "mtu (%S+)")
        elseif string.match(v, "switchport mode ") then  
            insts[flags.key].properties.switchportMode = string.match(v, "switchport mode (%S+)")
        elseif string.match(v, "switchport access vlan ") then  
            insts[flags.key].properties.switchportAccessVLAN = tonumber(string.match(v, "switchport access vlan (%S+)"))
        elseif string.match(v, "switchport trunk native vlan ") then  
            insts[flags.key].properties.switchportTrunkNativeVLAN = tonumber(string.match(v, "switchport trunk native vlan (%S+)"))
        elseif string.match(v, "switchport trunk allowed vlan ") then  
            if insts[flags.key].properties.switchportTrunkVLANs == nil then insts[flags.key].properties.switchportTrunkVLANs = {} end
            t=string.match(v, "switchport trunk allowed vlan (%S+)")
            t=mysplit(t, ",")
            for k,v in pairs(t) do
                print(v)
                if string.match(v, "-") then
                    a = mysplit(v,"-")
                    starting = tonumber(a[1])
                    ending = tonumber(a[2])
                    for i in range(starting,ending) do
                        logger("VLAN : '"..i.."'")
                        table.insert(insts[flags.key].properties.switchportTrunkVLANs,tonumber(i))
                    end
                else 
                    logger("VLAN : '"..v.."'")
                    table.insert(insts[flags.key].properties.switchportTrunkVLANs,tonumber(v))
                end
            end
            --table.insert(insts[flags.key].properties.switchportTrunkVLANs,string.match(v, "switchport trunk allowed vlan (%S+)"))
        elseif string.match(v, "switchport access bridge%-domain ") then  
            insts[flags.key].properties.switchportAccessBridgeDomain = string.match(v, "switchport access bridge%-domain (%S+)")
        elseif string.match(v, "vservice path ") then  
            insts[flags.key].properties.vservicePath = string.match(v, "vservice path (%S+)")
        elseif string.match(v, "vservice node ") then  
            insts[flags.key].properties.vserviceNodeName = string.match(v, "vservice node (%S+)")
            if string.match(v, "vservice node .* profile") then  
                insts[flags.key].properties.vserviceProfile = string.match(v, "vservice node %S+ profile (%S+)")
            end
        else
            if insts[flags.key].properties.profileConfig == nil then insts[flags.key].properties.profileConfig = {} end
            table.insert(insts[flags.key].properties.profileConfig,v)
        end
    end
    if (flags.l3Control or flags.iscsiMultipath or flags.vxlan or flags.l3vservice) and flags.newInstance then
        if insts[flags.key].properties.capability == nil then insts[flags.key].properties.capability = {} end
        if capability ~= "" then 
            table.insert(insts[flags.key].properties.capability,(capability))
        end
    end

end


v.enum = function()
    local xml = vsh.run("show port-profile | xml")
    sax.parse(xml,sc)
    return {instances=insts}
end


v.get = function(index)
    local xml = vsh.run("show port-profile name "..index.. " | xml")
    sax.parse(xml,sc)
    if next(insts)==nil then
       error({code =404, msg="Not Found", detail='pp "'..index..'" does not exist'})
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
    if not v.has_instance(index) then error({code =404, msg="Not Found", detail='pp "'..index..'" does not exist'}) end
    vsh.run("config t ; no port-profile "..index)
end

v.create = function(index)
    if v.has_instance(index) then error('pp "'..index..'" already exists') end
    v.set(index)
end




v.set = function(index)
    if v.has_instance(index) then
        vExist=true
    else
        vExist=false
    end
    local cmd = 'config t ; '
    cmd = cmd .. 'port-profile'
    if request.type then
    if vExist then
       logger("Changing type of an existing  profile is not allowed for pp "..index.."\n")
       error({code =404, msg="Invalid", detail='Failed to configure pp "'..index..'" \nChanging type of an existing  profile is not allowed'})
    else
        cmd = cmd..' type '..request.type..''
    end
    end
    cmd = cmd ..' '..index..' ;'
    local tmpCmd = cmd
    local status, err = pcall(vsh.run, cmd)
    if not status then
       logger("Failed to configure pp "..index.."\n")
       error({code =404, msg="Invalid", detail='Failed to configure pp "'..index..'" \nProvide valid name and type(ethernet/vethernet) '})
    end

    if request.description then
        if request.description == NULL then
            cmd = tmpCmd .. 'no description '
        else 
            cmd = tmpCmd .. 'description '..request.description..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure description for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure description for port-profile"'..index..'"'})
        end
    end
    if request.state == true or request.state == false then
        if request.state == true then
            cmd = tmpCmd .. ' state enabled '
        else
            cmd = tmpCmd .. 'no state enabled '
        end 
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure state  for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure state for port-profile"'..index..'"'})
        end
    end
    if request.shutdown == true or request.shutdown == false then
        if request.shutdown == true then
            cmd = tmpCmd .. ' shutdown '
        else
            cmd = tmpCmd .. 'no shutdown '
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure shutdown state  for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure shutdown state for port-profile"'..index..'"'})
        end
    end

    if request.profileConfig then
        for i=1,table.getn(request.profileConfig) do
            cmd = tmpCmd .. request.profileConfig[i] ..' ;'
            local status, err = pcall(vsh.run, cmd)
            if not status then
                if not vExist then
                    v.delete(index)
                end
                logger("Failed to configure shutdown state  for port-profile"..index.."\n"..err.stdout.."")
                error({code =404, msg="Invalid", detail='Failed to configure shutdown state for port-profile"'..index..'"'})
            end
        end

    end

    if request.portGroupName then
        if request.portGroupName == NULL then
            cmd = tmpCmd .. ' no vmware port-group '
        else
            cmd = tmpCmd .. ' vmware port-group '..request.portGroupName..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure port group name for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure port group name for port-profile"'..index..'"'})
        end
    end


    if request.minPorts then
        if request.minPorts == NULL then
            cmd = tmpCmd .. 'no min-ports '
        elseif (request.minPorts < 1 or request.minPorts > 1024) then
           logger(request.minPorts)
           logger("Failed to configure pp "..index.."\n")
           error({code =404, msg="Invalid", detail='Failed to configure pp "'..index..'" \nProvide valid min-ports value <1-1024> '})
        else
            cmd = tmpCmd .. 'min-ports '..request.minPorts..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure min-ports for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure min-ports for port-profile"'..index..'"'})
        end
    end

    if request.maxPorts then
        if request.maxPorts == NULL then
            cmd = tmpCmd .. 'no max-ports '
        elseif (request.maxPorts < 1 or request.maxPorts > 1024) then
           logger("Failed to configure pp "..index.."\n")
           error({code =404, msg="Invalid", detail='Failed to configure pp "'..index..'" \nProvide valid max-ports value <1-1024> '})
        else
            cmd = tmpCmd .. 'max-ports '..request.maxPorts..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure max-ports for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure max-ports for port-profile"'..index..'"'})
        end
    end


    if request.switchportMode then
        if request.switchportMode == NULL then
            cmd = tmpCmd .. ' no switchport mode '
        elseif  (request.switchportMode ~= "trunk" and  request.switchportMode ~= "access") then
            error({code =404, msg="Invalid", detail='Invalid mode "'..request.switchportMode..'"\nValid modes can be "trunk" or "access"'})
        else
            cmd = tmpCmd .. '  switchport mode '..request.switchportMode..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure port mode for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure port mode for port-profile"'..index..'"'})
        end
    end

    if request.portBinding then
        if request.portBinding == NULL then
            cmd = tmpCmd .. ' no port-binding ' 
        elseif  (request.portBinding ~= "static" and  request.portBinding ~= "static auto" and request.portBinding ~= "dynamic" and  request.portBinding ~= "dynamic auto" and request.portBinding ~= "ephemeral") then
            error({code =404, msg="Invalid", detail='Invalid mode "'..request.portBinding..'"\nValid port binding can be one of these: "static, static auto, dynamic, dynamic auto, ephemeral"'})
        else
            cmd = tmpCmd .. ' port-binding '..request.portBinding..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure port-binding for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure port-binding for port-profile"'..index..'"'})
        end
    end


    if request.switchportTrunkVLANs then
        if request.switchportTrunkVLANs == NULL then  
            cmd = tmpCmd .. ' no switchport trunk allowed vlan '
        else
            local vlan = ""
            local vcount  = 0
            for i=1,table.getn(request.switchportTrunkVLANs) do
                if  (request.switchportTrunkVLANs[i]  < 1 and  request.switchportTrunkVLANs[i]  > 4094) then
                    error({code =404, msg="Invalid", detail='Invalid vlan "'..request.switchportTrunkVLANs[i]..'"\nValid vlans can be <1-4094>'}) 
                end
                if  vcount > 0 then 
                   vlan = vlan..", "..request.switchportTrunkVLANs[i].."" 
                else 
                   vlan = vlan..request.switchportTrunkVLANs[i]
                end
                vcount = 1
            end
            if not vcount then
                logger("Failed to configure switch port trunk vlans for port-profile"..index)
                error({code =404, msg="Invalid", detail='Failed to configure switch port trunk vlans for port-profile "'..index..'"'..'\n no vlans provided, please provide atleast one vlan'})
            end
            cmd = tmpCmd .. '  switchport trunk allowed vlan '..vlan..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure switch port  trunk vlans for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure switch port trunk vlans for port-profile"'..index..'"'})
        end
    end


    if request.switchportTrunkNativeVLAN then
        if request.switchportTrunkNativeVLAN == NULL then
            cmd = tmpCmd .. ' no switchport  trunk native vlan '
        elseif  (request.switchportTrunkNativeVLAN  < 1 and  request.switchportTrunkNativeVLAN  > 4094) then
            error({code =404, msg="Invalid", detail='Invalid vlan "'..request.switchportTrunkNativeVLAN ..'"\nValid vlans can be '}) 
        else
            cmd = tmpCmd .. '  switchport  trunk native vlan '..request.switchportTrunkNativeVLAN ..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure native vlan for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure native vlan for port-profile"'..index..'"'})
        end
    end

    if request.switchportAccessVLAN then
        if request.switchportAccessVLAN == NULL then
            cmd = tmpCmd .. ' no switchport access vlan '
        elseif  (request.switchportAccessVLAN < 1 and  request.switchportAccessVLAN > 4094) then
            error({code =404, msg="Invalid", detail='Invalid vlan "'..request.switchportAccessVLAN  ..'"\nValid vlans can be '}) 
        else
            cmd = tmpCmd .. ' switchport access vlan '..request.switchportAccessVLAN  ..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure access vlan for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure access vlan for port-profile"'..index..'"'})
        end
    end

    if request.switchportAccessBridgeDomain then
        if request.switchportAccessBridgeDomain == NULL then
            cmd = tmpCmd .. ' no switchport access bridge-domain '
        else
            cmd = tmpCmd .. ' switchport access bridge-domain '..request.switchportAccessBridgeDomain  ..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure access bridge-domain for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure access bridge-domain for port-profile"'..index..'"'})
        end
    end

    if request.mtu then
        if request.mtu == NULL then
            cmd = tmpCmd .. ' no mtu '
        elseif (request.mtu < 1500 or request.mtu > 9000) then
           logger("Failed to configure pp "..index.."\n")
           error({code =404, msg="Invalid", detail='Failed to configure pp "'..index..'" \nProvide valid mtu value <1500-9000>'})
        else
            cmd = tmpCmd .. ' mtu '..request.mtu..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure mtu for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure mtu for port-profile"'..index..'"'})
        end
    end

    if request.org then
        if request.org == NULL then
            cmd = tmpCmd .. ' no org '
        else
            cmd = tmpCmd .. ' org '..request.org..''
        end
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure org name for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure org name for port-profile"'..index..'"'})
        end
    end

    if request.vservicePath then
        cmd = tmpCmd .. ' vservice path '..request.vservicePath..''
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure vservicePath  for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure vservicePath for port-profile"'..index..'"'})
        end
    end

    if request.vserviceNodeName then
        cmd = tmpCmd .. ' vservice node '..request.vserviceNodeName..''
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure vserviceNodeName  for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure vserviceNodeName for port-profile"'..index..'"'})
        end
    end

    if request.vserviceProfile then
        if not request.vserviceNodeName then
            logger("Failed to configure vserviceProfile  for port-profile"..index)
            error({code =404, msg="Invalid", detail='Failed to configure vserviceProfile for port-profile"'..index..'"\nvserviceNodeName not provided, please privide vserviceNodeName along with profile'})
        end
        cmd = tmpCmd .. ' vservice node '..request.vserviceNodeName..' profile '..request.vserviceProfile..''
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure vserviceProfile  for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure vserviceProfile for port-profile"'..index..'"'})
        end
    end

    if request.capability then
        for i=1,table.getn(request.capability) do
            if  (request.capability[i] ~= "l3control" and  request.capability[i] ~= "l3-vservice" and request.capability[i] ~= "multi-mac" and  request.capability[i] ~= "vxlan") then
                error({code =404, msg="Invalid", detail='Invalid mode "'..request.capability[i]..'"\nValid capability can be one of these: "l3control, l3-vservice, multi-mac, vxlan"'})
            end

            cmd = tmpCmd .. ' capability '..request.capability[i]..''
            local status, err = pcall(vsh.run, cmd)
            if not status then
                if not vExist then
                    v.delete(index)
                end
                logger("Failed to configure capability for port-profile"..index.."\n"..err.stdout.."")
                error({code =404, msg="Invalid", detail='Failed to configure capability for port-profile"'..index..'"'})
            end
        end
    end

--    cmd = ' copy r s'
--    local status, err = pcall(vsh.run, cmd)
--    if not status then
--       if not vExist then
--          v.delete(index)
--       end
--       logger("Failed to do copy r s\n"..err.stdout.."")
--       error({code =404, msg="Invalid", detail='Failed to do copy r s'})
--    end
end

function mysplit(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end
function range(from , to)
    return function (_,last)
            if last >= to then return nil
            else return last+1
            end
        end , nil , from-1
end

return {pp=v}



