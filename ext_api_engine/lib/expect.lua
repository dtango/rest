local lpty = require "lpty"

local function spawn(...)
	local p = lpty.new()
	p:startproc(...)
	while p:hasproc() and not p:readok() do end
	if not p:hasproc() then
		local what, code = p:exitstatus()
        if p:hasproc() then p:endproc() end
        error("start failed: child process terminated because of " .. tostring(what) .. " " ..tostring(code))
    end
	return p
end

local function expect(p, what, timeout, plain)
    if not timeout then timeout = 5 end
    if not p:hasproc() then return nil, "no running process." end
    local res = ""
    local found = false

    -- consume all output from client while searching for our pattern
    while not found do
        local r, why = p:read(timeout)
        --io.write(tostring(r))
        if r ~= nil then
            res = res .. tostring(r)
            if type(what) == 'string' then
                local first, last, capture = string.find(res, what, 1, plain)
                if first then
                    if capture then
                        found = capture
                    else
                        found = string.sub(res, first, last)
                    end
                end
            elseif type(what) == 'table' then
                local lastfound = 0
                for i,v in pairs(what) do
                    if type(v) ~= 'string' then
                        if p:hasproc() then p:endproc() end
                        error("Invalid expection!")
                    end
                    local first, last, capture = string.find(res, v)
                    print("-------------------------------")
                    print(res)
                    print( v, first, last, caputre)
                    if first then
                        if first < lastfound or lastfound == 0 then
                            lastfound = first
                            function2call = v
                            if capture then
                                found = capture
                            else
                                found = string.sub(res, first, last)
                            end
                        end
                    end
                    if lastfound == 1 then break end
                end
            end
        else
            if why then
                if p:hasproc() then p:endproc() end
                error("read failed: " .. why)
            else
                local what, code = p:exitstatus()
                if what then
                    if p:hasproc() then p:endproc() end
                    error("read failed: child process terminated because of " .. tostring(what) .. " " ..tostring(code))
                end
            end
        end
    end
    return found
end

local function send(p, what)
	local s = p:send(what)
	-- wait for reply
	while not p:readok() and p:hasproc() do end
	return s
end

local function terminate(p)
   p:endproc()
end

return {expect=expect, spawn=spawn, send=send, terminate=terminate}
