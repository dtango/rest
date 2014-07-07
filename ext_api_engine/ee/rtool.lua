local CFG=require('ee_conf')

package.path = CFG.LUALIB_PATH
package.cpath = CFG.LUALIB_CPATH

require('socket')

lanes = require('lanes')
lanes.configure()

local workers = require("rtool_worker")

function run()
   print("Starting Remoter Tool...")

   local s = socket.bind("0.0.0.0", 8080)

   while true do
      local fd = s:acceptfd()

      if fd == nil then
         --cleanup_threads()
      else
         local threadid = workers.get_free_worker()
         if threadid == nil then
            local sock = socket.tcp(fd)
            sock:send("I'm busy!!!\r\n")
            sock:close()
            sock = nil
         else
            print(threadid, fd)
            workers.linda:send(threadid, fd)
         end
      end
   end
   s:close()
   s = nil
end

run()

