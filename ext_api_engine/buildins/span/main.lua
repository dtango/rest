-- Created by IntelliJ IDEA.
-- User: skolar
-- Date: 6/20/13
-- Time: 1:41 PM
-- To change this template use File | Settings | File Templates.
--

local vsh = require("vsh")
local sax = require("sax")

local insts = {}
local props = {}
local typeExist = false

local v = {}

local sc = {}
local vExist = flase
local flags = {}
local capability = ""
local sCount = 1
sourceVethRx = {}
sourceVethTx = {}
sourceVethBoth = {}
sourceEthRx = {}
sourceEthTx = {}
sourceEthBoth = {}
sourcePcRx = {}
sourcePcTx = {}
sourcePcBoth = {}
sourcePpRx = {}
sourcePpTx = {}
sourcePpBoth = {}
sourceVlanRx = {}
sourceVlanTx = {}
sourceVlanBoth = {}

sc.startElement =  function (en)
    if en == "ROW_session" then
        flags.newInstance = true
    elseif en == "session_number" and flags.newInstance then
        flags.id = true
    elseif en == "type" and flags.newInstance then
        flags.type = true
        typeExist = true
    elseif en == "description" and flags.newInstance then
        flags.desc = true
    elseif en == "state" and flags.newInstance then
        flags.state = true
    elseif (en == "sources_rx" or en == "source_vlans_rx" or en == "src_pp_rx")  and flags.newInstance then
        flags.sourcesRx = true
    elseif (en == "sources_tx" or en == "source_vlans_tx" or en == "src_pp_tx")  and flags.newInstance then
        flags.sourcesTx = true
    elseif (en == "sources_both" or en == "source_vlans_both" or en == "src_pp_both")  and flags.newInstance then
       flags.sourcesBoth = true
    elseif en == "filter_vlans" and flags.newInstance then
        flags.filterVlans = true
    elseif en == "destinations" and flags.newInstance then
        flags.destinations = true
    elseif en == "dst_pp_list" and flags.newInstance then
        flags.destPortProfile = true
    elseif en == "dst_ip" and flags.newInstance then
        flags.destIpAddr = true
    elseif en == "flow_id" and flags.newInstance then
        flags.erSpanId = true
    elseif en == "erspan_hdrver" and flags.newInstance then
        flags.headerType = true
    elseif en == "erspan_dscp" and flags.newInstance then
        flags.dscp = true
    elseif en == "erspan_ttl" and flags.newInstance then
        flags.ttl = true
    elseif en == "erspan_mtu" and flags.newInstance then
        flags.mtu = true
    elseif en == "erspan_ipp" and flags.newInstance then
        flags.prec = true
    end
end



sc.endElement =  function (en)
    if en == "ROW_session" then
        flags.newInstance = nil
        finalStruct()
    elseif en == "session_number" and flags.newInstance then
        flags.id = nil
    elseif en == "type" and flags.newInstance then
        flags.type = nil
    elseif en == "description" and flags.newInstance then
        flags.desc = nil
    elseif en == "state" and flags.newInstance then
        flags.state = nil
    elseif (en == "sources_rx" or en == "source_vlans_rx" or en == "src_pp_rx")  and flags.newInstance then
        flags.sourcesRx = nil
    elseif (en == "sources_tx" or en == "source_vlans_tx" or en == "src_pp_tx")  and flags.newInstance then
        flags.sourcesTx = nil
    elseif (en == "sources_both" or en == "source_vlans_both" or en == "src_pp_both")  and flags.newInstance then
        flags.sourcesBoth = nil
    elseif en == "filter_vlans" and flags.newInstance then
        flags.filterVlans = nil
    elseif en == "destinations" and flags.newInstance then
        flags.destinations = nil
    elseif en == "dst_pp_list" and flags.newInstance then
        flags.destPortProfile = nil
    elseif en == "dst_ip" and flags.newInstance then
        flags.destIpAddr = nil
    elseif en == "flow_id" and flags.newInstance then
        flags.erSpanId = nil
    elseif en == "erspan_hdrver" and flags.newInstance then
        flags.headerType = nil
    elseif en == "erspan_dscp" and flags.newInstance then
        flags.dscp = nil
    elseif en == "erspan_ttl" and flags.newInstance then
        flags.ttl = nil
    elseif en == "erspan_mtu" and flags.newInstance then
        flags.mtu = nil
    elseif en == "erspan_ipp" and flags.newInstance then
        flags.prec = nil
    end
end

local serialize = function(t)
  local serializedValues = {}
  local value, serializedValue
  for i=1,#t do
    value = t[i]
    serializedValue = type(value)=='table' and serialize(value) or value
    table.insert(serializedValues, serializedValue)
  end
  return string.format("{ %s }", table.concat(serializedValues, ', ') )
end


sc.characters =  function (v)
    if flags.id then
        if flags.newInstance then
            flags.key = v
            insts[v] = {}
            insts[v].properties= {id=tonumber(v)}
            insts[flags.key].properties.type = {}
        end
    end
    if flags.type and flags.newInstance then
        insts[flags.key].properties.type = v
    end
    if flags.desc and flags.newInstance then
        insts[flags.key].properties.description = v
    end
    if flags.destIpAddr and flags.newInstance then
        insts[flags.key].properties.destIpAddr = v
    end
    if flags.erSpanId and flags.newInstance then
        insts[flags.key].properties.erSpanId = tonumber(v)
    end
    if flags.headerType and flags.newInstance then
        insts[flags.key].properties.headerType = tonumber(v)
    end
    if flags.dscp and flags.newInstance then
        insts[flags.key].properties.dscp = tonumber(v)
    end
    if flags.ttl and flags.newInstance then
        insts[flags.key].properties.ttl = tonumber(v)
    end
    if flags.mtu and flags.newInstance then
        insts[flags.key].properties.mtu = tonumber(v)
    end
    if flags.prec and flags.newInstance then
        insts[flags.key].properties.prec = tonumber(v)
    end
    if flags.filterVlans and flags.newInstance then
        if insts[flags.key].properties.filterVlans == nil then
            insts[flags.key].properties.filterVlans = {} 
        end
        t=mysplit(v, ",")
        for k,v in pairs(t) do
            print(v)
            if string.match(v, "-") then
                a = mysplit(v,"-")
                starting = tonumber(a[1])
                ending = tonumber(a[2])
                for i in range(starting,ending) do
                    table.insert(insts[flags.key].properties.filterVlans,tonumber(i))
                end
            else
                table.insert(insts[flags.key].properties.filterVlans,tonumber(v))
            end
        end
    end
    if flags.state and flags.newInstance then
        if v == "down" then
            insts[flags.key].properties.shutdown = true
        else
            insts[flags.key].properties.shutdown = false
        end
    end
    if flags.destinations and flags.newInstance then
        t = string.lower(v)
        dest = string.match(v, "%d+.*")
        if string.match(t, "vethernet") then
            if insts[flags.key].properties.destVethIfs == nil then
                insts[flags.key].properties.destVethIfs = {}                 
            end
            table.insert(insts[flags.key].properties.destVethIfs, tonumber(dest))
        elseif string.match(t, "port%-channel") then
            if insts[flags.key].properties.destPortChannels == nil then
                insts[flags.key].properties.destPortChannels = {}                 
            end
            table.insert(insts[flags.key].properties.destPortChannels, dest)
        elseif string.match(t, "^ethernet") then
            if insts[flags.key].properties.destEthIfs == nil then
                insts[flags.key].properties.destEthIfs = {}                 
            end
            table.insert(insts[flags.key].properties.destEthIfs, dest)
        end
    end

    if flags.destPortProfile and flags.newInstance then
        if insts[flags.key].properties.destPortProfile == nil then
           insts[flags.key].properties.destPortProfile = {}                 
        end 
        table.insert(insts[flags.key].properties.destPortProfile,v)
    end

    if flags.sourcesRx and flags.newInstance then
        if v ~= {} then
        logger(v)
        end
        
        t = string.lower(v)
        if insts[flags.key].properties.sources == nil then
            insts[flags.key].properties.sources = {}                
        end
        source = string.match(v, "%d+.*")  --sanjay, this is not right,t_source.source is an array of string
        if string.match(t, "vethernet") then
            if sourceVethRx == nil then
                sourceVethRx = {}                
            end
            table.insert(sourceVethRx, source)
        elseif string.match(t, "port%-channel") then
            if sourcePcRx == nil then
                sourcePcRx = {}                
            end
            table.insert(sourcePcRx, source)
        elseif string.match(t, "ethernet") then
            if sourceEthRx == nil then
                sourceEthRx = {}                
            end
            table.insert(sourceEthRx, source)
        elseif string.match(t, "^%d+.*") then
            if sourceVlanRx == nil then
                sourceVlanRx = {}                
            end
            t=mysplit(source, ",")
            for k,v in pairs(t) do
                if string.match(v, "-") then
                    a = mysplit(v,"-")
                    starting = tonumber(a[1])
                    ending = tonumber(a[2])
                    for i in range(starting,ending) do
                        table.insert(sourceVlanRx, i)
                    end
                else
                    table.insert(sourceVlanRx, v)
                end
            end
            --table.insert(sourceVlanRx, source)
        else
            if sourcePpRx == nil then
                sourcePpRx = {}                
            end
            table.insert(sourcePpRx, v)
        end
        --local src = {}
        --table.insert(src, source)
        --table.insert(insts[flags.key].properties.sources,{type=types, direction=direction, source= src })
    end


    if flags.sourcesTx and flags.newInstance then
        t = string.lower(v)
        if insts[flags.key].properties.sources == nil then
            insts[flags.key].properties.sources = {}                
        end
        source = string.match(v, "%d+.*")  --sanjay, this is not right,t_source.source is an array of string
        if string.match(t, "vethernet") then
            if sourceVethTx == nil then
                sourceVethTx = {}                
            end
            table.insert(sourceVethTx, source)
        elseif string.match(t, "port%-channel") then
            if sourcePcTx == nil then
                sourcePcTx = {}                
            end
            table.insert(sourcePcTx, source)
        elseif string.match(t, "ethernet") then
            if sourceEthTx == nil then
                sourceEthTx = {}                
            end
            table.insert(sourceEthTx, source)
        elseif string.match(t, "^%d+.*") then
            if sourceVlanTx == nil then
                sourceVlanTx = {}                
            end
            table.insert(sourceVlanTx, source)
        else
            if sourcePpTx == nil then
                sourcePpTx = {}                
            end
            source = string.match(v, ".*")
            table.insert(sourcePpTx, source)
        end
        --local src = {}
        --table.insert(src, source)
        --table.insert(insts[flags.key].properties.sources,{type=types, direction=direction, source= src })
    end


    if flags.sourcesBoth and flags.newInstance then
        t = string.lower(v)
        if insts[flags.key].properties.sources == nil then
            insts[flags.key].properties.sources = {}                
        end
        source = string.match(v, "%d+.*")  --sanjay, this is not right,t_source.source is an array of string
        if string.match(t, "vethernet") then
            if sourceVethBoth == nil then
                sourceVethBoth = {}                
            end
            table.insert(sourceVethBoth, source)
        elseif string.match(t, "port%-channel") then
            if sourcePcBoth == nil then
                sourcePcBoth = {}                
            end
            table.insert(sourcePcBoth, source)
        elseif string.match(t, "ethernet") then
            if sourceEthBoth == nil then
                sourceEthBoth = {}                
            end
            table.insert(sourceEthBoth, source)
        elseif string.match(t, "^%d+.*") then
            if sourceVlanBoth == nil then
                sourceVlanBoth = {}                
            end
            table.insert(sourceVlanBoth, source)
        else
            if sourcePpBoth == nil then
                sourcePpBoth = {}                
            end
            source = string.match(v, ".*")
            table.insert(sourcePpBoth, source)
        end
        direction = "both"                 
        --source = string.match(v, "%d+.*")
        --local src = {}
        --table.insert(src, source)
        --table.insert(insts[flags.key].properties.sources,{type=types, direction=direction, source= src })
    end
end

function finalStruct()
        if insts[flags.key].properties.sources == nil then
            insts[flags.key].properties.sources = { }                
        end
        if #sourceVethRx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Vethernet", direction="rx", source=sourceVethRx})
        end
        if #sourceEthRx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Ethernet", direction="rx", source=sourceEthRx})
        end
        if #sourceVlanRx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Vlan", direction="rx", source=sourceVlanRx})
        end
        if #sourcePcRx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="port-channel", direction="rx", source=sourcePcRx})
        end
        if #sourcePpRx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="port-profile", direction="rx", source=sourcePpRx})
        end
        if #sourceVethTx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Vethernet", direction="tx", source=sourceVethTx})
        end
        if #sourceEthTx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Ethernet", direction="tx", source=sourceEthTx})
        end
        if #sourceVlanTx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Vlan", direction="tx", source=sourceVlanTx})
        end
        if #sourcePcTx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="port-channel", direction="tx", source=sourcePcTx})
        end
        if #sourcePpTx > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="port-profile", direction="tx", source=sourcePpTx})
        end
        if #sourceVethBoth > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Vethernet", direction="Both", source=sourceVethBoth})
        end
        if #sourceEthBoth > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Ethernet", direction="Both", source=sourceEthBoth})
        end
        if #sourceVlanBoth > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="Vlan", direction="Both", source=sourceVlanBoth})
        end
        if #sourcePcBoth > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="port-channel", direction="Both", source=sourcePcBoth})
        end
        if #sourcePpBoth > 0 then 
            table.insert(insts[flags.key].properties.sources,{type="port-profile", direction="Both", source=sourcePpBoth})
        end
	sourceVethRx = {}
	sourceVethTx = {}
	sourceVethBoth = {}
	sourceEthRx = {}
	sourceEthTx = {}
	sourceEthBoth = {}
	sourcePcRx = {}
	sourcePcTx = {}
	sourcePcBoth = {}
	sourcePpRx = {}
	sourcePpTx = {}
	sourcePpBoth = {}
	sourceVlanRx = {}
	sourceVlanTx = {}
	sourceVlanBoth = {}
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

v.enum = function()
    local xml = vsh.run("show monitor session all | xml")
    sax.parse(xml,sc)
    return {instances=insts}
end


v.get = function(index)
    if tonumber(index) < 1 or tonumber(index) > 64 then
       error({code =404, msg="Not Found", detail='span/erspan monitor session "'..index..'" is not valid (Valid session value will be <1-64>)'})
    end
    local xml = vsh.run("show monitor session "..index.. " | xml")
    sax.parse(xml,sc)
    if typeExist == false or next(insts)==nil then
    --if next(insts)==nil then
       error({code =404, msg="Not Found", detail='span/erspan monitor session "'..index..'" does not exist'})
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
    if not v.has_instance(index) then error({code =404, msg="Not Found", detail='span/erspan monitor session  "'..index..'" does not exist'}) end
    vsh.run("config t ; no monitor session "..index)
end

v.create = function(index)
    if v.has_instance(index) then error('span/erspan monitor session "'..index..'" already exists') end
    v.set(index)
end




v.set = function(index)
    if tonumber(index) < 1 or tonumber(index) > 64 then
       error({code =404, msg="Not Found", detail='span/erspan monitor session "'..index..'" is not valid (Valid session value will be <1-64>)'})
    end
    if v.has_instance(index) then
        vExist=true
    else
        vExist=false
    end
    local cmd = 'config t ; '
    cmd = cmd .. 'monitor session '..index..''

    if request.type then
        if request.type == NULL then
            cmd = cmd..' type '..' local'
        else
            cmd = cmd..' type '..request.type..''
        end
    end

    local cmd = cmd..' ; ' 
    local tmpCmd = cmd 
    logger(cmd)
    local status, err = pcall(vsh.run, cmd)
    if not status then
       logger("Failed to configure monitor session "..index.."\n")
       error({code =404, msg="Invalid", detail='Failed to configure monitor session "'..index..'"\n  Provide valid id and type(local/erspan-source) '})
    end

    if request.description then
        if request.description == NULL then
            cmd = tmpCmd .. 'no description '
        else
            cmd = tmpCmd .. 'description '..request.description..''
        end
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure description for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure description for monitor session "'..index..'"'})
        end
    end
    if request.shutdown == true or request.shutdown == false then
        if request.shutdown == true then
            cmd = tmpCmd .. ' shutdown '
        else
            cmd = tmpCmd .. 'no shutdown '
        end
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure shutdown state  for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure shutdown state for monitor session "'..index..'"'})
        end
    end

    if request.filterVlans then
        local vlan = ""
        local vcount  = 0
        for i=1,table.getn(request.filterVlans) do
            if  (request.filterVlans[i]  < 1 or  request.filterVlans[i]  > 4094) then
                error({code =404, msg="Invalid", detail='Invalid vlan "'..request.filterVlans[i]..'"\nValid vlans can be <1-4094>'})
            end
            if  vcount > 0 then
               vlan = vlan..", "..request.filterVlans[i]..""
            else
               vlan = vlan..request.filterVlans[i]
            end
            vcount = 1
        end
        if not vcount then
            logger("Failed to configure filter vlans for monitor session "..index)
            error({code =404, msg="Invalid", detail='Failed to configure filter valn for monitor session "'..index..'"'..'\n no vlans provided, please provide atleast one vlan'})
        end
        cmd = tmpCmd .. ' filter vlan '..vlan..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure switch port  trunk vlans for port-profile"..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure switch port trunk vlans for port-profile"'..index..'"'})
        end
    end

    if request.destPortChannels then
        local pc = ""
        local pccount  = 0
        for i=1,table.getn(request.destPortChannels) do
            if  pccount > 0 then
               pc = pc..", port-channel "..request.destPortChannels[i]..""
            else
               pc = pc..request.destPortChannels[i]
            end
            pccount = 1
        end
        if not pccount then
            logger("Failed to configure destination port-channel interface for monitor session "..index)
            error({code =404, msg="Invalid", detail='Failed to configure destination port-channel interface for monitor session "'..index..'"'..''})
        end
        cmd = tmpCmd .. ' destination interface port-channel '..pc..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure destination port-channel interface for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure destination port-channel interface for monitor session "'..index..'"'})
        end
    end

    if request.destVethIfs then
        local pc = ""
        local pccount  = 0
        for i=1,table.getn(request.destVethIfs) do
            if  pccount > 0 then
               pc = pc..", vethernet "..request.destVethIfs[i]..""
            else
               pc = pc..request.destVethIfs[i]
            end
            pccount = 1
        end
        if not pccount then
            logger("Failed to configure destination vethernet interface for monitor session "..index)
            error({code =404, msg="Invalid", detail='Failed to configure destination vethernet interface for monitor session "'..index..'"'..''})
        end
        cmd = tmpCmd .. ' destination interface vethernet '..pc..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure destination vethernet interface for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure destination vethernet interface for monitor session "'..index..'"'})
        end
    end


    if request.destEthIfs then
        local pc = ""
        local pccount  = 0
        for i=1,table.getn(request.destEthIfs) do
            if  pccount > 0 then
               pc = pc..", ethernet "..request.destEthIfs[i]..""
            else
               pc = pc..request.destEthIfs[i]
            end
            pccount = 1
        end
        if not pccount then
            logger("Failed to configure destination ethernet interface for monitor session "..index)
            error({code =404, msg="Invalid", detail='Failed to configure destination ethernet interface for monitor session "'..index..'"'..''})
        end
        cmd = tmpCmd .. ' destination interface ethernet '..pc..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure destination ethernet interface for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure destination ethernet interface for monitor session "'..index..'"'})
        end
    end

    if request.destIpAddr then
        cmd = tmpCmd .. 'destination ip '..request.destIpAddr..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure destination Ip Address for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure destination ip address for monitor session "'..index..'"'})
        end
    end

    if request.erSpanId then
        if  (request.erSpanId < 1 or  request.erSpanId  > 1023) then
            if not vExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid erspan-id "'..request.erSpanId..'"\nValid erspan-id can be <1-1023>'})
        end
        cmd = tmpCmd .. 'erspan-id '..request.erSpanId..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure erspan-id for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure erspan-id for monitor session "'..index..'"'})
        end
    end

    if request.headerType then
        if  (request.headerType < 2 or  request.headerType  > 3) then
            if not vExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid header Type "'..request.erSpanId..'"\nValid header Type can be <2-3>'})
        end
        cmd = tmpCmd .. 'header-type '..request.headerType..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure header type for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure header type for monitor session "'..index..'"'})
        end
    end
    if request.dscp then
        if  (request.dscp < 50 or  request.dscp  > 9000) then
            if not vExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid dscp value "'..request.dscp..'"\nValid dscp value can be <50-9000>'})
        end
        cmd = tmpCmd .. 'ip dscp '..request.dscp..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure dscp for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure dscp for monitor session "'..index..'"'})
        end
    end

    if request.prec then
        if  (request.prec < 0 or  request.prec  > 7) then
            if not vExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid prec value "'..request.prec..'"\nValid prec value can be <50-9000>'})
        end
        cmd = tmpCmd .. 'ip prec '..request.prec..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure prec for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure prec for monitor session "'..index..'"'})
        end
    end

    if request.ttl then
        if  (request.ttl < 1 or  request.ttl  > 255) then
            if not vExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid ttl value "'..request.ttl..'"\nValid ttl value can be <1-255>'})
        end
        cmd = tmpCmd .. 'ip ttl '..request.ttl..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure ttl for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure ttl for monitor session "'..index..'"'})
        end
    end

    if request.mtu then
        if  (request.mtu < 50 or  request.ttl  > 9000) then
            if not vExist then
                v.delete(index)
            end
            error({code =404, msg="Invalid", detail='Invalid mtu value "'..request.ttl..'"\nValid mtu value can be <50-9000>'})
        end
        cmd = tmpCmd .. 'mtu '..request.mtu..''
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure mtu for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure mtu for monitor session "'..index..'"'})
        end
    end

    if request.sources then
        cmd = tmpCmd
        for j=1,table.getn(request.sources) do
            pccount = 0
            if  request.sources[j].type then
                if string.match(request.sources[j].type, "ethernet") or string.match(request.sources[j].type, "port%-channel") then
                    cmd = cmd .. 'source interface '..request.sources[j].type..' '
                else
                    cmd = cmd .. 'source '..request.sources[j].type..' ' 
                end
            end
            for i=1,table.getn(request.sources[j].source) do
                if string.match(request.sources[j].type, "ethernet") or string.match(request.sources[j].type, "port%-channel") then
                    if  pccount > 0 then
                        cmd = cmd .. ', '..request.sources[j].type..' '..request.sources[j].source[i]..' '
                    else
                        cmd = cmd .. ' '..request.sources[j].source[i]..' '
                    end
                else
                    if  pccount > 0 then
                        cmd = cmd..', ' ..request.sources[j].source[i]
                    else
                        cmd = cmd..' ' ..request.sources[j].source[i]
                    end
                end
                pccount = 1
            end
            if  request.sources[j].direction then
                cmd = cmd .. ' '..request.sources[j].direction..' ;'
            end
            logger(cmd)
            local status, err = pcall(vsh.run, cmd)
            if not status then
                if not vExist then
                    v.delete(index)
                end
                logger("Failed to configure sources for monitor session "..index.."\n"..err.stdout.."")
                error({code =404, msg="Invalid", detail='Failed to configure sources for monitor session "'..index..'"'})
            end
        end
    end

    if request.config then
        cmd = tmpCmd
        for i=1,table.getn(request.config) do
            cmd = cmd ..''..request.config[i]..' ;'
        end
        logger(cmd)
        local status, err = pcall(vsh.run, cmd)
        if not status then
            if not vExist then
                v.delete(index)
            end
            logger("Failed to configure for monitor session "..index.."\n"..err.stdout.."")
            error({code =404, msg="Invalid", detail='Failed to configure for monitor session "'..index..'"'})
        end
    end
    
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

return {span=v}
