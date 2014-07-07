--
-- Created by IntelliJ IDEA.
-- User: jasonxu
-- Date: 5/13/13
-- Time: 11:40 PM
-- To change this template use File | Settings | File Templates.
--

return {
    addon_name = 'vlan',
    addon_type = 'REST',

    classes = {
        vlan = { key = "id",
            properties = {
                id        = {type = "number", attrib="rw"},
                name        = {type = "string", attrib="rw"},
                shutdown   = {type = "boolean", attrib="rw"},
                state          = {type = "string", attrib="rw"},
            }
        },
    }
}
