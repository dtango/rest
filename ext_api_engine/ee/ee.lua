function trace(event, line)
    local s = debug.getinfo(2).short_src
    print(s..":"..line)
end
--debug.sethook(trace,"l")

local CFG=require('ee_conf')

package.path = CFG.LUALIB_PATH
package.cpath = CFG.LUALIB_CPATH

lanes = require('lanes')
lanes.configure()

debugger = require("debugger")

logger = function (msg)
    rv = debugger.linda:send(1,"debug", {op="log",text=tostring(msg)})
end

lnull = require("luanull")

local main_linda = lanes.linda()
require('socket')
reg = require("reg_man")

function run()
   logger("Starting Execution Engine ...")

   local s = socket.bind(CFG.ADDRESS, CFG.PORT)
   if s == nil then
       logger("Binding to "..CFG.ADDRESS..":"..CFG.PORT.." failed.")
   else
       logger("Bound to "..CFG.ADDRESS..":"..CFG.PORT)
       local workers = require("ee_worker")
       while true do
          local fd = s:acceptfd()

          if fd == nil then
              logger("Socket acceptfd error, got nil.")
          else
             local worker = workers.get_free_worker()
             if worker == nil then
                 logger("Maximum "..tostring(CFG.MAX_THREADS).." connections reached.")
                 local sock = socket.tcp(fd)
                 local errmsg =  "Maximum connections ("..
                 tostring(CFG.MAX_THREADS)..") has reached.\r\n"
                 sock:send("HTTP/1.1 500.13 Server Too Busy\r\nContent-Length: "..tostring(string.len(errmsg)).."\r\n\r\n"..errmsg)
                 sock:close()
                 sock = nil
             else
                workers.linda:send(worker, {op="fd", data=fd})
             end
          end
       end
      s:close()
      s = nil
   end
   debugger.thread:cancel(1, true)

   --commit suicide :( due to lua lanes' problem
   local pid = require("pid")
   io.flush()
   pid.kill()
end

run()
