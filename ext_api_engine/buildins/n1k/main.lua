local _n = require('n1k_nexus1000v')
local _u = require('n1k_utils')

local function portProfileUsage()
    -- return structure
    -- {
    --  'ppName1' = {
    --      interfaces = {
    --          'interface_name1' = { 'adapter' = 'vmnic1', owner = '10.10.10.10' },
    --          'interface_name2' = { 'adapter' = 'vmnic3', owner = '11.11.11.11' },
    --           ...................................................................
    --      }
    --   },
    --   ...........................................................................
    -- }
    local portProfiles = {}
    local s = _n.run("show port-profile virtual usage | xml")
    local ppTbl = s:match('<TABLE_port_profile>(.-)</TABLE_port_profile>') or ''
    for ppRow in s:gmatch('<ROW_port_profile>(.-)</ROW_port_profile>') do
        local ppName = ppRow:match('<profile_name>(.-)</profile_name>')
        ppName = _u.fromXml(ppName)
        logger('ppName='..ppName)
        if ppName then
            -- portProfiles[ppName] = {}
            portProfiles[ppName] = {name = ppName}
            portProfiles[ppName].interfaces = {}
            portProfiles[ppName].interfacesCount = 0 -- keep interfaces count to speed up counting
            local tblInf = ppRow:match('<TABLE_interface>(.-)</TABLE_interface>')
            if tblInf then
                for inf in tblInf:gmatch('<ROW_interface>(.-)</ROW_interface>') do
                    local i = inf:match('<interface>(.-)</interface>')
                    if i then
                        local a = inf:match('<adapter>(.-)</adapter>') or ''
                        local o = inf:match('<owner>(.-)</owner>') or ''
                        portProfiles[ppName].interfaces[i] = { adapter = a, owner = o }
                        portProfiles[ppName].interfacesCount = portProfiles[ppName].interfacesCount + 1
                    end
                end
            end 
        end
    end
    return portProfiles
end


local function parseInterfaces()
    local parseXInterface = function(str, tbl)
        local interface = {}
        for k, v in pairs(tbl) do
            interface[v] = string.match(str, "%<" .. k .. "%>(.-)%<%/" .. k .. "%>")
        end
        return interface
    end

    local interfaces = {}
    local str = _n.run("show interface | xml")
    local tblInterface = string.match(str, "%<TABLE_interface%>(.*)%<%/TABLE_interface%>")
    local ptnRowInterface = "%<ROW_interface%>(.-)%<%/ROW_interface%>"
    if tblInterface then
        for row in string.gmatch(tblInterface, ptnRowInterface) do
            local interface
            if string.find(row, '<veth_hw_desc>Virtual</veth_hw_desc>') then
                -- parse Vethernet
                interface = parseXInterface(row, {
                    ['interface'] = 'name',
                    ['state'] = 'status',
                    ['veth_port_profile'] = 'portGroup',
                    ['veth_hw_addr'] = 'mac',
                    ['veth_hw_desc'] = 'type'
                })
                if interface then interfaces[interface.name] = interface end
            elseif string.find(row, '<eth_hw_desc>Port-Channel</eth_hw_desc>') then
                -- parse Port-Channel
                interface = parseXInterface(row, {
                    ['interface'] = 'name',
                    ['state'] = 'status',
                    ['eth_hw_desc'] = 'ethernet',
                    ['eth_hw_desc'] = 'type',
                    ['eth_mtu'] = 'mtu',
                    ['eth_speed'] = 'speed',
                    ['eth_inpkts'] = 'packetsRx',
                    ['eth_outpkts'] = 'packetsTx',
                })
                if interface then interfaces[interface.name] = interface end
            elseif string.find(row, '<vem_eth_hw_desc>Ethernet</vem_eth_hw_desc>') then
                --parse Ethernet
                interface = parseXInterface(row, {
                    ['interface'] = 'name',
                    ['state'] = 'status',
                    ['vem_eth_hw_desc'] = 'ethernet',
                    ['vem_eth_mtu'] = 'mtu',
                    ['vem_eth_speed'] = 'speed',
                    ['vem_eth_inpkts'] = 'packetsRx',
                    ['vem_eth_outpkts'] = 'packetsTx',
                    ['vem_eth_port_profile'] = 'portProfile'
                })
            end
            if interface then interfaces[interface.name] = interface end
        end
    end
    return interfaces
end

local SimpleCallPrototypeNoInstance = {}
SimpleCallPrototypeNoInstance.new = function ()
    local self = {}
    self.all_properties = function() return {} end
    self.enum = function() 
        local properties = self.all_properties()
        -- no instances, just properties
        local single_instance = {properties = properties}
        return {instances = {[''] = single_instance}}
    end
    return self
end

local MultiCallPrototype = {}
MultiCallPrototype.new = function(name, key)
    local self = {}
    name = name or ''
    key = key or 'name'
    self.list_all = function() return {} end
    self.has_instance = function (index) return self.list_all()[index] and true or false end
    self.enum = function () 
        return _u.toinstancesSub(_u.indexTable(self.list_all()) or {}, key)
    end
    -- self.get = function(index) return {instances = {[index] = self.enum().instances[index] }} end
    self.get = function(index)
        local rv = self.list_all()[index]
        if not rv or _u.is_empty(rv) then _u.index_not_found_error(index) end
        return _u.toinstances({[index] = rv}) 
    end
    self.create = function(index) 
         if self.has_instance(index) then error( name .. '"'..index..'" already exists') end
         self.set(index)
    end
    self.set = function(index) error( name .. ' modification is not implemented.') end
    self.delete = function(index) error( name .. 'deletion is not implemented.') end
    self.query = function() 
        local cmd, arg
        _, _, cmd, arg = string.find(_G.query_string, "([^=]+)=?(.*)")
        local rv
        if type(self.q[cmd])=="function" then
            rv = self.q[cmd](arg)
        end
        return rv
    end
    -- Map of queries
    self.q = {} -- map of queries
    self.q.bulk = function(arg)
        -- Query format: ?bulk=<start>-<finish>
        local q_pattern = "(%d*)-(%d+)"
        if string.len(arg) == 0 then
        else
            local start, finish
            _,_,start,finish = string.find(arg, q_pattern)
            if not finish then error('Invalid query format. Expected "' .. q_pattern .. '"') end
            start = start or 1
            local all_instances = self.list_all()
            local instances = {}
            for i = start, finish do instances[i] = all_instances[i] end
            return _u.toinstancesSub(instances, key)
        end
    end

    
    return self
 end



local Summary = SimpleCallPrototypeNoInstance.new()
Summary.all_properties = function ()
    local parse_xml_tags = _n.parse_xml_tags
    local rv = {}

    local s = _n.run("show interface mgmt0")
    local _, _, rv_ip = string.find(s, "Internet%s-Address%s-is%s-(%d-%.%d-%.%d-%.%d-)%/%d-")

    s = _n.run("show version")
    local rs = _u.vsh_parse(s, '\nSoftware', { ['system'] = 'system' })
    local rv_version = rs[1].system
    local _, _, rv_name = string.find(s, "%s+Device%sname:%s*(.-)%s")

    -- s = _n.run("show svs conn | xml")
    -- local rv_vc_conn = parse_xml_tags(s,
    --     {
    --         ['ipaddress'] = 'vc_ipaddress',
    --         ['conn%-oper%-status'] = 'status',
    --         ['dvs%-uuid'] = 'uuid',
    --         ['conn%-name'] = 'connectionName',
    --         ['datacenter%-name'] = 'datacenterName'
    --     })

    local str = _n.run("show svs domain | xml")
    local v = parse_xml_tags(str, { ['svs_mode'] = 'mode' })
    local rv_mode = v["mode"]

    str = _n.run("show redundancy status | xml")
    v = parse_xml_tags(str, { ['this_sup_int_st'] = 'haStatus' })
    local rv_ha_status = _n.boolean_to_string(v.haStatus == 'Active with HA standby')

    str = _n.run("show switch edition | xml")
    local rv_switch_mode = parse_xml_tags(str, { ['switch_mode'] = 'switchMode' })

    return {
        ip = rv_ip,
        name = rv_name,
        version = rv_version,
        -- connectionName = rv_vc_conn.connectionName,
        -- datacenterName = rv_vc_conn.datacenterName,
        -- vcIpaddress = rv_vc_conn.vc_ipaddress,
        -- vcStatus = rv_vc_conn.status,
        -- vcUuid = rv_vc_conn.uuid,
        haStatus = rv_ha_status,
        mode = rv_mode,
        switchMode = rv_switch_mode.switchMode
    }
end

-------------------------------------
-- License
-------------------------------------
local License = MultiCallPrototype.new("License", 'type')
License.list_all = function ()
    local str = _n.run("show license usage | xml")
    local licenses = _n.parse_table_rows(str, 'lic_usage', { ['feature_name'] = 'type', ['status'] = 'status' }, 'type')
    licenses = _n.rekey_table(licenses, function(k, v) return v.type end)
    for k, vLicenses in pairs(licenses) do
        str = _n.run("show license usage " .. k .. " | xml")
        local license = _n.parse_xml_tags(str,
            {
                ['avail_lics'] = 'available',
                ['inuse_lics'] = 'inUse',
                ['inuse_eval_lics'] = 'evalInUse',
                ['shortest_expiry'] = 'expires'
            })
        vLicenses.available = license.available
        vLicenses.expires = license.expires
        vLicenses.used = (tonumber(license.inUse) or 0) + (tonumber(license.evalInUse) or 0)
    end
    return licenses
end

-------------------------------------
-- Uplink
-------------------------------------
local Uplink = MultiCallPrototype.new("Uplinks")
Uplink.list_all = function ()
    local port_channels
    local is_ethernet_type = function(k, v) return v.ethernet ~= nil end
    local interfaces = parseInterfaces()
    local uplinks = _n.filterTable(interfaces, is_ethernet_type)
    local allVlans = _n.getInterfaceVlans()
    for k, v in pairs(uplinks) do
        logger("show interface " .. v.name .. " brief | xml")
        str = _n.run("show interface " .. v.name .. " brief | xml")
        local rv_brief = _n.parse_xml_tags(str, { ['vlan'] = 'vlans', ['portmode'] = 'mode', ['portchan'] = 'portChannel' })
        local module = string.match(v.name, "Ethernet%s*(%d+)/")
        if module ~= nil then v.module = module end
        for breif_k, brief_v in pairs(rv_brief) do
            v[breif_k] = brief_v
        end
        --set vlans
        v.vlans = allVlans[v.name].vlans
        --check for port-channel
        if v.portChannel ~= nil then
            --get port-channel data
            port_channels = port_channels or _n.get_port_channel_tbl()
            local p_channel = port_channels[v.portChannel]
            v.portChannelType = p_channel.type
            v.portChannelMembers = p_channel.members
        end
        -- get CDP uplink
        str = _n.run("show cdp neighbors interface " .. v.name .. " detail | xml")
        local rv_cdp = _n.parse_table_row(str, "cdp_neighbor_detail_info", { ['device_id'] = 'cdpSwitch', ['port_id'] = 'cdpPort', ['nativevlan'] = 'cdpNativeVlan' })
        for cdp_k, cdp_v in pairs(rv_cdp) do
            v[cdp_k] = cdp_v
        end
    end

    return uplinks
end

-------------------------------------
-- VNIC
-------------------------------------
local Vnic = MultiCallPrototype.new("Vnics", 'vnic')
Vnic.list_all = function ()
    local run = _n.run
    local xmlTableRow = _u.vsh_parse_xml_table_row

    local rv = {}
    local str = run("show interface virtual | xml")
    local vnics = xmlTableRow(str, '__XML__OPT_Cmd_vim_show_intf_virt___readonly__', 'interface',
        { interface = 'vnic', owner = 'vm', adapter = 'adapter', module = 'module', host = 'hostIP' })

    str = run("show interface virtual port-mapping | xml")
    local vnic_mapping = xmlTableRow(str, '__XML__OPT_Cmd_vim_show_intf_virt_port_map___readonly__', 'interface',
        { hport = 'dvport' })
    for k, v in pairs(vnic_mapping) do
        if vnics[k] == nil then
            -- will create interface that in not participating
            vnics[k] = {}
            vnics[k].vnic = k
        end
        vnics[k].dvport = v.dvport
    end

    str = run("show interface virtual description | xml")
    local vnic_description = xmlTableRow(str, '__XML__OPT_Cmd_vim_show_intf_virt_description___readonly__', 'interface',
        { description = 'description' })
    for k, v in pairs(vnics) do
        if not v.vm or not v.adapter then
            v.vm, v.adapter = unpack(_n.map(_n.trim, _n.str_split(vnic_description[k].description)))
        end
    end

    local allVlans = _n.getInterfaceVlans()
    local interfaces = parseInterfaces()
    for _, vnic_rv in pairs(vnics) do
        -- get veth details
        vnic_rv.status = interfaces[vnic_rv.vnic].status
        vnic_rv.portGroup = interfaces[vnic_rv.vnic].portGroup
        vnic_rv.mac = interfaces[vnic_rv.vnic].mac
        --set vlans
        vnic_rv.vlans = allVlans[vnic_rv.vnic] and allVlans[vnic_rv.vnic].vlans or ''
        rv[vnic_rv.vnic] = vnic_rv
    end
    return rv
end

-------------------------------------
-- Port Profile
-------------------------------------
local PortProfile = MultiCallPrototype.new("PortProfiles")
PortProfile.list_all = function ()
    local ppUsage = portProfileUsage() -- performance speedup
    local s = _n.run("show port-profile | xml")
    local portProfiles = {}
    local tbl = {
        ['profile_name'] = 'name',
        ['type'] = 'type',
        ['status'] = 'status',
        ['sys_vlans'] = 'systemVlans',
        ['max_ports'] = 'maxPorts',
        ['min_ports'] = 'minPorts',
        ['eval_cfg'] = 'evalCfg'
    }
    local endPP = 0
    while endPP ~= nil do
        local portProfile = {}
        portProfile.vlans = '' -- do not store vlans in the table, store in the string
        local startPP, i = s:find('<profile_name>', endPP)
        endPP = s:find('<profile_name>', i)
        local portProfileStr = s:sub(startPP, endPP)
        local ppVlans = {}
        for k, v in pairs(tbl) do
            for value in portProfileStr:gmatch('<' .. k .. '>(.-)</' .. k .. '>') do
                if v == 'evalCfg' then
                    local mode = value:match("switchport mode%s*(.*)%s*$")
                    local native = value:match("switchport trunk native vlan (%d+)")
                    if native then portProfile.nativeVlan = native end
                    if mode then
                        portProfile.mode = mode
                    elseif portProfile.mode and portProfile.mode == 'trunk' then
                        local vlans = value:match("switchport trunk allowed vlan%s%D*([%d,%-]*)%s*$")
                        if vlans then ppVlans[#ppVlans + 1] = vlans end
                    elseif portProfile.mode and portProfile.mode == 'access' then
                        local vlans = value:match("switchport access vlan%s*(.*)%s*$")
                        if vlans then ppVlans[#ppVlans + 1] = vlans end
                    end
                else
                    portProfile[v] = value
                end
            end
        end
        portProfile.name = _u.fromXml(portProfile.name)
        portProfile.vlans = table.concat(ppVlans, ',')
        portProfile.usedPorts = ppUsage[portProfile.name] and ppUsage[portProfile.name].interfacesCount or 0 --performance speedup
        -- table.insert(portProfiles, portProfile)
        portProfiles[portProfile.name] = portProfile
    end
    return portProfiles
end

local Vem = MultiCallPrototype.new("VEMs", 'module')
Vem.list_all = function ()
        local parse_xml_tags = _n.parse_xml_tags
    local mergeTables = _n.mergeTables
    local parse_module_table = _n.parse_module_table
    local filter = _n.filter
    local run = _n.run
    local str = run("show module vem | xml")
    local rv_info = parse_module_table(str, 'modinfo', 'modinf',
        { modinf = 'module', modtype = 'type', srvname = 'name', srvip = 'ip' })
    mergeTables(rv_info, parse_module_table(str, 'modsrvinfo', 'modsrv',
        { modsrv = 'module', modtype = 'type', srvname = 'name', srvip = 'ip' }))
    mergeTables(rv_info, parse_module_table(str, 'modver', 'modver',
        { modver = 'module', sw = 'version', hw = 'esxVersion' }))
    mergeTables(rv_info, parse_module_table(str, 'modmacinfo', 'modmac',
        { mac = 'mac' }))

    str = run("show module vem license-info | xml")
    local rv_vem_lic = parse_module_table(str, 'vem_licinfo', 'modNo',
        { modNo = 'module', lic_status = 'license', num_sockets = 'nSockets', lic_usage = 'licenseUsage' })
    -- only add modules that are presend in 'show module' command
    rv_vem_lic = filter(function(v) return rv_info[v.module] end, rv_vem_lic)
    mergeTables(rv_info, rv_vem_lic)
    --get Datacenter name
    -- str = run("show svs conn | xml")
    -- local rv_vc_conn = parse_xml_tags(str, { ['datacenter%-name'] = 'datacenterName' })

    -- get the module state and if absent make sure it is removed
    str = run("show module vem mapping | xml")
    local rv_mapping = parse_module_table(str, 'vem_map', 'modNo', { modNo = 'module', status = 'status' })
    for _, v in pairs(rv_mapping) do
        if v.status == 'absent' then
            logger('remove module ' .. v.module .. ' from /vem output')
            rv_info[v.module] = nil
        end
    end

    -- Count # of VMs and VNics and max
    str = run("show resource-availability vethports | xml")
    local vethPerModMax = string.match(str, "<permodmax>(%d+)</permodmax>") --"<mod%-max>(%d+)</mod%-max>")
    local vnicLimits = parse_module_table(str, "host", "mod", { ["used"] = 'used', ["avail"] = 'avail' })
    -- Works only on CX/CY
    -- str = run("show resource-availability mac-address-table | xml")
    -- local macPerModMax = string.match(str, "<permodmax>(%d+)</permodmax>")
    -- local macLimits = parse_module_table(str, "macaddr", "modid", { ["used"] = 'used', ["avail"] = 'avail' })

    local defaultVnicLimitsUsed = 0
    local defaultMaxLimits = 0
    for k, v in pairs(rv_info) do
        rv_info[k].vethUsed = vnicLimits[k] and vnicLimits[k].used or defaultVnicLimitsUsed
        rv_info[k].vethMax = vethPerModMax
        -- rv_info[k].macUsed = macLimits[k] and macLimits[k].used or defaultMaxLimits
        -- rv_info[k].macMax = macPerModMax
        rv_info[k].numVM = _n.count_vm_on_vem(k)
        -- rv_info[k].datacenterName = rv_vc_conn.datacenterName
    end
    return rv_info
end

local VemPortProfile = MultiCallPrototype.new("VEM Port Profiles")
VemPortProfile.list_all = function ()
    local module = _G.classpath[#_G.classpath - 1].index
    local cls = _G.classpath[#_G.classpath - 1].classname
    local vemPortProfiles = {}
    local names = _n.get_port_profiles_for_module(module)
    if names == nil then return {} end
    local allData =  _u.map_rekey(PortProfile.list_all(), function (k,v) return v.name end, _u.identity)
    for _, v in pairs(names) do
        vemPortProfiles[v] = allData[v]
    end

    local ppUsage = portProfileUsage()
    local moduleIndex = _G.classpath[#_G.classpath - 1].index
    local moduleInfo = _n.getModuleInfo(moduleIndex)
    local matchByServerNameOrModuleIndex = function(interface)
        return interface.owner == moduleInfo.name or interface.owner == 'Module ' .. moduleInfo.index
    end
    for k, v in pairs(vemPortProfiles) do
        local ppName = v.name
        if ppUsage[ppName] then
            local interfaces =  ppUsage[ppName].interfaces -- _n.filter(matchByServerNameOrModuleIndex, ppUsage[ppName].interfaces)
            if interfaces then
                v.usedPorts = _n.table_length(interfaces)
            end
        end
    end
    return vemPortProfiles
end

local VemVnic = MultiCallPrototype.new("VEM VNICs", 'vnic')
VemVnic.list_all = function ()
    local module = _G.classpath[#_G.classpath - 1].index
    local cls = _G.classpath[#_G.classpath - 1].classname
    local names = _n.get_vnics_for_module(module)
    if names == nil then return {} end
    return  _u.map_rekey(Vnic.list_all(), function (k,v) return v.vnic end, _u.identity)
end

local VemUplink = MultiCallPrototype.new("VEM Uplinks")
VemUplink.list_all = function ()
    local module = _G.classpath[#_G.classpath - 1].index
    local allUplinks = Uplink.list_all()
    local match_module = function (k,v) return v.module == module end
    local function filter_retain_key(tbl, fn)
        -- filter table retaining key: keep only values that for which the fn is True
        local m = {}
        for k, v in pairs(tbl) do if fn(k,v) then m[k] = v end end
        return m 
    end
    return filter_retain_key(allUplinks, match_module)
end

local _blank = { 
	has_instance = function() return true end,
    enum = function() return { instances = { [""] = { properties = {} } } } end,
}

return {
    n1k = _blank,
    summary = Summary,
    license = License,
    uplink  = Uplink,
    vnic    = Vnic,
    portProfile = PortProfile,
    vem = Vem,
    vemVnic = VemVnic,
    vemPortProfile = VemPortProfile,
    vemUplink = VemUplink,
}