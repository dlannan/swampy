
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local aes       = require("lua.aes")
local utils     = require("lua.utils")

-- User authenticate takes login info and generates a bearer token for all future calls
-- The bearer token is set in the http header when other requests are made.
-- /user/authenticate?logintoken={token}&uid={device_uid}

api_userAuthenticate = function( client, req, res )

    local params = url.parse(req.url)
    
    -- Default error
    local outjson = json.encode( { bearertoken = nil, status = "Error: No connect" } )

    -- Get logintoken and device must be resent - if device changes, then no connect
    if(params.query.logintoken and params.query.uid) then 

        -- Looks up in db and returns the bearertoken generated during login
        local bearertoken = tcpserve.authenticateUser(params.query.logintoken, params.query.uid)

        if(bearertoken ~= nil) then 

            print("[userAuthenticate] UserToken: ", params.query.logintoken, "  Device: ", params.query.uid)
            outjson = json.encode( { bearertoken = bearertoken, status = "OK" } )
        else
            outjson = json.encode( { bearertoken = nil, status = "Error: Invalid token" } )
        end
    end

    return outjson
end 