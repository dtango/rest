--nxos customized
return {
   REST_ROOTPATH = '',
   LUALIB_PATH = "/isan/ext_api_engine/lib/?.lua;/isan/ext_api_engine/ee/?.lua",
   LUALIB_CPATH = "/isan/ext_api_engine/lib/?.so",
   BUILDINS_DIR = "/isan/ext_api_engine/buildins",
   BUILDIN_REG_FILE = "/isan/ext_api_engine/buildins/urlreg.lua",
   DEFAULT_CONTENT_TYPE = "application/json",
   DEFAULT_RENDERER_TYPE = "application/xml",
   PLATFORM_NAME = "NX1000V",
   EE_VER = 1.0,
   EE_REV = 0,
   PLATFORM_VER = 1.0,
   PLATFORM_REV = 0,
   HTTP_TIMEOUT = 30,
   PORT = 8888,
   ADDRESS = "0.0.0.0",
   MAX_THREADS = 10,

   LOG_FILE = "/mnt/debug/ee.log",
   LOG_FILE_SIZE = 51200,
   LOG_FILE_ROTATION = 2,
   LOG_TO_STDOUT = true,
   LOG_TRACE = true,

}

