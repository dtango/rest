return {
   addon_name = 'api',
   addon_type = 'REST',
   version = 1.0,
   revision = 0,
   classes = {
      api = {
          methods = {
              cli = {
                  cmd ={
                      type = "string",
                      mandatory = true
                  }
              },
              scp = {
                  username ={type = "string",mandatory = true},
                  password ={type = "string",mandatory = true},
                  address ={type = "string",mandatory = true},
                  path ={type = "string",mandatory = true},
              },
              save_config  ={
                  filename ={type = "string",mandatory = true}
              },
              load_plugin = {
                  plugin = {type = 'string',mandatory = true},
              }
         }
      },
   }
}

