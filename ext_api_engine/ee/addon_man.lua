--todo copyright

if lanes == nil then 
   lanes = require("lanes")
   lanes.configure()
end

require("lfs")
local CFG = require("ee_conf")

local loadreg = function()
   --logger("Loading buildins...")
   local reg = assert(loadfile(CFG.BUILDIN_REG_FILE),"load regfile \""..CFG.BUILDIN_REG_FILE.."\" failed")()
   local renderer, content = {}, {}
   assert(type(reg)=="table", "invalid registry: type="..type(reg))
   for k, v in pairs(reg) do
      assert(type(k)=='string' and type(v)=='table')
      assert(type(v.addon)=='string' and type(v.class)=='string')
   end
   local validate_main = require('validate_main')
   local manifest, main
   for file in lfs.dir(CFG.BUILDINS_DIR) do
      if file ~= '.' and file ~= '..' then 
         local f = CFG.BUILDINS_DIR..'/'..file
         local attr = lfs.attributes(f)
         assert(type(attr) == 'table')
         if attr.mode == "directory" then
            local old_path = package.path
            local old_cpath = package.cpath
            package.path = old_path .. ';' .. f .. '/?.lua'
            package.cpath = old_cpath .. ';' .. f .. '/?.so' 
            manifest,main = validate_main(f)
            package.path = old_path
            package.cpath = old_cpath
            assert(manifest ~=nil)
            if manifest.addon_type == 'REST' then
               local found = false
               for k, v in pairs(reg) do
                  if v.addon == manifest.addon_name then
                     if manifest.classes[v.class] then
                        v.manifest = manifest
                        v.classimpl = main[v.class]
                        v.libpath = f
                     end
                     found = true
                  end
               end
               if not found then manifest,main = nil, nil end
            elseif manifest.addon_type == 'RENDERER' then
               for k, v in pairs(manifest.accepted_types) do 
                  assert(renderer[k] == nil)
                  renderer[k] = main
               end
            elseif manifest.addon_type == 'CONTENT' then
            end
         end 
      end
   end
   validate_manifest = nil
   validate_main = nil
   return reg, renderer, content
end

local addon_man = {loadreg = loadreg}

return(addon_man)

