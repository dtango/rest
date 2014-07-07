--
-- Created by IntelliJ IDEA.
-- User: skolar
-- Date: 5/13/13
-- Time: 11:40 PM
-- To change this template use File | Settings | File Templates.
--
return {
    addon_name = 'vxlan',
    addon_type = 'REST',

    classes = {
        vxlan = { key = "name",
            properties = {
                id     = {attrib="rw", type = "number",},
                name   = {attrib="rw", type = "string",},
                group  = {attrib="rw", type = "string",},
                state  = {attrib="rw", type = "string",},
                ports  = {attrib="rw", type = "string",},
                mode   = {attrib="rw", type = "string",},
                macLearn = {attrib="rw", type = "string",},
                macDist= {attrib="rw", type = "string",},
            }
        },
    }
}
