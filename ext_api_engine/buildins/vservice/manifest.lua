return {
    addon_name = 'vservice',
    addon_type = 'REST',
    version = 1.0,
    revision = 0,

    types = {
        t_node    = {
            node = {type = "string",},
            profileName = {type = "string",},
            order = {type = "number",}, --1..1000
        },
    },

    classes = {
        node = { key = "name",
            properties = {
                name        = {type = "string",},
                type = {type="string",}, --vsg, asa, ace
                ipAddr = {type = "string",}, --""==no ip address
                adjacency = {type = "string",}, -- l2-vlan <id>, l2-vxlan <bd-name>, l3, ""== no adjacency
                failmode = {type="string",}, --open,close,""
            }
        },
        path = { key = "name",
            properties = {
                name        = {type = "string",},
                nodes       = {type = "t_node", is_array="true"}, --one of a type only
            }
        },
    }
}
