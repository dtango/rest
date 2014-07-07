--
-- Created by IntelliJ IDEA.
-- User: skolar
-- Date: 7/4/13
-- Time: 1:41 PM
-- To change this template use File | Settings | File Templates.
--

local vsh = require("vsh")
local sax = require("sax")

local insts = {}
local inst
local props = {}


local u = {}

local sc = {}
local flags = {}

sc.startElement =  function (en)
    if en == "ROW_template" then
        flags.newinstance = true
    elseif en == "usr_name" and flags.newinstance then
        flags.usr_name = true
    elseif en == "expire_date" and flags.newinstance then
        flags.expire = true
    elseif en == "role" and flags.newinstance then
        flags.role = true
    end
end

sc.endElement =  function (en)
    if en == "ROW_template" then
        flags.newinstance = nil
    elseif en == "usr_name" and flags.newinstance then
        flags.usr_name = nil
    elseif en == "expire_date" and flags.newinstance then
        flags.expire = nil
    elseif en == "role" and flags.newinstance then
        flags.role = nil
    end
end

sc.characters =  function (v)
    if flags.usr_name then
        if flags.newinstance then
            flags.key = v
            insts[v] = {}
            insts[v].properties= {name=v}
        end
    end
    if flags.expire and flags.newinstance then
        insts[flags.key].properties.expire = string.gsub(v, "\n", "")
    end
    if flags.role and flags.newinstance then
        if insts[flags.key].properties.role == nil then insts[flags.key].properties.role = {} end
	table.insert(insts[flags.key].properties.role,v)
    end

end

u.enum = function()
    local xml = vsh.run("show user-account | xml")
    sax.parse(xml,sc)
    return {instances=insts}
end

u.get = function(index)
    local xml = vsh.run("show user-account "..index.. " | xml")
    sax.parse(xml,sc)
    return {instances=insts}
end

u.has_instance = function(index)
    local status, result = pcall(u.get, index)
    if status then
        for k,v in pairs(result) do
            return true
        end
    end
    return false
end

u.delete = function(index)
    if not u.has_instance(index) then error({code =404, msg="Not Found", detail='User "'..index..'" does not exist'}) end
    vsh.run("config t ; no username "..index)
end

u.create = function(index)
    if u.has_instance(index) then error('User "'..index..'" already exists') end
    u.set(index)
end 

u.serialize = function(t)
  local serializedValues = {}
  local value, serializedValue
  for i=1,#t do
    value = t[i]
    serializedValue = type(value)=='table' and serialize(value) or value
    table.insert(serializedValues, serializedValue)
  end
  return string.format("{ %s }", table.concat(serializedValues, ', ') )
end

u.set = function(index)
    local mrole = nil 
    local cmd = 'config t ; '
    cmd = cmd .. 'username "'..index..'" '
    local cmd1 = cmd 

    if request.password then
        cmd = cmd .. 'password '..request.password..' '
    end
    if request.expire then
        cmd = cmd .. 'expire '..request.expire..' '
    end
    if request.role then
        for _,v in pairs(request.role) do
            if not mrole then 
               cmd = cmd .. 'role '..v..' '
               mrole = true
            else 
               cmd = cmd .. ';'.. cmd1 .. 'role '..v..' '
            end
        end
    end
    local status, err = pcall(vsh.run, cmd)
    if not status then
       logger(err.stdout)
       logger("Error: Password may be too short or Invalid Role or Invalid Expire date\nPlease provide the valid values in arguments")
       error("Error: Password may be too short or Invalid Role or Invalid Expire date\nPlease provide the valid values in arguments")
    end
    --cmd = ' copy r s'
    --local status, err = pcall(vsh.run, cmd)
    --if not status then
    --   if not vExist then
    --      v.delete(index)
    --   end
    --   logger("Failed to copy r s \n"..err.stdout.."")
    --   error({code =404, msg="Invalid", detail='Failed to do copy r s'})
    --end
end

return {user=u}


