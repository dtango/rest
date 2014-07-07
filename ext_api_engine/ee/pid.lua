--
-- Created by IntelliJ IDEA.
-- User: jasonxu
-- Date: 7/11/12
-- Time: 5:21 PM
-- To change this template use File | Settings | File Templates.
--

local function get_pid()
    local f = assert(io.open('/proc/self/stat', "r"))
    local s = f:read("*all")
    local _,_,pid = string.find(s,"^([%d]+)[%s]+")
    return pid
end

local function kill()
    os.execute("kill -9 "..tostring(get_pid()))
end

return {get_pid = get_pid,kill=kill}