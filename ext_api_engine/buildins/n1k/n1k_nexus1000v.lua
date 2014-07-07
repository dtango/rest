-- NEXUS 1000V module
local _u = require('n1k_utils')
local M = {}

local function table_contains(tbl, elem)
    for _, value in pairs(tbl) do
        if value == elem then return true end
    end
    return false
end

local function run (cmd)
    local function _run(cmd)
        -- runs the cmd by vsh -c, if exit value != 0
        -- error will be raised
        -- other wise returns the string (stdout)
        local stderrf = os.tmpname()
        local rtn = os.tmpname()
        local authtoken = ee_auth_token and ' -p '..tostring(ee_auth_token) or ''
        local vshcmd = '/isan/bin/vsh '.. authtoken .. ' -c "'..cmd..'" '..' 2>'..stderrf..' ; echo -n $? > '..rtn
        local f = assert(io.popen(vshcmd), "Cannot open vsh")
        local rv = f:read('*a') .. '/n'
        f:close()
        f = io.open(rtn,"r")
        local s = f:read("*all")
        f:close()
        os.execute("rm -rf "..rtn.." "..stderrf)
        if tonumber(s) ~= 0 then
            logger("vsh command failed: "..vshcmd .. " code"..s)
            error({code=500, msg="vsh failed with "..s})
        end
        return rv
    end

    logger("run (" .. cmd .. ")")
    local status, err = pcall(_run, cmd)
    if not status then 
        local errorMsg = " error calling (" .. cmd .. ")"
        logger(" error calling (" .. cmd .. "):" .. err.msg)
        error(err)
    end
    return err
end

local function filter(func, tbl)
        local newtbl = {}
        for i, v in pairs(tbl) do
            if func(v) then
                newtbl[i] = v
            end
        end
        return newtbl
end

local function str_split (s, delim)
        local delim = delim or ','
        assert(type(delim) == "string" and string.len(delim) > 0,
            "bad delimiter")
        local start = 1
        local t = {} -- results table
        -- find each instance of a string followed by the delimiter
        while true do
            local pos = string.find(s, delim, start, true) -- plain find
            if not pos then
                break
            end
            table.insert(t, string.sub(s, start, pos - 1))
            start = pos + string.len(delim)
        end -- while
        -- insert final one (after last delimiter)
        table.insert(t, string.sub(s, start))
        return t
    end

local function map(func, tbl)
        local newtbl = {}
        for i, v in pairs(tbl) do
            newtbl[i] = func(v)
        end
        return newtbl
    end

local function parse_xml_tags(str, pl)
    local result = {}
    for plk, plv in pairs(pl) do
        local m = string.match(str, "<" .. plk .. ">(.-)</" .. plk .. ">")
        if m ~= nil then result[plv] = m end
    end
    return result
end

local function rekey_table (tbl, key_fn)
    local rv = {}
    for k, v in pairs(tbl) do
        rv[key_fn(k, v)] = v
    end
    return rv
end

local function count_interfaces(intf_type)
    local i = 0
    local rv = {}
    local str = M.run("show interface | xml")
    local t = _u.vsh_parse_xml_table_row(str, '__XML__OPT_Cmd_show_interface___readonly__', 'interface', { ['interface'] = 'interface', ['state'] = 'state' })
    for k, v in pairs(t) do
        local intf_n = string.match(k, intf_type .. "(%d+)")
        if intf_n ~= nil then
            i = i + 1
        end
    end
    return i
end

local function count_module_table(str, name, key_tag)
    local rows = 0
    local table_pattern = "<TABLE_" .. name .. ">(.-)</TABLE_" .. name .. ">"
    local row_pattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
    local table_content = string.match(str, table_pattern)
    if table_content == nil then return 0 end
    for row_content, _ in string.gmatch(table_content, row_pattern) do
        local module = {}
        local module_i = string.match(row_content, "<" .. key_tag .. ">(%d+)</" .. key_tag .. ">")
        if module_i ~= nil then
            rows = rows + 1
        end
    end
    return rows
end

local function count_active_port_profiles()
    local count = 0
    local s = M.run("show port-profile virtual usage | xml")
    for _, _ in string.gmatch(s, "<ROW_port_profile>(.-)</ROW_port_profile>") do count = count + 1 end
    return count
end

local function count_vlans()
    local s = M.run("show vlan summary | xml")
    local c = M.parse_xml_tags(s, { ['vlansum%-all%-vlan'] = 'all_vlan' })
    return c['all_vlan']
end

local function parse_table_row(str, name, tbl)
    local rows = {}
    local table_pattern = "<TABLE_" .. name .. ">(.-)</TABLE_" .. name .. ">"
    local row_pattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
    local table_content = string.match(str, table_pattern)
    if table_content == nil then return {} end
    local row_content = string.match(table_content, row_pattern)
    local module = {}
    --for tag, value in string.gmatch(row_content, "<([%w_]-)>(.-)</%1>") do
    --	if tbl[tag] ~= nil then module[tbl[tag]] = value else module[tag] = value end
    --end
    for k, v in pairs(tbl) do
        local _, value = string.match(row_content, "<(" .. k .. ")>(.-)</" .. k .. ">")
        module[v] = value
    end
    return module
end
    
local function parse_table_rows (str, name, tbl, key)
    local table_pattern = "<TABLE_" .. name .. ">(.-)</TABLE_" .. name .. ">"
    local row_pattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
    local table_content = string.match(str, table_pattern)
    if table_content == nil then return {} end
    local row_content = string.match(table_content, row_pattern)
    local rows = {}
    local i = 1
    for row_content, _ in string.gmatch(table_content, row_pattern) do
        local row = {}
        for k, v in pairs(tbl) do
            local _, value = string.match(row_content, "<(" .. k .. ")>(.-)</" .. k .. ">")
            row[v] = value
        end
        rows[i] = row
        i = i + 1
    end
    return rows
end

local function parse_table_rows_tbl(str, name, tbl, key)
    local table_pattern = "<TABLE_" .. name .. ">(.-)</TABLE_" .. name .. ">"
    local row_pattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
    local table_content = string.match(str, table_pattern)
    if table_content == nil then return {} end
    local row_content = string.match(table_content, row_pattern)
    local row = {}
    for row_content, _ in string.gmatch(table_content, row_pattern) do
        for k, v in pairs(tbl) do
            local _, value = string.match(row_content, "<(" .. k .. ")>(.-)</" .. k .. ">")
            row[v] = value
        end
    end
    return row
end

local function trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function filterTable(in_tbl, flt_fn)
    local out_tbl = {}
    for k, v in pairs(in_tbl) do
        if flt_fn(k, v) then out_tbl[k] = v end
    end
    return out_tbl
end

local function get_port_channel_tbl()
    local rv = {}
    local str = M.run(" show port-channel summary | xml")
    local port_channel = M.parse_table_rows(str, 'channel', { group = 'group', ['type'] = 'type', ['TABLE_member'] = 'members' }, 'group')
    for _, v in pairs(port_channel) do
        local k = v.group
        rv[k] = {}
        rv[k]['group'] = v.group
        rv[k]['type'] = v.type
        if v.members ~= nil then
            local members = {}
            for m in string.gmatch(v.members, "<ROW_member>(.-)</ROW_member>") do
                if m ~= nil then
                    local member = string.match(m, "<port>(.-)</port>")
                    if member ~= nil then members[#members + 1] = member end
                end
            end
            rv[k]['members'] = table.concat(members, ',')
        end
    end
    return rv
end

local function frameworkWrapper(fn, key)
    local wrap = {}
    wrap.enum = function()
        local rv = fn()
        local result = {}
        result.instances = {}
        if type(rv) == 'table' then
            if m.key then
                for k, v in pairs(rv) do
                    result.instances[v[key]] = {}
                    result.instances[v[key]].properties = v
                end
            else
                result.instances[''] = {}
                result.instances[''].properties = rv['']
            end
        end
        return result
    end

    wrap.get = function(idx)
        local rv = fn(idx)
        local result = {}
        if type(rv) == 'table' then
            if m.key then
                for k, v in pairs(rv) do
                    result.instances[v[key]] = {}
                    result.instances[v[key]].properties = v
                    return result
                end
            end
        end
    end

    return wrap
end
    
local function parse_module_table(str, name, key_tag, rename_keys, limit_fn)
    local rows = {}
    local table_pattern = "<TABLE_" .. name .. ">(.-)</TABLE_" .. name .. ">"
    local row_pattern = "<ROW_" .. name .. ">" .. "(.-)</ROW_" .. name .. ">"
    local table_content = string.match(str, table_pattern)
    if table_content == nil then return {} end
    for row_content, _ in string.gmatch(table_content, row_pattern) do
        local module = {}
        local module_i = 0
        for tag, value in string.gmatch(row_content, "<([%w_%-]-)>(.-)</%1>") do
            if tag == key_tag then module_i = value end
            if rename_keys[tag] ~= nil then module[rename_keys[tag]] = value else module[tag] = value end
        end
        if limit_fn ~= nil then
            if limit_fn(module) then rows[module_i] = module end
        else
            rows[module_i] = module
        end
    end
    return rows
end

local function mergeTables(firstT, secondT)
-- Merge second table into the first one
    for k, v in pairs(secondT) do
        firstT[k] = firstT[k] or {}
        for kk, vv in pairs(v) do
            firstT[k][kk] = vv
        end
    end
end

local function lines(str)
    local t = {}
    local function helper(line) table.insert(t, line) return "" end

    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end
    
local function count_vnic_on_vem(module)
    local s = M.run("show interface virtual module " .. module)
    local startsWithVeth = function(s) return s:match('^Veth') end
    return M.table_length(M.filter(startsWithVeth, M.lines(s)))
end

local function count_vm_on_vem(module)
    local str = M.run("show interface virtual module " .. module .. " vm")
    local startsWithVeth = function(s) return s:match('^Veth') end
    local subStrFrom28To50 = function(s) return s:sub(28, 50) end
    local lines = M.map(subStrFrom28To50, M.filter(startsWithVeth, M.lines(str)))
    local vms = {}
    for i, vmName in pairs(lines) do vms[vmName] = true end
    return M.table_length(vms)
end

local function table_length(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end
    
local function getModuleInfo(module)
    local s = M.run("show module " .. module .. " | xml")
    return s and {
        ip = string.match(s, "<srvip>(.-)</srvip>") or '0.0.0.0',
        name = string.match(s, "<srvname>(.-)</srvname>") or '',
        index = tonumber(module)
    } or {}
end

local function get_module_ip_by_idx(module)
    return M.getModuleInfo(module).ip
end

local function get_vnics_for_module(module)
    local vnics = {}
    local str = M.run("show interface virtual | xml")
    for row in string.gmatch(str, "<ROW_interface>(.-)</ROW_interface>") do
        if string.match(row, "<module>" .. module .. "</module>") then
            local vnic = string.match(row, "<interface>(.-)</interface>")
            if vnic ~= nil then vnics[vnic] = vnic end -- be able to table lookup
        end
    end
    return vnics
end

local function get_vnics_description(module)
    local runCmd = "show interface virtual | xml"
    local descriptionFields = { interface = 'interface', adapter = 'adapter', module = 'module', host = 'host', owner = 'owner' }
    local vnics = {}
    local str = M.run(runCmd)
    for row in string.gmatch(str, "<ROW_interface>(.-)</ROW_interface>") do
        local vnic = {}
        for k, v in pairs(descriptionFields) do
            vnic[v] = string.match(row, "<" .. k .. ">(.-)</" .. k .. ">")
        end
        if not module or (module and vnic.module == module) then
            vnics[vnic.interface] = vnic
        end
    end
    return vnics
end

local function get_uplinks_for_module(module)
    local uplinks = {}
    local module_ip = M.get_module_ip_by_idx(module)
    local moduleServerName = M.getModuleInfo(module).name
    local str = M.run("show port-profile virtual usage | xml")
    for row in string.gmatch(str, "<ROW_port_profile>(.-)</ROW_port_profile>") do
        if string.match(row, "<owner>" .. moduleServerName .. "</owner>") then
            local tbl_interface = string.match(row, "<TABLE_interface>(.-)</TABLE_interface>")
            if tbl_interface == nil then return uplinks end
            for row_interface in string.gmatch(tbl_interface, "<ROW_interface>(.-)</ROW_interface>") do
                local uplink = string.match(row_interface, "<interface>(.-)</interface>")
                if uplink ~= nil then uplinks[#uplinks + 1] = uplink end
            end
        end
    end
    return uplinks
end

local function get_port_profiles_for_module(module)
    local pprofiles = {}
    local module_ip = M.get_module_ip_by_idx(module)
    local moduleServerName = M.getModuleInfo(module).name
    local vnicsForModule = get_vnics_description(module)
    local str = M.run("show port-profile virtual usage | xml")
    for row in string.gmatch(str, "<ROW_port_profile>(.-)</ROW_port_profile>") do
        local owners = {}
        for owner in string.gmatch(row, "<owner>(.-)</owner>") do
            owners[#owners + 1] = owner
        end
        -- local interfaces = {}
        -- for interface in string.gmatch(row, "<interface>(.-)</interface>") do
        --    interfaces[#interfaces + 1] = interface
        -- end

        --if string.match(row, "<owner>" .. moduleServerName .. "</owner>") or
        --   string.match(row, "<owner>Module " .. module .. "</owner>") or
        if table_contains(owners, moduleServerName) or table_contains(owners, "Module " .. module) then
            local pprofile = string.match(row, "<profile_name>(.-)</profile_name>")
            if pprofile ~= nil then pprofiles[#pprofiles + 1] = pprofile end
        end
        -- check if Veth PGs
        for _, v in pairs(vnicsForModule) do
            if table_contains(owners, v.owner) then
                local pprofile = string.match(row, "<profile_name>(.-)</profile_name>")
                if pprofile ~= nil then pprofiles[#pprofiles + 1] = pprofile end
            end
        end
    end
    return pprofiles
end


local function string_to_boolean(s)
    local boolean_true_tbl = { enabled = true, yes = true, en = true }
    if boolean_true_tbl[string.lower(s)] ~= nil then
        return 'true'
    end
    return 'false'
end

local function boolean_to_string(b)
    if type(b) == 'boolean' then
        return b and 'true' or 'false'
    else return b
    end
end


local function getInterfaceVlans(name)
    local str = M.run("show interface switchport | xml")
    local fields = {
        ['oper_mode'] = 'mode',
        ['access_vlan'] = 'accessVlan',
        ['native_vlan'] = 'nativeVlan',
        ['trunk_vlans'] = 'trunkVlans'
    }
    local results = _u.vsh_parse_xml_table_row(str, '__XML__OPT_Cmd_show_interface_switchport___readonly__', 'interface', fields)
    for _, v in pairs(results) do
        if v.mode == 'trunk' then v.vlans = v.trunkVlans
        elseif v.mode == 'access' then v.vlans = v.accessVlan
        end
    end
    return name and results[name] or results
end

-- Public interface for module nexus1000v
M.run = run
M.parse_xml_tags = parse_xml_tags
M.boolean_to_string = boolean_to_string
M.lines = lines
M.parse_table_rows = parse_table_rows
M.rekey_table = rekey_table
M.filterTable = filterTable
M.getInterfaceVlans = getInterfaceVlans
M.get_port_channel_tbl = get_port_channel_tbl
M.parse_table_row = parse_table_row
M.map = map
M.trim = trim
M.str_split = str_split
M.getInterfaceVlans = getInterfaceVlans
M.mergeTables = mergeTables
M.parse_module_table = parse_module_table
M.filter = filter
M.count_vm_on_vem = count_vm_on_vem
M.get_port_profiles_for_module = get_port_profiles_for_module
M.getModuleInfo = getModuleInfo
M.table_length = table_length
M.get_vnics_for_module = get_vnics_for_module
M.get_module_ip_by_idx = get_module_ip_by_idx

return M
