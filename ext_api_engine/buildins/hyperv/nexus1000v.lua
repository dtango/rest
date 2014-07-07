-- NEXUS 1000V module
local _u = require 'utils'

local function decode_names_from_xml(tbl, name) 
    local name = name or 'name'
    local result = {}
    for k, v in pairs(tbl) do 
        local new_key = _u.fromXml(k)
        result[new_key] = v
        if result[new_key][name] then 
            result[new_key][name] = _u.fromXml(result[new_key][name])
        end
    end
    return result
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
            row[v] = value
            -- log_str = log_str .. v .. ' -> ' .. value
        end
        table.insert(rows, row)
        -- log_str = log_str .. "}\n"
    end
    -- logger(log_str)
    return rows
end

--
-- Nexus 1000V Switch object
--
local Switch = {
    const = { 
        empty = "<Empty>",
        empty_tag = "", -- to circumvent empty tag treated as nil
    },
}

setmetatable(Switch, {
    __index = function (table, key)
        logger('Switch: lookup [' .. key .. ']')
        if key == 'id' then
            local rv = Switch.show_parse('svs domain', {['switch_guid'] = 'id'})
            return rv.id or Switch.const.empty
        end
    end,
})


Switch._parse_table_rows = parse_table_rows

local function run(cmd)
    -- runs the cmd by vsh -c, if exit value != 0
    -- error will be raised
    -- other wise returns the string (stdout)
    
    -- Write commands to tmp file instead of string
    -- This ensured the error codes are geenreated properly
    local cmd_tmp_file = os.tmpname()
    local cmd_file = io.open(cmd_tmp_file, 'w')
    cmd_file:write(cmd:gsub(';', '\n') .. '\n')
    cmd_file:close()

    local stderrf = os.tmpname()
    local rtn = os.tmpname()
    -- local authtoken
    -- if ee_auth_token then authtoken = ' -p '..tostring(ee_auth_token)..' ' else authtoken = '' end
    local authtoken = ee_auth_token and ' -p '..tostring(ee_auth_token) or ''
    local vshcmd = '/isan/bin/vsh '.. authtoken ..' -f '..cmd_tmp_file..' 2>'..stderrf..' ; echo -n $? > '..rtn
    local f = assert(io.popen(vshcmd), "Cannot open vsh")
    local rv = f:read('*a') .. '/n'
    f:close()
    f = io.open(rtn,"r")
    local s = f:read("*all")
    f:close()
    os.execute("rm -rf "..rtn.." "..stderrf.." "..cmd_tmp_file)
    if tonumber(s) ~= 0 then
        for str in rv:gmatch('[%w%-%.\'_: ]*') do
            if (string.find(str, "ERROR:")) then
                errorMsg = "Command failed: "..prevStr.." "..str
                break
            end
            if (str~="")then
                prevStr = str
            end
        end
        logger("vsh command failed: "..vshcmd .. " code"..s)
        error({code=500, msg=errorMsg})
    end
    return rv
end

Switch.run = function (cmd)
    logger("run (" .. cmd .. ")")
    local status, err = pcall(run, cmd)
    if not status then 
        logger(" error calling (" .. cmd .. ")")
        error(err)
    end
    return err
end

Switch.show_parse = function(entity, props)
    -- Execute show command on an entity, get the result and parse individual properties
    -- Parameters:
    --   entity:     will be put into show <entity> | xml
    --   props:     table of properties that need to be parsed out with replcements key names
    if not entity then error("entity expected") end
    local status, str = pcall(Switch.run, "show " .. entity .. " | xml")
    if not status then return nil end
    local result = {}
    for pk, pv in pairs(props) do
        local m = string.match(str, "<" .. pk .. ">(.-)</" .. pk .. ">")
        if not m and string.match(str, "<" .. pk .. "%s*/>") then
            -- check if we have <tag></tag> or <tag/> situation          
            m = Switch.const.empty_tag
        end
        result[pv] = m
    end
    return result
end

Switch.show_table_parse = function(entity, props, table_key, instance_name)
    -- Execute show command on an entity, get the result table and parse individual instances and their properties
    -- Parameters:
    --   entity:     will be put into show <entity> | xml
    --   props:     table of properties that need to be parsed out with replcements key names
    --   [optional] table_key: normally table name is entity with '-' replaces by '_', if set, will used given key 
    --   [optional] instance_name: if specified will append "name <name>" to request
    if not entity then error("entity expected") end
    local table_key = table_key or _u.select(1, entity:gsub('[%-%s]', '_'))
    local cmd = "show " .. entity
    if instance_name and type(instance_name) == "string" then 
        cmd = cmd .. " name " .. instance_name
    end
    cmd = cmd .. " | xml"
    local s = Switch.run(cmd)
    local result = parse_table_rows(s, table_key, props)
    result = decode_names_from_xml(result)
    return result
end

Switch.allow_only_published = function(table, name, publish, remove_publish)
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
            local new_name = v[name]
            if v[publish] ~= Switch.const.empty_tag then new_name = v[publish] end
            results[new_name] = v
            results[new_name][name]= new_name
            if remove_publish then results[new_name][publish]  = nil end
        end
    end
    return results
end

Switch.parse_port_profiles = function(str, pl)
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

Switch.portProfiles = function(port_type)
    if not port_type then return {} end

    local s = run("show running-config port-profile")
    -- get defaults
    local defaultMaxPorts = string.match(s, "port%-profile%sdefault%smax%-ports%s(%d+)") or 512
    local portProfiles = Switch.parse_port_profiles(s, {
        ['guid'] = 'id',
        ['state'] = 'state',
        ['publish'] = 'publish',
        ['max-ports'] = 'maxPorts',
    })
    local rv = {}
    local switchId = Switch.id
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

return {
    ['switch'] = Switch,
}
