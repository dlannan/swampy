
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local aes       = require("lua.aes")
local utils     = require("lua.utils")

-- User authenticate takes login info and generates a bearer token for all future calls
-- The bearer token is set in the http header when other requests are made.
-- /api/adminupdate?username={username}

api_adminUpdate = function( client, req, res, body )

    local header =  req.headers
    
    -- Default error
    local outjson = json.encode( { status = "Error: Invalid admin update" } )

    -- Update user player name or/and language
    if(header["UserName"]) then 

        -- Looks up in db and returns the bearertoken generated during login
        local ok = tcpserve.setAdminUsername(client, header["UserName"])
        if(ok) then 

            print("[adminUpdate] UserName: ", header["UserName"])
            outjson = json.encode( { status = "OK" } )
        end
    end
    return outjson
end 

return api_adminUpdate