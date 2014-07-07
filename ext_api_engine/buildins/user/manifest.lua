--
-- Created by IntelliJ IDEA.
-- User: jasonxu
-- Date: 5/13/13
-- Time: 11:40 PM
-- To change this template use File | Settings | File Templates.
--

return {
    addon_name = 'user',
    addon_type = 'REST',

    classes = {
        user = { key = "name",
            properties = {
                name        = {type = "string",},
                password        = {type = "string",},
                expire          = {type = "string",},
                role            = {type = "string",is_array = true},
            }
        },
    }
}

