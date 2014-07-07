local function chunk(p, str)
   local a = {}
   p(string.format("%X",string.len(str)).."\r\n"..str.."\r\n")
end

local function get_table_len(t)
  if type(t) ~= 'table' then return 0 end
  local tt = 0
  for k,v in pairs(t) do tt = tt+1 break end
  return tt
end

local is_basetype = _G.is_basictype

local function manifest_to_json()
    local function table_to_json(dst, tbl)
        if type(tbl) == 'table' then
            for k, v in pairs(tbl) do
                table.insert(dst, '"'..k..'":')
                if type(v) ~= 'table' then
                    if k == "is_array" or k == "mandatory" then
                        table.insert(dst, tostring(v))
                    else
                        table.insert(dst, '"'..tostring(v)..'"')
                    end
                else
                    table.insert(dst, '{')
                    table_to_json(dst, v)
                    table.insert(dst, '}')
                end
                table.insert(dst, ',')
            end
         end
        if dst[#dst] == ',' then table.remove(dst,#dst) end
    end

    local tmp = {'var manifest =  {\n'};
    if type(_G.manifest.types) == 'table' then
        table.insert(tmp,'   "types":{\n')
        for k,v in pairs(_G.manifest.types) do
            table.insert(tmp, '      "'..k..'":{')
            for kk, vv in pairs(v) do
                if type(vv) == 'table' then
                    table.insert(tmp, '"'..kk..'":{')
                    table_to_json(tmp,vv)
                    table.insert(tmp, '}')
                    table.insert(tmp, ',')
                else
                    table.insert(tmp,'"'..kk..'":"'..tostring(vv)..'"')
                    table.insert(tmp, ',')
                end

            end
            table.remove(tmp, #tmp)
            table.insert(tmp, '}')
            table.insert(tmp, ',\n')
        end
        if tmp[#tmp] == ',\n' then table.remove(tmp,#tmp) end
        table.insert(tmp, '\n   },\n')
    end
    if type(_G.manifest.classes) == 'table' then
        if type(_G.manifest.classes[_G.classname]) == 'table' then
            table.insert(tmp,'   "class":{')
            table.insert(tmp, '"classname":"'.._G.classname..'",')
            table_to_json(tmp, _G.manifest.classes[_G.classname])
            table.insert(tmp,'\n   }\n')
        end
    end


        table.insert(tmp, '}\n')
    return table.concat(tmp);
end

local function meta(p, mime, c)
    p("HTTP/1.1 200 OK\r\n")
    p("Content-Type: "..mime.."; charset=utf-8\r\n")
    p("Transfer-Encoding: chunked\r\n")
    p("\r\n")
    chunk(p, "<!DOCTYPE html>\n<html>\n<head>\n<script>\n")
    chunk(p,  manifest_to_json())
    chunk(p, "</script>\n</head>\n<body>\n")
    local f = io.open("meta.html", "r")
    if f then
        chunk(p, f:read("*all"))
    end
    chunk(p, "</body>\n</html>\n")
    chunk(p, "")
end

local function render(p, mime, c)
    --for k,v in pairs(_G) do print(k,v) end
    writestruct = function(data, meta, tmp)
        table.insert(tmp, '{')
        for kkk, vvv in pairs(data) do
            if meta[kkk] then
                table.insert(tmp,'"'..kkk..'":')
                if is_basetype(meta[kkk].type) then
                    if meta[kkk].is_array then
                        table.insert(tmp, '[')
                        for kkkk, vvvv in pairs(vvv) do
                            if meta[kkk].type == "string" then
                                table.insert(tmp, '"'..tostring(vvvv)..'"')
                            else
                                table.insert(tmp, tostring(vvvv))
                            end
                            table.insert(tmp, ',')
                        end
                        if tmp[#tmp] == ',' then table.remove(tmp) end
                        table.insert(tmp,']')
                    else
                        if meta[kkk].type == "string" then
                            table.insert(tmp,'"'..tostring(vvv)..'"')
                        else
                            table.insert(tmp,tostring(vvv))
                        end
                    end
                else
                    if meta[kkk].is_array then
                        table.insert(tmp, '[')
                        for a, b in pairs(vvv) do
                            writestruct(b, manifest.types[meta[kkk].type], tmp)
                            table.insert(tmp,',')
                        end
                        if tmp[#tmp] == ',' then table.remove(tmp) end
                        table.insert(tmp,']')
                    else
                        writestruct(vvv, manifest.types[meta[kkk].type],tmp)
                    end
                end
                table.insert(tmp, ',')
            else
                logger("Renderer - type field does not exist: "..kkk)
            end
        end
        if tmp[#tmp] == ',' then table.remove(tmp) end
        table.insert(tmp, '}')
    end

    p("HTTP/1.1 200 OK\r\n")
   p("Content-Type: "..mime.."; charset=utf-8\r\n")
   p("Transfer-Encoding: chunked\r\n")
   p("\r\n")

    chunk(p, "<!DOCTYPE html>\n<html>\n<head>\n<script>\n")

    chunk(p,  manifest_to_json())

    chunk(p,  'var opertation = "'..operation..'"\n')

    chunk(p,  'var resourceURL = "'..resource_url..'"\n')
    ----------------------------local tmp = {'var instances = {\n' }
    if get_table_len(c.instances) > 0 then
        local tmp = {'var instances = {\n' }
        for k, v in pairs(c.instances) do
            table.insert(tmp, '   "'..k..'":')
            table.insert(tmp, '{')
            if k ~= '' then
                if operation == "get" then
                    table.insert(tmp, '"url":"'..resource_url..'"')
                    table.insert(tmp,',')
                else
                    table.insert(tmp, '"url":"'..resource_url..'/'..k..'"')
                    table.insert(tmp,',')
                end
            else
                table.insert(tmp, '"url":"'..resource_url..'"')
                table.insert(tmp,',')
            end

            if get_table_len(v.properties) > 0 then
                table.insert(tmp,'"properties":{')
                for pn, pv in pairs(v.properties) do
                    if manifest.classes[classname].properties[pn] then
                        table.insert(tmp,'"'..pn..'":')
                        if is_basetype(manifest.classes[classname].properties[pn].type) then
                            if manifest.classes[classname].properties[pn].is_array then
                                table.insert(tmp,'[')
                                for kk, vv in pairs(pv) do
                                    if manifest.classes[classname].properties[pn].type == "string" then
                                        table.insert(tmp, '"'..tostring(vv)..'"')
                                    else
                                        table.insert(tmp, tostring(vv))
                                    end
                                    table.insert(tmp, ',')
                                end
                                if tmp[#tmp] == ',' then table.remove(tmp) end
                                table.insert(tmp,']')
                            else
                                if manifest.classes[classname].properties[pn].type == "string" then
                                    table.insert(tmp,'"'..tostring(pv)..'"')
                                else
                                    table.insert(tmp,tostring(pv))
                                end
                            end
                        else
                            if manifest.classes[classname].properties[pn].is_array then
                                table.insert(tmp,'[')
                                for kk, vv in pairs(pv) do
                                    writestruct(vv, manifest.types[manifest.classes[classname].properties[pn].type], tmp)
                                    table.insert(tmp, ',')
                                end
                                if tmp[#tmp] == ',' then table.remove(tmp) end
                                table.insert(tmp,']')
                            else
                                writestruct(pv, manifest.types[manifest.classes[classname].properties[pn].type], tmp)
                            end
                        end
                        --                      table.insert(tmp,'}')
                        table.insert(tmp,',')
                    else
                        logger("Renderer - property does not exist: "..classname..'.'..pn)
                    end
                end
                if tmp[#tmp] == ',' then table.remove(tmp) end
                table.insert(tmp,'}')
                table.insert(tmp,',\n')
            end
            if get_table_len(v.children) > 0 then
                table.insert(tmp,'"subscopes":{')
                for kk,vv in pairs(v.children) do
                    table.insert(tmp, '"'..kk..'":"'..tostring(vv)..'"')
                    table.insert(tmp, ',')
                end
                if tmp[#tmp] == ',' then table.remove(tmp) end
                table.insert(tmp,'}')
            end
            if tmp[#tmp] == ',\n' or tmp[#tmp] == ','  then table.remove(tmp) end
            table.insert(tmp, '}')
            table.insert(tmp,',\n')
        end
        if tmp[#tmp] == ',\n' then table.remove(tmp) end
        table.insert(tmp, '}')
        chunk(p, table.concat(tmp))
    end
    chunk(p, "</script>\n</head>\n<body>\n")
    local f = io.open("script.html", "r")
    if f then
        chunk(p, f:read("*all"))
    end
    chunk(p, "</body>\n</html>\n")
    chunk(p, "")
end

return {
   ["text/html"] = {render=render, meta=meta},
}
