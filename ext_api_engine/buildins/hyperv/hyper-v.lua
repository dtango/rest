-- NEXUS 1000V VC Plugin addition
local _n = require 'nexus1000v'
local _u = require 'utils'
local Switch = _n.switch

------------------------------------------
-- Convenience functions
------------------------------------------
local _name = function(k,v) return v.name end -- return 'name' value from key/value pair 
    local splitJoinRows = function(str, name)
        local pieces = {}
        local rowPattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
        -- name = string.gsub(name, '_', '%%-')  -- wait for Alpesh to finish
        local dataPattern = "<" .. name .. ">(.-)</" .. name .. ">"
        if not str then return "" end
        for v, _ in string.gmatch(str, rowPattern) do
            if v then pieces[#pieces + 1] = v:match(dataPattern) end
        end
        return _u.join(pieces, ",")
    end

local CallPrototype = {}
CallPrototype.new = function(name)
    local self = {}
    name = name or ''

    self.list_all = function() return {} end
    self.has_instance = function (index) return self.list_all()[index] and true or false end
    self.enum = function () return _u.toinstances(self.list_all() or {}) end
    self.get = function(index) 
        local rv = self.list_all()[index]
        if not rv or _u.is_empty(rv) then _u.index_not_found_error(index) end
        return _u.toinstances({[index] = rv}) 
    end
    self.create = function(index) 
         -- if self.has_instance(index) then error( name .. '"'..index..'" already exists') end
         self.set(index)
    end
    self.set = function(index) error( name .. ' modification is not implemented.') end
    self.delete = function(index) error( name .. 'deletion is not implemented.') end
    
    return self
 end

local function get_instance(name, entity, props, table_key)
    -- Get individual instance 
    -- Parameters: 
    --   name: name of and instance to be retrieved from the whole list
    --   entity:     will be put into show <entity> | xml
    --   props:     table of properties that need to be parsed out with replcements key names
    --   [optional] table_key: normally table name is entity with '-' replaces by '_', if set, will used given key 
    if not name then error("isntance name expected") end
    if not entity then error("entity expected") end
    local named_entity = entity .. " name " .. name
    return Switch.show_table_parse(named_entity, props, table_key)
end

local function delete_instance(proto_instance, index, entity)
    --- Default delete method for 'CallPrototype'
    if not proto_instance then error("Prototype is empty") end
    -- if not proto_instance.has_instance then error('Prototype missing "has_instance"' ) end
    -- if not proto_instance.has_instance(index) then 
    --    error({code =404, msg="Not Found", detail='Instance "'..index..'" does not exist'}) 
    -- end
    local cmd = 'config t ; '
    cmd = cmd .. 'no ' .. entity .. ' ' .. index..' ; '
    Switch.run(cmd)
end

-------------------------------------
-- NETWORK SEGMENT POOL
-------------------------------------
local NetworkSegmentPool = CallPrototype.new('Network Segment Pool')
NetworkSegmentPool.list_all = function()
    local rv = Switch.show_table_parse('nsm network segment pool',{
            uuid = 'id',
            ['description'] = 'description',
            ['name_network_segment_pool'] = 'name',
            ['logical%-network'] = 'logicalNetwork',
            ['intra%-port%-communication'] = 'intraPortCommunication',
            -- ['publish_name'] = 'publish',
    }, 'network_segment_pool')

    return _u.map_rekey(rv, _name,
        function (v)
            v.intraPortCommunication = _u.toboolean(v.intraPortCommunication)
            v.supportsIpPool = true
            v.supportsVMNetworkProvisioning = true
            v.maximumNetworkSegmentsPerVMNetwork = 2000
            return v
        end)
end
NetworkSegmentPool.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'nsm network segment pool '..index)
    -- if request.naitiveNetworkSegment then
    -- table.insert(cmdtbl, "native-network-segment " .. request.naitiveNetworkSegment)
    -- end

    if request.description then 
        table.insert(cmdtbl, "description " .. request.description)    
    end

    if request.logicalNetwork then
       table.insert(cmdtbl, "member-of logical network " .. request.logicalNetwork)
    end

    if request.intraPortCommunication ~= nil then
        local cmd = "intraportcom"
        if false == request.intraPortCommunication then
            cmd = "no " .. cmd
        end
        table.insert(cmdtbl, cmd)
    end

    if request.id then
        table.insert(cmdtbl, "uuid " .. request.id)
    end 

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("NetworkSegmentPool.set cmd=" .. cmd)
    Switch.run(cmd)
end

NetworkSegmentPool.delete = function(index) delete_instance(NetworkSegmentPool,index,'nsm network segment pool') end

-------------------------------------
-- NETWORK SEGMENT
-------------------------------------
local NetworkSegment = CallPrototype.new('Network Segment')
NetworkSegment.fields = {
        ['uuid'] = 'id',
        ['name_network_segment'] = 'name',
        ['description'] = 'description',
        ['vlan'] = 'vlan',
        ['network%-segment%-pool'] = 'networkSegmentPool',
        ['ip%-pool%-template%-name'] = 'ipPool',
        ['ip%-pool%-template%-uuid'] = 'ipPoolId',
        --['publish_name'] = 'publishName',
        ['vm_network_name'] = 'vmNetwork',
        ['vm_network_uuid'] = 'vmNetworkId',
        ['publish'] = 'publish',
}
NetworkSegment.pre_output = function ( rv )
    -- Pre-process the  results so they are ready for output
        return _u.map_rekey(rv, _name,
        function (v)
            -- Modify each VMND:
            -- set maxNumberOfPorts to 200
            -- property set segment type
            v.maxNumberOfPorts = maxNumberOfPorts
            v.segmentType = v.vlan and 'VLAN' or 'BridgeDomain'
            return v
        end) 

end
NetworkSegment.list_all = function()
    local rv = Switch.allow_only_published(Switch.show_table_parse('nsm network segment', NetworkSegment.fields,'network_segment')) --{
return NetworkSegment.pre_output(rv)
end
-- NetworkSegment.get = function(index)
--     local rv = Switch.allow_only_published(Switch.show_table_parse("nsm network segment", NetworkSegment.fields, 'network_segment', index))
--     if _u.is_empty(rv) then _u.index_not_found_error(index) end
--     logger("NetworkSegment.get -> " .. index)
--     rv = NetworkSegment.pre_output(rv)
--     return {
--         instances = {
--             [index] = {
--                 properties = rv[index]
--             }
--         }
--     }
-- end
NetworkSegment.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'nsm network segment '..index)

    if request.ipPool then
        if request.deleteSubnet ~= nil and request.deleteSubnet then
            table.insert(cmdtbl, 'no publish network segment')
            table.insert(cmdtbl, 'no ip pool import template ' .. request.ipPool)
        else
            local ip_pool_cmd = "ip pool import template " .. request.ipPool
            if request.ipPoolId then ip_pool_cmd = ip_pool_cmd .. " uuid " .. request.ipPoolId end
            table.insert(cmdtbl, ip_pool_cmd)
        end
    end

    if request.networkSegmentPool then
        table.insert(cmdtbl, "member-of network segment pool " .. request.networkSegmentPool)
    end

    if request.segmentType == "vlan" and request.mode == "access" then
        table.insert(cmdtbl, "switchport mode access ")
        table.insert(cmdtbl, "switchport access vlan " .. request.vlan)
    elseif request.segmentType == "vxlan" and request.mode == "access" then
        table.insert(cmdtbl, "switchport access bridge-domain " .. request.bridgeDomain)
    elseif request.segmentType == "vlan" and request.mode == "trunk" then
        table.insert(cmdtbl, "switchport mode trunk ")
    end

    if request.description then
        table.insert(cmdtbl, 'no publish network segment')
        table.insert(cmdtbl, "description " .. request.description)
    end

    if request.id then
        table.insert(cmdtbl, "uuid " .. request.id)
    end 

    if request.publishName then
        table.insert(cmdtbl, "publish network segment " .. request.publishName)
    else
        -- Automatically publish to accomodate bug CSCug68288
       table.insert(cmdtbl, "publish network segment ")
    end


    local cmd = _u.join(cmdtbl, ' ; ')
    logger("vmNetworkDefinition.set cmd=" .. cmd)
    Switch.run(cmd)
end
NetworkSegment.delete = function(index) 
    -- if not NetworkSegment.has_instance(index) then
	-- _u.index_not_found_error(index)
    -- end
    local cmd = 'config t ; '
    cmd = cmd .. 'nsm network segment ' .. index .. ' ; '
    cmd = cmd .. 'no publish network segment ; '
    cmd = cmd .. 'no nsm network segment ' .. index..' ; '
    Switch.run(cmd)
end

-------------------------------------
-- IP Address Pool 
-------------------------------------
local IpPoolTemplate = CallPrototype.new('IP Address Pool Template')
IpPoolTemplate.list_all = function()
    local rv = Switch.show_table_parse('nsm ip pool template',{
        uuid = 'id',
        ['name_ip_pool'] = 'name',
        description = 'description',
        ['ip%-address%-range'] = 'ipAddressRange',
        ['network%-address'] = 'networkAddress',
        ['subnet%-mask'] = 'ipAddressSubnet',
        gateway = 'gateway',
        netbt = 'netbt',
        ['dhcp'] = 'dhcp',
        ['TABLE_reserved_ip'] = 'reservedIpList',
        ['TABLE_netbios_name_server'] = 'netbiosServersList',
        ['TABLE_dns_server'] = 'dnsServersList',
        ['TABLE_dns_suffix'] = 'dnsSuffixList'
    }, 'ip_pool_template')

    return _u.map_rekey(rv, _name,
        function (v)
            -- Modify each VMND:
            -- set maxNumberOfPorts to 200
            -- property set segment type
            v.netbt = _u.toboolean(v.netbt)
            v.dhcp = _u.toboolean(v.dhcp)
            v.addressRangeStart, v.addressRangeEnd = v.ipAddressRange:match('(.+)%-(.+)')
            v.ipAddressRange = nil --do not need this on the output
            v.reservedIpList = splitJoinRows(v.reservedIpList, 'reserved_ip')
            v.netbiosServersList = splitJoinRows(v.netbiosServersList, 'netbios_name_server')
            v.dnsServersList = splitJoinRows(v.dnsServersList, 'dns_server')
            v.dnsSuffixList = splitJoinRows(v.dnsSuffixList, 'dns_suffix')
            v.addressFamily = "IPv4";
            return v
        end)
end
IpPoolTemplate.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'nsm ip pool template ' .. index)

    if request.dhcp ~= nil then 
        if true == request.dhcp then  table.insert(cmdtbl, "dhcp")
        else table.insert(cmdtbl, "no dhcp") end
    end

    if request.netbt ~= nil then 
        if request.netbt then  table.insert(cmdtbl, "netbt")
        else table.insert(cmdtbl, "no netbt") end
    end

    if request.addressRangeStart and request.addressRangeEnd then
        table.insert(cmdtbl, "ip address " .. request.addressRangeStart .. " " .. request.addressRangeEnd)
    end

    if request.ipAddressSubnet then
        table.insert(cmdtbl, "network " .. request.networkAddress .. " " .. request.ipAddressSubnet)
    end

    if request.gateway and request.gateway ~= null then
        table.insert(cmdtbl, "default-router " .. request.gateway)
    end

    if request.reservedIpList then
        table.insert(cmdtbl, "ip reserved " .. request.reservedIpList)
    end

    if request.winServersList then
        table.insert(cmdtbl, "netbios-name-server " .. request.winServersList)
    end

    table.insert(cmdtbl, "no dns-server all")
    if request.dnsServersList then
        for key, value in ipairs(request.dnsServersList) do
            table.insert(cmdtbl, "dns-server " .. value)
        end
    end

    if request.dnsSuffixList then
        table.insert(cmdtbl, "dns-suffix " .. request.dnsSuffixList)
    end

    if request.description then
        table.insert(cmdtbl, "description " .. request.description)
    end

    if request.netSegmentName ~= nil then 
        table.insert(cmdtbl, "exit")
        table.insert(cmdtbl, "nsm network segment "..request.netSegmentName)
        table.insert(cmdtbl, "no publish network segment")
        table.insert(cmdtbl, "ip pool import template "..index.." uuid "..request.id)
        table.insert(cmdtbl, "publish network segment")
    end

    local cmd = _u.join(cmdtbl, ' ; ')
    logger("IpPoolTemplate.set cmd=" .. cmd)
    Switch.run(cmd)
end
IpPoolTemplate.delete = function(index) delete_instance(IpPoolTemplate,index,'nsm ip pool template') end

-------------------------------------
-- Uplink Port Profile 
-------------------------------------
local UplinkPortProfile = CallPrototype.new('Uplink Port Profile')
UplinkPortProfile.list_all = function()
    local s = Switch.run("show running-config port-profile")
    -- get defaults
    local defaultMaxPorts = string.match(s, "port%-profile%sdefault%smax%-ports%s(%d+)") or 512
    local portProfiles = Switch.portProfiles('ethernet')
    local rv = Switch.show_table_parse('nsm network uplink', {
        ['network_uplink_name'] = 'name',
        publish = 'publish',
        ['TABLE_network_segment_pool'] = 'TABLE_network_segment_pool',
    }, 'network_uplink')
    rv = _u.map(rv, function (v)
        local tmp_net_def_tbl = _u.tag_wrap(v['TABLE_network_segment_pool'], 'TABLE_network_segment_pool')
        local nd_names = Switch._parse_table_rows(tmp_net_def_tbl, 'network_segment_pool', {['network_segment_pool_name'] = 'nd_name'} )
        local names = {}
        for _, v in ipairs(nd_names) do table.insert(names, v.nd_name) end
        v.networkSegmentPool = not _u.is_empty(names) and _u.join(names,',') or nil
        v['TABLE_network_segment_pool'] = nil -- remove temp field
        return v
    end)

    local switchId = Switch.id
    rv = _u.map_rekey(rv, _name, function(v) 
        local pp = portProfiles[v.name]
        if pp then
            v.id = pp.id
            v.maxPorts = v.maxPorts or defaultMaxPorts
        end
        v.switchId = switchId
        return v 
    end)
    rv = Switch.allow_only_published(rv)
    return rv
end

-------------------------------------
-- Virtual Port Profile 
-------------------------------------
local VirtualPortProfile = CallPrototype.new('Virtual Port Profile')
VirtualPortProfile.list_all = function() 
    local port_type = 'vethernet'
    local maxNumberOfPortsPerHost = 216
    local rv = Switch.portProfiles(port_type)
    
    rv = Switch.allow_only_published(rv)

    return _u.map(rv, function(v) 
        v.maxNumberOfPortsPerHost = maxNumberOfPortsPerHost 
        return v 
    end)
end

-------------------------------------
-- Switch Extension Info 
-------------------------------------
local SwitchExtensionInfo = function()
    local sys_version  = Switch.show_parse('system vem version range', {
        ['min_version'] = 'min',
        ['max_version'] = 'max',
    })
    local version = Switch.show_parse('version', {
        ['host_name'] = 'name',
    })
    local opq = Switch.show_parse('msp internal info config-summary', {
        ['opq_data'] = 'data',
    })

    return {
        id = Switch.id,
        maxVersion = sys_version.max,
        minVersion = sys_version.min,
        name = version.name,
        drivernetcfginstanceid = "9C8ED422-F33A-4F34-B771-E8B8D0539FD3",
        mandatoryFeatureId = "2ABD62F9-0E77-4E4C-B7B0-B2DBAF9B7CBB",
        opdata = opq.data,
        maxNumberOfPorts = 16000,
        maxNumberOfPortsPerHost = 216,
        switchExtensionFeatureConfigId = "2ABD62F9-0E77-4E4C-B7B0-B2DBAF9B7CBB",
        isSwitchTeamSupported = true,
        extensionType = "Forwarding",
        isChildOfWFPSwitchExtension = false,
    }
end
-------------------------------------
-- VSEM System Info 
-------------------------------------
local VsemSystemInfo = function()
    local rv = Switch.show_parse('version', {
        ['chassis_id'] = 'chassis',
        ['sys_ver_str'] = 'version',
        ['host_name'] = 'host',
    })

    return {
        id = Switch.id,
        description = "Cisco Systems Nexus 1000V",
        manufacturer = "Cisco Systems",
        version = "1.0",
        model = rv.chassis,
        -- Format: Cisco Nexus 1000V Chassis version <release version> [build <daily build version] [gdb/final] - <your_switch_name>
        name = 'Cisco ' .. rv.chassis .. ' version ' .. rv.version .. ' - '.. rv.host,
        vendorId = "{55ca4f11-f549-4440-a489-e7337f3a6b73}",
    }
end
-------------------------------------
-- VM NETWORK 
-------------------------------------
local VmNetwork = CallPrototype.new('VM Network')
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
        ['network_segment_uuid'] = 'id', 
    }
    local array_fields = {['port_uuids'] = 'portId'}
    local s_run_cfg_vm_network = Switch.run("show running-config")
    local vm_network_names = match_all_to_table(s_run_cfg_vm_network, "nsm%snetwork%svethernet%s(.-)\n")

    for _, name in ipairs(vm_network_names) do
        local one_vm_net = {}
        local vm_net_s = Switch.run("show nsm network vethernet name "..name..' | xml')

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

    if request.networkSegment then
        table.insert(cmdtbl, "allow network segment " .. request.networkSegment .. " uuid " .. request.networkSegmentId)
    end

    if request.portProfile then
        table.insert(cmdtbl, "import port-profile " .. request.portProfile .. " uuid " .. request.portProfileId)
    end

-- Muru: Commenting it out for now as it triggers an error in VSM
--    if request.tenantId then
--        table.insert(cmdtbl, "tenant-id " .. request.tenantId)
--    end

    table.insert(cmdtbl, "state enabled" )

    if (request.portId and request.macAddress) then
       if (request.ipAddress and request.subnetId) then
           table.insert(cmdtbl, "port uuid " .. request.portId .. " mac " .. request.macAddress ..  " ip " .. request.ipAddress  .. " subnet " .. request.subnetId)
       else
           table.insert(cmdtbl, "port uuid " .. request.portId .. " mac " .. request.macAddress)
       end
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("VmNetwork.set cmd=" .. cmd)
    Switch.run(cmd)
end

VmNetwork.delete = function(index) 
    -- if not VmNetwork.has_instance(index) then
    -- _u.index_not_found_error(index)
    -- end
    local cmd = 'config t ; '
    cmd = cmd .. 'no nsm network vethernet ' .. index .. ' ; '
    Switch.run(cmd)
end

-- Dummy has_instance method to get around instance checks 
-- for a VmNetwork
VmNetwork.has_instance = function (index) return true end

----------------------------------------
-- VMNETWORK PORTS
----------------------------------------
local VmNetworkPorts = CallPrototype.new("VM Network Ports")
VmNetworkPorts.list_all = function()
    local vm_net = _G.classpath[#_G.classpath - 1].index
    local cls = _G.classpath[#_G.classpath - 1].classname
    logger('vm_network='..vm_net)
    logger('cls='..cls)
    local vmNetorkPorts = {}
    local vmNetwork = VmNetwork.list_all()[vm_net]
    for k,v in pairs(vmNetwork) do logger('k,v='..k) end
    if vmNetwork.portId then
        local s_run_cfg_vm_network = Switch.run("show running-config")
        for _,v in pairs(vmNetwork.portId) do
            local vmNetorkPort = {}
            vmNetorkPort.id = v
            local mac_ptn = 'port%suuid%s'..string.gsub(vmNetorkPort.id, '%-', '%%-')..'%smac%s(.-)\n'
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
       if (request.ipAddress and request.subnetId) then
           table.insert(cmdtbl, "port uuid " .. request.id .. " mac " .. request.macAddress ..  " ip " .. request.ipAddress  .. " subnet " .. request.subnetId)
       else
           table.insert(cmdtbl, "port uuid " .. request.id .. " mac " .. request.macAddress)
       end
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("VmNetworkPorts.set cmd=" .. cmd)
    Switch.run(cmd)
end

VmNetworkPorts.delete = function ( index )
    local vm_net = _G.classpath[#_G.classpath - 1].index
    if not index then error("Index is missing") end
    local cmd = 'config t ; '
    cmd = cmd .. 'nsm network vethernet ' .. vm_net .. ' ;'
    cmd = cmd .. 'no port uuid ' .. index .. ' ; '
    logger('VmNetworkPorts.delete=' .. cmd)
    Switch.run(cmd)
end 

----------------------------------------
-- BRIDGE DOMAIN
----------------------------------------
local BridgeDomain = CallPrototype.new("Bridge Domain")
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
    if request.subType == "unicast" then
        table.insert(cmdtbl, "segment mode unicast-only")
    elseif request.subType == "multicast" then
        table.insert(cmdtbl, "no segment mode unicast-only")
    end

    if request.segmentId then
        table.insert(cmdtbl, "segment id " .. request.segmentId)
    end

    if request.groupIp then
        table.insert(cmdtbl, "group " .. request.groupIp)
    end

    local cmd = table.concat(cmdtbl, ' ; ')
    logger("BridgeDomain.set cmd=" .. cmd)
    Switch.run(cmd)
end

BridgeDomain.delete = function(index) delete_instance(BridgeDomain,index,'bridge-domain') end

----------------------------------------
-- EVENTS
----------------------------------------
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

    local port_profiles = Switch.portProfiles('vethernet')

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
    local s = Switch.run(cmd)
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

----------------------------------------
-- LOGICAL NETWORK
----------------------------------------
local LogicalNetwork = CallPrototype.new('Logical Network')
LogicalNetwork.list_all = function()
    local rv = Switch.show_table_parse('nsm logical network',{
        ['name_logical_network'] = 'name',
        ['description'] = 'description',
    }, 'logical_network')
    --return rv
    return _u.map_rekey(rv, _name, _u.identity)
end
LogicalNetwork.set = function(index) 
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    table.insert(cmdtbl, 'nsm logical network '..index)

    if request.description then
        table.insert(cmdtbl, "description " .. request.description)
    end
    local cmd = table.concat(cmdtbl, ' ; ')
    logger("fabricNetwork.set cmd=" .. cmd)
    Switch.run(cmd)
end
LogicalNetwork.delete = function(index) delete_instance(LogicalNetwork,index,'nsm logical network') end

----------------------------------------
-- Encapsulation Profile 
----------------------------------------
local encap_prof_insts
local encap_prof_props
local EncapsulationProfile = CallPrototype.new("Encapsulation Profile")
local parsdot1q2mapping = function(xml, ptn)
    local num = 0
    local function match_all_to_table(s, ptn)
        local dot1q2map = {
            ['dot1q'] = 'dot1q',
            ['bridgeDomain'] = 'bridgeDomain',
        }
        if (s and ptn and type(s) == 'string' and type(ptn) == 'string') then
            for i in s:gmatch(ptn) do
                num = num + 1
                encap_prof_props.mappings.mapping[num] = {}
                for k,v in pairs(dot1q2map) do
                    local vv = i:match('<'..k..'>(.-)</'..k..'>')
                    if vv then
                        encap_prof_props.mappings.mapping[num][k] = vv
                    end
                end
            end
            if (num == 0) then
                encap_prof_props.mappings.mapping[num + 1] = {}
            end
        end
    end
    encap_prof_props.mappings = {}
    encap_prof_props.mappings.mapping = {}
    local array_fields = {['ROW_mappings'] = 'mapping'}
    for k, v in pairs(array_fields) do
        local vv = match_all_to_table(xml, '<'..k..'>(.-)</'..k..'>')
    end
end

local populatemappings = function(xml)
    local single_fields = {
        ['encap_prof_name'] = 'name',
    }
    parsdot1q2mapping(xml)
    for k, v in pairs(single_fields) do
        local vv = xml:match('<'..k..'>(.-)</'..k..'>')
        if vv then
            if (k == "encap_prof_name") then
                encap_prof_props.name = vv
            end
        end
    end
end

local mappinginstfound = function(s)
    encap_prof_props = {}
    populatemappings(s)
    local name = encap_prof_props.name
    encap_prof_props.name = nil
    encap_prof_insts[name] = {properties=encap_prof_props}
end

local parse_encap_profile = function(xml, ptn, callback)
    for s in string.gmatch(xml, ptn) do
        callback(s)
    end
end

EncapsulationProfile.enum = function()
    encap_prof_insts = {}
    local xml = Switch.run("show encapsulation profile |xml")
    parse_encap_profile(xml,"<ROW_encapsulation_profile>.-</ROW_encapsulation_profile>",mappinginstfound)
    return {instances=encap_prof_insts }
end

EncapsulationProfile.get = function(index)
    encap_prof_insts = {}
    local xml = Switch.run("show encapsulation profile segment "..index.." |xml")
    parse_encap_profile(xml,"<ROW_encapsulation_profile>.-</ROW_encapsulation_profile>",mappinginstfound)
    return {instances=encap_prof_insts }
end

EncapsulationProfile.has_instance = function(index)
    local status, result = pcall(EncapsulationProfile.get, index)
    if status then
        for k,v in pairs(result) do
            return true
        end
    end
    return false
end

EncapsulationProfile.set = function(index)
    local cmdtbl = {}
    table.insert(cmdtbl, 'config t')
    if request.name then
        logger("EncapsulationProfile.set cmd=" .. request.name)
        table.insert(cmdtbl, 'encapsulation profile segment '.. request.name)
    end
    if request.addMappings then
        logger("Add Mappings")
        for k,v in pairs (request.addMappings) do
            if type(v) ~= "table" then
                logger("Add mappings = " .. k .. "  " .. v);
            end
            if type(v) == "table" then
                local vlan = 0
                local bd = ""
                for key, value in pairs(v) do 
                    if type(value) ~= "table" then
                        if key == "dot1q" and type(value) == "string" then
                            vlan = value;
                        end
                        if key == "bridgeDomain" and type(value) == "string" then
                            bd = value;
                        end
                    end
                end
                logger ("vlan -- bd " .. vlan .. "  " .. bd)
                if vlan ~= 0 and bd ~= "" then
                    local buff = ""
                    buff = "dot1q " .. tostring(vlan) .. " bridge-domain " .. bd 
                    table.insert(cmdtbl, buff)
                end
            end
        end
    end
    if request.delMappings then
        logger("Del Mappings")
        for k,v in pairs (request.delMappings) do
            if type(v) ~= "table" then
                logger("Del mappings = " .. k .. "  " .. v);
            end
            if type(v) == "table" then
                local vlan = 0
                local bd = ""
                for key, value in pairs(v) do 
                    if type(value) ~= "table" then
                        if key == "dot1q" and type(value) == "string" then
                            vlan = value;
                        end
                        if key == "bridgeDomain" and type(value) == "string" then
                            bd = value;
                        end
                    end
                end
                logger ("vlan -- bd " .. vlan .. "  " .. bd)
                if vlan ~= 0 and bd ~= "" then
                    local buff = ""
                    buff = "no dot1q " .. tostring(vlan) .. " bridge-domain " .. bd 
                    table.insert(cmdtbl, buff)
                end
            end
        end
    end
    local cmd = table.concat(cmdtbl, ' ; ')
    logger("EncapsulationProfile.set cmd=" .. cmd)
    Switch.run(cmd)
end

EncapsulationProfile.delete = function(index) delete_instance(EncapsulationProfile,index,'encapsulation profile segment') end


local function wrap_one_instance(props_fn)
    return {
        has_instance = function() return true end,
        enum = function()
            local rv = {}
            if props_fn then rv = props_fn() end
            local instances = { [""] = { properties = rv } }
            return { instances = instances }
        end,
    }
end

return {
    hyper_v = wrap_one_instance(),
    switch_extension_info = wrap_one_instance(SwitchExtensionInfo),
    vsem_system_info = wrap_one_instance(VsemSystemInfo),
    network_segment_pool = NetworkSegmentPool,
    network_segment = NetworkSegment,
    ip_pool_template = IpPoolTemplate,
    uplink_port_profile = UplinkPortProfile,
    virtual_port_profile = VirtualPortProfile,
    vm_network = VmNetwork,
    vm_network_ports = VmNetworkPorts,
    bridge_domain = BridgeDomain,
    logical_network = LogicalNetwork,
    events = events,
    encapsulation_profile = EncapsulationProfile,
}

