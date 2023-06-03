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

local cfg       = require("app.server-config")
local pipe      = require("lua.pipe")

---------------------------------------------------------------------------------

require('lua.pretty-print')
local dbg           = require('lua.debugger')
local tcpserve      = require("app.dataserver")

---------------------------------------------------------------------------------
-- Init before assignments
tcpserve.init(args)

---------------------------------------------------------------------------------

-- All api endpoints must match a complete path
-- TODO: Publish these for users to access!
-- Format: /api/v1/<token>/<feature>/<function>?<params>
-- Output: Always returns json. Minimum is empty json object {}
local EndpointAPITbl = {
    [cfg.API_VERSION..'/user/']         = require("app.server-users"),
    [cfg.API_VERSION..'/data/']         = require("app.server-data"), 
    [cfg.API_VERSION..'/game/']         = require("app.server-game"),
}

---------------------------------------------------------------------------------

local function handleAPIEndpoints( client, req, res, body )

    -- p(req)
    local token = req.headers["APIToken"]

    -- Check headers first. If token is incorrect. Bail early
    if( token ) then 

        local urltbl = url.parse(req.url)
        if( tcpserve.checkAPIToken( token ) ~= true ) then return end
        local endpointType = string.sub(urltbl.path, 1, #(cfg.API_VERSION) + 6)

        local handled = nil
        local handleObject = EndpointAPITbl[endpointType]
        local output    = ""
        local mode      = "html"
        if(handleObject) then 
            if(req.method == "OPTIONS") then -- preflight call - return ok
                output  = ""
                mode    = "preflight"
            else 
                output = handleObject.handleEndpoint( urltbl.path, client, req, res, body )
                mode    = "json"
                handled = true 
            end 
        end 
        return handled, output, mode

    else 
        return nil, nil, nil 
    end
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

local function checkWebServer()

    -- Do a check on the webserver. If its not closed tell it to close.
    -- local ok, line = pipe.read(cfg.PIPE_ReadHttps, 32)
    -- if( ok > 0 ) then 
    --     p("[Pipe Read] "..ok.."  "..line)
    -- end
    -- p("[Complete] ------------>")
    ok = pipe.write(cfg.PIPE_WriteRouter, "ServerOk")
end

---------------------------------------------------------------------------------

local function run(port)

    ---------------------------------------------------------------------------------
    -- Need to auto update keys from lets encrypt
    local key = fs.readFileSync("./keys/privkey.pem")
    local cert = fs.readFileSync("./keys/fullchain.pem")

    ---------------------------------------------------------------------------------
    https.createServer({ key = key, cert = cert }, onRequest):listen(port)
    p("Router listening at https://"..cfg.SERVER_IP..":"..port.."/")

    -- Watch this webserver. If it dies, then restart it.
    pipe.close(cfg.PIPE_WriteHttps)
    pipe.close(cfg.PIPE_ReadRouter)
    timer.setInterval( 1000, checkWebServer )
    
    -- Need to catch sig and close (for proper shutdown)
    --tcpserve.close()
    ---------------------------------------------------------------------------------
    -- No general "module loop". Each game (module) will run an instance for each
    --   game it needs.
    -- tcpserve.runModules()


    print("Started router...")
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
