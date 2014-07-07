local CFG = require("ee_conf")
require("lfs")

local urlec = {[' ']='%20', ['<']='%3C', ['>']='%3E', ['#']='%23', ['%']='%25', ['{']='%7B', ['}']='%7D',
    ['|']='%7C', ['\\']='%5C',['^']='%5E', ['~']='%7E', ['[']='%5B', [']']='%5D', ['`']='%60', [';']='%3B', ['/']='%2F',
    ['?']='%3F', [':']='%3A', ['@']='%40', ['=']='%3D', ['&']='%26', ['$']='%24'}
local function url_esc(s)
    local tmp = tostring(s)
    return string.gsub(tmp, "[ <>#%%{}|\\%^~%[%]`;/%?:@=&%$]", function(w)return urlec[w] end)
end


local function printtbl(t, indent)
    if indent == nil then indent = '' end
    --if type(t) ~= "table" then print(t) return end
    --print(debug.traceback())
    for k, v in pairs(t) do
        print(indent, k,v)
        if type(v) == "table" then printtbl(v, indent.."\t")
        end
    end
end

local validator = require("validator")

local run = function(job)
    collectgarbage("collect")
    local cache = {}

    local env = _G
    local cp = {} --classpath

    local status
    local result
    local mfp --main file path

    for i = 1, #job.classpath do
        cp[i] = {}
        cp[i].classname = job.classpath[i].classname
        cp[i].index = job.classpath[i].index
        env.classname = job.classpath[i].classname
        env.index = job.classpath[i].index
        env.operation = job.classpath[i].op
        env.classpath = cp
        env.manifest = job.classpath[i].reg.manifest
        env.resource_url = job.classpath[i].url
        env.ee_auth_token = job.http_request.ee_auth_token
        env.query_string = job.classpath[i].query
        env.is_basictype = validator.is_basic
        env.print_func = job.renderer.printfunc
        env.configure = CFG
        if job.classpath[i].op == 'create' or job.classpath[i].op == 'set' or job.classpath[i].op == "invoke" then
            --load main.lua of addon to check if operation is valid
            env.package.path = _G.package.path..';'..job.classpath[i].reg.origin..'/'..job.classpath[i].reg.addon..'/?.lua'
            env.package.cpath = _G.package.cpath..';'..job.classpath[i].reg.origin..'/'..job.classpath[i].reg.addon..'/?.so'
            mfp = job.classpath[i].reg.origin..'/'..job.classpath[i].reg.addon..'/main.lua' --main file path
            if cache[mfp] == nil then
                local mf = assert(loadfile(mfp))
                setfenv(mf, env)
                local s,r = pcall(mf, job.classpath[i].index)
                if not s then
                    error(r)
                else
                    cache[mfp] = r
                end
            end
            if cache[mfp][job.classpath[i].reg.class][job.classpath[i].op] == nil then
                error({code=501, msg='Not Implemented', detail='"'..job.classpath[i].op..'" is not implemented in addon "'..job.classpath[i].reg.addon..'", class "'..job.classpath[i].classname..'"'})
            end
            --finish checking, class is cached

            env.package.path = _G.package.path..';'..job.content_type.origin..'/'..job.content_type.addon..'/?.lua'
            env.package.cpath = _G.package.cpath..';'..job.content_type.origin..'/'..job.content_type.addon..'/?.so'
            mfp = job.content_type.origin..'/'..job.content_type.addon..'/main.lua'
            if cache[mfp] == nil then
                local mf = assert(loadfile(mfp))
                cache[mfp] = mf()
            end

            setfenv(cache[mfp][job.content_type.mime], env)
            status, result = pcall(cache[mfp][job.content_type.mime], job.http_request.body)
            if status then
                --printtbl(result)
                if job.classpath[i].op ==  "invoke" then
                    validator.validate_arg(result, job.classpath[i].reg.manifest,job.classpath[i].classname, job.classpath[i].op, job.classpath[i].token)
                else
                    validator.validate_content(result, job.classpath[i].reg.manifest,job.classpath[i].classname, job.classpath[i].op)
                end
                if job.classpath[i].op == 'create' then
                    local thekey = job.classpath[i].reg.manifest.classes[job.classpath[i].classname].key
                    if thekey then
                        if not result[thekey] then
                            error("Cannot perform the creation: key \""..thekey.."\" is missing from the request")
                        else
                            job.classpath[i].index = result[thekey]
                            env.index = result[thekey]
                        end
                    end
                end
                env.request = result
            else
                error(result)
            end
        end

        env.package.path = _G.package.path..';'..job.classpath[i].reg.origin..'/'..job.classpath[i].reg.addon..'/?.lua'
        env.package.cpath = _G.package.cpath..';'..job.classpath[i].reg.origin..'/'..job.classpath[i].reg.addon..'/?.so'
        mfp = job.classpath[i].reg.origin..'/'..job.classpath[i].reg.addon..'/main.lua' --main file path
        if cache[mfp] == nil then
            local mf = assert(loadfile(mfp))
            setfenv(mf, env)
            local s,r = pcall(mf, job.classpath[i].index)
            if not s then
                error(r)
            else
                cache[mfp] = r
            end
        end
        --printtbl(cache[mfp])
        local opfunc
        if job.classpath[i].op == 'query' and job.classpath[i].query == 'meta' then
        else
            opfunc = cache[mfp][job.classpath[i].reg.class][job.classpath[i].op]
            if opfunc == nil then
                error({code=501, msg='Not Implemented', detail='"'..job.classpath[i].op..'" is not implemented in addon "'..job.classpath[i].reg.addon..'", class "'..job.classpath[i].classname..'"'})
            end
            setfenv(opfunc, env)
        end
        --print(job.classpath[i].op, opfunc)

        if job.classpath[i].op == 'invoke' then
            status,result  = pcall(opfunc, job.classpath[i].token, job.classpath[i].index)
        elseif job.classpath[i].op == 'query' and job.classpath[i].query == 'meta' then
            status, result = true, {}
        else
            status,result  = pcall(opfunc, job.classpath[i].index)
        end

        if job.classpath[i].op == 'query' and job.classpath[i].query == 'meta' then
        else
            if status then
                if (job.classpath[i].op == 'enum' or job.classpath[i].op == 'query') and (job.classpath[i].reg.manifest.classes[job.classpath[i].classname].key ~=nil) and result.groupname == nil  then
                    result.groupname = job.classpath[i].classname.."_set"
                end
                if job.classpath[i].op == 'enum' or job.classpath[i].op == 'get' or job.classpath[i].op == 'query' then
                    for k, v in pairs(result.instances) do
                        if v.children == nil then
                            v.children = {}
                            for kk, vv in pairs(job.classpath[i].reg.children) do
                                if k == '' or job.classpath[i].index then
                                   v.children[kk] = job.classpath[i].url..'/'..url_esc(kk)
                                else
                                    v.children[kk] = job.classpath[i].url..'/'..url_esc(k)..'/'..url_esc(kk)
                                end
                            end
                        end
                    end
                end
            else
                error(result)
            end
        end
        --if type(result) == table then printtbl(result) else print("+++++++++++",result) end
    end
    if result then
        if job.classpath[#job.classpath].op == 'enum' or job.classpath[#job.classpath].op == 'get' or job.classpath[#job.classpath].op == 'query' then
            mfp = job.renderer.origin..'/'..job.renderer.addon..'/main.lua' --main file path
            if cache[mfp] == nil then
                local mf = assert(loadfile(mfp))
                cache[mfp] = mf()
            end
            local rendererfunc = cache[mfp][job.renderer.mime]
            lfs.chdir(job.renderer.origin..'/'..job.renderer.addon)
            local s, r
            if job.classpath[#job.classpath].op == 'query' and job.classpath[#job.classpath].query == 'meta' then
                if type(rendererfunc) == 'function' or (type(rendererfunc) == 'table' and rendererfunc.meta == nil) then
                    error({code=501, msg='Not Implemented', detail='Querying metadata is not implemented for MIME type "'..job.renderer.mime..'".'})
                else
                    print(env.manifest)
--                    print(job.classpath[#job.classpath].repg.origin..'/'..job.classpath[#job.classpath].reg.addon..'/'..'doc.lua')
                    local docfunc = loadfile(job.classpath[#job.classpath].reg.origin..'/'..job.classpath[#job.classpath].reg.addon..'/'..'doc.lua')
                    if docfunc ~= nil then
                        local doc = docfunc()
                        local function mergedoc(doc, manifest)
                            if type(doc) == 'table' then
                                for k,v in pairs(doc) do
                                    if manifest[k] == nil then manifest[k] = v end
                                    if type(v) == 'table' then
                                        mergedoc(v,manifest[k])
                                    end
                                end
                            end
                        end
                        mergedoc(doc, env.manifest)
                        printtbl(env.manifest)
                        doc = nil
                        docfunc = nil
                    end

                    setfenv(rendererfunc.meta, env)
                    s,r = pcall(rendererfunc.meta, job.renderer.printfunc, job.renderer.mime, result)
                end
            else
                if type(rendererfunc) == 'function' then
                    setfenv(rendererfunc, env)
                    s,r = pcall(rendererfunc, job.renderer.printfunc, job.renderer.mime, result)
                elseif type(rendererfunc) == 'table' then
                    if rendererfunc.render ~= nil then
                        setfenv(rendererfunc.render, env)
                        local s,r = pcall(rendererfunc.render, job.renderer.printfunc, job.renderer.mime, result)
                    else
                        error({code=501, msg='Not Implemented', detail='Representation for MIME type "'..job.renderer.mime..'" is not implemented.'})
                    end
                elseif rendererfunc == nil then
                    error({code=501, msg='Not Implemented', detail='Representation for MIME type "'..job.renderer.mime..'" is not implemented.'})
                end
            end
            if not s then
                logger('Running renderer failed: '..job.renderer.mime)
            end
        elseif job.classpath[#job.classpath].op == "invoke" then
            msg({code=200, msg="OK", detail = result})
        end
    else
        if job.classpath[#job.classpath].op == "create" then
            msg({code=200, msg="OK", detail = 'Successfully created "'..job.classpath[#job.classpath].token..' '..job.classpath[#job.classpath].index..'"'})
        elseif job.classpath[#job.classpath].op == "delete" then
            msg({code=200, msg="OK", detail = 'Successfully deleted "'..job.classpath[#job.classpath].token..' '..job.classpath[#job.classpath].index..'"'})
        elseif job.classpath[#job.classpath].op == "set" then
            if job.classpath[#job.classpath].index then
                msg({code=200, msg="OK", detail = 'Successfully modified "'..job.classpath[#job.classpath].token..' '..job.classpath[#job.classpath].index..'"'})
            else
                msg({code=200, msg="OK", detail = 'Successfully modified "'..job.classpath[#job.classpath].token..'"'})
            end
        end
    end
end

return({run=run})

