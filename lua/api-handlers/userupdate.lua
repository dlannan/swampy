
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

    local header =  req.headers
    
    -- Default error
    local outjson = json.encode( { status = "Error: Invalid user update" } )

    -- Update user player name or/and language
    if(header["DeviceId"] and (header["PlayerName"] or header["Language"])) then 

        -- Looks up in db and returns the bearertoken generated during login
        local ok = tcpserve.userUpdateName(header["DeviceId"], header["PlayerName"], header["Language"])
        if(ok) then 

            print("[userUpdate] PlayerName: ", header["PlayerName"], " Lang: ", header["Language"])
            outjson = json.encode( { status = "OK" } )
        end
    end
    return outjson
end 