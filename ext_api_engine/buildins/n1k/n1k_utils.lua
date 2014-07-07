--
-- Various Utils
-- To include use  _u = require 'utils'
local M = {}

local function trimString(value)
	return string.match(value, "^%s*(.-)%s*$")
end

local function trimTableValues(tbl)
	local rv = {}
    for k, v in pairs(tbl) do
        rv[k] = trimString(v)
    end
    return rv
end

local function trim(value)
	if type(value) == "table" then
    	return trimTableValues(value)
    elseif type(value) == "string" then
    	return trimString(value)
	end
end

local function split_newlines(s)
    local ts = {}
    if not s then return ts end
    local posa = 1
    while 1 do
        local pos, chars = s:match('()([\r\n].?)', posa)
        if pos then
            if chars == '\r\n' then pos = pos + 1 end
            local line = s:sub(posa, pos)
            ts[#ts + 1] = line
            posa = pos + 1
        else
            local line = s:sub(posa)
            if line ~= '' then ts[#ts + 1] = line end
            break
        end
    end
    return ts
end

local function splitTrimJoin(s, delim)
    return table.concat(trim(split_newlines(s)), delim)
end

local function propertiesToInstances(props)
    local instances = {}
    for k, v in pairs(props) do instances[k] = { properties = v } end
    return { instances = instances }
end

local function propertiesToInstancesSubName(props, name)
    -- convert to output instances substituting name for key
    local name = name or 'name'
    local instances = {}
    for k, v in pairs(props) do
        if v[name] then 
            instances[v[name]] = { properties = v } 
        end
    end
    return { instances = instances }
end

local function  string_to_boolean(value)
	if type(value) == 'boolean' then return value 
	elseif type(value) == 'string' then 
    	local boolean_true_tbl = { enabled = true, yes = true, en = true }
    	if boolean_true_tbl[string.lower(value)] ~= nil then
        	return 'true'
    	end
    	return 'false'
	end
end

local function key_value_iterator(iterable)
    return coroutine.wrap(function() 
        for k,v in pairs(iterable) do coroutine.yield(k,v) end end)
end

local default_iterator = pairs

local function each_kv(table, fn)
    -- Iterate over key/ value table
    for k,v in pairs(table) do fn(k,v) end 
    return table
end

local function map_kv(table, fn)
    -- map table(k,v) => table(k,v')
    local m = {}
    for k,v in pairs(table) do m[k] = fn(v) end
    return m
end

local function map_rekey(table, key_fn, map_fn)
    -- map & rekey: table(k,v) =>table(k',v')
    -- key function gets both key and value as parameter
    local m = {}
    for k,v in pairs(table) do m[key_fn(k,v)] = map_fn(v) end
    return m
end

local function is_empty(tbl)
    return next(tbl) == nil
end

local function join(tbl, separator)
    return table.concat(tbl, separator)
end

local function identity(v) return v end

local function detect_kv(table, fn)
    -- find the first element for which the funciton is true and return key/value pair
    for k,v in pairs(table) do
        if fn(v) then return k, v end
    end
    return nil
end

local function wrap_with_tag(str, tag)
    if not tag then return str end 
    local str = str or ""
    return '<' .. tag .. '>' .. str .. '</' .. tag .. '>'
end

local function select (n, ...) return arg[n] end

local function indexTable(tbl)
    -- Convert table to array with indexes
    local outTbl = {}
    for _, v in pairs(tbl) do table.insert(outTbl, v) end
    return outTbl 
end

local function filter(tbl, fn)
    -- filter table: keep only values that for which the fn is True
    local m = {}
    for k, v in pairs(tbl) do
        if fn(k,v) then table.insert(m,v) end
    end
    return m 
end


local function parse (s, cn, pl)
    -- parse vsh output
    -- s: vsh output
    -- cn: object name
    -- pl: property list table
   local result = {}
   local ptn = "("..cn..".-\n)(%s.-)\n\n"
   --print(ptn)
   --local idx_ptn = "^[%a]+[%w_%-]*%s+([%w_%-]+)[:]-\n$"
   local idx_ptn = "^[%a]+[%w_%-]*%s+(.+)[:]-\n$"
   --local prop_ptn = "%s+([%w]+[%w%s%-_]-):%s-([%w_%-%s%p0-9]-)\n"
   local prop_ptn = "%s+([%w]+[%w%s%-_]-):%s-(.-)\n"

   for classnv, propset in string.gmatch(s, ptn) do
      print(classnv,"--------------\n", propset)
      if string.find(classnv, "^"..cn) then
          local _,_,idx = string.find(classnv, idx_ptn)
          if idx == nil then
             table.insert(result, {})
             idx = #result
          end
          result[idx] = {}
          for plk, plv in pairs(pl) do
             local p = "%s+"..plk..":%s*(.-)\n"
             local _,_,pv = string.find(propset, p)
             result[idx][plv] = pv
          end
       end
   end

   return result
end

local function parse_xml_table_row (s, cn, keyname, pl)
   local result = {}
   local ptn = "%<"..cn.."%>.-%<TABLE_interface%>(.*)%<%/TABLE_interface%>.-%<%/"..cn.."%>"
   local rowptn = "%<ROW_interface%>(.-)%<%/ROW_interface%>"
   local rows
   _,_,rows = string.find(s, ptn)
   if (nil ~= rows) then
   for row in string.gmatch(rows, rowptn) do
      local _,_,keyval = string.find(row, "%<"..keyname.."%>(.-)%<%/"..keyname.."%>")
      if keyval ~= nil then 
         result[keyval]={}
         for k, v in pairs(pl) do
            _,_,result[keyval][v]= string.find(row,"%<"..k.."%>(.-)%<%/"..k.."%>") 
         end
      end
   end
   end
   return result
end

local function index_not_found_error(index)
    local index = index or '?'
    error({code=404, msg="Not Found", detail='Instance "'..index..'" does not exist'})
end

local function from_xml(s) 
  local value = s;
  value = string.gsub(value, "&#x([%x]+)%;",
      function(h) 
        return string.char(tonumber(h,16)) 
      end);
  value = string.gsub(value, "&#([0-9]+)%;",
      function(h) 
        return string.char(tonumber(h,10)) 
      end);
  value = string.gsub (value, "&quot;", "\"");
  value = string.gsub (value, "&apos;", "'");
  value = string.gsub (value, "&gt;", ">");
  value = string.gsub (value, "&lt;", "<");
  value = string.gsub (value, "&amp;", "&");
  return value;
end
local function to_xml(s) 
  local value = s;
  value = string.gsub (value, "&", "&amp;");    -- '&' -> "&amp;"
  value = string.gsub (value, "<", "&lt;");   -- '<' -> "&lt;"
  value = string.gsub (value, ">", "&gt;");   -- '>' -> "&gt;"
  --value = string.gsub (value, "'", "&apos;"); -- '\'' -> "&apos;"
  value = string.gsub (value, "\"", "&quot;");  -- '"' -> "&quot;"
  -- replace non printable char -> "&#xD;"
  value = string.gsub(value, "([^%w%&%;%p%\t% ])",
        function (c) 
          return string.format("&#x%X;", string.byte(c)) 
          --return string.format("&#x%02X;", string.byte(c)) 
          --return string.format("&#%02d;", string.byte(c)) 
        end);
  return value;
end

-- Public interface for module Utils
M.trim = trim
M.toinstances = propertiesToInstances
M.toinstancesSub =propertiesToInstancesSubName
M.splitN = split_newlines
M.splitTrimJoin = splitTrimJoin
M.toboolean = string_to_boolean
M.each = each_kv
M.map = map_kv
M.map_rekey = map_rekey
M.join = join
M.identity = identity
M.detect = detect_kv
M.tag_wrap = wrap_with_tag
M.is_empty = is_empty
M.select = select
M.indexTable = indexTable
M.filter = filter
M.vsh_parse = parse
M.vsh_parse_xml_table_row = parse_xml_table_row
M.index_not_found_error = index_not_found_error
M.fromXml = from_xml
-- Public constants
M.opDelimiter = '$$'

return M