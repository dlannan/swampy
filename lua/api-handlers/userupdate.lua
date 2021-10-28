
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local aes       = require("lua.aes")
local utils     = require("lua.utils")

-- User authenticate takes login info and generates a bearer token for all future calls
-- The bearer token is set in the http header when other requests are made.
-- /user/update?playername={playername}&uid={device_uid}

api_userUpdate = function( client, req, res )

    local params = url.parse(req.url)
    
    -- Default error
    local outjson = json.encode( { status = "Error: Invalid user update" } )

    -- Update user player name or/and language
    if(params.query.uid and (params.query.playername or params.query.lang)) then 

        -- Looks up in db and returns the bearertoken generated during login
        local ok = tcpserve.userUpdateName(params.query.uid, params.query.playername, params.query.lang)
        if(ok) then 

            print("[userUpdate] PlayerName: ", params.query.playername, " Lang: ", params.query.lang)
            outjson = json.encode( { status = "OK" } )
        end
    end
    return outjson
end 