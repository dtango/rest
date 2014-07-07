return {
    addon_name = 'span',
    addon_type = 'REST',
    version = 1.0,
    revision = 0,

    types = {
        t_source    = {
            type = {type="string", attrib="rw"}, --ethernet, vethernet, port-channel, vlan, port-prfoile
            direction = {type="string", attrib="rw"}, --rx,tx,[both]
            source = {type="string", is_array=true, attrib="rw"}, --is slot/port when ethernet else "<number>" when veth,vlan,port-channel "<number>.<number>" also for port-channel
        },
    },

    classes = {
        span = { key = "id",
               properties = {
                   id = {type = "number", attrib="rw"}, --1-64
                   type = {type="string",attrib="rw"}, --[span], erspan
                   description = {type = "string", attrib="rw"},
                   shutdown = {type="boolean", attrib="rw"}, --false==no shutdown
                   sources = {type = "t_source", is_array=true, attrib="rw"},
                   filterVlans = {type = "number", is_array=true, attrib="rw"},

--valid for type span
                   destPortProfile = {type="string", is_array=true, attrib="rw"},
                   destPortChannels = {type = "string", is_array=true, attrib="rw"}, --1-4096
                   destVethIfs = {type = "number", is_array=true, attrib="rw"}, --1-1048575
                   destEthIfs = {type = "string", is_array=true, attrib="rw"}, --1-130

--valid for type erspan
                   destIpAddr = {type="string", attrib="rw"},
                   erSpanId = {type="number", attrib="rw"}, --1-1023
                   headerType = {type="number", attrib="rw"}, --2,3
                   dscp = {type="number", attrib="rw"}, --0-63
                   prec = {type="number", attrib="rw"}, --0-7
                   ttl = {type="number", attrib="rw"}, --1-255
                   mtu = {type="number", attrib="rw"}, --50-9000

                   config = {type="string", is_array=true, attrib="rw"} -- use this to accept configs like  "no source vethernet 1" to remove src/dest from session else will have to delete all source destinations to recreate with current src-dest points and interrupt the span traffic. Seems cruel to lose this ability via REST API
             }
        },
    }
}
