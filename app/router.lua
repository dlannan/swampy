-- Router - This is a router/proxy for the main front end of swampy  --
--          Connections attempt to connect to the router, then based --
--          on the connection, it begins a process for the new       --
--          connection. 

--    Example: 
--     - Client game WarGames requests connect
--     - Router creates connection. 
--     - Check game and player id.
--     - If there is a match then link to the running game or;
--     - If a new game is needed, create a game process and launch or;
--     - Close connection and add error, with potential blacklist on IP.

-- Main Sections:
--     Connection 
--     Authentication
--     Tunnel / Route 

package.path = package.path..";./deps/?.lua;./deps/?/init.lua"
package.path = package.path..";./deps/path/?.lua;./deps/stream/?.lua"
package.path = package.path..";./deps/luvit-websocket/?.lua"
package.path = package.path..";./deps/luvit-websocket/libs/?.lua"
package.path = package.path..";./deps/tls/?.lua"
---------------------------------------------------------------------------------

local ffi = require("ffi")


---------------------------------------------------------------------------------
local http      = require("http")
local https     = require("https")
local pathJoin  = require('luvi').path.join
local fs        = require('fs')
local uv        = require('uv')
local aes       = require('lua.aes')
local liluat    = require("lua.liluat")
local url       = require("lua.url")
local utils     = require("lua.utils")
local timer     = require "deps.timer"

---------------------------------------------------------------------------------
-- TODO: Make an arg, instead. This is very temp.
local SERVER_IP     = "0.0.0.0"
---------------------------------------------------------------------------------

require('lua.pretty-print')
local dbg           = require('lua.debugger')

local tcpserve      = require("app.dataserver")

---------------------------------------------------------------------------------
-- Init before assignments
tcpserve.init(args)


---------------------------------------------------------------------------------
-- API Handlers 
require("lua.api-handlers.userlogin")
require("lua.api-handlers.userauthenticate")
require("lua.api-handlers.userconnect")
require("lua.api-handlers.userupdate")

require("lua.api-handlers.datagettable")
require("lua.api-handlers.datasettable")

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
    ['/user/login']         = api_userLogin or function() end,
    ['/user/authenticate']  = api_userAuthenticate or function() end,
    ['/user/connect']       = api_userConnect or function() end,
    ['/user/close']         = api_userClose or function() end,
    ['/user/update']        = api_userUpdate or function() end,

    ['/data/gettable']      = api_dataGetTable or function() end, 
    ['/data/settable']      = api_dataSetTable or function() end,

    ['/game/find']          = api_gameFind or function() end,
    ['/game/create']        = api_gameCreate or function() end,
    ['/game/join']          = api_gameJoin or function() end,
    ['/game/leave']         = api_gameLeave or function() end,
    ['/game/close']         = api_gameClose or function() end,

    ['/game/update']        = api_gameUpdate or function() end,
}

---------------------------------------------------------------------------------

local function handleAPIEndpoints( client, req, res, body )

    local urltbl = url.parse(req.url)
    -- Split path to check token
    local path = urltbl.path
    local pathitems = utils.split(path, "/")

    if( tcpserve.checkAPIToken( pathitems[4] ) ~= true ) then return end
    local funcpath = ""
    for i=5, #pathitems do funcpath = funcpath.."/"..pathitems[i] end

    local handled = nil
    local handleFunc = EndpointAPITbl[funcpath]
    local output    = ""
    local mode      = "html"
    if(handleFunc) then 
        if(req.method == "OPTIONS") then -- preflight call - return ok
            output  = ""
            mode    = "preflight"
        else 
            output = handleFunc( client, req, res, body )
            mode    = "json"
            handled = true 
        end 
    end 
    return handled, output, mode
end

---------------------------------------------------------------------------------

local function processRequest(req, res, body)

    if( req.url == nil ) then 
        utils.sendhtml(res, "")
        return
    end

    local tcp = req.socket._handle
    local client = uv.tcp_getpeername( tcp )

    -- Api calls always first. These fan out - when a game starts then it handles its sockets
    if( string.match(req.url, "^/api/v1/") ) then 
        local handled, output, mode = handleAPIEndpoints(client, req, res, body)
        if(mode == "json") then 
            utils.sendjson(res, output) 
        elseif(mode == "preflight") then 
            utils.sendpreflight( req, res )
        elseif(mode == "html" and output) then 
            utils.sendhtml( res, output )
        end
        return -- Always exit with api calls
    end
end 

---------------------------------------------------------------------------------

local qs = require('querystring');

function onRequest(req, res) 
   
	local body = '';
	--req.setEncoding('utf8');
	req:on('data', function(chunk) body = body..chunk end);
	req:on('end', function()
		local obj = qs.parse(body)
		processRequest(req, res, body)
	end);
end

---------------------------------------------------------------------------------

local wshandle = nil 

local function checkWebServer( )

end

local function run(port)

    ---------------------------------------------------------------------------------
    -- Need to auto update keys from lets encrypt
    local key = fs.readFileSync("./keys/privkey.pem")
    local cert = fs.readFileSync("./keys/fullchain.pem")

    ---------------------------------------------------------------------------------
    https.createServer({ key = key, cert = cert }, onRequest):listen(port)
    p("Router listening at https://"..SERVER_IP..":"..port.."/")

    -- Watch this webserver. If it dies, then restart it.
    timer.setInterval( 1000, checkWebServer )
    
    -- Need to catch sig and close (for proper shutdown)
    --tcpserve.close()
    ---------------------------------------------------------------------------------
    -- No general "module loop". Each game (module) will run an instance for each
    --   game it needs.
    -- tcpserve.runModules()


    print("Started...")
end

---------------------------------------------------------------------------------
-- Kill the webserver 
local function stop()
    
end

---------------------------------------------------------------------------------

return {
    run     = run,
    stop    = stop,
}
