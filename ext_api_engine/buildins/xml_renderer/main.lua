local function chunk(p, str)
   local a = {}
   p(string.format("%X",string.len(str)).."\r\n"..str.."\r\n")
end

local function get_table_len(t)
  if type(t) ~= 'table' then return 0 end
  local tt = 0
  for k,v in pairs(t) do tt = tt+1 end
  return tt
end

local function xml_esc(s)
   local tmp = tostring(s)
   local ec = {['"']='&quot;',["'"]='&apos;', ['<']='&lt;', ['>']='&gt;',['&']='&amp;'}
   return string.gsub(tmp, "([\"'<>&])", function(w)return ec[w] end)
end

local urlec = {[' ']='%20', ['<']='%3C', ['>']='%3E', ['#']='%23', ['%']='%25', ['{']='%7B', ['}']='%7D',
    ['|']='%7C', ['\\']='%5C',['^']='%5E', ['~']='%7E', ['[']='%5B', [']']='%5D', ['`']='%60', [';']='%3B', ['/']='%2F',
    ['?']='%3F', [':']='%3A', ['@']='%40', ['=']='%3D', ['&']='%26', ['$']='%24'}
local function url_esc(s)
    local tmp = tostring(s)
    return string.gsub(tmp, "[ <>#%%{}|\\%^~%[%]`;/%?:@=&%$]", function(w)return urlec[w] end)
end

local is_basetype = _G.is_basictype


local function render(p, mime, c)
    writestruct = function(data, meta)
        for kkk, vvv in pairs(data) do
            if meta[kkk] then
                if is_basetype(meta[kkk].type) then
                    if meta[kkk].is_array then
                        for a, b in pairs(vvv) do
                            chunk(p, '<'..xml_esc(kkk)..'>'..xml_esc(b)..'</'..xml_esc(kkk)..'>\n')
                        end
                    else
                        chunk(p, '<'..xml_esc(kkk)..'>'..xml_esc(vvv)..'</'..xml_esc(kkk)..'>\n')
                    end
                else
                    if meta[kkk].is_array then
                        for a, b in pairs(vvv) do
                            chunk(p, '<'..xml_esc(kkk)..'>')
                            writestruct(b, manifest.types[meta[kkk].type])
                            chunk(p, '</'..xml_esc(kkk)..'>\n')
                        end
                    else
                        chunk(p, '<'..xml_esc(kkk)..'>')
                        writestruct(vvv, manifest.types[meta[kkk].type])
                        chunk(p, '</'..xml_esc(kkk)..'>\n')
                    end
                end
            else
                logger("Renderer - type field does not exist: "..kkk)
            end
        end
    end

   p("HTTP/1.1 200 OK\r\n")
   p("Content-Type: "..mime.."; charset=utf-8\r\n")
   p("Transfer-Encoding: chunked\r\n")
   p("\r\n")
   
   chunk(p, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")

   if c.groupname then
      chunk(p, '<set name="'..xml_esc(c.groupname)..'">\n')
   end

    if get_table_len(c.instances) > 0 then
      for k, v in pairs(c.instances) do
         if k ~= ''  then
             if operation ~= 'get' then
                chunk(p, '<instance name="'..xml_esc(k)..'" url="'..xml_esc(resource_url)..'/'..xml_esc(url_esc(k))..'">\n')
             else
                chunk(p, '<instance name="'..xml_esc(k)..'" url="'..xml_esc(resource_url)..'">\n')
             end
         else
            chunk(p, '<instance url="'..xml_esc(resource_url)..'">\n')
         end
         
         if get_table_len(v.properties) > 0 then
            chunk(p, '<properties>\n')
--            for kk,vv in pairs(v.properties) do
--                chunk(p, '<property key="'..kk..'" value="'..xml_esc(vv)..'"/>\n')
--            end
              for pn, pv in pairs(v.properties) do
                  if type(manifest.classes[classname].properties) == 'table' and manifest.classes[classname].properties[pn] then
                      if is_basetype(manifest.classes[classname].properties[pn].type) then
                          if manifest.classes[classname].properties[pn].is_array then
                              for kk, vv in pairs(pv) do
                                  chunk(p, '<'..xml_esc(pn)..'>'..xml_esc(vv)..'</'..xml_esc(pn)..'>\n')
                              end
                          else
                              chunk(p, '<'..xml_esc(pn)..'>'..xml_esc(pv)..'</'..xml_esc(pn)..'>\n')
                          end
                      else
                          if manifest.classes[classname].properties[pn].is_array then
                              for kk, vv in pairs(pv) do
                                  chunk(p, '<'..xml_esc(pn)..'>')
                                  writestruct(vv, manifest.types[manifest.classes[classname].properties[pn].type])
                                  chunk(p, '</'..xml_esc(pn)..'>\n')
                              end
                          else
                              chunk(p, '<'..xml_esc(pn)..'>')
                              writestruct(pv, manifest.types[manifest.classes[classname].properties[pn].type])
                              chunk(p, '</'..xml_esc(pn)..'>\n')
                          end
                      end
                  else
                      logger("Renderer - property does not exist: "..classname..'.'..pn)
                  end
              end
            chunk(p, '</properties>\n')
         end
         if get_table_len(v.children) > 0 then
            chunk(p, '<children>\n')
            for kk,vv in pairs(v.children) do
                chunk(p, '<child name="'..kk..'" url="'..xml_esc(vv)..'"/>\n')
            end
            chunk(p, '</children>\n')
         end
         chunk(p, '</instance>\n')
      end
   end
   
   if c.groupname then
      chunk(p, '</set>\n')
   end
   chunk(p, "")
end

return {
   ["application/xml"] = render, ["text/xml"] = render,
}
