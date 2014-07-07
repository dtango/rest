require('socket')
local lanes = require('lanes')
lanes.configure()

local workers = {}
local threads = {}
local mt = {}
local main_linda = lanes.linda()
local wait_linda = lanes.linda()   
local MAXWORKER = 2

for i = 1,MAXWORKER,1 do
   threads[i] = {}
   threads[i].id = "t"..tostring(i)
   --threads[i].status = "free"
end

local function worker(id)
   local CFG = require('ee_conf')
   package.path = CFG.LUALIB_PATH
   package.cpath = CFG.LUALIB_CPATH
   require("socket")
   while true do
      print(id)
      local fd,key = main_linda:receive(120,id)
      print("i'm here")
      if not key then break end;
      if tonumber(fd) < 0 then error("Invalid socket fd") end 
      local sock = socket.tcp(fd)
      local line, err = sock:receive("*l")
      if line == nil then
            if err == "closed" then break end
      else
         local rtn = os.tmpname()
         local err = os.tmpname()
         local f = assert (io.popen (line.." 2>"..err.." ; echo -n $? >"..rtn)) 
          
         sock:send(f:read'*a')
         --for l in f:lines() do
         --   print(l)
         --   sock:send(l..'\n')
         --end -- for loop

         f:close()            

         f = io.open(rtn,"r")
         local s = f:read("*all")
         sock:send(" "..s.." ------rEtURncoDE------\n")
         f:close()

         f = io.open(err,"r")
         s = f:read("*all")
         sock:send("------sTDeRR------\n"..s)
         f:close()
         os.execute("rm -rf "..rtn.." "..err)
      end
      sock:close()
      sock = nil
      collectgarbage()
   end
   return "done"
end

mt.linda = main_linda

mt.get_free_worker = function ()
   print("start get_free_worker")
   for i = 1,MAXWORKER,1 do
      if threads[i].thread ~= nil then
         print("before join")
         local rv, err, stack = threads[i].thread:join(0)
         print("after join")
         if rv == nil then
            print("======================",err, stack)
         else
            if rv == 'done' then
               threads[i].thread = nil
            end
         end
      end
   end
   print("end of clean up")
   
   for i = 1,MAXWORKER,1 do
      if threads[i].thread ~= nil and threads[i].thread.status == "waiting" then
         print("reuse old thread "..threads[i].id)
         return threads[i].id
      end
   end

   for i = 1,MAXWORKER,1 do
      if threads[i].thread == nil then
         threads[i].thread = lanes.gen("*", worker)(threads[i].id)
         while threads[i].thread.status ~= "waiting" do
            wait_linda:receive(0.1, "waitwaitwait")
            if threads[i].thread.status == "error" then
               threads[i].thread = nil
               return nil
            end
         end
         return threads[i].id
      end
   end
   return nil
end

mt.__index = function (t,k)
   print("accessing "..k)
   if k == "get_free_worker" or k == "linda" then
      return mt[k] 
   end
   return threads[k]
end

mt.__newindex = function(t,k,v)
   error("can't modify read only talbe")
end

mt.__metatable = function(t)
   error("can touch protected metatable")
end

setmetatable(workers, mt)

return workers
