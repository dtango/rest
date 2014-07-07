local function validate_main(path)
   local validate_manifest=require("validate_manifest")
   local manifest = validate_manifest(path..'/manifest.lua')

   local m = assert(loadfile(path..'/main.lua'),"load \""..path..'/main.lua'.."\" failed")
   local main = m()
   assert(type(main) == "table", "invalid main.lua: "..path..'/main.lua')
   
   if manifest.addon_type == "REST" then
      for k,v in pairs(manifest.classes) do
         assert(main[k], "unimplemented class: "..k)
      end

      for k,v in pairs(main) do
         assert(type(k) == 'string', "invalid type for class name: "..type(k))
         assert(manifest.classes[k], "undefined class: "..k)
         assert(type(v) == 'table', "invalid class implementation")
         assert(type(v.enum) == 'function', "enum is mandatory function")
       
         --if type(v.is_singleton) ~= 'function' then 
         --   if (type(v.get) ~= 'function') then 
         --      v.is_singleton = function() return true end 
         --   else
         --      v.is_singleton = function() return false end 
         --   end
         --end

         if (not type(v.has_instance) == 'function') then
            if type(v.get) == 'function' then
               v.has_instance = function(idx,objpath) 
                  return v.get(idx, objpath) ~= nil
               end
            else
               v.has_instance = function(idx,objpath) 
                  local inst = v.enum()
                  if inst then
                     return inst[idx] ~= nil
                  else
                     return false
                  end
               end
            end 
         end
      end
   end
   
   if manifest.addon_type == "RENDERER" then
      assert(type(main.render)=="function", "function \"render\" is mandatory")
      assert(type(main.message)=="function", "function \"message\" is mandatory")
   end
      
   return manifest, main
end

return(validate_main)

