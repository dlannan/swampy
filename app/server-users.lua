-- Handle user related endpoints


package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/luvit-websocket/?.lua"
package.path = package.path..";./deps/luvit-websocket/libs/?.lua"
package.path = package.path..";./deps/tls/?.lua"

---------------------------------------------------------------------------------

local cfg       = require("app.server-config")

---------------------------------------------------------------------------------
-- API Handlers 
require("lua.api-handlers.userlogin")
require("lua.api-handlers.userauthenticate")
require("lua.api-handlers.userconnect")
require("lua.api-handlers.userupdate")

---------------------------------------------------------------------------------

-- All api endpoints must match a complete path
-- TODO: Publish these for users to access!
-- Format: /api/v1/<token>/<feature>/<function>?<params>
-- Output: Always returns json. Minimum is empty json object {}
local EndpointAPITbl = {
    [cfg.API_VERSION..'/user/login']         = api_userLogin or function() end,
    [cfg.API_VERSION..'/user/authenticate']  = api_userAuthenticate or function() end,
    [cfg.API_VERSION..'/user/connect']       = api_userConnect or function() end,
    [cfg.API_VERSION..'/user/close']         = api_userClose or function() end,
    [cfg.API_VERSION..'/user/update']        = api_userUpdate or function() end,
}

---------------------------------------------------------------------------------

local function handleEndpoint( url, client, req, res, body )
    local output = ""

    local handleFunc = EndpointAPITbl[url]
    if(handleFunc) then 
        output = handleFunc( client, req, res, body )
    end
    return output
end

---------------------------------------------------------------------------------

return {

    handleEndpoint      = handleEndpoint,
}