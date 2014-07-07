local function chunk(p, str)
   p(string.format("%X",string.len(str)).."\r\n"..str.."\r\n")
end

local function is_empty(t)
  if type(t) ~= 'table' then return true end
  for k,v in pairs(t) do return false end
  return true
end

local function xml_esc(s)
   local tmp = tostring(s)
   local ec = {['"']='&quot;',["'"]='&apos;', ['<']='&lt;', ['>']='&gt;',['&']='&amp;'}
   return string.gsub(tmp, "([\"'<>&])", function(w)return ec[w] end)
end

local function is_basetype(t)
    return t == 'string' or t=='boolean' or t=='number'
end

local function render(p, mime, c)
    local id = 0

    writestruct = function(name, data, meta)
        if name then
            chunk(p, '<Obj N="'..name..'" RefId="'..tostring(id)..'">\n')
        else
            chunk(p, '<Obj RefId="'..tostring(id)..'">\n')
        end
        id = id + 1
        chunk(p,'<TN RefId="'..tostring(id)..'">\n')
        chunk(p,'<T>System.Collections.ArrayList</T>\n')
        chunk(p,'<T>System.Object</T>\n')
        chunk(p, '</TN>\n')
        chunk(p, '<MS>\n')
        for k, v in pairs(data) do
            if meta[k] then
                if is_basetype(meta[k].type) and not meta[k].is_array then
                    chunk(p, '<S N="'..k..'">'..xml_esc(v)..'</S>\n')
                elseif meta[k].is_array then
                    writearray(k, v, meta[k].type)
                else
                    writestruct(k, v, manifest.types[meta[k].type])
                end
            else
                error("Renderer - type field does not exist: "..kkk)
            end
        end
        chunk(p, '</MS>\n')
        chunk(p, '</Obj>\n')
    end

    writearray = function(name, data, meta)
        chunk(p, '<Obj N="'..name..'" RefId="'..tostring(id)..'">\n')
        id = id + 1
        chunk(p,'<TN RefId="'..tostring(id)..'">\n')
        chunk(p,'<T>System.Collections.ArrayList</T>\n')
        chunk(p,'<T>System.Object</T>\n')
        chunk(p, '</TN>\n')
        chunk(p,'<LST>\n')
        for i = 1, #data do
            if is_basetype(meta) then
               chunk(p,'<S>'..tostring(data[i])..'</S>\n')
            else
               writestruct(nil, data[i], manifest.types[meta])
            end
        end
        chunk(p,'</LST>\n')

        chunk(p, '</Obj>\n')
    end

   p("HTTP/1.1 200 OK\r\n")
   p("Content-Type: application/xml; charset=utf-8\r\n")
   p("Transfer-Encoding: chunked\r\n")
   p("\r\n")
   
   chunk(p, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")

   chunk(p, '<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">\n')
   if not is_empty(c.instances) then
      for k, v in pairs(c.instances) do
          chunk(p,'<Obj RefId="'..tostring(id)..'">\n')
          chunk(p,'<TN RefId="'..tostring(id)..'">\n')
          chunk(p,'<T>System.Management.Automation.PSCustomObject</T>\n')
          chunk(p,'<T>System.Object</T>\n')
          chunk(p,'</TN>\n')
          chunk(p,'<ToString>System.Object</ToString>\n')
          id = id+1
          if not is_empty(v.properties) then
             chunk(p, '<MS>\n')
             for pn, pv in pairs(v.properties) do
                 if manifest.classes[classname].properties[pn] then
                     if is_basetype(manifest.classes[classname].properties[pn].type) and not manifest.classes[classname].properties[pn].is_array then
                          chunk(p, '<S N="'..pn..'">'..xml_esc(pv)..'</S>\n')
                     elseif manifest.classes[classname].properties[pn].is_array then
                         writearray(pn, pv, manifest.classes[classname].properties[pn].type)
                     else
                         writestruct(pn, pv, manifest.types[manifest.classes[classname].properties[pn].type])
                     end
                 else
                     error("Renderer - property does not exist: "..classname..'.'..pn)
                 end
             end
          end
          chunk(p, '</MS>\n')
          chunk(p, '</Obj>\n')
      end
   end
   chunk(p, '</Objs>\n')
   chunk(p, "")
end

return {
   ['application/ps_clixml'] = render,
}

