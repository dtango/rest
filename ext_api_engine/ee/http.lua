local req = {}
local total = 0
local CFG = require('ee_conf')

local addline = function(line)
   total = total + 1
   if (req.method == nil) then
      _,_,req.method, req.url = string.find(line, "^(%a+)%s+(.+) HTTP%/%d.%d%s-$")
      if req.method == nil then
          return nil, {code=400, msg="Bad Request",detail="Bad Request"}
      end
   else
      if line:len() == 0 then
         if not req.accept then
            req.accept = {CFG.DEFAULT_RENDERER_TYPE}
         end
         if req.method == "POST" then
             if not req.content_length then req.content_length = 0 end
             if not req.content_type then req.content_type = CFG.DEFAULT_CONTENT_TYPE end
         end
         return req
      else 
         local _,_,key,value = string.find(line, "^(%u[%w%-]+)%:%s+(.+)$")
         if key == "Accept" then
            value = value .. ","
            local tmptbl = {}
            req.accept = {}
            for a in string.gfind(value, "(.-),") do
               a=a..";q=1"
               local _,_,t, power = string.find(a,"^(.-);q=([01]%.?%d?)") 
               table.insert(tmptbl, {t,power})
            end
            table.sort(tmptbl, function(a,b) return a[2] > b[2] end)
            for i=1, #tmptbl do
               req.accept[i] = tmptbl[i][1]
            end
         elseif key == "Content-Length" then
            req.content_length = value
         elseif key == "Content-Type" then
             req.content_type = value
         elseif key == "EE-Auth-Token" then
             req.ee_auth_token = value
         end
      end
   end
end

local function init()
   req,total = {},0
end

return {addline=addline, init=init}
