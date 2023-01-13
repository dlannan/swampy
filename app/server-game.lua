
-- Handle game related endpoints


package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/luvit-websocket/?.lua"
package.path = package.path..";./deps/luvit-websocket/libs/?.lua"
package.path = package.path..";./deps/tls/?.lua"

---------------------------------------------------------------------------------

local cfg       = require("app.server-config")

---------------------------------------------------------------------------------
-- API Handlers 
require("lua.api-handlers.gamecreate")
require("lua.api-handlers.gamefind")
require("lua.api-handlers.gamejoin")
require("lua.api-handlers.gameleave")
require("lua.api-handlers.gameclose")

require("lua.api-handlers.gameupdate")

---------------------------------------------------------------------------------

-- All api endpoints must match a complete path
-- TODO: Publish these for users to access!
-- Format: /api/v1/<token>/<feature>/<function>?<params>
-- Output: Always returns json. Minimum is empty json object {}
local EndpointAPITbl = {

    [cfg.API_VERSION..'/game/find']          = api_gameFind or function() end,
    [cfg.API_VERSION..'/game/create']        = api_gameCreate or function() end,
    [cfg.API_VERSION..'/game/join']          = api_gameJoin or function() end,
    [cfg.API_VERSION..'/game/leave']         = api_gameLeave or function() end,
    [cfg.API_VERSION..'/game/close']         = api_gameClose or function() end,

    [cfg.API_VERSION..'/game/update']        = api_gameUpdate or function() end,
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