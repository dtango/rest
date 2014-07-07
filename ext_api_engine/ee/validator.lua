local basetypes = {string=true, number=true, boolean=true,
    int8=true, int16=true,int32=true, int64=true,
    uint8=true, uint16=true, uint32=true,uint64=true,
    decimal64=true }

local function is_basic(t)
    return basetypes[t] ~= nil
end

local manifest

local function validate_type(name, value, meta)
    if value ~= NULL then
        local function err_invalid(n)
            error({code="400", msg="Bad Request", detail='Property field "'..n..'" has invalid type or format'})
        end

        if type(meta) ~= "table" then err_invalid(name) end
        if is_basic(meta.type) then
            if not meta.is_array then
                if not is_basic(type(value)) then
                end
            else
                if type(value) ~= 'table' then
                    err_invalid(name)
                end
                for k,v in pairs(value) do
                    if not is_basic(type(v)) then
                        err_invalid(name..'.'..tostring[k])
                    end

                end
            end
        else
            if manifest.types[meta.type] == nil then
                error({code="400", msg="Bad Request", detail='Undefined type "'..value.type..'"'})
            end
            if type(value) ~= 'table' then
                err_invalid(name)
            else
                if meta.is_array then
                    for i=1, #value  do
                        validate_type(name..'.'..tostring(i),value[i], {type = meta.type}, manifest )
                    end
                else
                    for k,v in pairs(value)  do
                        validate_type(name..'.'..tostring(k),v, manifest.types[meta.type][k] )
                    end
                end
            end
        end
    end
end

local function validate_content(content, m, class, operation)
    manifest = m
    assert(type(content)=="table", "Invalid content, expecting lua table")
    assert(manifest.classes[class])
    for k, v in pairs(content) do
        if manifest.classes[class].properties == nil or not manifest.classes[class].properties[k] then
            error({code="400", msg="Bad Request", detail='Undefined property "'..k..'"'})
        end
        validate_type(k,v, manifest.classes[class].properties[k])
    end

    for k, v in pairs(manifest.classes[class].properties) do
        if v.mandatory then
            if not conetent[k] then
                error({code="400", msg="Bad Request", detail='Mandatory property "'..k..'" is missing'})
            end
        end
    end
end

local function validate_arg(content, m, class, operation, method)
    manifest = m
    assert(type(content)=="table", "Invalid content, expecting lua table")
    assert(manifest.classes[class])
    assert(manifest.classes[class].methods)
    assert(manifest.classes[class].methods[method])
    for k, v in pairs(content) do
        if not manifest.classes[class].methods[method][k] then
            error({code="400", msg="Bad Request", detail='Undefined argument "'..k..'"'})
        end
        validate_type(k,v, manifest.classes[class].methods[method][k])
    end

    for k, v in pairs(manifest.classes[class].methods[method]) do
        if v.mandatory then
            if not content[k] then
                error({code="400", msg="Bad Request", detail='Mandatory argument "'..k..'" is missing'})
            end
        end
    end
end

return {validate_content =  validate_content, validate_arg = validate_arg, is_basic = is_basic}