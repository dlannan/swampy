
-- Handle data related endpoints

package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/luvit-websocket/?.lua"
package.path = package.path..";./deps/luvit-websocket/libs/?.lua"
package.path = package.path..";./deps/tls/?.lua"

---------------------------------------------------------------------------------

local cfg       = require("app.server-config")

---------------------------------------------------------------------------------
-- API Handlers 

require("lua.api-handlers.datagettable")
require("lua.api-handlers.datasettable")

---------------------------------------------------------------------------------

-- All api endpoints must match a complete path
-- TODO: Publish these for users to access!
-- Format: /api/v1/<token>/<feature>/<function>?<params>
-- Output: Always returns json. Minimum is empty json object {}
local EndpointAPITbl = {

    [cfg.API_VERSION..'/data/gettable']      = api_dataGetTable or function() end, 
    [cfg.API_VERSION..'/data/settable']      = api_dataSetTable or function() end,
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