return {
    addon_name = 'pp',
    
    types = {
    },

    classes = {
        pp = { key = "name",
            doc = 'port-profile document',
            properties = {
                name = {doc='Name of the port-profile (should be unique)'},
                type = {doc='type of the port-profile (Values can be <ethernet, vethernet>'}, 
                description = {doc='Description of the port-profile. Set null value to remove.'},
                portGroupName = {doc='Name of the portgrouop to be created in esxi'}, 
                minPorts = {doc='Minimum no of ports ESXi only'},
                maxPorts = {doc='Maximum no of ports ESXi only'},
                portBinding = {doc='port-binding behavior of the port-profile ESXi only'},
                state = {doc='state of the port-profile, true=enabled'}, 
                shutdown = {doc='shutdown state of the port-profile, false==no shutdown'}, 
                switchportMode = {doc='switchport mode of the port-profile can be <trunk, access>'}, 
                switchportTrunkVLANs = {doc='trunk vlans to be allowed on the port-profile'}, 
                switchportTrunkNativeVLAN = {doc='nativ vlans to be allowed on the port-profile'},
                switchportAccessVLAN = {doc='Access vlan to be allowed on the port-profile'}, 
                switchportAccessBridgeDomain = {doc='Access bridge-domain to be configured on the port-profile'},
                capability = {doc='Capability  of port-profile <l3-vn-service,vxlan,l3control,iscsi-multipath]'}, 
                org = {doc='Org Name of port-profile'},
                mtu = {mtu='mtu Value for port-profile'},
                vservicePath = {doc='vservice path  of port-profile'},
                vserviceNodeName = {doc='vervice node name of port-profile'},
                vserviceProfile = {doc='vservice proifle name of port-profile'},
                inherit = {doc='name of port-profile to inherit settings from. Set null value to remove.'}
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
