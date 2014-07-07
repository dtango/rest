return {
    addon_name = 'vpath',
    addon_type = 'REST',
    version = 1.0,
    revision = 0,

    types = {
        t_node    = {
            node = {doc= "",},
            profileName = {doc= "",},
            order = {doc= "[1..1000]",},
        },
    },

    classes = {
        node = { key = "name",
            properties = {
                name = {doc= "string",},
                type = {doc="{vsg, asa, ace}",},
                ipAddr = {doc= "set to \"\"to remove ip address",}, 
                adjacency = {doc= "l2-vlan <id>, l2-vxlan <bd-name>, l3, \"\"== no adjacency"},
                failmode = {doc="{open, close}",}, 
            }
        },
        path = { key = "name",
            properties = {
                name        = {doc= "",},
                nodes       = {doc="one of a type permitted"}, 
            }
        },
    }
}
