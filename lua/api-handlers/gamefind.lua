
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local utils     = require("lua.utils")

-- /game/find?name={game_name}&uid={user_id}

api_gameFind = function( client, req, res )

    local header =  req.headers
    -- Default error
    local outjson = json.encode( { result = nil, status = "Error: Cant find game." } )

    if(header["Name"] and header["DeviceId"]) then 

        -- This is effectively the bearertoken for the session. Will be sent with all further requests
        local jsonstr = tcpserve.gameFind(header["DeviceId"], header["Name"])

        if(jsonstr) then 
            print("[gameFind] Name: ", header["Name"], "  UID: ", header["DeviceId"])
            outjson = json.encode( { result = jsonstr, status = "OK" } )
        end
    end

    return outjson
end 