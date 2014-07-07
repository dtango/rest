--todo copyright

require("lfs")

local function validate_by_meta(data, meta, userdata)
   for i=1, #meta, 1 do
      if meta[i].mandatory then 
         assert(data[meta[i].name], 'mandatory field "'..meta[i].name..'" is missing') 
      end
      if (data[meta[i].name]) then
         assert(type(data[meta[i].name]) == meta[i].type, 'data type for "'..meta[i].name..'" is not "'..meta[i].type..'"')
      end
      if meta[i].validate and data[meta[i].name] then meta[i].validate(meta[i].name, data[meta[i].name], userdata) end
   end  
   return data
end

local function validate_name(name, value)
   local b,e,s = string.find(value,"^%a+[%w_]*$")
   assert(b == 1 and e == string.len(value), value.." is not in valid format for "..name)
end

local function validate_libs(name, value, path)
   for i, v in ipairs(value) do 
     assert(type(v) == 'string', "library name should be a string") 
   end
   --todo: validate libraries
end

--types meta
local types_meta = {
   {name = "is_array",   mandatory=false,  type="boolean",validate=nil},
   {name = "fields",     mandatory=true,   type="table",  validate=nil},
}

--type_field meta
local tf_meta = {
   {name = "field_type", mandatory=true,  type="string", validate=nil},
}

local function is_reserverd_type(v)
   return (v =="string" or v =="number" or v=="boolean")
end

local function validate_type(k,t)
   validate_name('type name',k);
   assert(t[k], 'no type by name "'..k..'" has been defined')
   v = t[k]
   assert(not v["__EE_VALIDATING__"], "recursing type definition is not supported")
   if v["__EE_VALIDATED__"] then return end  
   v["__EE_VALIDATING__"] = true
   assert(not is_reserverd_type(v), "type name cannot be a reserved name") --todo: do more check
   validate_by_meta(v, types_meta, types)
   local total_fields = 0
   for kk, vv in pairs(v.fields) do
      validate_by_meta(vv, tf_meta, types)
      if not is_reserverd_type(vv.field_type) then
         validate_type(vv.field_type,t)
      end
      total_fields = total_fields + 1
   end
   assert(total_fields ~= 0, 'no field has been defined in type "'..k..'"')
   v["__EE_VALIDATING__"] = nil
   v["__EE_VALIDATED__"] = true
end

local function validate_types(name, value, types)
   for k,v in pairs(value) do
      validate_type(k,types)
   end
end

local class_meta = {
   {name = "containers",   mandatory=false, type="table",  validate=nil},
   {name = "version",      mandatory=false, type="number", validate=nil},
   {name = "revision",     mandatory=false, type="number", validate=nil},
   {name = "key",          mandatory=false, type="string", validate=nil},
   {name = "properties",   mandatory=false, type="table",  validate=nil},
   {name = "methods",      mandatory=false, type="table",  validate=nil},
}

local property_meta = {
   {name = "prop_type",    mandatory=true,  type="string", validate=nil},
   {name = "mandatory",    mandatory=false, type="boolean",validate=nil},
}

local method_meta = {
   {name = "arg_type",     mandatory=true,  type="string", validate=nil},
   {name = "mandatory",    mandatory=false, type="boolean",validate=nil},
}


local function validate_class(k,v, types)
   validate_name('class name',k)
   validate_by_meta(v, class_meta)
   if v.properties then 
      local t = 0
      for kk,vv in pairs(v.properties) do
         validate_by_meta(vv, property_meta, types)
         assert(is_reserverd_type(vv.prop_type) or (types[vv.prop_type]), 'undefined type: "'..vv.prop_type..'"') 
         t = t + 1
      end
      assert(t~=0, 'no property has been defined for "'..k..'"')
   end
   if v.methods then 
      local t = 0
      for kk,vv in pairs(v.methods) do
         validate_name("method name", kk)
         assert(type(vv) == 'table', 'invalid method definition for method "'..kk..'"') 
         t = t + 1
         for kkk, vvv in pairs(vv) do
            validate_name("argument name", kkk)
            validate_by_meta(vvv, method_meta, types)
            assert(is_reserverd_type(vvv.arg_type) or (types[vvv.arg_type]), 'undefined type: "'..vvv.arg_type..'"') 
         end   
      end
      assert(t~=0, 'no method has been defined for "'..k..'"')
   end
end

local function validate_classes(name, value, types)
   local total_class = 0
   for k,v in pairs(value) do
      validate_class(k,v, types)
      total_class = total_class + 1
   end
   assert(total_class ~= 0, "no class has been defined")
end

--manifest common meta, using array to ensure the validation order
local common_meta = {
   {name = "addon_type",       mandatory=true,  type="string", validate=function(n,v) assert(v=="REST" or v=="CONTENT" or v=="RENDERER",'"'..v..'" is not a valid addon type') end},
   {name = "addon_name",       mandatory=true,  type="string", validate=validate_name},
   {name = "version",          mandatory=true,  type="number", validate=nil},
   {name = "revision",         mandatory=true,  type="number", validate=nil},
   {name = "required_libs",    mandatory=false, type="table",  validate=validate_libs},
   {name = "min_ee_ver",       mandatory=false, type="number", validate=function(n,v) assert(EE_VER>=v, 'this Execution Engine is too old to run this addon') end},
   {name = "max_ee_ver",       mandatory=false, type="number", validate=function(n,v) assert(EE_VER<=v, 'this Execution Engine is too new to run this addon') end},
   {name = "min_platform_ver", mandatory=false, type="number", validate=function(n,v) assert(PLATFORM_VER>=v, 'this platform is too old to run this addon') end},
   {name = "max_platform_ver", mandatory=false, type="number", validate=function(n,v) assert(PLATFORM_VER<=v, 'this platform is too new to run this addon') end},  
   {name = "platform_name",    mandatory=false, type="string", validate=function(n,v) assert(v==PLATFORM_NAME, 'this addon is not for this platform') end},
}

--REST manifest meta
local rest_meta = {
   {name = "types",            mandatory=false, type="table",  validate=validate_types},
   {name = "classes",          mandatory=true,  type="table",  validate=validate_classes},
}

--CONTENT manifest meta
local content_meta = {
   {name = "content_types",     mandatory=true,  type="table",  validate=nil},
}

--RENDERER manifest meta
local renderer_meta = {
   {name = "accepted_types",    mandatory=true,  type="table",  validate=nil},
}

local function validate_manifest(path)
   local m = assert(loadfile(path),"load \""..path.."\" failed")
   assert(type(m) == "function")
   local manifest = m()
   assert(type(manifest) == "table", path.." does not return manifest table")
   validate_by_meta(manifest, common_meta, path)
   if manifest.addon_type == 'REST' then validate_by_meta(manifest, rest_meta, manifest.types) end
   if manifest.addon_type == 'CONTENT' then 
      validate_by_meta(manifest, content_meta)
      local t = 0
      for k, v in pairs(manifest.content_types) do
         assert(type(v) == 'boolean', "invalid definition for content type")
         t = t + 1
      end 
      assert(t ~= 0, "no content type defined")
   end
   if manifest.addon_type == 'RENDERER' then 
      validate_by_meta(manifest, renderer_meta) 
      local t = 0
      for k, v in pairs(manifest.accepted_types) do
         assert(type(v) == 'boolean', "invalid definition for accepted type")
         t = t + 1
      end 
      assert(t ~= 0, "no accepted type defined")
   end
   return manifest
end

return(validate_manifest)
