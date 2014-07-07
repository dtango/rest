LOG = {EMERG=0, ALERT=1, CRIT=2, ERR=3, WARNING=4, NOTICE=5, INFO=5, DEBUG=6}

local CFG = require("ee_conf")
local lanes = require("lanes")
lanes.configure()

local debug_linda = lanes.linda()

local debug_thread_finalizer = function (err)
   --print(err)
end

local function debugger()
    set_finalizer(debug_thread_finalizer)

    local CFG = require("ee_conf")
    package.path = CFG.LUALIB_PATH
    package.cpath = CFG.LUALIB_CPATH

    os.execute("touch "..CFG.LOG_FILE)
    for i = 1, CFG.LOG_FILE_ROTATION do
        os.execute("touch "..CFG.LOG_FILE..'.'..i)
    end

    local logf = assert(io.open(CFG.LOG_FILE, "a"))

    local function rotate_log()
       logf:close()
       for i = 1, CFG.LOG_FILE_ROTATION-1 do
          os.execute("mv -f "..CFG.LOG_FILE..'.'..i.." "..CFG.LOG_FILE..'.'..(i+1))
       end
       os.execute("mv -f "..CFG.LOG_FILE.." "..CFG.LOG_FILE..'.'..'1')
       os.execute("touch "..CFG.LOG_FILE)
       logf = assert(io.open(CFG.LOG_FILE, "a"))
    end

    while true do
        local msg = debug_linda:receive("debug")
        if msg.op == "log" then
            local m = os.date() .. '   ' .. tostring(msg.text)
            if CFG.LOG_TO_STDOUT then io.write(tostring(m).."\n") io.flush() end
            logf:write(m..'\n')
            local size = logf:seek("end")
            if size >= CFG.LOG_FILE_SIZE then rotate_log() end
        end
    end

    return "done"
end

local debug_thread

if debug_thread == nil then
    debug_thread = lanes.gen("*", debugger)()
end

return {linda = debug_linda, thread = debug_thread}
