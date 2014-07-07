return {
    addon_name = 'pp',
    addon_type = 'REST',
    version = 1.0,
    revision = 0,

    types = {
    },

    classes = {
        pp = { key = "name",
               properties = {
                   name = {type = "string", attrib = "rw"},
                   type = {type="string", attrib = "rw"}, --ethernet,vethernet
                   description = {type = "string", attrib = "rw"},
                   portGroupName = {type= "string", attrib = "rw"}, --esxi only
                   minPorts = {type = "number", attrib = "rw"},
                   maxPorts = {type = "number", attrib = "rw"},
                   portBinding = {type="string", attrib = "rw"}, --static, static auto, dynamic, dynamic auto, ephemeral
                   state = {type="boolean", attrib = "rw"}, --true==enabled
                   shutdown = {type="boolean", attrib = "rw"}, --false==no shutdown
                   switchportMode = {type="string", attrib = "rw"}, --trunk, access
                   switchportTrunkVLANs = {type="number", is_array=true, attrib = "rw"},
                   switchportTrunkNativeVLAN = {type="number",attrib = "rw"},
                   switchportAccessVLAN = {type="number",attrib = "rw"},
                   switchportAccessBridgeDomain = {type="string",attrib = "rw"}, --""==no switchport access bridge-domain
                   apability = {type="string", is_array=true, attrib = "rw"}, --l3-vn-service,vxlan,l3control,iscsi-multipath
                   org = {type="string",attrib = "rw"},
                   mtu = {type="number",attrib = "rw"},
                   profileConfig = {type="string",is_array = true,attrib = "rw"},
                   vservicePath = {type="string",attrib = "rw"},
                   vserviceNodeName = {type="string",attrib = "rw"},
                   vserviceProfile = {type="string",attrib = "rw"},
                   inherit = {type="string",attrib = "rw"},
             }
        },
    }
}

