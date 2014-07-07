local _u = require 'utils'

-------------------------------------
-- Convinience functions
-------------------------------------
local const = {
	empty_tag = "", -- to circumvent empty tag treated as nil
}

local function cmd_to_file(cmd)
    -- cmd - is a ';' separated vsh command
    -- return file name ofr command otherwise nil
    if cmd and type(cmd) == 'string' then
        local tmp_f = os.tmpname()
        local f = assert(io.open(tmp_f, 'w'), "Can not open ".. tmp_f)
        local cmd = cmd:gsub(';', '\n') 
        f:write(cmd .. '\n')
        f:close()
        os.execute("chmod +r ".. tmp_f)
        return tmp_f
    end
end

local function _run(cmd, auth)
    -- runs the cmd by vsh -c, if exit value != 0
    -- error will be raised
    -- other wise returns the string (stdout)
    local auth = auth or true
    local stderrf = os.tmpname()
    local rtn = os.tmpname()
    local cmd_file = cmd_to_file(cmd)
    local vshcmd = '/isan/bin/vsh '
    if auth then 
        if ee_auth_token then authtoken = ' -p '..tostring(ee_auth_token)..' ' else authtoken = '' end
        vshcmd = vshcmd .. authtoken
    end    
    vshcmd = vshcmd .. ' -f '..cmd_file..' '..' 2>'..stderrf..' ; echo -n $? > '..rtn
    local f = assert(io.popen(vshcmd), "Cannot open vsh")
    local rv = f:read('*a') .. '/n'
    f:close()
    f = io.open(rtn,"r")
    local s = f:read("*all")
    f:close()
    os.execute("rm -rf ".. _u.join({rtn, stderrf, cmd_file}, " "))
    if tonumber(s) ~= 0 then
        local t_ev = {}
        for ev in rv:gmatch("ERROR: (.-)\n") do table.insert(t_ev, ev) end
        local error_msg = 'Error('..s..'): '.._u.join(t_ev, " AND ")
        logger("vsh command failed: "..vshcmd .. " "..error_msg)
        error({code=500, msg=error_msg})
    end
    return rv
end

local function run(cmd)
    logger("run (" .. cmd .. ")")
    local status, err = pcall(_run, cmd)
    if not status then 
        local errorMsg = " error calling (" .. cmd .. ")"
        logger(" error calling (" .. cmd .. "):" .. err.msg)
        error(err)
    end
    return err
end


local function allow_only_published(table, name, publish, remove_publish)
    -- Filter out records that are not marked for publishing (publish tag will be removed)
    -- table: table of instances
    -- name: name of an instance - default if published but without alias
    -- [optional] publish: in case something else is used instead of <publish> tag
    -- [optional] remove_publish: should the publish tag be removed
    if not table then error("table expected") end
    local results = {}
    local name = name or 'name'
    local publish = publish or 'publish'
    local remove_publish = remove_publish or true
    for k, v in pairs(table) do
        if v[publish] then
            results[k] = {}
            local new_name = v[name]
            if v[publish] ~= const.empty_tag then new_name = v[publish] end
            for kk, vv in pairs(v) do results[k][kk] = vv end
            results[k][name] = new_name
            if remove_publish then results[k][publish]  = nil end
        end
    end
    return results  
end

local function parse_table_rows(str, name, tbl, key)
    -- local log_str = "parse_table_rows"
    local table_pattern = "<TABLE_" .. name .. ">(.-)</TABLE_" .. name .. ">"
    local row_pattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
    local table_content = string.match(str, table_pattern)
    if table_content == nil then return {} end
    local row_content = string.match(table_content, row_pattern)
    local rows = {}
    for row_content, _ in string.gmatch(table_content, row_pattern) do
        local row = {}
        -- log_str = log_str .. "{\n"
        for k, v in pairs(tbl) do
            local value = string.match(row_content, "<" .. k .. ">(.-)</" .. k .. ">")
            if not value and string.match(row_content, "<" .. k .. "%s*/>") then
            -- check if we have <tag/> situation          
                value = ""
            end
            row[v] = _u.decode(value)
            -- log_str = log_str .. v .. ' -> ' .. value
            --logger(v .. ' -> ' .. row[v])
        end
        table.insert(rows, row)
        -- log_str = log_str .. "}\n"
    end
    -- logger(log_str)
    return rows
end

local function show_table_parse(entity, props, table_key, instance_name)
    -- Execute show command on an entity, get the result table and parse individual instances and their properties
    -- Parameters:
    --   entity:     will be put into show <entity> | xml
    --   props:     table of properties that need to be parsed out with replcements key names
    --   [optional] table_key: normally table name is entity with '-' replaces by '_', if set, will used given key 
    --   [optional] instance_name: if specified will append "name <name>" to request
    if not entity then error("entity expected") end
    local table_key = table_key or _u.select(1, entity:gsub('%-', '_'))
    local cmd = "show " .. entity
    if instance_name and type(instance_name) == "string" then 
        cmd = cmd .. " name " .. instance_name
    end
    cmd = cmd .. " | xml"
    local s = run(cmd)
    local result = parse_table_rows(s, table_key, props)
    return result
end

local _name = function(k,v) return v.name end -- return 'name' value from key/value pair 

local function _parse_port_profiles(str, pl)
    local result = {}
    local pp_name
    local lines = _u.splitN(str)
    for _, line in ipairs(lines) do
        local pp_type, name = string.match(line, "port%-profile%s*type%s+(%S+)%s+(%S+)")
        if name ~= nil then
            pp_name = name
            result[pp_name] = {}
            result[pp_name]['type'] = pp_type
        elseif string.match(line, "^%s+") then
            if pp_name ~= nil then
                -- collect requested properties
                local props = {}
                for p in string.gmatch(line, "%S+") do table.insert(props, p) end
                local property_name = props[1]
                local proprty_value = props[2]
                if #props > 2 then
                    -- property_name = property_name .. props[2]
                    proprty_value = table.concat(props, " ", 2)
                end
                for plk, plv in pairs(pl) do
                    local oldValue = result[pp_name][plv]
                    if plk == property_name then
                        result[pp_name][plv] = oldValue and oldValue .. ',' .. proprty_value or proprty_value
                    end
                end
            end
        else
            pp_name = nil
        end
    end
    return result
end

local function _show_parse(entity, props)
    -- Execute show command on an entity, get the result and parse individual properties
    -- Parameters:
    --   entity:     will be put into show <entity> | xml
    --   props:     table of properties that need to be parsed out with replcements key names
    if not entity then error("entity expected") end
    local status, str = pcall(run, "show " .. entity .. " | xml")
    if not status then return nil end
    local result = {}
    for pk, pv in pairs(props) do
        local m = string.match(str, "<" .. pk .. ">(.-)</" .. pk .. ">")
        if not m and string.match(str, "<" .. pk .. "%s*/>") then
            -- check if we have <tag></tag> or <tag/> situation          
            m = const.empty_tag
        end
        result[pv] = m
    end
    return result
end

local function _switch_id()
    return _show_parse('svs domain', {['switch_guid'] = 'id'})['id']
end

local function _portProfiles(port_type)
    if not port_type then return {} end

    local s = run("show running-config port-profile")
    -- get defaults
    local defaultMaxPorts = string.match(s, "port%-profile%sdefault%smax%-ports%s(%d+)") or 512
    local portProfiles = _parse_port_profiles(s, {
        ['guid'] = 'id',
        ['state'] = 'state',
        ['publish'] = 'publish',
        ['max-ports'] = 'maxPorts',
    })
    local rv = {}
    local switchId = _switch_id()
    for pp_name, v in pairs(portProfiles) do
        -- output only port-profiles with id and publish
        if v.type == port_type and v.id  then --and v.publish then
            v.name = pp_name
            if v.publish then
                v.publish = v.publish and string.match(v.publish, "port%-profile%s+(%S+)") or v.name
            end 
            v.switchId = switchId
            v.maxPorts = v.maxPorts or defaultMaxPorts
            -- v.publish = nil -- remove publish from port-profile properties
            
            local publish = v.publish or 'nil'
            logger("pp[name=" .. v.name .. " type=".. v.type .. " publish=" .. publish .. "]")

            rv[v.name] = v  -- key off of name, not ID
        end
    end
    return rv
end


-------------------------------------
-- Prototype for set
-------------------------------------
local MultiCallPrototype = {}
MultiCallPrototype.new = function(name, entity, key)
    local self = {}
    name = name or ''
    entity = entity
    key = key

    self.name = name
    self.entity = entity
    self.fields = nil
    self.list_all = function(show_only_published, pre_output_fn)
    	-- pre_output_fn should be in a format of:
    	-- function (v)
        --     -- Modify each VMND:
        --     -- set maxNumberOfPorts to 200
        --     -- property set segment type
        --     v.netbios = _u.toboolean(v.netbios)
        --     v.dhcp = _u.toboolean(v.dhcp)
        --     v.addressRangeStart, v.addressRangeEnd = v.ipAddressRange:match('(.+)%-(.+)')
        --     v.ipAddressRange = nil --do not need this on the output
        --     v.reservedIpList = splitJoinRows(v.reservedIpList, 'reserved_ip')
        --     v.winServersList = splitJoinRows(v.winServersList, 'wins_server')
        --     v.dnsServersList = splitJoinRows(v.dnsServersList, 'dns_server')
        --     v.dnsSuffixList = splitJoinRows(v.dnsSuffixList, 'dns_suffix')
        --     v.addressFamily = "IPv4";
        --     return v
        -- end
        if not entity then error("Entity is not set for " .. name) end
    	if not self.fields then error("Fields are not defined for " .. name) end
    	local show_only_published = show_only_published or false
        local pre_output_fn = pre_output_fn or _u.identity
    	local rv = show_table_parse(entity, self.fields)
    	if show_only_published == true then rv = allow_only_published(rv) end
    	return _u.map_rekey(rv, _name, pre_output_fn)
    end
    self.has_instance = function (index) return self.list_all()[index] and true or false end
    self.enum = function () return _u.toinstancesSub(self.list_all() or {}, key) end
    self.get = function(index)
        local instance = self.list_all()[index]
        if not instance then error('"' .. index .. '"' .. 'does not exist') end
        return _u.toinstances( {[index] = self.list_all()[index]} or {}) 
    end    
    self.create = function(index) 
         if self.has_instance(index) then error( name .. '"'..index..'" already exists') end
         self.set(index)
    end
    self.set = function(index) error( name .. ' modification is not implemented.') end
    self.delete = function(index) 
        if not index then error("Index is missing") end
        if not entity then error("Entity is not set") end
        if not self.has_instance(index) then
            error({code =404, msg="Not Found", 
                   detail= name .. ' ' .. index ..'" does not exist'})
        end
        local cmd = 'config t ; '
        cmd = cmd .. 'no ' .. entity .. ' ' .. index..' ; '
        run(cmd)
    end
    
    return self
 end

-------------------------------------
-- Definitions for Classes
-------------------------------------
local FabricNetworkDefinition = MultiCallPrototype.new("Fabric Network Definition", 'network-definition')
FabricNetworkDefinition.fields = {
	guid = 'id',
	['name_network_definition'] = 'name',
	['fabric%-network'] = 'fabricNetworkName',
	['intra%-port%-communication'] = 'intraPortCommunication',	
}
FabricNetworkDefinition.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'network-definition '..index)
    -- if request.naitiveNetworkSegment then
    -- table.insert(cmdtbl, "native-network-segment " .. request.naitiveNetworkSegment)
    -- end
    if request.fabricNetworkName then
       table.insert(cmdtbl, "fabric-network " .. request.fabricNetworkName)
    end
    if request.intraPortCommunication ~= nil then
        local cmd = "intraportcom"
        if false == request.intraPortCommunication then
            cmd = "no " .. cmd
        end
        table.insert(cmdtbl, cmd)
    end
    if request.id then
        table.insert(cmdtbl, "guid " .. request.id)
    end 

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("FabricNetworkDefinition.set cmd=" .. cmd)
    run(cmd)
end

local VmNetworkDefinition = MultiCallPrototype.new("VM Network Definition", 'network-segment')
VmNetworkDefinition.fields = {
	['guid'] = 'id',
	['name_network_segment'] = 'name',
	['description'] = 'description',
	['vlan'] = 'vlan',
	['network%-definition'] = 'networkDefinition',
	['ip%-pool%-name'] = 'ipPoolName',
	['ip%-pool%-guid'] = 'ipPoolId',
	['vm_network_name'] = 'vmNetwork',
	['vm_network_guid'] = 'vmNetworkId',
	['publish_name'] = 'publish',
}
VmNetworkDefinition.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'network-segment '..index)
    if request.description then
        table.insert(cmdtbl, "description " .. request.description)
    end
    if request.ipPoolName then
        table.insert(cmdtbl, "ip-pool " .. request.ipPoolName)
    end
    if request.networkDefinition then
        table.insert(cmdtbl, "network-definition " .. request.networkDefinition)
    end
    if request.publishName then
        table.insert(cmdtbl, "publish " .. request.publishName)
    end
    if request.vlan then
        table.insert(cmdtbl, "switchport access vlan " .. request.vlan)
    end
    if request.bridgeDomain then
        table.insert(cmdtbl, "switchport access bridge-domain " .. request.bridgeDomain)
    end
    if request.id then
        table.insert(cmdtbl, "guid " .. request.id)
    end 
    table.insert(cmdtbl, "publish network-segment " .. index) 

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("VmNetworkDefinition.set cmd=" .. cmd)
    run(cmd)
end

local UplinkPortProfile = MultiCallPrototype.new("Uplink Port Profile")
UplinkPortProfile.list_all = function()
    local s = run("show running-config port-profile")
    -- get defaults
    local defaultMaxPorts = string.match(s, "port%-profile%sdefault%smax%-ports%s(%d+)") or 512
    local portProfiles = _portProfiles('ethernet')

    ------    
    -- local names = {}
    -- for k,v in pairs(portProfiles) do
    --     table.insert(names, k)
    -- end
    -- logger("Found port-profiles:" .. table.concat(names,','))
    -----

    local rv = show_table_parse('uplink-network', {
        ['uplink_network_name'] = 'name',
        publish = 'publish',
        ['TABLE_network_def'] = 'TABLE_network_def',
    })
    rv = allow_only_published(rv)

    rv = _u.map(rv, function (v)
        local tmp_net_def_tbl = _u.tag_wrap(v['TABLE_network_def'], 'TABLE_network_def')
        local nd_names = parse_table_rows(tmp_net_def_tbl, 'network_def', {['network_def_name'] = 'nd_name'} )
        local names = {}
        for _, v in ipairs(nd_names) do table.insert(names, v.nd_name) end
        v.networkDefinition = not _u.is_empty(names) and _u.join(names,',') or nil
        v['TABLE_network_def'] = nil -- remove temp field
        return v
    end)

    local switchId = _switch_id()
    return _u.map_rekey(rv, _name, function(v) 
        local pp = portProfiles[v.name]
        if pp then
            v.id = pp.id
            v.maxPorts = v.maxPorts or defaultMaxPorts
        end
        v.switchId = switchId
        return v 
    end)
end

local VirtualPortProfile = MultiCallPrototype.new("Virtual Port Profile")
VirtualPortProfile.list_all = function() 
    local port_type = 'vethernet'
    local rv = _portProfiles(port_type)
    return rv
end

local IpAddressPool = MultiCallPrototype.new("IP Address Pool", 'ip-pool')
IpAddressPool.fields = {
	guid = 'id',
	['name_ip_pool'] = 'name',
	description = 'description',
	['ip%-address%-range'] = 'ipAddressRange',
	['subnet%-mask'] = 'ipAddressSubnet',
	gateway = 'gateway',
	netbios = 'netbios',
	['dhcp%-support'] = 'dhcp',
	['TABLE_reserved_ip'] = 'reservedIpList',
	['TABLE_wins_server'] = 'winServersList',
	['TABLE_dns_server'] = 'dnsServersList',
	['TABLE_dns_suffix'] = 'dnsSuffixList',
}
IpAddressPool.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'ip-pool ' .. index)

    if request.description then
        table.insert(cmdtbl, "description " .. request.description)
    end

    if request.dhcp ~= nil then 
        if true == request.dhcp then  table.insert(cmdtbl, "dhcp-support")
        else table.insert(cmdtbl, "no dhcp-support") end
    end

    if request.gateway then
        table.insert(cmdtbl, "gateway " .. request.gateway)
    end

    if request.netbios ~= nil then 
        if request.netbios then  table.insert(cmdtbl, "netbios")
        else table.insert(cmdtbl, "no netbios") end
    end

    if request.addressRangeStart and request.addressRangeEnd then
        table.insert(cmdtbl, "ip-address " .. request.addressRangeStart .. " " .. request.addressRangeEnd)
    end

    if request.ipAddressSubnet then
        table.insert(cmdtbl, "subnet-mask " .. request.ipAddressSubnet)
    end

    if request.reservedIpList then
        table.insert(cmdtbl, "reserved-ip " .. request.reservedIpList)
    end

    if request.winServersList then
        table.insert(cmdtbl, "wins-server " .. request.winServersList)
    end

    if request.dnsServersList then
        table.insert(cmdtbl, "dns-server " .. request.dnsServersList)
    end

    if request.dnsSuffixList then
        table.insert(cmdtbl, "dns-suffix " .. request.dnsSuffixList)
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("IpAddressPool.set cmd=" .. cmd)
    run(cmd)
end

local FabricNetwork = MultiCallPrototype.new("Fabric Network", 'fabric-network')
FabricNetwork.fields = {
	name = 'name',
	description = 'description',	
}

local VmNetwork = MultiCallPrototype.new("VM Network", 'nsm network vethernet')
VmNetwork.list_all = function()
    local vmNetworks = {}
    local function match_all_to_table(s, ptn)
        -- match all entries and put them in the out table
        local t = {}
        if s and ptn and type(s) == 'string' and type(ptn) == 'string' then
            for i in s:gmatch(ptn) do table.insert(t, i) end
        end
        return t
    end
    local singe_fields = {
        ['vm_network_name'] = 'name', 
        ['tenant_id'] = 'tenantId',
        ['network_segment_guid'] = 'id', 
    }
    local array_fields = {['port_guids'] = 'portId'}
    local s_run_cfg_vm_network = run("show running-config")
    local vm_network_names = match_all_to_table(s_run_cfg_vm_network, "nsm%snetwork%svethernet%s(.-)\n")

    for _, name in ipairs(vm_network_names) do
        local one_vm_net = {}
        local vm_net_s = run("show nsm network vethernet name "..name..' | xml')

        for k, v in pairs(singe_fields) do 
            local vv = vm_net_s:match('<'..k..'>(.-)</'..k..'>')
            one_vm_net[v] = vv
        end

        
        for k, v in pairs(array_fields) do
            local vv = match_all_to_table(vm_net_s, '<'..k..'>(.-)</'..k..'>')
            one_vm_net[v] = vv
        end
        vmNetworks[_u.encode(name)] = one_vm_net
    end
    return vmNetworks
end
VmNetwork.set = function(index)
    local cmdtbl = {}

    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'nsm network vethernet ' .. index)
    table.insert(cmdtbl, 'no state enabled') -- have to disable to modify

    if request.vmNetworkDefinition then
        table.insert(cmdtbl, "allow network segment " .. request.vmNetworkDefinition .. " guid " .. request.vmNetworkDefinitionId)
    end

    if request.portProfile then
        table.insert(cmdtbl, "import port-profile " .. request.portProfile .. " guid " .. request.portProfileId)
    end

    if request.tenantId then
        table.insert(cmdtbl, "tenant-id " .. request.tenantId)
    end

    table.insert(cmdtbl, "state enabled" )

    if (request.portId and request.macAddress) then
        table.insert(cmdtbl, "port guid " .. request.portId .. " mac " .. request.macAddress .. " ; ")
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("VmNetwork.set cmd=" .. cmd)
    run(cmd)
end

local VmNetworkPorts = MultiCallPrototype.new("VM Network Ports", nil, 'id')
VmNetworkPorts.list_all = function()
    local vm_net = _G.classpath[#_G.classpath - 1].index
    local cls = _G.classpath[#_G.classpath - 1].classname
    logger('vm_network='..vm_net)
    logger('cls='..cls)
    local vmNetorkPorts = {}
    local vmNetwork = VmNetwork.list_all()[vm_net]
    for k,v in pairs(vmNetwork) do logger('k,v='..k) end
    if vmNetwork.portId then
        local s_run_cfg_vm_network = run("show running-config")
        for _,v in pairs(vmNetwork.portId) do
            local vmNetorkPort = {}
            vmNetorkPort.id = v
            local mac_ptn = 'port%sguid%s'..string.gsub(vmNetorkPort.id, '%-', '%%-')..'%smac%s(.-)\n'
            logger('matching '..mac_ptn) 
            vmNetorkPort.macAddress = s_run_cfg_vm_network:match(mac_ptn)
            table.insert(vmNetorkPorts,vmNetorkPort)
        end
    end
    return vmNetorkPorts
end

VmNetworkPorts.set = function(index)
    local vm_net = _G.classpath[#_G.classpath - 1].index 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'nsm network vethernet ' .. vm_net)
    table.insert(cmdtbl, 'state enabled')

    if (request.macAddress and request.id) then
        table.insert(cmdtbl, "port guid " .. request.id .. " mac " .. request.macAddress .. " ; ")
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("VmNetworkPorts.set cmd=" .. cmd)
    run(cmd)
end
VmNetworkPorts.delete = function ( index )
    local vm_net = _G.classpath[#_G.classpath - 1].index
    local mac
    if not index then error("Index is missing") end
    instances = VmNetworkPorts.list_all()
    for k,v in pairs(instances) do
        if v.id == index then
            mac = v.macAddress
        end
    end
    if not mac then error("Could not find macAddress") end
    local cmd = 'config t ; '
    cmd = cmd .. 'nsm network vethernet ' .. vm_net .. ' ;'
    cmd = cmd .. 'no port guid ' .. index .. ' mac ' ..mac ..' ; '
    logger('VmNetworkPorts.delete=' .. cmd)
    run(cmd)
end    

local BridgeDomain = MultiCallPrototype.new("Bridge Domain", 'bridge-domain')
BridgeDomain.fields = {
    ['bd_name'] = 'name',
    ['port_count'] = 'portCount',
    ['segment_id'] = 'segmentId',
    ['group_ip'] = 'groupIp',
    ['state'] = 'state',
    ['mac_learning'] = 'macLearning',
}
BridgeDomain.set = function(index)
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'bridge-domain '..index)
    if request.segmentId then
        table.insert(cmdtbl, "segment id " .. request.segmentId)
    end
    if request.groupIp then
        table.insert(cmdtbl, "group " .. request.groupIp)
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("BridgeDomain.set cmd=" .. cmd)
    run(cmd)
end

local blank_properties = {
	enum = function() return {instances = {[''] = {}}} end,
	has_instance = function() return true end,
}

local function validate_accounting_time_format( time )
    -- Valid format is YYYY Mon dd HH:MM:SS
    -- YYYY is 1970-2030
    -- Mon is 3 characters long e.g. Jan, Feb, etc
    -- dd is day of month (2 chars)
    -- Enter hour, minutes, seconds as HH:MM:SS (Max Size 8)

end

local function to_accounting_time(t) return type(t) == 'number' and os.date("%Y %b %m %X", t) or nil end

local function to_unix(date)
    local MONTHS = { ["Jan"] = 1, ["Feb"] = 2, ["Mar"] = 3, 
                     ["Apr"] = 4, ["May"] = 5, ["Jun"] = 6, 
                     ["Jul"] = 7, ["Aug"] = 8, ["Sep"] = 9, 
                     ["Oct"] =10, ["Nov"] =11, ["Dec"] =12 }
    local mon, day, hr, min, sec, yr = date:match("(%u%l%l) (%d+) (%d+):(%d+):(%d+) (%d+)")
    if day and mon and yr and hr and min and sec then
        local month = MONTHS[mon]
        return os.time( {year=yr, month=month, day=day, 
                         hour=hr, min=min, sec=sec } ) 
    end
    return 0
end

local function get_accouting_log(event_type, start_time, end_time)
    -- start_time and validate_accounting_time_format(start_time)
    -- end_time and validate_accounting_time_format(end_time)
    local events = {}
    local cmd = "show accounting log"
    if start_time then
        local start_time = tonumber(start_time) 
        if not start_time then error({code=500, msg="Start time must be a number in epoc format"}) end
        cmd = cmd .. " start-time " .. to_accounting_time(start_time)
    end
    if end_time then
        local end_time = tonumber(end_time) 
        if not end_time then error({code=500, msg="End time time must be a number in epoc format"}) end
        cmd = cmd .. " end-time " .. to_accounting_time(end_time)
    end

    local port_profiles = _portProfiles('vethernet')

    local function last_word(s) return s:match('(%S+)%s*$') end
    local function unquote(str) return (string.gsub(str,"^([\"\'])(.*)%1$","%2")) end
    
    local function event_default(s)
        local split_ptn = "%a-%s(.-):type=(.-):id=(.-):user=(.-):cmd=(.*)"
        if not s then return nil end
        local time, e_type, id, user, cmd = string.match(s, split_ptn)
        if not time then return nil end
        return { time = to_unix(time), event_type = e_type, id = id, user = user, cmd = cmd }
    end

    local function parse_port_profile_cmd(cmd)
        -- Returns <portprofile name,  result>
        local no_prefix_cmd = string.match(cmd, "^[^;]-;%s*(.*)")
        if not no_prefix_cmd then return nil end
        local pp, result = string.match(no_prefix_cmd, "port%-profile(.-)%((%a+)%)%s*$")
        local no = string.match(no_prefix_cmd, "^%s*no")
        return no, pp, result
    end

    local function event_type_port_profile(s)
        local event  = event_default(s)
        if not event then return nil end
        local cmd = event.cmd
        local no, pp, result = parse_port_profile_cmd(cmd)
        if pp and result == 'SUCCESS' then
            if not pp:find(';') then --make sure it is a first line of create/set
                local name = unquote(last_word(pp))
                local pp = port_profiles[name]
                local id = pp and pp.id or nil 
                return {time = event.time, name = name, cmd = cmd, id = id}
            end
        end
    end

    local function event_type_port_profile_update(s) 
       local event  = event_default(s)
        if not event then return nil end
        local cmd = event.cmd
        local no, pp, result = parse_port_profile_cmd(cmd)
        if pp and not no and result == 'SUCCESS' then
            if not pp:find(';') then --make sure it is a first line of create/set
                local name = unquote(last_word(pp))
                local pp = port_profiles[name]
                local id = pp and pp.id or nil 
                return {time = event.time, name = name, id = id }
            end
        end
    end

    local function event_type_port_profile_delete(s) 
       local event  = event_default(s)
        if not event then return nil end
        local cmd = event.cmd
        local no, pp, result = parse_port_profile_cmd(cmd)
        if pp and no and result == 'SUCCESS' then
            local name = unquote(last_word(pp))
            local pp = port_profiles[name]
            local id = pp and pp.id or nil 
            return {time = event.time, name = name, id = id }
        end
    end

    local type_fn = {
        ['port_profile'] = event_type_port_profile,
        ['port_profile_update'] = event_type_port_profile_update,
        ['port_profile_delete'] = event_type_port_profile_delete,
    }

    local event_fn = (event_type and type_fn[event_type] or event_default) or event_default
    local s = run(cmd)
    for _, line in pairs(_u.splitN(s)) do  
        local event = event_fn(line)
        if event then
            table.insert(events, event) 
        end
    end 
    return events
end

local function timed(fn, timeout)
    local r = {}
    local time = os.time
    local timeout = timeout or 10
    local t0 = time()
    while time() - t0 <= timeout do
        r = fn()
        local is_empty_result = (#r == 0)
        if is_empty_result then
            os.execute("sleep 1")
        else break end
    end
    return r
end

local function parse_query(query)
    local parsed = {}
    local pos = 0

    query = string.gsub(query, "&amp;", "&")
    query = string.gsub(query, "&lt;", "<")
    query = string.gsub(query, "&gt;", ">")

    local function ginsert(qstr)
        local first, last = string.find(qstr, "=")
        if first then
            parsed[string.sub(qstr, 0, first-1)] = string.sub(qstr, first+1)
        end
    end

    while true do
        local first, last = string.find(query, "&", pos)
        if first then
            ginsert(string.sub(query, pos, first-1));
            pos = last+1
        else
            ginsert(string.sub(query, pos));
            break;
        end
    end
    return parsed
end

local events = {
    enum = function() 
        return _u.toinstances(get_accouting_log()) or {} 
    end,
    has_instance = function (index) return false end,
    query = function ()
        local q = parse_query(_G.query_string)
        local event_type = q['type']
        local start_time = q['start']
        local end_time = q['end']
        return _u.toinstances(
            timed(function() 
                return get_accouting_log(event_type, start_time, end_time) 
                end)) or {} 
    end,
}

return {
	hyper_v = blank_properties,
	fabric_network_definition = FabricNetworkDefinition,
	vm_network_definition = VmNetworkDefinition,
	uplink_port_profile = UplinkPortProfile,
	virtual_port_profile = VirtualPortProfile,
	ip_address_pool = IpAddressPool,
	fabric_network = FabricNetwork,
	vm_network = VmNetwork,
	vm_network_ports = VmNetworkPorts,
	bridge_domain = BridgeDomain,
    events = events,
}
