local json = require("json")

local function parse(body)
    local s, r = pcall(json.decode, body)
    if s then return r else error({code=500, msg= 'Internal Error', detail="Parsing application/json content failed"}) end
end

return {["application/json"]=parse}

