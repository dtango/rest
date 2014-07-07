local function chunk(p, str)
   p(string.format("%X",string.len(str)).."\r\n"..str.."\r\n")
end

local function get_table_len(t)
  if type(t) ~= 'table' then return 0 end
  local tt = 0
  for k,v in pairs(t) do tt = tt+1 end
  return tt
end

local function render(p, mime, c)
   p("HTTP/1.1 200 OK\r\n")
   p("Content-Type: "..mime.."; charset=utf-8\r\n")
   p("Transfer-Encoding: chunked\r\n")
   p("\r\n")
   
   local header = 0
   if get_table_len(c.instances) > 0 then
      for k, v in pairs(c.instances) do
         if get_table_len(v.properties) > 0 then
            local str
            local temp
            local comma = ''
            if header == 0 then
               header = {}
               local i = 1
               for kk,vv in pairs(v.properties) do
                  header[i] = kk
                  i = i + 1
               end
               str = ''
               for j = 1, #header, 1 do
                  temp = tostring(header[j])
                  str = str..comma..'"'..temp:gsub('"', '""')..'"'
                  comma =','
               end
               chunk(p,str..'\n')
            end
            comma = ''
            str = ''
            for j = 1, #header, 1 do
               temp = tostring(v.properties[header[j]])
               str = str..comma..'"'..temp:gsub('"', '""')..'"'
               comma =','
            end
            print(str)
            chunk(p,str..'\n')
         end
      end
   end
   
   chunk(p, "")
end

local function message(p, mime, e)
   if type(e) == 'string' then
      p("HTTP/1.1 500 Internal Error\r\n\r\n"..e..'\n')
   end
   if type(e) == 'table' and e.code and e.msg then
      p("HTTP/1.1 "..e.code..' '..e.msg.."\r\n")
      p("Content-Type: "..mime.."; charset=utf-8\r\n")
      p("Transfer-Encoding: chunked\r\n")
      p("\r\n")
      chunk(p,"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
      chunk(p,"<message>\n")
		chunk(p,"<code>"..e.code.."</code>\n")
		chunk(p,"<msg>"..e.msg.."</msg>\n")
		chunk(p,"</message>\n");
		chunk(p,"")
   end
end

return {
   render = render,
   message = message
}
