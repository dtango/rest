--
-- Created by: ssudakov
-- Date: 8/8/12 10:06 AM
--
return {
    addon_name = 'hyperv',
    addon_type = 'REST',
    version = 1.0,
    revision = 0,
    types = {
        t_fnd = {
            id = { type = 'string' },
            name = { type = 'string' },
            logicalNetwork = { type = 'string' },
            intraPortCommunication = { type = 'boolean' },
            naitiveNetworkSegment = { type = 'string' },
        },

        t_ippool = {
            name = { type = 'string' },
            description = { type = 'string' },
            addressFamily = { type = 'string' },
            addressRangeStart = { type = 'string' },
            addressRangeEnd = { type = 'string' },
            networkAddress = { type = 'string' },
            ipAddressSubnet = { type = 'string' },
            networkGateways = { type = 'string' },
        },
         
        t_dot1q2map = {
            ['dot1q']         = {type = 'number'},
            ['bridgeDomain']  = {type = 'string'},
        },
        t_mappings = {
            mapping   = {type = 't_dot1q2map', is_array=true},
        },
    },
    classes = {
        hyper_v = {},
        switch_extension_info = {
            properties = {
                id = { type = 'string' },
                maxVersion = { type = 'string' },
                minVersion = { type = 'string' },
                name = { type = 'string' },
                drivernetcfginstanceid = { type = 'string' },
                opdata = { type = 'string' },
                maxNumberOfPorts = {type = 'number'},
                maxNumberOfPortsPerHost = {type = 'number'},
                switchExtensionFeatureConfigId = { type = 'string' },
                isSwitchTeamSupported = { type = 'boolean' },
                extensionType = { type = 'string' },
                mandatoryFeatureId = { type = 'string' },
                isChildOfWFPSwitchExtension = { type = 'boolean' },
            }
        },
        vsem_system_info = {
            properties = {
                id = { type = 'string' },
                description = { type = 'string' },
                manufacturer = { type = 'string' },
                version = { type = 'string' },
                model = { type = 'string' },
                name = { type = 'string' },
                vendorId = { type = 'string' },
            }
        },
        network_segment_pool = {
            key = 'name',
            properties = {
                id = { type = 'string' },
                name = { type = 'string' },
                description = { type = 'string' },
                tenantId = { type = 'string' },
                logicalNetwork = { type = 'string' },
                intraPortCommunication = { type = 'boolean' },
                supportsVMNetworkProvisioning = { type = 'boolean'},
                supportsIpPool = { type = 'boolean'},
                -- naitiveNetworkSegment = { type = 'string' },
                maximumNetworkSegmentsPerVMNetwork = {type = 'number'},
            }
        },
        network_segment = {
            key = 'name',
            properties = {
                id = { type = 'string' },
                name = { type = 'string' },
                description = { type = 'string' },
                tenantId = { type = 'string' },
                vlan = { type = 'string' },
                networkSegmentPool = { type = 'string' },
                ipPool = { type = 'string' },
                ipPoolId = {type = 'string'},
                publishName = { type = 'string' },
                vmNetwork = { type = 'string' },
                vmNetworkId = { type = 'string' },
                maxNumberOfPorts = {type = 'number'},
                segmentType = { type = 'string' },
                bridgeDomain = { type = 'string' },
                deleteSubnet = { type = 'boolean' },
                mode = { type = 'string' },
                addSegments = { type = 'string' }, 
                delSegments = { type = 'string' }, 
            },
        },
        ip_pool_template = {
            key = 'name',
            properties = {
                id = { type = 'string' },
                name = { type = 'string' },
                description = { type = 'string' },
                tenantId = { type = 'string' },
                addressRangeStart = { type = 'string' },
                addressRangeEnd = { type = 'string' },
                networkAddress = { type = 'string' },
                ipAddressSubnet = { type = 'string' },
                gateway = { type = 'string' },
                netbt = { type = 'boolean' },
                dhcp = { type = 'boolean' },
                reservedIpList = { type = 'string' },
                netbiosServersList = { type = 'string' },
                dnsServersList = { type = 'string' },
                dnsSuffixList = { type = 'string' },
                addressFamily = { type = 'string' },
                netSegmentName = { type = 'string' },
            },
        },
        uplink_port_profile = {
            key = 'name',
            properties = {
                id = { type = 'string' },
                name = { type = 'string' },
                type = { type = 'string' },
                state = { type = 'string' },
                networkSegmentPool = { type = 'string' },
                switchId = { type = 'string' },
                maxPorts = { type = 'string' },
            },
        },
        virtual_port_profile = {
            key = 'name',
            properties = {
                id = { type = 'string' },
                name = { type = 'string' },
                type = { type = 'string' },
                state = { type = 'string' },
                networkSegmentPool = { type = 'string' },
                switchId = { type = 'string' },
                maxPorts = { type = 'number' },
                maxNumberOfPortsPerHost = {type = 'number'},
            },
        },
        vm_network = {
            key = 'name',
            properties = {
                id = { type = 'string' },
                name = { type = 'string' },
                tenantId = { type = 'string' },
                networkSegment = { type = 'string' },
                networkSegmentId = { type = 'string' },
                portId = { type = 'string' },
                portProfile = { type = 'string' },
                portProfileId = { type = 'string' }, 
                macAddress = { type = 'string' }, 
                subnetId = { type = 'string' },
                ipAddress = { type = 'string' },
           }
        },
        vm_network_ports = {
            key = 'id',
            properties = {
                id = { type = 'string' },
                macAddress = { type = 'string' }, 
                subnetId = { type = 'string' },
                ipAddress = { type = 'string' },
           }
        },
        bridge_domain = {
            key = 'name',
            properties = {
                name = { type = 'string' },
                portCount = { type = 'string' },
                segmentId = { type = 'string' },
                groupIp = { type = 'string' },
                state = { type = 'string' },
                macLearning = { type = 'string' },
                subType = { type = 'string' },
                tenantId = { type = 'string' },
            }
        },   
        events = {
            key = 'count',
            properties = {
                time = { type = 'number' },
                event_type = { type = 'string' },
                id = { type = 'string' },
                name = {type = 'string'},
                user = { type = 'string' },
                cmd = { type = 'string' },
            },
        },
        logical_network = {
            key = 'name',
            properties = {
                description = { type = 'string' },
                name = { type = 'string' },
                tenantId = { type = 'string' },
            },
        },
        encapsulation_profile = {
            key = 'name',
            properties = {
                name  = { type = 'string' },
                addMappings = { type = 'string' },
                delMappings = { type = 'string' },
                dot1q ={ type = 'number' },
                bridgeDomain = { type = 'string' },
                mappings = { type = 't_mappings' },
            },
        },
    }
}

