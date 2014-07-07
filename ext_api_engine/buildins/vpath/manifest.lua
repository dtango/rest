return {
    addon_name = 'vpath',
    addon_type = 'REST',
    version = 1.0,
    revision = 0,

    types = {
        t_node    = {
            name = {type = "string",},
            order = {type = "number",}, --1..1000
        },
        t_overlay = {
            encapType = {type = "string",},                
            segmentType = {type = "string",},
            segmentValue = {type = "string",},
        },
        t_dict_servicepath = {
            direction = {type = "string",},                
            vlans = {type = "number", is_array="true"},
        },
        t_dict_actionpath = {
            name = {type = "string",},                
            vlans = {type = "number", is_array="true"},
        },
    },

    classes = {
        vpath = {},
        v1 = {},
        node = { key = "name",
            properties = {
                name        = {type = "string",},
                type = {type="string",}, --vsg, asa, ace
                ipAddress = {type = "string",}, --""==no ip address
                failMode = {type="string",}, --open,close,""
                operationMode = {type="string",},   --opern-mode terminated,transparent
                adminState = {type = "string",},  --up, down
                isAgentless = {type = "string",}, --
                overlay = {type = "t_overlay"}, 
                id = {type = "string",},
                forwarderIP = {type = "string",},
                module = {type = "string",},
            }
        },
        path = { key = "name",
            properties = {
                name        = {type = "string",},
                serviceNodes       = {type = "t_node", is_array="true"},
--                profileName = {type = "string",},
                id      = {type = "string",}, 
                rawId   = {type = "string",}, 
--                location  = {type = "string",},
            }
        },
         pool = { key = "name",
            properties = {
                name        = {type = "string",},
                predictor   = {type = "string",},
                serviceNodes  = {type = "string", is_array="true"},
                id = {type = "number",},
            }
        },
         vrf = { key = "vrfId",
            properties = {
                vrfId        = {type = "number",},
            }
        },
         vrfmap = { key = "id",
            properties = {
                inVrfId        = {type = "number",},
                outVrfId       = {type = "number",},
                id             = {type = "number",},
            }
        },
         idletime = { key = "protocol",
            properties = {
                protocol      = {type = "string",},
                timeout       = {type = "number",},
            }
        },
         port = { key = "macAddress",
            properties = {
                macAddress  = {type = "string",},
                owner       = {type = "string",},
                type       = {type = "string",},
                servicePathBinding = {type = "t_dict_servicepath",},
                activeServicePath = {type = "t_dict_actionpath",},
            }
        },
    }
}

