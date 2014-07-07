return {
    addon_name = 'vxlan',

    classes = {
        vxlan = { key = "id",
            doc = 'vxlan document',
            properties = {
                id     = {doc='Vxlan id valid value : <4096-16000000> '},
                name   = {doc='Name of the Vxlan (should be unique)'},
                state  = {doc="Shut State of the vxlan valid state active or suspend"},
                mode   = {doc=""},
                macDist= {doc=""},
                group  = {doc="group name. Set null value to remove."},
                ports  = {doc=""},
                macLearn = {doc=""},
            },
            operations = {
                get = true,
                enum = true,
                delete = true,
                create = true,
                set = true,
                query = false,
            }
        },
    }
}

