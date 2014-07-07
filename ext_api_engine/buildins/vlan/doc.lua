local checkPlatform = function ()
--    if platform == "hyperv" then
--    return
--        {
--            get = true,
--            enum = true,
--            delete = false,
--            create = false,
--            set = false,
--            query = false,
--        }
--    else
        return {
                get = true,
                enum = true,
                delete = true,
                create = true,
                set = true,
                query = false,
            }
--    end

end

return {
    addon_name = 'vlan',

    classes = {
        vlan = { key = "id",
            doc = 'vlan document',
            properties = {
                id = {doc='Vlan id <1-3967,4048-4093>'},
                name = {doc='Name of the Vlan (should be unique). Set null value to remove.'},
                shutdown = {doc="Shut State of the vlan"},
                state = {doc="set active or suspended state for the vlan. Set null value to remove."},
            },
            operations = checkPlatform()
        },
    }
}
