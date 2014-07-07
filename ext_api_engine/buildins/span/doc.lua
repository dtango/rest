return {
    addon_name = 'span',

    types = {
        t_source    = {
            type = {doc="ethernet, vethernet, port-channel, vlan, port-profile"},
            direction = {doc="rx,tx,[both]"},
            source = {doc="<slot>/<port> when ethernet, <number> when veth,vlan,port-channel, port-channel includes <number>.<number>"},
        },
    },


    classes = {
        span = { key = "id",
               doc = 'span document',
               properties = {
                   id = {doc='ID of the span/erspan (should be unique)'}, --1-64
                   type = {doc='type of the session (Values can be <local, erspan-source>)'}, 
                   description = {doc='Description of the monitor session'},
                   shutdown = {doc='shutdown state of the monitor session'}, --false==no shutdown
                   sources = {doc="source interface/vlan/port-profile which has type/direction/source"},
                   filterVlans = {doc='vlans to be filtered on the monitor session'}, --trunk, access

--valid for type span
                   destPortProfile = {doc='destination port-profile for the monitor session'}, --trunk, access
                   destPortChannels = {doc='destination port-channel for the monitor session'}, --trunk, access
                   destEthIfs = {doc='destination ethernet interfaces for the monitor session'}, --trunk, access
                   destVethIfs = {doc='destination vethernet interfaces for the monitor session'}, --trunk, access

--valid for type erspan
                   destIpAddr = {doc='destination ip address for the monitor session'}, 
                   erSpanId = {doc='erspan id for the monitor session (Values can be <1-1023>)'}, 
                   headerType = {doc='header type for the monitor session (Values can be <2-3>)'}, 
                   dscp = {doc='ip dscp value for the monitor session (Values can be <0-63>)'}, 
                   prec = {doc='ip precedence value for the monitor session (Values can be <0-7>)'}, 
                   ttl = {doc='ip time-to-live value value for the monitor session (Values can be <1-255>'}, 
                   mtu = {doc='mtu value for the monitor session (Values can be <50-9000>)'}, 
                   config = {doc='configs for the monitor session'}, 

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

