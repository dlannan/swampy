
-- These are global, but when running in a tee'd vm they will only 
--   be global to the game vm. 

local tcpserve  = require("app.dataserver")
local url       = require("lua.url")
local json      = require("lua.json")
local utils     = require("lua.utils")

local games     = require("app.gameserver")

-- /game/update?name={game_name}&uid={user_id}

-- Game update is a little special. It fetches the game state that is running in the  server. 
--    This is a module that is run in its own lua env. 
--    It has complete access to the sqlite db for the game data, and all user info. 
--    The update sends out information when this is requested

api_gameUpdate = function( client, req, res, body )

    local header =  req.headers
    -- Default error
    local outjson = json.encode( { result = nil, status = "Error: Cant update game." } )

    if(header["Name"] and header["DeviceId"]) then 

        -- Set the uid timeout. This is how we know they are still connected
        games.gameUserUpdate(header["DeviceId"], header["Name"])

        -- Get the current game state. This is within a running lua vm.
        local tblstr = tcpserve.gameUpdate(header["DeviceId"], header["Name"], body)

        if(tblstr) then 
            -- print("[gameUpdate] Name: ", header["Name"], "  UID: ", header["DeviceId"])
            outjson = json.encode( { result = tblstr, status = "OK" } )
        end
    end
    return outjson
end 