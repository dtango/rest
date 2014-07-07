return {
    addon_name = 'user',

    classes = {
        user = { key = "name",
            doc = 'user document',
            properties = {
                name = {doc='User name'},
                password = {doc='Password for the user (alphanumeric clear text) (Max Size 64) (Min size 8)', attrib='rw'},
                role      = {doc="Role which the user is to be assigned to (its an array of Strings example: ["network-admin", "network-operator"])", attrib='rw'},
                expire    = {doc="Expiry date for this user account(in YYYY-MM-DD format)"}, attrib='rw',
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
